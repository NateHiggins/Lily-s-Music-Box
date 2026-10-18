# Candidate verification - f0eaf7dceb0e

- candidate `f0eaf7dceb0ebbfe3dbd9785eec82e32cf237e83`
- base `95c1c7be5e91020eae757db7cd7de2faf1bcaca9`
- merge-base `95c1c7be5e91020eae757db7cd7de2faf1bcaca9`
- verified 2026-10-18T21:25:35Z from verifier `f0eaf7dceb0e`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 25, 'FULL_BUILDING_STRUCTURAL': 48, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 65, 'V1_RETIREMENT': 67} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 48, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 65, 'V1_RETIREMENT': 67} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 1 gate file(s); read those diffs before trusting the board
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

## Gates changed by the candidate (1)

- A tools/tests/test_v2_public_landing_footprints.py

MERGE-CANDIDATE f0eaf7dceb0ebbfe3dbd9785eec82e32cf237e83
