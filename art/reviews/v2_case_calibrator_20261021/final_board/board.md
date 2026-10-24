# Gate board - 0c596a199afa

- commit `0c596a199afa7d5a0b90cb601e21b19cfba26696`
- tree `5ca214e3679bea48e78567187c8be3f45b7e6aee`
- created 2026-10-21T22:04:47Z
- dirty paths: 1552

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 0.41 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.64 | no defects counted |
| v2_surface_qualification | PASS | 0 | 8.22 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.09 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.34 | no defects counted |
| ledger | INCOMPLETE | 2 | 23.34 | blockers 0 / 1 / 21 / 25 / 38 / 40; requirements 240 |
| spatial | PASS | 0 | 5.36 | drift.new_reported 17 |
| systemic | PASS | 0 | 3.75 | drift.new_review 21 |
| period | PASS | 0 | 1.12 | no defects counted |
| reader | PASS | 0 | 3.61 | unread 1109; vs frozen baseline: new 0, resolved 199 |
| carriers | PASS | 0 | 0.83 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 179.84 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.45 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.41 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.36 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.64 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.17 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.19 | ran 3, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.28 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.28 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.22 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.39 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 8.31 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.22 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.17 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.27 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.16 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.61 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.45 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.91 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 0.98 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.72 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.19 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.8 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.33 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 8.05 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.12 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.7 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.22 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.23 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.45 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.2 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.33 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 7.16 | ran 59, failed 0 |
| test:test_orison_v2_completeness | PASS | 0 | 70.3 | ran 109, failed 0 |
| test:test_period_dates | PASS | 0 | 0.56 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.72 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.5 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.66 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.38 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.31 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.92 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 13.5 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 105.69 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 20.62 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 108.56 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 80.64 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.58 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.14 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.72 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.36 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.31 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.56 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 3.05 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.5 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.14 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.36 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.14 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.2 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.42 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.28 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.25 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.53 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.2 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 26.27 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.28 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.56 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.72 | ran 5, failed 0 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.17 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.19 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.19 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.34 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.2 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.48 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.2 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.39 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.44 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.16 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.23 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.52 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.42 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.72 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.28 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 196.09 | ran 32, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.19 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 3.23 | ran 19, failed 0 |

## Against 1e8b332fdfef

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (16)

- spatial: drift.new_reported 2 -> 17
- spatial: new defect new_reported:395b18e17d485646
- spatial: new defect new_reported:4abcec5eb3c253a9
- spatial: new defect new_reported:4ecf4240a09b8ac9
- spatial: new defect new_reported:7cb296dd4c15fde9
- spatial: new defect new_reported:85c0656e4f8b37ad
- spatial: new defect new_reported:88e5aa35d7242728
- spatial: new defect new_reported:8e7b74773a06d70b
- spatial: new defect new_reported:bb2f0b876656e46e
- spatial: new defect new_reported:cc8edbf49f6ea520
- spatial: new defect new_reported:d62c7a873f94fffa
- spatial: new defect new_reported:d9d7267d4a63015d
- spatial: new defect new_reported:df0bbdfbd9e69517
- spatial: new defect new_reported:e51fb11231a05e59
- spatial: new defect new_reported:f3286d079601b16a
- spatial: new defect new_reported:ff88c7cf9888057e

### Improvements (0)

- none

### Other changes (0)

- none

