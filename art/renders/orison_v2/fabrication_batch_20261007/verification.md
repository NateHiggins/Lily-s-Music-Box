# Candidate verification - 1c319e582f57

- candidate `1c319e582f57bc9a505093f1a89146c78562756e`
- base `0c3f2bb9a57c3867f03bd2c10ea42d78b7001e4b`
- merge-base `0c3f2bb9a57c3867f03bd2c10ea42d78b7001e4b`
- verified 2026-10-07T12:44:51Z from verifier `1c319e582f57`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 2 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (2)

- candidate changes 2 gate file(s); read those diffs before trusting the board
- Godot suites were not run (--no-godot)

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

## Gates changed by the candidate (2)

- M tools/orison_spatial_dependency_manifest.json
- A tools/tests/test_v2_fabrication_batch.py

MERGE-CANDIDATE 1c319e582f57bc9a505093f1a89146c78562756e
