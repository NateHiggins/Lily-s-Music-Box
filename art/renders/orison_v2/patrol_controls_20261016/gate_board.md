# Gate board - 6620ec3a042d

- commit `6620ec3a042d062f062aa25f2ea0af57a90e48f8`
- tree `fdda32b9abe9e5d4865eceee2cf3b44c40c10edc`
- created 2026-10-16T17:21:10Z
- dirty paths: 1461

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_surface_qualification | PASS | 0 | 4.05 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.08 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.28 | no defects counted |
| ledger | INCOMPLETE | 2 | 35.23 | blockers 0 / 1 / 48 / 25 / 65 / 67; requirements 240 |
| spatial | PASS | 0 | 4.83 | no defects counted |
| systemic | PASS | 0 | 2.86 | drift.new_review 21 |
| period | PASS | 0 | 1.05 | no defects counted |
| reader | PASS | 0 | 3.34 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.66 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 30.23 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.28 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.38 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.75 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.59 | ran 26, failed 0 |
| test:test_gate_board | PASS | 0 | 0.2 | ran 15, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.61 | ran 4, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.81 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.03 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.58 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.42 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.62 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.28 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 2.33 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.09 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.59 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.17 | ran 22, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.28 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 5.92 | ran 56, failed 0 |
| test:test_orison_v2_completeness | PASS | 0 | 109.25 | ran 108, failed 0 |
| test:test_period_dates | PASS | 0 | 0.44 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.41 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.33 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.8 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.7 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 6.11 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 78.31 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 12.58 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 81.8 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 59.81 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.31 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.3 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.23 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 5.3 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.28 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.3 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.47 | ran 6, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 6.02 | ran 19, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.48 | ran 19, failed 0 |

## Against b112e625648d

Verdict: **NO REGRESSIONS**

requirements_changed: []

### Regressions (0)

- none

### Improvements (0)

- none

### Other changes (0)

- none

