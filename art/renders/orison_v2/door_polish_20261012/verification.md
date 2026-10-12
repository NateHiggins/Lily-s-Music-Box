# Candidate verification - 777a7ee89988

- candidate `777a7ee89988512a5d8f94c1bf63b156e28b6d8d`
- base `09d0d75d2d8ec9027c8d31e956c9de3adb66e8f4`
- merge-base `09d0d75d2d8ec9027c8d31e956c9de3adb66e8f4`
- verified 2026-10-12T11:50:09Z from verifier `777a7ee89988`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 115, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 132, 'V1_RETIREMENT': 134} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 115, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 132, 'V1_RETIREMENT': 134} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 2 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 2 gate file(s); read those diffs before trusting the board
- Godot suites were not run (--no-godot)
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

## Gates changed by the candidate (2)

- M tools/orison_spatial_dependency_manifest.json
- A tools/tests/test_additive_material_rebind.py

MERGE-CANDIDATE 777a7ee89988512a5d8f94c1bf63b156e28b6d8d
