# Gate board - 7283b99b2661

- commit `7283b99b2661368398619145c3cb77822a8b5590`
- tree `abdb84953df9b317dcf1117d5010efbc3f38a4e9`
- created 2026-10-13T16:19:35Z
- dirty paths: 1414

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_surface_qualification | PASS | 0 | 4.23 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.06 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.62 | no defects counted |
| ledger | INCOMPLETE | 2 | 26.55 | blockers 0 / 34 / 102 / 1 / 119 / 121; requirements 240 |
| spatial | PASS | 0 | 4.53 | no defects counted |
| systemic | PASS | 0 | 2.86 | drift.new_review 21 |
| period | PASS | 0 | 1.05 | no defects counted |
| reader | PASS | 0 | 3.19 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.66 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 135.16 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.09 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.08 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 3.44 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.55 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.53 | ran 26, failed 0 |
| test:test_gate_board | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 1.17 | ran 4, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.83 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 0.83 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.56 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.17 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.33 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.19 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 2.66 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.09 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.59 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.16 | ran 22, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.25 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 5.55 | ran 56, failed 0 |
| test:test_orison_v2_completeness | PASS | 0 | 94.02 | ran 108, failed 0 |
| test:test_period_dates | PASS | 0 | 0.36 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.36 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.22 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.25 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.78 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.67 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 7.77 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 77.47 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 11.64 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 86.47 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 56.14 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 0.88 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.09 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.22 | ran 8, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 4.88 | ran 58, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.19 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.27 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.42 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.78 | ran 6, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.78 | ran 4, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 7.19 | ran 19, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 1.75 | ran 19, failed 0 |

## Against cb218439df1f

Verdict: **NO REGRESSIONS**

requirements_changed: []

### Regressions (0)

- none

### Improvements (0)

- none

### Other changes (0)

- none

