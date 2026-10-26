# Candidate verification - f54ad2a323d7

- candidate `f54ad2a323d793a72bcf95b16e8e74b3681de13c`
- base `4dec20aa369ea24a1c237317e11b4a1abbbd60cd`
- merge-base `4dec20aa369ea24a1c237317e11b4a1abbbd60cd`
- verified 2026-10-26T22:59:39Z from verifier `f54ad2a323d7`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 5 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'FULL_BUILDING_RUNTIME': 42, 'FULL_BUILDING_STRUCTURAL': 110, 'GOLDEN_SHIFT_V2': 8, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 110, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 7 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 7 gate file(s); read those diffs before trusting the board
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (5)

- v2_surface_qualification: FAIL -> PASS
- v2_surface_qualification: defects 3 -> 0
- v2_surface_qualification: resolved missing or stale rendered review
- v2_surface_qualification: resolved runtime contract does not bind the current surface test
- v2_surface_qualification: resolved stale surface qualification: rendering inputs changed

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (7)

- M tools/audit_v2_surfaces.py
- M tools/lane_common.ps1
- M tools/orison_spatial_dependency_manifest.json
- M tools/run_godot_long_suite.ps1
- M tools/run_godot_serial.ps1
- A tools/tests/test_godot_engine_selection.py
- M tools/tests/test_v2_surface_requirements.py

MERGE-CANDIDATE f54ad2a323d793a72bcf95b16e8e74b3681de13c
