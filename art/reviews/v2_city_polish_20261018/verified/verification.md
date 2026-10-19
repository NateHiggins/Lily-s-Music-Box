# Candidate verification - 30f603c3bdd7

- candidate `30f603c3bdd75ab5557cba15c2db4c9b35be1555`
- base `fa6e8f9762763a0ff369c74ed42aa704b44365e2`
- merge-base `fa6e8f9762763a0ff369c74ed42aa704b44365e2`
- verified 2026-10-19T05:25:05Z from verifier `30f603c3bdd7`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 25, 'FULL_BUILDING_STRUCTURAL': 27, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 44, 'V1_RETIREMENT': 46} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 27, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 44, 'V1_RETIREMENT': 46} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 4 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 4 gate file(s); read those diffs before trusting the board
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

## Gates changed by the candidate (4)

- M tools/orison_spatial_dependency_manifest.json
- A tools/tests/test_city_ground_apron.py
- A tools/tests/test_city_horizon.py
- M tools/tests/test_v2_surface_requirements.py

MERGE-CANDIDATE 30f603c3bdd75ab5557cba15c2db4c9b35be1555
