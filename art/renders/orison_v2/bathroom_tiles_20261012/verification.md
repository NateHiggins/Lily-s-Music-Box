# Candidate verification - 8996abf2a326

- candidate `8996abf2a326bdc2ed21775d734d2fa0cc60e8f9`
- base `06e74bf4cce15e9db61d98fd3defde3608e13103`
- merge-base `06e74bf4cce15e9db61d98fd3defde3608e13103`
- verified 2026-10-12T15:59:43Z from verifier `8996abf2a326`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 4 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 103, 'FULL_BUILDING_RUNTIME': 34, 'PRODUCTION_CUTOVER': 120, 'V1_RETIREMENT': 122} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 102, 'FULL_BUILDING_RUNTIME': 34, 'PRODUCTION_CUTOVER': 119, 'V1_RETIREMENT': 121} |
| requirements_changed | ['roof.tank_machinery'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 2 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (4)

- candidate changes 2 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['roof.tank_machinery']
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (4)

- ledger: blockers.FULL_BUILDING_STRUCTURAL 103 -> 102
- ledger: blockers.PRODUCTION_CUTOVER 120 -> 119
- ledger: blockers.V1_RETIREMENT 122 -> 121
- ledger: roof.tank_machinery ABSENT -> SPATIALLY_PROVEN

## Report claims contradicted (0)

- none

## Design doc lint (4)

- INFO design/ORISON_V2_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 15 requirement status(es): contract.F04_B_BATH PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_CLOSET PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_KITCHEN PROGRAMMED->SPATIALLY_PROVEN, unit.2A PROGRAMMED->SPATIALLY_PROVEN, unit.2A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.2A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.2B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2B.living PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_COMPLETION_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_ROOF_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_ROOF_PROGRAM_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 0 requirement status(es): no requirement status

## Gates changed by the candidate (2)

- M tools/orison_spatial_dependency_manifest.json
- M tools/tests/test_orison_v2_completeness.py

MERGE-CANDIDATE 8996abf2a326bdc2ed21775d734d2fa0cc60e8f9
