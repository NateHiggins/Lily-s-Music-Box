"""Reservation phases and the unchanged terminal regression. The copied core is imported for utilities only."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import time
import tempfile
import assess
import core

HERE = Path(__file__).resolve().parent
BASE = HERE.parent
ROOT = BASE.parents[3]
EVIDENCE = ROOT / "design/astra/evidence/v2_reservation_display_03"
OWNERS = ["game/scripts/building/orison_v2_blockout.gd", "game/scripts/building/orison_v2_runtime_root.gd"]
core.HERE = HERE
core.ROOT = ROOT
core.RUNNER = ROOT / "tools/run_godot_serial.ps1"
core.BRIDGE = HERE / "runner_bridge.ps1"
_instruments = core.instrument_paths
core.instrument_paths = lambda: {**_instruments(), "reservation_preparation.json": BASE / "preparation.json",
    "terminal_39_preparation.json": BASE.with_name("v2_terminal_access_arrival_02") / "preparation.json"}
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
    return row, {rel:BASE/path for rel,path in row["sources"].items()}


def install():
    plan, manifest = package()
    if core.git("rev-parse", "HEAD").decode().strip() != plan["required_install_head"]: raise ValueError("reviewed execution HEAD differs")
    if core.godot_processes(): raise ValueError("lane busy before installation")
    for rel in OWNERS:
        if sha(ROOT / rel) != plan["source_bindings_sha256"][rel]: raise ValueError("original reservation / accepted terminal bytes required")
    for rel in manifest["install"]:
        if sha(ROOT/rel) != manifest["replace_existing_install"][rel]: raise ValueError("runtime02 exact installed fixture required")
    EVIDENCE.mkdir(parents=True, exist_ok=False)
    for rel in OWNERS:
        target = EVIDENCE / "preinstall" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        if sha(target) != plan["source_bindings_sha256"][rel]: raise ValueError("preinstall backup hash mismatch")
    replace_fixtures(manifest)
    rows = dict(core.all_game_rows())
    dump(EVIDENCE / "install.json", {"status": "EXACT_RUNTIME02_FIXTURES_BACKED_UP_AND_REVISED_PRODUCTION_UNCHANGED", "head": core.git("rev-parse", "HEAD").decode().strip(), "files": rows, "fixture_replacement_receipt_sha256":sha(EVIDENCE/"fixture_replacement.json"), "package_sha256": sha(HERE / "package.json")})


def replace_fixtures(manifest):
    prior = manifest["replace_existing_install"]
    desired = manifest["install"]
    receipt = {"status":"PREPARING", "prior_sha256":prior, "desired_sha256":desired, "copied_paths":[]}
    succeeded = False
    backups = {}
    try:
        if set(prior) != set(desired): raise ValueError("fixture replacement path set differs")
        for rel,value in prior.items():
            if sha(ROOT/rel) != value: raise ValueError("fixture changed before backup")
            backup = EVIDENCE/"preinstall_fixtures"/rel
            backup.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(ROOT/rel,backup)
            if sha(backup) != value: raise ValueError("fixture backup changed")
            backups[rel] = backup
        for rel,value in desired.items():
            if core.godot_processes(): raise ValueError("active engine during fixture replacement")
            if sha(ROOT/rel) != prior[rel] or sha(BASE/"proposed"/rel) != value: raise ValueError("fixture source changed")
            atomic_owner_copy(BASE/"proposed"/rel,ROOT/rel)
            if sha(ROOT/rel) != value: raise ValueError("fixture install hash mismatch")
            receipt["copied_paths"].append(rel)
        succeeded = True
        receipt["status"] = "EXACT_FIXTURES_INSTALLED"
    except BaseException as error:
        receipt["failure"] = {"type":type(error).__name__,"message":str(error)}
        raise
    finally:
        try:
            if not succeeded:
                receipt["rollback_processes"] = core.godot_processes()
                if receipt["rollback_processes"]: raise ValueError("fixture rollback refused active engine")
                for rel in prior:
                    current = sha(ROOT/rel)
                    if current == prior[rel]: continue
                    if current != desired[rel] or rel not in backups or sha(backups[rel]) != prior[rel]: raise ValueError("fixture rollback refused unexpected bytes")
                    atomic_owner_copy(backups[rel],ROOT/rel)
                    if sha(ROOT/rel) != prior[rel]: raise ValueError("fixture rollback hash mismatch")
                if {rel:sha(ROOT/rel) for rel in prior} != prior: raise ValueError("not all prior fixture bytes restored")
                receipt["status"] = "FAILED_INSTALL_EXACT_PRIOR_FIXTURES_RESTORED"
        except BaseException as error:
            receipt["status"] = "FIXTURE_ROLLBACK_REFUSED_OR_FAILED"
            receipt["rollback_failure"] = {"type":type(error).__name__,"message":str(error)}
            raise
        finally:
            receipt["observed_hashes"] = {}
            for rel in prior:
                try: receipt["observed_hashes"][rel] = sha(ROOT/rel)
                except OSError as error: receipt["observed_hashes"][rel] = {"read_error":str(error)}
            dump(EVIDENCE/"fixture_replacement.json",receipt)


def verify_artifacts(out, result):
    mandatory = {"godot.stdout.log", "godot.stdout.log.stderr", "runner.stdout.log", "runner.stderr.log", "command.json", "invocation.json", "run_config.json", "process_observations.json", "prelaunch_processes.json", "before.all_game_files.json", "after.all_game_files.json", "before.runtime_text.json", "after.runtime_text.json", "before.game.diff", "after.game.diff"}
    plan, manifest = package()
    spec, desired = owner_sources(plan, result["phase"])
    mandatory.add("shots/"+spec["receipt_name"])
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
    spec = next(row for row in plan["sequence"] if row["run_name"] == out.name)
    return {"ProjectPath": str(ROOT / "game"), "Scene": spec["scene"], "LogPath": str(out / "godot.stdout.log"), "ShotDir": str(out / "shots"), "TimeoutSeconds": 180, "Windowed": True, "ExtraArgs": ["--verbose", "--audio-driver", "Dummy", "--resolution", "1280x720", "--rendering-method", "forward_plus", "--rendering-driver", "vulkan"]}


def require_prepared_request(request, out, plan):
    if request != {"runner": str(core.RUNNER), "parameters": parameters_for(out, plan)}:
        raise ValueError("actual runner request differs from prepared request")


def require_restoration(receipt, expected):
    if (receipt.get("status") != "EXACT_OWNED_SOURCES_RESTORED" or receipt.get("process_census") != []
            or any(receipt.get(key) != expected for key in ("hashes", "expected_hashes", "restoration_input_hashes", "observed_final_hashes"))
            or sorted(receipt.get("restored_paths", [])) != sorted(expected)):
        raise ValueError("prior exact restoration proof missing or failed")


def classify_lane(samples, child, wrapper_pid):
    rows = {int(row["pid"]): row for sample in samples for row in sample["processes"]}
    def owned(pid):
        seen = set()
        while pid in rows and pid not in seen:
            seen.add(pid)
            pid = rows[pid].get("parent_pid")
            if pid == wrapper_pid: return True
        return False
    conflicts = []
    for sample in samples:
        for row in sample["processes"]:
            current = rows[int(row["pid"])]
            if (row.get("parent_pid"), row.get("executable")) != (current.get("parent_pid"), current.get("executable")):
                conflicts.append(row)
    foreign = [row for row in rows.values() if not owned(int(row["pid"]))]
    actual = rows.get(child, {}).get("executable", "").lower() == core.ENGINE_NAME.lower() and owned(child)
    return {"actual_child_ancestry_verified": actual, "owned_pids": sorted(pid for pid in rows if owned(pid)),
        "foreign_processes": foreign, "conflicting_pid_observations": conflicts,
        "lane_contract_exit": int(bool(foreign or conflicts)), "exclusive_performance_claim": False,
        "scope": "Sampled Windows Godot-name census only; Linux/container engines require separate root admission. Foreign overlap stops progression independently of functional results."}


def atomic_owner_copy(source, target):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=target.name + ".astra-", suffix=".tmp", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(source.read_bytes())
        if sha(temporary) != sha(source): raise ValueError("atomic source copy mismatch")
        os.replace(temporary, target)
    finally:
        if temporary is not None and temporary.exists(): temporary.unlink()


def transition_and_run(phase, desired, pre_hashes, success_restore, failure_restore, action):
    receipt_path = EVIDENCE / (phase + ".restoration.json")
    if receipt_path.exists(): raise ValueError("historical restoration receipt already exists")
    desired_hashes = {rel:sha(path) for rel,path in desired.items()}
    restoration = {"phase": phase, "status": "TRANSITION_NOT_COMPLETED", "pre_transition_hashes": pre_hashes,
        "desired_hashes": desired_hashes, "copied_paths": [], "restored_paths": []}
    verdict = 1
    try:
        if set(desired) != set(OWNERS) or set(pre_hashes) != set(OWNERS): raise ValueError("owned transition path set mismatch")
        if core.godot_processes(): raise ValueError("lane busy before protected source transition")
        if {rel:sha(ROOT/rel) for rel in OWNERS} != pre_hashes: raise ValueError("source changed before protected transition")
        for rel,path in desired.items():
            if sha(ROOT/rel) != pre_hashes[rel]: raise ValueError("source changed during transition")
            atomic_owner_copy(path, ROOT/rel)
            if sha(ROOT/rel) != desired_hashes[rel]: raise ValueError("installed owner hash mismatch")
            restoration["copied_paths"].append(rel)
        verdict = action()
        return verdict
    except BaseException as error:
        restoration["execution_failure"] = {"type": type(error).__name__, "message": str(error)}
        raise
    finally:
        try:
            processes = core.godot_processes()
            restoration["process_census"] = processes
            if processes:
                restoration["status"] = "RESTORATION_REFUSED_ACTIVE_PROCESS"
                raise ValueError("active Godot process remains; source restoration refused")
            target_phase, restored, expected = success_restore if verdict == 0 else failure_restore
            restoration.update(target_phase=target_phase, expected_hashes=expected,
                restoration_input_hashes={rel:sha(path) for rel,path in restored.items()})
            if set(restored) != set(OWNERS) or restoration["restoration_input_hashes"] != expected:
                restoration["status"] = "RESTORATION_REFUSED_INVALID_BOUND_INPUT"
                raise ValueError("restoration source bytes differ from sealed expectations")
            current = {rel:sha(ROOT/rel) for rel in OWNERS}
            if any(value not in (pre_hashes[rel], desired_hashes[rel]) for rel,value in current.items()):
                restoration["status"] = "RESTORATION_REFUSED_UNEXPECTED_OWNED_EDIT"
                raise ValueError("refuse to overwrite unexpected owned-source edit")
            for rel,path in restored.items():
                if sha(ROOT/rel) != current[rel]: raise ValueError("owned source changed during restoration")
                atomic_owner_copy(path, ROOT/rel)
                if sha(ROOT/rel) != expected[rel]: raise ValueError("restored hash differs from bound expectation")
                restoration["restored_paths"].append(rel)
            restoration["hashes"] = {rel:sha(ROOT/rel) for rel in OWNERS}
            restoration["status"] = "EXACT_OWNED_SOURCES_RESTORED"
        except BaseException as error:
            if not restoration["status"].startswith("RESTORATION_REFUSED"):
                restoration["status"] = "RESTORATION_FAILED"
            restoration["restoration_failure"] = {"type": type(error).__name__, "message": str(error)}
            raise
        finally:
            observed = {}
            for rel in OWNERS:
                try: observed[rel] = sha(ROOT/rel) if (ROOT/rel).is_file() else None
                except OSError as error: observed[rel] = {"read_error": str(error)}
            restoration["observed_final_hashes"] = observed
            dump(receipt_path, restoration)


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
    config = {"schema": "astra.v2-reservation-display.run.v1", "phase": phase, "before": before, "started_at_utc": core.utc(), "fresh_APPDATA": str(profile), "cleared_environment_keys": removed, "parameters": parameters, "package_sha256": sha(HERE / "package.json")}
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
    try: probe = json.loads(read("shots/"+phase_spec["receipt_name"]))
    except (ValueError, OSError): probe = None
    child = (probe or {}).get("pid")
    lane_contract = classify_lane(samples, child, process.pid)
    pid_ok = lane_contract["actual_child_ancestry_verified"]
    verdict = assess.assess(probe, read("godot.stdout.log"), read("godot.stdout.log.stderr"), read("runner.stdout.log") + "\n" + read("runner.stderr.log"), process.returncode, before == after, pid_ok, before["engine_binaries"] == after["engine_binaries"], phase)
    result = {**config, "after": after, "actual_runner_exit": process.returncode, "wrapper_pid": process.pid,
        "lane_contract": lane_contract, "serial_process_seconds": serial_elapsed, "source_unchanged": before == after, "pid_ancestry_verified": pid_ok, "assessment": verdict, "artifacts": {p.relative_to(out).as_posix(): sha(p) for p in out.rglob("*") if p.is_file() and "APPDATA" not in p.relative_to(out).parts}}
    try: verify_artifacts(out, result)
    except (ValueError, OSError) as error:
        verdict["reasons"].append(str(error)); verdict["diagnostic_gate_exit"] = 1; verdict["control_contract_exit"] = 1
    dump(out / "result.json", result)
    print(json.dumps({"phase": phase, "actual_runner_exit": process.returncode, "assessment": verdict, "lane_contract": lane_contract, "receipt": str(out / "result.json")}), flush=True)
    return max(verdict["control_contract_exit"], lane_contract["lane_contract_exit"])


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
        prior_spec = next(row for row in plan["sequence"] if row["run_name"] == prior)
        probe = json.loads(read("shots/"+prior_spec["receipt_name"]))
        lane_contract = classify_lane(json.loads(read("process_observations.json")), probe.get("pid"), result["wrapper_pid"])
        if lane_contract != result.get("lane_contract") or lane_contract["lane_contract_exit"] != 0: raise ValueError("prior sampled engine overlap requires review")
        reproduced = assess.assess(probe, read("godot.stdout.log"), read("godot.stdout.log.stderr"), read("runner.stdout.log") + "\n" + read("runner.stderr.log"), result["actual_runner_exit"], result["before"] == result["after"], result["pid_ancestry_verified"], result["before"]["engine_binaries"] == result["after"]["engine_binaries"], prior)
        if reproduced != result["assessment"]: raise ValueError("prior assessment was altered or cannot be reproduced")
        restored = json.loads((EVIDENCE / (prior + ".restoration.json")).read_text())
        _, restored_sources = owner_sources(plan, restored.get("target_phase", ""))
        require_restoration(restored, {rel:sha(path) for rel,path in restored_sources.items()})
    if core.godot_processes(): raise ValueError("lane busy before source transition")
    _, candidate_sources = owner_sources(plan, "01_candidate")
    wanted = state["files"] if index == 0 else {**state["files"], **{rel:sha(path) for rel,path in candidate_sources.items()}}
    if dict(core.all_game_rows()) != wanted: raise ValueError("unexpected source before phase")
    _, desired = owner_sources(plan, phase)
    candidate_restore = ("01_candidate", candidate_sources, {rel:sha(path) for rel,path in candidate_sources.items()})
    failure_restore = candidate_restore if index > 0 else ("preinstall", {rel:EVIDENCE/"preinstall"/rel for rel in OWNERS}, {rel:plan["source_bindings_sha256"][rel] for rel in OWNERS})
    return transition_and_run(phase, desired, {rel:wanted[rel] for rel in OWNERS}, candidate_restore, failure_restore,
        lambda: run_installed(phase, plan, manifest, state, desired))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["install", *[row["run_name"] for row in assess.PLAN["sequence"]]])
    args = parser.parse_args()
    if args.phase == "install": install()
    else: raise SystemExit(phase_run(args.phase))
