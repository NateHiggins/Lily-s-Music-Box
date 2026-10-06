# Candidate verification - 30b223cb44ca

- candidate `30b223cb44cabce2819c8b2b35e854af39d4296e`
- base `fd273b5ba36672096ab3fd3f105a1d91d64f400b`
- merge-base `fd273b5ba36672096ab3fd3f105a1d91d64f400b`
- verified 2026-10-06T21:12:32Z from verifier `30b223cb44ca`

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
| gates changed by candidate | 0 |
| godot (import) | exit 0 |
| godot (import) | exit 0 |
| godot res://tests/OrisonV2LaundryFittingsTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2LaundryApparatusTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2RadioReceivingTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2PassageResidencyTest.tscn | exit 0, receipt binds |
| godot res://tests/OrisonV2ResidentKeyRouteTest.tscn | exit 0, receipt binds |

## Blocking reasons (3)

- regression: spatial: drift.new_reported 0 -> 2
- regression: spatial: new defect new_reported:9cfcbb83c8f74ca9
- regression: spatial: new defect new_reported:f0910768912fde33

## Needs human review (not blocking) (1)

- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (3)

- spatial: drift.new_reported 0 -> 2
- spatial: new defect new_reported:9cfcbb83c8f74ca9
- spatial: new defect new_reported:f0910768912fde33

## Accepted regressions (0)

- none

## Improvements (0)

- none

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (0)

- none

BLOCKED regression: spatial: drift.new_reported 0 -> 2; regression: spatial: new defect new_reported:9cfcbb83c8f74ca9; regression: spatial: new defect new_reported:f0910768912fde33
