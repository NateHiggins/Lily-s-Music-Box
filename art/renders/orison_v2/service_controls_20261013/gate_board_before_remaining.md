# Gate board - b112e625648d

- commit `b112e625648d038541f290c046af4869cf87ea24`
- tree `2de6ada92684a9e8eba969786ba7a75fc85cb014`
- created 2026-10-13T23:20:10Z
- dirty paths: 1440

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_surface_qualification | PASS | 0 | 4.97 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.09 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.78 | no defects counted |
| ledger | INCOMPLETE | 2 | 48.88 | blockers 0 / 1 / 102 / 34 / 119 / 121; requirements 240 |
| spatial | PASS | 0 | 6.03 | no defects counted |
| systemic | PASS | 0 | 3.41 | drift.new_review 21 |
| period | PASS | 0 | 1.16 | no defects counted |
| reader | PASS | 0 | 3.97 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.77 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 185.03 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.38 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 5.59 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.8 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 10.06 | ran 26, failed 0 |
| test:test_gate_board | PASS | 0 | 0.17 | ran 15, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 1.34 | ran 4, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.89 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.3 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 2.09 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.55 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.23 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.78 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.25 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 6.78 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.7 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.23 | ran 22, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.3 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 7.17 | ran 56, failed 0 |
| test:test_orison_v2_completeness | PASS | 0 | 154.73 | ran 108, failed 0 |
| test:test_period_dates | PASS | 0 | 0.47 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.48 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.28 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.33 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 2.08 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.8 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 15.17 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 103.0 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 24.69 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 135.34 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 104.91 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.38 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.27 | ran 8, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.11 | ran 58, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.12 | ran 1, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.3 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.34 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.33 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.39 | ran 6, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.47 | ran 4, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 7.47 | ran 19, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.38 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.67 | ran 19, failed 0 |

## Against 555b01f3bdcd

Verdict: **REGRESSED**

requirements_changed: ['unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']

### Regressions (58)

- ledger: blockers.FULL_BUILDING_RUNTIME 25 -> 34
- ledger: blockers.FULL_BUILDING_STRUCTURAL 48 -> 102
- ledger: blockers.PRODUCTION_CUTOVER 65 -> 119
- ledger: blockers.V1_RETIREMENT 67 -> 121
- ledger: unit.3A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.entry SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.entry SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.3B.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.entry SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.4A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5B.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5C SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5C.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5C.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.5C.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6A.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.sleep SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6B.storage SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C.cooking SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C.living SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C.sanitary SPATIALLY_PROVEN -> PROGRAMMED
- ledger: unit.6C.sleep SPATIALLY_PROVEN -> PROGRAMMED

### Improvements (0)

- none

### Other changes (0)

- none

