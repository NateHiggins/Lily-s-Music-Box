Explicit composed diagnostic board; not a second full execution.

# Gate board - e9df01d2babb

- commit `e9df01d2babb6e751ebb302522fe9898fed8823d`
- tree `bc609524dc9a7b68a2c91772a3b38c92871f79b0`
- created 2026-10-22T17:20:55Z
- dirty paths: 2598

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 0.34 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.66 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 12.38 | defects 2 |
| v2_mesh_uv_imports | PASS | 0 | 0.09 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.3 | no defects counted |
| ledger | INCOMPLETE | 2 | 25.86 | blockers 7 / 42 / 110 / 8 / 134 / 136; requirements 240 |
| spatial | PASS | 0 | 5.25 | drift.new_reported 7 |
| systemic | PASS | 0 | 3.28 | drift.new_review 21 |
| period | PASS | 0 | 1.17 | no defects counted |
| reader | PASS | 0 | 3.47 | unread 1108; vs frozen baseline: new 0, resolved 200 |
| carriers | PASS | 0 | 0.8 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 178.14 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.39 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.36 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.39 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.52 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 4.92 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.03 | ran 3, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.25 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.28 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.27 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.19 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.31 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 8.28 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.22 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.19 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.28 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.62 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.5 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 1.12 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.11 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.64 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.38 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.62 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.3 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 3.17 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.69 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.22 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.22 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.45 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.3 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 6.0 | ran 59, failed 0 |
| test:test_orison_v2_completeness | FAIL | 1 | 62.0 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.53 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.72 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.59 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.67 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.42 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.12 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.77 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 12.09 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 88.83 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 16.42 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 90.56 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 67.08 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.38 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.59 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.36 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.3 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.59 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 2.94 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.22 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.12 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.31 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.34 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.16 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.2 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.3 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.22 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.19 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.11 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.42 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 22.31 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.27 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.56 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.61 | ran 5, failed 0 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.17 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.17 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.14 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.2 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.23 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.38 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.36 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.14 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.23 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.52 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.36 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.69 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.3 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 189.33 | ran 32, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.14 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.58 | ran 19, failed 0 |

## Against b98efbd32763

Verdict: **NO REGRESSIONS**

requirements_changed: []

### Regressions (0)

- none

### Improvements (9)

- spatial: FAIL -> PASS
- spatial: drift.new_failing 1 -> 0
- spatial: resolved new_failing:624e888547a3c32c
- test:test_nook_readable_books: FAIL -> PASS
- test:test_nook_readable_books: failed 1 -> 0
- test:test_nook_readable_books: resolved test_manufactured_outputs_bind_current_source (__main__.NookBooksTests.test_manufactured_outputs_bind_current_source)
- test:test_orison_spatial_dependencies: FAIL -> PASS
- test:test_orison_spatial_dependencies: failed 1 -> 0
- test:test_orison_spatial_dependencies: resolved test_live_check_is_clean (__main__.ProductionSmokeTests.test_live_check_is_clean)

### Other changes (0)

- none
