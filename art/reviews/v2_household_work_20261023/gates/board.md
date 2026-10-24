# Gate board - 2faba6e1eaca

- commit `2faba6e1eaca3429b9ca2fe86489cafb252cc89e`
- tree `9030eda548278642ff1f67afc54d30d70e0aa43f`
- created 2026-10-23T23:02:35Z
- dirty paths: 3029

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | FAIL | 1 | 0.5 | wrong 4 |
| v2_recipe_projections | PASS | 0 | 0.66 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 16.42 | defects 2 |
| v2_mesh_uv_imports | PASS | 0 | 0.09 | no defects counted |
| v2_surface_imports | PASS | 0 | 2.05 | no defects counted |
| ledger | INCOMPLETE | 2 | 34.05 | blockers 7 / 8 / 110 / 42 / 134 / 136; requirements 240 |
| spatial | FAIL | 1 | 6.39 | drift.new_failing 8, drift.new_reported 39 |
| systemic | PASS | 0 | 3.61 | drift.new_review 27 |
| period | PASS | 0 | 1.26 | no defects counted |
| reader | FAIL | 1 | 4.08 | unread 1141; vs frozen baseline: new 33, resolved 200 |
| carriers | PASS | 0 | 0.84 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 182.27 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.47 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.42 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.36 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.66 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.27 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.26 | ran 3, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.25 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.28 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.25 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.19 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.38 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 10.97 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.22 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.2 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.64 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.2 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.48 | ran 3, failed 0 |
| test:test_interaction_implementors | FAIL | 1 | 0.95 | ran 31, failed 1 |
| test:test_interaction_prompt_carriers | FAIL | 1 | 1.25 | ran 28, failed 1 |
| test:test_lanes | PASS | 0 | 2.62 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.84 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.3 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.75 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.34 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 4.05 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.12 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.83 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.7 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.22 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.51 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.19 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.38 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 8.94 | ran 59, failed 1 |
| test:test_orison_v2_completeness | FAIL | 1 | 83.47 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.55 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.69 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.58 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.7 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.39 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.19 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.81 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 17.41 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 108.17 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 25.39 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 124.75 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 98.41 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.69 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.62 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 1.12 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.48 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.33 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.49 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 3.06 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 7.38 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.14 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.36 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.19 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.19 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.28 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.22 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.19 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.36 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.42 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.23 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 31.66 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.25 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.53 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.67 | ran 5, failed 0 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.16 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.17 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.22 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.25 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.41 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.42 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.19 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.19 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.5 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.36 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.64 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.3 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 279.45 | ran 32, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.17 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.84 | ran 19, failed 0 |

## Against 702e14a7e878

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (2)

- systemic: drift.new_review 26 -> 27
- systemic: new defect new_review:100fa9f16fe48c8b

### Improvements (0)

- none

### Other changes (0)

- none

