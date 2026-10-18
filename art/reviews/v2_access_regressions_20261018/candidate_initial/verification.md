# Candidate verification - 042386dc00ae

- candidate `042386dc00aeb2bb9ea3db63551a322b2af62dde`
- base `e0b0dd293325a49c207785888112262a4990e474`
- merge-base `e0b0dd293325a49c207785888112262a4990e474`
- verified 2026-10-18T05:46:01Z from verifier `042386dc00ae`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 18 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 34, 'FULL_BUILDING_STRUCTURAL': 102, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 119, 'V1_RETIREMENT': 121} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 102, 'FULL_BUILDING_RUNTIME': 41, 'PRODUCTION_CUTOVER': 126, 'V1_RETIREMENT': 128} |
| requirements_changed | ['contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'job.lena_radiator_round_2b', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 39 |

## Blocking reasons (18)

- regression: ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7
- regression: ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 41
- regression: ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8
- regression: ledger: blockers.PRODUCTION_CUTOVER 119 -> 126
- regression: ledger: blockers.V1_RETIREMENT 121 -> 128
- regression: ledger: contract.B1_BOILER_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: contract.F02_B_RADIATOR_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: job.lena_radiator_round_2b RUNTIME_PROVEN -> PROGRAMMED
- regression: ledger: ritual.F01_NIGHT_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: ritual.F01_SIGNAL_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: ritual.F01_TOUR_KEY_GUARD RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: ritual.F01_WATCHMAN_DETECTOR RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: spatial: drift.new_reported 0 -> 1
- regression: spatial: new defect new_reported:d88885feefc2fc54
- regression: test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- regression: test:test_orison_v2_completeness: failed 0 -> 2
- regression: test:test_orison_v2_completeness: new defect test_live_acceptance_grants_spatial_only (__main__.LiveRepoSmokeTests.test_live_acceptance_grants_spatial_only)
- regression: test:test_orison_v2_completeness: new defect test_live_first_slice_current_checkpoint_has_executed_contracts (__main__.LiveRepoSmokeTests.test_live_first_slice_current_checkpoint_has_executed_contracts)

## Needs human review (not blocking) (3)

- candidate changes 39 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'job.lena_radiator_round_2b', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR']
- Godot suites were not run (--no-godot)

## Regressions (18)

- ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7
- ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 41
- ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8
- ledger: blockers.PRODUCTION_CUTOVER 119 -> 126
- ledger: blockers.V1_RETIREMENT 121 -> 128
- ledger: contract.B1_BOILER_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: contract.F02_B_RADIATOR_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: job.lena_radiator_round_2b RUNTIME_PROVEN -> PROGRAMMED
- ledger: ritual.F01_NIGHT_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_SIGNAL_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_TOUR_KEY_GUARD RUNTIME_PROVEN -> SPATIALLY_PROVEN
- ledger: ritual.F01_WATCHMAN_DETECTOR RUNTIME_PROVEN -> SPATIALLY_PROVEN
- spatial: drift.new_reported 0 -> 1
- spatial: new defect new_reported:d88885feefc2fc54
- test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_v2_completeness: failed 0 -> 2
- test:test_orison_v2_completeness: new defect test_live_acceptance_grants_spatial_only (__main__.LiveRepoSmokeTests.test_live_acceptance_grants_spatial_only)
- test:test_orison_v2_completeness: new defect test_live_first_slice_current_checkpoint_has_executed_contracts (__main__.LiveRepoSmokeTests.test_live_first_slice_current_checkpoint_has_executed_contracts)

## Accepted regressions (0)

- none

## Improvements (0)

- none

## Report claims contradicted (0)

- none

## Design doc lint (5)

- INFO design/ORISON_V2_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_FIRST_SLICE_RUNTIME_COMPOSITION_CHECKPOINT_2026-10-11.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_HOME_COHORT_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 15 requirement status(es): contract.F04_B_BATH PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_CLOSET PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_KITCHEN PROGRAMMED->SPATIALLY_PROVEN, unit.2A PROGRAMMED->SPATIALLY_PROVEN, unit.2A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.2A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.2B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2B.living PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_REMAINING_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-13.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_ROOF_COHORT_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 0 requirement status(es): no requirement status

## Gates changed by the candidate (39)

- M tools/audit_data_consumption.py
- M tools/audit_orison_spatial_dependencies.py
- M tools/audit_orison_v2_completeness.py
- M tools/audit_systemic_situation_authority.py
- A tools/audit_v2_acoustic_ownership.py
- M tools/audit_v2_surfaces.py
- M tools/gate_board.py
- M tools/orison_spatial_dependency_manifest.json
- M tools/systemic_situation_authority_baseline.json
- A tools/tests/test_construction_shed_plan.py
- A tools/tests/test_construction_shed_uv.py
- M tools/tests/test_data_consumption.py
- A tools/tests/test_heating_pipe_fittings.py
- A tools/tests/test_ingest_retirement.py
- M tools/tests/test_m11c1_runtime_rehearsal.py
- A tools/tests/test_material_catalog_persistence.py
- M tools/tests/test_orison_spatial_dependencies.py
- M tools/tests/test_orison_v2_completeness.py
- A tools/tests/test_physical_import_sources.py
- A tools/tests/test_site_softwood_maps.py
- A tools/tests/test_spatial_binding_preflight.py
- M tools/tests/test_systemic_situation_authority.py
- A tools/tests/test_v2_acoustic_ownership.py
- A tools/tests/test_v2_acoustic_ventilation.py
- A tools/tests/test_v2_audit_digest_snapshot.py
- A tools/tests/test_v2_front_lighting_plan.py
- A tools/tests/test_v2_front_lighting_projection.py
- A tools/tests/test_v2_front_trim.py
- A tools/tests/test_v2_heating_branch_supports.py
- A tools/tests/test_v2_heating_envelopes.py
- A tools/tests/test_v2_heating_interfaces.py
- A tools/tests/test_v2_heating_refit_projection.py
- A tools/tests/test_v2_heating_routes.py
- A tools/tests/test_v2_heating_takeoff.py
- A tools/tests/test_v2_physical_inputs.py
- A tools/tests/test_v2_radiator_vent_thread.py
- A tools/tests/test_v2_recipe_projections.py
- A tools/tests/test_v2_surface_publication.py
- M tools/tests/test_v2_surface_requirements.py

BLOCKED regression: ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7; regression: ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 41; regression: ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8 (+15 more)
