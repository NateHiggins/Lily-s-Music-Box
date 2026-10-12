# Candidate verification - f8bf3b18cdbb

- candidate `f8bf3b18cdbb7ec7fb1eabeff1c0625409c956f3`
- base `e91b81dd653c621d5bee651aeb9152c37bf9ba41`
- merge-base `e91b81dd653c621d5bee651aeb9152c37bf9ba41`
- verified 2026-10-12T05:08:42Z from verifier `f8bf3b18cdbb`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 4 regressions, 5 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 117, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 115, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 132, 'V1_RETIREMENT': 134} |
| requirements_changed | ['floor.ROOF', 'roof.roof_bulkhead'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 3 |

## Blocking reasons (4)

- regression: test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- regression: test:test_orison_v2_completeness: failed 0 -> 2
- regression: test:test_orison_v2_completeness: new defect test_live_first_slice_is_proven_not_complete (__main__.LiveRepoSmokeTests.test_live_first_slice_is_proven_not_complete)
- regression: test:test_orison_v2_completeness: new defect test_live_production_blockers_are_whole_building (__main__.LiveRepoSmokeTests.test_live_production_blockers_are_whole_building)

## Needs human review (not blocking) (3)

- candidate changes 3 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['floor.ROOF', 'roof.roof_bulkhead']
- Godot suites were not run (--no-godot)

## Regressions (4)

- test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_v2_completeness: failed 0 -> 2
- test:test_orison_v2_completeness: new defect test_live_first_slice_is_proven_not_complete (__main__.LiveRepoSmokeTests.test_live_first_slice_is_proven_not_complete)
- test:test_orison_v2_completeness: new defect test_live_production_blockers_are_whole_building (__main__.LiveRepoSmokeTests.test_live_production_blockers_are_whole_building)

## Accepted regressions (0)

- none

## Improvements (5)

- ledger: blockers.FULL_BUILDING_STRUCTURAL 117 -> 115
- ledger: blockers.PRODUCTION_CUTOVER 134 -> 132
- ledger: blockers.V1_RETIREMENT 136 -> 134
- ledger: floor.ROOF PROGRAMMED -> SPATIALLY_PROVEN
- ledger: roof.roof_bulkhead PROGRAMMED -> SPATIALLY_PROVEN

## Report claims contradicted (0)

- none

## Design doc lint (1)

- INFO design/ORISON_V2_ROOF_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 2 requirement status(es): floor.ROOF PROGRAMMED->SPATIALLY_PROVEN, roof.roof_bulkhead PROGRAMMED->SPATIALLY_PROVEN

## Gates changed by the candidate (3)

- M tools/audit_v2_surfaces.py
- M tools/orison_spatial_dependency_manifest.json
- M tools/tests/test_v2_surface_requirements.py

BLOCKED regression: test:test_orison_v2_completeness: PASS -> FAIL (exit 0 -> 1); regression: test:test_orison_v2_completeness: failed 0 -> 2; regression: test:test_orison_v2_completeness: new defect test_live_first_slice_is_proven_not_complete (__main__.LiveRepoSmokeTests.test_live_first_slice_is_proven_not_complete) (+1 more)
