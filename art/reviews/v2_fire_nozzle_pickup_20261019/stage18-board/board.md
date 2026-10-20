# Gate board - 82887a14d083

- commit `82887a14d08357a400047624a6ce720351a748e0`
- tree `c3fe9ec4f7e115f36a3346143a5af6c249f42ef0`
- created 2026-10-19T15:47:43Z
- dirty paths: 1778

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| physical_import_sources | FAIL | 1 | 0.75 | wrong 14 |
| v2_recipe_projections | PASS | 0 | 0.64 | no defects counted |
| v2_surface_qualification | FAIL | 1 | 14.09 | defects 2 |
| v2_mesh_uv_imports | PASS | 0 | 0.08 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.75 | no defects counted |
| ledger | INCOMPLETE | 2 | 27.62 | blockers 7 / 8 / 110 / 42 / 134 / 136; requirements 240 |
| spatial | FAIL | 1 | 5.7 | drift.new_failing 2, drift.new_reported 14 |
| systemic | PASS | 0 | 3.09 | drift.new_review 22 |
| period | PASS | 0 | 1.16 | no defects counted |
| reader | PASS | 0 | 3.64 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.75 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 173.84 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_arcade_canopy_shells | PASS | 0 | 0.39 | ran 3, failed 0 |
| test:test_arcade_clock | PASS | 0 | 0.47 | ran 4, failed 0 |
| test:test_arcade_lantern | PASS | 0 | 0.39 | ran 4, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.53 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.03 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 1.22 | ran 8, failed 0 |
| test:test_city_ground_apron | PASS | 0 | 0.28 | ran 2, failed 0 |
| test:test_city_horizon | PASS | 0 | 0.23 | ran 3, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.17 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.39 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 10.12 | ran 28, failed 0 |
| test:test_domestic_objects_bounded_preflight | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_gate_board | PASS | 0 | 0.24 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.77 | ran 4, failed 0 |
| test:test_house_switchboard_native | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.53 | ran 3, failed 0 |
| test:test_interaction_implementors | FAIL | 1 | 0.94 | ran 31, failed 1 |
| test:test_interaction_prompt_carriers | FAIL | 1 | 1.0 | ran 28, failed 1 |
| test:test_lanes | PASS | 0 | 2.7 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.22 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.2 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 4.31 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.33 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 3.81 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.94 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.25 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.19 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.3 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 7.62 | ran 59, failed 1 |
| test:test_orison_v2_completeness | FAIL | 1 | 66.45 | ran 109, failed 2 |
| test:test_period_dates | PASS | 0 | 0.48 | ran 4, failed 0 |
| test:test_physical_import_sources | PASS | 0 | 1.59 | ran 6, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.55 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.34 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.17 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.88 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 13.42 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 98.73 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 19.34 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 114.77 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 89.06 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.22 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.14 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.61 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.3 | ran 9, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.27 | ran 13, failed 0 |
| test:test_spatial_connection_evidence | PASS | 0 | 0.45 | ran 14, failed 0 |
| test:test_spatial_region_evidence | PASS | 0 | 2.97 | ran 18, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.75 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.16 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.34 | ran 10, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.23 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.36 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_v2_exterior_source | PASS | 0 | 0.14 | ran 10, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.41 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.25 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.56 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.72 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.14 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.16 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.19 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.25 | ran 11, failed 0 |
| test:test_v2_public_landing_footprints | PASS | 0 | 0.22 | ran 8, failed 0 |
| test:test_v2_public_landing_programmes | PASS | 0 | 0.38 | ran 11, failed 0 |
| test:test_v2_public_regions | PASS | 0 | 0.39 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.12 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.17 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.53 | ran 4, failed 0 |
| test:test_v2_service_entries | PASS | 0 | 0.38 | ran 7, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.28 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 156.84 | ran 26, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.36 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.92 | ran 19, failed 0 |

## Against 82887a14d083

Verdict: **REGRESSED**

requirements_changed: ['circ.F01.public_landing', 'circ.F02.service_core', 'circ.F02.service_route', 'circ.F03.public_core', 'circ.F03.public_landing', 'circ.F03.service_core', 'circ.F03.service_route', 'circ.F04.service_core', 'circ.F04.service_route', 'circ.F05.public_core', 'circ.F05.public_landing', 'circ.F05.service_core', 'circ.F05.service_route', 'circ.F06.public_core', 'circ.F06.public_landing', 'circ.F06.service_core', 'circ.F06.service_route', 'contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'job.lena_radiator_round_2b', 'region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam', 'region.shops', 'region.street', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']

### Regressions (159)

- ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7
- ledger: blockers.FULL_BUILDING_RUNTIME 25 -> 42
- ledger: blockers.FULL_BUILDING_STRUCTURAL 21 -> 110
- ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8
- ledger: blockers.PRODUCTION_CUTOVER 38 -> 134
- ledger: blockers.V1_RETIREMENT 40 -> 136
- ledger: circ.F01.public_landing SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F02.service_core SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F02.service_route SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F03.public_core SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F03.public_landing SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F03.service_core SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F03.service_route SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F04.service_core SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F04.service_route SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F05.public_core SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F05.public_landing SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F05.service_core SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F05.service_route SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F06.public_core SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F06.public_landing SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F06.service_core SPATIALLY_PROVEN -> PROGRAMMED
- ledger: circ.F06.service_route SPATIALLY_PROVEN -> PROGRAMMED
- ledger: contract.B1_BOILER_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: contract.F02_B_RADIATOR_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: contract.F04_B_BATH SPATIALLY_PROVEN -> PROGRAMMED
- ledger: contract.F04_B_CLOSET SPATIALLY_PROVEN -> PROGRAMMED
- ledger: contract.F04_B_KITCHEN SPATIALLY_PROVEN -> PROGRAMMED
- ledger: job.lena_radiator_round_2b RUNTIME_PROVEN -> PROGRAMMED
- ledger: region.arcade_hall SPATIALLY_PROVEN -> PROGRAMMED
- ledger: region.arcade_portal SPATIALLY_PROVEN -> PROGRAMMED
- ledger: region.arcade_throat SPATIALLY_PROVEN -> PROGRAMMED
- ledger: region.construction_seam SPATIALLY_PROVEN -> PROGRAMMED
- ledger: region.shops SPATIALLY_PROVEN -> PROGRAMMED
- ledger: region.street SPATIALLY_PROVEN -> PROGRAMMED
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
- physical_import_sources: PASS -> FAIL (exit 0 -> 1)
- physical_import_sources: wrong 0 -> 14
- physical_import_sources: new defect wrong:game/assets/props/fire_fold_stock.glb.import: settings are untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_fold_stock.glb: model is untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_hose_rack.glb.import: settings are untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_hose_rack.glb: model is untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_hose_stock.glb.import: settings are untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_hose_stock.glb: model is untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_joint_stock.glb.import: settings are untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_joint_stock.glb: model is untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_nozzle_detail.glb.import: settings are untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_nozzle_detail.glb: model is untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_nozzle_hose.glb.import: settings are untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_nozzle_hose.glb: model is untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_nozzle_joint.glb.import: settings are untracked
- physical_import_sources: new defect wrong:game/assets/props/fire_nozzle_joint.glb: model is untracked
- spatial: PASS -> FAIL (exit 0 -> 1)
- spatial: drift.new_failing 0 -> 2
- spatial: drift.new_reported 0 -> 14
- spatial: new defect new_failing:41f6958445a7f0e2
- spatial: new defect new_failing:ccf11275cbd8162a
- spatial: new defect new_reported:0138b5933032dfb1
- spatial: new defect new_reported:092e4b1a9ab6e438
- spatial: new defect new_reported:13f3909b17f036fe
- spatial: new defect new_reported:1fe22ed5946dd40c
- spatial: new defect new_reported:3a0fb148bf72f83a
- spatial: new defect new_reported:3fbbedb45f34b7f6
- spatial: new defect new_reported:450ba0edc27c373b
- spatial: new defect new_reported:5be2d3dc74295b9b
- spatial: new defect new_reported:6ede5c3bb5e53964
- spatial: new defect new_reported:a158076a1ad2cc5b
- spatial: new defect new_reported:bc8a3a36cc62cd05
- spatial: new defect new_reported:c7d6d6f88e0c9689
- spatial: new defect new_reported:d84f78c69c2cb065
- spatial: new defect new_reported:ebd1301a23460bb9
- systemic: drift.new_review 21 -> 22
- systemic: new defect new_review:f200aa5f88af1d6a
- test:test_interaction_implementors: PASS -> FAIL (exit 0 -> 1)
- test:test_interaction_implementors: failed 0 -> 1
- test:test_interaction_implementors: new defect test_production_census_agrees_with_manifest (__main__.ProductionSmokeTests.test_production_census_agrees_with_manifest)
- test:test_interaction_prompt_carriers: PASS -> FAIL (exit 0 -> 1)
- test:test_interaction_prompt_carriers: failed 0 -> 1
- test:test_interaction_prompt_carriers: new defect test_production_counts_match_interaction_contract (__main__.ProductionSmokeTests.test_production_counts_match_interaction_contract)
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

