# Candidate verification - 964ac99c006d

- candidate `964ac99c006dda8281d7577e4725b4df41e86a71`
- base `47f4c8b1dac7bdd37fee1f048cadd15bd1a24945`
- merge-base `47f4c8b1dac7bdd37fee1f048cadd15bd1a24945`
- verified 2026-10-25T21:49:55Z from verifier `964ac99c006d`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'FULL_BUILDING_RUNTIME': 42, 'FULL_BUILDING_STRUCTURAL': 110, 'GOLDEN_SHIFT_V2': 8, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 110, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
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

## Design doc lint (0)

- none

## Gates changed by the candidate (0)

- none

MERGE-CANDIDATE 964ac99c006dda8281d7577e4725b4df41e86a71
