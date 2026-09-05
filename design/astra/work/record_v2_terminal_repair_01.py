"""Record bounded actual terminal input/capture evidence without release promotion."""
from pathlib import Path
import hashlib
import json

PACKET = Path(r"C:\PleaseRemainOnTheLine-astra\design\astra")
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding="utf-8"))
write = lambda p, value: p.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
input_path = PACKET / "reviews/v2_terminal_access_arrival_02_review.json"
view_path = PACKET / "reviews/v2_terminal_candidate_view_01.json"
assert sha(input_path) == "9128b8815edbf5d603220cacfeee9c05f66e89efed862c2fb1cda3e67baa0c04"
assert sha(view_path) == "3a11228440443cc91524df8718e95138039afb5dc1810a2510178510ce3fd871"
input_review, view_review = read(input_path), read(view_path)
assert len(input_review["runs"]) == 6 and view_review["passed"] == 21
sources = ["reviews/v2_terminal_access_arrival_02_review.json", "reviews/v2_terminal_candidate_view_01.json"]
path = PACKET / "reviews/production_obligations.json"
rows = read(path)
interaction = next(row for row in rows if row["id"] == "ASTRA-INTERACTION")
interaction["current_state"] += (" V2 terminal composition now turns the actual console toward its authored operator and mounts the existing DeskZone/CallInterface. Six actual39-check runs establish the input repair with selective orientation, desk and footprint negatives, followed by restored39/39. The source remains a working checkpoint until its named commit is recorded.")
interaction["automated_proof"] = ("V2 original19/39; candidate39/39; orientation omission38/39; desk omission20/39; footprint omission38/39; restored candidate39/39. Both actor/camera ray origins independently match the authored operator after actual deferred arrival. All344 raw artifact entries verify; source restoration and domain retirement are recorded. The fifth run overlaps unrelated Godot processes and requires an additive actual restoration receipt; its concurrency context is preserved.")
interaction["composed_runtime_proof"] = ("Actual CampaignShell/V2, ordinary2.1m physics ray and prompt, real E entry/seated exit/reentry, real Escape event, reciprocal player/desk/call ownership, retained case and Telephone audio owner. Final candidate39/39 and separate actual operator/phone capture21/21. Controlled physics-disabled pose and compressed opener delay; no walked route, completed case, controller, physical handset or listening acceptance.")
interaction["production_consumer"] = "PlayerController / V2 mounted DeskZone / existing CallInterface and Telephone owner; existing physical affordances"
interaction["provenance"]["sources"].extend(sources)
art = next(row for row in rows if row["id"] == "ASTRA-ART")
art["current_state"] += (" The repaired V2 operator and phone captures now show the actual console front and support-desk prompt. Yellow/teal development reservation meshes, gray-box architecture and coarse handset remain visible; no visual or human acceptance follows from21/21 capture checks.")
art["next_decisive_action"] = "Hide only nonphysical reservation display in production V2 while preserving dedicated review geometry, then compare actual operator/phone/lobby/lift views and retain the input regression. Continue source-based world construction."
art["provenance"]["sources"].append(sources[1])
perf = next(row for row in rows if row["id"] == "ASTRA-PERF")
perf["current_state"] += " Later terminal evidence resolves the wrong-facing/missing-desk defect and uses the actual operator viewpoint; this is an input/display repair, not performance acceptance."
perf["open_defects"] = ["V2 operator now sees and can enter the terminal in focused tests; development reservation geometry and unfinished surroundings remain perceptual debt." if value.startswith("V2 bedside-to-terminal capture") else value for value in perf["open_defects"]]
perf["next_decisive_action"] = "Review the optional clean C1 F01 provider against actual current-root consumers and lifecycle; complete V2 reservation display cleanup. Continue content-equivalent residency and frame-budget work without treating sparse V2 or adaptive-quality deltas as release performance."
perf["provenance"]["sources"].extend(sources)
write(path, rows)
path = PACKET / "LIVE_STATE.json"
state = read(path)
state["current_v2_terminal_repair"] = {"status": "FOCUSED_INPUT_AND_CAPTURE_VERIFIED_COMMIT_PENDING", "base_head": "af9c5b6fdc42079d4bd64549b709a49ababa9e50",
    "input_review": sources[0], "input_review_sha256": sha(input_path), "capture_review": sources[1], "capture_review_sha256": sha(view_path),
    "sources": input_review["candidate_sources"], "scope": "39-check actual controlled-pose input with selective negatives and21-check operator/phone capture. No traversal, complete case, performance, visual or human acceptance."}
write(path, state)
path = PACKET / "DECISION_LOG.md"
log = path.read_text(encoding="utf-8")
assert "### D037 " not in log
log += ("\n### D037 — Restore actual V2 terminal access and operator view\n\n"
    "V2 now rotates only the mounted terminal consumer toward its authored operator and composes the existing DeskZone/CallInterface using the authored use footprint. Semantic transforms and the V1 default footprint remain intact. The first fixture's deferred-arrival placement error is preserved as a failed test setup; a new39-check fixture witnesses arrival before authoring its controlled pose and independently binds both ray origins. Original19/39, candidate39/39, selective orientation38/39, desk20/39, footprint38/39 and restored39/39 establish the bounded input repair. Foreign Godot activity interrupted the fifth restoration; the refusal, exact additive recovery and final continuation remain explicit. The actual operator/phone capture passes21/21 and shows the console front; translucent development reservations and unfinished art remain. No walked route, full case, controller, listening, performance, human or cutover acceptance follows. See `reviews/v2_terminal_access_arrival_02_review.json` and `reviews/v2_terminal_candidate_view_01.json`.\n")
path.write_text(log, encoding="utf-8", newline="\n")
print("Recorded D037 and bounded terminal input/capture evidence.")
