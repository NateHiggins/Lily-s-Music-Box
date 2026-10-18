# Candidate verification - 8d1ce1793426

- candidate `8d1ce17934266eec40de25d15342bfb31c8f2038`
- base `9928c34361cb7315270917d4d79c02b137e78a5a`
- merge-base `9928c34361cb7315270917d4d79c02b137e78a5a`
- verified 2026-10-18T21:04:49Z from verifier `8d1ce1793426`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 4 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 25, 'FULL_BUILDING_STRUCTURAL': 48, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 65, 'V1_RETIREMENT': 67} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 48, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 65, 'V1_RETIREMENT': 67} |
| requirements_changed | ['region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 5 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (4)

- candidate changes 5 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['region.arcade_hall', 'region.arcade_portal', 'region.arcade_throat', 'region.construction_seam']
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (4)

- ledger: region.arcade_hall ABSENT -> PROGRAMMED
- ledger: region.arcade_portal ABSENT -> PROGRAMMED
- ledger: region.arcade_throat ABSENT -> PROGRAMMED
- ledger: region.construction_seam ABSENT -> PROGRAMMED

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (5)

- M tools/orison_spatial_dependency_manifest.json
- A tools/tests/test_domestic_objects_bounded_preflight.py
- M tools/tests/test_spatial_binding_preflight.py
- M tools/tests/test_v2_audit_digest_snapshot.py
- A tools/tests/test_v2_public_regions.py

MERGE-CANDIDATE 8d1ce17934266eec40de25d15342bfb31c8f2038
