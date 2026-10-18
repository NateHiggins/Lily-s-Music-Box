# Gate board - b8e9a4b12a6f

- commit `b8e9a4b12a6f9dfc72492283b07544174b5d3d70`
- tree `931166716c79ebadb1a005cf8d085fa56f8afbf2`
- created 2026-10-18T06:00:12Z
- dirty paths: 1391

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 0.41 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.67 | no defects counted |
| v2_surface_qualification | PASS | 0 | 5.14 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.11 | no defects counted |
| v2_surface_imports | PASS | 0 | 1.05 | no defects counted |
| ledger | INCOMPLETE | 2 | 16.16 | blockers 0 / 1 / 48 / 25 / 65 / 67; requirements 240 |
| spatial | PASS | 0 | 4.95 | no defects counted |
| systemic | PASS | 0 | 2.98 | drift.new_review 21 |
| period | PASS | 0 | 1.11 | no defects counted |
| reader | PASS | 0 | 3.38 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.72 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 197.06 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.34 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.42 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.75 | ran 6, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.38 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.89 | ran 28, failed 0 |
| test:test_gate_board | PASS | 0 | 0.2 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.61 | ran 4, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.45 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.88 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 0.97 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.92 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.24 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.38 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.8 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.28 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 6.55 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.67 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.22 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.23 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.31 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 6.39 | ran 59, failed 0 |
| test:test_orison_v2_completeness | FAIL | 1 | 90.09 | ran 108, failed 2 |
| test:test_period_dates | PASS | 0 | 0.5 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.53 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.42 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.39 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.03 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.75 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 10.91 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 115.66 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 19.05 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 117.38 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 88.62 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 3.72 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.38 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 1.66 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.61 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.38 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 19.78 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.5 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.47 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.42 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.8 | ran 8, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 2.83 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.61 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.67 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 1.11 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.47 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 1.09 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 1.45 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.25 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.25 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.25 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.58 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.27 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.28 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.8 | ran 11, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.17 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.22 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.72 | ran 4, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.34 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 59.5 | ran 25, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.69 | ran 19, failed 0 |

## Against e0b0dd293325

Verdict: **REGRESSED**

requirements_changed: ['unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']

### Regressions (4)

- test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_v2_completeness: failed 0 -> 2
- test:test_orison_v2_completeness: new defect test_live_acceptance_grants_spatial_only (__main__.LiveRepoSmokeTests.test_live_acceptance_grants_spatial_only)
- test:test_orison_v2_completeness: new defect test_live_production_blockers_are_whole_building (__main__.LiveRepoSmokeTests.test_live_production_blockers_are_whole_building)

### Improvements (58)

- ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 25
- ledger: blockers.FULL_BUILDING_STRUCTURAL 102 -> 48
- ledger: blockers.PRODUCTION_CUTOVER 119 -> 65
- ledger: blockers.V1_RETIREMENT 121 -> 67
- ledger: unit.3A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.entry PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.entry PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.entry PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C.sleep PROGRAMMED -> SPATIALLY_PROVEN

### Other changes (26)

- physical_import_sources: new gate (PASS, exit 0)
- test:test_construction_shed_plan: new gate (PASS, exit 0)
- test:test_construction_shed_uv: new gate (PASS, exit 0)
- test:test_heating_pipe_fittings: new gate (PASS, exit 0)
- test:test_ingest_retirement: new gate (PASS, exit 0)
- test:test_material_catalog_persistence: new gate (PASS, exit 0)
- test:test_physical_import_sources: new gate (PASS, exit 0)
- test:test_site_softwood_maps: new gate (PASS, exit 0)
- test:test_spatial_binding_preflight: new gate (PASS, exit 0)
- test:test_v2_acoustic_ownership: new gate (PASS, exit 0)
- test:test_v2_acoustic_ventilation: new gate (PASS, exit 0)
- test:test_v2_audit_digest_snapshot: new gate (PASS, exit 0)
- test:test_v2_front_lighting_plan: new gate (PASS, exit 0)
- test:test_v2_front_lighting_projection: new gate (PASS, exit 0)
- test:test_v2_front_trim: new gate (PASS, exit 0)
- test:test_v2_heating_branch_supports: new gate (PASS, exit 0)
- test:test_v2_heating_envelopes: new gate (PASS, exit 0)
- test:test_v2_heating_interfaces: new gate (PASS, exit 0)
- test:test_v2_heating_refit_projection: new gate (PASS, exit 0)
- test:test_v2_heating_routes: new gate (PASS, exit 0)
- test:test_v2_heating_takeoff: new gate (PASS, exit 0)
- test:test_v2_physical_inputs: new gate (PASS, exit 0)
- test:test_v2_radiator_vent_thread: new gate (PASS, exit 0)
- test:test_v2_recipe_projections: new gate (PASS, exit 0)
- test:test_v2_surface_publication: new gate (PASS, exit 0)
- v2_recipe_projections: new gate (PASS, exit 0)

