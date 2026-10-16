# Candidate verification - ccb94d88d8ab

- candidate `ccb94d88d8abb1863ce6d2467b068d5fdea66480`
- base `e0b0dd293325a49c207785888112262a4990e474`
- merge-base `e0b0dd293325a49c207785888112262a4990e474`
- verified 2026-10-16T20:54:39Z from verifier `ccb94d88d8ab`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 23 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 102, 'FULL_BUILDING_RUNTIME': 34, 'PRODUCTION_CUTOVER': 119, 'V1_RETIREMENT': 121} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 114, 'FULL_BUILDING_RUNTIME': 35, 'PRODUCTION_CUTOVER': 131, 'V1_RETIREMENT': 133} |
| requirements_changed | ['contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 14 |

## Blocking reasons (23)

- regression: ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 35
- regression: ledger: blockers.FULL_BUILDING_STRUCTURAL 102 -> 114
- regression: ledger: blockers.PRODUCTION_CUTOVER 119 -> 131
- regression: ledger: blockers.V1_RETIREMENT 121 -> 133
- regression: ledger: contract.F04_B_BATH SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: contract.F04_B_CLOSET SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: contract.F04_B_KITCHEN SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2A.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2B.living SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.2B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- regression: ledger: unit.4B.storage SPATIALLY_PROVEN -> PROGRAMMED
- regression: v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- regression: v2_surface_qualification: defects 0 -> 2
- regression: v2_surface_qualification: new defect missing or stale rendered review
- regression: v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

## Needs human review (not blocking) (3)

- candidate changes 14 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage']
- Godot suites were not run (--no-godot)

## Regressions (23)

- ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 35
- ledger: blockers.FULL_BUILDING_STRUCTURAL 102 -> 114
- ledger: blockers.PRODUCTION_CUTOVER 119 -> 131
- ledger: blockers.V1_RETIREMENT 121 -> 133
- ledger: contract.F04_B_BATH SPATIALLY_PROVEN -> PROGRAMMED
- ledger: contract.F04_B_CLOSET SPATIALLY_PROVEN -> PROGRAMMED
- ledger: contract.F04_B_KITCHEN SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2B.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.2B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4B.storage SPATIALLY_PROVEN -> PROGRAMMED
- v2_surface_qualification: PASS -> FAIL (exit 0 -> 1)
- v2_surface_qualification: defects 0 -> 2
- v2_surface_qualification: new defect missing or stale rendered review
- v2_surface_qualification: new defect stale surface qualification: rendering inputs changed

## Accepted regressions (0)

- none

## Improvements (0)

- none

## Report claims contradicted (0)

- none

## Design doc lint (3)

- INFO design/ORISON_V2_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_FIRST_SLICE_RUNTIME_COMPOSITION_CHECKPOINT_2026-10-11.md: this document changes 7 requirement status(es): contract.B1_BOILER_01 SPATIALLY_PROVEN->RUNTIME_PROVEN, contract.F02_B_RADIATOR_01 SPATIALLY_PROVEN->RUNTIME_PROVEN, job.lena_radiator_round_2b PROGRAMMED->RUNTIME_PROVEN, ritual.F01_NIGHT_REGISTER SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_SIGNAL_REGISTER SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_TOUR_KEY_GUARD SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_WATCHMAN_DETECTOR SPATIALLY_PROVEN->RUNTIME_PROVEN
- INFO design/ORISON_V2_REMAINING_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-13.md: this document changes 0 requirement status(es): no requirement status

## Gates changed by the candidate (14)

- M tools/audit_systemic_situation_authority.py
- A tools/audit_v2_acoustic_ownership.py
- M tools/orison_spatial_dependency_manifest.json
- A tools/tests/test_heating_pipe_fittings.py
- M tools/tests/test_m11c1_runtime_rehearsal.py
- M tools/tests/test_orison_v2_completeness.py
- A tools/tests/test_spatial_binding_preflight.py
- M tools/tests/test_systemic_situation_authority.py
- A tools/tests/test_v2_acoustic_ownership.py
- A tools/tests/test_v2_acoustic_ventilation.py
- A tools/tests/test_v2_heating_branch_supports.py
- A tools/tests/test_v2_heating_envelopes.py
- A tools/tests/test_v2_heating_interfaces.py
- A tools/tests/test_v2_heating_routes.py

BLOCKED regression: ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 35; regression: ledger: blockers.FULL_BUILDING_STRUCTURAL 102 -> 114; regression: ledger: blockers.PRODUCTION_CUTOVER 119 -> 131 (+20 more)
