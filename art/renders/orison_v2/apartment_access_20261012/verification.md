# Candidate verification - 6faf490e2c55

- candidate `6faf490e2c555798e71fbbc853e7372d3f7ecd22`
- base `4be49f1d2844c02941387b6ac4ecb56fe7480f68`
- merge-base `4be49f1d2844c02941387b6ac4ecb56fe7480f68`
- verified 2026-10-12T13:49:19Z from verifier `6faf490e2c55`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 19 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 115, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 132, 'V1_RETIREMENT': 134} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 103, 'FULL_BUILDING_RUNTIME': 34, 'PRODUCTION_CUTOVER': 120, 'V1_RETIREMENT': 122} |
| requirements_changed | ['contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 4 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (4)

- candidate changes 4 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage']
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (19)

- ledger: blockers.FULL_BUILDING_RUNTIME 35 -> 34
- ledger: blockers.FULL_BUILDING_STRUCTURAL 115 -> 103
- ledger: blockers.PRODUCTION_CUTOVER 132 -> 120
- ledger: blockers.V1_RETIREMENT 134 -> 122
- ledger: contract.F04_B_BATH PROGRAMMED -> SPATIALLY_PROVEN
- ledger: contract.F04_B_CLOSET PROGRAMMED -> SPATIALLY_PROVEN
- ledger: contract.F04_B_KITCHEN PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2B.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.2B.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4B.storage PROGRAMMED -> SPATIALLY_PROVEN

## Report claims contradicted (0)

- none

## Design doc lint (1)

- INFO design/ORISON_V2_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 15 requirement status(es): contract.F04_B_BATH PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_CLOSET PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_KITCHEN PROGRAMMED->SPATIALLY_PROVEN, unit.2A PROGRAMMED->SPATIALLY_PROVEN, unit.2A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.2A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.2B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2B.living PROGRAMMED->SPATIALLY_PROVEN

## Gates changed by the candidate (4)

- M tools/audit_orison_v2_completeness.py
- M tools/orison_spatial_dependency_manifest.json
- M tools/tests/test_orison_v2_completeness.py
- A tools/tests/test_spatial_access_evidence.py

MERGE-CANDIDATE 6faf490e2c555798e71fbbc853e7372d3f7ecd22
