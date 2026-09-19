"""Explicit install/run/restore plan. Import and plan never launch Godot or edit game."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import time

import assess
from support import sha, digest, dump, utc, godot_processes

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
SEALED = HERE.with_name("ownership_2a440_01")
EVIDENCE = ROOT / "design/astra/evidence/encroachment_sweep/equivalence_runtime"
RUNNER = ROOT / "tools/run_godot_serial.ps1"
BRIDGE = HERE / "runner_bridge.ps1"
PWSH = Path(r"C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe")
OWNER = "game/scripts/reality/apartment_encroachment.gd"
MODES = {"candidate": ("candidate", "01_candidate"), "priority": ("priority", "02_priority"),
         "drop_late": ("drop_late", "03_drop_late"), "restored": ("candidate", "04_restored")}
ORDER = list(MODES)
ENGINE_NAME = "Godot_v4.7.1-stable_win64.exe"
EXPECTED_ENGINE = "4.7.1.stable.official.a13da4feb"


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def package_check():
    manifest = json.loads((HERE / "package.json").read_text(encoding="utf-8"))
    for relative, fingerprint in manifest["files"].items():
        if sha(HERE / relative) != fingerprint: raise ValueError("prepared package changed: " + relative)
    for relative, fingerprint in manifest["sealed_files"].items():
        if sha(SEALED / relative) != fingerprint: raise ValueError("sealed source package changed: " + relative)
    for relative, fingerprint in manifest["production_bindings"].items():
        if sha(ROOT / relative) != fingerprint: raise ValueError("reviewed production dependency changed: " + relative)
    if sha(RUNNER) != manifest["serial_runner_sha256"]: raise ValueError("canonical runner changed")
    return manifest


def all_game_rows():
    paths = git("ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", "game").decode().split("\0")
    return [[p, sha(ROOT / p)] for p in sorted(set(paths)) if p and (ROOT / p).is_file()]


def instrument_paths():
    result = {p.name: p for p in HERE.iterdir() if p.is_file() and p.suffix in (".py", ".ps1", ".json")}
    result["canonical_run_godot_serial.ps1"] = RUNNER
    return result


def engine_manifest():
    command = [str(PWSH), "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; (Get-Command Godot_v4.7.1-stable_win64_console.exe -ErrorAction Stop).Source"]
    launcher = Path(subprocess.check_output(command, cwd=ROOT, text=True).strip())
    return [{"path": str(p), "bytes": p.stat().st_size, "sha256": sha(p)}
            for p in (launcher, launcher.with_name(ENGINE_NAME))]


def snapshot(out, label):
    rows = all_game_rows()
    runtime = [[p, h] for p, h in rows if p.endswith((".gd", ".tscn", ".tres", ".json", ".godot", ".gdshader", ".gdshaderinc"))]
    dump(out / (label + ".all_game_files.json"), rows)
    dump(out / (label + ".runtime_text.json"), runtime)
    manifest = json.loads((HERE / "package.json").read_text())
    selected = sorted(set(manifest["install"]) | set(manifest["production_bindings"]))
    for relative in selected:
        target = out / label / "source" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, target)
    (out / (label + ".game.diff")).write_bytes(git("diff", "--binary", "HEAD", "--", "game"))
    return {"all_game_files_sha256": digest(rows), "runtime_text_sha256": digest(runtime),
            "copied_sources": {relative: sha(ROOT / relative) for relative in selected},
            "head_observed": git("rev-parse", "HEAD").decode().strip(),
            "instruments": {name: sha(path) for name, path in instrument_paths().items()},
            "engine_binaries": engine_manifest()}


def batch_path(name):
    if not re.fullmatch(r"[A-Za-z0-9_-]+", name): raise ValueError("fresh plain batch name required")
    return EVIDENCE / name


def verify_install(root, install, expected):
    if len(expected) != 6 or install["installed"] != expected: raise ValueError("six-file install contract changed")
    for relative, fingerprint in expected.items():
        if not relative.startswith("game/tests/") or sha(root / relative) != fingerprint:
            raise ValueError("installed fixture changed: " + relative)


def install(batch):
    manifest = package_check()
    if godot_processes(): raise ValueError("engine lane busy; install refused before source mutation")
    out = batch_path(batch); out.mkdir(parents=True, exist_ok=False)
    expected = manifest["install"]
    original = {}
    # Inspect every target before changing any target. Refuse unknown existing bytes.
    for relative, fingerprint in expected.items():
        target = ROOT / relative
        original[relative] = sha(target) if target.is_file() else None
        if target.exists() and original[relative] != fingerprint: raise ValueError("existing test not owned: " + relative)
    state = {"status": "INSTALL_STARTED", "at_utc": utc(), "original": original, "installed": expected,
             "production_owner_sha256": sha(ROOT / OWNER), "package_sha256": sha(HERE / "package.json")}
    dump(out / "install.json", state)
    for relative in expected:
        source = SEALED / "proposed" / relative
        target = ROOT / relative; target.parent.mkdir(parents=True, exist_ok=True)
        if original[relative] is not None:
            saved = out / "preinstall" / relative; saved.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(target, saved)
        shutil.copy2(source, target)
    verify_install(ROOT, state, expected)
    rows = all_game_rows(); dump(out / "installed.all_game_files.json", rows)
    state.update(status="INSTALLED_ONLY_ENGINE_UNRUN", all_game_files_sha256=digest(rows), head_observed=git("rev-parse", "HEAD").decode().strip())
    dump(out / "install.json", state)
    return state


def restore_preinstall(root, out, state):
    # Explicit optional cleanup only. Resolve every target before the first mutation.
    tests_root = (root / "game/tests").resolve()
    for relative, fingerprint in state["installed"].items():
        target = (root / relative).resolve()
        if not target.is_relative_to(tests_root) or sha(target) != fingerprint:
            raise ValueError("refuse restore over changed/unowned test: " + relative)
        old = state["original"][relative]
        if old is not None and sha(out / "preinstall" / relative) != old:
            raise ValueError("preinstall backup changed: " + relative)
    for relative in state["installed"]:
        target = root / relative
        if state["original"][relative] is None: target.unlink()  # Exactly six named leaf candidates; no recursive removal.
        else: shutil.copy2(out / "preinstall" / relative, target)
    for relative, expected in state["original"].items():
        actual = sha(root / relative) if (root / relative).is_file() else None
        if actual != expected: raise ValueError("restoration verification failed: " + relative)


def child_engine_seen(samples, wrapper_pid):
    rows = {int(row["pid"]): row for sample in samples for row in sample["processes"]}
    for pid, row in rows.items():
        if row["executable"].lower() != ENGINE_NAME.lower(): continue
        cursor = pid
        for _ in range(8):
            parent = rows.get(cursor, {}).get("parent_pid")
            if parent == wrapper_pid: return True
            if parent is None or parent == cursor: break
            cursor = parent
    return False


def clean_environment(environ, mode, profile):
    env = dict(environ)
    cleared = sorted(key for key in env if key.startswith(("SURFACE_", "ENCROACH_", "LIVING_", "SCHEDULE_", "DAYNIGHT_", "REALITY_TIME", "PERF_"))
                     or key in {"SURFACE", "ENCROACH", "LIVING", "SCHEDULE", "DAYNIGHT", "ORISON_BUILDING_ROOT", "SHOT_DIR", "CAMPAIGN_TIME_FREEZE", "VULKAN_PAIRING_CASE", "APPDATA"})
    for key in cleared: env.pop(key)
    env.update(APPDATA=str(profile), ENCROACH_SWEEP_VARIANT=mode, CAMPAIGN_TIME_FREEZE="1")
    return env, cleared


def artifact_errors(out, result):
    mandatory = {"godot.stdout.log", "godot.stdout.log.stderr", "runner.stdout.log", "runner.stderr.log",
                 "shots/equivalence.json", "command.json", "invocation.json", "run_config.json", "process_observations.json", "prelaunch_processes.json",
                 "before.all_game_files.json", "after.all_game_files.json", "before.runtime_text.json", "after.runtime_text.json",
                 "before.game.diff", "after.game.diff"}
    mandatory.update("instruments/" + name for name in result["before"]["instruments"])
    for label in ("before", "after"):
        mandatory.update(label + "/source/" + relative for relative in result[label]["copied_sources"])
    if not mandatory.issubset(result.get("artifacts", {})): return ["required_artifact_entry_missing"]
    for relative, fingerprint in result["artifacts"].items():
        path = (out / relative).resolve()
        if not path.is_relative_to(out.resolve()) or not path.is_file() or sha(path) != fingerprint:
            return ["artifact_missing_or_changed:" + relative]
    for label in ("before", "after"):
        rows = json.loads((out / (label + ".all_game_files.json")).read_text())
        runtime = json.loads((out / (label + ".runtime_text.json")).read_text())
        if digest(rows) != result[label]["all_game_files_sha256"] or digest(runtime) != result[label]["runtime_text_sha256"]:
            return ["recorded_source_manifest_digest_mismatch"]
        source_map = dict(rows)
        expected_copies = {**package_check()["install"], **package_check()["production_bindings"]}
        if result[label]["copied_sources"] != expected_copies:
            return ["copied_source_contract_changed"]
        for relative, fingerprint in result[label]["copied_sources"].items():
            if source_map.get(relative) != fingerprint or sha(out / label / "source" / relative) != fingerprint:
                return ["copied_source_does_not_match_manifest"]
    return []


def prior_runs(out, phase, install_state):
    receipts = []
    for prior in ORDER[:ORDER.index(phase)]:
        path = out / "runs" / MODES[prior][1] / "result.json"
        result = json.loads(path.read_text(encoding="utf-8"))
        if result["phase"] != prior or result["assessment"]["control_acceptance_exit"] != 0 \
                or result["before"]["all_game_files_sha256"] != install_state["all_game_files_sha256"] \
                or result["before"] != result["after"] or artifact_errors(path.parent, result):
            raise ValueError("prior phase is incomplete, red outside declared control, or changed: " + prior)
        scene = json.loads((path.parent / "shots/equivalence.json").read_text())
        read = lambda name: (path.parent / name).read_text(encoding="utf-8-sig", errors="replace")
        rerun = assess.assess(scene, read("godot.stdout.log"), read("godot.stdout.log.stderr"),
            read("runner.stdout.log") + "\n" + read("runner.stderr.log"), result["actual_runner_exit"],
            result["source_unchanged"], result["pid_ancestry_verified"], result["engine_identity_verified"], MODES[prior][0])
        if rerun != result["assessment"]: raise ValueError("prior assessment cannot be reproduced: " + prior)
        receipts.append({"phase": prior, "path": str(path), "sha256": sha(path)})
    return receipts


def run(phase, batch):
    manifest = package_check(); out_batch = batch_path(batch)
    state = json.loads((out_batch / "install.json").read_text(encoding="utf-8"))
    verify_install(ROOT, state, manifest["install"])
    if state["package_sha256"] != sha(HERE / "package.json"): raise ValueError("install binds another package")
    priors = prior_runs(out_batch, phase, state)
    mode, name = MODES[phase]; out = out_batch / "runs" / name
    out.mkdir(parents=True, exist_ok=False)
    profile = out / "APPDATA"; profile.mkdir(); shots = out / "shots"; shots.mkdir()
    parameters = {"ProjectPath": str(ROOT / "game"), "Scene": "res://tests/EncroachmentSweepEquivalenceTest.tscn",
                  "LogPath": str(out / "godot.stdout.log"), "ShotDir": str(shots), "TimeoutSeconds": 60, "ExtraArgs": ["--verbose"]}
    dump(out / "invocation.json", {"runner": str(RUNNER), "parameters": parameters})
    command = [str(PWSH), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(BRIDGE), "-InvocationPath", str(out / "invocation.json")]
    dump(out / "command.json", command)
    env, cleared = clean_environment(os.environ, mode, profile)
    (out / "instruments").mkdir()
    for name, path in instrument_paths().items(): shutil.copy2(path, out / "instruments" / name)
    before = snapshot(out, "before")
    if before["all_game_files_sha256"] != state["all_game_files_sha256"] or before["head_observed"] != state["head_observed"]:
        raise ValueError("game or HEAD changed since exact six-file install; no engine launched")
    expected_engines = manifest["engine_sha256"]
    if sorted(row["sha256"] for row in before["engine_binaries"]) != sorted(expected_engines):
        raise ValueError("installed engine changed; no engine launched")
    config = {"schema": "astra.encroachment-equivalence.run.v1", "phase": phase, "variant": mode,
              "started_utc": utc(), "command": command, "parameters": parameters, "before": before,
              "expected_native_exit": 0 if mode == "candidate" else 1, "expected_diagnostic_gate_exit": 0 if mode == "candidate" else 1,
              "expected_control_acceptance_exit": 0, "expected_checks": 171, "prior_results": priors,
              "selected_copy_sha256": manifest["install"]["game/tests/fixtures/encroachment_sweep/" + mode + ".gd"],
              "fresh_APPDATA": str(profile), "profile_existed_before_run": False, "cleared_environment_keys": cleared,
              "explicit_environment": {key: env[key] for key in ("APPDATA", "ENCROACH_SWEEP_VARIANT", "CAMPAIGN_TIME_FREEZE")},
              "scope": "Headless synthetic actual-method/material equivalence only; no composed building, callback, visual or performance acceptance."}
    dump(out / "run_config.json", config)
    observations = []; census = godot_processes(); dump(out / "prelaunch_processes.json", census)
    started = time.perf_counter()
    with (out / "runner.stdout.log").open("wb") as stdout, (out / "runner.stderr.log").open("wb") as stderr:
        # Canonical runner independently refuses any occupied engine lane.
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr)
        while process.poll() is None:
            rows = godot_processes()
            if rows and (not observations or rows != observations[-1]["processes"]):
                observations.append({"elapsed_seconds": time.perf_counter() - started, "processes": rows})
                dump(out / "process_observations.json", observations)
            time.sleep(0.05)
    elapsed = time.perf_counter() - started
    dump(out / "process_observations.json", observations)
    after = snapshot(out, "after")
    read = lambda name: (out / name).read_text(encoding="utf-8-sig", errors="replace") if (out / name).is_file() else ""
    probe = None; receipt_error = None
    try: probe = json.loads(read("shots/equivalence.json"))
    except (ValueError, OSError) as error: receipt_error = str(error)
    stable = before == after
    pid_ok = child_engine_seen(observations, process.pid)
    engine_ok = EXPECTED_ENGINE in read("godot.stdout.log") and len(before["engine_binaries"]) == 2
    assessment = assess.assess(probe, read("godot.stdout.log"), read("godot.stdout.log.stderr"),
        read("runner.stdout.log") + "\n" + read("runner.stderr.log"), process.returncode, stable, pid_ok, engine_ok, mode)
    result = {**config, "finished_utc": utc(), "after": after, "actual_runner_exit": process.returncode,
              "runner_pid": process.pid, "elapsed_serial_process_seconds": elapsed,
              "source_unchanged": stable, "pid_ancestry_verified": pid_ok, "engine_identity_verified": engine_ok,
              "receipt_read_error": receipt_error, "assessment": assessment,
              "artifacts": {p.relative_to(out).as_posix(): sha(p) for p in sorted(out.rglob("*"))
                            if p.is_file() and "APPDATA" not in p.relative_to(out).parts}}
    errors = artifact_errors(out, result)
    if errors:
        assessment["reasons"] += errors; assessment["control_acceptance_exit"] = 1; assessment["diagnostic_gate_exit"] = 1
    dump(out / "result.json", result)
    print(json.dumps({"phase": phase, "receipt": str(out / "result.json"), **assessment}), flush=True)
    return assessment["control_acceptance_exit"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["plan", "install", *ORDER, "restore-preinstall"])
    parser.add_argument("batch", nargs="?", default="ownership_2a440_01")
    args = parser.parse_args()
    if args.action == "plan":
        manifest = package_check()
        print(json.dumps({"install": manifest["install"], "commands": manifest["commands"], "engine_run": False}, indent=2)); return 0
    if args.action == "install": install(args.batch); return 0
    if args.action == "restore-preinstall":
        package_check()
        if godot_processes(): raise ValueError("engine lane busy; restoration refused")
        out = batch_path(args.batch); state = json.loads((out / "install.json").read_text())
        receipt = out / "restoration.json"
        if receipt.exists(): raise ValueError("restoration receipt already exists")
        verify_install(ROOT, state, package_check()["install"])
        restore_preinstall(ROOT, out, state)
        dump(receipt, {"status": "EXACT_PREINSTALL_TEST_STATE_RESTORED", "at_utc": utc(), "original": state["original"]}); return 0
    return run(args.action, args.batch)


if __name__ == "__main__": raise SystemExit(main())
