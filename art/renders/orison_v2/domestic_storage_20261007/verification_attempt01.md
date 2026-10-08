# Candidate verification - 7b8d8e37c3cc

- candidate `7b8d8e37c3cc687c2fa44fdab00a138074f08149`
- base `1c319e582f57bc9a505093f1a89146c78562756e`
- merge-base `1c319e582f57bc9a505093f1a89146c78562756e`
- verified 2026-10-07T23:57:08Z from verifier `9e08a579a3f7`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 5 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |

## Blocking reasons (5)

- regression: spatial: drift.new_reported 0 -> 4
- regression: spatial: new defect new_reported:134a4e65efa27f6e
- regression: spatial: new defect new_reported:151f1581d6bb34da
- regression: spatial: new defect new_reported:3ccecfa28128f48a
- regression: spatial: new defect new_reported:efdbff2149638fc1

## Needs human review (not blocking) (2)

- candidate changes 1 gate file(s); read those diffs before trusting the board
- Godot suites were not run (--no-godot)

## Regressions (5)

- spatial: drift.new_reported 0 -> 4
- spatial: new defect new_reported:134a4e65efa27f6e
- spatial: new defect new_reported:151f1581d6bb34da
- spatial: new defect new_reported:3ccecfa28128f48a
- spatial: new defect new_reported:efdbff2149638fc1

## Accepted regressions (0)

- none

## Improvements (0)

- none

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (1)

- M tools/orison_spatial_dependency_manifest.json

BLOCKED regression: spatial: drift.new_reported 0 -> 4; regression: spatial: new defect new_reported:134a4e65efa27f6e; regression: spatial: new defect new_reported:151f1581d6bb34da (+2 more)
