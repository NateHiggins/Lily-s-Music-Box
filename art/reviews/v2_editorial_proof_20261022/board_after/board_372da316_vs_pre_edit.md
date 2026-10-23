# Gate board - 372da3167467

- commit `372da316746735bf68e425389021133428a0a7a3`
- tree `f49b55a3cfb5038d12586d15b7e133b9cab1e309`
- created 2026-10-23T08:53:47Z
- dirty paths: 0

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 0.49 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.74 | no defects counted |
| v2_surface_qualification | PASS | 0 | 13.67 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.12 | no defects counted |
| v2_surface_imports | PASS | 0 | 7.06 | no defects counted |
| ledger | INCOMPLETE | 2 | 29.91 | blockers 0 / 1 / 56 / 26 / 73 / 75; requirements 240 |
| spatial | FAIL | 1 | 11.16 | drift.new_failing 1, drift.new_reported 6 |
| systemic | PASS | 0 | 10.64 | drift.new_review 22 |
| period | PASS | 0 | 1.22 | no defects counted |
| reader | PASS | 0 | 4.17 | unread 1109; vs frozen baseline: new 0, resolved 199 |
| carriers | PASS | 0 | 0.81 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 155.92 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.39 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.39 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.48 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.41 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.42 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.3 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.09 | ran 3, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.11 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.25 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.25 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.22 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 10.5 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.17 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.22 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.56 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.41 | ran 3, failed 0 |
| test:test_interaction_implementors | FAIL | 1 | 0.92 | ran 31, failed 1 |
| test:test_interaction_prompt_carriers | FAIL | 1 | 0.97 | ran 28, failed 1 |
| test:test_lanes | PASS | 0 | 2.44 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.23 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.2 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 3.5 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.44 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 6.75 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.12 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.7 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.23 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.19 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.44 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.19 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.31 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 8.19 | ran 59, failed 1 |
| test:test_orison_v2_completeness | PASS | 0 | 83.23 | ran 109, failed 0 |
| test:test_period_dates | PASS | 0 | 0.48 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.58 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.62 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.3 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.62 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.14 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.83 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 15.31 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 93.94 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 26.06 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 114.16 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 87.97 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.59 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.73 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.38 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.28 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.44 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 3.38 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 7.19 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.14 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.36 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.36 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.16 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.22 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.34 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.41 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.36 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.22 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.14 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.61 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.25 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 26.59 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.23 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.53 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.61 | ran 5, failed 0 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.14 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.16 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.3 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.17 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.05 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.36 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.34 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.12 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.19 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.39 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.56 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.25 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 173.52 | ran 32, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.14 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.17 | ran 19, failed 0 |

## Against 21f0b1fc27ac

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (17)

- spatial: PASS -> FAIL (exit 0 -> 1)
- spatial: drift.new_failing 0 -> 1
- spatial: drift.new_reported 4 -> 6
- spatial: new defect new_failing:b576dbee0adacd93
- spatial: new defect new_reported:59a5ace2277b4c0c
- spatial: new defect new_reported:d3a6cf0baf7052b9
- systemic: drift.new_review 21 -> 22
- systemic: new defect new_review:05c37c55db8f4e67
- test:test_interaction_implementors: PASS -> FAIL (exit 0 -> 1)
- test:test_interaction_implementors: failed 0 -> 1
- test:test_interaction_implementors: new defect test_production_census_agrees_with_manifest (__main__.ProductionSmokeTests.test_production_census_agrees_with_manifest)
- test:test_interaction_prompt_carriers: PASS -> FAIL (exit 0 -> 1)
- test:test_interaction_prompt_carriers: failed 0 -> 1
- test:test_interaction_prompt_carriers: new defect test_production_counts_match_interaction_contract (__main__.ProductionSmokeTests.test_production_counts_match_interaction_contract)
- test:test_orison_spatial_dependencies: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_spatial_dependencies: failed 0 -> 1
- test:test_orison_spatial_dependencies: new defect test_live_check_is_clean (__main__.ProductionSmokeTests.test_live_check_is_clean)

### Improvements (0)

- none

### Other changes (0)

- none

