# Gate board - 4b5340f051ff

- commit `4b5340f051ff838f08d090b68d908a288b1b1608`
- tree `d326395f28714700efeb91a4f03bd097dd539286`
- created 2026-10-17T01:51:06Z
- dirty paths: 1420

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_surface_qualification | FAIL | 1 | 5.33 | defects 2 |
| v2_mesh_uv_imports | PASS | 0 | 0.12 | no defects counted |
| v2_surface_imports | PASS | 0 | 1.0 | no defects counted |
| ledger | INCOMPLETE | 2 | 9.42 | blockers 7 / 8 / 114 / 42 / 138 / 140; requirements 240 |
| spatial | PASS | 0 | 5.23 | drift.new_reported 8 |
| systemic | PASS | 0 | 3.17 | drift.new_review 21 |
| period | PASS | 0 | 1.22 | no defects counted |
| reader | PASS | 0 | 3.66 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.78 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 149.77 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.56 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.8 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.86 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.92 | ran 28, failed 0 |
| test:test_gate_board | PASS | 0 | 0.2 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.14 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 1.42 | ran 4, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.84 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.2 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.64 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.28 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.72 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.23 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 4.55 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.14 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.69 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.22 | ran 22, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.28 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 6.19 | ran 56, failed 0 |
| test:test_orison_v2_completeness | FAIL | 1 | 40.81 | ran 108, failed 1 |
| test:test_period_dates | PASS | 0 | 0.42 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.44 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.28 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.33 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.97 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.75 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 7.69 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 80.28 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 17.38 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 90.45 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 68.78 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.19 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.11 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.27 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.17 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.06 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.22 | ran 8, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.23 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.3 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.34 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.23 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.53 | ran 6, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.09 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.17 | ran 7, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.5 | ran 4, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 15.95 | ran 20, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.58 | ran 19, failed 0 |
