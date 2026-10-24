# Gate board - 21f0b1fc27ac

- commit `21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede`
- tree `513a57f34f50295e9ba1c1ba50ea451e7ea6c3bb`
- created 2026-10-21T11:22:56Z
- dirty paths: 775

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | PASS | 0 | 0.34 | no defects counted |
| v2_recipe_projections | PASS | 0 | 0.66 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 9.92 | defects 2 |
| v2_mesh_uv_imports | PASS | 0 | 0.06 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.47 | no defects counted |
| ledger | INCOMPLETE | 2 | 20.56 | blockers 7 / 8 / 110 / 42 / 134 / 136; requirements 240 |
| spatial | FAIL | 1 | 12.11 | drift.new_failing 1, drift.new_reported 13 |
| systemic | PASS | 0 | 3.06 | drift.new_review 21 |
| period | PASS | 0 | 1.11 | no defects counted |
| reader | PASS | 0 | 3.48 | unread 1109; vs frozen baseline: new 0, resolved 199 |
| carriers | PASS | 0 | 0.75 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 174.52 | no defects counted |
| test:test_additive_material_bindings | PASS | 0 | 0.31 | ran 6, failed 0 |
| test:test_additive_material_rebind | PASS | 0 | 0.11 | ran 8, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.44 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.42 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.12 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 4.11 | ran 6, failed 0 |
| test:test_binding_relief | PASS | 0 | 1.08 | ran 3, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.06 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.22 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.22 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.33 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.42 | ran 29, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.16 | ran 15, failed 0 |
| test:test_grade_source_snapshot | PASS | 0 | 0.2 | ran 3, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.58 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.38 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.84 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 0.91 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.2 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.17 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.17 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.44 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.2 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 6.09 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.11 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.62 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.2 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.16 | ran 1, failed 0 |
| test:test_material_relief | PASS | 0 | 0.33 | ran 5, failed 0 |
| test:test_nook_readable_books | PASS | 0 | 0.16 | ran 4, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.28 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 6.31 | ran 59, failed 1 |
| test:test_orison_v2_completeness | FAIL | 1 | 80.95 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.44 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.31 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.56 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.25 | ran 4, failed 0 |
| test:test_readable_library | PASS | 0 | 0.52 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.36 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.84 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.73 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 9.52 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 67.78 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 10.08 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 71.33 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 50.94 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.12 | ran 11, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.09 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.56 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.28 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.22 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.33 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 2.64 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 5.17 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.09 | ran 1, failed 0 |
| test:test_v2_acoustic_flue | PASS | 0 | 0.3 | ran 10, failed 0 |
| test:test_v2_acoustic_heating | PASS | 0 | 0.28 | ran 10, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.17 | ran 8, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.22 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.22 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.3 | ran 3, failed 0 |
| test:test_v2_c_stove_stack_plan | PASS | 0 | 0.19 | ran 10, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.11 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.33 | ran 6, failed 0 |
| test:test_v2_flue_airway_plan | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_v2_flue_native_evidence | PASS | 0 | 17.23 | ran 1, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.19 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.5 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.58 | ran 5, failed 0 |
| test:test_v2_ground_probe_updates | PASS | 0 | 0.14 | ran 3, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.09 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.09 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.09 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.31 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.14 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.0 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.33 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.34 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.11 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.14 | ran 5, failed 0 |
| test:test_v2_retained_grade_plan | PASS | 0 | 0.16 | ran 9, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.44 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.34 | ran 7, failed 0 |
| test:test_v2_spatial_publication | PASS | 0 | 0.47 | ran 11, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.2 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 169.03 | ran 32, failed 0 |
| test:test_v2_test_dependency_literals | PASS | 0 | 0.12 | ran 2, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.08 | ran 19, failed 0 |

## Against 21f0b1fc27ac

Verdict: **REGRESSED**

requirements_changed: ['contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'job.lena_radiator_round_2b', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR', 'unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']

### Regressions (91)

- ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7
- ledger: blockers.FULL_BUILDING_RUNTIME 26 -> 42
- ledger: blockers.FULL_BUILDING_STRUCTURAL 56 -> 110
- ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8
- ledger: blockers.PRODUCTION_CUTOVER 73 -> 134
- ledger: blockers.V1_RETIREMENT 75 -> 136
- ledger: contract.B1_BOILER_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: contract.F02_B_RADIATOR_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: job.lena_radiator_round_2b RUNTIME_PROVEN -> PROGRAMMED
- ledger: ritual.F01_NIGHT_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_SIGNAL_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_TOUR_KEY_GUARD RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_WATCHMAN_DETECTOR RUNTIME_PROVEN -> SPATIALLY_PROVEN
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
- spatial: PASS -> FAIL (exit 0 -> 1)
- spatial: drift.new_failing 0 -> 1
- spatial: drift.new_reported 4 -> 13
- spatial: new defect new_failing:e3bfbde6c2455192
- spatial: new defect new_reported:11b9de3c24918db8
- spatial: new defect new_reported:39474a8145d31585
- spatial: new defect new_reported:3a280e8394d69e6a
- spatial: new defect new_reported:4896ccb94b81f830
- spatial: new defect new_reported:53d239a1bb2c9b88
- spatial: new defect new_reported:84a84a0d32f0c03d
- spatial: new defect new_reported:9a6bf33766d0daec
- spatial: new defect new_reported:bfd85aa7fb30b318
- spatial: new defect new_reported:f1b9e78a8051f54f
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

### Improvements (0)

- none

### Other changes (0)

- none
