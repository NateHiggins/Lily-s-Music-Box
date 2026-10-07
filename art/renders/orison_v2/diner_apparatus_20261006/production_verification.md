# Candidate verification - fa769b26f075

- candidate `fa769b26f075ef8893ed3b1f50b99110f9ed11d8`
- base `bc94f82cad4e4dd03e099b6550d98f8145427f72`
- merge-base `bc94f82cad4e4dd03e099b6550d98f8145427f72`
- verified 2026-10-07T02:07:20Z from verifier `fa769b26f075`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |
| godot (import) | exit 0 |
| godot (import) | exit 0 |
| godot res://tests/OrisonV2DinerApparatusTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerUrnsTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerBackbarTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerReceivingTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageResidencyTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageLoadTeardownTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ShopSimulationTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ResidentKeyRouteTest.tscn | exit 0, receipt binds |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (2)

- candidate changes 1 gate file(s); read those diffs before trusting the board
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

- M tools/orison_spatial_dependency_manifest.json

MERGE-CANDIDATE fa769b26f075ef8893ed3b1f50b99110f9ed11d8
