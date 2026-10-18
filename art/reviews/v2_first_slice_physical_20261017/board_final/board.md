# Gate board - a9f61f8bfa30

- commit `a9f61f8bfa3021c0762c2acc05c75ba7914755e4`
- tree `7429a0ad4fae6a28231460230c8f297cff1223ba`
- created 2026-10-18T03:09:07Z
- dirty paths: 1411

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_recipe_projections | PASS | 0 | 0.64 | no defects counted |
| v2_surface_qualification | PASS | 0 | 6.45 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.08 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.28 | no defects counted |
| ledger | INCOMPLETE | 2 | 23.48 | blockers 0 / 1 / 114 / 35 / 131 / 133; requirements 240 |
| spatial | FAIL | 5 | 6.58 | drift.new_failing 28, drift.new_reported 43, drift.stale_preserved 1 |
| systemic | PASS | 0 | 3.2 | drift.new_review 26 |
| period | PASS | 0 | 1.12 | no defects counted |
| reader | PASS | 0 | 4.52 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.7 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 49.19 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.48 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 4.81 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 13.17 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 2.19 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 14.72 | ran 28, failed 0 |
| test:test_gate_board | PASS | 0 | 0.5 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.28 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 1.42 | ran 4, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.81 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 2.22 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.94 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 3.33 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.42 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.27 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 5.09 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.44 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 4.3 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.38 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 1.05 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.39 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.77 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.55 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 13.55 | ran 56, failed 1 |
| test:test_orison_v2_completeness | PASS | 0 | 76.47 | ran 108, failed 0 |
| test:test_period_dates | PASS | 0 | 1.05 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.81 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.61 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.62 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 3.78 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 1.72 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 11.64 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 83.02 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 19.66 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 81.0 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 59.53 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.45 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.25 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.19 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 5.33 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.11 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.24 | ran 8, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.2 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.31 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.39 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.22 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.52 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.66 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.11 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.3 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.14 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.11 | ran 11, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.12 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.14 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.47 | ran 4, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.25 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 48.22 | ran 25, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.28 | ran 19, failed 0 |

## Against 29226611b5be

Verdict: **NO REGRESSIONS**

requirements_changed: ['contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'job.lena_radiator_round_2b', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR']

### Regressions (0)

- none

### Improvements (15)

- ledger: blockers.FIRST_SLICE_TECHNICAL 7 -> 0
- ledger: blockers.FULL_BUILDING_RUNTIME 42 -> 35
- ledger: blockers.GOLDEN_SHIFT_V2 8 -> 1
- ledger: blockers.PRODUCTION_CUTOVER 138 -> 131
- ledger: blockers.V1_RETIREMENT 140 -> 133
- ledger: contract.B1_BOILER_01 SPATIALLY_PROVEN -> RUNTIME_PROVEN
- ledger: contract.F02_B_RADIATOR_01 SPATIALLY_PROVEN -> RUNTIME_PROVEN
- ledger: job.lena_radiator_round_2b PROGRAMMED -> RUNTIME_PROVEN
- ledger: ritual.F01_NIGHT_REGISTER SPATIALLY_PROVEN -> RUNTIME_PROVEN
- ledger: ritual.F01_SIGNAL_REGISTER SPATIALLY_PROVEN -> RUNTIME_PROVEN
- ledger: ritual.F01_TOUR_KEY_GUARD SPATIALLY_PROVEN -> RUNTIME_PROVEN
- ledger: ritual.F01_WATCHMAN_DETECTOR SPATIALLY_PROVEN -> RUNTIME_PROVEN
- test:test_orison_v2_completeness: FAIL -> PASS
- test:test_orison_v2_completeness: failed 1 -> 0
- test:test_orison_v2_completeness: resolved test_live_first_slice_current_checkpoint_has_executed_contracts (__main__.LiveRepoSmokeTests.test_live_first_slice_current_checkpoint_has_executed_contracts)

### Other changes (1)

- test:test_v2_physical_inputs: new gate (PASS, exit 0)

