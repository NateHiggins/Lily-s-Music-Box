# Gate board - e2ffefd8efb3

- commit `e2ffefd8efb30354c3ad0c3518c43204de9226f8`
- tree `463395c96fe010357f5c9224885c597585527cd4`
- created 2026-10-16T18:20:40Z
- dirty paths: 1427

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_surface_qualification | PASS | 0 | 5.36 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.09 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.77 | no defects counted |
| ledger | INCOMPLETE | 2 | 42.25 | blockers 0 / 1 / 48 / 25 / 65 / 67; requirements 240 |
| spatial | PASS | 0 | 9.56 | no defects counted |
| systemic | PASS | 0 | 9.42 | drift.new_review 21 |
| period | PASS | 0 | 1.05 | no defects counted |
| reader | PASS | 0 | 3.67 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.75 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 197.31 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.36 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 4.86 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.74 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 8.86 | ran 26, failed 0 |
| test:test_gate_board | PASS | 0 | 0.19 | ran 15, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 1.62 | ran 4, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 1.06 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.19 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 2.12 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 1.06 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.88 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.97 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.44 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 7.24 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.12 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.77 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.27 | ran 22, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.41 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 6.42 | ran 56, failed 0 |
| test:test_orison_v2_completeness | PASS | 0 | 144.56 | ran 108, failed 0 |
| test:test_period_dates | PASS | 0 | 0.44 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.56 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.17 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.83 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 12.41 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 103.7 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 19.81 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 127.31 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 102.22 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.58 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.23 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.48 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.31 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 7.52 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.14 | ran 1, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.36 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.39 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.48 | ran 6, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.48 | ran 4, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 8.95 | ran 19, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.41 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.98 | ran 19, failed 0 |

## Against 6620ec3a042d

Verdict: **NO REGRESSIONS**

requirements_changed: []

### Regressions (0)

- none

### Improvements (0)

- none

### Other changes (0)

- none

