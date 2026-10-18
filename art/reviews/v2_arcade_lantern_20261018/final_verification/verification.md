# Candidate verification - cc295929f414

- candidate `cc295929f414f8eab0b96cd2deb1a831af00e498`
- base `f5d617379a3f9148450d5ef5eb36ce86c3c788af`
- merge-base `f5d617379a3f9148450d5ef5eb36ce86c3c788af`
- verified 2026-10-18T14:04:15Z from verifier `cc295929f414`

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
| gates changed by candidate | 3 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 3 gate file(s); read those diffs before trusting the board
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

## Gates changed by the candidate (3)

- M tools/orison_spatial_dependency_manifest.json
- A tools/tests/test_arcade_lantern.py
- M tools/tests/test_check_rulings.py

MERGE-CANDIDATE cc295929f414f8eab0b96cd2deb1a831af00e498
