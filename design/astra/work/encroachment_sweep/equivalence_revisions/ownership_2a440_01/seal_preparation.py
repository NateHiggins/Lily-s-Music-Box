"""Seal this bounded source preparation without engine or live installation."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "game/project.godot").is_file())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    command = [sys.executable, "-B", "-m", "unittest", "discover", "-s", str(HERE), "-p", "test_*.py", "-v"]
    result = subprocess.run(command, cwd=ROOT, capture_output=True)
    (HERE / "controls.stdout.log").write_bytes(result.stdout)
    (HERE / "controls.stderr.log").write_bytes(result.stderr)
    dependencies = json.loads((HERE.with_name("runtime_plan_01") / "package.json").read_text())["production_bindings"]
    current = {path: sha(ROOT / path) for path in dependencies}
    old = HERE.with_name("ownership_7c54c_01")
    preserved = ["gate.py", "expected_check_contract.json",
        "proposed/game/tests/encroachment_sweep_equivalence_test.gd",
        "proposed/game/tests/EncroachmentSweepEquivalenceTest.tscn"]
    assert all((HERE / p).read_bytes() == (old / p).read_bytes() for p in preserved)
    receipt = {"status": "PREPARATION_ONLY_ENGINE_UNRUN_LIVE_GAME_UNCHANGED",
        "source_binding": json.loads((HERE / "preparation.json").read_text()),
        "pure_python_controls": {"command": command, "tests": 23, "exit": result.returncode,
            "stdout": "controls.stdout.log", "stderr": "controls.stderr.log"},
        "expected_complete_fixture_check_count": 171,
        "unchanged_historical_contract": {p: sha(HERE / p) for p in preserved},
        "direct_dependency_hashes_at_preparation": current,
        "dependency_limit": "Bounded direct inputs only. Runtime controller must freeze and snapshot all game inputs during actual runs.",
        "engine_checks": "NOT_RUN", "performance_claim": "NONE",
        "open_scope": ["Current-source Godot parse and all four equivalence runs",
            "Actual composed candidate material/render/lifecycle and matched cost"],
        "artifacts": {p.relative_to(HERE).as_posix(): sha(p) for p in sorted(HERE.rglob("*"))
            if p.is_file() and "__pycache__" not in p.parts and p.name != "preparation_receipt.json"}}
    (HERE / "preparation_receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"exit": result.returncode, "tests": 23, "receipt_sha256": sha(HERE / "preparation_receipt.json")}, indent=2))
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
