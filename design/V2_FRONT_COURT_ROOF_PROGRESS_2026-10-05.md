# REPORT - V2 FRONT COURT ROOF - 2026-10-05

Evidence class: **INERT**

## Candidate and result

Branch **main**; verified code HEAD **04aaeb37f224cb3e0df54af2d40645377ccbd05c**; origin/main and merge-base **764c33bd2563053d00d380f412c9918e13bfd913**.
Worktree clean at verification: **yes**. Protected **17/17 unchanged**. Selector **v2**; explicit **ORISON_BUILDING_ROOT=v1** rollback remains. This canonical in-place comparison does not establish fresh-checkout import or autocrlf behavior.
The large gray shape above the entrance is the retained front-court roof slab. Three fitted I-section girders, six knee brackets and 48 anchor/head pairs now meet its actual masonry and slab faces. The exposed underside uses the existing calibrated concrete finish. Roof dimensions, slab thickness, walking surfaces and opening authorities retain their sources.
The native contains **117 positive closed stocks**; the installed export is **25 bounded draws / 5,418 triangles**, with strict metre UVs, corrected tangent handedness and **zero UV fallbacks**. The right masonry face steps from **9.22 m** to **8.02 m** behind the leading bay; the fitted stations follow that source step. Existing catalogue **cast_iron**, **metal** and **concrete** keys supply the finishes. These contacts establish fitted geometry, without asserting engineering capacity.

## Ledger

Before **[7, 8, 127, 42, 151, 153]** -> after **[7, 8, 127, 42, 151, 153]**, ordered first slice / golden shift / structural / runtime / cutover / retirement; requirements_changed **[]**.
**240 requirements**: ABSENT **21**, HUMAN_ACCEPTED **1**, PROGRAMMED **119**, RUNTIME_PROVEN **27**, SHELL_ONLY **3**, SPATIALLY_PROVEN **69**; **2** V1 fallbacks, **117** heuristic conclusions and **1** stale checkpoint identifier. The exact test-written resident-key contract from **4979cfde** is copied as current scoped provenance. Its runtime inputs and key test remain unchanged by the later test-only correction. No architecture or human acceptance status is promoted. Earlier façade contracts remain historical, with stale bindings reported.

## Complete static comparison

**48** gates/tools suites ran; **0 regressions** against the complete clean baseline; reader **0 NEW unread fields**. The known incomplete ledger and existing runtime-rehearsal failure remain visible below. Complete comparison: **tmp/v2-facade/roof-frame-final/verification.json**; baseline: **tmp/v2-facade/764c33bd-clean-board.json**.

| Gate or tools suite | Actual exit |
| --- | --- |
| ledger | 2 |
| spatial | 0 |
| systemic | 0 |
| period | 0 |
| reader | 0 |
| carriers | 0 |
| rulings | 0 |
| test:test_astra_packet | 0 |
| test:test_audio_emitters | 0 |
| test:test_check_rulings | 0 |
| test:test_data_consumption | 0 |
| test:test_gate_board | 0 |
| test:test_honed_stone_maps | 0 |
| test:test_interaction_implementors | 0 |
| test:test_interaction_prompt_carriers | 0 |
| test:test_lanes | 0 |
| test:test_lint_design_doc | 0 |
| test:test_m11c0_floor01_harness_contract | 0 |
| test:test_m11c1_floor01_source_ownership | 0 |
| test:test_m11c1_owner_first_export | 0 |
| test:test_m11c1_runtime_rehearsal | 1 |
| test:test_m11c1_scanner_consumer_adapter | 0 |
| test:test_m11c2_floor01_production_export | 0 |
| test:test_m11c2_production_harness_contract | 0 |
| test:test_orison_floor01_source_ownership | 0 |
| test:test_orison_spatial_dependencies | 0 |
| test:test_orison_v2_completeness | 0 |
| test:test_period_dates | 0 |
| test:test_prop_reference | 0 |
| test:test_prop_review | 0 |
| test:test_rehearse_orison_floor01_partition | 0 |
| test:test_room_checkpoint_linter | 0 |
| test:test_room_checkpoint_reconciler | 0 |
| test:test_room_evidence_verifier | 0 |
| test:test_room_gate_hook | 0 |
| test:test_room_layout_workbench | 0 |
| test:test_room_reconstruction_gate | 0 |
| test:test_room_reconstruction_progress | 0 |
| test:test_run_receipt | 0 |
| test:test_runtime_source_projections | 0 |
| test:test_systemic_situation_authority | 0 |
| test:test_upper_daylight_contract | 0 |
| test:test_v2_authoring_projection | 0 |
| test:test_v2_boiler_inlet_projection | 0 |
| test:test_v2_completion_projection | 0 |
| test:test_v2_roof | 0 |
| test:test_v2_ventilation_fabric_projection | 0 |
| test:test_verify_candidate | 0 |

## Executed renderer and route checks

| Scene | Actual source | Actual exit | Wrapper receipt |
| --- | --- | --- | --- |
| (import) | 04aaeb37 | 0 | [import1.log.receipt.json](../tmp/v2-facade/roof-frame-final/godot/import1.log.receipt.json) |
| (import) | 04aaeb37 | 0 | [import2.log.receipt.json](../tmp/v2-facade/roof-frame-final/godot/import2.log.receipt.json) |
| res://tests/OrisonV2LandingSoffitTest.tscn | 04aaeb37 | 0 | [OrisonV2LandingSoffitTest_tscn_windowed.log.receipt.json](../tmp/v2-facade/roof-frame-final/godot/OrisonV2LandingSoffitTest_tscn_windowed.log.receipt.json) |
| res://tests/OrisonV2FrontCourtRoofTest.tscn | 4979cfde | 0 | [OrisonV2FrontCourtRoofTest_tscn_windowed.log.receipt.json](../tmp/v2-facade/roof-frame-verified/godot/OrisonV2FrontCourtRoofTest_tscn_windowed.log.receipt.json) |
| res://tests/OrisonV2LandingSoffitTest.tscn | 4979cfde | 1 | [OrisonV2LandingSoffitTest_tscn_windowed.log.receipt.json](../tmp/v2-facade/roof-frame-verified/godot/OrisonV2LandingSoffitTest_tscn_windowed.log.receipt.json) |
| res://tests/OrisonV2FrontFacadeTest.tscn | 4979cfde | 0 | [OrisonV2FrontFacadeTest_tscn_windowed.log.receipt.json](../tmp/v2-facade/roof-frame-verified/godot/OrisonV2FrontFacadeTest_tscn_windowed.log.receipt.json) |
| res://tests/OrisonV2RoofRouteTest.tscn | 4979cfde | 0 | [OrisonV2RoofRouteTest_tscn_windowed.log.receipt.json](../tmp/v2-facade/roof-frame-verified/godot/OrisonV2RoofRouteTest_tscn_windowed.log.receipt.json) |
| res://tests/OrisonV2ResidentKeyRouteTest.tscn | 4979cfde | 0 | [OrisonV2ResidentKeyRouteTest_tscn_windowed.log.receipt.json](../tmp/v2-facade/roof-frame-verified/godot/OrisonV2ResidentKeyRouteTest_tscn_windowed.log.receipt.json) |

**OrisonV2FrontCourtRoofTest**: **356 checks, 0 failures**, including all 48 actual masonry anchor seats, 24 shelf/girder samples, nine slab contacts, exact native colliders, bounded draws and calibrated soffit maps.
**OrisonV2FrontFacadeTest**: **666 checks, 0 failures**, at the retained native façade's 59 draws / 8,480 triangles.
**OrisonV2RoofRouteTest**: **53 continuous waypoints, 0 failures**.
**OrisonV2ResidentKeyRouteTest**: **PASS, 85 waypoints / 55 checks**, including permission, a resident-authorized spare, locking, save/reconstruction and zero retained runtime-owned resources. The retained schema-2 contract is the exact test output.
The first **4979cfde** comparison was **BLOCKED** solely by two obsolete single-shape assertions in **OrisonV2LandingSoffitTest**: 2,938 checks, two failures, zero missing/duplicate undersides. The two already-published roof-door landings retain their original boxes plus native curb envelopes. The corrected test now verifies the exact additional imported faces within **20 microns** and rejects missing, duplicated or extra shapes; the other platforms retain the single-box check. No production collider or underside-coverage tolerance changed.
The committed correction passes **3,012 checks**, across **67 platforms / 603 landing stations / 54 room draws / 468 room samples**, with zero failures and zero missing/duplicate undersides. Its final canonical comparison imports twice and passes the windowed suite. The other four suites above retain the production input digest **0944331b38468fb8bd0cd08551b3b6c070ad827a22e423f0567a951465d767da** and unchanged test hashes. They are reported at their actual source, without claiming they were rerun at the later commit. The final verifier accepts no failed suite.
Native inspection reopened the saved Blender file, checked its closed stocks, bindings and relative map paths, and rendered three directly inspected views: **tmp/v2-facade/inspect-front-court-roof.log** and **tmp/v2-facade/roof-frame-native**. Temporary source masonry/slabs are unsaved context. Initial unstepped bearing probes and a compilation-failed frame probe remain diagnostic failures; successful repaired results govern publication.

## Boundaries, open findings and owner decisions

The boundary is the fitted native roof frame, its mount/fixture/test, exposed exterior soffit material selection and fabrication records. The spatial dependency manifest appends three reviewed **ROOF_DECK_** prefix-reader records for the mount and inspections; all prior records remain unchanged. The source dimensions and protected paths retain their owners. No heating cuts or distribution installation was performed. The owner-shot record remains unchanged.
The pre-existing roof illumination failure in **OrisonV2PrimaryLampTest**, residual air settling after camera moves, wider geometry/texture review, independent shop services, the eleven golden beats, whole-building human acceptance and V1 retirement remain open. This batch does not rerun or close the lamp defect documented in **design/V2_FRONT_FACADE_AIR_FINISH_2026-10-05.md**. No owner decision is needed for this scoped façade continuation.

## Retained review

[Street view](../art/renders/orison_v2/front_court_roof_20261005/street.png), [front-court view](../art/renders/orison_v2/front_court_roof_20261005/front_court.png), [native left bearing](../art/renders/orison_v2/front_court_roof_20261005/left_bearing.png) and [exact resident-key runtime contract](../art/renders/orison_v2/front_court_roof_20261005/runtime_authority_receipt.json). The game frames were captured by the source-bound **4979cfde** frame test. The native image verifies form with temporary context materials. Captures and wrapper receipts are inspection evidence; they do not supply runtime or human proof.

MERGE-CANDIDATE 04aaeb37f224cb3e0df54af2d40645377ccbd05c
