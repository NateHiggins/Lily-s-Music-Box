# Gate board - 1432ef830415

- commit `1432ef830415596feb60666381c026fe53c39dc6`
- tree `7a9b3789f13c5c29eb4756128827629e91398d26`
- created 2026-10-18T19:05:56Z
- dirty paths: 0

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 1.47 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.62 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 7.67 | defects 3 |
| v2_mesh_uv_imports | PASS | 0 | 0.06 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.88 | no defects counted |
| ledger | INCOMPLETE | 2 | 18.34 | blockers 7 / 8 / 114 / 42 / 138 / 140; requirements 240 |
| spatial | PASS | 0 | 5.23 | drift.new_reported 4 |
| systemic | PASS | 0 | 3.42 | drift.new_review 21 |
| period | PASS | 0 | 1.11 | no defects counted |
| reader | PASS | 0 | 3.31 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.69 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 130.64 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.42 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.17 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 4.66 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.09 | ran 8, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.14 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.31 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.33 | ran 28, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.17 | ran None, failed 0 |
| test:test_gate_board | PASS | 0 | 0.16 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.09 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.64 | ran 4, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.38 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.78 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 0.86 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.8 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.25 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.42 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.58 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.31 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 5.69 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.11 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.64 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.17 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.16 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.33 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 5.81 | ran 59, failed 0 |
| test:test_orison_v2_completeness | FAIL | 1 | 46.55 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.31 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.42 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.27 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.31 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.81 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.69 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 8.56 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 74.34 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 13.42 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 78.19 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 56.11 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.09 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.55 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.25 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.25 | ran 13, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 5.23 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.11 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.22 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.17 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.28 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.36 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.2 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.5 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.66 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.3 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.12 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.39 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.11 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.23 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 60.33 | ran 25, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.27 | ran 19, failed 0 |
