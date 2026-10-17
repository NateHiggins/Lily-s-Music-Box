# Candidate verification - 826702562f7f

- candidate `826702562f7faa26051f010e2706eac3482c9600`
- base `e0b0dd293325a49c207785888112262a4990e474`
- merge-base `e0b0dd293325a49c207785888112262a4990e474`
- verified 2026-10-17T16:16:42Z from verifier `826702562f7f`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 91 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 34, 'FULL_BUILDING_STRUCTURAL': 102, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 119, 'V1_RETIREMENT': 121} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 114, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 138, 'V1_RETIREMENT': 140} |
| requirements_changed | ['contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'job.lena_radiator_round_2b', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 25 |

## Blocking reasons (91)

- regression: ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7
- regression: ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 42
- regression: ledger: blockers.FULL_BUILDING_STRUCTURAL 102 -> 114
- regression: ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8
- regression: ledger: blockers.PRODUCTION_CUTOVER 119 -> 138
- regression: ledger: blockers.V1_RETIREMENT 121 -> 140
- regression: ledger: contract.B1_BOILER_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: contract.F02_B_RADIATOR_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: contract.F04_B_BATH SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: contract.F04_B_CLOSET SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: contract.F04_B_KITCHEN SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: job.lena_radiator_round_2b RUNTIME_PROVEN -> PROGRAMMED
- regression: ledger: ritual.F01_NIGHT_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: ritual.F01_SIGNAL_REGISTER RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: ritual.F01_TOUR_KEY_GUARD RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: ritual.F01_WATCHMAN_DETECTOR RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: unit.2A SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2B.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: spatial: PASS -> FAIL (exit 0 -> 5)
- regression: spatial: drift.new_failing 0 -> 27
- regression: spatial: drift.new_reported 0 -> 15
- regression: spatial: drift.stale_preserved 0 -> 1
- regression: spatial: new defect new_failing:0bd8d892556827db
- regression: spatial: new defect new_failing:28eefca2da7f4012
- regression: spatial: new defect new_failing:2955d42f1790aa54
- regression: spatial: new defect new_failing:2d1da5352652d925
- regression: spatial: new defect new_failing:4b361beaddebd14c
- regression: spatial: new defect new_failing:5bea0b0d9192e492
- regression: spatial: new defect new_failing:6372592de7ad6d15
- regression: spatial: new defect new_failing:64f13b7edfd96b2f
- regression: spatial: new defect new_failing:6f3361d9b6100fca
- regression: spatial: new defect new_failing:8bcb5051cf606fb1
- regression: spatial: new defect new_failing:8ea3a964f1ef27fb
- regression: spatial: new defect new_failing:9e8fd18a3f65176c
- regression: spatial: new defect new_failing:9f412a58198eaca2
- regression: spatial: new defect new_failing:a3ea9df579a29c96
- regression: spatial: new defect new_failing:aafab6128a46d8af
- regression: spatial: new defect new_failing:af38fcfe6feb2206
- regression: spatial: new defect new_failing:b7ed75bcb5e0d419
- regression: spatial: new defect new_failing:bb5b5ea40fc00b3c
- regression: spatial: new defect new_failing:be8bef1587c68bca
- regression: spatial: new defect new_failing:c06112129f04ae63
- regression: spatial: new defect new_failing:c0793b8c68768065
- regression: spatial: new defect new_failing:cd9f1ea081ff1e79
- regression: spatial: new defect new_failing:dcee4de31c4dbc7e
- regression: spatial: new defect new_failing:ea6f0f576962b309
- regression: spatial: new defect new_failing:ead3d9bcbca4a06f
- regression: spatial: new defect new_failing:eaf6cc66fe85ba22
- regression: spatial: new defect new_failing:fd711437ffbe3139
- regression: spatial: new defect new_reported:0f0bff46c738c8d3
- regression: spatial: new defect new_reported:12ba5177cdbfb533
- regression: spatial: new defect new_reported:12f564c9554da0a1
- regression: spatial: new defect new_reported:24c55aac6d26345a
- regression: spatial: new defect new_reported:2d2f6802ad2c14cf
- regression: spatial: new defect new_reported:484c1299671c9c5e
- regression: spatial: new defect new_reported:61389e5ff6c7193b
- regression: spatial: new defect new_reported:84ef295b0abe57b7
- regression: spatial: new defect new_reported:90e23897cf075464
- regression: spatial: new defect new_reported:b68c63c167724041
- regression: spatial: new defect new_reported:b732b678578aba9a
- regression: spatial: new defect new_reported:b83aca0e4c1aa060
- regression: spatial: new defect new_reported:c36e6321ff9034cb
- regression: spatial: new defect new_reported:d4e181dac590b686
- regression: spatial: new defect new_reported:e667af037a75aaa4
- regression: spatial: new defect stale_preserved:e7d798aad4ef7f42
- regression: systemic: drift.new_review 21 -> 22
- regression: systemic: new defect new_review:c727358ac9dc394f
- regression: test:test_orison_spatial_dependencies: PASS -> FAIL (exit 0 -> 1)
- regression: test:test_orison_spatial_dependencies: failed 0 -> 1
- regression: test:test_orison_spatial_dependencies: new defect test_live_check_is_clean (__main__.ProductionSmokeTests.test_live_check_is_clean)
- regression: test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- regression: test:test_orison_v2_completeness: failed 0 -> 1
- regression: test:test_orison_v2_completeness: new defect test_live_first_slice_current_checkpoint_has_executed_contracts (__main__.LiveRepoSmokeTests.test_live_first_slice_current_checkpoint_has_executed_contracts)
- regression: test:test_v2_front_trim: new gate is FAIL (exit 1)
- regression: test:test_v2_ventilation_fabric_projection: PASS -> FAIL (exit 0 -> 1)
- regression: test:test_v2_ventilation_fabric_projection: failed 0 -> 1
- regression: test:test_v2_ventilation_fabric_projection: new defect test_roof_and_home_owners_stay_fresh (__main__.VentilationFabricProjectionTest.test_roof_and_home_owners_stay_fresh)
- regression: v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- regression: v2_surface_qualification: defects 0 -> 2
- regression: v2_surface_qualification: new defect missing or stale rendered review
- regression: v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

## Needs human review (not blocking) (3)

- candidate changes 25 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'job.lena_radiator_round_2b', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage']
- Godot suites were not run (--no-godot)

## Regressions (91)

- ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7
- ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 42
- ledger: blockers.FULL_BUILDING_STRUCTURAL 102 -> 114
- ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8
- ledger: blockers.PRODUCTION_CUTOVER 119 -> 138
- ledger: blockers.V1_RETIREMENT 121 -> 140
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
- ledger: unit.4B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4B.storage SPATIALLY_PROVEN -> PROGRAMMED
- spatial: PASS -> FAIL (exit 0 -> 5)
- spatial: drift.new_failing 0 -> 27
- spatial: drift.new_reported 0 -> 15
- spatial: drift.stale_preserved 0 -> 1
- spatial: new defect new_failing:0bd8d892556827db
- spatial: new defect new_failing:28eefca2da7f4012
- spatial: new defect new_failing:2955d42f1790aa54
- spatial: new defect new_failing:2d1da5352652d925
- spatial: new defect new_failing:4b361beaddebd14c
- spatial: new defect new_failing:5bea0b0d9192e492
- spatial: new defect new_failing:6372592de7ad6d15
- spatial: new defect new_failing:64f13b7edfd96b2f
- spatial: new defect new_failing:6f3361d9b6100fca
- spatial: new defect new_failing:8bcb5051cf606fb1
- spatial: new defect new_failing:8ea3a964f1ef27fb
- spatial: new defect new_failing:9e8fd18a3f65176c
- spatial: new defect new_failing:9f412a58198eaca2
- spatial: new defect new_failing:a3ea9df579a29c96
- spatial: new defect new_failing:aafab6128a46d8af
- spatial: new defect new_failing:af38fcfe6feb2206
- spatial: new defect new_failing:b7ed75bcb5e0d419
- spatial: new defect new_failing:bb5b5ea40fc00b3c
- spatial: new defect new_failing:be8bef1587c68bca
- spatial: new defect new_failing:c06112129f04ae63
- spatial: new defect new_failing:c0793b8c68768065
- spatial: new defect new_failing:cd9f1ea081ff1e79
- spatial: new defect new_failing:dcee4de31c4dbc7e
- spatial: new defect new_failing:ea6f0f576962b309
- spatial: new defect new_failing:ead3d9bcbca4a06f
- spatial: new defect new_failing:eaf6cc66fe85ba22
- spatial: new defect new_failing:fd711437ffbe3139
- spatial: new defect new_reported:0f0bff46c738c8d3
- spatial: new defect new_reported:12ba5177cdbfb533
- spatial: new defect new_reported:12f564c9554da0a1
- spatial: new defect new_reported:24c55aac6d26345a
- spatial: new defect new_reported:2d2f6802ad2c14cf
- spatial: new defect new_reported:484c1299671c9c5e
- spatial: new defect new_reported:61389e5ff6c7193b
- spatial: new defect new_reported:84ef295b0abe57b7
- spatial: new defect new_reported:90e23897cf075464
- spatial: new defect new_reported:b68c63c167724041
- spatial: new defect new_reported:b732b678578aba9a
- spatial: new defect new_reported:b83aca0e4c1aa060
- spatial: new defect new_reported:c36e6321ff9034cb
- spatial: new defect new_reported:d4e181dac590b686
- spatial: new defect new_reported:e667af037a75aaa4
- spatial: new defect stale_preserved:e7d798aad4ef7f42
- systemic: drift.new_review 21 -> 22
- systemic: new defect new_review:c727358ac9dc394f
- test:test_orison_spatial_dependencies: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_spatial_dependencies: failed 0 -> 1
- test:test_orison_spatial_dependencies: new defect test_live_check_is_clean (__main__.ProductionSmokeTests.test_live_check_is_clean)
- test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_v2_completeness: failed 0 -> 1
- test:test_orison_v2_completeness: new defect test_live_first_slice_current_checkpoint_has_executed_contracts (__main__.LiveRepoSmokeTests.test_live_first_slice_current_checkpoint_has_executed_contracts)
- test:test_v2_front_trim: new gate is FAIL (exit 1)
- test:test_v2_ventilation_fabric_projection: PASS -> FAIL (exit 0 -> 1)
- test:test_v2_ventilation_fabric_projection: failed 0 -> 1
- test:test_v2_ventilation_fabric_projection: new defect test_roof_and_home_owners_stay_fresh (__main__.VentilationFabricProjectionTest.test_roof_and_home_owners_stay_fresh)
- v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- v2_surface_qualification: defects 0 -> 2
- v2_surface_qualification: new defect missing or stale rendered review
- v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

## Accepted regressions (0)

- none

## Improvements (0)

- none

## Report claims contradicted (0)

- none

## Design doc lint (3)

- INFO design/ORISON_V2_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_FIRST_SLICE_RUNTIME_COMPOSITION_CHECKPOINT_2026-10-11.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_REMAINING_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-13.md: this document changes 0 requirement status(es): no requirement status

## Gates changed by the candidate (25)

- M tools/audit_data_consumption.py
- M tools/audit_orison_v2_completeness.py
- M tools/audit_systemic_situation_authority.py
- A tools/audit_v2_acoustic_ownership.py
- M tools/orison_spatial_dependency_manifest.json
- M tools/tests/test_data_consumption.py
- A tools/tests/test_heating_pipe_fittings.py
- M tools/tests/test_m11c1_runtime_rehearsal.py
- A tools/tests/test_material_catalog_persistence.py
- M tools/tests/test_orison_v2_completeness.py
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
- M tools/tests/test_v2_surface_requirements.py

BLOCKED regression: ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7; regression: ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 42; regression: ledger: blockers.FULL_BUILDING_STRUCTURAL 102 -> 114 (+88 more)
