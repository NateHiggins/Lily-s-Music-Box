# Candidate verification - c9d2ae174a9e

- candidate `c9d2ae174a9e4a968e7d5e1e70572e56f574be87`
- base `e1311f7aa4fd131b9d6324532e5623babdafbe27`
- merge-base `e1311f7aa4fd131b9d6324532e5623babdafbe27`
- verified 2026-10-20T22:56:54Z from verifier `c9d2ae174a9e`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 103 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 35, 'FULL_BUILDING_STRUCTURAL': 110, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 127, 'V1_RETIREMENT': 129} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 21, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 38, 'V1_RETIREMENT': 40} |
| requirements_changed | ['circ.F01.public_landing', 'circ.F02.service_core', 'circ.F02.service_route', 'circ.F03.public_core', 'circ.F03.public_landing', 'circ.F03.service_core', 'circ.F03.service_route', 'circ.F04.service_core', 'circ.F04.service_route', 'circ.F05.public_core', 'circ.F05.public_landing', 'circ.F05.service_core', 'circ.F05.service_route', 'circ.F06.public_core', 'circ.F06.public_landing', 'circ.F06.service_core', 'circ.F06.service_route', 'contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam', 'region.shops', 'region.street', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 0 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- ledger requirements changed: ['circ.F01.public_landing', 'circ.F02.service_core', 'circ.F02.service_route', 'circ.F03.public_core', 'circ.F03.public_landing', 'circ.F03.service_core', 'circ.F03.service_route', 'circ.F04.service_core', 'circ.F04.service_route', 'circ.F05.public_core', 'circ.F05.public_landing', 'circ.F05.service_core', 'circ.F05.service_route', 'circ.F06.public_core', 'circ.F06.public_landing', 'circ.F06.service_core', 'circ.F06.service_route', 'contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam', 'region.shops', 'region.street', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (103)

- ledger: blockers.FULL_BUILDING_RUNTIME 35 -> 25
- ledger: blockers.FULL_BUILDING_STRUCTURAL 110 -> 21
- ledger: blockers.PRODUCTION_CUTOVER 127 -> 38
- ledger: blockers.V1_RETIREMENT 129 -> 40
- ledger: circ.F01.public_landing PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F02.service_core PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F02.service_route PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F03.public_core PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F03.public_landing PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F03.service_core PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F03.service_route PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F04.service_core PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F04.service_route PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F05.public_core PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F05.public_landing PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F05.service_core PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F05.service_route PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F06.public_core PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F06.public_landing PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F06.service_core PROGRAMMED -> SPATIALLY_PROVEN
- ledger: circ.F06.service_route PROGRAMMED -> SPATIALLY_PROVEN
- ledger: contract.F04_B_BATH PROGRAMMED -> SPATIALLY_PROVEN
- ledger: contract.F04_B_CLOSET PROGRAMMED -> SPATIALLY_PROVEN
- ledger: contract.F04_B_KITCHEN PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.arcade_hall PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.arcade_portal PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.arcade_throat PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.construction_seam PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.shops PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.street PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2B.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2B.sleep PROGRAMMED -> SPATIALLY_PROVEN
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
- ledger: unit.4B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4B.storage PROGRAMMED -> SPATIALLY_PROVEN
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
- test:test_orison_v2_completeness: FAIL -> PASS
- test:test_orison_v2_completeness: failed 1 -> 0
- test:test_orison_v2_completeness: resolved test_played_cohorts_do_not_leak_into_capture_only_history (__main__.LiveRepoSmokeTests.test_played_cohorts_do_not_leak_into_capture_only_history)
- v2_surface_qualification: FAIL -> PASS
- v2_surface_qualification: defects 2 -> 0
- v2_surface_qualification: resolved missing or stale rendered review
- v2_surface_qualification: resolved stale surface qualification: rendering inputs changed

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (0)

- none

MERGE-CANDIDATE c9d2ae174a9e4a968e7d5e1e70572e56f574be87
