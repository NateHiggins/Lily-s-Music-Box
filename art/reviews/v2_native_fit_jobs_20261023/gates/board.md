# Gate board - 7852da8b5eff

- commit `7852da8b5eff593a3144ba8765d156813fd06df0`
- tree `b92b2ac13b6fd757d6d024707b2c7a740692d05b`
- created 2026-10-24T03:12:03Z
- dirty paths: 3028

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | FAIL | 1 | 0.91 | wrong 4 |
| v2_recipe_projections | PASS | 0 | 0.78 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 18.47 | defects 2 |
| v2_mesh_uv_imports | PASS | 0 | 0.11 | no defects counted |
| v2_surface_imports | PASS | 0 | 4.05 | no defects counted |
| ledger | INCOMPLETE | 2 | 30.58 | blockers 7 / 8 / 110 / 42 / 134 / 136; requirements 240 |
| spatial | FAIL | 5 | 12.3 | drift.new_failing 10, drift.new_reported 44, drift.stale_preserved 1 |
| systemic | PASS | 0 | 11.52 | drift.new_review 26 |
| period | PASS | 0 | 1.39 | no defects counted |
| reader | FAIL | 1 | 4.2 | unread 1644; vs frozen baseline: new 536, resolved 200 |
| carriers | PASS | 0 | 0.84 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 178.03 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.42 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.44 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.38 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.59 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.17 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.23 | ran 3, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.39 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.24 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.26 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.19 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.34 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 9.67 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.25 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.2 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.24 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.67 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.47 | ran 3, failed 0 |
| test:test_interaction_implementors | FAIL | 1 | 0.92 | ran 31, failed 1 |
| test:test_interaction_prompt_carriers | FAIL | 1 | 1.09 | ran 28, failed 1 |
| test:test_lanes | PASS | 0 | 2.39 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.99 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.3 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.67 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.38 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 7.95 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.11 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.69 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.25 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.19 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.39 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.3 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 7.16 | ran 59, failed 1 |
| test:test_orison_v2_completeness | FAIL | 1 | 64.75 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.5 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.59 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.5 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.66 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.38 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.14 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.73 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 12.06 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 97.95 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 17.81 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 101.98 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 75.2 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.38 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.62 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.33 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.31 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.42 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 2.83 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.47 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.14 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.36 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.31 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.16 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.19 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.22 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.2 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.11 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.42 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 25.02 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.24 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.56 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.62 | ran 5, failed 0 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.14 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.16 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.31 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.17 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.17 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.42 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.44 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.41 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.16 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.19 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.48 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.42 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.75 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.31 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 203.48 | ran 32, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.19 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 3.11 | ran 19, failed 0 |

## Against 2f5d5ac597e0

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (515)

- reader: unread 1141 -> 1644
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|plain_alpha
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_canopy.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_clock.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_clock.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_clock.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_clock.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_clock.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_clock.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_clock.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_clock.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_lantern.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/arcade_throat.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_pool.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/bar_stage.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/cobbler_fittings.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_apparatus.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_apparatus.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_apparatus.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_apparatus.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_apparatus.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_apparatus.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_apparatus.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_apparatus.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_backbar.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_backbar.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_backbar.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_backbar.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_backbar.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_backbar.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_backbar.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_backbar.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|plain_alpha
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_counter.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|at
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|color
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|font_size
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|labels
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|pixel_size
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|text
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_overhead.json|yaw
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|plain_alpha
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_till.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|plain_alpha
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/diner_urns.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|plain_alpha
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_carboys.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_counter.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|plain_alpha
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|tint
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_cupboard.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|plain_alpha
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_dispensary.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_drawers.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_fountain.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_fountain.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_fountain.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_fountain.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_fountain.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_fountain.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_fountain.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_fountain.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_mortar.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_mortar.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_mortar.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_mortar.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_mortar.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_mortar.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_mortar.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/druggist_mortar.json|tolerance
- reader: new defect FIELD_UNREAD|game/data/orison_v2/funeral_drapes.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/funeral_drapes.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/funeral_drapes.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/funeral_drapes.json|name
- reader: new defect FIELD_UNREAD|game/data/orison_v2/funeral_drapes.json|parts
- ... 315 more in board.json

### Improvements (0)

- none

### Other changes (1)

- spatial: exit 1 -> 5

