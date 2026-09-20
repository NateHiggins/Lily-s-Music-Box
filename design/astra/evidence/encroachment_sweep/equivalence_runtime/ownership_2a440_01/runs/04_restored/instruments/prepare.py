"""Rebind the existing controller; no new runner, engine or live writes."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = next(p for p in HERE.parents if (p / "game/project.godot").is_file())
OLD = HERE.with_name("runtime_plan_01")
SEALED = HERE.with_name("ownership_2a440_01")
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    files = ("assess.py", "execute.py", "expected_check_contract.json", "gate.py",
        "runner_bridge.ps1", "support.py", "test_gate.py", "test_runtime_plan.py")
    for name in files:
        target = HERE / name
        assert not target.exists(), "preserve prior preparation"
        raw = (OLD / name).read_bytes()
        if name == "execute.py":
            assert raw.count(b"ownership_7c54c_01") == 2
            raw = raw.replace(b"ownership_7c54c_01", b"ownership_2a440_01")
        target.write_bytes(raw)
    command = [sys.executable, "-B", "-m", "unittest", "discover", "-s", str(HERE), "-p", "test_*.py", "-v"]
    run = subprocess.run(command, cwd=ROOT, capture_output=True)
    (HERE / "controls.stdout.log").write_bytes(run.stdout)
    (HERE / "controls.stderr.log").write_bytes(run.stderr)
    assert run.returncode == 0, "preserve failed offline controller run"
    previous = json.loads((OLD / "package.json").read_text())
    binding = json.loads((SEALED / "preparation.json").read_text())
    manifest = {"schema": previous["schema"], "status": "PREPARED_OFFLINE_ENGINE_UNRUN_NO_LIVE_INSTALL",
        "controller_reuse": "All seven support files byte-identical; execute.py changes only sealed sibling and default evidence batch names.",
        "historical_controller_package_sha256": sha(OLD / "package.json"),
        "install": {p.relative_to(SEALED / "proposed").as_posix(): sha(p)
            for p in (SEALED / "proposed/game/tests").rglob("*") if p.is_file()},
        "production_bindings": {p: sha(ROOT / p) for p in previous["production_bindings"]},
        "serial_runner_sha256": sha(ROOT / "tools/run_godot_serial.ps1"),
        "engine_sha256": previous["engine_sha256"],
        "engine_hash_provenance": "Expected binaries inherited from the completed controller; actual execution independently verifies binaries, banner and child PID.",
        "commands": [["python", "-B", (HERE / "execute.py").relative_to(ROOT).as_posix(), action, "ownership_2a440_01"]
            for action in ("install", "candidate", "priority", "drop_late", "restored")],
        "source_binding": binding,
        "pure_python_controls": {"command": command, "tests": 25, "exit": run.returncode,
            "stdout": "controls.stdout.log", "stderr": "controls.stderr.log"},
        "sealed_files": {p.relative_to(SEALED).as_posix(): sha(p) for p in SEALED.rglob("*")
            if p.is_file() and "__pycache__" not in p.parts},
        "files": {p.name: sha(p) for p in HERE.iterdir() if p.is_file() and p.name != "package.json"}}
    assert len(manifest["install"]) == 6
    (HERE / "package.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"tests": 25, "exit": run.returncode, "package_sha256": sha(HERE / "package.json")}, indent=2))


if __name__ == "__main__":
    main()
