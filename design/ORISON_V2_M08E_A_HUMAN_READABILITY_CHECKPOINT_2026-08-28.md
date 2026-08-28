# ORISON-V2-M08E-A human-readability checkpoint — 2026-08-28

Status: **TECHNICAL PASS; HUMAN SPATIAL-READABILITY ACCEPTANCE PASS**

This checkpoint corrects review presentation only, except for one genuine spatial defect exposed by the recapture. It does not compose runtime directors, change the selector, or authorize M08F/M09/cutover.

## Corrections

- F01 now uses distinct review-only clock/dial, ledger, annunciator-lamp, and guarded-key silhouettes with focused practical lighting and small period-style plates. The preserved semantic owners remain unchanged and unique.
- B1 now uses review-only vessel, firebox/firing door, water column, gauge, feet, pipe, and flue forms. Arrival/bridge/approach lighting and camera alignment expose the complete return leg. The open fire-door presentation leaf is hidden only for the retreat evidence frame; its schema and collision contract are unchanged.
- 2B now has legible mattress/headboard/pillow, folding cutting table, fabric rolls, kitchen counter/uppers/sink, radiator fins, and bath-threshold cues. These meshes are presentation-only and own no gameplay behavior.
- Cameras were reframed from natural 1.41 m eye positions. The axonometric frame alone uses a semantic route overlay.

## Accepted geometry correction

Visual inspection found `F02_B_BED_DOOR` at `(12.8, -10.30)`, where the east-side space is the bathroom despite the leaf declaring `F02_B_PRIVATE_HALL`. The center moves to `(12.8, -8.85)`, inside the actual 1.00 m bed/private-hall shared partition. Door identity, width, hinge, latch, handedness, swing, connected spaces, room envelopes, and route authority are unchanged. The blockout suite validates the corrected boundary.

## Evidence

Replacement packet: `art/renders/orison_v2/m08e_spatial_owners_checkpoint_03/`

- `scene_capture_receipt.json`: 13/13 PASS at 1600 × 900.
- `camera_and_frame_receipt.json`: exact position, target, FOV, player-height flag, and per-frame capture result.
- `FRAME_REVIEW_AND_BEFORE_AFTER.md`: frame-level submission checks, checkpoint_02 defect mapping, human checklist, and acceptance question.

Checkpoint_02 is unchanged. Automated evidence production does not constitute owner acceptance.

## Authority boundary

The six accepted owners, collision-bearing route, doors/openings/stairs/platforms/stances, save/audio/gameplay authorities, production layout, and v1 selector default remain preserved. Review silhouettes are non-colliding and non-authoritative. `FirstShiftDirector` and `ServiceRoundDirector` are not composed.

## Validation

- `OrisonV2BlockoutTest`: PASS after the 2B doorway correction; 50 spaces, 21 doors, 48 anchors, and production-layout byte stability preserved.
- `OrisonV2M08ESpatialTest`: PASS; all six owners resolve exactly once and the production controller completes the collision-bearing boiler-to-ritual-to-2B-to-porter-to-boiler-to-radiator route.
- `OrisonV2IntegratedTest` (M08A): PASS; F01/F02/F04 public contracts, real save/reload, continuous street-to-bedside traversal, service continuity, proportional budgets, layout stability, and adapter/acoustic teardown all pass.
- Review-scene startup: PASS headlessly with 50 spaces, 21 doors, and 48 anchors.
- Dependency audit: clean; zero new unclassified dependencies, authority-class changes, vanished targets, unresolved save contracts, or stale preserved records. Eleven incidental report-only records remain unblessed, including unrelated F03 test work and the two evidence-only leaf paths used by this capture harness.
- Dependency-audit self-tests: 48/48 PASS.
- Selector assertion: `BuildingRootSelector.DEFAULT_ID == "v1"`.
- Production layouts: both copies remain SHA-256 `9e6b4fa95a88e7ea23fe8bfac188fd094fd1cace628237010a683db7c0c4356e`.
- Capture: 13/13 PASS at 1600 x 900 in 1.888 s; camera/frame receipt reports PASS for every frame.
- Teardown: no ObjectDB or resource-retention warning occurred in the focused spatial test, M08A integration test, or review-scene startup.
- M08A measured startup was 17.110 ms with 2,186 nodes and 523 collision objects. Warm station CPU samples after the initial street frame were 0.122-0.890 ms; physics samples were 0.264-1.467 ms. The cold/first street CPU sample was 131.066 ms. GPU timing is unavailable headlessly.

## Verdict

The owner answered PASS on 2026-08-28:

**Does this packet make the F01 ritual station, complete 2B home/radiator service stance, and B1 boiler route readable, credible, safely approachable, and memorable as one service round?**

This closes the gray-box spatial-readability gate only. It does not accept final furnishing, materials, lighting, labels, boiler art, or apartment characterization. M08F was separately authorized; M09, selector change, production cutover, and v1 retirement remain unauthorized.
