# Gate board - 93f1b733122c

- commit `93f1b733122cd694623f81e3ac9028bbc356323e`
- tree `b4c298c198e9b7a174f1531c308eb5c232afd169`
- created 2026-10-25T12:22:43Z
- dirty paths: 798

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 1.48 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.66 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 18.12 | defects 3 |
| v2_mesh_uv_imports | PASS | 0 | 0.33 | no defects counted |
| v2_surface_imports | PASS | 0 | 5.64 | no defects counted |
| ledger | INCOMPLETE | 2 | 37.17 | blockers 7 / 8 / 110 / 42 / 134 / 136; requirements 240 |
| spatial | PASS | 0 | 7.97 | no defects counted |
| systemic | PASS | 0 | 3.59 | drift.new_review 28 |
| period | PASS | 0 | 1.23 | no defects counted |
| reader | PASS | 0 | 4.48 | unread 1102; vs frozen baseline: new 0, resolved 206 |
| carriers | PASS | 0 | 0.8 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 233.69 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.34 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 11, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.42 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.3 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 4.41 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.11 | ran 3, failed 0 |
| test:test_campaign_weather | PASS | 0 | 0.2 | ran 7, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.08 | ran 8, failed 0 |
| test:test_city_closure_source | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.22 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.22 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.17 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.31 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 12.91 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.16 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.22 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.09 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.55 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.38 | ran 3, failed 0 |
| test:test_interaction_implementors | FAIL | 1 | 0.83 | ran 31, failed 1 |
| test:test_interaction_prompt_carriers | FAIL | 1 | 0.98 | ran 28, failed 1 |
| test:test_lanes | PASS | 0 | 3.3 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.22 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.7 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | FAIL | 1 | 1.3 | ran 11, failed 11 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.31 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 8.53 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.11 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | FAIL | 1 | 0.61 | ran 11, failed 1 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.22 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.19 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.27 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 9.97 | ran 59, failed 0 |
| test:test_orison_v2_completeness | FAIL | 1 | 91.08 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.44 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.39 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.44 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.3 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.62 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.33 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.98 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.77 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 17.44 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 84.2 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 29.47 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 175.16 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 127.42 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.22 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.14 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.55 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.3 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.27 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.39 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 2.69 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 7.77 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.31 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.28 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.2 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.25 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.17 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.19 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.3 | ran 4, failed 0 |
| test:test_v2_door_frame_mitres | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.14 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.36 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 35.5 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.2 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.52 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.58 | ran 5, failed 0 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.14 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.3 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.17 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.12 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.34 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.36 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.14 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.17 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.34 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.53 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.25 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 345.66 | ran 33, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.16 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.31 | ran 19, failed 0 |

## Against 2b7bf3db948f

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (2)

- v2_surface_qualification: defects 2 -> 3
- v2_surface_qualification: new defect runtime contract does not bind the current surface test

### Improvements (20)

- reader: unread 1106 -> 1102
- reader: resolved FIELD_UNREAD|game/data/resident_animation_profiles.json|display
- reader: resolved FIELD_UNREAD|game/data/resident_animation_profiles.json|slug
- reader: resolved FIELD_UNREAD|game/data/runtime_material_sets.json|metallic
- reader: resolved FILE_UNREAD|game/data/resident_animation_profiles.json|
- spatial: drift.new_reported 2 -> 0
- spatial: resolved new_reported:181303fce6afb35e
- spatial: resolved new_reported:6e912b2821800613
- test:test_house_switchboard_native: FAIL -> PASS
- test:test_house_switchboard_native: failed 1 -> 0
- test:test_house_switchboard_native: resolved test_construction_is_bound_to_current_recipe_and_closed_stock (__main__.NativeSwitchboard.test_construction_is_bound_to_current_recipe_and_closed_stock)
- test:test_material_catalog_persistence: FAIL -> PASS
- test:test_material_catalog_persistence: failed 1 -> 0
- test:test_material_catalog_persistence: resolved test_registered_catalog_survives_regeneration (__main__.MaterialCatalogPersistenceTest.test_registered_catalog_survives_regeneration)
- test:test_nook_readable_books: FAIL -> PASS
- test:test_nook_readable_books: failed 1 -> 0
- test:test_nook_readable_books: resolved test_manufactured_outputs_bind_current_source (__main__.NookBooksTests.test_manufactured_outputs_bind_current_source)
- test:test_readable_library: FAIL -> PASS
- test:test_readable_library: failed 1 -> 0
- test:test_readable_library: resolved test_native_stock_is_closed_and_binds_current_source (__main__.ReadableLibraryTests.test_native_stock_is_closed_and_binds_current_source)

### Other changes (3)

- test:test_campaign_weather: new gate (PASS, exit 0)
- test:test_city_closure_source: new gate (PASS, exit 0)
- test:test_v2_door_frame_mitres: new gate (PASS, exit 0)

