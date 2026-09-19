"""Explicit terminal-only phases. The copied core is imported for utilities only."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import time
import assess
import core

HERE = Path(__file__).resolve().parent
BASE = HERE.parent
ROOT = BASE.parents[3]
EVIDENCE = ROOT / "design/astra/evidence/v2_terminal_access"
OWNERS = ["game/scripts/building/orison_v2_runtime_root.gd", "game/scripts/call/desk_zone.gd"]
core.HERE = HERE
core.ROOT = ROOT
core.RUNNER = ROOT / "tools/run_godot_serial.ps1"
core.BRIDGE = HERE / "runner_bridge.ps1"
_instruments = core.instrument_paths
core.instrument_paths = lambda: {**_instruments(), "terminal_preparation.json": BASE / "preparation.json"}
sha, dump = core.sha, core.dump


def package():
    plan = json.loads((BASE / "preparation.json").read_text(encoding="utf-8"))
    manifest = json.loads((HERE / "package.json").read_text(encoding="utf-8"))
    if sha(BASE / "preparation.json") != manifest["parent_preparation_sha256"]: raise ValueError("parent preparation changed")
    for rel, value in manifest["files"].items():
        if sha(HERE / rel) != value: raise ValueError("runtime instrument changed: " + rel)
    for rel, value in plan["files_sha256"].items():
        if sha(BASE / rel) != value: raise ValueError("prepared input changed: " + rel)
    for rel, value in plan["source_bindings_sha256"].items():
        if rel not in OWNERS and sha(ROOT / rel) != value: raise ValueError("unowned dependency changed: " + rel)
    return plan, manifest


def owner_sources(plan, phase):
    row = next(x for x in plan["sequence"] if x["run_name"] == phase)
    return row, {OWNERS[0]: BASE / row["root_source"], OWNERS[1]: BASE / row["desk_source"]}


def install():
    plan, manifest = package()
    if core.git("rev-parse", "HEAD").decode().strip() != plan["required_install_head"]: raise ValueError("reviewed execution HEAD differs")
    if core.godot_processes(): raise ValueError("lane busy before installation")
    for rel in OWNERS:
        if sha(ROOT / rel) != plan["source_bindings_sha256"][rel]: raise ValueError("original production bytes required")
    for rel in manifest["install"]:
        if (ROOT / rel).exists(): raise ValueError("new fixture target already exists: " + rel)
    EVIDENCE.mkdir(parents=True, exist_ok=False)
    for rel in OWNERS:
        target = EVIDENCE / "preinstall" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
    for rel in manifest["install"]:
        shutil.copy2(BASE / "proposed" / rel, ROOT / rel)
    rows = dict(core.all_game_rows())
    dump(EVIDENCE / "install.json", {"status": "ONLY_TWO_NEW_FIXTURES_INSTALLED_ORIGINAL_PRODUCTION", "head": core.git("rev-parse", "HEAD").decode().strip(), "files": rows, "package_sha256": sha(HERE / "package.json")})


def verify_artifacts(out, result):
    mandatory = {"godot.stdout.log", "godot.stdout.log.stderr", "runner.stdout.log", "runner.stderr.log", "shots/terminal_access.json", "command.json", "invocation.json", "run_config.json", "process_observations.json", "prelaunch_processes.json", "before.all_game_files.json", "after.all_game_files.json", "before.runtime_text.json", "after.runtime_text.json", "before.game.diff", "after.game.diff"}
    plan, manifest = package()
    _, desired = owner_sources(plan, result["phase"])
    copied_expected = {**manifest["production_bindings"], **manifest["install"], **{rel:sha(path) for rel,path in desired.items()}}
    for label in ("before", "after"):
        if result[label]["copied_sources"] != copied_expected: raise ValueError("copied source contract differs from phase")
        source_map = dict(json.loads((out / (label + ".all_game_files.json")).read_text()))
        if any(source_map.get(rel) != value or sha(out / label / "source" / rel) != value for rel,value in copied_expected.items()): raise ValueError("copied source differs from full manifest")
        mandatory.update(label + "/source/" + rel for rel in result[label]["copied_sources"])
        for suffix, field in (("all_game_files", "all_game_files_sha256"), ("runtime_text", "runtime_text_sha256")):
            if core.digest(json.loads((out / (label + "." + suffix + ".json")).read_text())) != result[label][field]: raise ValueError("source manifest digest changed")
    mandatory.update("instruments/" + name for name in result["before"]["instruments"])
    actual = {p.relative_to(out).as_posix() for p in out.rglob("*") if p.is_file() and "APPDATA" not in p.relative_to(out).parts and p.name != "result.json"}
    if not mandatory.issubset(result["artifacts"]) or actual != set(result["artifacts"]): raise ValueError("raw artifact map incomplete")
    for rel, value in result["artifacts"].items():
        path = (out / rel).resolve()
        if not path.is_relative_to(out.resolve()) or sha(path) != value: raise ValueError("raw artifact changed: " + rel)


def parameters_for(out, plan):
    return {"ProjectPath": str(ROOT / "game"), "Scene": plan["scene"], "LogPath": str(out / "godot.stdout.log"), "ShotDir": str(out / "shots"), "TimeoutSeconds": 60, "Windowed": True, "ExtraArgs": ["--verbose", "--audio-driver", "Dummy", "--resolution", "1280x720", "--rendering-method", "forward_plus", "--rendering-driver", "vulkan"]}


def require_prepared_request(request, out, plan):
    if request != {"runner": str(core.RUNNER), "parameters": parameters_for(out, plan)}:
        raise ValueError("actual runner request differs from prepared request")


def require_restoration(receipt, expected):
    if receipt.get("status") != "EXACT_OWNED_SOURCES_RESTORED" or receipt.get("process_census") != [] or receipt.get("hashes") != expected:
        raise ValueError("prior exact restoration proof missing or failed")


def run_installed(phase, plan, manifest, state, desired):
    out = EVIDENCE / "runs" / phase
    out.mkdir(parents=True, exist_ok=False)
    profile, shots = out / "APPDATA", out / "shots"
    profile.mkdir(); shots.mkdir()
    parameters = parameters_for(out, plan)
    phase_spec = next(row for row in plan["sequence"] if row["run_name"] == phase)
    prepared_request = json.loads((BASE / phase_spec["request"]).read_text())
    require_prepared_request(prepared_request, out, plan)
    dump(out / "invocation.json", prepared_request)
    command = [str(core.PWSH), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(core.BRIDGE), "-InvocationPath", str(out / "invocation.json")]
    dump(out / "command.json", command)
    env, removed = core.clean_environment(os.environ, "candidate", profile)
    env.pop("ENCROACH_SWEEP_VARIANT", None)
    env.pop("ORISON_TITLE_DEBUG", None)
    env.update(ORISON_BUILDING_ROOT="v2", WEATHER_SEED="19281110", TITLE_SCREEN_SILENT="1")
    (out / "instruments").mkdir()
    for name, path in core.instrument_paths().items(): shutil.copy2(path, out / "instruments" / name)
    before = core.snapshot(out, "before")
    wanted = {**state["files"], **{rel: sha(path) for rel,path in desired.items()}}
    if before["all_game_files_sha256"] != core.digest(sorted(wanted.items())): raise ValueError("unrelated game mutation before launch")
    if sorted(x["sha256"] for x in before["engine_binaries"]) != manifest["engine_sha256"]: raise ValueError("installed engine differs from reviewed engine")
    prelaunch = core.godot_processes(); dump(out / "prelaunch_processes.json", prelaunch)
    if prelaunch: raise ValueError("lane busy at final prelaunch")
    config = {"schema": "astra.v2-terminal-access.run.v1", "phase": phase, "before": before, "started_at_utc": core.utc(), "fresh_APPDATA": str(profile), "cleared_environment_keys": removed, "parameters": parameters, "package_sha256": sha(HERE / "package.json")}
    dump(out / "run_config.json", config)
    samples = []; started = time.perf_counter()
    with (out / "runner.stdout.log").open("wb") as stdout, (out / "runner.stderr.log").open("wb") as stderr:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr)
        while process.poll() is None:
            rows = core.godot_processes()
            if rows and (not samples or samples[-1]["processes"] != rows): samples.append({"elapsed_seconds": time.perf_counter()-started, "processes": rows})
            time.sleep(0.05)
    serial_elapsed = time.perf_counter()-started
    dump(out / "process_observations.json", samples)
    after = core.snapshot(out, "after")
    read = lambda rel: (out / rel).read_text(encoding="utf-8-sig", errors="replace") if (out / rel).is_file() else ""
    try: probe = json.loads(read("shots/terminal_access.json"))
    except (ValueError, OSError): probe = None
    census_rows = {int(row["pid"]): row for sample in samples for row in sample["processes"]}
    child = (probe or {}).get("pid")
    pid_ok = census_rows.get(child, {}).get("executable", "").lower() == core.ENGINE_NAME.lower()
    cursor = child
    for _ in range(8):
        cursor = census_rows.get(cursor, {}).get("parent_pid")
        if cursor == process.pid: break
    pid_ok = pid_ok and cursor == process.pid
    verdict = assess.assess(probe, read("godot.stdout.log"), read("godot.stdout.log.stderr"), read("runner.stdout.log") + "\n" + read("runner.stderr.log"), process.returncode, before == after, pid_ok, before["engine_binaries"] == after["engine_binaries"], phase)
    result = {**config, "after": after, "actual_runner_exit": process.returncode, "serial_process_seconds": serial_elapsed, "source_unchanged": before == after, "pid_ancestry_verified": pid_ok, "assessment": verdict, "artifacts": {p.relative_to(out).as_posix(): sha(p) for p in out.rglob("*") if p.is_file() and "APPDATA" not in p.relative_to(out).parts}}
    try: verify_artifacts(out, result)
    except (ValueError, OSError) as error:
        verdict["reasons"].append(str(error)); verdict["diagnostic_gate_exit"] = 1; verdict["control_contract_exit"] = 1
    dump(out / "result.json", result)
    print(json.dumps({"phase": phase, "actual_runner_exit": process.returncode, "assessment": verdict, "receipt": str(out / "result.json")}), flush=True)
    return verdict["control_contract_exit"]


def phase_run(phase):
    plan, manifest = package()
    state = json.loads((EVIDENCE / "install.json").read_text())
    if state["package_sha256"] != sha(HERE / "package.json") or state["head"] != core.git("rev-parse", "HEAD").decode().strip(): raise ValueError("install package or HEAD changed")
    order = [x["run_name"] for x in plan["sequence"]]; index = order.index(phase)
    for prior in order[:index]:
        out = EVIDENCE / "runs" / prior
        result = json.loads((out / "result.json").read_text())
        verify_artifacts(out, result)
        if result["assessment"]["control_contract_exit"] != 0: raise ValueError("prior run requires review")
        read = lambda rel: (out / rel).read_text(encoding="utf-8-sig", errors="replace")
        probe = json.loads(read("shots/terminal_access.json"))
        reproduced = assess.assess(probe, read("godot.stdout.log"), read("godot.stdout.log.stderr"), read("runner.stdout.log") + "\n" + read("runner.stderr.log"), result["actual_runner_exit"], result["before"] == result["after"], result["pid_ancestry_verified"], result["before"]["engine_binaries"] == result["after"]["engine_binaries"], prior)
        if reproduced != result["assessment"]: raise ValueError("prior assessment was altered or cannot be reproduced")
        restored = json.loads((EVIDENCE / (prior + ".restoration.json")).read_text())
        _, restored_sources = owner_sources(plan, restored.get("target_phase", ""))
        require_restoration(restored, {rel:sha(path) for rel,path in restored_sources.items()})
    if core.godot_processes(): raise ValueError("lane busy before source transition")
    previous = "01_original" if index < 2 else "02_candidate"
    _, previous_sources = owner_sources(plan, previous)
    wanted = {**state["files"], **{rel:sha(path) for rel,path in previous_sources.items()}}
    if dict(core.all_game_rows()) != wanted: raise ValueError("unexpected source before phase")
    _, desired = owner_sources(plan, phase)
    for rel,path in desired.items(): shutil.copy2(path, ROOT / rel)
    verdict = 1
    try:
        verdict = run_installed(phase, plan, manifest, state, desired)
        return verdict
    finally:
        processes = core.godot_processes()
        restoration = {"phase": phase, "process_census": processes, "status": "UNCHANGED"}
        if processes:
            restoration["status"] = "RESTORATION_REFUSED_ACTIVE_PROCESS"
        else:
            target_phase = "02_candidate" if "omission" in phase or (verdict == 0 and index > 0) else "01_original"
            _, restored = owner_sources(plan, target_phase)
            if any(sha(ROOT/rel) != sha(path) for rel,path in desired.items()): raise ValueError("refuse to overwrite unexpected owned-source edit")
            for rel,path in restored.items(): shutil.copy2(path, ROOT/rel)
            restoration.update(status="EXACT_OWNED_SOURCES_RESTORED", target_phase=target_phase, hashes={rel:sha(ROOT/rel) for rel in OWNERS})
        dump(EVIDENCE / (phase + ".restoration.json"), restoration)
        if processes: raise ValueError("active Godot process remains; source restoration refused")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["install", *[row["run_name"] for row in assess.PLAN["sequence"]]])
    args = parser.parse_args()
    if args.phase == "install": install()
    else: raise SystemExit(phase_run(args.phase))
