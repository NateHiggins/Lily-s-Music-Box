# Candidate verification - b8d5e1eae539

- candidate `b8d5e1eae5393e004556c0320f0d4bab95553bfa`
- base `1c319e582f57bc9a505093f1a89146c78562756e`
- merge-base `1c319e582f57bc9a505093f1a89146c78562756e`
- verified 2026-10-08T07:54:17Z from verifier `74056323e122`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 9 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |

## Blocking reasons (9)

- regression: reader: PASS -> FAIL (exit 0 -> 1)
- regression: reader: unread 1124 -> 1131
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|angle_degrees
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|blender_center
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|cap_end_blender_delta
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|cap_lift_m
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|grate_forward_m
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|grate_lift_m
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|grate_parking

## Needs human review (not blocking) (2)

- candidate changes 1 gate file(s); read those diffs before trusting the board
- Godot suites were not run (--no-godot)

## Regressions (9)

- reader: PASS -> FAIL (exit 0 -> 1)
- reader: unread 1124 -> 1131
- reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|angle_degrees
- reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|blender_center
- reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|cap_end_blender_delta
- reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|cap_lift_m
- reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|grate_forward_m
- reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|grate_lift_m
- reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|grate_parking

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

BLOCKED regression: reader: PASS -> FAIL (exit 0 -> 1); regression: reader: unread 1124 -> 1131; regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/household_stoves.json|angle_degrees (+6 more)
