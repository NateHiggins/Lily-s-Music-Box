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

**Dream rendering checkpoint (2026-08-20):** R1–R6 of the production surface
redesign are landed through `art/renders/dream_rendering_r6/README.md`. The
current target pocket is a recognisable furnished Orison invaded by one
dark-live hazard surface: layered tissue/wet/gold, architecture-bound relief,
the seeded eye family, and one hazard-provenant torn Atlas-wall breach whose
flat shader interior reads 32 m deep while the real wall collision remains
intact. R5 now reveals that wound continuously from durable exposure, shares
one Orison/rupture/living-gold controller, confines warp to 0.085 aperture UV,
and returns one measured 0.42-energy / 3.2 m shadowless gold light at retained
high exposure. R6 opens its centre onto one already-live Atlas room through a
bounded shared-world camera, turned one odd quarter-turn. The camera excludes
the sampling wound, making recursion depth zero; it creates no room, route,
collision, light, interaction or danger, and the real wall remains solid. The
R7 rules that depth-zero view complete: recursive rendering adds cost without a
new decision, while enterable nesting repeats the Atlas's existing traversal
promise and would create a second collision/navigation/pursuit contract. Reopen
only for a later case mechanic with a genuinely new verb or consequence. The
ruled capture/embrace is now landed too. One inward camera shell closes from
every edge over 1.5 seconds, preserves the state of the player's lamp, closes
the existing batched eyes, collapses the acoustic room and delays the unchanged
`capture` outcome until its held final frame. It creates no new camera, light,
collision, hazard, topology or input. Proof and exact perf are in
`art/renders/dream_embrace_v1/README.md`. `DreamAtlas` remains topology owner
and `DreamHazard` remains danger owner. The stale chain-era
`DreamPerceptionTest` is repaired against deterministic real Atlas pockets:
60/60 approaches execute with no injected danger or geometry. N9 is now closed
too: Peter's slot-2 data changes onset, run ceiling, silhouette, pursuit
attention, spatial grammar and case truth through the same root/builder/pursuer
owners Mina uses. A junction reversal returns the same remembered room with
one more deterministic, paper-stamped door; Mina is a measured no-op. Proof and
28/28 focused checks live at `art/renders/dream_profile_n9/README.md`. This is
the dream-profile seam only, not a claim that Peter's waking case loop exists.
The owner ruled the full order Mina, Peter, Juno, Mae, Cal, Omar on 2026-08-20.
INC-V3 is now landed: Mina consumes one active 17-map / 96.000004 MiB bundle
through the shared cache and shader include, with annotation/ink/blankness,
all three irradiance bands, five fauna costumes, blank mercy, stillness-only
pressure, anti-tiling and the empty reflected-world plate proved in the
production root. The cache packs scalar channels into the already-budgeted
RGBA maps for nine sampler bindings while retaining all 17 auditable resources.
No annotation gameplay, truth, topology, collision, hazard, pursuit or save
fact changed. Proof: `art/renders/dream_incarnation_mina_v3/README.md`.
INC-V4 is now technically complete as well: Peter replaces Mina with exactly
his active 17-map bundle and uses the same root/cache/include/collector for
recursive blank dockets, oxblood decision lines, carbon depth, legal brass,
the one full-exposure route, pressure-only tenderness and five fauna costumes.
The demanding-door grammar, remembered room, pursuit event, release print,
truth, empty hazard allowlist and save boundary are unchanged. Production
proof: `art/renders/dream_incarnation_peter_v4/README.md`. INC-V5 is now
technically complete too: Juno replaces Peter with exactly her active 17-map
bundle and uses the same root/cache/include/collector for speaker cloth,
paired send/return traces, oxidized brass, pressure tissue, a sub-Hz standing
wave, one sustained band, a quiet node and five fauna costumes. The shader
cannot read or create channel edges, partitions, pursuit attention, sound or
sustain credit; the shared profile and irradiance tests retain those owners.
Production proof: `art/renders/dream_incarnation_juno_v5/README.md`. INC-V6 is
also technically complete: Mae replaces Juno with exactly her active 17-map
bundle and uses the same owners for equal-authority emerald/lapis provenance,
sub-0.1 Hz moire, two reflection lobes, dark overlap, shared thumb pressure and
five fauna costumes. Her presentation cannot reach or adjudicate the two
stored spatial accounts. Proof: `art/renders/dream_incarnation_mae_v6/README.md`.
INC-V7 is technically complete: Cal replaces Mae with exactly his active
17-map bundle through those same owners. Four ordinary thresholds hand the
fading broadcast forward, the fifth drains irreversibly, and only the first
handoff informs pursuit. No topology, collision, hazard, room identity, save
or waking-case fact changed; `cal_memory_radio` remains disabled. Dial glass,
bakelite, wax groove, valve mica, the completed amber phrase, black wake, warm
pressure and five fauna costumes are proved with A/A control at
`art/renders/dream_incarnation_cal_v7/README.md`. INC-V8 is technically
complete too: Omar replaces Cal with exactly his active 17-map bundle. Every
revisit adds a visible impossible fault to one stable machine; it changes no
door/topology/collision/hazard/save fact and does not refresh pursuit, so
inspection costs only ordinary pursuit time. Tool steel, fatigue lamellae,
never-setting solder, workshop enamel, the honest seam, laid-down pressure and
five fauna costumes are proved with A/A control at
`art/renders/dream_incarnation_omar_v8/README.md`. All six downstream profiles
are now authored; neither Cal nor Omar has a waking case loop. INC-V9 joins
all six production proofs at `art/renders/dream_incarnation_v9/README.md`:
paired same-seed roots preserve plan/pursuit/collision/hazard/save facts and
exact active-only 17-map residency, while the windowed six-case sweep is 24/24
under 16.6 ms (worst 2.87 ms). The ordered INC-V3–V9 surface queue is closed.
FA-V4 closed 2026-08-21: DreamWalk's `F` names fauna instances collision-free
from the director's own record, with a windowed `DREAM_WALK_PROBE` self-check
(`art/renders/dream_fauna_fa4/README.md`); it also measured that Compatibility
stores `INSTANCE_CUSTOM` as truncated half-floats, so only the packed HIGH
byte is exact on the GPU. H13's live presentation audit instrument landed the
same day (`res://tests/PresentationAudit.tscn`, proof at
`art/renders/presentation_audit_h13/README.md`): walls are closed by
measurement, the corridor ceiling gap is the atrium light well, and the
"lights disappear with direction" lead is neither gating nor culling. Its
first generator fix also landed: every generated kitchen's toaster stood on
its dishrack from a yaw-rotated offset; `gen_layout.py` now guards worktop
spacing, and the regenerated JSONs (markers only, no GLB rebuild) are copied.
The material sources were scrubbed of the generator's sparkle watermark the
same day (`art/tools/scrub_source_watermarks.py`, run it before every ingest;
record at `art/renders/material_watermark_scrub/README.md`), the ingest's
flat-surface check became relative (TASKS D5), and MX — the layered surface
system — is the next materials programme (TASKS §MX).
M-COVER now has its frames: `art/renders/material_coverage_m/README.md` shows
nine anti-repetition options on the same floors from the same stands with
GPU medians; the recommendation is cell-snapped hex for terrazzo and
per-board-row offsets for oak, both at noise-level cost. The owner adopted it
and ruled the wider programme on 2026-08-21: `design/DREAM_ENCROACHMENT_BRIEF.md`
(verbatim ruling, five-layer dream model, waking encroachment per case flat,
critter skin atlases, build order) and `TASKS.md` §EN / §MC-P. MC-P is in
production (all 26 floor surfaces). EN-1's frames are at
`art/renders/dream_layers_en1/README.md`: the grounded-base / flesh / gold-skin
/ molten-weld / portal stack beside the shipping Klimt from one camera, cheaper
than what ships; it waits on the owner's read before anything is promoted.
N12's shared profile makes delayed
feedback physically load-bearing, then releases the oldest partition when one
channel remains open. N13 lets two real branches return to one stable antique
with incompatible provenance. Cal and Omar are downstream-profile complete;
neither has a waking case loop.
FA1 and FA2 are closed too. One presentation-only `DreamFaunaDirector`
advances bounded 3 Hz densities for Gilder's Buttons, Tessellates, Wine
Anemones, Ribbonettes and the single harmless Loupe, reading real lineage
birth-frames/exposure/lamp/Tenant state. Five shadowless MultiMeshes create no
hazard, collision, light or save seam and remain under one 96-instance cap.
Focused proof is 16/16; the final stable deep-pocket A/B is +3 submitted draws
and -0.01 ms. Evidence: `art/renders/dream_fauna_fa2/README.md`. FA3–FA4 remain
gated and this does not complete any waking case loop.
The owner-directed fauna visual addendum is now queued in
`design/DREAM_FAUNA_BRIEF.md` V9: cloisonné procedural skins, calligraphic
silhouettes and a three-light proof system, reconciled with the rule of cool.
It is now implemented for the landed five without erasing FA1/FA2's gameplay.
FA-V0's read-only adversarial audit is ingested in V10: the unshaded lamp-cone migration, exact packed channels,
bounded material feed, production three-light/A-A harness and four-slice
order are specified. The owner ruled the cached in-engine ArrayMesh kit with
named GLB exceptions, the `0.018 < fauna <= 0.10 < 0.55` dark-glow ordering
(tunable downward by proof), and deletion of the temporary legacy selector at
FA-V3 closeout. FA-V1 Slices A–C are now technically proved: all five families
use the packed unshaded style seam and cached attributed part kit, and the final
render A/B costs at most +3 calls / 0.01 ms. Compact half-float `CUSTOM0` is the
Compatibility-safe layout; full float cost +23/+24 waking calls and indexing
cost +45. The permanent
batch-override proposal was rejected by contradictory +24/+25-call evidence;
five zero-mesh binding nodes preserve the unchanged root owner at zero draws.
Proof is `art/renders/dream_fauna_v3/README.md`; FA-V1 and the FA-V2 landed-five
migration are technically complete. The owner accepted FA-V3 on 2026-08-20;
its temporary environment selector, callable switch and legacy shader are now
deleted while the two comparator PNGs remain historical evidence. Slice D /
FA-V4 DreamWalk remains open. The owner also approved and closed the V12/V13
dream irradiance doctrine as IR-V0–V2. Architecture, lineage and fauna now
share one continuous neon/oblique/molten helper. The existing exposure volume
is RG8: durable gameplay exposure remains R, while reversible rate-limited
irradiance occupies G. The existing PlayerController owns a deterministic
seed/run-clock gutter inside the unchanged lamp-on boolean; only Juno's sustain
accumulator consumes delivered-light seconds. No new draw, material, sampler,
light, texture object, gameplay edge or save owner was added. The production
proof includes 22 frames, A/A, five-step wall/Tessellate sweeps, a six-cycle
luma trace, a steady/gutter shadow pair and gutter-floor Vantry confirmation.
The proof also repaired the existing arc/conduit lifecycle so presentation now
follows HazardField rearm into a later fractal pocket. Focused IR is 16/16, Exposure is
35/35, the shared dream battery is 538/538, dream perf is 0/4 over budget and
WalkTest FAST passes x8/480. FULL was terminated without a result at the
mandatory 60-second process limit; do not claim a fresh FULL pass. Evidence:
`art/renders/dream_irradiance_v1/README.md`. The owner has now queued the six
case-specific surface incarnations in DREAM_FAUNA_BRIEF V14 and TASKS INC-V0–9.
They are presentation love letters over the landed profile/irradiance seams,
not six shader forks or new case owners. The old no-bitmap law is retained as
history but superseded: procedure owns semantic masks/lines/state/gameplay
readability, while AI-derived plates may supply region substance and molten
reflected worlds through the existing ignored-source/shipped-derivative
pipeline. `design/SIX_INCARNATIONS.md` is owner-approved. INC-V1's bounded
profile bundle now reaches the existing architecture, lineage and five fauna
materials through the existing collector while adding no node, draw, gameplay
branch or save fact. `DreamIncarnationTest` passes 28/28; Profile 46/46,
Irradiance 16/16 and Fauna 21/21 also pass. INC-V2 is landed too: the 30-key
ingest manifest, provenance-note rule and whole-dream import-sidecar coverage
feed one root-owned RefCounted cache. It holds exactly 17 active maps, computes
the lossless full-mip ceiling as 100,663,284 bytes (96.00 MiB), substitutes no
case and releases every reference on exit. The ingest audit passes; plate proof
is 6/6. No case is marked available until all five reviewed sets ship. INC-V3
Mina is next. No new accent color was introduced; reflected-world people and
the older faceless figure are explicitly excluded.
The audit's pre-C1 anchor appendix is
superseded and does not reopen the landed commensal proof. Separately, waking-world
commensals C1 is now landed: moths at the two owner-derived entry street lamps,
one sparse F02 riser mouse cue through the shared ambience pool, one habituated
4B switch scatter and one named-hoarding-base weed cluster. Three shadowless
MultiMeshes, 19/19 focused checks, a 1.5 µs tick and matched +3-object/+0.028 ms
street proof are recorded in `art/renders/orison_commensals_c1/README.md`.
There was no `gen_layout.py` edit. E15/C2 is unblocked but not silently begun;
Room 0 exclusion and haunting-controlled animal behavior remain rejected.

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
#    (marker-only changes skip this). THE `bpy` PIP WHEEL IS NOT INSTALLED
#    on this machine (verified 2026-08-16) - `python build_orison.py` dies
#    on `ModuleNotFoundError: No module named 'bpy'`. Use real Blender; 5.2
#    works despite the script's "4.5" docstring, and takes ~41 s:
"/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P art/blender/scripts/build_orison.py

# 4. re-import + run the walk test. BARE `godot` FAILS — the user PATH
#    still points at D:\Python projects\devkit\bin, which no longer
#    exists. Two working addresses, verified 2026-08-13:
#      C:\devkit\bin\godot.cmd                     <- prefer this
#      ./Godot_v4.7.1-stable_win64_console.exe     <- repo root, gitignored
C:/devkit/bin/godot.cmd --headless --path game --import
```

**RUN THAT IMPORT ONCE PER WORKTREE BEFORE ANY TEST, or you will debug a
codebase that is not broken.** `.godot/` is gitignored, so a fresh
`git worktree` has no global script-class cache. Every test scene then
dies in a cascade that reads exactly like rot:

```
Parse Error: Identifier "ChirpHunt" / "PoltergeistLibrary" not declared
Could not find type "PlayerController" / "WorkOrders" / "DoorProp"
Failed to instantiate an autoload, script 'acoustic_graph.gd' does not
    inherit from 'Node'
```

The run never reaches a single check and spams one `_process` error
(~13k lines) until an external timeout kills it at exit 124. Nothing is
wrong with the code. Do not debug those parse errors, and never judge a
bug report "unreproducible" from this state — it is the single most
convincing false negative in this repo. The import takes a couple of
minutes and exits 0. Side effect on the shared tree: it writes ~51
untracked `*.uid` files, which are NOT gitignored (the repo tracks `.uid`
generally). Leave them; never `git add -A`.
(Recorded 2026-08-16 from the parallel session that hit it.)

```
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
  researched copy loader, the first four formerly silent targets (utility case
  latch, chained Passage carts, busy toaster and contextual hardware counter),
  and the laundry control split (lid, safety release, wringer, fill, drain,
  airer cleat and rinse stand). It also proves the five task lamps' local keys
  survive central light-budget passes and the five domestic picture receivers
  tune without erasing a case signal. It also operates an overlaid cistern
  handle and proves an impatient second press cannot restart its refill, then
  switches a baked valve radio on and off without borrowing case state. The
  guard also opens and closes the two authoritative wardrobe leaves and returns
  resident-private copy. The closed/open production pair is in
  `art/renders/wardrobe_split_i4/`; Blender no longer bakes a second pair of
  doors behind them. Finally the guard proves the
  Harukiya jukebox's separate selection-bank and coin-return owners: three
  shipped catalog records play from the cabinet's own spatial pickup and the
  return stops only that local motor, never the WORS ghost-radio director.
- `game/tests/WardrobeInteractionShot.tscn` — paired production visual proof
  for the 21-record wardrobe generator/runtime split. It frames 4A closed and
  open and prints both final hinge angles. Exit code 0 = both frames saved.
  Unresolved state tokens never print, and the case-owner template cannot leak
  generic copy. Exit code 0 = pass.
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

**2026-08-21, latest:** the MX programme (layered surface system) is in
production on the architecture: MX-0 census, MX-1 shader, MX-2 governor,
MX-4 steps 1–3 (walls, finishes, floors with coverage folded in, trims;
relief at 2.5× by owner ruling), draw-heavy tiers (furnishing, props) ON by
owner ruling ("it should reach the props"), paid for by the governor's
prop-tier lever (`SURFACE_PROPS=0` for the A/B); each case's states reach
the props in its flat (`ApartmentEncroachment.reach_props`, clipped by
`state_rect`)
(`art/renders/orison_surface_mx1/README.md`, `SURFACE=0` for the A/B,
`game/tests/SurfaceShot.tscn` for frames). CT-1 fauna skin atlases landed
(`art/renders/dream_fauna_ct1/README.md`). EN-1b landed: the re-layered dream is
in `dream_klimt.gdshader` (`layer_mask`, `DREAM_LAYERS=0` the control;
`art/renders/dream_layers_en1b/README.md`), and Klimt's NORMAL is now
view-space — the lamp reaches the plaster. EN-2 landed 2026-08-22: the weld
core opens onto R6's live view (`art/renders/dream_layers_en2/README.md`).
MX-3's first slice landed
2026-08-22 (`ship_surface_tables.py`: calibrated heights + generated table,
`wall_age.png` mask library as the standing age). The encroachment is a
state of the one surface since 2026-08-22 (`os_encroach`;
`wall_encroachment.gdshader` is reference only). The six encroachment grammars landed 2026-08-22, and with them the fix that let
flats other than 2A encroach at all. EN-3 landed 2026-08-22 in both halves (surface fold + tessellated boxes whose
wall vertices sink into the weld; Gate C clean). The encroachment is now a
living slime-mould field per case flat (`LivingField`, `design/LIVING_FIELD_BRIEF.md`,
`art/renders/living_field/README.md`; `LIVING=0` restores the static creep);
Second ruling built the same day: the organism is storey-wide with a gravity
of its own, radiant onto nearby meshes and lights, pooling on floors, carrying
the dream's states (`LivingFieldTest` 14/14). Third ruling the same day:
the organism in someone else's flat is reported by that resident (a work
order in their voice) with a seeded chance of a fixable appliance condition
whose fix repels it (`OrganismIncidents`, `OrganismIncidentsTest` 18/18,
`ORGANISM_INCIDENTS=0` off). LF-2 landed the same day: the grammars ride
the organism (`art/renders/living_field/README.md` LF-2). §LF is closed;
next rows are MX-3's rest and the EN-2/EN-3 taste rows. Open, in order:
MX-3's rest (ORM, detail maps); the WK-1 per-case grammars; EN-3
folds; CT-2; the EN-2 taste/perf rows (weld vocabulary placing R6's
camera; trim the ornament under the layers). `TASKS.md` §MX / §CT / §EN. Harness note: the layout's y is
Godot's −z — 2A is at z +0.45..+9.65.

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
dream request with a test stub; production now owns the N4 scene transaction,
N5 onset and the N6 maze assembly and pursuit. Owner correction 2026-08-15:
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
exact scene/save contract is `game/docs/dream_boundary.md`. DreamMazeRoot now
assembles its slot's module chain from the N2 catalog and the exact campaign
seed, spawns the dream body with the real service lamp, and runs the
shadows-only release-print pursuit. N5 now gives
CampaignShell one persistent SleepPressureDirector: Mina's authored 2.60-second
gradual warning, exact mid-onset real-file restore, the shipped Always-warn
option, and pause-without-cancel gates for `call_locked`, unstable floor, the
real lift seam and the permanent carriageway. It is the sole production caller
of dream entry. The 20/20 contract and A/A/B/C visual proof are in
`game/docs/dream_onset.md` and `art/renders/dream_onset_n5/README.md`.
**N6 is now closed:** the runtime maze (slot-1 chain `D00→D01→D03→D04→D05`
from the catalog and seed, real opaque graybox collision, sealed later-slot
connectors) and Mina's release-print pursuit landed with a 39/39 exact-count
proof — the `mina_vale` silhouette never enters beauty, module walls block
acquisition, the real lamp owner gates pursuit (6.450 s on / 10.742 s off /
10.600 s extinguished captures at the fixed seed, 0 route violations), and
capture reaches `end_dream("capture")` through the shell. Record and frames:
`art/renders/dream_pursuit_n6/README.md`.

**N7 is now closed, and with it Gate D.** The run can end three ways through
one latched funnel in `DreamMazeRoot._commit_outcome()`: capture, the slot's
authored 28 s ceiling, and hazards. The Vantry trunk's condition is `lamp_on`
(the arc reaches for the beam, so light activates the danger it reveals) and
the open lift void is a real hole subtracted from the floor slab, resolved by
real gravity rather than by a radius. `DreamCaptionLayer` writes each tell as
a cue and one of eight sectors and nothing else, under the opt-in
`dream_directional_captions` setting.

`GateDJoinTest.tscn` closes the seam that had gone unnoticed because both
sides of it were green: `GoldenLoopTest` played the whole shift but answered
the dream request with a test-only stub predating N4, while
`DreamPursuitTest` ran the real maze but wrote finished job facts straight
into `RealityState` instead of earning them. Gate D now plays the shift inside
a real `CampaignShell` and carries it into the real dream, once per ending:
`capture` 69/69, `contact` 71/71, `fall` 71/71, each about 35 s and each
returning to the authored 4B bedside in a REBUILT waking Orison. Set
`GATE_D_OUTCOME` to choose the ending.

Two things a future harness should not rediscover the hard way. The production
onset clock cannot be used in a joined test: onset is 2.60 sim-seconds, or
0.74 wall seconds after the case resolves, and every gate passes at that
moment, so the dream enters mid-assertion and the shell frees the waking world
underneath it — use `sleep_manual_clock`. And `DreamBoundaryTest._exclusive()`
counts the `waking_world` group, which only the boundary *stub* joins; the
real `OrisonRoot` joins `building_root`, so copying that helper reports a
false failure on a correct join.

Numbers, and a recorded correction to several claims that an adversarial
review found overstated, are in `art/renders/dream_hazards_n7/README.md`. The
one binding constraint to carry forward: the dream acoustic graph, when built,
must **attenuate** hazard tells across a wall and must not **silence** them —
occluded to its own room the trunk gives 0.65 s and the void 0.13 s against
the 0.90 s their sockets owe. The runner gives 0.92 s against 0.75 s.
`DreamPerceptionTest` now stages each real source through deterministic Atlas
ancestry, prints that verdict every run and is that work's acceptance check.

The next dream items are presentation or separately ruled breadth: FA3–FA4
remain gated after the successful harmless FA2 trophic loop; the hollow runner's effect is blocked
on an owner ruling — the catalog puts its socket in `D01_F04_LONG_HALL` while
the brief's script says D04, which has no sockets), the trunk's lit
beam-splash, and the production dream `WorldEnvironment`. Gate E is untouched. GoldenLoopTest's two K6 objective-title checks failed
on clean origin at that time; **resolved 2026-08-16 on `66a00f3`** — the
cause was `b318d84`'s telegram restyle prefixing `"WORK ORDER / "` onto
titles the job library already authors, not the `1f8faa0` I had suspected.
87/87 green again. Wake
persists one
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
- **THE LIGHT BUDGET, IN THE ONLY ORDER THAT IS TRUE.** There are three
  layers here and reading any one of them alone gives you a wrong answer.
  I got this wrong twice in one day; the empirical check is at the bottom
  and it settles it in four seconds.
  1. **Engine per-object cap: 128.** `project.godot` sets
     `limits/opengl/max_lights_per_object=128`, raised from the
     Compatibility default of 16. That raise was real and load-bearing: a
     storey's walls merge into ONE mesh, so a 28 × 20 m plate overlapping
     40 fixtures used to keep an arbitrary 16 and a lit corridor went
     black at its far end. That failure is fixed and cannot return.
  2. **`light_rig.gd`'s `UNLIMITED = 4096` IS DEAD TEXT.** Its header
     narrates a desktop budget removal that never reaches production.
  3. **`building_root.gd:456-465` overrides it on EVERY boot** —
     `set_budgets(16, 16)` on the cinematic max-quality path,
     `set_budgets(14, 8)` otherwise. There is no branch that leaves the
     rig unlimited.
  **So real lights ARE scarce: sixteen active, sixteen shadow, and every
  new one evicts an existing one.** All those "measured at 16/16" tables
  were therefore accurate about the *live* budget, not merely about a test
  condition — what was stale in them was only the *mechanism* they blamed
  (the per-object cap, now 128). Shadows are scarcer still, because
  `positional_shadow/atlas_size=8192` also subdivides per caster, so each
  one shrinks all the others. Draw calls remain the real frame bottleneck.
  **Never infer this from constants or comments — print it.** Every run
  logs the resolved pair, and the rig logs it precisely because a wrong
  budget once survived in three documents (`light_rig.gd:328-330`):
  `[LIGHT RIG] budgets resolved: 16 active / 16 shadow`
  **Standing shadow policy, owner ruling 2026-08-16:** a new fixture ships
  with `shadow_enabled = false` and has to earn a caster slot. Authored
  fixtures obey by construction (LightRig ranks and grants through
  `LightFixtureProp.set_budget`); ad-hoc lights built in scripts are the
  population that creeps, and LightingAudit now gates them at
  `UNGOVERNED_CASTER_BUDGET = 8`, measured. Raising it is allowed and
  expected — it must just be a deliberate edit naming the new caster.
  Historical tables that say "measured at 16/16" are accurate records of
  how a measurement was taken and must not be rewritten; only live claims
  that the cap constrains authoring today are wrong. Corrected in place
  2026-08-16 at `art/docs/photoreal_target.md`,
  `design/walkthrough_punchlist.md`, `design/PROP_ACTIVITIES.md`,
  `design/FINAL_MAP_REDESIGN_BRIEF.md` §10ab, `art/data/gen_layout.py`
  and `exterior_detail_pass.gd`. See TASKS §L11–L12.
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
