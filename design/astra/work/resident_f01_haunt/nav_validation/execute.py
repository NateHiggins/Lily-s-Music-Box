"""Prepared commands: five reviewed phases, no action without an explicit phase."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
import traceback

import assess
import run_case as runner

HERE, ROOT = runner.HERE, runner.ROOT
NAV = "game/scripts/characters/resident_nav.gd"
ROUTINES = "game/scripts/characters/resident_routines.gd"
LIVE_INPUTS = {
    "game/tests/resident_nav_direct_segment_test.gd": "direct_test.gd",
    "game/tests/ResidentNavDirectSegmentTest.tscn": "direct_test.tscn",
    "game/tests/resident_f01_haunt_test.gd": "haunt_test.gd",
    "game/tests/ResidentF01HauntTest.tscn": "haunt_test.tscn",
    "game/tests/resident_lift_waiting_test.gd": "waiting_test.gd",
    "game/tests/ResidentLiftWaitingTest.tscn": "waiting_test.tscn",
    "game/tests/passage_nav_test.gd": "passage_test.gd",
    "game/tests/PassageNavTest.tscn": "passage_test.tscn",
}
PHASES = {
    "focused": [("01_original_focused", "direct", "old_direct"), ("02_candidate_focused", "direct", "green")],
    "lifecycle": [("03_candidate_lifecycle", "haunt", "green")],
    "nav-control": [("04_nav_call_omission_lifecycle", "haunt", "nav_omission"),
                    ("05_nav_restored_lifecycle", "haunt", "green")],
    "coordinate-control": [("06_coordinate_omission_lifecycle", "haunt", "coordinate_omission"),
                           ("07_coordinate_restored_lifecycle", "haunt", "green")],
    "regressions": [("08_waiting_regression", "waiting", "green"), ("09_passage_regression", "passage", "green")],
}
DEPENDENCY = {"lifecycle": "focused", "nav-control": "lifecycle",
              "coordinate-control": "nav-control", "regressions": "coordinate-control"}


def input_bytes(name):
    path = HERE / "inputs" / name
    if assess.sha(path) != assess.CONTRACT["inputs"][name]: raise ValueError("prepared input changed: " + name)
    return path.read_bytes()


def write_bound(relative, new_name, expected_name):
    path = (ROOT / relative).resolve()
    path.relative_to((ROOT / "game").resolve())
    if expected_name is None:
        if path.exists(): raise ValueError("new fixture already exists: " + relative)
    elif not path.is_file() or path.read_bytes() != input_bytes(expected_name):
        raise ValueError("live owner changed before mutation: " + relative)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(input_bytes(new_name))
    if path.read_bytes() != input_bytes(new_name): raise ValueError("write verification failed: " + relative)


def load_state(batch):
    return json.loads((runner.EVIDENCE / batch / "batch.json").read_text(encoding="utf-8"))


def check_live(batch, nav_name="nav_candidate.gd", routines_name="routines_candidate.gd"):
    state = load_state(batch)
    expected = dict(state["all_game_reference"])
    expected[NAV] = assess.CONTRACT["inputs"][nav_name]
    expected[ROUTINES] = assess.CONTRACT["inputs"][routines_name]
    if dict(runner.all_game_rows()) != expected: raise ValueError("batch runtime/assets/tests changed beyond exact planned source swap")
    if runner.support.parser_module.engine_binary_manifest() != state["engine_binaries"]:
        raise ValueError("installed engine changed between phases")
    runner.package_check()


def verified_result(batch, name):
    folder = runner.EVIDENCE / batch / "runs" / name
    result = assess.verify_artifacts(folder)
    state = load_state(batch)
    if result["before"]["engine_binaries"] != state["engine_binaries"]:
        raise ValueError("run engine differs from frozen batch")
    expected_map = dict(state["all_game_reference"])
    nav_name = "nav_original.gd" if result["expected"] == "old_direct" else "nav_call_omission.gd" if result["expected"] == "nav_omission" else "nav_candidate.gd"
    routines_name = "routines_original.gd" if result["expected"] == "coordinate_omission" else "routines_candidate.gd"
    expected_map[NAV] = assess.CONTRACT["inputs"][nav_name]
    expected_map[ROUTINES] = assess.CONTRACT["inputs"][routines_name]
    for label in ["before", "after"]:
        observed = dict(json.loads((folder / (label + ".all_game_files.json")).read_text(encoding="utf-8")))
        if observed != expected_map: raise ValueError("run source differs from exact planned batch variant")
    info = assess.MODES[result["mode"]]
    scene = json.loads((folder / "shots" / info["json"]).read_text(encoding="utf-8")) if info["json"] else None
    read = lambda name: (folder / name).read_text(encoding="utf-8-sig")
    recalculated = assess.assess(result["mode"], result["expected"], scene,
        read("godot.stdout.log"), read("godot.stdout.log.stderr"),
        read("runner.stdout.log") + "\n" + read("runner.stderr.log"), result["actual_runner_exit"],
        result["before"] == result["after"], result["pid_ancestry_verified"], result["engine_identity_verified"])
    if recalculated != result["assessment"]: raise ValueError("stored assessment differs from raw re-evaluation")
    if recalculated["control_acceptance_exit"] != 0: raise ValueError("run did not satisfy exact declared control: " + name)
    return result


def require_phase(batch, phase):
    root = runner.EVIDENCE / batch
    receipt = json.loads((root / (phase + ".json")).read_text(encoding="utf-8"))
    if receipt.get("status") != "COMPLETE": raise ValueError("prior phase not complete: " + phase)
    expected_names = [r[0] for r in PHASES[phase]]
    if [r["name"] for r in receipt["runs"]] != expected_names: raise ValueError("prior phase missing run")
    for row in receipt["runs"]:
        if assess.sha(root / "runs" / row["name"] / "result.json") != row["result_sha256"]:
            raise ValueError("prior bound result changed")
        verified_result(batch, row["name"])
    if phase in DEPENDENCY: require_phase(batch, DEPENDENCY[phase])


def run_one(batch, entry, record, nav_name="nav_candidate.gd", routines_name="routines_candidate.gd"):
    check_live(batch, nav_name, routines_name)
    name, mode, expected = entry
    result = runner.run(mode, expected, name, batch)
    record["runs"].append({"name": name, "result_sha256": assess.sha(runner.EVIDENCE / batch / "runs" / name / "result.json"),
                           "actual_runner_exit": result["actual_runner_exit"], "assessment": result["assessment"]})
    runner.dump(runner.EVIDENCE / batch / (record["phase"] + ".json"), record)
    # A refusal, timeout, unrelated red or missing artifact stops dependent work.
    verified_result(batch, name)
    check_live(batch, nav_name, routines_name)


def prepare_batch(batch):
    root = runner.EVIDENCE / batch
    root.mkdir(parents=True, exist_ok=False)
    runner.package_check()
    # Verify all existing owners before creating either new fixture.
    if (ROOT / NAV).read_bytes() != input_bytes("nav_original.gd"): raise ValueError("initial nav is not exact reviewed original")
    if (ROOT / ROUTINES).read_bytes() != input_bytes("routines_candidate.gd"): raise ValueError("initial routines differ")
    for relative, name in LIVE_INPUTS.items():
        if not name.startswith("direct_") and (ROOT / relative).read_bytes() != input_bytes(name):
            raise ValueError("existing regression fixture changed: " + relative)
    for relative, name in LIVE_INPUTS.items():
        path = ROOT / relative
        if name.startswith("direct_"):
            if path.exists():
                if path.read_bytes() != input_bytes(name): raise ValueError("existing direct fixture differs")
            else: write_bound(relative, name, None)
        elif path.read_bytes() != input_bytes(name): raise ValueError("existing regression fixture changed: " + relative)
    if (ROOT / NAV).read_bytes() != input_bytes("nav_original.gd"): raise ValueError("initial nav is not exact reviewed original")
    if (ROOT / ROUTINES).read_bytes() != input_bytes("routines_candidate.gd"): raise ValueError("initial routines differ")
    runner.dump(root / "batch.json", {"schema": "astra.nav-validation.batch.v1", "status": "STARTED",
        "package_sha256": assess.sha(HERE / "package.json"), "all_game_reference": runner.all_game_rows(),
        "engine_binaries": runner.support.parser_module.engine_binary_manifest(),
        "note": "Reference is frozen after installing only the two direct fixtures; all later game differences must be exact nav/routines variants."})


def execute(phase, batch):
    if not re.fullmatch(r"[A-Za-z0-9_-]+", batch): raise ValueError("fresh plain batch name required")
    runner.package_check()
    if phase == "focused": prepare_batch(batch)
    else: require_phase(batch, DEPENDENCY[phase])
    root = runner.EVIDENCE / batch
    record_path = root / (phase + ".json")
    if record_path.exists(): raise ValueError("phase already has retained results; use a reviewed new attempt, never overwrite")
    record = {"phase": phase, "status": "RUNNING", "runs": [], "mutations": [],
              "scope": "Exact declared controls only; raw diagnostic red stays red."}
    runner.dump(record_path, record)
    try:
        if phase == "focused":
            run_one(batch, PHASES[phase][0], record, nav_name="nav_original.gd")
            write_bound(NAV, "nav_candidate.gd", "nav_original.gd")
            record["mutations"].append({"path": NAV, "installed_sha256": assess.sha(ROOT / NAV)})
            run_one(batch, PHASES[phase][1], record)
        elif phase in {"nav-control", "coordinate-control"}:
            check_live(batch)
            relative, variant, normal = (NAV, "nav_call_omission.gd", "nav_candidate.gd") if phase == "nav-control" \
                else (ROUTINES, "routines_original.gd", "routines_candidate.gd")
            before = (ROOT / relative).read_bytes()
            (root / (phase + ".candidate.before.gd")).write_bytes(before)
            try:
                write_bound(relative, variant, normal)
                kwargs = {"nav_name": variant} if relative == NAV else {"routines_name": variant}
                run_one(batch, PHASES[phase][0], record, **kwargs)
            finally:
                current = (ROOT / relative).read_bytes()
                if current not in {input_bytes(variant), before}:
                    record["restoration"] = {"exact_bytes_restored": False, "reason": "unexpected owner bytes; refused to overwrite another edit"}
                    runner.dump(record_path, record)
                    raise ValueError("restoration blocked by unexpected source mutation")
                (ROOT / relative).write_bytes(before)
                record["restoration"] = {"path": relative, "exact_bytes_restored": (ROOT / relative).read_bytes() == before,
                                         "candidate_sha256": assess.sha(ROOT / relative)}
                runner.dump(record_path, record)
            if not record["restoration"]["exact_bytes_restored"]: raise ValueError("candidate restoration failed")
            run_one(batch, PHASES[phase][1], record)
        else:
            for entry in PHASES[phase]: run_one(batch, entry, record)
        record["status"] = "COMPLETE"
    except BaseException as error:
        record["status"] = "STOPPED_REVIEW_REQUIRED"
        record["failure"] = str(error)
        record["traceback"] = traceback.format_exc()
        raise
    finally:
        runner.dump(record_path, record)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("phase", choices=["plan", *PHASES])
    p.add_argument("batch", nargs="?", default="nav_direct_01")
    args = p.parse_args()
    if args.phase == "plan":
        print(json.dumps({phase: {"command": ["python", "-B", str(HERE / "execute.py"), phase, args.batch],
                                 "runs": rows} for phase, rows in PHASES.items()}, indent=2))
        return 0
    execute(args.phase, args.batch)
    return 0


if __name__ == "__main__": raise SystemExit(main())
