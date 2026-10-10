# V2 environment dossier: merge report (2026-10-10)

Evidence class: **INERT**

This report covers branch `claude/orison-v2-environment-design-778e17` from
merge-base 2ea28ee0 to its tip 5467439f, which is the commit the owner asked
to merge into main. The pushed branch head d416d4ee was verified first and is
BLOCKED; 5467439f (slice 82) is one commit on top of it and clears the block.
The report promotes nothing. Row, space and anchor ids are written in bold
outside the fenced block. The lane receipts it cites are wrapper receipts
(`orison.run-receipt.v1`, evidence kind suite_run). They show that a suite ran
and how it ended. They are not schema-2 runtime_contract receipts, and they are
not runtime proof (RUL-003).

Sources: the packet `art/reviews/v2_environment_design_20261008` (README.md,
`content/status.py`, `change_register.json`, `implementation/<tag>/`), lane
output under `C:/ov/envimpl_out/<tag>/`, the candidate verifier for the tip at
`C:/ov/reports/5467439f2207/verification.{md,json}`, the verifier for the
pushed head at `C:/ov/reports/d416d4ee8a87/verification.{md,json}`, the
systemic audit output `C:/ov/systemic_now.json` (finding locations), and slice
82's runs under `C:/ov/envimpl_out/slice82/`. Slice 82 has no packet evidence.

## 1. Developer report

```
REPORT - V2-ENV-DOSSIER - 2026-10-10
Branch / HEAD / origin/main / merge-base:
  claude/orison-v2-environment-design-778e17 /
  5467439f2207efb943bbfd2f976f00077aae4c5c /
  2ea28ee056dba9a511b87086aa43ed29c3159d2a /
  2ea28ee056dba9a511b87086aa43ed29c3159d2a
  This report and its sidecar are committed on top of 5467439f; the
    branch is pushed with them, and main fast-forwards to that commit
    (no merge commit). origin/main was 2ea28ee0 when this was written.
  The branch forked from main at fdf01a36 (e63ce4f6's parent). main then
    moved 11 commits to 2ea28ee0, merged into the branch at 16f1d353.
  82 commits in 2ea28ee0..5467439f:
    - e63ce4f6, the INERT dossier packet.
    - 16f1d353, a merge of origin/main.
    - 79 slice commits for slices 1-44 and 47-81. The WIPs for slices 45
      and 46 were squashed into slice 44's commit 7e31b188.
    - 5467439f, slice 82, made to clear the verifier's block on d416d4ee.
  origin/main is an ancestor of 5467439f, so the merge is a fast-forward.
Worktree clean at end: branch worktree yes (git status --short is empty
  at 5467439f). The canonical checkout C:/PleaseRemainOnTheLine (main,
  where the merge and this report land) is not clean:
    - 3 modified: art/renders/insitu/shots.md (+30 lines), and
      art/textures/ai_materials/enamel_appliance/material.json and
      game/scripts/building/orison_v2_prep_cabinet.gd (line endings only).
    - 274 untracked entries (280 files), e.g.
      art/reviews/v2_improvement_20261008/ and *.gd.uid files.
  None of them is a path the branch changes or adds, so the fast-forward
  does not collide with them; the canonical checkout's fast-forward
  leaves them exactly as they were.
Protected 17/17: yes      Selector: v2 (owner-authorized default
  2026-09-21; verifier PASS)
  Both verifier reports: "17/17 unchanged vs merge-base; 0 authorized
  selector change(s)". building_root_selector.gd is unchanged, so the
  ORISON_BUILDING_ROOT=v1 rollback is unchanged. Only 7 of 17 match the
  historical recorded baseline (the seven floor .bin files; the seven
  .gltf files, both building_layout.json files and the selector do not).
  All 17 are identical to 2ea28ee0, so that mismatch comes from main.
Ledger before -> after:
  FIRST_SLICE_TECHNICAL 7, GOLDEN_SHIFT_V2 8, FULL_BUILDING_STRUCTURAL 127,
  FULL_BUILDING_RUNTIME 42, PRODUCTION_CUTOVER 151, V1_RETIREMENT 153
  -> 7, 8, 127, 42, 151, 153; requirements_changed: []
  240 requirements. Statuses are unchanged: ABSENT 21, SHELL_ONLY 3,
  PROGRAMMED 119, SPATIALLY_PROVEN 69, RUNTIME_PROVEN 27, HUMAN_ACCEPTED 1.
Gates (real exit codes, -LogPath):
  Static gates, merge-base board -> candidate board, from
  C:/ov/reports/5467439f2207/verification.json (base board 16:27:57Z at
  2ea28ee0; candidate board 16:39:35Z at 5467439f; fresh checkout, clean).
  The static gates take no -LogPath; their stdout hashes are in that file.
    completeness (ledger)  2 -> 2   INCOMPLETE both. Red on main by design.
    spatial                0 -> 0   All drift counts 0; records 8460 -> 9386.
    systemic               0 -> 0   new_actionable 0 -> 0,
                                    new_review 21 -> 21.
    period                 0 -> 0   fail_lines 0
    reader                 0 -> 0   unread 1124 -> 1120: 0 new vs baseline,
                                    4 resolved (domestic_radios crosley_pup and
                                    radiola_table; blockout private and wet)
    carriers               0 -> 0   forbidden 0, legacy_uncovered 0,
                                    ambiguous_dynamic 2 both
    rulings                0 -> 0   errors 0, warnings 0; citations 25 -> 30
    tools tests: all 42 exit 0 on both boards
      test_astra_packet, test_audio_emitters, test_check_rulings,
      test_data_consumption, test_gate_board, test_honed_stone_maps,
      test_interaction_implementors, test_interaction_prompt_carriers,
      test_lanes, test_lint_design_doc, test_m11c0_floor01_harness_contract,
      test_m11c1_floor01_source_ownership, test_m11c1_owner_first_export,
      test_m11c1_runtime_rehearsal, test_m11c1_scanner_consumer_adapter,
      test_m11c2_floor01_production_export,
      test_m11c2_production_harness_contract,
      test_orison_floor01_source_ownership, test_orison_spatial_dependencies,
      test_orison_v2_completeness, test_period_dates, test_prop_reference,
      test_prop_review, test_rehearse_orison_floor01_partition,
      test_room_checkpoint_linter, test_room_checkpoint_reconciler,
      test_room_evidence_verifier, test_room_gate_hook,
      test_room_layout_workbench, test_room_reconstruction_gate,
      test_room_reconstruction_progress, test_run_receipt,
      test_runtime_source_projections, test_systemic_situation_authority,
      test_upper_daylight_contract, test_v2_authoring_projection,
      test_v2_boiler_inlet_projection, test_v2_completion_projection,
      test_v2_fabrication_batch, test_v2_roof,
      test_v2_ventilation_fabric_projection, test_verify_candidate
    design-doc lint: 0
    gate files changed by the candidate: 1,
      tools/orison_spatial_dependency_manifest.json. It was regenerated with
      --update-manifest; v2_blockout ids went from 2,054 to 2,344.
    Verifier last line for 5467439f:
      MERGE-CANDIDATE 5467439f2207efb943bbfd2f976f00077aae4c5c
    The pushed head d416d4ee (C:/ov/reports/d416d4ee8a87/verification.md,
      16:30:44Z) has the same board except systemic drift.new_review
      21 -> 23 (REGRESSION), two new review findings
      (locations from C:/ov/systemic_now.json):
        new_review:3c7b30ac728507aa TEST_AUTHORITY_SHORTCUT,
          game/tests/orison_v2_patrol_stations_test.gd:41
        new_review:b5926cd581bc71c6 TIMER_IMPERSONATES_ACTOR,
          game/scripts/building/orison_v2_domestic_furniture.gd:164
      Its last line: BLOCKED regression: systemic: drift.new_review
      21 -> 23; regression: systemic: new defect new_review:3c7b30ac728507aa;
      regression: systemic: new defect new_review:b5926cd581bc71c6
    Neither run above was given --report. The commit carrying this report
      is verified in fresh mode with --report design/reports/V2-ENV-DOSSIER-2026-10-10.json
      and --base 2ea28ee0 before main moves (Open finding 2).
  Godot suites:
    The verifier ran with --no-godot (verification.md, "Needs human
    review"). The workflow records the reason as the fresh checkout lacking
    the machine-local runtime textures; this report did not re-check that.
    Suite-run evidence is the lane receipts committed under
    implementation/<tag>/receipts. Each receipt's log.stdout is its
    -LogPath, C:/ov/envimpl_out/<tag>/<name>.log unless noted. 101 tags,
    784 *.receipt.json files:
      - 783 are orison.run-receipt.v1 with evidence_kind suite_run. Of these,
        546 exited 0, 230 exited non-zero and 7 were killed at the 180 s
        serial ceiling (exit_code null).
      - 1 is slice34/receipts/keep_audit.receipt.json
        (orison.dossier-keep-audit.v1), 9 of 9 holds.
    The receipts folders also hold 243 other JSON reports: 88
      orison.environment-dossier-sweep.v1, 67 orison.fabrication-batch.v1
      and 88 schema-less node censuses.
    Every run receipt records a dirty lane checkout (source.dirty_paths
      400-416; 414 at slice80/patrol_stations), and every dirty_sample
      lists .import files only. The lane checkout C:/ov/envimpl has 414
      status entries now, including the untracked sweep scene
      game/tests/OrisonV2EnvironmentDossierSweep.tscn and its .gd. All 123
      sweep receipts ran that untracked test; the branch commits it only
      under art/reviews/v2_environment_design_20261008/sources/.
    No packet file is a runtime_contract. Eight schema-2 runtime_contract
      files exist outside the packet, uncommitted, and promote nothing:
      C:/ov/envimpl_out/ base53/news_receiving (1 failure, 3f3f0d75),
      slice57b/news_receiving (1 failure, 260849e8), slice57b/
      photo_receiving and radio_receiving (0 failures, 260849e8),
      slice67/news_receiving (1 failure, 2c25e683),
      slice80/fabrication_shots/service_instruments (0 failures,
      129e02d3); C:/ov/envimpl/tmp/resident-keys (0 failures, 2c25e683);
      C:/ov/envimpl/game (0 failures, 8f72926b).
    217 more lane receipts under C:/ov/envimpl_out are in neither the
      packet nor the census above: 86 exit 0, 130 non-zero, 1 timed out.
      Among them: slice64b (808eb3fb) 29 of 30 non-zero, slice66
      (d49faa9f) 20 of 22, slice65 (25d9743b) 3 of 7, all at slice 58-66
      WIPs (Open finding 15); slice76/coal_heap exit 1 at 7dd227dd;
      slice77/fabrication exit 1 at b2cf2b70; base48_routes/resident_key
      exit 1 at 14fec84e.
    Final batches:
    slice67: 48 runs, 39 exit 0. 46 ran at WIP 2c25e683 (game/art
      identical to bbe0f527). 2 are baseline runs at 260849e8, a slice-57
      WIP: base58__coal_delivery and base58__vantry_gateway (logs under
      C:/ov/envimpl_out/base58/).
      exit 0: resident_key "PASS" 86 waypoints, 55 checks; sweeps 0-11
        "COMPLETE" 54 spaces, 0 failures; sweep_city 130 views, 0 failures;
        upper_lighting 9257 checks; door_casings 107 openings and 15 service
        frames, 0 failures; hardware_drawers 1309 checks; shop_seating 953;
        radiator_tie 367; funeral_fittings 231; household_state 154;
        basement_route 88 wp; first_upper_hall 50 wp; apartment_door_route
        45 wp; rear_wing_a 45 wp; door_4b 32 wp; upper_transfers 28 wp;
        reading_furniture 25 wp; street_route 24 wp; boiler_route 17 wp;
        public_doors 17 wp; street_boundary 13 checks; heating 12 wp;
        basement_ground 11 wp; commensal PASS; passage_visibility PASS;
        import and import2. ventilation passes with "0 waypoints; 0 failures",
        which is weak evidence.
      non-zero (9):
        - apartment_batch "23727 checks, 204 failures" (S1, plus script
          errors SE1 and SE2).
        - coal_delivery and base58__coal_delivery, 1 failure each (S16).
        - vantry_gateway and base58__vantry_gateway, exit 5, "FAIL (5
          failures)" (S17).
        - fabrication "module_checks=12295 failures=1". Harness:
          B1_cleat_run camera station.
        - news_receiving "FAIL checks=771" (S15).
        - upper_furniture "1125 checks, 488 failures" (S7).
        - upper_kitchen "1189 checks, 206 failures" (S8).
    slice68 (WIP 088f987a; game/art identical to d238fea9): 26 runs, 24 exit 0.
      exit 0: roof_route_long "ROOF ROUTE: 53 waypoints; 0 failures" (log
        C:/ov/envimpl_out/slice68b/roof_route.log); fabrication 11108
        checks, 0 failures; hardware_stock 1418; hardware_drawers 1309;
        laundry_fittings 1139; cobbler 753; laundry_trade 347; diner_counter
        160; diner_till 130; diner_overhead 99; golden_repair 94 wp;
        apartment_door_route 45 wp; laundry_route 17 wp; public_doors 17 wp;
        wall_mount 4 wp; mail_bank PASS; door_casings and roof_drainage 0
        failures; sweeps 0-2 (9 spaces); sweep_city 130 views; import and
        import2.
      non-zero (2):
        - completion_interiors "40 waypoints; 1 failures" at
          F01_1A_FRIDGE_01 (S2). This was an unfiltered run: 1D's 25
          waypoints, then 1A's 15. The route returns at its first failure,
          so the 3D, 4D, 2C, 4C and staff legs never ran. The last per-home
          runs are at 54f7aee1 (3D), 815745ee (4C), 15aee765 (2C) and
          093e8d3f (4D); no staff leg ran anywhere.
        - roof_route, timed out on the serial runner. It was rerun as
          roof_route_long (exit 0).
    slice80 (16 runs at WIP 129e02d3, 7 at WIP 1d65072d; 1d65072d's game/art
      are identical to 287594f6 and d416d4ee): 23 runs, 18 exit 0.
      exit 0 at 1d65072d:
        patrol_stations "PATROL STATIONS: stations=7 marks=7 delivered=7
          failures=0"; watch_pair_b PASS 118/118; watch_register_b PASS 87/87;
          tour_key_b PASS 65/65; sweep_lobby 2 spaces, 0 failures;
          node_probe_b; import_b.
      exit 0 at 129e02d3:
        coal_heap 36 wp, 9 contacts; laundry_route 17 wp; tour_key PASS
        65/65; m08f PASS 29 checks; blockout PASS; sweeps 0-2 (10 spaces);
        node_probe; import and import2.
      non-zero (5), all at 129e02d3:
        - fabrication "12350 checks failures=2": two harness refusals, the
          tour-card capture actor and the B1_rinse_taps camera station.
        - m08e "FAIL (1)", headless (S10).
        - mail_route "4 waypoints; 1 failures", headless (S11).
        - watch_pair FAIL 117/118 and watch_register FAIL 86/87. Both were
          superseded by the _b runs after the test edits.
    slice81 (WIP 129e02d3): 2 runs, 2 exit 0. sweep_city and sweep_city_storm,
      each "DOSSIER SWEEP COMPLETE: spaces=0 city=130 failures=0".
    slice82 (the tip 5467439f; C:/ov/envimpl_out/slice82, not in the
      packet; 4 runs):
        - patrol_stations exit 0 "stations=7 marks=7 delivered=7 failures=0".
        - laundry_route exit 0 "17 waypoints; 0 failures".
        - import exit 0.
        - fabrication exit 1 "modules=1 module_checks=10137 failures=5":
          five "clear standing camera station" refusals (2B_dress_form,
          5B_aerial_wire, B1_cleat_run, B1_washer_supply, B1_rinse_taps).
    Most suites last ran on older trees than the tip; see the last-run
      table in section 5.
Numbers management asked for:
  Change register: 584 rows. verified 375, implemented 87, deferred 107,
    rejected 15. change_register.json equals content/status.py: 0 status or
    owner_notes mismatches.
    By priority:
      P1 153 (116 / 14 / 14 / 9)
      P2 321 (216 / 34 / 68 / 3)
      P3 110 (43 / 39 / 25 / 3)
    (verified / implemented / deferred / rejected.) Slice 81 statused the
    last 111 rows and changed no existing status: 106 deferred; 3 verified
    from captures (**CITY_PASSAGE-001**, **F01_LOBBY-004**,
    **F01_LOBBY-005**); 2 rejected (**F04_B_ALCOVE_APPROACH-002**,
    **F05_SERVICE_CROSSING-002**).
  Slices: README items 1-44 and 47-81. 79 slice commits; slices 45 and 46
    have no commit of their own. Slice 82 (5467439f) has no README item, no
    status.py entry and no packet evidence, and its message is the only
    commit message besides the merge 16f1d353 without the INERT marker.
  Patrol stations: 7 boxes, at B1 boiler room, F02-F06 public core, and
    F01 lobby. The signal register goes from 4 drops to 7.
  Diff vs merge-base at 5467439f: 3,415 files (3,021 added, 394 modified,
    0 deleted or renamed), +4,983,403 / -146,852 lines (d416d4ee: the same
    files, +4,983,383). 3,003 of the files (211,897,803 bytes) are the
    review packet.
  Largest binary: game/assets/props/surface_stock.glb, 103,057,996 bytes
    (98.28 MiB; 64,538,348 at base). That is 1,799,604 bytes under GitHub's
    100 MiB limit.
Changes outside the expected file boundary, and why:
  The expected boundary, as taken here: the packet; V2 owners, data and
  tests (orison_v2_* scripts, game/data/orison_v2*, orison_v2_* and
  OrisonV2*.tscn tests, the regenerated game/tests fixtures); art/blender
  family sources and scripts; art/data source plans; regenerated
  game/assets. Outside the packet the diff touches art/blender 166,
  art/data 38, art/tools 2, game/assets 47, game/data 44, game/scripts 32,
  game/tests 81, design 1 and tools 1 files. Outside that boundary:
  - art/tools/build_architectural_plate.py (slice 55): a lettering-free plate
    for portrait-atlas cell 3, **CITY_SHOP_PHOTO_SUPPLIES-001**. Provenance is
    in art/data/photo_portraits/generation_provenance.json. Slice 55 also
    changed art/data/photo_portraits/portrait_atlas.png, its runtime copy
    game/assets/props/photo_portraits/portrait_atlas.png, and
    art/data/photo_portraits/source_plan.json (borderline).
  - art/tools/build_wear_decals.py (slices 60, 61, 67): generator for the
    positional-wear decal PNGs. Slice 52 committed the first PNGs before the
    generator existed. Its byte-identical regeneration claim is unconfirmed.
  - game/scripts/building/exterior_detail_pass.gd and exterior_ground_decal.gd
    (slice 65): broadsides on the hoardings and feathered pavement marks.
    V1's building_root.gd builds ExteriorDetailPass directly
    (building_root.gd:266, 482-485, 789), and the pass creates the
    ExteriorGroundDecal (exterior_detail_pass.gd:198). Neither change is
    gated to V2, so V1 changes too. V2 reaches the same pass through
    orison_v2_street_boundaries.gd.
  - game/scripts/props shared with V1:
      - building_entry_sign.gd (slice 2), single-sided labels.
      - domestic_radio_prop.gd (slice 42), open cone speaker.
      - door_prop.gd (slices 5 and 43), darker room-leaf cream and the
        service-leaf frame.
      - functional_prop.gd (slice 9), visual bounds skip v2_surface_prop.
      - mail_bank_prop.gd (slice 68), overfull and ajar boxes.
      - watch_register_prop.gd and watch_station_prop.gd (slice 80), seven
        drops and an 8-row STATIONS table.
    The dossier fixes were made at the family or prop level. V1 impact is
    unconfirmed beyond the watch and tour-key suites. One V1 suite does
    fail on the branch: VantryGatewayTest loads
    res://scenes/building/orison_root.tscn (V1's building_root.gd) and
    exits 5 with five kiosk FAILs at 260849e8, 25d9743b (outside the
    packet) and 2c25e683. It was never run at 16f1d353 (S17).
  - game/tests/watch_pair_test.gd and watch_register_test.gd (slice 80): V1
    test assertions updated for the 8-row STATIONS table and the drops 1-7.
  - tools/orison_spatial_dependency_manifest.json (56 of 81 commits):
    regenerated for new and retired ids.
  - 15 paths marked -text in .gitattributes now hold CRLF blobs where the
    merge-base had none (first introduced in slices 6-10): nine
    art/blender/scripts/*.py, art/data/prep_cabinets/source_plan.json,
    four game/scripts/building/orison_v2_*.gd (domestic_doors,
    domestic_furniture, surface_props, surface_stock) and
    game/tests/orison_v2_completion_interiors_test.gd. Two more -text
    paths changed line endings: art/data/orison_v2/heating_source.json was
    already CRLF (437 -> 438 CRLF lines), and
    art/data/orison_v2/domestic_radios_source.json went from CRLF (281) to
    LF in slice 2 (45ef3257). .gitattributes itself is unchanged.
  - No .import, .uid, project.godot, AGENTS.md or DOCS.md file changed.
Open findings not fixed:
  1. The pushed head d416d4ee is BLOCKED by the verifier on two
     review-class systemic findings. Slice 82 (5467439f) moves the patrol
     round to E presses and hoists the kind list to SOURCE_KINDS; its
     verifier reports 0 regressions. 5467439f's message lacks the
     INERT marker, and its only runs are the 4 in
     C:/ov/envimpl_out/slice82.
  2. The sidecar design/reports/V2-ENV-DOSSIER-2026-10-10.json names 5467439f as
     head. The verifier accepts that only when the sidecar is committed in
     a commit whose parent is 5467439f, which this report's commit is; main
     fast-forwards to it. A --no-ff merge commit would need the head changed
     to that merge commit. Once main has moved, verify the report commit
     with --report and --base 2ea28ee056dba9a511b87086aa43ed29c3159d2a, or
     the merge_base claim is contradicted. --in-place cannot run in the
     canonical checkout ("--in-place requires a clean current checkout");
     use a fresh-mode run.
  3. Seven failing receipts are unexplained or contradicted by the notes
     (section 5). Among them, the 5C_bed0 bedding stance is labelled
     pre-existing, but slice2/bedding passed at c01e2e14; it is present at
     slice 43's commit cc3f2ac3 (bedding_base43, outside the packet), so
     the branch introduced it between those commits. The rear_wing_c
     collider is the 2C bookshelf this branch installed in slice 26.
  4. ApartmentBatch script errors appear from slice 7 (SE1) and slice 43
     (SE2) and are absent at 16f1d353. Part of that suite's checks never run.
     No note mentions them.
  5. The slice 76-80 suites mostly ran at 129e02d3, not the final tree
     1d65072d. Only seven runs exist at 1d65072d, and OrisonV2BlockoutTest
     never ran on the shipped F01_WATCH_STATION anchor in F01_LOBBY. No
     route suite that may cross the lobby (street_route, public_doors,
     resident_key, basement_route, coal_heap, mail_route,
     apartment_door_route) ran with the box there. Slice 82 changed
     orison_v2_domestic_furniture.gd, which every composed world mounts;
     only 4 runs exist at 5467439f.
  6. Ten baselines are branch-internal only (S8, S10-S18), two are
     inferred (S4, S5), and one is not identical (S6). The baselines base80,
     base48_routes, bedding_base43 and f01base exist only under
     C:/ov/envimpl_out.
  7. The README's squash claim fails for four slices. No slice-3 WIP
     (a159e499, 9f95732c, 0b5f8a7b) matches f99e4f2f. Neither slice-5 WIP
     matches 5bf9202c: 67c233a5 differs in orison_v2_domestic_doors.gd and
     orison_v2_readability_cues.gd, 47d93679 in orison_v2_domestic_doors.gd
     (only numerals2's 0b5f8a7b, filed under slice 3, matches it).
     4e589c0c differs from dae10668 by 2 files. 129e02d3 differs from
     d416d4ee by 6 files. The WIP shas are reachable from no ref; they
     survive as loose objects or reflog entries.
  8. Evidence-tag mismatches:
       - status.py headers cite slice14, 27, 28, 30 and 31, but the folders
         are the b/c variants.
       - status.py cites slice9b, which is not in the packet; its 7 lane
         runs at ae5f26f6 (6 exit 1 at startup, "remaining interiors
         refused: invalid preparation cabinet mechanism") are only under
         C:/ov/envimpl_out/slice9b.
       - README cites slice26b; its three runs are in the packet as
         slice26/receipts/rerun_b__{bookshelves,household_state,import}.
       - Commit 4433a936 cites routes6/; the folder is routes6b.
       - Commit 355fb4ba (slice 27) cites implementation/slice27/; the
         folder is slice27b.
  9. Two documents still say the work changes no code or data:
     design/V2_ENVIRONMENT_DESIGN_DOSSIER_2026-10-08.md and the packet
     README.
  10. The slice 80 refabrication census is not committed: the
      OrisonV2CensusCapture.tscn scene and census80/register_census.json.
  11. first_shift_director.gd maps any central drop 2 to
      F02_STATION_2A_LANDING. In V2 the F02 core box now satisfies the
      opening-station step. This is untested.
  12. Status.py inaccuracies:
        - It calls the 2C/4C failure "kitchen-leg"; the logs show the
          bath-door leaf.
        - It names 0bac8f87 for resident_key; the receipt says 3f3f0d75.
        - It calls 129e02d3 "runtime-identical" to 1d65072d. The git diff
          contradicts this (6 files), and the receipts carry different
          runtime_inputs_sha256 (3ea8ae43... against 63cf49d4...).
        - Every slice-80 row says "The static gate board at 1d65072d
          matches slice 35's on all 49 gates" (5 rows). That compares
          against a slice board, not the merge-base, and it hides the
          systemic new_review 21 -> 23 regression.
  13. Slice 82 has no status.py entry, so its fabrication refusals for
      2B_dress_form and B1_washer_supply are not discussed anywhere.
  14. The positional-wear mount only push_errors on refusal; it never sets
      startup_failed.
  15. Slice commits 58 (e145c48d) through 66 (8f35dc22) do not compose the
      V2 world: each carries the id 6A_light_box in domestic_objects.json,
      domestic_furniture.json and orison_v2_blockout.json as well as
      surface_stock.json, and lane runs there log "surface props refused:
      [missing support or occupied identity: 6A_light_box]". Slice 67
      (bbe0f527) renames it. A fast-forward puts these nine commits on
      main; they were never verified on their own.
  16. 217 lane receipts are outside the packet (section 1, Godot suites),
      130 of them non-zero. The packet census of 783 covers only the copies.
Decision needed from owner:
  The merge target is settled by the owner's request to merge the branch:
  its tip 5467439f is this candidate. Merging only the pushed d416d4ee
  would merge a BLOCKED commit.
  1. Rulings that gate deferred rows (section 8):
       - Prohibition
       - the election headline in the Bible
       - commensals C2
       - the owner JSON's A06 item
       - K2, the clock_prop "Hold E" carrier
       - restating the four monitor-top kitchen rows
       - the 16/16 light budget
       - casket records in the protected building_layout.json (RUL-004)
  2. Whether to accept the V1-visible changes in shared props, and the V1
     watch tests coupled to V2's 8-row STATIONS table.
  3. Whether V2's F02 core box should satisfy the first-shift
     opening-station step.
  4. Where new small forms go, given surface_stock.glb's 1.72 MiB headroom.
MERGE-CANDIDATE 5467439f2207efb943bbfd2f976f00077aae4c5c
```

## 2. What the branch does

The branch implements the 2026-10-08 V2 environment design dossier. The
dossier is a room-by-room review of the V2 building and its city block. Its
change register holds 584 rows (BW building-wide families, B1, F01-F06, ROOF and
CITY spaces), each with a priority (P1 reads wrong from the doorway, P2 story
or period truth, P3 polish) and an action.

- **The packet (e63ce4f6).** It adds `design/V2_ENVIRONMENT_DESIGN_DOSSIER_2026-10-08.md` and
  `art/reviews/v2_environment_design_20261008`: the README, the dossier PDF
  (34,407,932 bytes), `change_register.json` with its .csv and .xlsx copies
  (584 rows, none statused yet) and the `content/` sources (`areas_*.py` and
  others). That is 1,243 files: 1,242 packet files and the design document.
  `content/status.py` first arrives with slice 1 (8df6ee18). The packet is
  211,897,803 bytes (3,003 files) once the evidence is in. e63ce4f6's parent
  is fdf01a36; main moved 11 commits from there to 2ea28ee0.
- **The merge (16f1d353).** It takes origin/main 2ea28ee0 into the branch.
  Its game tree is identical to the merge-base: only `art/reviews` and one
  design document differ. So the receipts run at 16f1d353 (baseline_* and
  bisect_16f1d353) count as merge-base baselines.
- **The slice workflow (slices 1-81).** Each slice:
  1. Authors a set of rows as WIP commits.
  2. Verifies the WIP through the Godot lane (`tools/run_godot_serial.ps1`,
     `tools/run_godot_long_suite.ps1`, each run with `-LogPath`), writing
     receipts to `C:/ov/envimpl_out/<tag>/`.
  3. Copies the receipts and capture images into `implementation/<tag>/`.
  4. Statuses the rows in `content/status.py` and regenerates
     `change_register.json`.
  5. Squashes the WIPs into one slice commit.
  6. Is meant to prove the squashed commit's game and art trees identical
     to the verified WIP. README lines 245-247 say `git diff --stat <wip>
     <commit> -- game art` confirms it; the packet under `art/reviews`
     always differs, so the check needs `':(exclude)art/reviews'`. With
     it, the claim fails for slices 3, 4 and 5 and for slice 80's
     129e02d3 runs (section 1, Open finding 7).

  Later batches verify several slices at once: slice54b covers 53-54,
  slice57b covers 55-57, slice67 covers 58-67, slice68 covers 68-75 and
  slice80 covers 76-80.
- **Status changes.** Every slice commit's message from 1 to 81 declares
  INERT; the merge 16f1d353 and slice 82 declare nothing. No commit changes
  a ledger status: the verifier's ledger before and after are identical,
  and requirements_changed is empty.
- **Slice 81 (d416d4ee).** It statuses the last 111 rows with their reasons:
  106 deferred, 3 verified from captures (**CITY_PASSAGE-001**,
  **F01_LOBBY-004**, **F01_LOBBY-005**) and 2 rejected
  (**F04_B_ALCOVE_APPROACH-002**, **F05_SERVICE_CROSSING-002**). It changes
  no existing status.
- **Slice 82 (5467439f).** It answers the verifier's block on d416d4ee. The
  patrol test now takes the tour key with E at its guard, opens and cranks
  each box with E and hangs the key back. `validate()` in
  `orison_v2_domestic_furniture.gd` reads its kinds from the file-level
  SOURCE_KINDS instead of an inline list (the "mopbucket" kind entered that
  list in slice 32, 6c12f983). It touches only those two files.

## 3. What changed in the world

Rows cited here are verified unless marked. 25 are implemented only, 13 of
them partial (their owner_notes begin "Partial:"): **BW-002**,
**F05_C_BED2-001**, **F06_C_BED2-001**, **BW-011**, **BW-009**,
**F01_A_BATH-002** (partial), **F01_PUBLIC_CORE-002** (partial),
**F02_LANDING-002** (partial), **F03_C_RESTRICTED-002** (partial),
**F05_D_RESTRICTED-002** (partial), **F01_WATCH-001**,
**F01_MAIL_TELEPHONE-002**, **F01_COMMON_B-002**, **B1_ELECTRICAL-001**,
**B1_COAL_ROOM-001** (partial), **B1_BOILER_APPROACH-001** (partial),
**B1_BOILER_ROOM-002**, **B1_COAL_ROOM-003** (partial),
**ROOF_PUBLIC_CORE-003**, **CITY_SHOP_NEWS_CIGARS-001** (partial),
**CITY_SHOP_HARDWARE_PAINT-001** (partial), **CITY_SHOP_KEYS_CUT-001**
(partial), **CITY_SHOP_RADIO_SERVICE-001** (partial), **CITY_STREET-002**,
**CITY_STREET-005** (partial).

### Apartments

- **Building-wide domestic families.**
  - The fridge count is corrected: 4D's monitor-top becomes a dry icebox
    (**F04_D_KITCHEN-003**).
  - Second beds are out of 2C, 5C and 6C (**BW-002**, **F02_C_BED2-001**,
    **F05_C_BED2-001**, **F06_C_BED2-001**).
  - Radios are in all 18 homes (**BW-011**).
  - Period furniture forms replace the post-1950 variants (**BW-003**).
  - Bath tile is on one face only (**BW-004**).
  - Room leaves are painted a step lower (**BW-016**).
  - The six completion homes have resident furniture (**BW-001**), and
    signal outlets are added (**BW-013**).
  - 4D's closet is locked (**F04_D_STUDY-001**).
- **Kitchens.**
  - Kitchen sets on the drainboards and prep cabinets of all 18 homes
    (**F01_A_KITCHEN-001** to **F06_C_KITCHEN-001**).
  - Drip pans under the fourteen iceboxes (slice 22, **F01_D_KITCHEN-002**
    to **F06_B_KITCHEN-002**). Eleven of these rows are titled "Ice card
    and drip tray evidence". Three (**F02_A_KITCHEN-002**,
    **F03_D_KITCHEN-002**, **F04_D_KITCHEN-002**) carry the title
    "Monitor-top electric evidence", which the four deferred households
    with a FridgeMonitor also carry (section 6).
  - Owner enamel finishes on six ranges (**F05_C_KITCHEN-003**,
    **F06_C_KITCHEN-003**).
- **Vestibules and private halls.**
  - Hall stands (**F02_A_VESTIBULE-001** and others).
  - Chain guards on the entry leaves (**F01_A_VESTIBULE-002** to
    **F06_C_VESTIBULE-002**).
  - Unit numerals on every entry leaf (**BW-022**).
  - One use object in each private hall (**F01_A_PRIVATE_HALL-001** to
    **F06_C_PRIVATE_HALL-001**).
  - 1A's corrected notice (**F01_A_VESTIBULE-003**).
- **Rooms.**
  - Paper, books and small stock on residents' surfaces (**F04_A_MAIN-001**).
  - Wall art (**F04_B_MAIN-001**, **F02_C_MAIN-002**).
  - Garment rails and hung blankets (**F04_B_CLOSET-001**,
    **F02_C_BED2-002**).
  - Bedside stock (**F01_A_BED-002**, **F01_D_BED-002**).
  - Resident bath sets in all 18 baths (**F01_A_BATH-001** to
    **F06_C_BATH-001**).
  - Positional bath wear: a grout ring, the mop corner and a hem water line
    (**F01_A_BATH-002**, partial, and others).
- **Resident-specific objects.**
  - 2B's sewing machine (**F02_B_MAIN-001**).
  - 3B's radio teardown (**F03_B_MAIN-001**).
  - 5C's easel and canvases (**F05_C_BED2-002**).
  - 3A's propagation shelves (**F03_A_MAIN-001**).
  - 6A's backdrop and print line (**F06_A_MAIN-001**).
  - 4C's colour board (**F04_C_MAIN-005**).
  - 3A's memorial pot (**F03_A_KITCHEN-003**).
  - 6C's ledger (**F06_C_MAIN-002**).
  - 6A's light table (**F06_A_KITCHEN-003**).
  - 4D's lost-property shelves (**F04_D_STUDY-002**).

### Public floors

- **Upper halls and cores.**
  - Public hall practicals (**BW-017**).
  - The building's paper trail on every core level (**F01_PUBLIC_CORE-001**
    to **ROOF_SERVICE_CORE-001**).
  - Thresholds at every household door (**F02_WEST_HALL-001**,
    **F06_EAST_HALL-001**).
  - Stair treads dished on the walking line, plus one piece per landing
    (**F01_PUBLIC_CORE-002**, **F02_LANDING-002**, both partial).
  - Hall wear (**F02_WEST_HALL-002**), strengthened in slice 67.
  - The sealed 3C threshold (**F03_C_RESTRICTED-002**, partial).
  - 5D's soot ghost (**F05_D_RESTRICTED-002**, partial).
  - Cal's aerial wire (**F05_WEST_HALL-003**).
  - 6D's padlock (**F06_D_RESTRICTED-002**).
- **Ground floor.**
  - The lobby noticeboard and photograph (**F01_LOBBY-001**,
    **F01_LOBBY-002**).
  - The common-room armchair (**F01_COMMON_B-001**).
  - The service rooms (**F01_PACKAGE-001**, **F01_WATCH-001**,
    **F01_MAIL_TELEPHONE-002**).
  - The reading room's bookcases (**F01_COMMON_B-002**).
  - The mail bank, overfull and ajar (**F01_MAIL_TELEPHONE-001**).
  - The night watch's kettle and the tour card (**F01_WATCH-002**).
  - The patrol stations and the seven-drop register
    (**F01_MAIL_TELEPHONE-003**, section 4).

### Basement

- Storage bay contents and laundry baskets (**B1_RESIDENT_STORAGE-001**,
  **B1_LAUNDRY-001**).
- The boiler room's tools and the signal frame (**B1_BOILER_ROOM-001**,
  **B1_ELECTRICAL-001**).
- The laundry rota, cleated wiring and the coal shovel (**B1_LAUNDRY-002**,
  **B1_ELECTRICAL-002**, **B1_COAL_ROOM-001**).
- Coal dust and the chalked log (**B1_BOILER_APPROACH-001**,
  **B1_BOILER_ROOM-002**).
- The shadow toolboard (**B1_MAINTENANCE_SHOP-002**).
- The nook's reader (**B1_PUBLIC_CORE-001**).
- The coal chute on a boarded bunker, with the coal route through both
  vestibule leaves (**B1_COAL_ROOM-002**, **B1_COAL_ROOM-003**).
- The washers' supply and the rinse tubs' taps (**B1_LAUNDRY-004**).
- Register for B1: 13 verified, 8 implemented, 3 deferred.

### Roof

- The bulkhead's garden kit (**ROOF_PUBLIC_CORE-003**).
- The house tank in staves (**ROOF_DECK_WEST-004**).
- Most roof-deck rows are deferred on the sloped-deck support path
  (section 6).
- Register for ROOF: 4 verified, 5 implemented, 16 deferred.

### City and shops

- The news booth's stock and the worn mat (**CITY_SHOP_NEWS_CIGARS-001**,
  **CITY_SHOP_NEWS_CIGARS-003**).
- Hardware paint tins, the bell and the night card
  (**CITY_SHOP_HARDWARE_PAINT-001**, **CITY_SHOP_HARDWARE_PAINT-002**).
- Photo supplies (**CITY_SHOP_PHOTO_SUPPLIES-001**).
- Keys (**CITY_SHOP_KEYS_CUT-001**).
- Radio service (**CITY_SHOP_RADIO_SERVICE-001**).
- The pawnbroker (**CITY_SHOP_PAWNBROKER-001**).
- The funeral register (**CITY_SHOP_FUNERAL_PARLOUR-002**).
- The luncheonette's menu board, shakers and worn stool
  (**CITY_SHOP_LUNCHEONETTE-001**, **CITY_SHOP_LUNCHEONETTE-002**).
- The cobbler (**CITY_SHOP_SHOE_REBUILDING-001**).
- The laundry's tickets (**CITY_SHOP_MODEL_LAUNDRY-001**).
- Wordless election broadsides and feathered pavement marks
  (**CITY_STREET-002**, **CITY_STREET-005**).
- Register for CITY: 20 verified, 10 implemented, 40 deferred.

### Building-wide engineering

- **Blockout.** A 4 mm far-face skin on wet walls, and dished treads that
  are visual only (`game/scripts/building/orison_v2_blockout.gd`).
- **Positional wear.** A new owner,
  `game/scripts/building/orison_v2_positional_wear.gd`, with 109 decals in
  eleven kinds.
- **Labels.** Shop families now build Label3D labels (RUL-008).
- **Household save.** The save owner widens from 186 to 203 records.
- **Surface stock.** 247 assemblies, up from 55.
- **Readability light pools** are off in production (**BW-009**,
  implemented).
- **Register for BW:** 9 verified, 3 implemented, 8 deferred, 3 rejected.

## 4. The patrol stations (owner direction, 2026-10-10)

Sources: the commit message of 287594f6, README item 80, and the STATIONS
comment in `game/scripts/props/watch_station_prop.gd`. The register has no row
of its own for this work; its evidence is filed under **F01_MAIL_TELEPHONE-003**.
`design/RULINGS.json` is untouched.

**Where the boxes hang.** These are interaction anchors in
`game/data/orison_v2_blockout.json`:

| Station | Anchor | Room | Position, yaw |
|---|---|---|---|
| 1 | **B1_WATCH_STATION** | **B1_BOILER_ROOM** | [9.57, 1.42, 2.4], pi/2 |
| 2-6 | **F02_WATCH_STATION** to **F06_WATCH_STATION** | **F02_PUBLIC_CORE** to **F06_PUBLIC_CORE**, north wall | [1.6, 1.42, 3.78], pi |
| 7 | **F01_WATCH_STATION** | **F01_LOBBY**, beside the watch room | [-4.85, 1.42, -3.92], pi |

- Station 7 was in **F01_PUBLIC_CORE** at [-1.13, 1.42, -1.5], yaw pi/2, at
  WIPs fed69144 and 129e02d3. At 1d65072d it moved to **F01_LOBBY**, and its
  STATIONS id was renamed from F01_STATION_CORE (serves F01) to
  F01_STATION_LOBBY (serves lobby) (`git diff 129e02d3 1d65072d`). The tour
  card committed in slice 79 (027a22ca, `domestic_furniture.json`
  notice_text) already read "BOX 7 LOBBY", so the move brought the anchor
  into line with the card. No commit message states the motive; the three
  WIPs share one subject.

**How they mount.**
- `orison_v2_runtime_root.gd` adds PATROL_STATIONS.
- At the end of _compose_service_round_props, after the network has its
  register and key guard, it mounts one WatchStationProp per anchor
  through `mount_consumer`.
- A refusal sets startup_failed.
- The STATIONS table gains F02-F06_STATION_CORE and F01_STATION_LOBBY,
  making 8 rows. V1's F02_STATION_2A_LANDING and V2's F02_STATION_CORE
  both carry number 2. The network de-duplicates by station_id only.

**The register.**
- SHUTTER_NUMBERS goes from 1-4 to 1-7, with drops at 50 mm centres.
- V1 wires only drops 1 and 2, but V1's lobby register redraws with seven
  narrower drops.
- The native fabrication was rebuilt:
  - The M05 source_plan goes from 40 to 55 meshes. The unchanged parts
    match the old census within 4.3e-7 m.
  - source_sha256 is the LF blob hash of `watch_register_prop.gd`.
  - `service_instruments.glb` goes from 33,065,404 to 33,622,224 bytes.
- The census scene and its output are not committed.

**Proof.**
- `game/tests/orison_v2_patrol_stations_test.gd` checks the round: 7 boxes
  on one network, drops 1-7, each case at 1.42 m and flush on a wall, the
  delivered order 1-7, and reset. Those individual checks come from the
  test source: the log prints only the summary line, and the wrapper
  receipt records pass_count 0 and fail_count 0. They are implied by
  failures=0, not shown.
- implementation/slice80/receipts/patrol_stations.log.receipt.json: exit 0,
  long runner, windowed, 64.88 s, at 1d65072d. The log reads "PATROL
  STATIONS: stations=7 marks=7 delivered=7 failures=0". It is a suite_run,
  not a runtime_contract.
- At d416d4ee the round is driven by method calls. That is the
  TEST_AUTHORITY_SHORTCUT finding that blocks the pushed head. Slice 82 at
  5467439f drives it with E presses and passes with the same result line
  (`C:/ov/envimpl_out/slice82/patrol_stations.log`).
- The V1 suites at 1d65072d: WatchPair 118/118, WatchRegister 87/87,
  TourKey 65/65.
- The tour card (slice 79, a Label3D) reads "BOX 1 BOILER ROOM / BOXES 2 TO
  6 FLOORS 2 TO 6 / BOX 7 LOBBY".
- No route suite ran with the station 7 box in the lobby (section 1, Open
  finding 5), so whether it obstructs a route is unconfirmed.

## 5. Verification and standing pre-existing failures

**Exit codes.** 237 of the 783 run receipts did not exit 0 (230 non-zero,
7 killed at the ceiling). The split below is the author's classification;
an independent recount reproduced the total but not every class count, so
the split is unconfirmed.

| Class | Count | What they are |
|---|---|---|
| (a) Same failure class at a baseline | 155 | 112 at the merge-base-equivalent 16f1d353. Most of these are ApartmentBatch and UpperFurniture receipts, which match the baseline by failure label, not by count (S1: 192 at baseline against 204 at 2c25e683; S7: 396 against 488). The branch also edited the tests the baselines ran (apartment_batch, completion_interiors, upper_furniture, upper_kitchen), so the 16f1d353 receipts ran main's versions. 43 match only at a branch-internal baseline, so whether they fail on main is unconfirmed. |
| (a*) Called pre-existing without a matching baseline | 35 | 3D and 4C completion routes have no baseline run. 4D has one, and it contradicts the label: baseline_completion_4D/completion_4D at 16f1d353 fails earlier, at F04_D_BED_STORAGE_DOOR after 7 waypoints, so the branch's 12-waypoint fridge failure is not shown pre-existing (S6). |
| (b) Harness | 11 | 9 fabrication capture refusals and 2 headless pointer runs. |
| (d) Real, explained, superseded by a later rerun | 19 | 10 passed only after a test edit, 9 after a data fix. |
| (e) Killed at the 180 s ceiling | 7 | Each has a long-runner or later rerun. |
| (f) The suite's own watchdog or precondition | 3 | For example slice37/earned_dream, which stops at its own "earned input save exists = false" precondition. |
| (c) Unexplained or contradicted | 7 | Listed below. |

**Standing failures.** These are the failures seen across the branch's runs.

| | Suite | Signature on the branch | Shown at |
|---|---|---|---|
| S1 | OrisonV2ApartmentBatchTest | Seven label classes. 192 at baseline. 236 on the branch (receiver texture class 98 -> 142 as receivers go 12 -> 18), then 204 from d351823a (receiver class 110). | Same classes at 16f1d353 (baseline_apartment_batch/suite), count not identical: 204 is 12 more than baseline, all in the receiver-texture class added by the six new receivers (**BW-011**). Since 6bb07f16 (slice 12) the test also skips category furniture whose provenance note begins "V2 environment dossier". |
| S2 | CompletionInteriors 1A | 1 failure at F01_1A_FRIDGE_01 | 16f1d353 (baseline_completion/completion_windowed, bisect_16f1d353/completion_1A) |
| S3 | CompletionInteriors 2C | 1 failure at the F02_C_PRIVATE_HALL_BATH_DOOR leaf, 9 waypoints | 16f1d353 (baseline_completion_2C/suite) |
| S4 | CompletionInteriors 4C | 1 failure at the F04_C_PRIVATE_HALL_BATH_DOOR leaf | Not shown. Inferred from S3. |
| S5 | CompletionInteriors 3D | 1 failure at F03_3D_FRIDGE_01 | Not shown. Inferred from 1A. One run (slice6 at 992ae898) fails earlier, at F03_D_BED_STORAGE_DOOR after 7 waypoints. |
| S6 | CompletionInteriors 4D | 1 failure at F04_4D_FRIDGE_01, 12 waypoints | Not identical. At 16f1d353 it fails earlier, at F04_D_BED_STORAGE_DOOR (7 waypoints). |
| S7 | OrisonV2UpperFurnitureTest | "mesh has material binding" plus 2 desk checks; 402 to 496 on the branch, 488 at the last run (2c25e683) | Class shown at 16f1d353, count not: 396 there (394 binding + 2 desk) against 488 (486 + 2). The extra binding failures come from the branch's new stock meshes. slice14base 78a9a903 (444) and baseline_ufbase30 40110d19 (484) are branch commits. The test's roster check also changed from 50 to 51. |
| S8 | OrisonV2UpperKitchenTest | Material binding for 5A-6C plus 3 stances; 238 to 240 (240 at 4444e1e1 and 3ee31793), then 206 from WIP 2c52a53e (slice24c, squashed into ac6294fe) | Branch only: slice9h at 66994c91 |
| S9 | OrisonV2IntegratedTest | "FAIL 04 street-to-bedside traversal", BLOCKED at (1.590925, 3.835109, -2.50041) | 16f1d353 (baseline_integrated/suite) |
| S10 | OrisonV2M08ESpatialTest | BLOCKED at **PASSENGER_SHAFT_EAST** | Branch only: base80 088f987a and f01base 432ad0a5, both outside the packet |
| S11 | OrisonV2MailRouteTest | tour_key_guard prompt false in headless runs | Not isolated. Both failing runs are headless (129e02d3, and base80 at 088f987a). The only windowed passes are at older trees (slice28b c6e01928, 16 waypoints; f01base 432ad0a5). No windowed run exists on a tree with slices 76-80, which changed `orison_v2_runtime_root.gd` (it builds the guard) and `watch_station_prop.gd`. Calling it a harness failure is an inference. |
| S12 | OrisonV2DoorHingeTest | 10 failures (1 fabricated-hinges, 9 coaxial) | Branch only: slice10c 6d99760d |
| S13 | OrisonV2FloorSurfaceTest | 57 failures | Branch only: floorbase 9f95732c |
| S14 | OrisonV2GroundCoreTransferRouteTest | Stops one riser above the basement landing | Branch only: base47_ground_core 6d62caab |
| S15 | OrisonV2NewsReceivingTest | News keyboard stance, plus a script error at news_receiving_test.gd:70 | Branch only: base53 3f3f0d75 |
| S16 | OrisonV2CoalDeliveryTest | 1 failure at the F01_INNER_DOOR leaf | Branch only: base58 260849e8. Superseded: rerouted in 0d9a2b4c, and coal_heap passes 36 waypoints at 129e02d3. |
| S17 | VantryGatewayTest (a V1 scene: orison_root.tscn) | Exit 5, five kiosk failures | Branch only: base58 260849e8. Never run at 16f1d353. No later run than 2c25e683. |
| S18 | OrisonV2WakeReconstructionTest | 33 checks pass, then the suite's own 150 s watchdog | Branch only: 7478bd9c (slice 25's commit) and c9bc2317 (a slice-26 WIP), in slice27b. Never run at 16f1d353 or after slice 26. |

**When each suite last ran.** The latest packet receipt per suite (started
time order), plus slice 82. No standing-failure suite ran on a tree that
carries slices 68-82, except CompletionInteriors (1D and 1A legs only) and
the slice 80 suites.

| Last run at | Suites (exit) |
|---|---|
| 67c233a5 (slice-5 WIP) | IntegratedTest (1) |
| 9f95732c | FloorSurfaceTest (1) |
| 6d99760d | DoorHingeTest (1) |
| 7478bd9c, c9bc2317 | WakeReconstructionTest (1) |
| 991e7f05 | EarnedDreamBoundaryTest (1), BookshelvesTest (0) |
| 777d2ec2 | BeddingTest (1) |
| 36f8f9bb | RearWingCApartmentRouteTest (1) |
| 14fec84e | GroundCoreTransferRouteTest (1), PublicFurnishingsTest and stair suites (0) |
| 2c25e683 (slice-67 WIP) | ApartmentBatch (1), UpperKitchen (1), UpperFurniture (1), NewsReceiving (1), HouseholdState, UpperLighting, ResidentKey, BasementRoute, StreetBoundaryRoute and 15 more (0) |
| 260849e8 (slice-57 WIP) | CoalDelivery (1), VantryGateway (5) |
| 088f987a (slice-75 WIP) | CompletionInteriors (1), PublicDoors, ApartmentDoorRoute, RoofRoute, MailBank and 12 more (0) |
| 129e02d3 (slice-80 WIP) | FabricationBatch (1), M08ESpatial (1), MailRoute (1), Blockout, CoalHeap, LaundryRoute, m08f (0) |
| 1d65072d (= d416d4ee game/art) | PatrolStations, WatchPair, WatchRegister, TourKey, sweep_lobby, NodeProbe, WalkTest import (0) |
| 5467439f (slice 82, outside the packet) | PatrolStations, LaundryRoute, import (0); FabricationBatch (1) |

**Unexplained or contradicted (7).**

1. slice42/apartment_batch: 252 failures at b0770fb2. The notes never cite
   it, and its stderr file is gone.
2. slice44/bedding: 4 failures (the 5C_bed0 inspection stance, two
   batched-role checks and one shared-variant check); only 5C_bed0
   survives in bedding_fix. A run at slice 43's commit (bedding_base43,
   cc3f2ac3, outside the packet) also fails on 5C_bed0, so "as at slice 43"
   holds within the branch. But status.py calls it pre-existing, and
   slice2/bedding passed with 0 failures at c01e2e14, so the branch
   introduced it between those commits.
3. slice44/bedding_fix: the same 5C_bed0 failure, at 777d2ec2. No later
   bedding run exists.
4. slice49/rear_wing_c: the collider is F02_2C_BOOKSHELF_01, which this
   branch installed in slice 26. Likely a branch regression.
5. slice5/door_casings: 3 portal-label failures. slice5b passes, but no
   cause is stated.
6. slice50/sweep_2: the runtime refused native household objects.
   Superseded by slice52b; no cause is stated. The receipt's
   repository_head is 0bac8f87 (slice 51's WIP), not slice 50's 14fec84e.
7. slice9/fabrication: household_fridges collision sizing. Superseded by
   slice9e; no cause is stated.

Two more apartment-batch totals are cited nowhere (no "252" or "254" in
status.py, the README or any commit message): slice2/apartment_batch, 254
failures at c01e2e14, and slice12/apartment_batch, 252 at 76d0a584. The
class table does not say where they fall.

**Script errors in the apartment batch.** 53 ApartmentBatch receipts, from
slice7 through slice67, record script errors that are absent at 16f1d353,
slice2 and slice2b:

- SE1, from slice 7: "Invalid access to key '1A'" at
  apartment_batch_test.gd:339.
- SE2, from slice 43: "Invalid access to key 'spaces'" at
  orison_v2_blockout.gd:827.

Both abort part of the suite, so "236/204 as before" does not show this.

## 6. Deferred work by blocker

| Blocker | Rows | What unblocks it |
|---|---|---|
| Service spine is a shell (**BW-006**); 17 of these are maintenance-evidence rows | 23 | Blockout and stair generator work: risers in a chase, the lift landing, the service stair finish, dado, cage bulbs |
| Roof decks are a sloped membrane; the inspector seats on a flat datum | 13 | A sloped-deck support path in the domestic-object inspector |
| Bar fittings are census-bound fabrications | 11 | A bar pass that re-captures each census and refabricates |
| The bodega has no V2 fittings family | 5 | A bodega fittings family |
| "Monitor-top electric evidence" rows describe icebox evidence | 4 | The owner restates the rows |
| Pinned or bound sources: 5B larder, ventilation registers, 5A plan table | 3 | A new larder mechanism hash, a register-set change, a re-planned lamp cord |
| Protected shop layout (RUL-004), caskets | 1 | Authorized layout change or another source owner |
| Material catalogue gaps: chain-link, linoleum, terrazzo scale | 3 | New catalogue entries (RUL-008) |
| Light budget 16/16 and practical lights | 3 | A lighting-budget decision or an emissive finish, plus an F04 landing sconce |
| Owner rulings: Prohibition, election, C2, A06, K2 | 7 | Section 8 |
| City shell: closure masses, alley walls, light court | 4 | A city-shell generator pass |
| Window joinery has no blind, curtain or ice-card states | 2 | Joinery variants driven by sleep schedules |
| FX, weather, audio, rendering. status.py **CITY_STREET-007** reports the storm sweep (WEATHER_SIMULATE=storm) matching the clear one at a mean pixel difference of 0.12/255 on one view, facade_front_wide. No receipt records the comparison or the weather setting, neither sweep log has a weather line, and the packet keeps only one frame of each pair (implementation/slice81/manifest.json maps both sources to one image). | 6 | Port V1's weather owner, steam billboards, the acoustic bed, the 6A bath reflection |
| City-owned exterior ground has no static-object family | 3 | A street-furniture owner that passes the route and containment tests |
| Shell joints and plaster emission | 3 | A shell-joint pass, side-aware plaster, the F04 lift landing finish |
| Positional-wear passes not yet run (facade, alley, cobbler counter) | 3 | Those decal passes |
| Shop and arcade fittings (10 of 11 rear rooms bare, **BW-023**) | 6 | A rear-room pass and a druggist pass, the diner backbar, cloth garments |
| Domestic casework, soft goods, millwork | 5 | Casework, bedding, curtain and mirror variants, a millwork pass |
| Other: chimney joints, kiosk station | 2 | A roof plant pass, a new city sweep station |
| **Total** | **107** | |

Representative rows:

- **Service spine:** **F01_SERVICE_HALL-001**, **F04_SERVICE_CROSSING-001**.
- **Roof decks:** **ROOF_DECK_WEST-001**, **ROOF_DECK_NORTHEAST-001**.
- **Bar:** **CITY_BAR_ROOM-001**, **CITY_BAR_WC-002**.
- **Bodega:** **CITY_BODEGA-001** to **CITY_BODEGA-005**.
- **Monitor-top:** **F01_A_KITCHEN-002**, **F03_A_KITCHEN-002**,
  **F05_B_KITCHEN-002**, **F06_C_KITCHEN-002**.
- **Pinned sources:** **F05_B_KITCHEN-003**, **F05_D_RESTRICTED-003**,
  **F05_A_MAIN-002**.
- **Protected layout:** **CITY_SHOP_FUNERAL_PARLOUR-001**.
- **Catalogue:** **B1_RESIDENT_STORAGE-002**, **BW-021**, **BW-020**.
- **Light budget:** **B1_BOILER_ROOM-003**, **CITY_SHOP_OTIS_SON-001**,
  **F04_LANDING-003**.
- **Weather and FX:** **CITY_STREET-007**, **F06_A_BATH-003**.

## 7. Rejected rows (15)

| Row | Priority | Reason |
|---|---|---|
| **BW-005** | P1 | Measured at 1fadb5ad (implementation/ducts): the branches hang on seated trapeze hangers and end in register boxes. A P3 sheet-collar remainder stays open. |
| **BW-018** | P1 | Measured: all 19 water closets show LowCistern (implementation/baths). The raised lid hides it front-on. |
| **BW-014** | P3 | The peephole is a brass lens, and the bright disc is lamp specular. The wainscot relief stays open. |
| **F02_C_KITCHEN-004** | P1 | F02_2C_FRIDGE_01 is at yaw 90.0 in the census. The skew is perspective (implementation/slice1). |
| **F04_C_KITCHEN-004** | P1 | F04_4C_FRIDGE_01 is at yaw 90.0, with no clipping in the data. |
| **F05_C_KITCHEN-004** | P2 | F05_5C_FRIDGE_01 is at yaw 90.0 in the runtime census. |
| **F02_C_BATH-003** | P2 | Measured with **BW-005**. A galvanised run is correct for the retrofit. |
| **F03_B_ALCOVE-001** | P1 | The wardrobe at yaw 0 already faces the room (F03_B_ALCOVE_DT3.jpg). |
| **F03_D_BATH-003** | P1 | The magenta cistern is not reproduced at 49e5e3a1 (F03_D_BATH_OV.jpg). |
| **F04_A_BATH-003** | P1 | The cistern is present per **BW-018**. The curtain goes to **BW-008**. |
| **F05_A_BATH-003** | P1 | The cistern is present per **BW-018**. The pipe and register go to **BW-005** and heating. |
| **F05_B_BATH-003** | P2 | Misread: the "radiator" is the closed shower curtain, and heating places no radiator in 5B's bath. |
| **F05_C_VESTIBULE-003** | P1 | The duct runs on two hangers into the partition (F05_C_VESTIBULE_TH.jpg). |
| **F04_B_ALCOVE_APPROACH-002** | P3 | The V2 light switch is a toggle by design (light_switch.md). |
| **F05_SERVICE_CROSSING-002** | P3 | The peephole disc is brass specular. The wall joint goes with **BW-006**. |

## 8. Decisions for the owner

The merge target is settled: the owner asked to merge the branch, and its
tip 5467439f is the candidate (verifier MERGE-CANDIDATE, 0 regressions).
Merging only the pushed d416d4ee would merge a commit the verifier BLOCKS.

**Merge plan.** Commit this report and its sidecar directly on top of
5467439f (the sidecar's head is the report commit's parent); verify that
commit with `python tools/verify_candidate.py <sha> --base 2ea28ee056dba9a511b87086aa43ed29c3159d2a --report design/reports/V2-ENV-DOSSIER-2026-10-10.json`
in fresh mode; push the branch; fast-forward main to the report commit and
push main; take a clean gate board at the merged main as the next baseline.

1. **Prohibition.** Gates the speakeasy judas window and the teacups'
   speakeasy reading (**CITY_BAR_DESCENT-003**, **CITY_BAR_ROOM-004**).
2. **The election headline in the Bible.** Gates the headline board and the
   gutter's election ephemera (**CITY_SHOP_NEWS_CIGARS-002**,
   **F01_STREET_APRON-002**). Slice 65's broadsides are wordless.
3. **Commensals C2.** Gates the fly shimmer and the roof roost
   (**CITY_STREET-001**, **ROOF_DECK_NORTH-002**).
4. **The owner JSON's A06 item.** The roof ventilator housings that read as
   cream stone plinths (**ROOF_DECK_WEST-005**).
5. **K2, the interaction carrier.** Gates the drop-octagon clock's winding
   owner, given clock_prop's open "Hold E" violation (**F04_B_MAIN-002**).
6. **Restate the four monitor-top rows.** The title says monitor-top, but
   the construction is icebox evidence (**F01_A_KITCHEN-002**,
   **F03_A_KITCHEN-002**, **F05_B_KITCHEN-002**, **F06_C_KITCHEN-002**).
   Three verified drip-tray rows carry the same title.
7. **The light budget.** Allow cage bulbs and practicals beyond 16/16, or
   fund an emissive finish (**B1_BOILER_ROOM-003**,
   **CITY_SHOP_OTIS_SON-001**).
8. **Caskets.** Authorize casket source records in the protected
   `building_layout.json` (RUL-004), or name another source owner
   (**CITY_SHOP_FUNERAL_PARLOUR-001**). This decision is implied by the row
   note; the note does not ask for it outright.
9. **V1 coupling.** Accept, or ask to revert, the V1-visible changes in
   shared props (door_prop, mail_bank_prop, domestic_radio_prop,
   watch_register_prop, exterior passes), and the V1 watch tests now
   coupled to V2's 8-row STATIONS table.
10. **First shift.** Should marking V2's F02 core box satisfy the
    first-shift opening-station step?
11. **Surface stock headroom.** Where new small forms go, given
    surface_stock.glb's 1.72 MiB headroom under GitHub's limit.

## 9. Traps for the next developer

**Ids and startup.**
- Duplicate ids between anchors, surface stock and objects stop the V2 world
  from composing. Grep every new id across the blockout,
  `surface_stock.json` and `domestic_objects.json` (slices 44 and 58).
- Slice commits 58 to 66 carry such a duplicate (6A_light_box) and do not
  start the V2 world. Skip them when bisecting on main.
- Every new object material key needs finish parameters, or nothing composes
  (slice 47). Paper label bands must bind a registered catalogue key
  (slice 54).
- The positional-wear mount is non-fatal. Missing decals will not fail
  startup.

**Gates and the systemic audit.**
- Compare gate boards against the merge-base board, never against the
  previous slice's. Slice 32's "mopbucket" timer finding hid behind
  "matches slice 35".
- The systemic audit flags tests that call prop methods directly. Work props
  through the player's presses. Keep kind lists as file-level consts
  (5467439f).
- Once main has moved, pass `--base` with the old merge-base to
  `tools/verify_candidate.py`, and pass `--report` or the sidecar is never
  checked.

**Hashes and line endings.**
- Paths marked -text are stored byte-for-byte, so a Windows editor commits
  CRLF. Check `git show <c>:<path> | tr -cd '\r' | wc -c` before
  committing.
- Run receipts hash the raw checkout bytes. The patrol test_sha256 184eea57
  is the CRLF copy; the LF blob is dbb32da8.

**WIPs and receipts.**
- WIPs amended under the same subject (fed69144, 129e02d3, 1d65072d) are
  different trees. Check each receipt's repository_head and
  runtime_inputs_sha256 before calling one runtime-identical to another.
- Check the squash with `':(exclude)art/reviews'`; without it the packet
  always differs.
- Re-run OrisonV2BlockoutTest after moving any anchor.
- Copy the baseline runs a claim relies on into the packet. base80,
  base48_routes, bedding_base43 and f01base live only under
  `C:/ov/envimpl_out`.
- The lane checkout is dirty (about 414 entries) and the sweep scene runs
  from an untracked copy there; a fresh checkout has it only under the
  packet's `sources/`.

**Fabrication.**
- Godot renames duplicate sibling names, so census part names drift when a
  count changes (source_plan M05).
- Commit or cite the census scene and output for any refabrication.
- surface_stock.glb is 1.72 MiB under GitHub's limit. Put new small forms in
  another family.
- `orison_v2_surface_stock.gd` prepare() hard-codes the assembly count
  (247). Update it with every roster change.

**Routes and waypoints.**
- Routes written before the vestibule leaves must open both leaves
  (_leave_front_entrance and _enter_front_entrance).
- Never stand a waypoint inside a door leaf's quarter-turn sweep (slice 6).
- An unfiltered CompletionInteriors run stops at its first failure (1A),
  so set V2_TEST_UNIT to reach the other homes and the staff leg.

**Running suites.**
- Pointer and patrol suites need -Windowed. The apartment batch exceeds the
  180 s serial ceiling; use the long runner.
- A fresh checkout needs --import twice before suites.

**Manifests and inspectors.**
- Regenerate `tools/orison_spatial_dependency_manifest.json` with
  --update-manifest whenever ids change.
- Context inspectors accept only the supports they have been taught. A new
  support type needs an inspector change first (slices 7, 9, 27, 37, 47, 78).
- Keep 6C last in the bookshelf manifest (slice 26).

**Known suite behaviour.**
- The wake reconstruction suite trips its own 150 s watchdog after the same
  33 checks. This is shown only at 7478bd9c (slice 25's commit) and
  c9bc2317 (a slice-26 WIP), both branch trees. The suite never ran at
  16f1d353 or after slice 26, so whether it passes on main or on the final
  tree is unconfirmed.

**V1 and V2 sharing.**
- first_shift_director maps any central drop 2 to F02_STATION_2A_LANDING.
- STATIONS carries number 2 twice. Never mount both worlds' boxes on one
  network.
- Props in `game/scripts/props` are shared with V1. A dossier fix there
  changes V1 too.

## 10. Slice index

| Slice | Commit | Subject | Evidence tag |
|---|---|---|---|
| packet | e63ce4f6 | Add V2 environment design dossier and change register | none (INERT packet) |
| merge | 16f1d353 | Merge remote-tracking branch 'origin/main' into claude/orison-v2-environment-design-778e17 | baseline_*, bisect_16f1d353 |
| 1 | 8df6ee18 | Fridge count, living-room pendants, 4D closet lock | slice1, slice1b, baths |
| 2 | 45ef3257 | Second beds out, radios in six homes, moves and sign fixes | slice2, slice2b, slice2c |
| 3 | f99e4f2f | Public hall practicals, unit numerals, cue masses gated | slice3b, numerals, numerals2 |
| 4 | dae10668 | Period furniture forms replace the post-1950 variants | slice34 |
| 5 | 5bf9202c | Bath tile on one face only, room leaves a step lower | slice5, slice5b (skinbase, floorbase) |
| 6 | 4433a936 | Resident furniture for the six completion homes, signal outlets | slice6, slice6d, routes6b, ducts, bisect_* |
| 7 | e1bfe131 | Kitchen sets on the drainboards and prep cabinets | slice7 (slice7b also in the packet) |
| 8 | 66994c91 | Hall stands in the seventeen apartment vestibules | slice8, slice8b |
| 9 | 6d99760d | Paper, book and small stock on the residents' surfaces | slice9, slice9e, slice9f, slice9g (slice9h); status.py's slice9b is only in C:/ov/envimpl_out |
| 10 | a33a5edc | Chain guards on the entry leaves, the armchair form | slice10, slice10b (slice10c) |
| 11 | 7ded29fc | The reel-deck table, outgoing shelf, desk and plain box | slice11b (slice11) |
| 12 | 6bb07f16 | Case wall, plan wall and the wall-art form | slice12, slice12b |
| 13 | 78a9a903 | Garment rails and hung blankets | slice13 |
| 14 | 0fc99ff9 | One use object in each private hall | slice14b, slice14c (slice14base) |
| 15 | a906e43a | Wall art in the residents' rooms | slice15 |
| 16 | b9444e2e | Bedside and tabletop stock | slice16, slice16c |
| 17 | d1d199d2 | 2B's bedside and client chair, 3A's pail, 4D's luggage | slice17b (slice17) |
| 18 | 75e61eae | Sewing machine, radio teardown, easel and canvases | slice18 |
| 19 | 03bd45fc | Propagation shelves, covered objects, card cabinet | slice19 |
| 20 | 858fb707 | 2A's box files, 6A's backdrop and print line | slice20 |
| 21 | b96e3160 | Lobby noticeboard and photograph, common-room armchair | slice21, slice21b, slice21c (slice21base) |
| 22 | 09e583ee | Drip pans under the fourteen iceboxes | slice22, slice22b |
| 23 | 1b60a8ed | Storage bay contents and laundry baskets | slice23, slice23b, slice23c, slice23mina (bases) |
| 24 | ac6294fe | Out-tray, torch, battery case, cap, card index | slice24, slice24c |
| 25 | 7478bd9c | 2C's rig deck and cable hooks, 4D's print, 6A's archive crates | slice25 |
| 26 | 8c601251 | The 2C and 4C bookshelves and 4C's colour board | slice26 (the README's slice26b runs are slice26/receipts/rerun_b__*) |
| 27 | 355fb4ba | 3A's memorial pot, 6A's plates, 6C's ledger | slice27b (the commit message cites slice27/) |
| 28 | 6f938b86 | The ground-floor service rooms | slice28b |
| 29 | 37d70315 | The boiler room's tools and the signal frame | slice29 |
| 30 | 40110d19 | 5A's corrected plan and 2C's session archive | slice30b |
| 31 | c569c9b3 | Bedsides, garments on chairs, 1A's organizer | slice31b |
| 32 | 6c12f983 | Service evidence in the laundry and ground floor | slice32 |
| 33 | f59116ca | 6A's prints, the bulkhead's garden kit, cushions | slice33 |
| 34 | 0ef631a2 | 1A's trunk, the sweep's kit, and a keep audit | slice34 |
| 35 | 5031c0ba | Pigment and packing stores, 4C's garments, pinboard | slice35b |
| 36 | 964c0044 | Owner enamel finishes on six gas ranges | slice36 |
| 37 | ed898d17 | Bare closet shelf, cup rings, code books, boots | slice37 |
| 38 | 6b585295 | Dress form, recorder, taped form, light box | slice38 |
| 39 | 5f94847a | Bolts, cutting kit, fastener cabinet, closures | slice39 |
| 40 | 84d9e4e4 | Japanned lamp, model case, T-square, 4D's case | slice40 |
| 41 | 27124d28 | Hall file, toaster form, basement shop stock | slice41 |
| 42 | 56138373 | House bell, quiet sign, route map, cone speaker | slice42 |
| 43 | cc3f2ac3 | Oak desk wall, laid headsets, framed service leaf | slice43 |
| 44 | 7e31b188 | Pot, tape boxes, jacket, bedding states, sink tile (WIP slices 45, 46 squashed here) | slice44 |
| 47 | 6d62caab | Resident bath sets, the overflowed umbrella tray | slice47 |
| 48 | de5189d7 | The building's paper trail on every core level | slice48 |
| 49 | f7d118cf | Door thresholds, a household at every door | slice49 |
| 50 | 7c7245c5 | Stair wear and one piece per core landing | slice50 (rerun in slice52b) |
| 51 | 8146159d | The sealed 3C threshold, 5D's soot ghost, Cal's aerial wire | slice51 |
| 52 | 88e94de9 | Positional wear in every bath and the upper halls | slice52, slice52b |
| 53 | 44d8ae0a | The news booth's stock and the proprietor's worn mat | slice54b |
| 54 | 5b3f1bec | Paint tins in three sizes, one drawer open | slice54b |
| 55 | f57d44ee | Film stock, the counter case, one print a building | slice57b |
| 56 | 74ae8be6 | The key board varied, a lock case open, the register | slice57b |
| 57 | 3d21c4cb | Radio valves in racks, the 1610 set, test gear, the wire reel | slice57b |
| 58 | e145c48d | 1A's bath rail, 1D's window towel, 6A's light table, 4D's lost property | slice67 |
| 59 | 87db0900 | The laundry rota and painted-over outlet, cleated wiring, a coal shovel | slice67 |
| 60 | 3a97848b | Coal dust, the door sweep, the chute fan, the chalked log | slice67 |
| 61 | f8facac2 | A water line under every curtain, 5D's soot as a soft fan | slice67 |
| 62 | ea89c6c2 | The pawnbroker's ring in an envelope, the safe's blank name panel | slice67 |
| 63 | 659562ce | The reading room's bookcases in varied runs and bound magazines | slice67 |
| 64 | 5dfb45d9 | The funeral register open, chairs off their marks, the worn third stool | slice67 |
| 65 | 1242e55c | Feathered pavement marks, election broadsides on the hoardings | slice67 |
| 66 | 8f35dc22 | The last thresholds, 4B's worn runner, 5C's paint rag, 6D's padlock | slice67 |
| 67 | bbe0f527 | Hall wear strengthened, the news mat and drawer test fixed, the light table renamed | slice67 |
| 68 | 18faa509 | The house tank in staves, the mail bank overfull and ajar, 1A's corrected notice | slice68 |
| 69 | dd437ef8 | The hardware counter's bell and night card, the capsule box; shop labels | slice68 |
| 70 | fabde5eb | The luncheonette's menu board in push-in letters (statused with 71) | slice68 |
| 71 | 25bb0627 | The luncheonette's sugar shakers and a jar of pickled eggs | slice68 |
| 72 | 9ffcfbe0 | The basement toolboard a shadow board, one tool out | slice68 |
| 73 | a56872a9 | The basement nook's reader, a book tented on the cushion | slice68 |
| 74 | 55be67fc | The cobbler's floor in leather dust, the dark pairs brown leather | slice68 |
| 75 | d238fea9 | The laundry's ticket halves in four ages, the oldest parcel row | slice68 |
| 76 | 0d9a2b4c | The coal chute seated on a boarded bunker; the coal route through the vestibule | slice80 |
| 77 | 6c0f62b9 | The basement washers' hot and cold supply, hoses and floor gullies (statused with 78) | slice80 |
| 78 | 034aa54a | The rinse tubs' taps out of the wet stack, their waste back into it | slice80 |
| 79 | 027a22ca | The night watch's kettle on a gas ring and the tour card | slice80 |
| 80 | 287594f6 | A patrol station on every floor; the signal register with seven drops | slice80 |
| 81 | d416d4ee | Every remaining row statused, each with its reason | slice81 |
| 82 (tip, the candidate) | 5467439f | Patrol round worked by the player's presses; furniture kinds as a const | C:/ov/envimpl_out/slice82 (not in the packet) |

MERGE-CANDIDATE 5467439f2207efb943bbfd2f976f00077aae4c5c
