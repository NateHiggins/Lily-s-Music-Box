"""Reuse proven snapshot/PID/environment/bridge mechanics; owner changes are explicit."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import time
import core
import assess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
BASE = HERE.parent
OWNER = "game/scripts/reality/apartment_encroachment.gd"
EVIDENCE = ROOT / "design/astra/evidence/apartment_floor_ownership"
core.HERE = HERE; core.ROOT = ROOT; core.RUNNER = ROOT / "tools/run_godot_serial.ps1"; core.BRIDGE = HERE / "runner_bridge.ps1"
_instrument_paths = core.instrument_paths
core.instrument_paths = lambda: {**_instrument_paths(), "parent_expected_contract.json": BASE / "expected_contract.json", "parent_preparation.json": BASE / "preparation.json"}
PHASES = {"original": ("originals", "red", "01_original"), "candidate": ("proposed", "green", "02_candidate"),
          "omission": ("omission", "red", "03_omission"), "restored": ("proposed", "green", "04_restored"),
          "binding36": ("proposed", "binding36", "05_binding36")}
sha = core.sha; dump = core.dump


def check_package():
    package = json.loads((HERE / "package.json").read_text())
    for name, fingerprint in package["files"].items():
        if sha(HERE / name) != fingerprint: raise ValueError("runtime instrument changed: " + name)
    prep = json.loads((BASE / "preparation.json").read_text())
    for name, fingerprint in prep["files"].items():
        if sha(BASE / name) != fingerprint: raise ValueError("prepared producer package changed: " + name)
    if sha(core.RUNNER) != package["serial_runner_sha256"]: raise ValueError("canonical runner changed")
    return package


def install(batch):
    package = check_package()
    if core.godot_processes(): raise ValueError("lane busy before fixture install")
    if sha(ROOT / OWNER) != package["owner_hashes"]["originals"]: raise ValueError("original owner required")
    out = EVIDENCE / batch; out.mkdir(parents=True, exist_ok=False)
    for name in package["install"]:
        if (ROOT / name).exists(): raise ValueError("new fixture target already exists")
    for name in package["install"]:
        target = ROOT / name; target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(BASE / "proposed" / name, target)
    rows = core.all_game_rows(); dump(out / "installed.all_game_files.json", rows)
    state = {"status": "EXACT_TWO_TEST_FILES_INSTALLED_ORIGINAL_OWNER", "head": core.git("rev-parse", "HEAD").decode().strip(),
             "files": dict(rows), "runtime_package_sha256": sha(HERE / "package.json"), "install": package["install"]}
    dump(out / "install.json", state)


def selected_context(package, source):
    manifest = json.loads(json.dumps(package))
    manifest["production_bindings"][OWNER] = package["owner_hashes"][source]
    return manifest


def run(phase, batch):
    package = check_package(); batch_root = EVIDENCE / batch
    state = json.loads((batch_root / "install.json").read_text())
    if state["runtime_package_sha256"] != sha(HERE / "package.json"): raise ValueError("runtime package differs from install")
    source, expected, name = PHASES[phase]
    prior_names = list(PHASES)[:list(PHASES).index(phase)]
    for prior in prior_names:
        receipt = json.loads((batch_root / "runs" / PHASES[prior][2] / "result.json").read_text())
        if receipt["assessment"]["control_acceptance_exit"] != 0: raise ValueError("preceding proof did not meet its contract: " + prior)
        for relative, fingerprint in receipt["artifacts"].items():
            if sha(batch_root / "runs" / PHASES[prior][2] / relative) != fingerprint: raise ValueError("prior raw artifact changed")
    if core.godot_processes(): raise ValueError("lane busy before source transition")
    previous_source = PHASES[prior_names[-1]][0] if prior_names else "originals"
    if prior_names and prior_names[-1] == "omission":
        restoration = json.loads((batch_root / "omission_restoration.json").read_text())
        if restoration != {"candidate_sha256": package["owner_hashes"]["proposed"], "exact": True}: raise ValueError("exact omission restoration not established")
        previous_source = "proposed"
    if sha(ROOT / OWNER) != package["owner_hashes"][previous_source]: raise ValueError("owner bytes differ from exact preceding phase")
    if core.git("rev-parse", "HEAD").decode().strip() != state["head"]: raise ValueError("HEAD changed")
    current = dict(core.all_game_rows()); allowed = dict(state["files"]); allowed[OWNER] = package["owner_hashes"][previous_source]
    if current != allowed: raise ValueError("unrelated game mutation before phase")
    shutil.copy2(BASE / source / OWNER, ROOT / OWNER)
    # Failure/exception after an omission always restores only its exact owned bytes.
    try:
        return run_installed(phase, expected, source, batch_root, name, state, package)
    finally:
        if phase == "omission":
            actual = sha(ROOT / OWNER)
            if actual != package["owner_hashes"]["omission"]: raise ValueError("refuse restoration over unexpected owner edit")
            shutil.copy2(BASE / "proposed" / OWNER, ROOT / OWNER)
            dump(batch_root / "omission_restoration.json", {"candidate_sha256": sha(ROOT / OWNER), "exact": sha(ROOT / OWNER) == package["owner_hashes"]["proposed"]})


def run_installed(phase, expected, source, batch_root, name, state, package):
    out = batch_root / "runs" / name; out.mkdir(parents=True, exist_ok=False)
    profile = out / "APPDATA"; profile.mkdir(); shots = out / "shots"; shots.mkdir()
    context = selected_context(package, source); core.package_check = lambda: context
    scene = "ApartmentMaterialBindingTest" if expected == "binding36" else "WardrobeFloorAdmissionTest"
    parameters = {"ProjectPath": str(ROOT / "game"), "Scene": "res://tests/" + scene + ".tscn", "LogPath": str(out / "godot.stdout.log"), "ShotDir": str(shots), "TimeoutSeconds": 60, "ExtraArgs": ["--verbose"]}
    dump(out / "invocation.json", {"runner": str(core.RUNNER), "parameters": parameters})
    command = [str(core.PWSH), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(core.BRIDGE), "-InvocationPath", str(out / "invocation.json")]
    dump(out / "command.json", command)
    env, removed = core.clean_environment(os.environ, "candidate", profile); env.pop("ENCROACH_SWEEP_VARIANT", None)
    (out / "instruments").mkdir()
    for name, path in core.instrument_paths().items(): shutil.copy2(path, out / "instruments" / name)
    before = core.snapshot(out, "before")
    wanted = dict(state["files"]); wanted[OWNER] = package["owner_hashes"][source]
    if before["all_game_files_sha256"] != core.digest(sorted(wanted.items())): raise ValueError("source transition changed unrelated game inputs")
    if sorted(row["sha256"] for row in before["engine_binaries"]) != sorted(package["engine_sha256"]): raise ValueError("engine changed")
    config = {"schema": "astra.wardrobe-floor.run.v1", "phase": phase, "expected": expected, "source": source, "before": before, "started_utc": core.utc(), "command": command, "parameters": parameters, "fresh_APPDATA": str(profile), "profile_existed_before_run": False, "cleared_environment_keys": removed, "expected_checks": 36 if expected == "binding36" else 63}
    dump(out / "run_config.json", config); dump(out / "prelaunch_processes.json", core.godot_processes())
    samples = []; started = time.perf_counter()
    with (out / "runner.stdout.log").open("wb") as stdout, (out / "runner.stderr.log").open("wb") as stderr:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr)
        while process.poll() is None:
            rows = core.godot_processes()
            if rows and (not samples or rows != samples[-1]["processes"]):
                samples.append({"elapsed_seconds": time.perf_counter() - started, "processes": rows})
                dump(out / "process_observations.json", samples)
            time.sleep(0.05)
    elapsed = time.perf_counter() - started; dump(out / "process_observations.json", samples)
    after = core.snapshot(out, "after")
    read = lambda name: (out / name).read_text(encoding="utf-8-sig", errors="replace") if (out / name).is_file() else ""
    probe = None; receipt_error = None
    if expected != "binding36":
        try: probe = json.loads(read("shots/wardrobe_floor.json"))
        except ValueError as error: receipt_error = str(error)
    pid_ok = core.child_engine_seen(samples, process.pid); engine_ok = core.EXPECTED_ENGINE in read("godot.stdout.log")
    verdict = assess.assess(probe, read("godot.stdout.log"), read("godot.stdout.log.stderr"), read("runner.stdout.log") + "\n" + read("runner.stderr.log"), process.returncode, before == after, pid_ok, engine_ok, expected)
    result = {**config, "after": after, "finished_utc": core.utc(), "actual_runner_exit": process.returncode, "serial_process_elapsed_seconds": elapsed, "source_unchanged": before == after, "pid_ancestry_verified": pid_ok, "engine_identity_verified": engine_ok, "receipt_read_error": receipt_error, "assessment": verdict, "artifacts": {p.relative_to(out).as_posix(): sha(p) for p in out.rglob("*") if p.is_file() and "APPDATA" not in p.relative_to(out).parts}}
    required = ["godot.stdout.log", "godot.stdout.log.stderr", "runner.stdout.log", "runner.stderr.log", "process_observations.json", "before.all_game_files.json", "after.all_game_files.json", "before.runtime_text.json", "after.runtime_text.json", "command.json", "invocation.json", "run_config.json"]
    if expected != "binding36": required.append("shots/wardrobe_floor.json")
    if any(name not in result["artifacts"] for name in required):
        verdict["reasons"].append("required_raw_artifact_missing"); verdict["control_acceptance_exit"] = 1; verdict["diagnostic_gate_exit"] = 1
    dump(out / "result.json", result)
    print(json.dumps({"phase": phase, "actual_runner_exit": process.returncode, "receipt": str(out / "result.json"), "assessment": verdict}), flush=True)
    return verdict["control_acceptance_exit"]


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("phase", choices=["install", *PHASES]); parser.add_argument("batch"); args = parser.parse_args()
    if not __import__("re").fullmatch(r"[A-Za-z0-9_-]+", args.batch): raise ValueError("fresh plain batch name required")
    if args.phase == "install": install(args.batch); return 0
    return run(args.phase, args.batch)


if __name__ == "__main__": raise SystemExit(main())
