# Candidate verification - e07488a324da

- candidate `e07488a324dae7ee64f548e25bc4d36b410771ce`
- base `662aa9fcb0d47b852eeb4ec41f55ca1c9f76bdf0`
- merge-base `662aa9fcb0d47b852eeb4ec41f55ca1c9f76bdf0`
- verified 2026-10-24T14:25:55Z from verifier `e07488a324da`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 62 regressions, 2 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'FULL_BUILDING_RUNTIME': 42, 'FULL_BUILDING_STRUCTURAL': 110, 'GOLDEN_SHIFT_V2': 8, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 110, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 134, 'V1_RETIREMENT': 136} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 5 |
| godot (import) | exit 124, waited 60 s for lane |

## Blocking reasons (63)

- regression: spatial: PASS -> FAIL (exit 0 -> 5)
- regression: spatial: drift.new_failing 0 -> 5
- regression: spatial: drift.new_reported 0 -> 40
- regression: spatial: drift.stale_preserved 0 -> 1
- regression: spatial: new defect new_failing:6c602186c54680c4
- regression: spatial: new defect new_failing:9249b31ea1ebd4f3
- regression: spatial: new defect new_failing:d7ed71e3162306a4
- regression: spatial: new defect new_failing:e9ab1df5c9b61cb8
- regression: spatial: new defect new_failing:eb01a5bea876b327
- regression: spatial: new defect new_reported:07b207ae7e3d6042
- regression: spatial: new defect new_reported:0c25cfda6835dd62
- regression: spatial: new defect new_reported:161a8a03115dc2e8
- regression: spatial: new defect new_reported:1d8cd0d4e7bc6443
- regression: spatial: new defect new_reported:2bb19937111d7e7e
- regression: spatial: new defect new_reported:31e34879401716b5
- regression: spatial: new defect new_reported:366fac99766a3b03
- regression: spatial: new defect new_reported:39a38ba275a1b72d
- regression: spatial: new defect new_reported:39ad07f0abd1724f
- regression: spatial: new defect new_reported:3bd4e4a354c6d8bb
- regression: spatial: new defect new_reported:40397dc19c0c561f
- regression: spatial: new defect new_reported:4043cc8400ca0463
- regression: spatial: new defect new_reported:409080b46d3ef9ab
- regression: spatial: new defect new_reported:479e9ab792af93a5
- regression: spatial: new defect new_reported:4c8df3cbcda0b737
- regression: spatial: new defect new_reported:4f5265d56634ec5d
- regression: spatial: new defect new_reported:53e1bacc428ee529
- regression: spatial: new defect new_reported:54e31b0adfc4276e
- regression: spatial: new defect new_reported:59c19ae1ed2c224c
- regression: spatial: new defect new_reported:5b29db853c596037
- regression: spatial: new defect new_reported:5c27d701bb5f2eea
- regression: spatial: new defect new_reported:6066068d662b48f5
- regression: spatial: new defect new_reported:642d39a5dece3748
- regression: spatial: new defect new_reported:68899bd450e790ee
- regression: spatial: new defect new_reported:6c0cf99cebb303c3
- regression: spatial: new defect new_reported:86189c8d4c91647a
- regression: spatial: new defect new_reported:8996193aa9a6b0d7
- regression: spatial: new defect new_reported:89b99a8e81ccf6c9
- regression: spatial: new defect new_reported:8edc62628acae61f
- regression: spatial: new defect new_reported:9af84b190c7b70b2
- regression: spatial: new defect new_reported:9cf5c638ad747bd3
- regression: spatial: new defect new_reported:c46522bc58811c4c
- regression: spatial: new defect new_reported:c7e72fb66ff1d25a
- regression: spatial: new defect new_reported:cbd62eb68971e340
- regression: spatial: new defect new_reported:d480570852ce3f0e
- regression: spatial: new defect new_reported:dafdc729865f35e8
- regression: spatial: new defect new_reported:df545f5e9d5dd594
- regression: spatial: new defect new_reported:ea8423a29da18fc5
- regression: spatial: new defect new_reported:f0de032933304e71
- regression: spatial: new defect new_reported:fb527eff33679334
- regression: spatial: new defect stale_preserved:deabb0b0ba3b1b44
- regression: systemic: drift.new_review 23 -> 29
- regression: systemic: new defect new_review:2c377954fd7ede00
- regression: systemic: new defect new_review:3651b08395f36f8f
- regression: systemic: new defect new_review:5cb1c5ae0e0e266d
- regression: systemic: new defect new_review:b0c27264fdb96424
- regression: systemic: new defect new_review:ba1f3264dd6c9a97
- regression: systemic: new defect new_review:cad26cae74ebba5d
- regression: test:test_orison_spatial_dependencies: PASS -> FAIL (exit 0 -> 1)
- regression: test:test_orison_spatial_dependencies: failed 0 -> 1
- regression: test:test_orison_spatial_dependencies: new defect test_live_check_is_clean (__main__.ProductionSmokeTests.test_live_check_is_clean)
- regression: v2_surface_qualification: defects 2 -> 3
- regression: v2_surface_qualification: new defect runtime contract does not bind the current surface test
- godot (import): exit 124

## Needs human review (not blocking) (2)

- candidate changes 5 gate file(s); read those diffs before trusting the board
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (62)

- spatial: PASS -> FAIL (exit 0 -> 5)
- spatial: drift.new_failing 0 -> 5
- spatial: drift.new_reported 0 -> 40
- spatial: drift.stale_preserved 0 -> 1
- spatial: new defect new_failing:6c602186c54680c4
- spatial: new defect new_failing:9249b31ea1ebd4f3
- spatial: new defect new_failing:d7ed71e3162306a4
- spatial: new defect new_failing:e9ab1df5c9b61cb8
- spatial: new defect new_failing:eb01a5bea876b327
- spatial: new defect new_reported:07b207ae7e3d6042
- spatial: new defect new_reported:0c25cfda6835dd62
- spatial: new defect new_reported:161a8a03115dc2e8
- spatial: new defect new_reported:1d8cd0d4e7bc6443
- spatial: new defect new_reported:2bb19937111d7e7e
- spatial: new defect new_reported:31e34879401716b5
- spatial: new defect new_reported:366fac99766a3b03
- spatial: new defect new_reported:39a38ba275a1b72d
- spatial: new defect new_reported:39ad07f0abd1724f
- spatial: new defect new_reported:3bd4e4a354c6d8bb
- spatial: new defect new_reported:40397dc19c0c561f
- spatial: new defect new_reported:4043cc8400ca0463
- spatial: new defect new_reported:409080b46d3ef9ab
- spatial: new defect new_reported:479e9ab792af93a5
- spatial: new defect new_reported:4c8df3cbcda0b737
- spatial: new defect new_reported:4f5265d56634ec5d
- spatial: new defect new_reported:53e1bacc428ee529
- spatial: new defect new_reported:54e31b0adfc4276e
- spatial: new defect new_reported:59c19ae1ed2c224c
- spatial: new defect new_reported:5b29db853c596037
- spatial: new defect new_reported:5c27d701bb5f2eea
- spatial: new defect new_reported:6066068d662b48f5
- spatial: new defect new_reported:642d39a5dece3748
- spatial: new defect new_reported:68899bd450e790ee
- spatial: new defect new_reported:6c0cf99cebb303c3
- spatial: new defect new_reported:86189c8d4c91647a
- spatial: new defect new_reported:8996193aa9a6b0d7
- spatial: new defect new_reported:89b99a8e81ccf6c9
- spatial: new defect new_reported:8edc62628acae61f
- spatial: new defect new_reported:9af84b190c7b70b2
- spatial: new defect new_reported:9cf5c638ad747bd3
- spatial: new defect new_reported:c46522bc58811c4c
- spatial: new defect new_reported:c7e72fb66ff1d25a
- spatial: new defect new_reported:cbd62eb68971e340
- spatial: new defect new_reported:d480570852ce3f0e
- spatial: new defect new_reported:dafdc729865f35e8
- spatial: new defect new_reported:df545f5e9d5dd594
- spatial: new defect new_reported:ea8423a29da18fc5
- spatial: new defect new_reported:f0de032933304e71
- spatial: new defect new_reported:fb527eff33679334
- spatial: new defect stale_preserved:deabb0b0ba3b1b44
- systemic: drift.new_review 23 -> 29
- systemic: new defect new_review:2c377954fd7ede00
- systemic: new defect new_review:3651b08395f36f8f
- systemic: new defect new_review:5cb1c5ae0e0e266d
- systemic: new defect new_review:b0c27264fdb96424
- systemic: new defect new_review:ba1f3264dd6c9a97
- systemic: new defect new_review:cad26cae74ebba5d
- test:test_orison_spatial_dependencies: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_spatial_dependencies: failed 0 -> 1
- test:test_orison_spatial_dependencies: new defect test_live_check_is_clean (__main__.ProductionSmokeTests.test_live_check_is_clean)
- v2_surface_qualification: defects 2 -> 3
- v2_surface_qualification: new defect runtime contract does not bind the current surface test

## Accepted regressions (0)

- none

## Improvements (2)

- reader: unread 1108 -> 1107
- reader: resolved FIELD_UNREAD|game/data/runtime_material_sets.json|metallic

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (5)

- M tools/audit_data_consumption.py
- M tools/orison_spatial_dependency_manifest.json
- M tools/tests/test_m11c1_runtime_rehearsal.py
- M tools/tests/test_nook_readable_books.py
- M tools/tests/test_v2_surface_requirements.py

BLOCKED regression: spatial: PASS -> FAIL (exit 0 -> 5); regression: spatial: drift.new_failing 0 -> 5; regression: spatial: drift.new_reported 0 -> 40 (+60 more)
