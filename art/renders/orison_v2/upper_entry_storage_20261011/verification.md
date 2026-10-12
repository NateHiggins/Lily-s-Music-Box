# Candidate verification - 6d8bcd716ac4

- candidate `6d8bcd716ac42128263b2e0f18c7bef7bf214fe0`
- base `3c356b412f9c12a4c491c1daac256fda0099acf7`
- merge-base `3c356b412f9c12a4c491c1daac256fda0099acf7`
- verified 2026-10-12T02:34:20Z from verifier `6d8bcd716ac4`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 12 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 144, 'V1_RETIREMENT': 146} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 118, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 135, 'V1_RETIREMENT': 137} |
| requirements_changed | ['unit.5A.entry', 'unit.5B.entry', 'unit.5C.entry', 'unit.5C.sleep', 'unit.5C.storage', 'unit.6A.entry', 'unit.6B.entry', 'unit.6C.entry', 'unit.6C.storage'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 1 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['unit.5A.entry', 'unit.5B.entry', 'unit.5C.entry', 'unit.5C.sleep', 'unit.5C.storage', 'unit.6A.entry', 'unit.6B.entry', 'unit.6C.entry', 'unit.6C.storage']
- Godot suites were not run (--no-godot)

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (12)

- ledger: blockers.FULL_BUILDING_STRUCTURAL 127 -> 118
- ledger: blockers.PRODUCTION_CUTOVER 144 -> 135
- ledger: blockers.V1_RETIREMENT 146 -> 137
- ledger: unit.5A.entry ABSENT -> SPATIALLY_PROVEN
- ledger: unit.5B.entry ABSENT -> SPATIALLY_PROVEN
- ledger: unit.5C.entry ABSENT -> SPATIALLY_PROVEN
- ledger: unit.5C.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C.storage ABSENT -> SPATIALLY_PROVEN
- ledger: unit.6A.entry ABSENT -> SPATIALLY_PROVEN
- ledger: unit.6B.entry ABSENT -> SPATIALLY_PROVEN
- ledger: unit.6C.entry ABSENT -> SPATIALLY_PROVEN
- ledger: unit.6C.storage ABSENT -> SPATIALLY_PROVEN

## Report claims contradicted (0)

- none

## Design doc lint (1)

- INFO design/ORISON_V2_UPPER_ENTRY_STORAGE_CHECKPOINT_2026-10-11.md: this document changes 9 requirement status(es): unit.5A.entry PROGRAMMED->SPATIALLY_PROVEN, unit.5B.entry PROGRAMMED->SPATIALLY_PROVEN, unit.5C.entry PROGRAMMED->SPATIALLY_PROVEN, unit.5C.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.5C.storage PROGRAMMED->SPATIALLY_PROVEN, unit.6A.entry PROGRAMMED->SPATIALLY_PROVEN, unit.6B.entry PROGRAMMED->SPATIALLY_PROVEN, unit.6C.entry PROGRAMMED->SPATIALLY_PROVEN, unit.6C.storage PROGRAMMED->SPATIALLY_PROVEN

## Gates changed by the candidate (1)

- M tools/orison_spatial_dependency_manifest.json

MERGE-CANDIDATE 6d8bcd716ac42128263b2e0f18c7bef7bf214fe0
