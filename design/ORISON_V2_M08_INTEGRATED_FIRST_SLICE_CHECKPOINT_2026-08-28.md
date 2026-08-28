# ORISON-V2-M08 — Integrated First-Slice Checkpoint

Date: 2026-08-28  
Selector: explicit development scene `res://scenes/building/orison_v2_integrated_review.tscn`; production v1 remains the project default.  
Route: street → F01 arrival/lobby → primary stair → F02/2A → primary stair through F03 → F04/4B → bedside return.

## Bounded implementation

- `game/data/orison_v2_blockout.json` — corrected primary landing head-clearance boundary exposed by integrated capsule travel.
- `game/scripts/building/orison_v2_blockout.gd` — emits compatibility-capable semantic anchors and sufficient U-turn landing floor.
- `game/scripts/building/orison_v2_review_controller.gd` — development-review-only 220 mm step assist; no production controller change.
- `game/scripts/building/orison_v2_semantic_anchor.gd` — existing CallInterface-compatible semantic node, without gameplay authority.
- `game/scripts/building/orison_v2_anchor_adapter.gd` — unique ID resolution, scoped acoustic position injection/restore, explicit bed selection, and separately tested production anonymous-bed fallback.
- `game/scenes/building/orison_v2_integrated_review.tscn` — explicit integrated selector.
- `game/tests/orison_v2_integrated_test.gd`, `game/tests/OrisonV2IntegratedTest.tscn` — runtime compatibility, traversal, service, stability, and performance gate.
- `game/tests/orison_v2_integrated_shot.gd`, `game/tests/OrisonV2IntegratedShot.tscn` — eight-frame human-review capture.
- `art/renders/orison_v2/m08_integrated_checkpoint_01/` — evidence PNGs and `scene_capture_receipt.json`.

No production selector, gameplay authority, save owner, golden-shift fact, v1 layout generation, or production asset was changed. The pre-existing `art/renders/orison_v2/f04_4b_checkpoint_01/` packet was not touched.

## Ordered integration gate

1. **PASS — deterministic v2 schema and generation.** Existing full blockout suite passed; development-only layout identity remained `orison_v2_h_plan_blockout_01`.
2. **PASS — generated construction and startup.** Integrated scene instantiated 1,716 blockout nodes in 12.973 ms.
3. **PASS — unique compatibility anchors.** All twelve required external IDs resolved exactly once.
4. **PASS — continuous controller traversal.** One collision-bearing CharacterBody3D walked the complete route and three storey transitions without teleporting.
5. **PASS — F01 compatibility.** Stable mail bank, porter board, house telephone, and dumbwaiter identities resolve through the adapter; no new interaction protocol exists.
6. **PASS — F02 compatibility.** Existing chirp job identity and work anchor were exercised; acoustic overrides used the existing AcousticGraphData consumer and were restored.
7. **PASS — F04 compatibility.** Existing CallInterface wrote terminal state through the semantic compatibility surface; terminal/acoustic identities stayed stable.
8. **PASS — bed/save compatibility.** Explicit `F04_B_BED` and anonymous production `bed` fallback passed separately. RealitySaveCompatTest passed 14/14; save ownership is root-neutral and unchanged.
9. **PASS — essential services.** Wet, heat, telephone/message, and service-lift stacks remained continuous.
10. **PASS automated / HUMAN ACCEPTANCE PENDING — performance and route-readability evidence.** Capture receipt passed 8/8; visual interpretation still requires a person.

Production `game/data/building_layout.json` was SHA-256 checked before and after the integrated run and remained byte-stable.

## Performance

The established proportional target is a 16.67 ms frame at 60 Hz. Measurements are fixed-station headless runtime snapshots; GPU time is unavailable in headless mode and is therefore not invented. The first street sample includes cold physics initialization; warmed route samples are the comparable gameplay measurements.

| Station | CPU ms | Physics ms | Result |
|---|---:|---:|---|
| Street approach (cold) | 0.631 | 54.380 | startup/import sample |
| F01 threshold/lobby | 0.143 | 0.411 | pass |
| Primary F01→F02 stair | 0.145 | 0.619 | pass |
| F02 landing | 0.146 | 0.320 | pass |
| 2A work position | 0.162 | 0.419 | pass |
| Primary F02→F03 stair | 0.135 | 0.379 | pass |
| Primary F03→F04 stair | 0.158 | 0.319 | pass |
| F04 landing | 0.827 | 0.348 | pass |
| 4B terminal | 0.140 | 1.045 | pass |
| Bedside return | 0.167 | 2.160 | pass |

Startup 12.973 ms; generated nodes 1,716; collision objects 411. Automated traversal duration (43.018 s) is deliberately frame-stepped test time, not a gameplay-frame metric. The windowed evidence run used Vulkan Forward+ on an NVIDIA GeForce RTX 4080 and completed eight captures in 1.092 s, but composition capture timing is not claimed as gameplay GPU performance.

## Evidence and human checklist

Receipt: `art/renders/orison_v2/m08_integrated_checkpoint_01/scene_capture_receipt.json`

Review the numbered frames for: street entrance legibility; lobby orientation and visible upward choice; stair cue; recognizable 2A threshold; return-core cue; recognizable 4B threshold; terminal/home context; and bedside exit direction. Automation proves clearance only. Human route-readability acceptance remains explicitly pending.

## Deviations, risks, and recommendation

Integration exposed two earlier-blockout defects: the U-turn landing lacked capsule standing depth, and the upper north landing slab reduced crossover headroom. Both received development-v2-only geometric corrections and the full schema/blockout suite plus continuous traversal passed afterward. Godot reports four ObjectDB instances/two resources at test shutdown; this is a test teardown warning, not a route failure, and remains cleanup debt. GPU gameplay-frame timing remains unavailable from the headless traversal.

M08 is technically ready as a bounded development checkpoint. Do **not** begin M09 yet: human route-readability acceptance is pending, and production cutover, v1 retirement, and M09 remain separately unauthorized.
