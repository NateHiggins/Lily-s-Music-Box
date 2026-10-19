# Candidate verification - 8521e1c4d9c0

- candidate `8521e1c4d9c0af9b013f7e48f9efc0e7f4ee0c20`
- base `8db55d0d0e9c7e4ba06829dd0d3be8e70085a469`
- merge-base `8db55d0d0e9c7e4ba06829dd0d3be8e70085a469`
- verified 2026-10-19T09:02:09Z from verifier `8521e1c4d9c0`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 25, 'FULL_BUILDING_STRUCTURAL': 21, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 38, 'V1_RETIREMENT': 40} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 21, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 38, 'V1_RETIREMENT': 40} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 3 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 3 gate file(s); read those diffs before trusting the board
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

## Gates changed by the candidate (3)

- M tools/orison_spatial_dependency_manifest.json
- A tools/tests/test_house_switchboard_native.py
- M tools/tests/test_v2_surface_requirements.py

MERGE-CANDIDATE 8521e1c4d9c0af9b013f7e48f9efc0e7f4ee0c20
