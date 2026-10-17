# Candidate verification - d16991fd1149

- candidate `d16991fd11498e906b2ed930740f43f943950eab`
- base `e0b0dd293325a49c207785888112262a4990e474`
- merge-base `e0b0dd293325a49c207785888112262a4990e474`
- verified 2026-10-17T07:30:46Z from verifier `d16991fd1149`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 58 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 34, 'FULL_BUILDING_STRUCTURAL': 102, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 119, 'V1_RETIREMENT': 121} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 48, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 65, 'V1_RETIREMENT': 67} |
| requirements_changed | ['unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep'] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 24 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 24 gate file(s); read those diffs before trusting the board
- ledger requirements changed: ['unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']
- Godot suites were not run (--no-godot)

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (58)

- ledger: blockers.FULL_BUILDING_RUNTIME 34 -> 25
- ledger: blockers.FULL_BUILDING_STRUCTURAL 102 -> 48
- ledger: blockers.PRODUCTION_CUTOVER 119 -> 65
- ledger: blockers.V1_RETIREMENT 121 -> 67
- ledger: unit.3A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.entry PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.entry PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.3B.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.entry PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.4A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5B.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.5C.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6A.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.sleep PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6B.storage PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C.cooking PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C.living PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C.sanitary PROGRAMMED -> SPATIALLY_PROVEN
- ledger: unit.6C.sleep PROGRAMMED -> SPATIALLY_PROVEN

## Report claims contradicted (0)

- none

## Design doc lint (3)

- INFO design/ORISON_V2_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-12.md: this document changes 15 requirement status(es): contract.F04_B_BATH PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_CLOSET PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_KITCHEN PROGRAMMED->SPATIALLY_PROVEN, unit.2A PROGRAMMED->SPATIALLY_PROVEN, unit.2A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.2A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.2B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2B.living PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_FIRST_SLICE_RUNTIME_COMPOSITION_CHECKPOINT_2026-10-11.md: this document changes 7 requirement status(es): contract.B1_BOILER_01 SPATIALLY_PROVEN->RUNTIME_PROVEN, contract.F02_B_RADIATOR_01 SPATIALLY_PROVEN->RUNTIME_PROVEN, job.lena_radiator_round_2b PROGRAMMED->RUNTIME_PROVEN, ritual.F01_NIGHT_REGISTER SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_SIGNAL_REGISTER SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_TOUR_KEY_GUARD SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_WATCHMAN_DETECTOR SPATIALLY_PROVEN->RUNTIME_PROVEN
- INFO design/ORISON_V2_REMAINING_APARTMENT_SPATIAL_ACCESS_CHECKPOINT_2026-10-13.md: this document changes 54 requirement status(es): unit.3A PROGRAMMED->SPATIALLY_PROVEN, unit.3A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.3A.entry PROGRAMMED->SPATIALLY_PROVEN, unit.3A.living PROGRAMMED->SPATIALLY_PROVEN, unit.3A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.3A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.3A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.3B PROGRAMMED->SPATIALLY_PROVEN, unit.3B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.3B.entry PROGRAMMED->SPATIALLY_PROVEN

## Gates changed by the candidate (24)

- M tools/audit_data_consumption.py
- M tools/audit_orison_v2_completeness.py
- M tools/audit_systemic_situation_authority.py
- A tools/audit_v2_acoustic_ownership.py
- M tools/orison_spatial_dependency_manifest.json
- M tools/tests/test_data_consumption.py
- A tools/tests/test_heating_pipe_fittings.py
- M tools/tests/test_m11c1_runtime_rehearsal.py
- M tools/tests/test_orison_v2_completeness.py
- A tools/tests/test_spatial_binding_preflight.py
- M tools/tests/test_systemic_situation_authority.py
- A tools/tests/test_v2_acoustic_ownership.py
- A tools/tests/test_v2_acoustic_ventilation.py
- A tools/tests/test_v2_audit_digest_snapshot.py
- A tools/tests/test_v2_front_lighting_plan.py
- A tools/tests/test_v2_front_lighting_projection.py
- A tools/tests/test_v2_front_trim.py
- A tools/tests/test_v2_heating_branch_supports.py
- A tools/tests/test_v2_heating_envelopes.py
- A tools/tests/test_v2_heating_interfaces.py
- A tools/tests/test_v2_heating_refit_projection.py
- A tools/tests/test_v2_heating_routes.py
- A tools/tests/test_v2_heating_takeoff.py
- M tools/tests/test_v2_surface_requirements.py

MERGE-CANDIDATE d16991fd11498e906b2ed930740f43f943950eab
