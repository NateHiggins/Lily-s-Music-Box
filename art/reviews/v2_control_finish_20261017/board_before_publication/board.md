# Gate board - 0ae108b720cb

- commit `0ae108b720cb662a8e705d0473189cc979ff836e`
- tree `494bf946f88a5c0b2c18a79b313eee9337e23a4d`
- created 2026-10-18T01:20:40Z
- dirty paths: 1559

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_recipe_projections | PASS | 0 | 0.72 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 6.23 | defects 3 |
| v2_mesh_uv_imports | PASS | 0 | 0.08 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.81 | no defects counted |
| ledger | INCOMPLETE | 2 | 13.39 | blockers 7 / 8 / 114 / 42 / 138 / 140; requirements 240 |
| spatial | FAIL | 5 | 6.3 | drift.new_failing 28, drift.new_reported 49, drift.stale_preserved 1 |
| systemic | PASS | 0 | 3.42 | drift.new_review 26 |
| period | PASS | 0 | 1.28 | no defects counted |
| reader | PASS | 0 | 4.12 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.78 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 197.69 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.45 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 8.89 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.83 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 10.27 | ran 28, failed 0 |
| test:test_gate_board | PASS | 0 | 0.19 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.75 | ran 4, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.45 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 1.0 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.09 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 4.45 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.2 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.27 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 7.2 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.27 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 8.09 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.12 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.78 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.25 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.22 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.33 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 8.36 | ran 56, failed 1 |
| test:test_orison_v2_completeness | FAIL | 1 | 60.0 | ran 108, failed 1 |
| test:test_period_dates | PASS | 0 | 0.58 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.56 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.38 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.25 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.84 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 15.34 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 116.03 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 24.08 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 148.06 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 118.05 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.45 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.23 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.31 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.22 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 7.45 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.12 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.14 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.27 | ran 8, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.42 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.38 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.42 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.28 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.58 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.75 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.16 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.14 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.34 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.17 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.2 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.14 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.2 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.53 | ran 4, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 83.41 | ran 25, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.36 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 3.0 | ran 19, failed 0 |

## Against cc77be1a8473

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (11)

- spatial: new defect new_reported:0b7c83d2f9499576
- spatial: new defect new_reported:2d9f7e3ca708697f
- spatial: new defect new_reported:6cede161e98e6ead
- spatial: new defect new_reported:70575bb2d2d6da15
- spatial: new defect new_reported:96638c16c737db2c
- spatial: new defect new_reported:db94c59b46de5d34
- v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- v2_surface_qualification: defects 0 -> 3
- v2_surface_qualification: new defect missing or stale rendered review
- v2_surface_qualification: new defect runtime contract does not bind the current surface test
- v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

### Improvements (6)

- spatial: resolved new_reported:39b97475764f8dbc
- spatial: resolved new_reported:436511a6fd65a8c8
- spatial: resolved new_reported:84cf1a06e3aa83f7
- spatial: resolved new_reported:c6c55b46684343f2
- spatial: resolved new_reported:c73593759b84c640
- spatial: resolved new_reported:cee6eb9df18aa0a2

### Other changes (3)

- test:test_ingest_retirement: new gate (PASS, exit 0)
- test:test_v2_recipe_projections: new gate (PASS, exit 0)
- v2_recipe_projections: new gate (PASS, exit 0)
