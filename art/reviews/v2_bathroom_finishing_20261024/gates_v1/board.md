# Gate board - 1a2029b4044b

- commit `1a2029b4044b7cc51f85de7c598dd905a40f80ac`
- tree `c6381a1b4c35d4a5ee3515ae0a5cfe2d746064ea`
- created 2026-10-24T11:13:47Z
- dirty paths: 3369

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | FAIL | 1 | 0.75 | wrong 6 |
| v2_recipe_projections | PASS | 0 | 0.62 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 14.39 | defects 2 |
| v2_mesh_uv_imports | PASS | 0 | 0.08 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.5 | no defects counted |
| ledger | INCOMPLETE | 2 | 26.02 | blockers 7 / 8 / 110 / 42 / 134 / 136; requirements 240 |
| spatial | FAIL | 1 | 5.62 | drift.new_failing 8, drift.new_reported 40 |
| systemic | PASS | 0 | 3.31 | drift.new_review 26 |
| period | PASS | 0 | 1.2 | no defects counted |
| reader | FAIL | 1 | 3.64 | unread 1141; vs frozen baseline: new 33, resolved 200 |
| carriers | PASS | 0 | 0.78 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 194.16 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.45 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.45 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.5 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.56 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.03 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.31 | ran 3, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.23 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.3 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.22 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.19 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 8.89 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.25 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.16 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.26 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.61 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.5 | ran 3, failed 0 |
| test:test_interaction_implementors | FAIL | 1 | 0.95 | ran 31, failed 1 |
| test:test_interaction_prompt_carriers | FAIL | 1 | 1.19 | ran 28, failed 1 |
| test:test_lanes | PASS | 0 | 2.98 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.58 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.45 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.75 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.39 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 8.08 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.14 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.74 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.25 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.19 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.39 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.3 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 7.24 | ran 59, failed 1 |
| test:test_orison_v2_completeness | FAIL | 1 | 63.47 | ran 109, failed 3 |
| test:test_period_dates | PASS | 0 | 0.47 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.52 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.55 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.28 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.61 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.17 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.84 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 12.33 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 92.89 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 18.55 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 95.75 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 70.14 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.39 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.66 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.33 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.31 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.47 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 2.92 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.17 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.14 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.31 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.2 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.22 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.2 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.19 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.36 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 24.67 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.27 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.56 | ran 7, failed 0 |
| test:test_v2_front_trim | FAIL | 1 | 0.55 | ran 5, failed 1 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.19 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.16 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.17 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.36 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.2 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.17 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.45 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.2 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.41 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.41 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.14 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.2 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.53 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.42 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.66 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.3 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 196.97 | ran 32, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.2 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.95 | ran 19, failed 0 |

## Against 5ccd76e7d661

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (10)

- physical_import_sources: wrong 4 -> 6
- physical_import_sources: new defect wrong:game/assets/props/door_casing_mitres.glb.import: settings are untracked
- physical_import_sources: new defect wrong:game/assets/props/door_casing_mitres.glb: model is untracked
- spatial: drift.new_reported 39 -> 40
- spatial: new defect new_reported:8128afb52fce45d3
- test:test_orison_v2_completeness: failed 2 -> 3
- test:test_orison_v2_completeness: new defect test_live_region_axis_names_every_ruled_exterior_region (__main__.LiveRepoSmokeTests.test_live_region_axis_names_every_ruled_exterior_region)
- test:test_v2_front_trim: PASS -> FAIL (exit 0 -> 1)
- test:test_v2_front_trim: failed 0 -> 1
- test:test_v2_front_trim: new defect test_stale_or_missing_source_binding_is_rejected (__main__.FrontTrimTests.test_stale_or_missing_source_binding_is_rejected)

### Improvements (0)

- none

### Other changes (0)

- none

