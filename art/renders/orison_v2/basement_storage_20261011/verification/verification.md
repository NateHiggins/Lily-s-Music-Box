# Candidate verification - 734b4ae071da

- candidate `734b4ae071daa44dccc513aac7a58d3772df4167`
- base `6d8bcd716ac42128263b2e0f18c7bef7bf214fe0`
- merge-base `6d8bcd716ac42128263b2e0f18c7bef7bf214fe0`
- verified 2026-10-12T04:02:03Z from verifier `ddd10eaa958d`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 7 regressions, 4 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 118, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 135, 'V1_RETIREMENT': 137} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 117, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
| requirements_changed | ['b1.resident_storage'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |

## Blocking reasons (7)

- regression: test:test_v2_ventilation_fabric_projection: PASS -> FAIL (exit 0 -> 1)
- regression: test:test_v2_ventilation_fabric_projection: failed 0 -> 1
- regression: test:test_v2_ventilation_fabric_projection: new defect test_roof_and_home_owners_stay_fresh (__main__.VentilationFabricProjectionTest.test_roof_and_home_owners_stay_fresh)
- regression: v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- regression: v2_surface_qualification: defects 0 -> 2
- regression: v2_surface_qualification: new defect missing or stale rendered review
- regression: v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

## Needs human review (not blocking) (3)

- candidate changes 1 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['b1.resident_storage']
- Godot suites were not run (--no-godot)

## Regressions (7)

- test:test_v2_ventilation_fabric_projection: PASS -> FAIL (exit 0 -> 1)
- test:test_v2_ventilation_fabric_projection: failed 0 -> 1
- test:test_v2_ventilation_fabric_projection: new defect test_roof_and_home_owners_stay_fresh (__main__.VentilationFabricProjectionTest.test_roof_and_home_owners_stay_fresh)
- v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- v2_surface_qualification: defects 0 -> 2
- v2_surface_qualification: new defect missing or stale rendered review
- v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

## Accepted regressions (0)

- none

## Improvements (4)

- ledger: blockers.FULL_BUILDING_STRUCTURAL 118 -> 117
- ledger: blockers.PRODUCTION_CUTOVER 135 -> 134
- ledger: blockers.V1_RETIREMENT 137 -> 136
- ledger: b1.resident_storage ABSENT -> SPATIALLY_PROVEN

## Report claims contradicted (0)

- none

## Design doc lint (1)

- INFO design/ORISON_V2_BASEMENT_STORAGE_CHECKPOINT_2026-10-11.md: this document changes 1 requirement status(es): b1.resident_storage PROGRAMMED->SPATIALLY_PROVEN

## Gates changed by the candidate (1)

- M tools/orison_spatial_dependency_manifest.json

BLOCKED regression: test:test_v2_ventilation_fabric_projection: PASS -> FAIL (exit 0 -> 1); regression: test:test_v2_ventilation_fabric_projection: failed 0 -> 1; regression: test:test_v2_ventilation_fabric_projection: new defect test_roof_and_home_owners_stay_fresh (__main__.VentilationFabricProjectionTest.test_roof_and_home_owners_stay_fresh) (+4 more)
