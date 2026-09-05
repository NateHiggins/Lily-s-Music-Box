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

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
EVIDENCE = ROOT / "design/astra/evidence/resident_f01_haunt"


def sha(data):
    return hashlib.sha256(data).hexdigest()


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
    result = {"scope": "One-coordinate omission; do not treat expected red as acceptance", "runs": []}
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
    old = json.loads((EVIDENCE / run_names[0] / "result.json").read_text(encoding="utf-8"))
    restored = json.loads((EVIDENCE / run_names[1] / "result.json").read_text(encoding="utf-8"))
    old_checks = json.loads((EVIDENCE / run_names[0] / "shots/resident_f01_haunt.json").read_text(encoding="utf-8"))
    checks = {row["label"]: row["passed"] for row in old_checks.get("checks", [])}
    old_manifest = json.loads((EVIDENCE / run_names[0] / "before.all_game_files.json").read_text(encoding="utf-8"))
    restored_manifest = json.loads((EVIDENCE / run_names[1] / "before.all_game_files.json").read_text(encoding="utf-8"))
    old_map, restored_map = dict(old_manifest), dict(restored_manifest)
    changed = sorted(path for path in old_map.keys() | restored_map.keys()
                     if old_map.get(path) != restored_map.get(path))
    result["changed_between_control_and_restored"] = changed
    result["expected_control_pattern"] = (
        old.get("native_exit") == 1 and old.get("diagnostic_gate", {}).get("exit") == 1
        and old.get("source_unchanged") is True
        and checks.get("whole destination body footprint fits the public F01 lobby") is False
        and checks.get("actual F01 readiness alone releases the rider at its public landing") is True
        and restored.get("native_exit") == 0 and restored.get("diagnostic_gate", {}).get("exit") == 0
        and restored.get("source_unchanged") is True and restored.get("suite_completion") is True
        and old["before"]["engine_binaries"] == restored["before"]["engine_binaries"]
        and old["test_sha256"] == restored["test_sha256"]
        and changed == [relative])
    result["scope"] = "Read both raw runtime receipts; expected old-haunt red then exact restored green, with unchanged fixture"
    (transaction / "restoration.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return int(not result["expected_control_pattern"])


if __name__ == "__main__":
    raise SystemExit(main())
