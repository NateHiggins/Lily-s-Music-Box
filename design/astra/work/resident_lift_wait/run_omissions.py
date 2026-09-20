"""Authorized exact-byte independent omissions; always restore reviewed candidate.

Requires exclusive Godot/source ownership. Uses unchanged final fixture/runner.
This script cannot label an omission green: each native/gate result is preserved.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
WORK = Path(__file__).resolve().parent
EVIDENCE = ROOT / "design/astra/evidence/resident_lift_waiting"
paths = {name: ROOT / "game/scripts/characters" / name
         for name in ("resident_nav.gd", "resident_routines.gd")}
candidate = {name: path.read_bytes() for name, path in paths.items()}
expected = {"resident_nav.gd": "362de8a26f67741960e0721a9da7ae95418eb5904db5c8deaf389d834b5baec8",
            "resident_routines.gd": "7e88a9f430e7f7ed7149312392f9711741e55fb51230f8eee53e3c634b33e6a5"}
sha = lambda data: hashlib.sha256(data).hexdigest()
assert all(sha(candidate[name]) == expected[name] for name in paths)
fixture = ROOT / "game/tests/resident_lift_waiting_test.gd"
fixture_sha = "d8587a70e51db0399cbafb087db76180886ec06142f5ab26a03f15c20481bae0"
assert sha(fixture.read_bytes()) == fixture_sha
transaction = EVIDENCE / "omission_transaction_01"
transaction.mkdir(exist_ok=False)
for name, data in candidate.items():
    (transaction / (name + ".candidate.txt")).write_bytes(data)
results = []
try:
    for run_name, omitted in (("omit_portal_01", "resident_nav.gd"),
                              ("omit_wait_01", "resident_routines.gd"),
                              ("candidate_restored_01", None)):
        for name, path in paths.items():
            data = candidate[name]
            if name == omitted:
                data = (WORK / name.replace(".gd", ".before.gd.txt")).read_bytes()
            path.write_bytes(data)
        assert sha(fixture.read_bytes()) == fixture_sha
        code = subprocess.run([sys.executable, str(WORK / "run_waiting.py"), "lift", run_name],
                              cwd=ROOT).returncode
        receipt = json.loads((EVIDENCE / run_name / "result.json").read_text(encoding="utf-8"))
        results.append({"run": run_name, "omitted": omitted, "wrapper_exit": code,
                        "native_exit": receipt["native_exit"], "gate_exit": receipt["diagnostic_gate"]["exit"],
                        "source_unchanged": receipt["source_unchanged"]})
finally:
    for name, path in paths.items():
        path.write_bytes(candidate[name])
    restored = {name: sha(path.read_bytes()) for name, path in paths.items()}
    record = {"runs": results, "candidate_expected": expected, "restored": restored,
              "exact_candidate_restored": restored == expected,
              "final_fixture_sha256": sha(fixture.read_bytes()), "expected_fixture_sha256": fixture_sha}
    (transaction / "restoration.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(record), flush=True)
    assert restored == expected and sha(fixture.read_bytes()) == fixture_sha
