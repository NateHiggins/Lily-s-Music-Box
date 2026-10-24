# Candidate verification - cc857aee87c0

- candidate `cc857aee87c063a0e2204ea6befc683dfa1c8a4d`
- base `45ec315bfdddfa785cde5a3627f79a2f9e1b02bf`
- merge-base `45ec315bfdddfa785cde5a3627f79a2f9e1b02bf`
- verified 2026-10-11T16:27:21Z from verifier `cc857aee87c0`

| check | result |
|---|---|
| checkout mode | fresh |
| checkout clean | yes |
| gate board vs merge-base | 0 regressions, 1 improvements |
| ledger before | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| ledger after | {'FIRST_SLICE_TECHNICAL': 7, 'GOLDEN_SHIFT_V2': 8, 'FULL_BUILDING_STRUCTURAL': 127, 'FULL_BUILDING_RUNTIME': 42, 'PRODUCTION_CUTOVER': 151, 'V1_RETIREMENT': 153} |
| requirements_changed | [] |
| protected | 17/17 unchanged vs merge-base; 0 authorized selector change(s) |
| selector | v2 |
| design doc lint errors | 0 |
| gates changed by candidate | 7 |

## Blocking reasons (0)

- none

## Needs human review (not blocking) (2)

- candidate changes 7 gate file(s); read those diffs before trusting the board
- Godot suites were not run (--no-godot)

## Regressions (0)

- none

## Accepted regressions (0)

- none

## Improvements (1)

- v2_surface_imports: ERROR -> PASS

## Report claims contradicted (0)

- none

## Design doc lint (0)

- none

## Gates changed by the candidate (7)

- A tools/audit_glb_surface_uvs.py
- A tools/audit_v2_surfaces.py
- M tools/gate_board.py
- M tools/orison_spatial_dependency_manifest.json
- M tools/run_godot_long_suite.ps1
- M tools/systemic_situation_authority_baseline.json
- A tools/tests/test_v2_surface_requirements.py

MERGE-CANDIDATE cc857aee87c063a0e2204ea6befc683dfa1c8a4d
