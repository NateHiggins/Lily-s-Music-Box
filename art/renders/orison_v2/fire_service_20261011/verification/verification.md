# Candidate verification - abaea074b27f

- candidate `abaea074b27f2125635341ba4f451bfebf4917fe`
- base `b73a8753615bcbdf4477f1a01ab989f1c08207bb`
- merge-base `b73a8753615bcbdf4477f1a01ab989f1c08207bb`
- verified 2026-10-11T22:23:38Z from verifier `abaea074b27f`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 1 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 144, 'V1_RETIREMENT': 146} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 144, 'V1_RETIREMENT': 146} |
| requirements_changed | ['service.fire_service'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 1 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['service.fire_service']
- Godot suites were not run (--no-godot)

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (1)

- ledger: service.fire_service ABSENT -> PROGRAMMED

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (1)

- M tools/orison_spatial_dependency_manifest.json

MERGE-CANDIDATE abaea074b27f2125635341ba4f451bfebf4917fe
