# Candidate verification - 250fdb496a78

- candidate `250fdb496a78aeb64a8605b5cc2a298464c9b43f`
- base `111469baeaff38ca8f621593325cb9c817aff4e6`
- merge-base `111469baeaff38ca8f621593325cb9c817aff4e6`
- verified 2026-10-18T07:38:39Z from verifier `250fdb496a78`

| check | result |
|---|---|
| checkout mode | in-place |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 0 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 0, 'FULL_BUILDING_RUNTIME': 25, 'FULL_BUILDING_STRUCTURAL': 48, 'GOLDEN_SHIFT_V2': 1, 'PRODUCTION_CUTOVER': 65, 'V1_RETIREMENT': 67} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 0, 'GOLDEN_SHIFT_V2': 1, 'FULL_BUILDING_STRUCTURAL': 48, 'FULL_BUILDING_RUNTIME': 25, 'PRODUCTION_CUTOVER': 65, 'V1_RETIREMENT': 67} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 1 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (3)

- candidate changes 1 gate file(s); read those diffs before trusting the board
- Godot suites were not run (--no-godot)
- Verified the clean canonical checkout; fresh-checkout import and autocrlf behavior are outside this in-place verification

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (0)

- none

## Report claims contradicted (0)

- none

## Design doc lint (3)

- INFO design/ORISON_V2_FIRST_SLICE_RUNTIME_COMPOSITION_CHECKPOINT_2026-10-11.md: this document changes 7 requirement status(es): contract.B1_BOILER_01 SPATIALLY_PROVEN->RUNTIME_PROVEN, contract.F02_B_RADIATOR_01 SPATIALLY_PROVEN->RUNTIME_PROVEN, job.lena_radiator_round_2b PROGRAMMED->RUNTIME_PROVEN, ritual.F01_NIGHT_REGISTER SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_SIGNAL_REGISTER SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_TOUR_KEY_GUARD SPATIALLY_PROVEN->RUNTIME_PROVEN, ritual.F01_WATCHMAN_DETECTOR SPATIALLY_PROVEN->RUNTIME_PROVEN
- INFO design/ORISON_V2_REMAINING_COHORT_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 54 requirement status(es): unit.3A PROGRAMMED->SPATIALLY_PROVEN, unit.3A.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.3A.entry PROGRAMMED->SPATIALLY_PROVEN, unit.3A.living PROGRAMMED->SPATIALLY_PROVEN, unit.3A.sanitary PROGRAMMED->SPATIALLY_PROVEN, unit.3A.sleep PROGRAMMED->SPATIALLY_PROVEN, unit.3A.storage PROGRAMMED->SPATIALLY_PROVEN, unit.3B PROGRAMMED->SPATIALLY_PROVEN, unit.3B.cooking PROGRAMMED->SPATIALLY_PROVEN, unit.3B.entry PROGRAMMED->SPATIALLY_PROVEN
- INFO design/ORISON_V2_ROOF_COHORT_SPATIAL_ACCESS_CHECKPOINT_2026-10-18.md: this document changes 0 requirement status(es): no requirement status

## Gates changed by the candidate (1)

- M tools/orison_spatial_dependency_manifest.json

MERGE-CANDIDATE 250fdb496a78aeb64a8605b5cc2a298464c9b43f
