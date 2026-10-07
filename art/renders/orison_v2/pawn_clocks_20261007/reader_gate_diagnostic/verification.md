# Candidate verification - 683b6bc8dddd

- candidate `683b6bc8dddd6f7a5fe0748cca176e424527bf02`
- base `193cce6fc969c7b0477b6d6c1951d4ead0118991`
- merge-base `193cce6fc969c7b0477b6d6c1951d4ead0118991`
- verified 2026-10-07T10:44:23Z from verifier `683b6bc8dddd`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 16 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |
| godot (import) | exit 0 |
| godot (import) | exit 0 |
| godot res://tests/OrisonV2PawnClocksTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ShopSeatingTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2DinerOverheadTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageResidencyTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageLoadTeardownTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ShopSimulationTest.tscn | exit 0, receipt binds |

## Blocking reasons (16)

- regression: reader: PASS -> FAIL (exit 0 -> 1)
- regression: reader: unread 1124 -> 1138
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|asset
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|catalog_key
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|cells
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|expected_triangles
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|high
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|id
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|key
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|low
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|parts
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|plain_alpha
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|replace
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|schema_version
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|tile
- regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|tolerance

## Needs human review (not blocking) (1)

- candidate changes 1 gate file(s); read those diffs before trusting the board

## Regressions (16)

- reader: PASS -> FAIL (exit 0 -> 1)
- reader: unread 1124 -> 1138
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|asset
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|catalog_key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|cells
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|expected_triangles
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|high
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|id
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|key
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|low
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|parts
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|plain_alpha
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|replace
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|schema_version
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|tile
- reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|tolerance

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

BLOCKED regression: reader: PASS -> FAIL (exit 0 -> 1); regression: reader: unread 1124 -> 1138; regression: reader: new defect FIELD_UNREAD|game/data/orison_v2/pawn_clocks.json|asset (+13 more)
