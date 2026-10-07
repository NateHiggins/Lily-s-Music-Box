# Candidate verification - 0c3f2bb9a57c

- candidate `0c3f2bb9a57c3867f03bd2c10ea42d78b7001e4b`
- base `908d187e5fb4f00016a6c1e8b5a4d6a0386f4491`
- merge-base `908d187e5fb4f00016a6c1e8b5a4d6a0386f4491`
- verified 2026-10-07T12:06:50Z from verifier `0c3f2bb9a57c`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'FULL_BUILDING_RUNTIME': 42, 'FULL_BUILDING_STRUCTURAL': 127, 'GOLDEN_SHIFT_V2': 8, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |
| godot (import) | exit 0 |
| godot (import) | exit 0 |
| godot res://tests/OrisonV2PawnDisplayTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PawnClocksTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ShopSeatingTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageResidencyTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageLoadTeardownTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ShopSimulationTest.tscn | exit 0, receipt binds |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (1)

- candidate changes 1 gate file(s); read those diffs before trusting the board

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

- M tools/orison_spatial_dependency_manifest.json

MERGE-CANDIDATE 0c3f2bb9a57c3867f03bd2c10ea42d78b7001e4b
