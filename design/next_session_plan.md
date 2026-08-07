# Priorities — after the street learned to end and the bar learned the time

## STATUS UPDATE 2026-08-07 (evening session): P0 and P1 SHIPPED

- **P0 done.** `game/data/resident_schedules.json` (382 blocks, 19
  date-keyed observances, outfit field reserved for #46; overlay schema
  doy > monthly+days > days > base) + `ScheduleDirector` driving
  resident_routines: home / place / exterior (lobby-door crossing, same
  abstraction as the lifts) / offsite despawn. Envs: SCHEDULE=1/0,
  SCHEDULE_DAY, SCHEDULE_DOY; inert under DAYNIGHT=0. Suites:
  ScheduleTest (headless) + ScheduleLiveProbe (manual; proved the
  Friday bar roster forms in engine). Doc wobble kept faithful: the
  Thursday bodega stagger runs 4 bodies 17:30-18:15, wider than SIII's
  quarter-hour claim.
- **P1 P5 done.** HarukiyaStateDirector: OPEN 19:00-02:00 /
  AFTER-HOURS -04:30 / CLOSED, same clock as the sky. Fixed en route:
  bar fixtures were storey-gated OFF for anyone standing in the room
  (F01_ names at B1 heights) — the venue is a vertical zone now.
- **P1 P6 done.** Inspectables (pictures/barrels/pool table) + four
  couch seat sockets; scheduled bar-goers claim couches and settle.
- **Signage redesign done (user directive).** Both shops dropped tube
  neon: bodega = HALF BAKED backlit yellow awning valance + projecting
  corner lightbox (24 h, one tired tube); Harukiya = painted 春木屋
  board under goosenecks + red chochin (lit when open, taken in when
  closed) + marquee bulb arrow. Doc shots b_44-b_47; all states
  verified by render + measured RGB.
- **P2 Songbook remains gated on explicit user direction.** The owner
  filed three more modes on 2026-08-07; they are ADDENDUM A of
  `docs/songbook_brief.md` (Blind Read · STRICT METER · Producer and
  Performer). Phase 1's scope is unchanged but for one thing: the lyric
  editor should draw the syllable map from `melodic_shape` /
  `suggested_syllables`, which the PhraseSlot spec already carries.

Written 2026-08-07, at the close of the exterior-makeover arc: the
elevator finished top to bottom (roof car included), the texture library
regenerated and folded into ai_materials with multi-gen synthesis
families (#51), the street rebuilt at a true 60 ft right-of-way with
diegetic route closures, the bodega (Half Baked) and Harukiya (Akira)
standing through Phase 3 hero geometry, and a real-local-time day/night
director with four measured states. WalkTest and LightingAudit green on
the committed tree. Governing design docs now include the Harukiya
Accords (ORISON_BIBLE laws 9–15), `docs/harukiya_reference_notes.md`,
and `docs/songbook_brief.md`.

## P0 — the residents get a clock (#50, second half)

Day/night is DONE (`day_night_director.gd`, DAYNIGHT_FORCE/DAYNIGHT=0
envs, tests pinned at 03:00). Remaining, in order:

1. **Transcribe the timetables** — `design/ORISON_ARCHETYPE_SCHEDULES.md`
   (18 schedules, lines 201–1236) → `game/data/resident_schedules.json`.
   Do it IN-LOOP: the agent route died twice on the monthly spend limit.
   Schema to design on the way in: per-resident array of
   {start_min, end_min, place, activity, days/holiday filters} honoring
   the cross-schedule interlocks (§III).
2. **Schedule runtime** — a director that reads the JSON + the day/night
   clock and drives resident_routines destinations: home rooms, hallway,
   roof, lobby, bodega aisles, Harukiya (stage/couches/bar), "work" =
   offsite despawn. Weekend/holiday branches per day-of-year.
3. **Wardrobe hooks later** — swaps wait on #46 model generation; leave a
   per-entry `outfit` field in the schema now so the data doesn't need a
   second pass.

## P1 — Harukiya phases that need no assets (#52)

P1–P3 verified (descent, red door, room, restroom, hero couches/cabs/
jukebox). P4 material language is BLOCKED on user gens
(`design/RETAIL_TEXTURE_PROMPTS.md`, 6 prompts, plus green wall / red
trim / couch vinyl). Self-serviceable meanwhile:

- **P5 lighting states** — bar OPEN/CLOSED/AFTER-HOURS looks; the
  day/night director is the natural driver (bar lights keyed to
  minute-of-day, exterior:True lights already unit SITE).
- **P6 components** — Inspectable on the pictures/barrels/pool table,
  Seat sockets on the couches (resident `settle` role + player sit,
  same pattern as the lobby bench).
- **P7 is superseded** by the Songbook (#53) — do not build the brief's
  timed-lyrics karaoke; it is Songbook Phase 1 now.

## P2 — THE SONGBOOK Phase 1 (#53, when directed)

LAST TRAIN HOME vertical slice per `docs/songbook_brief.md` MVP order:
SongResource + phrase slots + timed display + lyric editor + mic record
+ latency clap-check + playback through the bar-PA effect chain. The
stage, mic stand, and karaoke TV already exist in the bar. Ask before
starting — it is a large feature and the user said "when directed."

## Blocked on the user (offer prompts, don't wait)

- **#22** — `linen_aged` hi-res gen (last of batch B).
- **#36** — garbage cleanup pass; user F-keys floating placeholders
  first, then they move to the warehouse.
- **#46** — character models: Cal Dwyer FIRST, verify retarget on Mae's
  coat and Jonah's robe before batching the other 51 prompts
  (`design/ORISON_APOSE_PROMPTS.md`).
- **#52 P4** — the six retail texture gens + bar accent prompts.
- Day-state eyeball: bodega fluorescents under DAYNIGHT_FORCE=day are
  untested-by-eye; worth a look next time in engine.

## New invariants learned this arc (also in memory)

- TWO SILENT JAILERS: anything opening the earth registers in
  `GROUND_HOLES` (gen_layout site_pass) or gets an asphalt lid; any
  off-site floor registers an AABB in `safety_net.exempt_zones` or
  teleports silently snap back.
- `EXPLICIT_MATS` in build_orison.py: materials sampled by explicit UVs
  (stair_treads, art, sidewalk_haunted) — world-projection forbidden.
- Judge rooms with SHOT_LIGHTS=1 SHOT_TORCH=1, never SHOT_FILL (merged
  meshes drop lights past 16).
- Multi-gen synthesis: drop `stem_alt`/`stem_vN` files next to a source
  and ingest builds `_b/_c/_d` family variants automatically;
  `NO_VARIANTS`/`GRID_SLOTS`/`ROT_OK` sets in ingest control behavior.
- material_catalog.json is GENERATED — new materials go in gen_layout's
  MATERIAL_CATALOG dict; GDScript-only props also need GODOT_STAGE +
  MatLib.SETS.

## Standing state

- Building green B1–roof; elevator serves every stop including ROOF.
- Street: 3 legal routes (Orison circumference, bar, bodega); trenches,
  hoardings, alley fences close the rest; shop doors proven unlocked.
- Day/night: night/dawn/day/twilight measured distinct (36.8/22.7/
  10.3/6.4 frame means); WalkTest deterministic via DAYNIGHT=0.
- Warehouse teleport proven by headless probe (WarehouseTeleportTest).
- Cases, mail, nav, cast: unchanged from the 2026-08-02 brief below the
  line — Mina voiced and complete, Peter Wren the sanctioned second
  case, brass mailbank functional, collision-audited nav graph.

## Invariants (unchanged, sworn again)

gen_layout authors all coordinates; b2g() is the only conversion; never
hand-edit generated JSON/glTF; all suites green before every commit;
fetch before push; one Godot instance at a time against the .godot
cache; audio stays procedural except catalogued, attributed assets with
gitignored sources.
