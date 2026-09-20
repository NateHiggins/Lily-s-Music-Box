"""Bind the actual operator/phone capture and root's direct visual review."""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
RUN = ROOT / "design/astra/evidence/vulkan_composed/runs/terminal_candidate_view_v2_01"
OUT = ROOT / "design/astra/reviews/v2_terminal_candidate_view_01.json"
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding="utf-8"))
assert not OUT.exists()
result = read(RUN / "result.json")
probe = read(RUN / "frames/probe.json")
invocation_path = ROOT / "design/astra/evidence/vulkan_composed/invocations/terminal_candidate_view_v2_01/invocation.json"
invocation = read(invocation_path)
assert invocation["status"] == "EXACT_FIXTURE_RESTORED" and invocation["actual_command_exit"] == 0
assert invocation["source_before"] == invocation["source_after"]
assert result["actual_engine_exit"] == result["gate"]["diagnostic_gate_exit"] == 0
assert result["before"] == result["after"] and result["engines_before"] == result["engines_after"]
assert result["source_unchanged"] and not result["gate"]["retention"]
plan = read(ROOT / "design/astra/work/vulkan_composed/revisions/terminal_operator_view_01/preparation.json")
assert [row["label"] for row in probe["checks"]] == plan["expected_complete_v2_ordered_labels"]
assert len(probe["checks"]) == 21 and all(row["passed"] for row in probe["checks"])
for rel, expected in result["artifacts"].items():
    path = (RUN / rel).resolve()
    assert path.is_relative_to(RUN.resolve()) and sha(path) == expected
actual_paths = {p.relative_to(RUN).as_posix() for p in RUN.rglob("*") if p.is_file() and "APPDATA" not in p.relative_to(RUN).parts and p.name != "result.json"}
assert actual_paths == set(result["artifacts"])
sys.path.insert(0, str(ROOT / "design/astra/work/vulkan_composed"))
from gate import classify
text = lambda rel: (RUN / rel).read_text(encoding="utf-8-sig", errors="replace")
assert classify(0, text("stdout.log"), text("stdout.log.stderr"), probe, True, True) == result["gate"]
diag = next(row for row in probe["owned_controls"] if row.get("kind") == "v2_terminal_operator_view")
assert diag["complete"] and diag["face_dot_operator"] >= .99 and len(diag["desk_zones"]) == 1
assert all(abs(a-b) < 1e-4 for a,b in zip(diag["camera_position"], [-9.9, 11.01, 1.25]))
images = [RUN / "frames/v2_actual_f04_semantic_stance.png", RUN / "frames/v2_actual_f04_phone.png"]
report = {"schema": "astra.v2-terminal-candidate-view.review.v1", "status": "FUNCTIONAL_CAPTURE_PASS_VISUAL_DEBT_REMAINS",
    "reviewer_sha256": sha(Path(__file__)), "result_sha256": sha(RUN / "result.json"), "probe_sha256": sha(RUN / "frames/probe.json"),
    "invocation_sha256": sha(invocation_path), "checks": 21, "passed": 21, "native_exit": 0, "gate_exit": 0,
    "artifact_entries_verified": len(result["artifacts"]), "stable_source_files": len(result["before"]["files"]),
    "operator_diagnostics": diag, "images_directly_viewed_by_root": [{"path": p.relative_to(ROOT).as_posix(), "sha256": sha(p)} for p in images],
    "visual_finding": "The actual console now presents its circular green face and front controls toward the operator. The normal support-desk prompt is visible. The phone capture also shows the front. Translucent yellow/teal reservation geometry remains conspicuous across the desk and lower view; surrounding gray-box architecture and coarse handset remain unfinished.",
    "scope": "Controlled authored operator pose and fixture-mounted production PhoneCamera. The separate39-check fixture establishes input. This capture does not establish walking/body clearance, physical handset use, completed calls, audio listening, performance or human acceptance.",
    "next_action": "Hide only nonphysical reservation display in production, preserve dedicated review/default geometry, then compare actual views and interaction regression."}
OUT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"status": report["status"], "sha256": sha(OUT), "artifacts": report["artifact_entries_verified"]}))
