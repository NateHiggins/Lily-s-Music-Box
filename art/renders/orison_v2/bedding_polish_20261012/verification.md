# Candidate verification - 06e74bf4cce1

- candidate `06e74bf4cce15e9db61d98fd3defde3608e13103`
- base `e72c8a1c46a905c3ea7ad94206217967b6e78ce8`
- merge-base `e72c8a1c46a905c3ea7ad94206217967b6e78ce8`
- verified 2026-10-12T14:38:01Z from verifier `06e74bf4cce1`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 103, 'FULL_BUILDING_RUNTIME': 34, 'PRODUCTION_CUTOVER': 120, 'V1_RETIREMENT': 122} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 103, 'FULL_BUILDING_RUNTIME': 34, 'PRODUCTION_CUTOVER': 120, 'V1_RETIREMENT': 122} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 0 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (2)

- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (0)

- none

## Report claims contradicted (0)

- none

## Design doc lint (2)

- INFO design/ORISON_V2_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 15 requirement status(es): contract.F04_B_BATH PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_CLOSET PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_KITCHEN PROGRAMMED->SPATIALLY_PROVEN, unit.2A PROGRAMMED->SPATIALLY_PROVEN, unit.2A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.2A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.2B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2B.living PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_COMPLETION_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 0 requirement status(es): no requirement status

## Gates changed by the candidate (0)

- none

MERGE-CANDIDATE 06e74bf4cce15e9db61d98fd3defde3608e13103
