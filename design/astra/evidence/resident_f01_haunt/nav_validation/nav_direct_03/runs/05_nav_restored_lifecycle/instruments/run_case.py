"""Prepared exclusive-lane execution. Importing this module never launches Godot."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

import assess as contract
import support
from haunt_control import clean_environment

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
EVIDENCE = ROOT / "design/astra/evidence/resident_f01_haunt/nav_validation"
RUNNER = ROOT / "tools/run_godot_serial.ps1"
BRIDGE = HERE / "runner_bridge.ps1"
PWSH = support.PWSH


def dump(path, value):
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def package_check():
    manifest = json.loads((HERE / "package.json").read_text(encoding="utf-8"))
    for relative, fingerprint in manifest["files"].items():
        if contract.sha(HERE / relative) != fingerprint: raise ValueError("package changed: " + relative)
    if contract.sha(RUNNER) != manifest["serial_runner_sha256"]: raise ValueError("canonical runner changed")
    if contract.sha(support.PARSER_PATH) != manifest["pairing_parser_sha256"]: raise ValueError("pairing parser changed")
    return manifest


def all_game_rows():
    raw = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "--cached", "--others",
                                   "--exclude-standard", "-z", "--", "game"])
    return [[p, contract.sha(ROOT / p)] for p in sorted(set(raw.decode().split("\0"))) if p and (ROOT / p).is_file()]


def instrument_paths():
    paths = {p.name: p for p in HERE.iterdir() if p.is_file() and p.suffix in {".py", ".ps1", ".json"}}
    paths["canonical_run_godot_serial.ps1"] = RUNNER
    paths["pairing_parser.py"] = support.PARSER_PATH
    return paths


def snapshot(out, label):
    rows = all_game_rows()
    runtime = [[p, digest] for p, digest in rows if p == "game/project.godot"
        or p.startswith("game/scripts/") and p.endswith(".gd")
        or p.startswith("game/scenes/") and p.endswith((".tscn", ".tres"))
        or p.startswith("game/data/") and p.endswith(".json")]
    dump(out / (label + ".all_game_files.json"), rows)
    dump(out / (label + ".runtime_inputs.json"), runtime)
    # Preserve full authored text and tests; large binary assets stay hash-bound.
    for relative, _ in rows:
        if relative.endswith((".gd", ".tscn", ".tres", ".json", ".godot")):
            target = out / label / "source" / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, target)
    (out / (label + ".game.diff")).write_bytes(subprocess.check_output(
        ["git", "-C", str(ROOT), "diff", "--binary", "HEAD", "--", "game"]))
    return {"all_game_files_sha256": support.digest(rows), "runtime_inputs_sha256": support.digest(runtime),
            "instruments": {name: contract.sha(path) for name, path in instrument_paths().items()},
            "engine_binaries": support.parser_module.engine_binary_manifest()}


def serial_command(out, parameters):
    invocation = out / "invocation.json"
    dump(invocation, {"runner": str(RUNNER), "parameters": parameters})
    return [str(PWSH), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(BRIDGE),
            "-InvocationPath", str(invocation)]


def child_engine_seen(observations, runner_pid):
    rows = {int(p["pid"]): p for sample in observations for p in sample["processes"]}
    for pid, row in rows.items():
        if row["executable"].lower() != "godot_v4.7.1-stable_win64.exe": continue
        cursor = pid
        for _ in range(8):
            parent = rows.get(cursor, {}).get("parent_pid")
            if parent == runner_pid: return True
            if parent is None or parent == cursor: break
            cursor = parent
    return False


def run(mode, expected, name, batch):
    package_check()
    if not all(re.fullmatch(r"[A-Za-z0-9_-]+", s) for s in [name, batch]): raise ValueError("plain fresh names required")
    out = EVIDENCE / batch / "runs" / name
    out.mkdir(parents=True, exist_ok=False)
    profile = out / "APPDATA"; profile.mkdir()
    shots = out / "shots"; shots.mkdir()
    info = contract.MODES[mode]
    parameters = {"ProjectPath": str(ROOT / "game"), "Scene": "res://tests/" + info["scene"] + ".tscn",
        "LogPath": str(out / "godot.stdout.log"), "ShotDir": str(shots), "TimeoutSeconds": 180,
        "Windowed": True, "ExtraArgs": ["--verbose", "--audio-driver", "Dummy", "--resolution", "1280x720",
            "--rendering-method", "forward_plus", "--rendering-driver", "vulkan"]}
    command = serial_command(out, parameters)
    dump(out / "command.json", command)
    env, cleared, present = clean_environment(os.environ)
    for key in list(env):
        if key.startswith(("ENCROACH_", "SCHEDULE_", "DAYNIGHT_")) or key in {"ENCROACH", "LIVING", "SURFACE", "DAYNIGHT"}:
            present.append(key); cleared.append(key); env.pop(key)
    env["APPDATA"] = str(profile)
    env["CAMPAIGN_TIME_FREEZE"] = "1"
    binding = {name: contract.sha(path) for name, path in instrument_paths().items()}
    (out / "instruments").mkdir()
    for instrument, path in instrument_paths().items(): shutil.copy2(path, out / "instruments" / instrument)
    before = snapshot(out, "before")
    config = {"schema": "astra.nav-validation.run.v1", "mode": mode, "expected": expected, "name": name,
        "batch": batch, "scene": parameters["Scene"], "command": command, "parameters": parameters,
        "fresh_APPDATA": str(profile), "profile_existed_before_run": False, "started_utc": support.utc(),
        "cleared_environment_keys": sorted(set(cleared)), "present_overrides_removed": sorted(set(present)),
        "before": before, "instrument_binding": binding,
        "head_observed": subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"]).decode().strip(),
        "scope": "Selected nav admission/actual resident/regression scope only; no visual, all-resident or performance acceptance."}
    dump(out / "run_config.json", config)
    started = time.perf_counter(); observations = []
    with (out / "runner.stdout.log").open("wb") as stdout_file, (out / "runner.stderr.log").open("wb") as stderr_file:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stdout_file, stderr=stderr_file)
        while process.poll() is None:
            current = support.godot_processes()
            if current and (not observations or current != observations[-1]["processes"]):
                observations.append({"elapsed_seconds": time.perf_counter() - started, "processes": current})
                dump(out / "process_observations.json", observations)
            time.sleep(0.05)
        code = process.returncode
    dump(out / "process_observations.json", observations)
    after = snapshot(out, "after")
    read = lambda p: p.read_text(encoding="utf-8-sig", errors="replace") if p.is_file() else ""
    stdout = read(out / "godot.stdout.log"); stderr = read(out / "godot.stdout.log.stderr")
    runner_text = read(out / "runner.stdout.log") + "\n" + read(out / "runner.stderr.log")
    scene = None; receipt_error = None
    if info["json"]:
        try: scene = json.loads((shots / info["json"]).read_text(encoding="utf-8"))
        except (OSError, ValueError, UnicodeError) as error: receipt_error = str(error)
    stable = before == after and len(before["engine_binaries"]) == 2
    pid_ok = child_engine_seen(observations, process.pid)
    engine_ok = support.parser_module.EXPECTED_ENGINE in stdout and "Vulkan " in stdout and "Forward+" in stdout
    assessment = contract.assess(mode, expected, scene, stdout, stderr, runner_text, code, stable, pid_ok, engine_ok)
    result = {**config, "after": after, "finished_utc": support.utc(), "runner_pid": process.pid,
        "actual_runner_exit": code, "elapsed_seconds": time.perf_counter() - started,
        "source_unchanged": stable, "pid_ancestry_verified": pid_ok, "engine_identity_verified": engine_ok,
        "receipt_read_error": receipt_error, "assessment": assessment,
        "actual_renderer_lines": [line for line in stdout.splitlines() if line.startswith("Vulkan ")],
        "raw_log_presence": {name: (out / name).is_file() for name in ["godot.stdout.log", "godot.stdout.log.stderr"]},
        "artifacts": {p.relative_to(out).as_posix(): contract.sha(p) for p in sorted(out.rglob("*"))
                      if p.is_file() and "APPDATA" not in p.relative_to(out).parts}}
    dump(out / "result.json", result)
    print(json.dumps({"name": name, "actual_runner_exit": code,
        "diagnostic_gate_exit": assessment["diagnostic_gate_exit"],
        "control_acceptance_exit": assessment["control_acceptance_exit"],
        "runner_condition": assessment["runner_condition"], "reasons": assessment["reasons"]}), flush=True)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("mode", choices=contract.MODES)
    p.add_argument("expected", choices=["green", "old_direct", "nav_omission", "coordinate_omission"])
    p.add_argument("batch"); p.add_argument("name")
    args = p.parse_args()
    return run(args.mode, args.expected, args.name, args.batch)["assessment"]["control_acceptance_exit"]


if __name__ == "__main__": raise SystemExit(main())
