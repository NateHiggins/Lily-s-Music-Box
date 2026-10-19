# Candidate verification - 6529faf556a9

- candidate `6529faf556a9d1e5e11c5d8ab0147b276714018c`
- base `82887a14d08357a400047624a6ce720351a748e0`
- merge-base `82887a14d08357a400047624a6ce720351a748e0`
- verified 2026-10-19T17:32:29Z from verifier `6529faf556a9`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 114 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 25, 'FULL_BUILDING_STRUCTURAL': 21, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 38, 'V1_RETIREMENT': 40} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 110, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
| requirements_changed | ['circ.F01.public_landing', 'circ.F02.service_core', 'circ.F02.service_route', 'circ.F03.public_core', 'circ.F03.public_landing', 'circ.F03.service_core', 'circ.F03.service_route', 'circ.F04.service_core', 'circ.F04.service_route', 'circ.F05.public_core', 'circ.F05.public_landing', 'circ.F05.service_core', 'circ.F05.service_route', 'circ.F06.public_core', 'circ.F06.public_landing', 'circ.F06.service_core', 'circ.F06.service_route', 'contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'job.lena_radiator_round_2b', 'region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam', 'region.shops', 'region.street', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 5 |

## Blocking reasons (114)

- regression: ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7
- regression: ledger: blockers.FULL_BUILDING_RUNTIME 25 -> 42
- regression: ledger: blockers.FULL_BUILDING_STRUCTURAL 21 -> 110
- regression: ledger: blockers.GOLDEN_SHIFT_V2 1 -> 8
- regression: ledger: blockers.PRODUCTION_CUTOVER 38 -> 134
- regression: ledger: blockers.V1_RETIREMENT 40 -> 136
- regression: ledger: circ.F01.public_landing SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F02.service_core SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F02.service_route SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F03.public_core SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F03.public_landing SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F03.service_core SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F03.service_route SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F04.service_core SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F04.service_route SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F05.public_core SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F05.public_landing SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F05.service_core SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F05.service_route SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F06.public_core SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F06.public_landing SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F06.service_core SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: circ.F06.service_route SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: contract.B1_BOILER_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: contract.F02_B_RADIATOR_01 RUNTIME_PROVEN -> SPATIALLY_PROVEN
- regression: ledger: contract.F04_B_BATH SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: contract.F04_B_CLOSET SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: contract.F04_B_KITCHEN SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: job.lena_radiator_round_2b RUNTIME_PROVEN -> PROGRAMMED
- regression: ledger: region.arcade_hall SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: region.arcade_portal SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: region.arcade_throat SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: region.construction_seam SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: region.shops SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: region.street SPATIALLY_PROVEN -> PROGRAMMED
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
- regression: ledger: unit.3A SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3A.entry SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3A.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3A.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3B SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3B.entry SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3B.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.3B.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4A SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4A.entry SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4A.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4A.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5A SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5A.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5A.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5B SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5B.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5B.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5C SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5C.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5C.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.5C.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6A SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6A.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6A.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6B SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6B.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6B.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6C SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6C.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6C.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6C.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.6C.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- regression: test:test_orison_v2_completeness: failed 0 -> 2
- regression: test:test_orison_v2_completeness: new defect test_live_first_slice_current_checkpoint_has_executed_contracts (__main__.LiveRepoSmokeTests.test_live_first_slice_current_checkpoint_has_executed_contracts)
- regression: test:test_orison_v2_completeness: new defect test_played_cohorts_do_not_leak_into_capture_only_history (__main__.LiveRepoSmokeTests.test_played_cohorts_do_not_leak_into_capture_only_history)
- regression: v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- regression: v2_surface_qualification: defects 0 -> 3
- regression: v2_surface_qualification: new defect missing or stale rendered review
- regression: v2_surface_qualification: new defect runtime contract does not bind the current surface test
- regression: v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

## Needs human review (not blocking) (4)

- candidate changes 5 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['circ.F01.public_landing', 'circ.F02.service_core', 'circ.F02.service_route', 'circ.F03.public_core', 'circ.F03.public_landing', 'circ.F03.service_core', 'circ.F03.service_route', 'circ.F04.service_core', 'circ.F04.service_route', 'circ.F05.public_core', 'circ.F05.public_landing', 'circ.F05.service_core', 'circ.F05.service_route', 'circ.F06.public_core', 'circ.F06.public_landing', 'circ.F06.service_core', 'circ.F06.service_route', 'contract.B1_BOILER_01', 'contract.F02_B_RADIATOR_01', 'contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'job.lena_radiator_round_2b', 'region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam', 'region.shops', 'region.street', 'ritual.F01_NIGHT_REGISTER', 'ritual.F01_SIGNAL_REGISTER', 'ritual.F01_TOUR_KEY_GUARD', 'ritual.F01_WATCHMAN_DETECTOR', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (114)

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
- test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_v2_completeness: failed 0 -> 2
- test:test_orison_v2_completeness: new defect test_live_first_slice_current_checkpoint_has_executed_contracts (__main__.LiveRepoSmokeTests.test_live_first_slice_current_checkpoint_has_executed_contracts)
- test:test_orison_v2_completeness: new defect test_played_cohorts_do_not_leak_into_capture_only_history (__main__.LiveRepoSmokeTests.test_played_cohorts_do_not_leak_into_capture_only_history)
- v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- v2_surface_qualification: defects 0 -> 3
- v2_surface_qualification: new defect missing or stale rendered review
- v2_surface_qualification: new defect runtime contract does not bind the current surface test
- v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

## Accepted regressions (0)

- none

## Improvements (0)

- none

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (5)

- M tools/interaction_implementor_manifest.json
- M tools/orison_spatial_dependency_manifest.json
- M tools/tests/test_interaction_implementors.py
- M tools/tests/test_interaction_prompt_carriers.py
- M tools/tests/test_v2_surface_requirements.py

BLOCKED regression: ledger: blockers.FIRST_SLICE_TECHNICAL 0 -> 7; regression: ledger: blockers.FULL_BUILDING_RUNTIME 25 -> 42; regression: ledger: blockers.FULL_BUILDING_STRUCTURAL 21 -> 110 (+111 more)
