# Candidate verification - 06afe50a3706

- candidate `06afe50a37062889bd2098ced99f00a09d7c5ed1`
- base `4887f644b9081f78bfcba317cadaa796d9bb009e`
- merge-base `4887f644b9081f78bfcba317cadaa796d9bb009e`
- verified 2026-10-19T05:46:53Z from verifier `06afe50a3706`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 9 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 25, 'FULL_BUILDING_STRUCTURAL': 27, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 44, 'V1_RETIREMENT': 46} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 21, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 38, 'V1_RETIREMENT': 40} |
| requirements_changed | ['region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam', 'region.shops', 'region.street'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 4 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (4)

- candidate changes 4 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam', 'region.shops', 'region.street']
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (9)

- ledger: blockers.FULL_BUILDING_STRUCTURAL 27 -> 21
- ledger: blockers.PRODUCTION_CUTOVER 44 -> 38
- ledger: blockers.V1_RETIREMENT 46 -> 40
- ledger: region.arcade_hall PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.arcade_portal PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.arcade_throat PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.construction_seam PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.shops PROGRAMMED -> SPATIALLY_PROVEN
- ledger: region.street PROGRAMMED -> SPATIALLY_PROVEN

## Report claims contradicted (0)

- none

## Design doc lint (1)

- INFO design/ORISON_V2_EXTERIOR_SPATIAL_ACCESS_CHECKPOINT_2026-10-19.md: this document changes 6 requirement status(es): region.arcade_hall PROGRAMMED->SPATIALLY_PROVEN, region.arcade_portal PROGRAMMED->SPATIALLY_PROVEN, region.arcade_throat PROGRAMMED->SPATIALLY_PROVEN, region.construction_seam PROGRAMMED->SPATIALLY_PROVEN, region.shops PROGRAMMED->SPATIALLY_PROVEN, region.street PROGRAMMED->SPATIALLY_PROVEN

## Gates changed by the candidate (4)

- M tools/audit_orison_v2_completeness.py
- M tools/orison_spatial_dependency_manifest.json
- A tools/tests/test_spatial_region_evidence.py
- A tools/tests/test_v2_exterior_source.py

MERGE-CANDIDATE 06afe50a37062889bd2098ced99f00a09d7c5ed1
