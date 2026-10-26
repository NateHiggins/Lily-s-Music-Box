# Gate board - 4dec20aa369e

- commit `4dec20aa369ea24a1c237317e11b4a1abbbd60cd`
- tree `c9f7c3f669d86dc8eb96146e7a80b41237336d90`
- created 2026-10-26T21:15:58Z
- dirty paths: 0

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 1.61 | no defects counted |
| v2_recipe_projections | PASS | 0 | 1.39 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 23.19 | defects 3 |
| v2_mesh_uv_imports | PASS | 0 | 0.39 | no defects counted |
| v2_surface_imports | PASS | 0 | 7.62 | no defects counted |
| ledger | INCOMPLETE | 2 | 33.02 | blockers 7 / 8 / 110 / 42 / 134 / 136; requirements 240 |
| spatial | PASS | 0 | 14.0 | no defects counted |
| systemic | PASS | 0 | 12.89 | drift.new_review 29 |
| period | PASS | 0 | 2.89 | no defects counted |
| reader | PASS | 0 | 3.8 | unread 1102; vs frozen baseline: new 0, resolved 206 |
| carriers | PASS | 0 | 0.81 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 184.94 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.34 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 11, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.38 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.42 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.25 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 4.41 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.19 | ran 3, failed 0 |
| test:test_campaign_weather | PASS | 0 | 0.2 | ran 7, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.12 | ran 8, failed 0 |
| test:test_city_closure_source | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.22 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.22 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.17 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.31 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 9.44 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.2 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.19 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.22 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.67 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.23 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.41 | ran 3, failed 0 |
| test:test_interaction_implementors | FAIL | 1 | 0.97 | ran 31, failed 1 |
| test:test_interaction_prompt_carriers | FAIL | 1 | 1.09 | ran 28, failed 1 |
| test:test_lanes | PASS | 0 | 2.78 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.23 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | FAIL | 1 | 1.47 | ran 11, failed 11 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.39 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 7.99 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.11 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | FAIL | 1 | 0.66 | ran 11, failed 1 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.22 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.19 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.3 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 6.95 | ran 59, failed 0 |
| test:test_orison_v2_completeness | FAIL | 1 | 59.64 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.39 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.53 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.27 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.64 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.34 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.09 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.77 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 10.05 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 76.52 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 14.25 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 77.0 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 55.0 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.25 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.59 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.28 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.26 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.39 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 2.67 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.08 | ran 60, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.31 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.14 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.17 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.27 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.17 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.19 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_v2_door_frame_mitres | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.36 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 20.02 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.2 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.52 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.59 | ran 5, failed 0 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.16 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.16 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.3 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.17 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.11 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.34 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.36 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.11 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.19 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.34 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.58 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.23 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 176.28 | ran 35, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.14 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.33 | ran 19, failed 0 |
