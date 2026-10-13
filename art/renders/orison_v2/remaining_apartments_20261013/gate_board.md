# Gate board - 26681527ac72

- commit `26681527ac72e0cdd6ac7a4e64e143c51968e5ae`
- tree `18ccc42be69e08ddef898fe8dfff1829d62da151`
- created 2026-10-13T18:04:37Z
- dirty paths: 1390

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_surface_qualification | PASS | 0 | 4.06 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.06 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.61 | no defects counted |
| ledger | INCOMPLETE | 2 | 31.0 | blockers 0 / 25 / 48 / 1 / 65 / 67; requirements 240 |
| spatial | PASS | 0 | 4.7 | no defects counted |
| systemic | PASS | 0 | 2.95 | drift.new_review 21 |
| period | PASS | 0 | 1.0 | no defects counted |
| reader | PASS | 0 | 3.3 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.62 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 128.81 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.11 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.3 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 3.78 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.61 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.55 | ran 26, failed 0 |
| test:test_gate_board | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 1.14 | ran 4, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.72 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 0.86 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.62 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.19 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.11 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.34 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.22 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 5.66 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.09 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.62 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.16 | ran 22, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.25 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | PASS | 0 | 5.8 | ran 56, failed 0 |
| test:test_orison_v2_completeness | PASS | 0 | 100.45 | ran 108, failed 0 |
| test:test_period_dates | PASS | 0 | 0.36 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.41 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.22 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.28 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.84 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.69 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 9.7 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 74.11 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 11.53 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 82.22 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 54.53 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 0.95 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.25 | ran 8, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 4.81 | ran 58, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.09 | ran 1, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.2 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.28 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.27 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.34 | ran 6, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.41 | ran 4, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 5.48 | ran 19, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.28 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 1.77 | ran 19, failed 0 |

## Against 7283b99b2661

Verdict: **NO REGRESSIONS**

requirements_changed: ['unit.3A', 'unit.3A.cooking', 'unit.3A.entry', 'unit.3A.living', 'unit.3A.sanitary', 'unit.3A.sleep', 'unit.3A.storage', 'unit.3B', 'unit.3B.cooking', 'unit.3B.entry', 'unit.3B.living', 'unit.3B.sanitary', 'unit.3B.sleep', 'unit.3B.storage', 'unit.4A', 'unit.4A.cooking', 'unit.4A.entry', 'unit.4A.living', 'unit.4A.sanitary', 'unit.4A.sleep', 'unit.4A.storage', 'unit.5A', 'unit.5A.cooking', 'unit.5A.living', 'unit.5A.sanitary', 'unit.5A.sleep', 'unit.5A.storage', 'unit.5B', 'unit.5B.cooking', 'unit.5B.living', 'unit.5B.sanitary', 'unit.5B.sleep', 'unit.5B.storage', 'unit.5C', 'unit.5C.cooking', 'unit.5C.living', 'unit.5C.sanitary', 'unit.6A', 'unit.6A.cooking', 'unit.6A.living', 'unit.6A.sanitary', 'unit.6A.sleep', 'unit.6A.storage', 'unit.6B', 'unit.6B.cooking', 'unit.6B.living', 'unit.6B.sanitary', 'unit.6B.sleep', 'unit.6B.storage', 'unit.6C', 'unit.6C.cooking', 'unit.6C.living', 'unit.6C.sanitary', 'unit.6C.sleep']

### Regressions (0)

- none

### Improvements (58)

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

### Other changes (0)

- none

