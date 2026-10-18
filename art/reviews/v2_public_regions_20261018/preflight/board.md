# Gate board - 9928c34361cb

- commit `9928c34361cb7315270917d4d79c02b137e78a5a`
- tree `cbc762f03718e07ce88a7a1018518f533408f90a`
- created 2026-10-18T17:24:50Z
- dirty paths: 1626

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 0.72 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.64 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 12.8 | defects 2 |
| v2_mesh_uv_imports | PASS | 0 | 0.09 | no defects counted |
| v2_surface_imports | PASS | 0 | 3.92 | no defects counted |
| ledger | INCOMPLETE | 2 | 23.36 | blockers 7 / 8 / 114 / 42 / 138 / 140; requirements 240 |
| spatial | FAIL | 4 | 5.78 | drift.new_reported 3, drift.stale_preserved 1 |
| systemic | PASS | 0 | 3.23 | drift.new_review 21 |
| period | PASS | 0 | 1.16 | no defects counted |
| reader | PASS | 0 | 3.67 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.78 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 187.53 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.11 | ran 5, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.41 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.5 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.41 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.53 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.24 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.17 | ran 8, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.17 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.44 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 10.03 | ran 28, failed 0 |
| test:test_gate_board | PASS | 0 | 0.22 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.78 | ran 4, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.47 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.95 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.31 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.94 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.34 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.73 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.3 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 7.08 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.64 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.27 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.2 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.3 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 7.23 | ran 59, failed 1 |
| test:test_orison_v2_completeness | FAIL | 1 | 52.72 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.45 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.48 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.48 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.39 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.06 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.81 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 12.58 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 95.77 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 18.7 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 105.62 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 72.81 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.26 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.17 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.64 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.33 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.2 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.31 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.16 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.14 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.2 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.28 | ran 8, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.41 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.39 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.38 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.47 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.23 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.61 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.7 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.17 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.14 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.38 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.19 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.28 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.38 | ran 5, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.14 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.2 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.55 | ran 4, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.34 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 62.17 | ran 25, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.38 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.61 | ran 19, failed 0 |

## Against 9928c34361cb

Verdict: **REGRESSED**

requirements_changed: ['contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'job.lena_radiator_round_2b', 'region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']

### Regressions (100)

- ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7
- ledger: blockers.FULL_BUILDING_RUNTIME 25 -> 42
- ledger: blockers.FULL_BUILDING_STRUCTURAL 48 -> 114
- ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8
- ledger: blockers.PRODUCTION_CUTOVER 65 -> 138
- ledger: blockers.V1_RETIREMENT 67 -> 140
- ledger: contract.B1_BOILER_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: contract.F02_B_RADIATOR_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: contract.F04_B_BATH SPATIALLY_PROVEN -> PROGRAMMED
- ledger: contract.F04_B_CLOSET SPATIALLY_PROVEN -> PROGRAMMED
- ledger: contract.F04_B_KITCHEN SPATIALLY_PROVEN -> PROGRAMMED
- ledger: job.lena_radiator_round_2b RUNTIME_PROVEN -> PROGRAMMED
- ledger: ritual.F01_NIGHT_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_SIGNAL_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_TOUR_KEY_GUARD RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_WATCHMAN_DETECTOR RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: unit.2A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2B.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.entry SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.entry SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.entry SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4B.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5C SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5C.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5C.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5C.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C.sleep SPATIALLY_PROVEN -> PROGRAMMED
- spatial: PASS -> FAIL (exit 0 -> 4)
- spatial: drift.new_reported 0 -> 3
- spatial: drift.stale_preserved 0 -> 1
- spatial: new defect new_reported:413f653c83ab1b97
- spatial: new defect new_reported:7a4fb64a0176cf9a
- spatial: new defect new_reported:e06e4b3303396b7f
- spatial: new defect stale_preserved:aa93bcadeb9fb163
- test:test_orison_spatial_dependencies: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_spatial_dependencies: failed 0 -> 1
- test:test_orison_spatial_dependencies: new defect test_live_check_is_clean (__main__.ProductionSmokeTests.test_live_check_is_clean)
- test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_v2_completeness: failed 0 -> 2
- test:test_orison_v2_completeness: new defect test_live_first_slice_current_checkpoint_has_executed_contracts (__main__.LiveRepoSmokeTests.test_live_first_slice_current_checkpoint_has_executed_contracts)
- test:test_orison_v2_completeness: new defect test_played_cohorts_do_not_leak_into_capture_only_history (__main__.LiveRepoSmokeTests.test_played_cohorts_do_not_leak_into_capture_only_history)
- v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- v2_surface_qualification: defects 0 -> 2
- v2_surface_qualification: new defect missing or stale rendered review
- v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

### Improvements (4)

- ledger: region.arcade_hall ABSENT -> PROGRAMMED
- ledger: region.arcade_portal ABSENT -> PROGRAMMED
- ledger: region.arcade_throat ABSENT -> PROGRAMMED
- ledger: region.construction_seam ABSENT -> PROGRAMMED

### Other changes (1)

- test:test_v2_public_regions: new gate (PASS, exit 0)

