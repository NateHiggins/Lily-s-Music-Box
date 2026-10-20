# Candidate verification - 6e547d865316

- candidate `6e547d86531647fe0d16c5f88360e24f6c2f808d`
- base `82887a14d08357a400047624a6ce720351a748e0`
- merge-base `82887a14d08357a400047624a6ce720351a748e0`
- verified 2026-10-20T22:00:31Z from verifier `6e547d865316`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 4 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 25, 'FULL_BUILDING_STRUCTURAL': 21, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 38, 'V1_RETIREMENT': 40} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 21, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 38, 'V1_RETIREMENT': 40} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 18 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 18 gate file(s); read those diffs before trusting the board
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (4)

- reader: unread 1115 -> 1112
- reader: resolved FIELD_UNREAD|game/data/runtime_material_sets.json|materials
- reader: resolved FIELD_UNREAD|game/data/runtime_material_sets.json|meters_per_tile
- reader: resolved FILE_UNREAD|game/data/runtime_material_sets.json|

## Report claims contradicted (0)

- none

## Design doc lint (7)

- INFO design/ORISON_V2_EXTERIOR_SPATIAL_ACCESS_CHECKPOINT_2026-10-19.md: this document changes 6 requirement status(es): region.arcade_hall PROGRAMMED->SPATIALLY_PROVEN, region.arcade_portal PROGRAMMED->SPATIALLY_PROVEN, region.arcade_throat PROGRAMMED->SPATIALLY_PROVEN, region.construction_seam PROGRAMMED->SPATIALLY_PROVEN, region.shops PROGRAMMED->SPATIALLY_PROVEN, region.street PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_FIRST_SLICE_RUNTIME_COMPOSITION_CHECKPOINT_2026-10-11.md: this document changes 7 requirement status(es): contract.B1_BOILER_01 SPATIALLY_PROVEN->RUNTIME_PROVEN, contract.F02_B_RADIATOR_01 SPATIALLY_PROVEN->RUNTIME_PROVEN, job.lena_radiator_round_2b PROGRAMMED->RUNTIME_PROVEN, ritual.F01_NIGHT_REGISTER SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_SIGNAL_REGISTER SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_TOUR_KEY_GUARD SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_WATCHMAN_DETECTOR SPATIALLY_PROVEN->RUNTIME_PROVEN
- INFO design/ORISON_V2_HOME_COHORT_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 15 requirement status(es): contract.F04_B_BATH PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_CLOSET PROGRAMMED->SPATIALLY_PROVEN, contract.F04_B_KITCHEN PROGRAMMED->SPATIALLY_PROVEN, unit.2A PROGRAMMED->SPATIALLY_PROVEN, unit.2A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.2A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.2A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.2B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.2B.living PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_PUBLIC_LANDING_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 7 requirement status(es): circ.F01.public_landing PROGRAMMED->SPATIALLY_PROVEN, circ.F03.public_core PROGRAMMED->SPATIALLY_PROVEN, circ.F03.public_landing PROGRAMMED->SPATIALLY_PROVEN, circ.F05.public_core PROGRAMMED->SPATIALLY_PROVEN, circ.F05.public_landing PROGRAMMED->SPATIALLY_PROVEN, circ.F06.public_core PROGRAMMED->SPATIALLY_PROVEN, circ.F06.public_landing PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_REMAINING_COHORT_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 54 requirement status(es): unit.3A PROGRAMMED->SPATIALLY_PROVEN, unit.3A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.3A.entry PROGRAMMED->SPATIALLY_PROVEN, unit.3A.living PROGRAMMED->SPATIALLY_PROVEN, unit.3A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.3A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.3A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.3B PROGRAMMED->SPATIALLY_PROVEN, unit.3B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.3B.entry PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_ROOF_COHORT_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 0 requirement status(es): no requirement status
- INFO design/ORISON_V2_SERVICE_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 10 requirement status(es): circ.F02.service_core PROGRAMMED->SPATIALLY_PROVEN, circ.F02.service_route PROGRAMMED->SPATIALLY_PROVEN, circ.F03.service_core PROGRAMMED->SPATIALLY_PROVEN, circ.F03.service_route PROGRAMMED->SPATIALLY_PROVEN, circ.F04.service_core PROGRAMMED->SPATIALLY_PROVEN, circ.F04.service_route PROGRAMMED->SPATIALLY_PROVEN, circ.F05.service_core PROGRAMMED->SPATIALLY_PROVEN, circ.F05.service_route PROGRAMMED->SPATIALLY_PROVEN, circ.F06.service_core PROGRAMMED->SPATIALLY_PROVEN, circ.F06.service_route PROGRAMMED->SPATIALLY_PROVEN

## Gates changed by the candidate (18)

- M tools/audit_data_consumption.py
- M tools/audit_orison_v2_completeness.py
- M tools/audit_period_dates.py
- M tools/interaction_implementor_manifest.json
- M tools/orison_spatial_dependency_manifest.json
- M tools/run_receipt.py
- A tools/tests/test_additive_material_bindings.py
- A tools/tests/test_binding_relief.py
- M tools/tests/test_data_consumption.py
- M tools/tests/test_interaction_implementors.py
- M tools/tests/test_interaction_prompt_carriers.py
- A tools/tests/test_material_relief.py
- A tools/tests/test_nook_readable_books.py
- A tools/tests/test_readable_library.py
- M tools/tests/test_run_receipt.py
- M tools/tests/test_v2_front_trim.py
- A tools/tests/test_v2_spatial_publication.py
- M tools/tests/test_v2_surface_requirements.py

MERGE-CANDIDATE 6e547d86531647fe0d16c5f88360e24f6c2f808d
