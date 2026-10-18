# Gate board - 837fbdef6318

- commit `837fbdef6318ea573e1e9bf6c9e113b9c8d3ae60`
- tree `a6d86794fe106740ff7715e837b740dc8843b8f8`
- created 2026-10-18T04:22:00Z
- dirty paths: 1528

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_recipe_projections | PASS | 0 | 0.62 | no defects counted |
| v2_surface_qualification | PASS | 0 | 5.94 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.08 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.7 | no defects counted |
| ledger | INCOMPLETE | 2 | 16.73 | blockers 0 / 1 / 114 / 35 / 131 / 133; requirements 240 |
| spatial | FAIL | 5 | 5.03 | drift.new_failing 28, drift.new_reported 43, drift.stale_preserved 1 |
| systemic | PASS | 0 | 3.19 | drift.new_review 26 |
| period | PASS | 0 | 1.11 | no defects counted |
| reader | PASS | 0 | 3.48 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.73 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 158.28 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.47 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.81 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.78 | ran 6, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.17 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.38 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 8.05 | ran 28, failed 0 |
| test:test_gate_board | PASS | 0 | 0.2 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.69 | ran 4, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.44 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.92 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 0.97 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.89 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.5 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.66 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.73 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.25 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 6.72 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.14 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.72 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.25 | ran 22, failed 0 |
| test:test_material_catalog_persistence | FAIL | 1 | 0.23 | ran 1, failed 1 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.28 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 6.28 | ran 56, failed 1 |
| test:test_orison_v2_completeness | PASS | 0 | 69.39 | ran 108, failed 0 |
| test:test_period_dates | PASS | 0 | 0.42 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.48 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.33 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.0 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.75 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 10.11 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 88.78 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 16.33 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 93.31 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 68.0 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.3 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.14 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.66 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.28 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.19 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.03 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.14 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.3 | ran 8, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.3 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.59 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.25 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.56 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.73 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.14 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.11 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.12 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.34 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.2 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.25 | ran 11, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.12 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.2 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.47 | ran 4, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.41 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 55.56 | ran 25, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.36 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.62 | ran 19, failed 0 |

## Against a9f61f8bfa30

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (3)

- test:test_material_catalog_persistence: PASS -> FAIL (exit 0 -> 1)
- test:test_material_catalog_persistence: failed 0 -> 1
- test:test_material_catalog_persistence: new defect test_registered_catalog_survives_regeneration (__main__.MaterialCatalogPersistenceTest.test_registered_catalog_survives_regeneration)

### Improvements (0)

- none

### Other changes (3)

- test:test_construction_shed_plan: new gate (PASS, exit 0)
- test:test_construction_shed_uv: new gate (PASS, exit 0)
- test:test_site_softwood_maps: new gate (PASS, exit 0)

