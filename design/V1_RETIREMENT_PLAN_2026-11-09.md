# V1 retirement plan: what V1 still owns, and how it reaches V2

Evidence class: **INERT** (plan). It promotes nothing; the completeness
ledger's **V1_RETIREMENT** scope remains the proof authority.

Date: 2026-11-09. Base: main at 8c9525df.
Asked by Lily: "create a plan to finish importing systems from v1 into v2 so
we can retire and remove v1, ask me about each system to import and defer to
v2 decisions."

## 1. How the inventory was taken

Reachability, not file names. Starting from each building root scene
(`orison_root.tscn` for V1, `orison_v2_runtime.tscn` for V2), the census
follows every `res://` path and every `class_name` use, with comments stripped,
through scripts, scenes, resources and data JSON. The title screen and the
nine autoloads count as shared. The script is at
`C:/ov/reports/startup_profile_20261109/reach.py` (unfiled scratch).

Result: 959 files reachable from V1, 2,606 from V2 (shared included).
**88 files are reachable from V1 and not from V2.** That set is the whole
of what V1 still owns; everything else V1 touches is already V2's or shared.

Static reachability misses paths built at run time from variables. V2's
dynamic loads read asset fields from JSON, which the census does
follow. Treat the list as complete for literal references and confirm each
removal with the gate board and a compile pass, as the test retirement did
(PR 192).

## 2. Deferring to V2

Where V2 already built its own version of a V1 system, V2's version stands
and V1's copy is removed without a question. Where a V2 document already
decided the matter, that decision is cited and not reopened. Lily is asked
only about systems V2 has no answer for.

### V2 has its own; V1's copy goes (no ruling)

| V1 file | V2 owner that replaced it |
|---|---|
| `props/kettle_prop.gd` | `orison_v2_surface_props.gd` |
| `props/elevator_interlock_prop.gd` | `orison_v2_elevator.gd`, `orison_v2_lift_drive.gd` |
| `props/monitor_prop.gd` | `orison_v2_native_signal_terminal.gd` and region programmes |
| `building/domestic_radio_pass.gd` | `orison_v2_radios.gd`, radio receiving/stock |
| `building/atmospheric_decal_pass.gd` (ordinary wear) | `orison_v2_positional_wear.gd`, `orison_v2_service_wear.gd` |
| `building/wayfinding_signage_pass.gd` | V2 region and exterior signage (48 V2 scripts) |
| `building/railing_polish.gd` | V2 native stair geometry |
| `building/floor_coverage_pass.gd`, `heightmap_pass.gd` | already superseded by SurfacePass (its own header says so) |

### A V2 document already decided

| System | Decision | Source |
|---|---|---|
| Room 0 (`building/room0.gd`) | "Defer fiction choice; preserve current geometry and explicit unresolved task" | **Q17**, `design/V2_TASK_RELEVANCE_REVIEW_2026-10-27.md` |

Room 0 is still asked about (ruling **v1r_room0_20261109**), only for what
happens to V1's code under that deferral, never to reopen the fiction.

## 3. Systems V2 has no answer for: one ruling each

Each is filed to Lily's rulings widget, recommended option first. Status of
every item: **ruled 2026-11-09**; Lily's answers are in section 6.

| Ruling id | System (V1 files) | Recommended |
|---|---|---|
| **v1r_sanity_layer_20261109** | The invisible director: `reality/sanity_director.gd`, `building_personality_director.gd`, `intrusions.gd`, plus `audio/ambient_soundscape.gd`'s object-that-speaks hook | Import, rebuilt on V2 anchors |
| **v1r_witness_tells_20261109** | `reality/domestic_witness_system.gd`, `props/domestic_witness_clock.gd`, `props/possessed_domestic_prop.gd` | Import with the sanity layer |
| **v1r_organism_incidents_20261109** | `reality/organism_incidents.gd` (LF-3, owner ruling 2026-08-22) | Import |
| **v1r_room0_20261109** | `building/room0.gd`, `props/door_anomaly_prop.gd`, `props/case_door_prop.gd` | Keep deferred per Q17; remove V1 code, tag keeps it |
| **v1r_case_presentation_20261109** | `cases/apartment_reality_controller.gd`, `reality_threshold.gd`, `portal_rule_display.gd`, `reality_affected_prop.gd` | Import into V2 case placement |
| **v1r_geomagnetic_static_20261109** | `audio/geomagnetic_static.gd` (Lily's sun_storms ruling 2026-11-04) | Import onto V2 radios now: it never plays in V2 today |
| **v1r_music_director_20261109** | `audio/music_director.gd`: the carrier-current station and the earned music library | Import the earned library; V2 radios keep the station |
| **v1r_broadcast_director_20261109** | `building/broadcast_director.gd` (37 clips, card breaks) | Import as the programme behind V2 radios |
| **v1r_historical_radio_20261109** | `game/historical_radio_notice.gd`, `data/historical_radio_reallocation.json` | Import |
| **v1r_night_glows_20261109** | `building/door_glow.gd`, `window_glow.gd`, `moon_fill.gd`, `props/vault_light_glow.gd` | Import |
| **v1r_commensals_20261109** | `building/commensal_director.gd` (moths, flies, roost) | Import |
| **v1r_period_layer_20261109** | `building/period_reality_layer.gd` (aircraft, distant period sound) | Import the aircraft only; V2 city, trams and el cover the rest |
| **v1r_uncanny_marks_20261109** | the rare uncanny marks in `atmospheric_decal_pass.gd` | Import onto V2 wear |
| **v1r_found_art_20261109** | `building/found_art_pass.gd`, `props/character_memory_art.gd` and the five art/story JSON tables | Import |
| **v1r_detail_pass_20261109** | `building/orison_detail_pass.gd` (clutter and narrative paper) | Drop; V2 dresses rooms natively |
| **v1r_lobby_boards_20261109** | `props/lobby_bulletin_board.gd`, `lobby_orison_ad_board.gd` | Import |
| **v1r_dead_letters_20261109** | `minigames/dead_letters.gd`, `ui/dead_letters_panel.gd`, `props/dead_letters_prop.gd` | Import as direct manipulation (RUL-013) |
| **v1r_maintenance_hq_20261109** | `building/maintenance_headquarters.gd` | Import |
| **v1r_mail_chute_20261109** | `props/mail_chute_prop.gd` | Import beside the V2 mail bank |
| **v1r_extinguisher_20261109** | `props/soda_acid_extinguisher_prop.gd` | Import beside V2 fire cabinets |
| **v1r_door_closer_20261109** | `props/door_check_closer_prop.gd` | Import on the V2 stair door |
| **v1r_small_props_20261109** | `ceiling_light_prop.gd`, `clock_prop.gd`, `porch_deck_prop.gd`, `boxfan_prop.gd`, `bench_zone.gd` | Import the honest clocks; drop the rest |
| **v1r_rollback_20261109** | Removing V1 removes the `ORISON_BUILDING_ROOT=v1` rollback that AGENTS.md and **RUL-004** keep | Remove rollback once every import above is merged |

## 4. Plumbing (no ruling; done during removal)

- V2's debug prop warehouse reads `building_root.gd`'s `PROP_SCRIPTS`
  (`orison_v2_runtime_root.gd`, the warehouse build call). Move the table to its own file first.
- V1 geometry: `assets/building/floor_02` to `floor_06`, `floor_b1`, `roof`
  glTF and their buffers. V2 rebuilt the building; nothing imports.
- V1 F01 composition: `floor01_cell_registry.gd`,
  `floor01_geometry_configuration.gd`, `furniture_interaction_pass.gd`.
- `characters/npc_placeholder.gd`, `ui/building_debug.gd`'s V1 half,
  `shaders/floor_coverage.gd`, `shaders/tv_screen.gd`.
- 29 test scripts and 8 tools name the V1 root. Each either moves to V2 or
  retires with it.
- The completeness ledger's acoustic fallback: `acoustic_graph.json` is still
  authored against V1 geometry (**acoustic.v2_rederivation**). It must be
  re-derived on V2 before V1 geometry goes.

## 5. Order of work

1. Collect the rulings. Nothing is imported or removed before them.
2. Imports, one PR each, in dependency order: sanity layer, then witness
   tells, organism incidents and case presentation (they bind to it); the
   audio group; the rest in any order.
3. Plumbing: move `PROP_SCRIPTS`, re-derive the acoustic graph.
4. Retire V1: tag main, remove the 88 files and V1 tests, change the
   selector, update AGENTS.md and RULINGS.json for the rollback ruling.
   Gate board against main, compile pass, world startup.

## 6. Lily's answers (2026-11-09, 17:40 to 18:00)

Recorded from her rulings widget (`toolbox.py decisions`). Each import below
is its own PR; nothing in V1 is removed until all of them are merged
(**v1r_rollback_20261109**).

**Import**

| System | As ruled |
|---|---|
| Invisible director (sanity, personality, intrusions) | Import, rebuilt on V2 anchors |
| Witness clocks and possessed household objects | Import together with the director |
| Organism incidents | Import |
| Case presentation (reality controller, thresholds, portal display, affected props) | Import into V2 case placement |
| Geomagnetic static | Onto the V2 radios now |
| Music director | Import the earned library; V2's station stands |
| Broadcast director | Import as the programme behind the V2 radios |
| Historical radio notice | Import onto the lobby boards (**v1r_historical_radio_b_20261109**) |
| Night glows (door, window, moon fill, vault lights) | Import all four |
| Commensals | Import |
| Period layer | The aircraft only |
| Uncanny marks | Import onto V2 wear |
| Found art | The residents' memory art only |
| Lobby boards (bulletin and Orison advert) | Import both |
| Mail chute | Beside the V2 mail bank |
| Soda-acid extinguisher | Beside the V2 fire cabinets |
| Door closer | On the V2 roof stair door, by direct manipulation (**v1r_door_closer_b_20261109**) |
| Small props | The honest clocks only |

**Into the first-floor reorganization** (new work order): dead letters and
the maintenance headquarters. Lily: reorganize the lobby and first-floor
common area so the maintenance interactive objects, the switchboard and the
like, are better distributed and easy for every resident to reach.

**Drop** (the tag keeps them): Room 0, the 4B seam and case doors; the
detail pass; found-art pieces other than memory art; the period layer
other than the aircraft; the ceiling bowl, porch deck, box fan and bench
zone.

**Order**: the director first (witness tells, organism incidents and case
presentation bind to it); the radio group (static, library, broadcast);
then the rest; the first-floor reorganization; then plumbing and removal.

## 7. What RUL-012 means for the imports (found 2026-11-09)

Every V2 physical surface needs authored UVs, a registered custom PBR recipe
and full mip chains, with no legacy exemption (**RUL-012**,
`design/V2_SURFACE_REQUIREMENTS_2026-10-11.md`). V1's props build their own
procedural geometry with V1 materials, so none of that geometry can be
carried into V2 as it is. The imports therefore split in two.

**Behaviour, sound and text: import directly, in this order**

1. The director (done: PR 199).
2. Organism incidents: no geometry of their own.
3. Case presentation: the controllers and thresholds, onto V2 rooms.
4. Possessed-object tells: the behaviour, attached to V2's own household
   props where a matching V2 object exists.
5. The radio group: geomagnetic static, the earned music library, the
   broadcast programme.
6. Night glows and uncanny marks: optical effects and decals, reviewed under
   the optical and decal clauses of the surface rule.

**Visible objects: new Blender assets first** (art/blender/v2_batch_workflow.md,
one batch per related set, rendered before a combined Godot capture)

- The eighteen witness clocks (one batch of dial styles) and any possessed
  object with no V2 counterpart.
- Lobby group: bulletin board, Orison advert board (carrying the historical
  radio notice), mail chute.
- Apparatus group: soda-acid extinguisher, roof-stair door closer.
- The honest clocks, the residents' memory art, the aircraft, the commensals'
  bodies.

V2 precedent for where the clocks go: V2 already keeps apartment clocks as
surface props on furniture (1D's alarm clock on the fridge, 3B's on the bed)
and hangs frames and pinboards as wall furniture. Witness clocks follow
those: mantel and travelling-alarm styles on furniture, the rest hung beside
the resident's existing frames.

## 8. Runtime census (2026-11-09)

The reference census in section 1 counts a file as V2's when V2 code names
it, even when V2 never builds it. A second census booted each root and
listed the scripts live on nodes: 180 in V1, 257 in V2. Of V1's, 24 run in
V2 as a V2 subclass. 64 do not run in V2 at all.

Beyond the systems already ruled, that adds:

| System | Disposition |
|---|---|
| Arcade cabinets (`arcade_machine.gd`, ten cabinets) | Dropped: Lily asked for their complete removal pending a later redesign (`design/V2_SHARED_FINISH_OWNERSHIP_AND_ARCADE_RETIREMENT_2026-10-24.md`). |
| V1 street traffic | V2's own traffic and trams stand. |
| V1 resident navigation and routines | V2's resident routes, agendas and presentation stand. |
| Radiator hand surfaces (161) | V2's radiator assemblies stand. |
| Exterior detail pass | V2's city stands. |
| The waking organism: apartment encroachment, the waking ecology (moss, residue, tendrils, margin palps, cellular audio) | Ruled: import it onto V2 apartment walls and props (**v1r_waking_organism_20261109**). Organism incidents follow it. |
| Story decals (98) and exterior ground decals (11) | Ruled: import the story decals onto V2 surfaces; V2's exterior ground stands (**v1r_story_decals_20261109**). |

The census probe is scratch and is not committed; its outputs are
`C:/ov/reports/v1r_import/live_v1.json` and `live_v2.json` (unfiled).

## 9. Removal (2026-11-11)

Done on branch `claude/v1-removal` under **v1r_rollback_20261109**, after the
last import (the house office, PR 227) merged. The tag
`before-v1-removal-20261111` is main at 54652e463, the last tree that holds V1.

### Removed

213 files, 79.1 MB, counted against the tag.

| What | Files | Size |
|---|---|---|
| The V1 scene `orison_root.tscn` | 1 | 0.2 KB |
| Scripts and one shader: `building_root.gd`, `music_director.gd`, the atmospheric decal, domestic radio, found art, furniture interaction, floor coverage, heightmap, detail, wayfinding signage and railing passes, door, window and vault-light glows, the floor-01 cell registry and geometry configuration, `npc_placeholder.gd`, `bench_zone.gd`, `elevator_interlock_prop.gd`, `domestic_witness_system.gd`, the floor coverage shader | 21 | 369 KB |
| Data tables: wall art, hallway art, stair-landing art, found-art catalogue, house telephones, resident story details, V1's anomaly prop catalogue | 7 | 17 KB |
| Geometry: `floor_02` to `floor_06` and `roof`, glTF and buffers | 12 | 34.5 MB |
| Textures, moved to `C:/ov/holding/retired_textures/v1_removal_20261111/` with `manifest.json` (path, bytes, sha256) before leaving the repository | 24 | 43.2 MB |
| Tests that boot the V1 root, and their scenes | 49 | 866 KB |
| Tools and tools tests that served only those harnesses | 8 | 199 KB |
| Notes in `game/docs` for the removed tables and the detail pass | 3 | 5 KB |
| `.uid` and `.import` sidecars of the above | 88 | 38 KB |

The selector keeps its file, class, `scene_path()`, `path_for()` and
`reset_for_tests()`. `PATHS` holds only V2; an unknown or `v1` value warns and
runs V2. `tools/verify_candidate.py` accepts that exact edit and the absence
of the ten protected paths that were V1's upper-floor geometry, and nothing
else (**RUL-004**).

### Kept, though the census called it V1-only

| File | Why |
|---|---|
| `data/character_memory_art.json`, `scripts/props/character_memory_art.gd` | Memory art is V2 work, held unmounted until the pictures are redrawn. |
| `assets/building/floor_b1.gltf` and its buffer | Seventeen V2 Blender builders read its material table and bind its hash in their construction records and test fixtures. Nothing loads it at run time. |
| `assets/building/textures/atmospheric_decals/institutional_wear_atlas.png`, `uncanny_trace_atlas.png` and their chroma sources | `art/tools/build_wear_decals.py` reads the first; V2's four uncanny wear decals were cut from the second. Authoring sources, not loaded at run time. |
| `shaders/floor_coverage.gd` | Never existed: the census cut the floor coverage shader's name short. The shader itself was V1-only and is removed. |

Also left in place: `floor_01.gltf` and `floor_01_cells` (V2's front facade,
bar and passage read them); both copies of `building_layout.json` (protected,
and the source of the acoustic graph); `acoustic_graph.json`, still authored
against V1 geometry (**acoustic.v2_rederivation** stays open).

### What V1's removal leaves behind

- 89 data fields lost their only reader. They sit in files this removal may
  not edit or should not: `building_layout.json` (32, protected),
  `floor_01_cell_registry.json` (42, hash-bound), `character_memory_art.json`
  (7, held), `reality_affected_props.json` (5), `domestic_witness_clocks.json`
  (2), `signage_plates.json` (1). The reader baseline records them as debt.
  They are not excepted.
- `tools/m11c2_floor01_production/export_floor01_cells.py` is bound by hash
  into the floor-01 manifest and so is unchanged; it refuses to run without
  the retired floors. Re-exporting the floor-01 cells needs an owner decision.
- About 354 building textures are now named only by their folder, because the
  removed glTF files were the last to name them by stem. Whether V2 loads them
  through the material catalogue needs a load trace
  (`tools/audit_textures.py --trace`); none was removed.
- Comments in V2 scripts still describe V1 passes by name. `HANDOFF.md`,
  `TASKS.md` and older notes in `game/docs` are history and were not rewritten.
- The completeness ledger still describes a V1 fallback in its
  **selector.reversible_two_root** row. Its counts did not change.

### Coverage lost

None of these could be pointed at V2 by a small honest change: each drives V1
node names, V1 root fields or V1 coordinates.

| Removed | What it proved, on V1 | V2 has |
|---|---|---|
| `walk_test.gd` | The headless whole-building walk (floors, stairs, lift, art sweep) | Its own route and access suites; no single equivalent |
| `perf_probe.gd`, `Perf.tscn`, `shadow_policy_shot.gd`, `run_release_performance_matrix.ps1` | Station frame times, the dream benchmark mode, and the second-machine release performance receipt | Per-feature V2 profiles; **no release performance matrix** |
| `first_shift_opening_live_test.gd` | The opening ritual in the production world | `first_shift_ritual_test`, `first_shift_custody_test` (no world) |
| `night_register_live_test.gd`, `watch_register_live_test.gd`, `watch_station_live_test.gd` and their shot scripts | Register, watch line and station in place in the building | The hand tests and `v2_watch_stations_review` |
| `maintenance_fuse_shot.gd`, `maintenance_watchman_shot.gd` | Proof sheets of the panelboard and the detector | `fuse_panel_hand_test`; V2 first-floor suites |
| `service_set_test.gd` | The service set and E prompt in the production scene | `v2_service_set_hand_world_test` |
| `weather_sky_test.gd` | One weather clock, four skies, fog, rain and exposure on the V1 root | `campaign_weather_test`, `live_weather_service_test`, V2 weather profiles |
| `street_shot.gd`, `street_id_shot.gd`, `route_probe.gd` | V1 street stream, buffer ownership and shop routes | V2 street, tram and route tests |
| `dream_hero_lifecycle_live_test.gd`, `dream_hero_lifecycle_shot.gd`, `dream_voxel_v1_runtime_shot.gd`, `dream_voxel_v1a_runtime_shot.gd` | The modelled hero's lifecycle and voxel light inside V1's apartment encroachment | The waking organism's V2 suites; not these stop gates |
| `interaction_inventory.gd` | A census of every interactable in the V1 world | The source-only implementor and carrier audits |
| `orison_v2_two_root_matrix_test.gd` | Selecting either root and switching between them | Nothing: there is one root |
| `orison_v2_m11c2_production_matrix.gd`, `..._capture.gd`, the teardown fixture, the door-crossing support, the `orison_v2_m11c1_owner_first` harness | The floor-01 cell cut rehearsed and proven against the V1 monolith | Nothing: history |
| `free_cam.gd`, `screenshot_run.gd` | Developer camera and screenshot driver for V1 | V2 review scenes |
| Tools tests `test_m11c1_scanner_consumer_adapter`, `test_m11c1_runtime_rehearsal`, `test_m11c2_production_harness_contract`; tools `m11c1_floor01_rehearsal/`, `merge_m11c2_capture_receipts.py` | Source contracts of those harnesses | Nothing: history |

Two source tests lost one case each with the file it pinned:
`test_interaction_implementors` (the wayfinding buzzer) and
`test_orison_spatial_dependencies` (the cell registry's floor asset path).
