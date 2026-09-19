"""Independent source/artifact/pose review after all six actual terminal runs."""
from pathlib import Path
import hashlib
import json
import math
import sys

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
BASE = ROOT / "design/astra/work/v2_terminal_access_arrival_02"
EVIDENCE = ROOT / "design/astra/evidence/v2_terminal_access_arrival_02"
OUT = ROOT / "design/astra/reviews/v2_terminal_access_arrival_02_review.json"
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding="utf-8"))


def near(actual, expected):
    return len(actual) == len(expected) and all(type(a) in (int, float) and math.isfinite(a) and abs(a-b) < 1e-4 for a, b in zip(actual, expected))


def main():
    assert not OUT.exists()
    assert sha(BASE / "preparation.json") == "bb79be11112e7d23666ce8437cc6604b76be4c293716c747a728b634d87cbd02"
    assert sha(BASE / "runtime/package.json") == "d0e81f833b08844face2f85cf411e6b3e52a5da2165e33d96975342b53d7e7e0"
    sys.path.insert(0, str(BASE / "runtime"))
    import run
    plan, package = run.package()
    summaries = []
    stable_inputs = None
    for phase in plan["sequence"]:
        name = phase["run_name"]
        folder = EVIDENCE / "runs" / name
        result = read(folder / "result.json")
        probe = read(folder / "shots/terminal_access.json")
        assert result["before"] == result["after"] and result["source_unchanged"]
        assert result["pid_ancestry_verified"] and result["actual_runner_exit"] == phase["expected_native_exit"]
        assert result["before"]["head_observed"] == "af9c5b6fdc42079d4bd64549b709a49ababa9e50"
        run.verify_artifacts(folder, result)
        for rel, expected in result["artifacts"].items():
            target = (folder / rel).resolve()
            assert target.is_relative_to(folder.resolve()) and sha(target) == expected
        before = dict(read(folder / "before.all_game_files.json"))
        after = dict(read(folder / "after.all_game_files.json"))
        assert before == after
        stable = {rel: value for rel, value in before.items() if rel not in run.OWNERS}
        if stable_inputs is None:
            stable_inputs = stable
        assert stable == stable_inputs
        native_text = lambda rel: (folder / rel).read_text(encoding="utf-8-sig", errors="replace")
        verdict = run.assess.assess(probe, native_text("godot.stdout.log"), native_text("godot.stdout.log.stderr"),
            native_text("runner.stdout.log") + "\n" + native_text("runner.stderr.log"),
            result["actual_runner_exit"], True, True, result["before"]["engine_binaries"] == result["after"]["engine_binaries"], name)
        assert verdict == result["assessment"] and verdict["control_contract_exit"] == 0
        assert not verdict["unknown_diagnostics"] and not verdict["retention"]
        assert [row["label"] for row in probe["checks"]] == plan["full_unique_ordered_labels"]
        assert all(row["passed"] for row in probe["checks"][-3:])
        diag = probe["diagnostics"]
        assert near(diag["arrival"]["position"], [-3.6, .1, 24.72]) and diag["arrival"]["settled"]
        for key in ["first_ray", "second_ray"]:
            assert near(diag[key]["from"], [-9.9, 11.01, 1.25])
            assert near(diag[key]["camera_position"], [-9.9, 11.01, 1.25])
            assert near(diag[key]["actor_position"], [-9.9, 9.6, 1.25])
        if name in ["02_candidate", "06_restored_candidate"]:
            assert verdict["diagnostic_gate_exit"] == 0 and verdict["passed"] == 39
            assert [event["identity"] for event in diag["world_events"]] == ["F04_B_DESK_ZONE"] * 2
            assert all(diag[key] is True for key in ["first_interact_action_dispatched", "seated_E_action_dispatched", "reentry_action_dispatched", "escape_key_dispatched"])
        restoration_path = EVIDENCE / (name + ".restoration.json")
        preserved_refusal_sha256 = None
        if name == "05_footprint_omission":
            assert read(restoration_path)["status"] == "RESTORATION_REFUSED_ACTIVE_PROCESS"
            preserved_refusal_sha256 = sha(restoration_path)
            restoration_path = ROOT / "design/astra/evidence/v2_terminal_access_invocations/arrival_02_postrun_recovery_01/recovery.json"
            assert read(restoration_path)["preserved_refusal_sha256"] == preserved_refusal_sha256
            assert read(restoration_path)["result_sha256"] == sha(folder / "result.json")
        restoration = read(restoration_path)
        _, restored = run.owner_sources(plan, "01_original" if name == "01_original" else "02_candidate")
        run.require_restoration(restoration, {rel: sha(path) for rel, path in restored.items()})
        summaries.append({"phase": name, "result_sha256": sha(folder / "result.json"),
            "probe_sha256": sha(folder / "shots/terminal_access.json"), "restoration_sha256": sha(restoration_path),
            "preserved_refusal_sha256": preserved_refusal_sha256,
            "native_exit": result["actual_runner_exit"], "ordinary_gate_exit": verdict["diagnostic_gate_exit"],
            "control_contract_exit": verdict["control_contract_exit"], "passed": verdict["passed"], "total": verdict["total"],
            "failed_labels": verdict["failed_labels"], "artifact_entries_verified": len(result["artifacts"]),
            "known_diagnostic_debt": verdict["known_diagnostic_debt"]})
    _, candidate = run.owner_sources(plan, "02_candidate")
    assert all(sha(ROOT / rel) == sha(path) for rel, path in candidate.items())
    assert run.core.godot_processes() == []
    report = {"schema": "astra.v2-terminal-access.independent-review.v1", "status": "SIX_ACTUAL_RUNS_VERIFY_FOCUSED_INPUT_REPAIR",
        "reviewer_sha256": sha(Path(__file__)), "runs": summaries, "stable_non_owner_inputs": len(stable_inputs),
        "candidate_sources": {rel: sha(path) for rel, path in candidate.items()},
        "scope": "Actual CampaignShell/V2 at a controlled physics-disabled operator pose: ordinary ray, prompt, E entry/exit, reentry, Escape, call continuity, existing Telephone owner and world retirement.",
        "limits": "No walked route, body clearance, completed case, controller, physical handset, audio listening, performance, visual or human acceptance. Five host Vulkan loader errors, two loader warnings and39 RGB8 conversion warnings remain in each run.",
        "historical_failed_fixture_review": "reviews/v2_terminal_access_startup_review_01.json",
        "prelaunch_refusal": "evidence/v2_terminal_access_invocations/arrival_02_footprint_busy_01.json",
        "concurrent_process_context": "Foreign Godot processes joined during phase05 and blocked its first restoration. The actual focused input result is retained; exact source recovery and final39 pass followed under additive captured continuation. No exclusive hardware or timing claim is made for phase05.",
        "recovery": "evidence/v2_terminal_access_invocations/arrival_02_postrun_recovery_01/recovery.json"}
    OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"], "sha256": sha(OUT), "runs": len(summaries), "artifact_entries": sum(row["artifact_entries_verified"] for row in summaries)}))


if __name__ == "__main__":
    main()
