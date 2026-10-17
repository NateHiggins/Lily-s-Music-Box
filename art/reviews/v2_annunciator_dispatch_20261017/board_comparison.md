Evidence class: **INERT**. Older-board comparison; not candidate verification.

# Gate board - cc77be1a8473

- commit `cc77be1a8473c8faa9e73a15d2af06f006958570`
- tree `ee498a28a49100ff84179e7322f1c53f0d108b7a`
- created 2026-10-17T23:56:43Z
- dirty paths: 1576

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_surface_qualification | PASS | 0 | 6.22 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.09 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.77 | no defects counted |
| ledger | INCOMPLETE | 2 | 12.31 | blockers 7 / 42 / 114 / 8 / 138 / 140; requirements 240 |
| spatial | FAIL | 5 | 7.84 | drift.new_failing 28, drift.new_reported 49, drift.stale_preserved 1 |
| systemic | PASS | 0 | 4.72 | drift.new_review 26 |
| period | PASS | 0 | 1.3 | no defects counted |
| reader | PASS | 0 | 6.23 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 1.16 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 241.5 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.25 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 5.06 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 9.0 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 2.47 | ran 6, failed 0 |
| test:test_data_consumption | PASS | 0 | 12.41 | ran 28, failed 0 |
| test:test_gate_board | PASS | 0 | 0.3 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.17 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 1.5 | ran 4, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 1.12 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 1.25 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 2.05 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.41 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.86 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 4.03 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.33 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 10.28 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.69 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.33 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.31 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.7 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 14.69 | ran 56, failed 1 |
| test:test_orison_v2_completeness | FAIL | 1 | 73.02 | ran 108, failed 1 |
| test:test_period_dates | PASS | 0 | 1.39 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.84 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.69 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 1.09 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 4.67 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 1.83 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 17.2 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 147.52 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 25.53 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 143.83 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 106.58 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 4.11 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.34 | ran 4, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.48 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.34 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 13.64 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.22 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.17 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.23 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.34 | ran 8, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.52 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.69 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 1.28 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.75 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.36 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.69 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 1.3 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.44 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.67 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.72 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 1.0 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.31 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.27 | ran 7, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.16 | ran 2, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.91 | ran 4, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 65.19 | ran 25, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.53 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 6.7 | ran 19, failed 0 |

## Against fdac253b3ccb

Verdict: **REGRESSED**

requirements_changed: []

### Regressions (13)

- spatial: drift.new_reported 39 -> 49
- spatial: new defect new_reported:1dd4dd163672cdf9
- spatial: new defect new_reported:39b97475764f8dbc
- spatial: new defect new_reported:436511a6fd65a8c8
- spatial: new defect new_reported:84cf1a06e3aa83f7
- spatial: new defect new_reported:91a895be90505f67
- spatial: new defect new_reported:ba77ad60a15d6d3b
- spatial: new defect new_reported:c4bd37e08ea8f0ae
- spatial: new defect new_reported:c6c55b46684343f2
- spatial: new defect new_reported:c73593759b84c640
- spatial: new defect new_reported:cee6eb9df18aa0a2
- spatial: new defect new_reported:e636939f4e372e56
- spatial: new defect new_reported:e91d6a7940d54a66

### Improvements (2)

- spatial: resolved new_reported:0a267f3f9a71b6c5
- spatial: resolved new_reported:3dd544fc6ae167d2

### Other changes (0)

- none
