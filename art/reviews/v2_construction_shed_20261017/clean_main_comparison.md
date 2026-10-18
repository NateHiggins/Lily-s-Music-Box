# Gate board - 837fbdef6318

- commit `837fbdef6318ea573e1e9bf6c9e113b9c8d3ae60`
- tree `a6d86794fe106740ff7715e837b740dc8843b8f8`
- created 2026-10-18T04:35:51Z
- dirty paths: 1533

| gate | severity | exit | seconds | headline |
|---|---|---:|---:|---|
| v2_recipe_projections | PASS | 0 | 0.64 | no defects counted |
| v2_surface_qualification | PASS | 0 | 5.03 | no defects counted |
| v2_mesh_uv_imports | PASS | 0 | 0.08 | no defects counted |
| v2_surface_imports | PASS | 0 | 0.91 | no defects counted |
| ledger | INCOMPLETE | 2 | 17.95 | blockers 0 / 35 / 114 / 1 / 131 / 133; requirements 240 |
| spatial | FAIL | 5 | 7.94 | drift.new_failing 28, drift.new_reported 43, drift.stale_preserved 1 |
| systemic | PASS | 0 | 7.75 | drift.new_review 26 |
| period | PASS | 0 | 1.09 | no defects counted |
| reader | PASS | 0 | 3.38 | unread 1115; vs frozen baseline: new 0, resolved 193 |
| carriers | PASS | 0 | 0.72 | ambiguous_dynamic 2 |
| rulings | PASS | 0 | 169.03 | no defects counted |
| test:test_additive_material_rebind | PASS | 0 | 0.12 | ran 5, failed 0 |
| test:test_astra_packet | PASS | 0 | 2.28 | ran 10, failed 0 |
| test:test_audio_emitters | PASS | 0 | 4.42 | ran 6, failed 0 |
| test:test_check_rulings | PASS | 0 | 0.72 | ran 6, failed 0 |
| test:test_construction_shed_plan | PASS | 0 | 0.14 | ran 4, failed 0 |
| test:test_construction_shed_uv | PASS | 0 | 0.33 | ran 5, failed 0 |
| test:test_data_consumption | PASS | 0 | 7.62 | ran 28, failed 0 |
| test:test_gate_board | PASS | 0 | 0.19 | ran 15, failed 0 |
| test:test_heating_pipe_fittings | PASS | 0 | 0.11 | ran 3, failed 0 |
| test:test_honed_stone_maps | PASS | 0 | 0.69 | ran 4, failed 0 |
| test:test_ingest_retirement | PASS | 0 | 0.44 | ran 3, failed 0 |
| test:test_interaction_implementors | PASS | 0 | 0.89 | ran 31, failed 0 |
| test:test_interaction_prompt_carriers | PASS | 0 | 0.91 | ran 28, failed 0 |
| test:test_lanes | PASS | 0 | 1.81 | ran 6, failed 0 |
| test:test_lint_design_doc | PASS | 0 | 0.17 | ran 9, failed 0 |
| test:test_m11c0_floor01_harness_contract | PASS | 0 | 0.19 | ran 5, failed 0 |
| test:test_m11c1_floor01_source_ownership | PASS | 0 | 2.86 | ran 27, failed 0 |
| test:test_m11c1_owner_first_export | PASS | 0 | 0.67 | ran 11, failed 0 |
| test:test_m11c1_runtime_rehearsal | PASS | 0 | 6.3 | ran 19, failed 0 |
| test:test_m11c1_scanner_consumer_adapter | PASS | 0 | 0.11 | ran 7, failed 0 |
| test:test_m11c2_floor01_production_export | PASS | 0 | 0.62 | ran 11, failed 0 |
| test:test_m11c2_production_harness_contract | PASS | 0 | 0.2 | ran 22, failed 0 |
| test:test_material_catalog_persistence | PASS | 0 | 0.17 | ran 1, failed 0 |
| test:test_orison_floor01_source_ownership | PASS | 0 | 0.28 | ran 13, failed 0 |
| test:test_orison_spatial_dependencies | FAIL | 1 | 5.89 | ran 56, failed 1 |
| test:test_orison_v2_completeness | PASS | 0 | 65.56 | ran 108, failed 0 |
| test:test_period_dates | PASS | 0 | 0.39 | ran 4, failed 0 |
| test:test_prop_reference | PASS | 0 | 0.44 | ran 23, failed 0 |
| test:test_prop_review | PASS | 0 | 0.28 | ran 4, failed 0 |
| test:test_rehearse_orison_floor01_partition | PASS | 0 | 0.31 | ran 5, failed 0 |
| test:test_room_checkpoint_linter | PASS | 0 | 1.84 | ran 29, failed 0 |
| test:test_room_checkpoint_reconciler | PASS | 0 | 0.7 | ran 38, failed 0 |
| test:test_room_evidence_verifier | PASS | 0 | 10.19 | ran 34, failed 0 |
| test:test_room_gate_hook | PASS | 0 | 79.05 | ran 24, failed 0 |
| test:test_room_layout_workbench | PASS | 0 | 15.45 | ran 35, failed 0 |
| test:test_room_reconstruction_gate | PASS | 0 | 82.39 | ran 26, failed 0 |
| test:test_room_reconstruction_progress | PASS | 0 | 58.0 | ran 24, failed 0 |
| test:test_run_receipt | PASS | 0 | 1.2 | ran 10, failed 0 |
| test:test_runtime_source_projections | PASS | 0 | 0.12 | ran 4, failed 0 |
| test:test_site_softwood_maps | PASS | 0 | 0.59 | ran 2, failed 0 |
| test:test_spatial_access_evidence | PASS | 0 | 0.3 | ran 8, failed 0 |
| test:test_spatial_binding_preflight | PASS | 0 | 0.36 | ran 7, failed 0 |
| test:test_systemic_situation_authority | PASS | 0 | 6.77 | ran 59, failed 0 |
| test:test_upper_daylight_contract | PASS | 0 | 0.12 | ran 1, failed 0 |
| test:test_v2_acoustic_ownership | PASS | 0 | 0.12 | ran 15, failed 0 |
| test:test_v2_acoustic_ventilation | PASS | 0 | 0.16 | ran 5, failed 0 |
| test:test_v2_audit_digest_snapshot | PASS | 0 | 0.25 | ran 8, failed 0 |
| test:test_v2_authoring_projection | PASS | 0 | 1.23 | ran 8, failed 0 |
| test:test_v2_boiler_inlet_projection | PASS | 0 | 0.31 | ran 3, failed 0 |
| test:test_v2_completion_projection | PASS | 0 | 0.3 | ran 4, failed 0 |
| test:test_v2_fabrication_batch | PASS | 0 | 0.41 | ran 6, failed 0 |
| test:test_v2_front_lighting_plan | PASS | 0 | 0.22 | ran 9, failed 0 |
| test:test_v2_front_lighting_projection | PASS | 0 | 0.53 | ran 7, failed 0 |
| test:test_v2_front_trim | PASS | 0 | 0.67 | ran 5, failed 0 |
| test:test_v2_heating_branch_supports | PASS | 0 | 0.12 | ran 3, failed 0 |
| test:test_v2_heating_envelopes | PASS | 0 | 0.12 | ran 8, failed 0 |
| test:test_v2_heating_interfaces | PASS | 0 | 0.14 | ran 10, failed 0 |
| test:test_v2_heating_refit_projection | PASS | 0 | 0.33 | ran 10, failed 0 |
| test:test_v2_heating_routes | PASS | 0 | 0.16 | ran 8, failed 0 |
| test:test_v2_heating_takeoff | PASS | 0 | 0.16 | ran 7, failed 0 |
| test:test_v2_physical_inputs | PASS | 0 | 1.16 | ran 11, failed 0 |
| test:test_v2_radiator_vent_thread | PASS | 0 | 0.12 | ran 2, failed 0 |
| test:test_v2_recipe_projections | PASS | 0 | 0.22 | ran 4, failed 0 |
| test:test_v2_roof | PASS | 0 | 0.47 | ran 4, failed 0 |
| test:test_v2_surface_publication | PASS | 0 | 0.25 | ran 6, failed 0 |
| test:test_v2_surface_requirements | PASS | 0 | 48.8 | ran 25, failed 0 |
| test:test_v2_ventilation_fabric_projection | PASS | 0 | 0.33 | ran 3, failed 0 |
| test:test_verify_candidate | PASS | 0 | 2.52 | ran 19, failed 0 |

## Against e0b0dd293325

Verdict: **REGRESSED**

requirements_changed: ['contract.F04_B_BATH', 'contract.F04_B_CLOSET', 'contract.F04_B_KITCHEN', 'unit.2A', 'unit.2A.cooking', 'unit.2A.sanitary', 'unit.2A.sleep', 'unit.2A.storage', 'unit.2B.cooking', 'unit.2B.living', 'unit.2B.sanitary', 'unit.2B.sleep', 'unit.4B.cooking', 'unit.4B.sanitary', 'unit.4B.storage']

### Regressions (104)

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
- spatial: PASS -> FAIL (exit 0 -> 5)
- spatial: drift.new_failing 0 -> 28
- spatial: drift.new_reported 0 -> 43
- spatial: drift.stale_preserved 0 -> 1
- spatial: new defect new_failing:0bd8d892556827db
- spatial: new defect new_failing:28eefca2da7f4012
- spatial: new defect new_failing:2955d42f1790aa54
- spatial: new defect new_failing:2d1da5352652d925
- spatial: new defect new_failing:4b361beaddebd14c
- spatial: new defect new_failing:5bea0b0d9192e492
- spatial: new defect new_failing:6372592de7ad6d15
- spatial: new defect new_failing:64f13b7edfd96b2f
- spatial: new defect new_failing:6f3361d9b6100fca
- spatial: new defect new_failing:8bcb5051cf606fb1
- spatial: new defect new_failing:8ea3a964f1ef27fb
- spatial: new defect new_failing:9660221b970efa34
- spatial: new defect new_failing:9f412a58198eaca2
- spatial: new defect new_failing:a3ea9df579a29c96
- spatial: new defect new_failing:aafab6128a46d8af
- spatial: new defect new_failing:af38fcfe6feb2206
- spatial: new defect new_failing:b7ed75bcb5e0d419
- spatial: new defect new_failing:bb5b5ea40fc00b3c
- spatial: new defect new_failing:be8bef1587c68bca
- spatial: new defect new_failing:c06112129f04ae63
- spatial: new defect new_failing:c0793b8c68768065
- spatial: new defect new_failing:c3946c7ee62354a8
- spatial: new defect new_failing:cd9f1ea081ff1e79
- spatial: new defect new_failing:dcee4de31c4dbc7e
- spatial: new defect new_failing:ea6f0f576962b309
- spatial: new defect new_failing:ead3d9bcbca4a06f
- spatial: new defect new_failing:eaf6cc66fe85ba22
- spatial: new defect new_failing:fd711437ffbe3139
- spatial: new defect new_reported:091e4aafd0da9c37
- spatial: new defect new_reported:0f0bff46c738c8d3
- spatial: new defect new_reported:12478d955c492c1c
- spatial: new defect new_reported:12ba5177cdbfb533
- spatial: new defect new_reported:15be0aad6e6168d7
- spatial: new defect new_reported:18578d46d304830b
- spatial: new defect new_reported:1c948ca5177bb7a2
- spatial: new defect new_reported:1dd4dd163672cdf9
- spatial: new defect new_reported:24c55aac6d26345a
- spatial: new defect new_reported:2b442c0128f69d47
- spatial: new defect new_reported:2e095a6404f2dc1a
- spatial: new defect new_reported:36db025f81285e2f
- spatial: new defect new_reported:3a908c07b7f2015f
- spatial: new defect new_reported:484c1299671c9c5e
- spatial: new defect new_reported:4b5b168a92ed0ff4
- spatial: new defect new_reported:58f8e781376ae6f6
- spatial: new defect new_reported:61389e5ff6c7193b
- spatial: new defect new_reported:64ce0140efb75beb
- spatial: new defect new_reported:64febdd5924954f4
- spatial: new defect new_reported:695437a2587e3215
- spatial: new defect new_reported:6b1852afab0a4877
- spatial: new defect new_reported:7505644561d16f41
- spatial: new defect new_reported:7778cc769a02c97d
- spatial: new defect new_reported:8eb1b3d9ad668dd8
- spatial: new defect new_reported:90e23897cf075464
- spatial: new defect new_reported:91a895be90505f67
- spatial: new defect new_reported:961da634af424211
- spatial: new defect new_reported:b06a9d855a2e07df
- spatial: new defect new_reported:b68c63c167724041
- spatial: new defect new_reported:b732b678578aba9a
- spatial: new defect new_reported:b83aca0e4c1aa060
- spatial: new defect new_reported:ba77ad60a15d6d3b
- spatial: new defect new_reported:c36e6321ff9034cb
- spatial: new defect new_reported:c4bd37e08ea8f0ae
- spatial: new defect new_reported:c97925b6b8fbc631
- spatial: new defect new_reported:c97ef356c005c262
- spatial: new defect new_reported:d2d3717054c0567e
- spatial: new defect new_reported:d4e181dac590b686
- spatial: new defect new_reported:daf26122767e5394
- spatial: new defect new_reported:e636939f4e372e56
- spatial: new defect new_reported:e91d6a7940d54a66
- spatial: new defect new_reported:ebfed44952d08237
- spatial: new defect new_reported:ef0fba1f5947de6f
- spatial: new defect stale_preserved:e7d798aad4ef7f42
- systemic: drift.new_review 21 -> 26
- systemic: new defect new_review:5c169ca68317db25
- systemic: new defect new_review:63e6cacdcd0b2344
- systemic: new defect new_review:c727358ac9dc394f
- systemic: new defect new_review:ea51a0ac0460d426
- systemic: new defect new_review:f8532cae716bd429
- test:test_orison_spatial_dependencies: PASS -> FAIL (exit 0 -> 1)
- test:test_orison_spatial_dependencies: failed 0 -> 1
- test:test_orison_spatial_dependencies: new defect test_live_check_is_clean (__main__.ProductionSmokeTests.test_live_check_is_clean)

### Improvements (0)

- none

### Other changes (24)

- test:test_construction_shed_plan: new gate (PASS, exit 0)
- test:test_construction_shed_uv: new gate (PASS, exit 0)
- test:test_heating_pipe_fittings: new gate (PASS, exit 0)
- test:test_ingest_retirement: new gate (PASS, exit 0)
- test:test_material_catalog_persistence: new gate (PASS, exit 0)
- test:test_site_softwood_maps: new gate (PASS, exit 0)
- test:test_spatial_binding_preflight: new gate (PASS, exit 0)
- test:test_v2_acoustic_ownership: new gate (PASS, exit 0)
- test:test_v2_acoustic_ventilation: new gate (PASS, exit 0)
- test:test_v2_audit_digest_snapshot: new gate (PASS, exit 0)
- test:test_v2_front_lighting_plan: new gate (PASS, exit 0)
- test:test_v2_front_lighting_projection: new gate (PASS, exit 0)
- test:test_v2_front_trim: new gate (PASS, exit 0)
- test:test_v2_heating_branch_supports: new gate (PASS, exit 0)
- test:test_v2_heating_envelopes: new gate (PASS, exit 0)
- test:test_v2_heating_interfaces: new gate (PASS, exit 0)
- test:test_v2_heating_refit_projection: new gate (PASS, exit 0)
- test:test_v2_heating_routes: new gate (PASS, exit 0)
- test:test_v2_heating_takeoff: new gate (PASS, exit 0)
- test:test_v2_physical_inputs: new gate (PASS, exit 0)
- test:test_v2_radiator_vent_thread: new gate (PASS, exit 0)
- test:test_v2_recipe_projections: new gate (PASS, exit 0)
- test:test_v2_surface_publication: new gate (PASS, exit 0)
- v2_recipe_projections: new gate (PASS, exit 0)


