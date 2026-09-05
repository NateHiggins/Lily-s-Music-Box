"""Assemble preserved run receipts and the explicit human-readable visual review."""
from collections import Counter
import datetime
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(name):
    return json.loads((BASE / name / "run_receipt.json").read_text())


classifications = {
    "calendar_01": "EVIDENCE_WRAPPER_ARGUMENT_REFUSAL_NO_GODOT",
    "calendar_02": "TEST_LITERAL_ROUNDED_TO_MIDNIGHT_49_OF_50",
    "calendar_03": "TEST_LITERAL_ROUNDING_DIAGNOSED_49_OF_50",
    "calendar_04": "CORRECTED_PREVIOUS_DOUBLE_FIXTURE_PASS_50_OF_50",
    "calendar_clamp_omitted": "MEANINGFUL_PRODUCTION_BOUNDARY_OMISSION_RED_49_OF_50",
    "calendar_05_restored": "FINAL_RESTORED_CALENDAR_PASS_50_OF_50",
    "admin_01": "PASS_29_OF_29_EXPECTED_FUTURE_DREAM_REJECTION_WARNING",
    "focused_01": "FUNCTIONAL_14_OF_14_SHUTDOWN_RETENTION_4_OBJECTS_2_RESOURCES",
    "focused_02": "OWNER_DETACH_ALONE_WITH_EARLY_QUIT_STILL_RETAINS",
    "focused_03": "OWNER_FREE_ALONE_WITH_EARLY_QUIT_STILL_RETAINS",
    "focused_04": "COALESCING_WITH_EARLY_QUIT_STILL_RETAINS",
    "focused_05": "EXPLICIT_REMOVAL_AND_DRAIN_PASS_14_OF_14",
    "notice_coalesce_omitted": "PASS_WITHOUT_COALESCING_WORKAROUND_REMOVED",
    "focused_06": "OBSERVER_FIXTURE_STRICT_TYPE_PARSE_FAILURE_RUNNER_TIMEOUT",
    "focused_07": "OBSERVER_COROUTINE_RESOURCE_TEMPORARY_RETENTION_16_OF_17",
    "focused_08": "SYNCHRONOUS_OBSERVER_LIVE_NEIGHBOR_PASS_17_OF_17",
    "notice_owner_cleanup_omitted": "MEANINGFUL_FINAL_OWNER_RELEASE_OMISSION_RED_16_OF_17",
    "focused_09": "FINAL_SHORT_COPY_AND_OWNERSHIP_PASS_17_OF_17",
    "capture_01": "CAPTURE_HARNESS_BOOL_INFERENCE_PARSE_FAILURE_RUNNER_TIMEOUT",
    "capture_02": "THREE_FRAMES_EXIT_ZERO_VISUAL_COPY_CLIPPING_FAIL_VULKAN_ERRORS",
    "capture_03": "THREE_FRAMES_EXIT_ZERO_SCOPED_NOTICE_VISUAL_PASS_VULKAN_ERRORS_UNRESOLVED",
}
runs = []
for name, classification in classifications.items():
    data = read(name)
    runs.append({"name": name, "classification": classification,
                 "receipt": name + "/run_receipt.json",
                 "receipt_sha256": sha(BASE / name / "run_receipt.json"),
                 "runner_exit": data["runner_exit"], "elapsed_seconds": data["elapsed_seconds"],
                 "source_unchanged": data["source_unchanged"],
                 "runtime_inputs_sha256": data["source_before"]["runtime_inputs_sha256"],
                 "diagnostic_counts": dict(Counter(data["diagnostic_lines"]))})

images = []
for name in ["capture_02", "capture_03"]:
    for path in sorted((BASE / name / "shots").glob("*.png")):
        images.append({"path": path.relative_to(BASE).as_posix(), "sha256": sha(path),
                       "review_method": "All six full local PNGs individually opened through view_image",
                       "verdict": "PHYSICAL_PAPER_VISIBLE" if path.name.startswith("01") else
                                  "FAIL_BODY_LAST_LINE_CLIPPED" if name == "capture_02" else
                                  "PASS_NOTICE_BODY_AND_CONDITION_LEGIBLE_AT_1280X720"})
final = read("capture_03")
observations_path = BASE / "capture_03/shots/lobby_observations.json"
observations = json.loads(observations_path.read_text())
final_hashes = []
for row in final["source_after"]["selected_source_copies"]:
    path = ROOT / row["path"]
    final_hashes.append({**row, "current_sha256": sha(path), "matches_final_run": sha(path) == row["sha256"]})
review = {
    "schema": "astra.historical_notice_runtime_visual_review.v1",
    "reviewed_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "run_source_head": final["source_before"]["head"],
    "runtime_inputs_sha256": final["source_before"]["runtime_inputs_sha256"],
    "current_selected_sources_match_final_run": all(row["matches_final_run"] for row in final_hashes),
    "source_files": final_hashes,
    "functional_verdict": "PASS_FOCUSED_NOTICE_17_CALENDAR_50_ADMIN_29",
    "notice_visual_verdict": "PASS_BOUNDED_1280X720_TELEPORTED_V1_INSPECTION",
    "runtime_clean_verdict": "FAIL_UNRESOLVED_V1_VULKAN_RENDERER_TEARDOWN",
    "human_accepted": False, "walked_route_proven": False,
    "v2_placement_proven": False, "npc_knowledge_delivery_proven": False,
    "authentic_broadcast_proven": False,
    "interaction_path": observations["interaction_path"],
    "before": observations["before"], "after": observations["after"],
    "observations": {"path": observations_path.relative_to(BASE).as_posix(), "sha256": sha(observations_path)},
    "images": images, "runs": runs,
    "red_controls": [
        {"mutation_receipt": "calendar_clamp_omitted.mutation.json", "red": "49/50 exit1",
         "restored_green": "calendar_05_restored:50/50 exit0", "scope": "Previous binary double before midnight cannot format hour24"},
        {"mutation_receipt": "notice_owner_cleanup_omitted.mutation.json", "red": "16/17 exit1",
         "restored_green": "focused_09:17/17 exit0", "scope": "Final owner must release recorded stream while another live owner survives"},
        {"red": "capture_02 original line4 visibly clipped", "green": "capture_03 all three notice lines and exact condition visible",
         "scope": "Local copy length only; global TelegramHud unchanged"}
    ],
    "unresolved_diagnostics": [
        {"classification": "UNRESOLVED_V1_VULKAN_RENDERER_TEARDOWN", "final_counts": {
            "geom->softshadow_count==0 - BUG!": 261, "indexing did not unpair geometries from light": 1252},
         "attempt": "Immediate remove/free replaced by queued retirement, two rendered frames and0.1s mixer drain; errors persist.",
         "scope": "No global light disabling, renderer API workaround, driver/registry changes, or runtime-clean claim."},
        {"classification": "HOST_VULKAN_LAYER_MANIFEST_DIAGNOSTICS", "errors": 5, "warnings": 2,
         "scope": "Raw missing TikTok/Epic manifest and duplicate OBS layer messages retained; no host change."},
        {"classification": "VULKAN_RGB8_CONVERSION_WARNING", "count": 965},
        {"classification": "EXISTING_FOUND_ART_PLACEMENT_WARNING", "count": 1, "piece": "cam_noel_witches"}
    ],
    "shutdown_objectdb_or_resource_leak_diagnostics_in_final_capture": any(
        "leaked" in line.lower() or "resources still in use" in line.lower() for line in final["diagnostic_lines"]),
    "historical_scope": "Fictional tenant hand-copy of sourced1928 license facts; fixed paper, civil campaign-time field copy, no recorded speech or invented programme hours.",
    "preservation": "Earlier source-only receipts, every failed log/source snapshot and original clipped render remain untouched. Source omissions restored byte-identically. No staging, commit or live-ledger edit."
}
target = BASE / "runtime_visual_validation.json"
assert not target.exists(), "Preserve completed proof"
target.write_text(json.dumps(review, indent=2) + "\n")
print(json.dumps({"review": str(target), "sha256": sha(target),
                  "source_match": review["current_selected_sources_match_final_run"],
                  "runtime_inputs_sha256": review["runtime_inputs_sha256"], "runs": len(runs), "images_reviewed": len(images)}, indent=2))
