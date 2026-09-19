"""Read an immutable Vulkan run; write the additive verdict outside that run."""
from pathlib import Path
import argparse
import hashlib
import importlib.machinery
import importlib.util
import json
import re
from material_gate import classify_materials

BASE_GATE_SHA = "2197f6ad6b9a13cf83c1d99313808b20b3a8be1472997d7e53d6ef61e035d264"
OWNER = "game/scripts/reality/apartment_encroachment.gd"
FIXTURE = "game/tests/vulkan_composed_root_test.gd"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect(result_path, owner_sha, fixture_sha):
    folder = result_path.parent
    result = json.loads(result_path.read_text())
    artifacts = result.get("artifacts", {})
    required = ["stdout.log", "stdout.log.stderr", "frames/probe.json", "before.diff", "after.diff", "gate.py.source"]
    reasons = []
    for name in required:
        path = folder / name
        if not path.is_file() or artifacts.get(name) != sha(path):
            reasons.append("missing or changed consumed artifact: " + name)
    gate_path = folder / "gate.py.source"
    if not gate_path.is_file() or sha(gate_path) != BASE_GATE_SHA:
        reasons.append("saved base diagnostic gate is not the unchanged bound version")
    before = result.get("before", {}).get("files", {})
    after = result.get("after", {}).get("files", {})
    stable = bool(before and before == after and result.get("source_unchanged") is True)
    if not stable:
        reasons.append("runtime source/assets changed or missing")
    if before.get(OWNER) != owner_sha or after.get(OWNER) != owner_sha \
            or before.get(FIXTURE) != fixture_sha or after.get(FIXTURE) != fixture_sha:
        reasons.append("exact owner/fixture source binding does not match request")
    for label in ("before", "after"):
        diff_path = folder / (label + ".diff")
        if diff_path.is_file() and result.get(label, {}).get("diff_sha256") != sha(diff_path):
            reasons.append("source diff metadata disagrees with consumed bytes: " + label)
    # Any source copy consumed for the binding must have its artifact hash;
    # tracked unchanged files can instead be reproduced from the retained HEAD.
    for prefix in ("before_sources", "after_sources"):
        for name, expected in ((OWNER, owner_sha), (FIXTURE, fixture_sha)):
            key = prefix + "/" + name
            path = folder / key
            if path.exists() and (artifacts.get(key) != sha(path) or sha(path) != expected):
                reasons.append("changed source copy: " + key)
    if reasons:
        return {"diagnostic_gate_exit": 1, "artifact_binding_reasons": reasons}
    loader = importlib.machinery.SourceFileLoader("bound_vulkan_gate", str(gate_path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    gate = importlib.util.module_from_spec(spec)
    loader.exec_module(gate)
    probe = json.loads((folder / "frames/probe.json").read_text())
    if any(probe.get(key) != result.get(key) for key in ("root", "variant", "execution_scope")):
        return {"diagnostic_gate_exit": 1, "artifact_binding_reasons": ["actual probe identity differs from requested run"]}
    stdout = (folder / "stdout.log").read_text(errors="replace")
    stderr = (folder / "stdout.log.stderr").read_text(errors="replace")
    engines = result.get("engines_before", [])
    engine_bound = len(engines) == 2 and engines == result.get("engines_after")
    base = gate.classify(result["actual_engine_exit"], stdout, stderr, probe, stable, engine_bound)
    material = classify_materials(probe, owner_sha)
    return {"diagnostic_gate_exit": int(base["diagnostic_gate_exit"] != 0 or material["material_gate_exit"] != 0),
            "base_gate": base, "material_gate": material, "artifact_binding_reasons": [],
            "source_result_sha256": sha(result_path), "owner_sha256": owner_sha, "fixture_sha256": fixture_sha,
            "consumed_artifacts": {name: artifacts[name] for name in required},
            "scope": "additive material contract; preserves existing native/capture/root/source gates and their expected-red semantics"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("result", type=Path)
    parser.add_argument("--owner-sha256", required=True)
    parser.add_argument("--fixture-sha256", required=True)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    if not all(re.fullmatch("[0-9a-f]{64}", value) for value in (args.owner_sha256, args.fixture_sha256)):
        parser.error("explicit lowercase SHA256 bindings required")
    result_path, output = args.result.resolve(), args.out.resolve()
    if output.is_relative_to(result_path.parent) or output.exists():
        parser.error("output must be a new path outside the immutable run folder")
    try:
        report = inspect(result_path, args.owner_sha256, args.fixture_sha256)
    except (OSError, ValueError, KeyError, TypeError) as error:
        report = {"diagnostic_gate_exit": 1, "artifact_binding_reasons": [str(error)]}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return report["diagnostic_gate_exit"]


if __name__ == "__main__":
    raise SystemExit(main())
