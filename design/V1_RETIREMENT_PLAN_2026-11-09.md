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
| The waking organism: apartment encroachment, the waking ecology (moss, residue, tendrils, margin palps, cellular audio) | Ruling **v1r_waking_organism_20261109**. Organism incidents depend on it. |
| Story decals (98) and exterior ground decals (11) | Ruling **v1r_story_decals_20261109**. |

The census probe is scratch and is not committed; its outputs are
`C:/ov/reports/v1r_import/live_v1.json` and `live_v2.json` (unfiled).
