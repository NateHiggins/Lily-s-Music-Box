"""Future authorized exclusive-lane control: old haunt, exact restore, candidate.

Preparation only until the root grants live source and Godot ownership. This
script executes Godot when invoked; it is not part of the static inspection.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

from haunt_control import assess_pair

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
EVIDENCE = ROOT / "design/astra/evidence/resident_f01_haunt"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load_verified_run(folder):
    result = json.loads((folder / "result.json").read_text(encoding="utf-8"))
    entries = result["artifacts"]
    recorded = {entry["path"]: entry["sha256"] for entry in entries}
    required = {"godot.stdout.log", "godot.stdout.log.stderr", "shots/resident_f01_haunt.json", "before.all_game_files.json"}
    if len(recorded) != len(entries) or not required.issubset(recorded):
        raise ValueError("missing or duplicated consumed artifact binding")
    for name, digest in recorded.items():
        if Path(name).is_absolute() or ".." in Path(name).parts:
            raise ValueError("non-relative artifact path")
        path = folder / name
        if not path.is_file() or sha(path.read_bytes()) != digest:
            raise ValueError("retained run artifact differs: " + name)
    return result


def main():
    if len(sys.argv) != 2 or not re.fullmatch(r"[A-Za-z0-9_-]+", sys.argv[1]):
        raise SystemExit("Use one new plain transaction name after exclusive-lane authorization.")
    name = sys.argv[1]
    manifest = json.loads((BASE / "preparation.json").read_text(encoding="utf-8"))
    bindings = manifest["source_binding"]
    for path, record in bindings.items():
        assert sha((ROOT / path).read_bytes()) == record["proposed_sha256"], path + " is not the reviewed candidate"
    relative = "game/scripts/characters/resident_routines.gd"
    live = ROOT / relative
    candidate = live.read_bytes()
    original = (BASE / "originals" / relative).read_bytes()
    assert sha(original) == bindings[relative]["original_sha256"]
    assert original.replace(b'"transient_guests": {"at": Vector2(2.2, -6.2)',
                            b'"transient_guests": {"at": Vector2(2.2, -8.3)') == candidate
    run_names = [name + "_old_haunt", name + "_restored"]
    assert all(not (EVIDENCE / run).exists() for run in run_names)
    transaction = EVIDENCE / name
    transaction.mkdir(parents=True, exist_ok=False)
    (transaction / "candidate.before.gd").write_bytes(candidate)
    result = {"scope": "One-coordinate omission; do not treat expected red as acceptance", "runs": [],
              "expected_candidate_sha256": sha(candidate)}
    try:
        live.write_bytes(original)
        code = subprocess.run([sys.executable, str(BASE / "run_haunt.py"), "lift", run_names[0]], cwd=ROOT).returncode
        result["runs"].append({"name": run_names[0], "wrapper_exit": code})
    finally:
        live.write_bytes(candidate)
        result["candidate_restored_sha256"] = sha(live.read_bytes())
        result["exact_bytes_restored"] = live.read_bytes() == candidate
        (transaction / "restoration.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    assert result["exact_bytes_restored"]
    code = subprocess.run([sys.executable, str(BASE / "run_haunt.py"), "lift", run_names[1]], cwd=ROOT).returncode
    result["runs"].append({"name": run_names[1], "wrapper_exit": code})
    old = load_verified_run(EVIDENCE / run_names[0])
    restored = load_verified_run(EVIDENCE / run_names[1])
    old_checks = json.loads((EVIDENCE / run_names[0] / "shots/resident_f01_haunt.json").read_text(encoding="utf-8"))
    old_manifest = json.loads((EVIDENCE / run_names[0] / "before.all_game_files.json").read_text(encoding="utf-8"))
    restored_manifest = json.loads((EVIDENCE / run_names[1] / "before.all_game_files.json").read_text(encoding="utf-8"))
    old_map, restored_map = dict(old_manifest), dict(restored_manifest)
    changed = sorted(path for path in old_map.keys() | restored_map.keys()
                     if old_map.get(path) != restored_map.get(path))
    result["changed_between_control_and_restored"] = changed
    old_folder = EVIDENCE / run_names[0]
    new_folder = EVIDENCE / run_names[1]
    new_checks = json.loads((new_folder / "shots/resident_f01_haunt.json").read_text(encoding="utf-8"))
    assessment = assess_pair(old, restored, old_checks, new_checks,
        (old_folder / "godot.stdout.log").read_text(encoding="utf-8-sig"),
        (old_folder / "godot.stdout.log.stderr").read_text(encoding="utf-8-sig"),
        (new_folder / "godot.stdout.log").read_text(encoding="utf-8-sig"),
        (new_folder / "godot.stdout.log.stderr").read_text(encoding="utf-8-sig"),
        changed, result)
    result["assessment"] = assessment
    result["expected_control_pattern"] = assessment["expected_control_pattern"]
    result["scope"] = "Read both raw runtime receipts; expected old-haunt red then exact restored green, with unchanged fixture"
    (transaction / "restoration.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return int(not result["expected_control_pattern"])


if __name__ == "__main__":
    raise SystemExit(main())
