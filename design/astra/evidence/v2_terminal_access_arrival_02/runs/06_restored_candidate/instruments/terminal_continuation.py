"""Explicit recovery/continuation after a preserved postrun busy-lane refusal."""
from pathlib import Path
import argparse
import json
import shutil
import sys

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
BASE = ROOT / "design/astra/work/v2_terminal_access_arrival_02"
sys.path.insert(0, str(BASE / "runtime"))
import run

OUT = ROOT / "design/astra/evidence/v2_terminal_access_invocations/arrival_02_postrun_recovery_01"
OLD = run.EVIDENCE / "05_footprint_omission.restoration.json"
read = lambda p: json.loads(p.read_text(encoding="utf-8"))
sha = run.sha


def prior_review(plan):
    for spec in plan["sequence"][:5]:
        phase = spec["run_name"]
        folder = run.EVIDENCE / "runs" / phase
        result = read(folder / "result.json")
        run.verify_artifacts(folder, result)
        text = lambda rel: (folder / rel).read_text(encoding="utf-8-sig", errors="replace")
        verdict = run.assess.assess(read(folder / "shots/terminal_access.json"), text("godot.stdout.log"), text("godot.stdout.log.stderr"),
            text("runner.stdout.log") + "\n" + text("runner.stderr.log"), result["actual_runner_exit"],
            result["before"] == result["after"], result["pid_ancestry_verified"],
            result["before"]["engine_binaries"] == result["after"]["engine_binaries"], phase)
        assert verdict == result["assessment"] and verdict["control_contract_exit"] == 0
        if phase != "05_footprint_omission":
            receipt = read(run.EVIDENCE / (phase + ".restoration.json"))
            _, sources = run.owner_sources(plan, "01_original" if phase == "01_original" else "02_candidate")
            run.require_restoration(receipt, {rel: sha(path) for rel, path in sources.items()})
    refusal = read(OLD)
    assert refusal["phase"] == "05_footprint_omission" and refusal["status"] == "RESTORATION_REFUSED_ACTIVE_PROCESS"
    assert sorted(row["pid"] for row in refusal["process_census"]) == [31476, 33024]


def bound_state():
    assert run.core.godot_processes() == [], "empty engine lane required before recovery review"
    assert sha(BASE / "preparation.json") == "bb79be11112e7d23666ce8437cc6604b76be4c293716c747a728b634d87cbd02"
    assert sha(BASE / "runtime/package.json") == "d0e81f833b08844face2f85cf411e6b3e52a5da2165e33d96975342b53d7e7e0"
    plan, manifest = run.package()
    state = read(run.EVIDENCE / "install.json")
    assert state["head"] == run.core.git("rev-parse", "HEAD").decode().strip() == plan["required_install_head"]
    assert state["package_sha256"] == sha(BASE / "runtime/package.json")
    prior_review(plan)
    return plan, manifest, state


def recover():
    assert not OUT.exists()
    plan, _, state = bound_state()
    _, omission = run.owner_sources(plan, "05_footprint_omission")
    _, candidate = run.owner_sources(plan, "02_candidate")
    assert dict(run.core.all_game_rows()) == {**state["files"], **{rel: sha(path) for rel, path in omission.items()}}
    assert run.core.godot_processes() == []
    OUT.mkdir(parents=True)
    for rel in run.OWNERS:
        target = OUT / "before" / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, target)
        assert sha(target) == sha(omission[rel])
    receipt = {"schema": "astra.terminal-restoration-recovery.v1", "status": "RECOVERY_STARTED",
        "phase": "05_footprint_omission", "target_phase": "02_candidate",
        "orchestrator_sha256": sha(Path(__file__)), "preserved_refusal_sha256": sha(OLD),
        "result_sha256": sha(run.EVIDENCE / "runs/05_footprint_omission/result.json"),
        "before_hashes": {rel: sha(ROOT / rel) for rel in run.OWNERS}, "processes_before": [],
        "scope": "Postrun recovery after an unrelated engine occupied the lane. Actual fifth run retained with concurrent-process context; no performance acceptance."}
    run.dump(OUT / "recovery.json", receipt)
    assert run.core.godot_processes() == []
    assert all(sha(ROOT / rel) == sha(omission[rel]) for rel in run.OWNERS)
    for rel, path in candidate.items():
        shutil.copy2(path, ROOT / rel)
    receipt["process_census"] = run.core.godot_processes()
    receipt["hashes"] = {rel: sha(ROOT / rel) for rel in run.OWNERS}
    receipt["status"] = "EXACT_OWNED_SOURCES_RESTORED" if receipt["hashes"] == {rel: sha(path) for rel, path in candidate.items()} and receipt["process_census"] == [] else "RECOVERY_REQUIRES_REVIEW"
    run.dump(OUT / "recovery.json", receipt)
    run.require_restoration(receipt, {rel: sha(path) for rel, path in candidate.items()})
    print(json.dumps({"status": receipt["status"], "receipt": str(OUT / "recovery.json")}))


def continue_final():
    plan, manifest, state = bound_state()
    receipt = read(OUT / "recovery.json")
    assert receipt["preserved_refusal_sha256"] == sha(OLD)
    assert receipt["result_sha256"] == sha(run.EVIDENCE / "runs/05_footprint_omission/result.json")
    assert receipt["orchestrator_sha256"] == sha(Path(__file__))
    _, desired = run.owner_sources(plan, "06_restored_candidate")
    expected = {rel: sha(path) for rel, path in desired.items()}
    run.require_restoration(receipt, expected)
    assert dict(run.core.all_game_rows()) == {**state["files"], **expected}
    assert not (run.EVIDENCE / "runs/06_restored_candidate").exists()
    assert not (run.EVIDENCE / "06_restored_candidate.restoration.json").exists()
    assert run.core.godot_processes() == []
    prior_instruments = run.core.instrument_paths
    run.core.instrument_paths = lambda: {**prior_instruments(), "terminal_continuation.py": Path(__file__), "terminal_recovery.json": OUT / "recovery.json"}
    invocation = {"status": "FINAL_RUN_STARTED", "orchestrator_sha256": sha(Path(__file__)),
        "recovery_sha256": sha(OUT / "recovery.json"), "preserved_refusal_sha256": sha(OLD),
        "declaration": "Only phase05 restoration is resolved through this additive actual recovery; all five raw run assessments and other restoration contracts are unchanged and revalidated."}
    assert not (OUT / "continuation.json").exists()
    run.dump(OUT / "continuation.json", invocation)
    verdict = 1
    try:
        verdict = run.run_installed("06_restored_candidate", plan, manifest, state, desired)
        invocation["control_contract_exit"] = verdict
    finally:
        processes = run.core.godot_processes()
        hashes = {rel: sha(ROOT / rel) for rel in run.OWNERS}
        status = "EXACT_OWNED_SOURCES_RESTORED" if not processes and hashes == expected else "RESTORATION_REFUSED_ACTIVE_PROCESS_OR_SOURCE_DRIFT"
        restoration = {"phase": "06_restored_candidate", "target_phase": "02_candidate", "process_census": processes,
            "hashes": hashes, "status": status, "supplementary_controller_sha256": sha(Path(__file__))}
        run.dump(run.EVIDENCE / "06_restored_candidate.restoration.json", restoration)
        invocation["status"] = status
        run.dump(OUT / "continuation.json", invocation)
    run.require_restoration(restoration, expected)
    return verdict


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=["recover", "continue"])
    args = parser.parse_args()
    if args.phase == "recover":
        recover()
    else:
        raise SystemExit(continue_final())
