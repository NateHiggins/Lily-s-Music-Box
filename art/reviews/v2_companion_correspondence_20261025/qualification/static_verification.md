# Candidate verification - 564ea46bdb63

- candidate `564ea46bdb636d485896980454369d21721a1450`
- base `ecce6e8c28bc68f3390011e64c9b146f7387a9b9`
- merge-base `ecce6e8c28bc68f3390011e64c9b146f7387a9b9`
- verified 2026-10-25T19:47:02Z from verifier `564ea46bdb63`

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

MERGE-CANDIDATE 564ea46bdb636d485896980454369d21721a1450
