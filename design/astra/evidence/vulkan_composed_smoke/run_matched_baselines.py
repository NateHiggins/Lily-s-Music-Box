"""Authorized exact one-file baseline restore, fresh runs, candidate restoration."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
BASE = Path(__file__).resolve().parent
LIVE = ROOT / "game/scripts/building/building_root.gd"
OUT = BASE / "matched_baseline_restore"
OUT.mkdir(exist_ok=False)
candidate = LIVE.read_bytes()
baseline = (BASE / "prechange/building_root.before.gd").read_bytes()
sha = lambda value: hashlib.sha256(value).hexdigest()
assert sha(candidate) == "cd174d254420dade5388fbe11745a38836d1bb3bfad44f85fdfc4e860aecb7a5"
assert sha(baseline) == "a357b6496ee96ad0ff1fe6a74d9e14ea84548090ef77e884db525336d132a17e"
(OUT / "candidate_before.gd").write_bytes(candidate)
results = []
try:
    LIVE.write_bytes(baseline)
    assert LIVE.read_bytes() == baseline
    for mode, name in [("street", "baseline_street_01"), ("passage", "baseline_passage_01")]:
        command = [sys.executable, str(BASE / "run_smoke.py"), mode, name]
        result = subprocess.run(command, cwd=ROOT, capture_output=True)
        (OUT / (name + ".wrapper.stdout.txt")).write_bytes(result.stdout)
        (OUT / (name + ".wrapper.stderr.txt")).write_bytes(result.stderr)
        results.append({"mode": mode, "command": command, "actual_wrapper_exit": result.returncode})
        print(result.stdout.decode(errors="replace"), flush=True)
finally:
    # Do not silently clobber a foreign source edit. This agent owns the file
    # and serial lane; any unexpected bytes require explicit attribution.
    assert LIVE.read_bytes() == baseline, "unexpected third-party building_root change during baseline"
    LIVE.write_bytes(candidate)
    restored = LIVE.read_bytes() == candidate
    (OUT / "restoration.json").write_text(json.dumps({
        "baseline_sha256": sha(baseline), "candidate_sha256": sha(candidate),
        "candidate_restored_exactly": restored, "results": results,
    }, indent=2) + "\n", encoding="utf-8")
    print("CANDIDATE_RESTORED_EXACTLY=" + str(restored), flush=True)
    assert restored
