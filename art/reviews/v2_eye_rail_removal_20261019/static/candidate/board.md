# Gate board - 22087f20f6a1

- commit `22087f20f6a14b8845e338b17ded103f83c065c0`
- tree `92b4001286ef7a72b44217632c561170eedaaaea`
- created 2026-10-20T00:25:12Z
- dirty paths: 18

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 0.36 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.62 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 6.14 | defects 3 |
| v2_mesh_uv_imports | PASS | 0 | 0.08 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.3 | no defects counted |
| ledger | INCOMPLETE | 2 | 18.25 | blockers 7 / 8 / 110 / 42 / 134 / 136; requirements 240 |
| spatial | PASS | 0 | 5.02 | drift.new_reported 2 |
| systemic | PASS | 0 | 3.03 | drift.new_review 21 |
| period | PASS | 0 | 1.11 | no defects counted |
| reader | PASS | 0 | 3.39 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.72 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 5.2 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.42 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.05 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 4.77 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.02 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.22 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.2 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.31 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.22 | ran 28, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.17 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.09 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.5 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.38 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 1.38 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.09 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.59 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.22 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.39 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.25 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 2.2 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.12 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.58 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.14 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.17 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.27 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 5.89 | ran 59, failed 0 |
| test:test_orison_v2_completeness | FAIL | 1 | 52.58 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.38 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.3 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.28 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.25 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.23 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.81 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.66 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 6.02 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 71.47 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 11.2 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 74.95 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 55.02 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.25 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.59 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.3 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.23 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.39 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 2.73 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 5.36 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.11 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.25 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.16 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.28 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.36 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.2 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.5 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.59 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.11 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.28 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.17 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.28 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.19 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.48 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.36 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.11 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.44 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.34 | ran 7, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.23 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 141.34 | ran 27, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.23 | ran 19, failed 0 |

## Against 22087f20f6a1

Verdict: **NO REGRESSIONS**

requirements_changed: []

### Regressions (0)

- none

### Improvements (3)

- test:test_v2_front_trim: FAIL -> PASS
- test:test_v2_front_trim: failed 1 -> 0
- test:test_v2_front_trim: resolved test_stale_or_missing_source_binding_is_rejected (__main__.FrontTrimTests.test_stale_or_missing_source_binding_is_rejected)

### Other changes (0)

- none

