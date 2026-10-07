# Candidate verification - b2cb465c3030

- candidate `b2cb465c30300cbdfed807fbfe599f2935ceb86b`
- base `a37ca398d32e620bdc44f88e1f800acd61da3a53`
- merge-base `a37ca398d32e620bdc44f88e1f800acd61da3a53`
- verified 2026-10-07T09:35:34Z from verifier `b2cb465c3030`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 3 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |
| godot (import) | exit 0 |
| godot (import) | exit 0 |
| godot res://tests/OrisonV2DinerOverheadTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerApparatusTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerUrnsTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerBackbarTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerTillTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerCounterTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2LaundryFittingsTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PhotoProcessTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerReceivingTest.tscn | exit 0, receipt binds |
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

## Improvements (3)

- test:test_m11c1_runtime_rehearsal: FAIL -> PASS
- test:test_m11c1_runtime_rehearsal: failed 1 -> 0
- test:test_m11c1_runtime_rehearsal: resolved setUpClass (__main__.FinalTransactionAndConfigTests)

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (1)

- M tools/orison_spatial_dependency_manifest.json

MERGE-CANDIDATE b2cb465c30300cbdfed807fbfe599f2935ceb86b
