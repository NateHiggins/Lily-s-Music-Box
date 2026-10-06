# Candidate verification - 6f120a2bd095

- candidate `6f120a2bd0954a96b14fc3f9a9b81039e66e991d`
- base `855898678cdde755f54e506e10cb577fd20e5828`
- merge-base `855898678cdde755f54e506e10cb577fd20e5828`
- verified 2026-10-06T23:40:04Z from verifier `6f120a2bd095`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 3 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |
| godot (import) | exit 0 |
| godot (import) | exit 0 |
| godot res://tests/OrisonV2DinerReceivingTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageResidencyTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageLoadTeardownTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ShopSimulationTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ResidentKeyRouteTest.tscn | exit 0, receipt binds |

## Blocking reasons (3)

- regression: spatial: drift.new_reported 0 -> 2
- regression: spatial: new defect new_reported:50d9edb7c7287f98
- regression: spatial: new defect new_reported:edc3ee661857e671

## Needs human review (not blocking) (2)

- candidate changes 1 gate file(s); read those diffs before trusting the board
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (3)

- spatial: drift.new_reported 0 -> 2
- spatial: new defect new_reported:50d9edb7c7287f98
- spatial: new defect new_reported:edc3ee661857e671

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

BLOCKED regression: spatial: drift.new_reported 0 -> 2; regression: spatial: new defect new_reported:50d9edb7c7287f98; regression: spatial: new defect new_reported:edc3ee661857e671
