# Handoff — Orison Apartments build (local continuation)

This document briefs a fresh Claude (or human) instance picking up the
Orison Apartments set build on a local machine. It covers the pipeline,
how to verify the build, exactly where work stopped, and the one open
defect with its full diagnosis so far.

## What this project is

*Please Remain On The Line* — a first-person Godot game set in the Orison,
a prewar brick apartment block in **Queens, New York**. Vantry & Co. built
it in 1912 as a showcase; it was partially demolished in 1927 and reopened
in 1928 as flats, and **it is 1928 when the game starts** (`ORISON_BIBLE.md`
VIII.5.h). What the building was before 1927 is shrouded in darkness.

The player is a night-shift maintenance tenant in 4B who also answers the
support line at the desk — both halves are the job. Sound propagates
through the building's physical infrastructure (heating risers,
electrical, water, structural, chimney flue) as an "audio virus"; *The
Audio Virus* was this project's prototype name and survives as the case
layer's fiction, not as the title. Design docs live in
`design/` and `art/docs/`; per-case content in the Case Network docs.

**Current title theme (owner ruling 2026-08-15):** Clockwork Waltz, provisionally.
The untouched 2:38.7 original opens; `ESCAPEMENT FAILURE ×1.414` is its optional
second record, and completed streams alternate automatically. Both play over
one rain-soaked waking-world hero joining ORISON, STREET and the Vantry Arcade
through mundane infrastructure and maintenance work. Owner spoiler ruling:
**the dream world is the reveal**, so the title contains no dream geography,
entity or impossible architecture. No title import loops. Exact masters,
hashes, trims and tests are recorded in `game/docs/title_screen.md`.

Three top-level projects:

| Path | What |
|---|---|
| `game/` | Godot 4.7.1 project (originally authored against 4.5) |
| `art/` | Procedural pipeline: layout generator + Blender build scripts |
| `legacy_mobile_mvp/` | The old mobile MVP, kept for reference only |

## The pipeline (single source of truth)

Everything is coordinate-driven from **one** generator. Never hand-edit
geometry or the JSONs — change `gen_layout.py` and re-run the chain.

```
art/data/gen_layout.py
  └─> building_layout.json   (walls, rooms, furniture, markers)
      acoustic_graph.json    (heating/electrical/water/structural/flue)
      prop_catalog.json      (functional prop behavior profiles)
      material_catalog.json
        └─> art/blender/scripts/build_orison.py  (bpy → per-floor GLBs)
              └─> game/assets/building/*.glb
        └─> game/data/*.json  (same files, copied verbatim — Godot reads
                               them directly to spawn props/doors/player)
```

Rebuild steps:

```sh
# 1. regenerate layout (validates itself: overlap, footprint, door-width,
#    height-aware door-swing audit — a nonzero exit means a real defect)
cd art/data && python gen_layout.py

# 2. copy the five generated JSONs into the game. fixture_light_map is
#    the one everybody forgets — gen_layout writes it (see the tail of
#    main()), and a stale copy fails LightingAudit's coverage assertion
#    with a fixture count that looks like a build defect and is not.
cp building_layout.json acoustic_graph.json prop_catalog.json \
   material_catalog.json fixture_light_map.json ../../game/data/

# 3. rebuild GLBs — only needed if walls/furniture/openings changed
#    (marker-only changes skip this). Uses the `bpy` pip wheel (4.5),
#    or real Blender: blender --background --python art/blender/scripts/build_orison.py
python art/blender/scripts/build_orison.py

# 4. re-import + run the walk test. BARE `godot` FAILS — the user PATH
#    still points at D:\Python projects\devkit\bin, which no longer
#    exists. Two working addresses, verified 2026-08-13:
#      C:\devkit\bin\godot.cmd                     <- prefer this
#      ./Godot_v4.7.1-stable_win64_console.exe     <- repo root, gitignored
C:/devkit/bin/godot.cmd --headless --path game --import
C:/devkit/bin/godot.cmd --headless --path game res://tests/WalkTest.tscn
```

Three failure modes that waste an hour because they do not look like
errors:
- **The build silently lags the data.** Step 3 is marked "only needed if
  walls/furniture/openings changed", so it gets skipped — and nothing ever
  says the glTFs no longer match the JSONs. On 2026-08-13 the build was
  eight commits stale: `888b1dc` had deleted sixteen parked cars, the bus
  shelter and the arrival rideshare from `building_layout.json` on
  2026-08-11, and every render since had still been drawing them. They
  read as anonymous black masses and cost most of a check to identify.
  Before trusting any render or perf number, confirm the build is current:
  ```sh
  git log --oneline $(git log -1 --format=%H -- game/assets/building/)..HEAD \
      -- art/data/building_layout.json
  ```
  Empty means current. Any output means re-run step 3 first. A stale build
  is invisible in-engine — it loads, walks and tests green, because it is a
  perfectly valid build of the wrong data.
- **A changed external `.bin` used to leave Godot's imported scene stale.**
  Position-only geometry edits can leave the `.gltf` descriptor byte-identical;
  Godot then reused its cached scene even though the sibling buffer changed.
  The canonical builder now writes each buffer's SHA-256 into
  `asset.extras.orison_bin_sha256`, making the descriptor and buffer an atomic
  import unit. Do not strip that generated metadata.
- **A test whose script will not parse HANGS rather than failing** — no
  output, no exit, until the timeout kills it. A new `class_name` also
  does not exist until Godot rescans. After adding or editing any script
  a test loads, run `C:/devkit/bin/godot.cmd --headless --path game
  --editor --quit` once before the test that references it.
- **Only one Godot may touch the `.godot` cache at a time.** The user's
  editor often sits open for days (PID from the project root, no args) —
  do not kill it, but expect a concurrent headless run to behave
  strangely rather than to say so. The `_console` build is the one that
  prints to stdout; the plain exe silently writes nothing.

Conventions that bite if forgotten:
- Meters, Blender axes (X east, Y north, Z up, street = −Y).
  Godot mapping: `GameBoot.b2g(p) = Vector3(p[0], p[2], -p[1])`.
- Mesh names ending `-col` import as visual+trimesh collision,
  `-colonly` as invisible collision.
- Aging/weathering is seeded (`random.Random(1927)` in `aging_pass`) —
  deterministic across rebuilds by design.
- Door markers carry `leaf` ("closed"/"open"/"locked"/"none"),
  optional `cabinet: true` (exempt from the swing audit), and optional
  `swing: "out"` (reversed hinge — currently only the street door).

## Verification

- `game/tests/WalkTest.tscn` — 157-check suite: physics-verified walks
  (stairs, apartment 4B entry, street exit, roof egress, the reading nook
  at the light tree's base), elevator doors and per-floor cab buttons,
  acoustic propagation timing (riser sweep, flue-vs-riser race), prop
  behavior, touch controls, occluders, and all three Case Network cases
  driven end to end including their consequences. Exit code 0 = all pass.
  **Run this before every commit.**
- `game/tests/ServiceWireResponseTest.tscn` — focused I4 guard for the
  researched copy loader and the first four formerly silent targets: utility
  case latch, chained Passage carts, busy toaster and contextual hardware
  counter. It also proves unresolved state tokens and the case-owner template
  cannot leak generic copy. Exit code 0 = pass.
- `game/tests/LightingAudit.tscn` — every space is reachable by light:
  127 spaces, 11 intentionally ambient/dark. Exit code 0 = pass.
- `game/tests/Perf.tscn` — six worst-case camera stations, reporting
  objects/draw calls/primitives and frame time. Must run **windowed**;
  headless reports zeroes, which the probe fails on rather than passing.
- `game/tests/WeatherPerf.tscn` — the production-player north-pavement gate at
  2560x1440, canonical night and 16/16 lighting. Since 2026-08-15 it warms 120
  frames and reports both direct wall-clock and Godot's rolling FPS monitor;
  do not compare its settled values to older 30-frame rolling-only logs. T7
  closes at 15.718 ms direct / 15.993 ms monitor means on the RTX 4080.
- `game/tests/Screenshot.tscn` — renders documentation stills into
  `SHOT_DIR`; needs a real window, so run it **without** `--headless`.
  `SCREENSHOT_ONLY` takes a comma-separated list of shot names to
  re-shoot a sequence in one scene load. Copies in
  `game/docs/screenshots/` are current as of the ground-plane fix.

Throwaway probes are a normal tool here: write one, get the number, then
delete it in the same pass rather than letting it rot in `tests/`. Two
have already paid for themselves — the street probe that found the B1
bearing wall, and a raycast fan that found the road slab over the well.

## State

**Three documents, three jobs — do not duplicate between them.**

| | |
|---|---|
| `art/docs/photoreal_target.md` | the eight-phase art roadmap and its per-phase assessment |
| `TASKS.md` | the live queue: one line per open task, anyone may add |
| this file | how to build and verify, and nothing else |

*ORISON_BIBLE §VI.7 records a dispute about this file's standing: HANDOFF
used to call `photoreal_target.md` "the live status document" and framed
the whole game as the desk prototype. The interim ruling is that the
execution plan governs and HANDOFF is pipeline mechanics only. That ruling
is now reflected above; the dispute stays open until the owner blesses or
amends it.*

Broadly: phases 1, 2 and 6 (dressing) are done; 3, 4, 5, 7 and 8 are
partly done with named remainders. The building is fully walkable end to
end — street, all seven storeys, basement, roof.

**Phase 7 (performance) is NOT done, and the old "112-161 fps at 1440p"
claim here was badly stale.** `Perf.tscn` currently fails six or seven of
its seven stations against the 16.6 ms budget. Two floor-streaming passes
took the F04 corridor from 65.54 ms to ~29 and the street from 52.25 to
~33 — real gains — but the atrium eye sits near 40 ms and is the wall,
because it is the one view that legitimately sees seven storeys and so
defeats floor streaming by design. Task #28 carries the measurements and
the remaining levers.

**Benchmark contract since `ab120dc` (2026-08-14): canonical pinned night
is the authoritative state.** `Perf.tscn` pins `DAYNIGHT=0` like every
other harness; before that it measured the wall clock, and interior
stations swing 2–3.5k objects between day and evening on one build. Every
perf number recorded above and in older logs is a DAYTIME number — label
it as such and never compare it directly with canonical-night results.
M0.5 closed accepted-with-measured-blocker at `ab120dc`: northbound
≈17.8 ms against the unchanged 16.6 target after three ownership leaks
were fixed (−3.1 ms) and the remaining ceiling was measured
(`FINAL_MAP_REDESIGN_BRIEF.md` §10an–§10ao). The 9 m shop-batch contract
stands; cross-shop batching is deferred to project-wide P1 with its own
proof burden.

**Passage hours contract since PS6 (2026-08-15).** Canonical 03:00 means ten
closed Vantry units, ten dark shop circuits and three chained/frozen carts.
HARDWARE PAINT alone remains lit, open and collidable because K3/K5's shipped
night maintenance loop physically buys its required part there. At 06:30 the
ten internal scissor grilles fold back, every shop circuit returns and carts
are released; ordinary closing begins at 02:00. Coordinates are generated
`passage_shop_hours` markers, not duplicated runtime literals. The retained
same-build diagnostic is `PASSAGE_HOURS_OFF=1`; it forces the open/day shop
state only and must never ship as gameplay configuration. Evidence and its
measurement caveat live in `art/renders/passage_hours_ps6/README.md`.

**Core-loop verification since K6 (2026-08-15).**
`game/docs/core_loop.md` is the authoritative K2–K6 subsystem reference: exact
owners, maintenance and coordinator state machines, signal contract, save
fields, complete Mina trace and the safe extension recipe. It is written from
the landed source, including the current single-job coordinator limit. Keep
build commands here and behavior there.

`GoldenLoopTest.tscn` is the authoritative continuous Mina-shift harness. It
drives 87 checks in one production scene: report/discovery convergence,
inspection, the walked HARDWARE PAINT errand and return, repair, Mina's first
conversation, recurrence, second factual calibration, complete-rule
conversation, integration, dream request, stubbed wake, and real-file
save/load at every boundary. That direct-building harness still consumes the
dream request with a test stub; production now owns the N4 scene transaction
and N5 onset, but no playable maze/pursuit exists yet. Owner correction 2026-08-15:
the reveal restriction applies to the **title screen only**; it does not block
dream design or production. The complete `design/ORISON_MAZE_BRIEF.md` is now
ruled canon. N2's source catalog, canonical seed-0 assembly, dimensioned drawing
and 100-seed audit are closed at `art/renders/dream_maze_n2/README.md`; the
current Godot DreamMazeRoot is a D00-only reconstruction payload. Owner ruling
2026-08-15 replaced the carried phone with
a no-screen Vantry service radiophone, attached warm work lamp, one amber ORDER
jewel and the later-added rear NET/LAMP indicators. Q2-Q6 are landed: production
instantiates `ServiceSetCarrier`, the lamp crosses a device-neutral player seam,
L toggles the lamp, R toggles the radio/aerial, and no phone screen or viewport
is instantiated. The dependency census, interaction contract and proof frames
are in `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md`, `game/docs/service_set.md`
and `art/renders/service_set_q4/README.md`. N3 may consume the neutral light
seam without entrenching the archived phone classes. **N3 is now closed:** its
disposable 42 × 3.2 × 3 m corridor measured 3.425 s lamp-on, 11.358 s lamp-off
and 11.225 s extinguished capture medians across eleven paired seeds (69.8%
shorter on; 7.800 s bought off); real collision blocks acquisition, and L / left
shoulder / touch LAMP converge on the public owner. The control pack, raw data,
dimensioned drawing and beauty proof are in
`art/renders/dream_light_n3/README.md`. K7 records the landed loop in
`game/docs/core_loop.md`. N4 now boots production through CampaignShell and
proves its five forward-only real-file phases in `DreamBoundaryTest.tscn`; the
exact scene/save contract is `game/docs/dream_boundary.md`. The current
DreamMazeRoot is a D00 marker payload, not playable maze art. N5 now gives
CampaignShell one persistent SleepPressureDirector: Mina's authored 2.60-second
gradual warning, exact mid-onset real-file restore, the shipped Always-warn
option, and pause-without-cancel gates for `call_locked`, unstable floor, the
real lift seam and the permanent carriageway. It is the sole production caller
of dream entry. The 20/20 contract and A/A/B/C visual proof are in
`game/docs/dream_onset.md` and `art/renders/dream_onset_n5/README.md`; N6 is the
next dream item. Wake persists one
`mina_factual_refrigerator_caption` fact. Its acoustic owner
is generated marker `F02_2A_FRIDGE_01`; its visible label follows generated
socket `2A_FRIDGE_FACE`. The before/after acceptance pair and rerun command are
recorded in `art/renders/mina_k6_waking_residue/README.md`.

## Arcade cabinets

The machines in the bar are playable. They are not arcade cabinets — they
are Vantry receiving furniture tuned to a broadcast this world has no
transmitter for, ruled in `design/ORISON_BIBLE.md` VIII.5.g. Each is running
a compiled first-person shooter. They are the same shooter — the world compiler at
`C:\FPSengine01` proves it with `worldc invariance` before writing the catalog,
and `res://tests/ArcadeTest.tscn` re-checks it here. Everything about them,
including how to regenerate them, is in `game/docs/arcade_cabinets.md`.

`game/assets/arcade/` is a **build output**. Regenerate it from that repository;
never hand-edit the catalog, for the same reason you never hand-edit the layout
JSONs.

## Known open items

**`TASKS.md` at the repo root is the live queue** — one line per open task,
shared by everyone working on this. What follows is the standing shape of the
work; anything actionable belongs in that file.

- **Signal parlour.** Never played by a human — verified only headless and
  by screenshot, so the panel's input path is unproven. The layout now
  carries twelve machines, and twelve live 3D worlds has never been
  profiled; machines never free their world once built. `.swcpkg` inclusion
  in the export preset is untested and probably missing. Full list in
  `game/docs/arcade_cabinets.md`.

- **Lighting (phase 5 remainder).** Lightmap bake / GI fallback is not
  started. The light-leak pass is done (`door_glow.gd`) — under-door spill
  and leaf seams, one batched mesh, agreeing with the window pass about who
  is awake. Transoms are not faked because the geometry has none.
- **HLOD and prop LODs (phase 7 remainder).** Untouched. The headroom
  above is measured on one high-end GPU only — mid-range is unproven.
  The coarse floor-visibility stand-in in `building_root.gd` is still a
  stand-in, though occlusion culling has taken most of its load.
- **Mobile.** The APK builds and runs, but the light/shadow budgets in
  `light_rig.gd` were tuned by argument and then loosened once from real
  device feedback. They want confirming on hardware via the debug panel
  sliders, not another guess.
- **Volumetrics.** Unavailable on the Compatibility renderer, so stairwell
  and basement fog needs a different technique. Glass has no dirt masks
  or per-window variation yet.
- **Aging (phase 4 remainder).** The `aging_pass` thin-box patches (facade
  brick, damp bases) should become mask-driven decals for softer edges.
- **Case content (phase 8).** Three of the seven drafted cases are wired
  (01 The Early Answer, 02 Someone Upstairs, 03 Voiceprint Correction —
  the opening trio the design doc names as the strongest). Cases are data
  in `scripts/call/case_library.gd`; `call_interface.gd` is the runner, so
  a fourth case is a dictionary rather than a class. Cases 04-07 and the
  convergence are unbuilt, and the draft in
  `audio_virus_prototype/docs/design/case_network_batch_01.md` is still
  marked NOT CANON — names and outcomes there are not settled.
  Case 02 has a **field phase**: its response window is long enough to
  leave the desk, and standing where the route ends resolves the case on
  foot. That is scored as a different outcome from letting the window run
  out in the chair, which is the whole point — the building learns whether
  you can be waited out. Any case can declare one; see the `field` key.
  What is still missing is the *journey*: the design has contact
  microphones and positional listening on the way down, and right now the
  walk is unguided beyond a banner and the motif playing from the F03
  riser.
- **Rigged residents are LIVE** (`USE_RIGGED_RESIDENTS := true` in
  `building_root.gd` — an earlier revision of this note said paused;
  the flag was flipped and the note was not).
  As of the 2026-08-14 repopulation the whole cast is hero-standard on
  Mina's pipeline: every mapped resident is its raw-dump hero conversion
  plus a personal `<slug>_moves.glb` (shared set baked onto its own rig
  by `bake_model_moves.py`, plus the model's own raw gait as
  `<slug>_Walk`); the generated `_rigged.glb/.blend` placeholders are
  retired. Evelyn keeps her merge hero — she is the bake convention
  reference. See `game/docs/mina_character_pipeline.md`.
- **Wall art placement wants an audit.** The B1 "KNOW YOUR EXIT" sign used
  to render mirrored; the cause was `cull_mode = CULL_DISABLED` on the art
  quad, which draws a reversed copy of the front on the back face, so
  anything viewed from behind read as broken art rather than as no art.
  Art is single-sided now (`character_memory_art.gd`) and the mirroring is
  gone. WalkTest prints an `[ART]` sweep at the end: of 48 pieces, 1 has
  something within 0.34 m in front of it and 8 have nothing solid behind.
  Those are leads, NOT confirmed bugs — a hit in front is as likely to be
  a wardrobe against the same wall, and "nothing behind" fires on anything
  hung over an archway, which may be intentional. Deliberately reported
  rather than asserted. Pinning down the placement rules well enough to
  make either a real invariant is a job of its own.

## Working alongside other sessions

More than one agent session works this repo, sometimes in the same
working tree, and as of 2026-08-13 they are not all Claude — Codex works
here too. Before pushing: `git fetch`, and if both sides changed the
same ground, keep the newest user-directed design, port the other side's
features additively, regenerate artifacts, and prove it with WalkTest.

**Never `git add -A`.** It is banned outright, not merely discouraged:
the tree usually carries somebody else's uncommitted generated data,
`.uid` files and renders, and a sweep commits their half-finished work
under your message. It has also, once, swept in a 170 MB engine binary
that the remote then refused. Stage named paths. If a file is dirty and
you did not touch it, leave it — `TASKS.md` claims are by name on the
line, and the same courtesy applies to the working tree.

Pushing is the other shared hazard. The remote intermittently answers
large packs with HTTP 500 / `unexpected disconnect while reading
sideband packet`, and git rebuilds the whole pack against the pushed
commit's direct parent, so retrying alone can never converge. Ordinary
pushes are fine; when one will not land, `tools/push_chunks.py` walks
the blobs up in 15 MB synthetic commits and `tools/api_push_main.py`
then recreates the commits SHA-exactly through the Git Data API and
moves the ref with no pack at all.

## Defects resolved along the way

Kept because each one cost real time and the diagnosis generalizes.

- **The street-exit blocker** was the B1 bearing wall: 1927 walls run
  continuously past the joist zone, so the basement street wall topped
  out 0.4 m above the F01 slab — a solid curb across the doorway. It now
  stops flush under the F01 slab (`exterior()`), water table dressing the
  base.
- **The basement was sealed by the road.** `site_pass` laid the ground as
  one 220 x 148 m asphalt slab across the whole block, running through
  the building footprint 20 mm under the lobby floor and capping the
  atrium well — every sightline down the eye died on tarmac instead of
  reaching B1. The road is now laid as four bands around the footprint.
  The lesson: site geometry authored in world space does not know the
  building is there, so anything spanning the block needs the footprint
  subtracted explicitly.
