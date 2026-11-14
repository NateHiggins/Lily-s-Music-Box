"""Run serial, source-restored negative controls in the isolated Astra worktree."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]
SOURCES = Path(__file__).resolve().parent
OUT = SOURCES / "owner_controls_v2"
OUT.mkdir(exist_ok=False)
REGISTER = ROOT / "game/scripts/props/night_register_prop.gd"
POLICY = ROOT / "game/scripts/audio/audio_policy.gd"
FIXTURE = ROOT / "game/tests/night_register_audio_lifecycle_test.gd"
original = {path: path.read_bytes() for path in [REGISTER, POLICY]}
cases = [
    ("missing_owner_release", REGISTER, SOURCES / "red_sources/game/scripts/props/night_register_prop.gd", 1),
    ("missing_pending_playback_release", POLICY, SOURCES / "audio_policy_before.gd", 1),
    ("complete_owner_release", None, None, 0),
]
receipt = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
           "fixture_sha256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "runs": []}
assert not (OUT / "owner_controls.json").exists(), "Evidence exists; select a fresh run directory"
try:
    for name, target, replacement, expected in cases:
        assert all(path.read_bytes() == blob for path, blob in original.items())
        if target:
            target.write_bytes(replacement.read_bytes())
        before = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                  for path in [REGISTER, POLICY, FIXTURE]}
        env = os.environ.copy()
        env["APPDATA"] = str(OUT / ("userdata_" + name))
        assert not Path(env["APPDATA"]).exists()
        log = OUT / (name + ".stdout.log")
        quote = lambda value: "'" + str(value).replace("'", "''") + "'"
        command = ("& " + quote(ROOT / "tools/run_godot_serial.ps1") + " -Scene "
                   + quote("res://tests/NightRegisterAudioLifecycleTest.tscn")
                   + " -ProjectPath " + quote(ROOT / "game") + " -LogPath " + quote(log)
                   + " -TimeoutSeconds 30 -ExtraArgs @('--verbose')")
        args = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command]
        start = time.monotonic()
        result = subprocess.run(args, cwd=ROOT, env=env, capture_output=True, text=True)
        after = {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                 for path in [REGISTER, POLICY, FIXTURE]}
        record = {"case": name, "args": args, "exit": result.returncode, "expected_exit": expected,
                  "seconds": round(time.monotonic()-start, 3), "source_before": before,
                  "source_after": after, "source_unchanged": before == after,
                  "stdout_sha256": hashlib.sha256(log.read_bytes()).hexdigest() if log.exists() else None,
                  "stderr_sha256": hashlib.sha256(Path(str(log)+".stderr").read_bytes()).hexdigest() if Path(str(log)+".stderr").exists() else None,
                  "runner_stdout": result.stdout, "runner_stderr": result.stderr}
        receipt["runs"].append(record)
        if target:
            target.write_bytes(original[target])
        print(json.dumps({k: record[k] for k in ["case", "exit", "expected_exit", "seconds", "source_unchanged"]}), flush=True)
        assert result.returncode == expected and before == after
finally:
    for path, blob in original.items():
        path.write_bytes(blob)
    receipt["production_sources_restored"] = all(path.read_bytes() == blob for path, blob in original.items())
    (OUT / "owner_controls.json").write_text(json.dumps(receipt, indent=2)+"\n")
