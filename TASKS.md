# OPEN TASKS

The shared queue. Everyone working on Orison writes here.

*2026-08-10: the arcade/compiler session took over the Orison work as well.
Sections A, C, L, N, S, U and the compiler-side items are all held by one
session now; that is a fact about staffing, not a claim of ownership over the
queue. Anyone may still add.*

**This is a list of open work, not a log.** Delete a task when it is done; git
history is the record. If a task is wrong, say so on the line rather than
quietly removing it.

## How to use it

- **Add to the bottom of a section.** Ids are permanent — never renumber.
- **Claim by putting your name in the line.** No name means unclaimed.
- **Section prefixes exist so two agents adding at once do not collide.**
  `K` core loop · `D` decisions · `A` arcade · `S` studio · `M` materials ·
  `H` housekeeping; subsystem sections retain their own prefixes.
- One line each. If it needs a paragraph it needs a brief in `design/`.

---

## K — Core loop / the complete shift

Product authority: `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`. These are
the immediate executable gates, not a second copy of its milestone status.

- **K1** Run M0 against the current tree: fresh-save Mina state trace, existing
  tests, warnings, critical-route reachability and performance baseline.
---

## D — Needs a decision from the owner

Nothing below is blocked on effort; it is blocked on someone choosing.

- **D1** Studio: does the desk power up? A room the player can use is a system;
  a room they can only look into is a landmark. The layout supports either.
  *Blocks S1.*
- **D2** Studio: do the storage cages stay? Argued for in the brief, but it
  costs floor area.
- **D3** Studio: is the echo chamber's extra tail ever *heard*, or only measured
  on the reel?
- **D4** Studio: which resident is found down there, if any, and at what hour.
- **D5** Coarse-luminance threshold is **absolute** luma (0.02) — that is 2.6%
  relative on plaster at mean 0.70 and 13% on a dark floor. Perceptually
  backwards. Absolute or relative? Shared definition, so it binds both
  pipelines.
- **D6** Does **VIII.5.g retire "minigames"** as a frame? The ruling says there
  is no video game industry in this world, but the pool table, the darts, the
  can-stacking and "one minigame per landmark" are all still described as games.
  Pool and darts are 1927 pub games and survive untouched; the question is only
  whether anything *screen-shaped* may be a game, or whether every screen must
  be a received broadcast. Answer binds the bodega machine and everything after.

## A — Arcade / the signal parlour

Ruled in `ORISON_BIBLE.md` VIII.5.g. Docs: `game/docs/arcade_cabinets.md`.

- **A2** Nobody has played one. `arcade_panel.gd` is unproven in the hand: mouse
  capture and restore, ESC, `E`, and whether a 480×360 feed at 2× is aimable.
  Expect tuning, not repair.
- **A4** *Measured 2026-08-10, and the answer is: the arcade is not the problem.*
  The premise was wrong - the twelve cabinets are scattered one or two per venue,
  not standing in a row, and sampling the F01 plane at 0.25 m says **no reachable
  point sees more than five** at the 9 m gate. That worst case is now a perf
  station: **19.73 ms**, the second cheapest of eight, against 42.05 for the
  atrium. Five live boards cost about what a bedroom costs. Nothing to do here;
  spend the effort on **P1** instead.

- **A5** Audio is undifferentiated: attract mode is silent and every machine
  shares one weapon report. The World Bible already carries a `sound_palette`
  per world and nothing consumes it. Probably the highest-value polish left.
- **A6** The held object is procedural GDScript built from `held_object`, not a
  compiled mesh shipped in the package like every other visual.
- **A7** `arcade_panel.gd` reads raw keys, bypassing Orison's input map — on
  purpose, so a cabinet cannot inherit the outer player's bindings, but it means
  no rebinding, no gamepad, no touch.
- **A8** Port drift: `game/scripts/arcade/swc_*.gd` is a deliberate *copy* of the
  compiler repo's runtime. Nothing checks the two have not diverged.
- **A9** Screen legibility at distance in the dark bar. Brightness floor on the
  feed, or accept it as atmosphere? Worth deciding rather than defaulting.
- **A10** Every spawned enemy is named `Enemy`, so Godot's rename-on-collision
  makes their degrade thresholds differ slightly. Cosmetic.

## G — The phonautograph

Ruled in `ORISON_BIBLE.md` III.2. The Harukiya's machine is Scott de
Martinville's 1857 phonautographe, and the prop is built.

- **G1 OWNER CORRECTION — REWORK REQUIRED.** `ORISON_BIBLE.md` III.2 now
  separates the native-speed instrumental catalogue from the player-made
  version. The player performs to a varied, unsped backing; publishing sends
  the complete take through one too-fast varispeed reconstruction, raising
  tempo and pitch together with no formant correction. That nightcore/chipmunk
  artifact is what other players hear.
- **G1a CURRENT CODE IS NOT AUTHORITY.** `PhonautogramReader.GUESSES` rerolls
  speed in both directions and labels `0.5x` as the 2008 error. First Sounds'
  documented error was a too-fast reading (two vocal-scale playbacks were at
  twice the correct speed). Replace random per-listen guessing for player-made
  versions with one tuned `reconstruction_ratio > 1.0`, stored on the immutable
  community version. Found traces may retain a separately authored unstable
  reader; they do not define shared karaoke playback.
- **G1b REWORK READ IT BACK.** The review option exists, but it currently reads
  only the dry vocal through a fresh guess. It must audition the same composite
  reconstruction recipients get: stable base backing plus the recorded vocal,
  both varisped together. The clean mic stem may stay local for latency and
  assembly; do not expose it as the shared artifact.
- **G1c** Playback may be non-positional in the review UI and spatial when a
  community version is deliberately played in the room. An uncommanded voice
  is not evidence that the cylinder learned playback.
- **G2** The basement studio is no longer the only possible playback site. It
  may own restoration, publication or found-trace work, but community versions
  must be receivable by everyone playing the game. Reframe S5 after the shared
  version contract is implemented; do not force the social feature through a
  basement visit.
- **G3** A trace is an OBJECT, like a reel: findable, carryable, losable. Some
  are already in the building and the player did not make them.
- **G4** **DONE for found traces only.** Four traces are on the
  machine when the player arrives, readable from WHAT WAS ALREADY ON IT. They
  are **synthesised, not recorded** - `PhonautogramForge` derives a line from
  the trace's identity and turns that line into a pressure wave, which is
  exactly what First Sounds did in 2008 minus the paper. There is no recording
  of these because there was never a recording of anything: a phonautogram is a
  line, and every sound anyone gets from one is a reconstruction. Their
  unstable/ambiguous read may remain as authored found-object behavior; it must
  not leak into the immutable player-version contract.
- **G4b** The sleeves are the hook and they are deliberately thin: "for M." with
  four residents whose name starts with M, a WORS sleeve with the date rubbed
  out, one found behind the pipes, one with no sleeve at all. **Nothing in the
  bar can resolve any of them.** What the basement studio should be able to do
  is say something about a trace the bar cannot - a cleaner read, a second
  voice, a date - and that is the errand.
- **G5** If singing is heard in the bar when no terminal or community version
  is deliberately playing, it is the Tenant. The cylinder itself never emits
  recorded audio.
- **G6 OWNER DIRECTION — PHRASE DUELS.** Design and seed bank are in
  `design/ORISON_SONGBOOK_PHRASE_DUEL_BRIEF.md`: players learn safe,
  period-attested phrase cards from dialogue, answer later calls with learned
  retorts, and construct lyric books from whole-line multiple choices. Public
  lyric data is phrase ids, never arbitrary text. Start with the `LAST TRAIN
  HOME` private graybox only after G1's corrected playback contract; do not add
  inert runtime data before the loader, composer and persistence owner exist.
- **G6a PUBLIC AUDIO IS A SEPARATE GATE.** Curated phrase ids do not prevent a
  player from singing other words. `COMMUNITY` microphone sharing remains
  disabled until consent, clean-stem analysis, report/block, takedown, appeals,
  retention and platform/age requirements have an owned design. PRIVATE may be
  the prototype; FRIENDS needs its own controls. Nightcore transformation is
  not moderation.
- **G7 OWNER RULING NEEDED — THE HOUSE RIG.** The owner asked for a heavy bass
  beat and ghostly distortion on the returned take ("this is just slightly
  faster"). Prototypes exist (`art/audio/Moonlight_HAUNTED_FLOOR_x1335/x1414`,
  2026-08-14, chain documented in the House Five book's audition log), but
  Music Bible §5.2 currently refuses anything added after the speedup. Rule it:
  pure varispeed stands, or §5.2 gains one authored house-rig chain (still one
  immutable ratio, still no formant correction). If adopted, the next pass is
  arrangement-aware (kick enters at the chorus, drops for the interlude).
- **G8** Scratch-vocal return test for the Moonlight/Dreamland candidate: a
  disposable vocal over the full 48k base, one complete take, ×1.335 true
  varispeed — that judges House Five checklist items 9-10 (the 2007 test).
  The base-only preview cannot pass or fail a candidate.

## S — Basement studio

Proposed in `design/ORISON_STUDIO_BRIEF.md`. Not canon until the owner rules.

- **S1** Author the studio and echo chamber in `gen_layout.py`. Studio in
  `B1_STORAGE_CAGES`, chamber in `B1_UTILITY`, clear height 2.62 m. Never
  hand-edit `building_layout.json`. *Blocked by D1.*
- **S2** Six new Blender assemblies: `mixing_desk`, `monitor_pair`, `patch_bay`,
  `control_glass`, `acoustic_drape`, `chamber_fitting`. Reuse the nine that
  exist first; check for an upright piano before authoring a seventh.
  *Blocked by S1.*
- **S3** Wire the chamber into the acoustic graph. Send and return cross
  `B1_ATRIUM` past the `room0_threshold`, so the return shares house wiring
  rather than a cable of its own. *Blocked by S1, D3.*
- **S4** Studio props and the dead-channel chore: pull the rack, read the
  schematic in the lid, find the dead valve, buy one at the bodega, return.
  *Blocked by S2.*
- **S5** Reframe the studio as a restoration/publication workspace after G1's
  shared-version contract lands. The bar is where songs mutate; a basement
  visit must not gate receiving the community's versions. Ghost duets and found
  traces may still belong downstairs. No pitch scoring. *Blocked by S4 and G1.*

## R — The street's shops

Built in `art/data/shop_interiors.py`. Guide: `design/SHOP_INTERIOR_BUILD_GUIDE.md`.
**The rooms are display cases, not spaces.** They were authored to be looked
into through a storefront; the owner wants them walked around in, by the player
and by NPCs. R2 needs a brief before anyone builds.

- **R1** Measure before resizing. Interior width is the authored bay less the
  200 mm party-wall inset. **Floor area is the number that matters, and it is
  small**: news 8.4 m², radio 15.0, locksmith 17.0, pawn 26.4, druggist 28.7,
  photo 30.0, funeral 30.8, cobbler 32.4, hardware 33.8, diner 35.0, laundry
  37.8 — all of it under a **3.30 m clear ceiling** (`SHOP_CLEAR`). That ratio
  is the complaint: these are tall narrow slots, not rooms. Player capsule is
  `BODY_RADIUS` 0.33, so a 0.66 m body needs ~0.9 m of aisle not to scrape.
- **R2** Enlarge and re-plan. **RULED BY THE OWNER 2026-08-10: DO NOT GAIN
  SPACE VERTICALLY.** Ceiling height is not usable space — a taller slot is
  still a slot. Three requirements, together: *historically accurate*, *less
  interior clutter so the player can move*, *use the space to its fullest*.
  They reconcile the way a real 1928 shop did — **density at the perimeter,
  clear floor in the middle**. Goods went floor-to-ceiling on the walls, behind
  and under counters, and overhead on rails; the customer floor stayed open,
  because the shopkeeper fetched. Fully stocked and walkable is the period-
  correct answer, not a compromise between them.
  Mechanically: **depth is the cheap axis** — `SHOP_PLAN` cuts further into the
  block and nothing is behind the south row. **Width is not:**
  `_south_street_wall()` makes every shop its own building, so `x0/x1` drives
  the footprint, void, awning, blade and signage together. Two cannot grow
  backward at all — the diner sits in the Harukiya's mass (`nbr_s2`) and the
  druggist in `nbr_w`. Nothing has been built yet: `SHOP_CLEAR/SHOP_H` are
  still 3.30/3.55 and every `SHOP_PLAN` depth is as filed. *Needs the brief.*
- **R3** NPCs have no way in. Movement is anchor-to-anchor in
  `resident_routines.gd` — there is **no NavigationRegion3D or NavigationAgent3D
  anywhere in the project** — so "NPCs move around inside" means authoring venue
  anchors per shop, not dropping a navmesh. Overlaps #22 (favourite spots) and
  should be done with it rather than twice.
- **R5** Two things the re-plan must not break: the **181 per-shop buffers**
  (fittings falling back into floor-wide buffers is what made the bodega go
  black), and `ShopEntryTest`'s ruling that the NEWS CIGARS proprietor side stays
  inaccessible — that one is deliberate, so changing it must be a decision.
  Watch the street elevation too: **32.53 ms** after the door pass streamed 120
  doors (it was 47.11 when this was filed), so there is real headroom for
  fittings now — but it is still double the budget, so spend it deliberately.
- **R6** **Residents walk through furniture, everywhere, today.** `resident_nav.gd`
  builds its AStar graph from `fl["walls"]` alone and never reads a prop, so the
  router cannot see a counter, a shelf or a display case. Harmless while NPCs
  only cross open corridors; fatal the moment they are asked to move inside a
  fitted shop. R2's re-plan is wasted unless the router learns about fittings —
  and the fix is worth having building-wide, not just on the street.


## V — Navigation, access and the play space

Opened 2026-08-13 from the map-redesign Phase 0 measurements
(`design/FINAL_MAP_REDESIGN_BRIEF.md`). R6 is the parent complaint; these are
the specific defects behind it, and V1 is the revamp the owner asked for.

- **V1** **Revamp resident pathfinding.** `resident_nav.gd` builds one AStar3D
  per floor from `building_layout.json` room rects, door markers and leafless
  wall openings, and **never reads a prop**. R6 is the symptom, this is the
  job. Wants a brief before code: the router has to learn fittings without
  becoming a navmesh, because there is no `NavigationRegion3D` or
  `NavigationAgent3D` anywhere in the project. Today: 336 nodes over 8 floors,
  57 wall-crossing edges rejected, 314 relinked.
- **V2** `validate_with_collision()` raycasts **once**, two physics frames
  after build (`resident_routines.gd:350-354`), against whatever colliders
  exist at that instant. Props spawned, moved or possessed later are invisible
  to the graph, and the relink step will happily connect an island through a
  gap that closes afterwards.
- **V3** `route()` returns `PackedVector3Array([from])` — stand still — when no
  wall-safe anchor pair exists (`resident_nav.gd:290-297`), warning once per
  rounded coordinate pair. A room rect edited without its door marker yields
  silently frozen residents rather than a failure. Make it loud.
- **V4** Residents are parented to `floor_nodes[floor_id]` and **never
  reparented**, so anyone who walks or rides to another storey is culled with
  their HOME floor. Tests paper over it with `show_all_floors`
  (`phone_light_shots.gd:24-26`). Every schedule that sends someone to a shop,
  the bar or the roof exposes it.
- **V5 DONE.** **Four shops sat outside the lateral stage boundary.** `STAGE_W`
  −20.10 / `STAGE_E` +20.60 against a parade running x −32.4..31.6 leaves
  laundry, cobbler, hardware and photo — **139 m² of fitted, lit interior** —
  beyond the playable bounds. **ANSWERED 2026-08-13 by `RouteProbe`: they are
  REACHABLE, and the play space leaks.** The south pavement sweeps walkable
  end to end to x −30.0 and x +29.5, and all four shop doors are reachable —
  every approach stops at 94%, on the glazing or on the laundry's own
  `HingedLeaf`. `ExteriorStreetStageBoundary` is two boxes 7.55 m deep centred
  at y −13.45; they close the north walk and part of the carriageway and never
  touch the south pavement. A player can stand ~10 m outside the intended
  lateral limit. Containment failure, not inaccessibility. Phase 3 moved all
  eleven shops into the Passage; Phase 4 replaced the partial boundary with
  visible hoarding/weather across both complete street sections.
- **V7** Reach versus authored height: the interaction ray is 2.1 m from a
  1.41 m eye, while measured shop counter tops run 1.05–1.18 and photo's brass
  top sits at 1.41–1.45, i.e. exactly at the eye line. The build guide states
  0.90–1.05. Decide which is canon before a Passage reuses those boxes.

## L — Light

`tests/RoomLumaAudit.tscn` guards this. **Run it windowed** - it reads pixels
back, and a headless run reports every room black. It turns each room's own
switch on before measuring, because a room the player has not lit is a mood
choice while a room still void after the switch is a defect. `LightingAudit` is
the companion and checks COVERAGE only; it never looks at a pixel, which is how
this went unseen for months.

**127 rooms PASS, `KNOWN_DARK` empty.** Keep it empty - anything added there is
an open defect, and rooms that are *supposed* to be dark go in
`INTENTIONALLY_DARK` with a reason.

- **L9** Owner call, now that they are visible: `B1_BOILER`, `B1_COAL`,
  `B1_ELECTRICAL`, `B1_STORAGE_CAGES` and `ROOF_OPEN` all read between 12 and 56
  with their lights on. A boiler room is *allowed* to be dark. If any of them
  should be, move them to `INTENTIONALLY_DARK` rather than leaving them lit by
  default.
- **L10** The audit measures one frame per room from a corner, with a fallback
  to the room centre. Rooms whose interesting half is neither will read
  optimistically. Worth a second angle if this ever becomes a shipping gate.

## T — The street and its traffic

Ruled and built under `design/ORISON_STREET_BRIEF.md`. The owner's later weather,
road-clearance and night-readability directions supersede the brief's four old
questions: the ends are quiet dense storm rather than loud tears; only traffic
emerges (no expelled debris or people); the rail-less tram is the authored wrong
5%; and traffic continues at night.

- **T1 DONE — BUILT RULINGS RECONCILED.** §8 now records the four decisions
  already present in production. This is documentation of the approved street,
  not a new spatial or fiction decision.
- **T2** **BUILT.** `StreetTraffic` - one MultiMesh for every vehicle, scaled
  and tinted per instance, plus a second for lamps. Ten kinds: dray, motor car,
  coal lorry, van, hansom, milk float, tram, hearse, and the wrong 5% (one too
  long for the road, one with no horse and the horse's pace). **It costs
  nothing**, which is what instancing from the start bought: street elevation
  measures **30.30 ms against the 33.28 ms baseline**, and objects went 14,081
  -> 14,145 for fourteen vehicles.
- **T2b** **Voices built, on FORGED audio - placeholder.** Five
  `AudioStreamPlayer3D` reassigned to the nearest vehicles each frame (fourteen
  would be fourteen voices competing on the worst station in the game), pitched
  by speed and by vehicle size so a lorry sits lower than a car. The loops
  themselves are synthesised in `_forge()` and **should be deleted the moment
  real recordings land** - see `design/STREET_AUDIO_SHOPPING_LIST.md`, which
  lists six sounds, CC0-only, with #1 and #2 alone enough to pass the brief's
  own test of crossing by ear.
- **T2b-old** Original note: The brief asks that a player
  can cross by EAR with the camera facing a door, and there is no sound on it
  at all yet. That is the single biggest gap between this and the brief.
- **T2c** **Silhouettes built.** Four original batches carry bodies, cabs,
  wheels and lamps, so each vehicle is a stepped shape on four wheels rather
  than a crate sliding down the road. T2d adds one shared wet-road reflection
  batch, and T2f adds one sign batch only when that rare truck is present.
- **T2d DONE — NIGHT TRAFFIC READABILITY.** Every live vehicle now paints one
  5.2 × 1.55 m broken tungsten reflection ahead of its nose. The whole stream
  shares one shadowless `TrafficWetHeadlightPools` MultiMesh; an empty road
  submits zero instances. It is a soft additive reading cue on the wet paving,
  not illumination: zero `Light3D`, zero shadow, no body self-emission and no
  brighter street lamps. Twin sources widen and dissolve inside a broad noisy
  pool instead of reading as clean game stripes. Fixed canonical-night
  control/control/final frames live in
  `art/renders/traffic_night_readability_t2d/`; the duplicate control records
  live-rain variance. `TrafficNightReadabilityTest` passes. A focused 1440p
  fresh-process pair measured 29.99 ms hidden versus 30.29 ms live while the
  runtime population itself differed by 10 objects / 15 calls, so the delta is
  inside run noise; the structural cost is exactly the one shared draw.
- **T2e** **SUBSUMED BY T2d.** Lamps remain emissive quads and the new roadway
  response remains an additive batched reflection; neither is a realtime light.
- **T2f DONE — WE TUNA PIANOS.** A rare 1928 one-ton piano-repair box truck
  joins the ordinary two-way stream at 2.0 / 99.0 selection weight. Its deep
  teal rear box and separate low cab stay inside 5.8 × 2.05 × 2.30 m; two dull
  painted panels carry the approved shark-and-mustachioed-tuna advertisement.
  Every visible repair truck shares one shadowless sign MultiMesh, so the exact
  cost is one draw owner and two panel instances only while present—zero light,
  collision, stop rule, dialogue or permanent scenery. `PianoRepairTruckTest`
  passes; production-street frames are under `art/renders/piano_repair_truck/`.
  This does not pretend to close T2d's street-wide night-lighting problem.
- **T3 DONE.** No death, damage, UI or dedicated crossing point. A hit now
  carries the real player with the vehicle for 0.72 s, damps rather than removes
  steering, gives the camera one restrained 4.9° roll and recovers without an
  input. Look remains live. Traffic owns four seconds of repeat immunity, so
  contacts cannot stack into a launch; calls and noclip cancel/reject the state.
  The carry vector follows world X, correcting the old cross-lane axis error.
  There is no health state, get-up prompt, fail screen or bespoke impact audio.
  `MAX_WAIT` remains an enforced promise rather than a tendency.
- **T3b DONE.** `PlayerController.stagger()` is the narrow public contract;
  `StreetStaggerTest` drives it through production `StreetTraffic` and proves
  displacement, recovery, retained look, non-stacking, protection and the
  absence of damage state.
- **T4 SUBSTRATE DONE.** The partial lateral collision is retired. At exact x
  −20.10 / +20.60, wet timber works own both pavements and quiet local weather
  owns the carriageway; `StreetContainmentTest` proves all six lanes. This does
  not settle T1's loudness, debris, arrivals or night-traffic questions.
- **T5 DONE.** The 4.4 × 1.4 m shelter is restored at (−12.6, −25.55) with
  literal 100 mm posts, glazed back, centre mullion, timber bench, bounded
  local material ownership, physical close-weather cover and a zero-light
  **CARS STOP HERE** board. Only eastbound trams serve it: one stop at x
  −10.40, one 4.5 s dwell, then an eastward resume; every opposite-lane or
  non-tram control passes through. Both pavement bypasses remain capsule-clear.
  Five visible owners cost 14 submissions and no measurable time at canonical
  street elevation (29.98 ms visible and hidden; repeat reversed inside noise).
  `TransitShelterTest` 20/20 plus containment, route, weather, lighting,
  Passage ownership/visibility and WalkTest FULL x8/480 all pass. Day/night
  proof: `art/renders/transit_shelter_t5/approved/`. T2d remains open; this
  task does not mislabel the deliberately crude tram silhouette as finished.
- **T5b DONE — ROAD CLEARED.** The superseded utility-excavation set piece is
  gone: four trench slabs, four spoil heaps, two loose planks, sixteen striped
  contractor barricades and one loose-paper assembly. It belonged to the old
  across-the-road shop layout and was fencing all four traffic lanes after the
  final x −20.10 / +20.60 timber-and-weather boundary took ownership. The
  zebra, traffic, shelter, wet-road detail and both visible stage ends remain.
  `RoadClearanceTest` proves zero obsolete production records, all sixteen old
  barricade stations capsule-clear, and the six-span boundary intact. F01 is
  −10,816 vertices / −17,952 indices / −381,296 bytes; fixed A/B plus a live-
  rain noise control is in `art/renders/road_clearance_t5b/`.
- **T6 DONE.** The first controllable frame now starts on the south kerb beside
  a low teal-black motor car, facing the full 30 ft crossing and Orison door.
  It holds 1.15 s without seizing the camera, accelerates to 6.4 m/s, merges
  into the eastbound lane, crosses the exact x +20.60 storm boundary once and
  is removed at x +27.00. It reuses the shared shadowless traffic batches,
  including T2d's wet-road response, adds no light or collision, cannot replay
  after `intro_complete`, and ordinary traffic resumes after a 5 s first-image
  clearance. The traffic
  player-reference startup bug is also closed. `ArrivalCarTest` passes; three
  fixed morning-rain frames are in `art/renders/arrival_car_t6/`. Transit,
  containment, route, weather, lighting, Passage ownership/visibility and
  WalkTest FAST all exit green. The single FULL x8/480 attempt produced no
  result inside the 60 s bound and was terminated; no FULL result is claimed.
- **T7 DONE.** The historical canonical-night street elevation was 29.30 ms
  against 16.6, still CPU-bound on submission. T7a closes P7's safe script-side
  remainder: the floor/prop/door gate now evaluates an exact eight-storey
  region signature and skips the ~734-actor scan until a visibility boundary
  changes. Direct in-scene attribution measures 0.003 ms/signature versus
  0.207 ms/full scan, **0.204 ms avoided per stable physics tick**. A fresh
  same-build frame pair read 28.79 ms cached / 29.58 ms old scan, but differed
  by 647 render objects, so the 0.79 ms is explicitly not claimed as causal.
  T7b then measured the actual playable north pavement, correcting two probe
  defects first: a detached eye-height override admitted F02, and the census
  counted render-layer-zero zone content plus lights inside arcade SubViewports.
  At the clean lens, Orison-core fixture shadows were the submission leak.
  `LightRig` now keeps their illumination but declines their shadow maps only
  while the player is physically in STREET; entry/facade lights, the phone,
  moon and Passage retain shadows, and ORISON restores the ranked shadow budget
  on entry. Same-build fresh-process controls are 35.929/36.486 ms versus
  26.486/27.042 production: **36.208 -> 26.764 ms (-9.444 ms, -26.1%)**,
  with mean calls **25,309 -> 12,207 (-51.8%)**. A paused same-process A/A/B
  render proves the small visible delta without hiding live-rain noise under a
  false zero; evidence is `art/renders/street_core_shadow_t7b/paired/`.
  LightingAudit passes the outside suppression, exterior preservation and
  inside restore. T7c then removes a second ownership leak: low STREET was
  still submitting 1,150 F01 draws wholly enclosed by the Orison shell. The
  new spatial index gates only complete AABBs behind the shell; WindowGlow,
  the landmark entry, facade-touching compound props and moving residents are
  explicitly protected. Its layer blocker composes with PASSAGE instead of
  allowing either zone to restore the other's hidden geometry. Same-build
  controls are 26.735/26.252 ms versus 22.870/22.794 production: **26.494 ->
  22.832 ms (-3.662 ms, -13.8%)**, with mean calls **11,873 -> 9,433
  (-20.5%)**. Exact production A/A/B frames at three street viewpoints live
  in `art/renders/street_core_geometry_t7c/production_pair/`; entry, windows,
  neon and facade architecture remain intact. `StreetCoreVisibilityTest`
  passes 16/16, including direct STREET/PASSAGE transitions. That pass appeared
  to leave a 6.23 ms gap, but T7d found both the final ownership leak and a
  benchmark-window defect. The approved Harukiya mass is a second F01 interior
  at x -12.0..6.4 / z 28.32..38.2; T7c's central rectangle never owned it.
  A dimensioned second prism now gates its 264 enclosed draws while retaining
  the street face and restoring exact layers on the descent into the bar.
  `StreetCoreVisibilityTest` passes 20/20. T7e batches each neon letter's fixed
  tube/support/boot primitives per finish without merging the letter animation
  unit: the focused proof is 285 -> 51 draws, exact AABBs and working drop/
  restore; the street census moves the Orison blade 202 -> 46 and tenant sign
  98 -> 20 visible objects.

  `WeatherPerf` now warms 120 frames and reports both direct wall-clock time
  and Godot's rolling FPS monitor. At 30 frames the monitor still included
  startup/shader history, so the absolute 22.832 ms T7c remainder was not a
  settled frame; its same-build relative improvement remains valid. With both
  new retained controls on, fresh direct clocks are 17.850/17.649 ms; production
  is **15.905/15.530 ms** (mean **17.750 -> 15.718, -2.032 ms / -11.4%**),
  objects 6,743 -> 5,554 and calls 7,938 -> 6,481. The independent rolling
  monitor also passes at 16.035/15.950 ms. Exact three-view proof lives in
  `art/renders/street_harukiya_t7d/production_pair/` and
  `art/renders/street_neon_batch_t7e/`. The real playable street therefore
  clears 16.6 ms with **0.88 ms direct-clock headroom**; T7 is closed.
- **T8 DONE.** `design/ORISON_DRIVING_RAIN_SKY_PROPOSAL.md` §17 records the
  production checkpoint: one geography-locked four-state storm family, slow
  lower cloud inside the existing sky draw, bounded middle-distance fog, one
  batched realistic rain draw, roadway mist, one synchronized hidden sky key
  and restrained cloud-light fingers. Twenty before and twenty final frames
  plus a fixed-camera cloud-motion pair are under
  `art/renders/weather_sky_t8`. The real-pavement control measured the weather
  below the +0.8 ms contract; WeatherSkyTest 31/31, containment, route,
  lighting, Passage ownership/visibility and WalkTest FULL all pass. Street
  ends, traffic `MAX_WAIT` / `GAP_SECONDS`, the three-zone map and one-light
  budget remain unchanged.

## P2 — The Passage (rehousing the shops)

Ruled as M0.5. Build drawing and measured baseline:
`design/FINAL_MAP_REDESIGN_BRIEF.md`. All eleven shops move. Code is `passage`;
fiction remains “the Vantry Arcade.” This supersedes R2's street re-plan: they
are two answers to the same problem and only this one is built.
- **PS1 DONE.** Check 3 fixes the exact portal, throat, expansion line and
  20 × 26 m hall in `art/renders/map_check3/passage_top_down.*` (`3153ed0`).
- **PS2 DONE.** The obsolete street parade is the isolated rollback commit
  `e102a41`; Phase 3 immediately rehoused all eleven identities in the Passage.
- **PS3 DONE.** Glass barrel vault, iron ribs, eleven units and a six-metre
  terrazzo aisle are built. Phase 5 adds eleven brass threshold nosings, paired
  edge drains and cart-specific wheel wear as three gated finish draws.
- **PS4 DONE.** Three loaded 1920s handcarts form the movable middle layer.
  They are real 46 kg rigid bodies, shoveable by player contact or `[E]`, and
  freeze with their collision disabled whenever STREET owns the frame.
- **PS5** **Carrying changes crossing.** The keystone of the loop: a crate slows
  you, blocks sprint and sits low in frame, so the return leg of an errand is
  harder than the outbound. Wires the Passage directly to section T with no UI.
- **PS6 DONE.** At canonical 03:00, ten ordinary units are dark behind
  source-positioned sliding iron lattice grilles and all three public
  handcarts are frozen behind visible frame chains. HARDWARE PAINT is the one
  night-service exception: Mina's proved maintenance shift buys the carbon
  transmitter capsule there, so closing it would break the full loop. From
  06:30 to 02:00 all eleven circuits return, the grilles fold against their
  piers, their collision disappears and the carts are released. The complete
  state is three bounded MultiMesh draws plus ten real barriers; shopfront
  coordinates exist only as `passage_shop_hours` generator markers.
  `PassageHoursTest` (15/15), Passage navigation/entry/visibility/ownership,
  LightingAudit, GoldenLoopTest (65/65) and WalkTest FULL all pass. Canonical
  before/night/day renders and the same-build focused performance control are
  in `art/renders/passage_hours_ps6/`.
- **PS7 DONE.** Eleven source-owned shop batches import as 263 bounded local
  draws; NEWS CIGARS keeps its inaccessible proprietor side. PassageVisibility,
  PassageNav and ShopEntry all pass on the rebuilt geometry.
- **PS8 DONE.** The real player now walks one deterministic reversible route
  ORISON → STREET → PASSAGE → HARDWARE PAINT customer floor. Passage owns F01
  without submitting the apartment stack, non-Passage F01 actors or 170 foreign
  site draws; the vertically bounded gate keeps the aerial street station honest.
- **PS9 CLOSED 2026-08-14 — owner accepted the measured blocker, and M0.5 is
  COMPLETE.** `ab120dc` is the final production checkpoint. The acceptance was
  earned, not resigned: shadows, prop ticks and submission were each attributed
  and their ceilings measured (brief §10aj–§10an); three ownership leaks were
  found and fixed for −3.1 ms at northbound; and the exhaustive remaining
  ceiling proves no candidate flips the station within the approved
  constraints. Northbound stands ≈17.8 ms against the unchanged 16.6 target —
  **≈1.2 ms over, at canonical pinned night, which is now the authoritative
  benchmark state** (perf_probe pins DAYNIGHT=0; historical interior numbers
  are DAYTIME and must not be compared against canonical-night runs). The 9 m
  shop-batch contract stays enforced — it protects local light selection and
  bounded AABBs — and **cross-shop batching is deferred to project-wide P1**,
  where it requires its own visual, lighting, culling, ownership and
  interaction proof. M1 may begin.
- **PS10 DONE.** WalkTest FULL is a fresh PASS in 48.3 seconds at x8 / 480 Hz.
  Physical walks and shared-elevator contention run before the harness pauses
  unrelated resident routines for the stateful Case 02–08 batch; case order,
  timers and consequences remain intact.
- **PS11 K1 PHYSICAL DIORAMA DONE.** Redesign the jarring STREET → PASSAGE gate under
  `design/VANTRY_GATEWAY_AND_SUBWAY_PROPOSAL.md` and
  `design/VANTRY_SUBWAY_KIOSK_PROPOSAL.md`. Gate A's reversible host/kiosk
  blockout, K0 historical exterior and K1 shallow stair now pass their exact envelope,
  visible-collision, ownership, route, FULL-walk, seven-view render and
  same-build performance controls (§§14–15). K0 replaces the stepped shell
  with iron panels and wire glass, adds unlit `EXIT` / `RAPID TRANSIT`, reuses
  the same two lights, and fixes the east approach's actual black owner: the
  unfinished outward face of `EastSouthWorks`, not the kiosk. K1 cuts only the
  approved kiosk footprint and adds eight real treads, a 1.05 m clear stair,
  tiled cheeks and turn, iron rails, lower landing and a finite dark terminus.
  Its exact source/runtime proof, eight-view dry/weather render set, FULL walk
  and same-build performance control pass in proposal §16. Sound/reflected
  train light remain optional later gates; the next map/environment package is
  T8. A station, cutscene, route, interaction or fourth zone remains rejected.

## F — Film (projectors instead of televisions)

Proposed in `design/ORISON_PROJECTOR_BRIEF.md`. **Not canon until the owner
rules its five open questions.** Nothing built.

- **F1** **CLOSED 2026-08-11 by the owner, on the evidence of the render.** The
  watermark is no longer legible once the plate pass and the long exposure are
  on it: the mark was always low-contrast and soft, and an image compressed to a
  mirror's tonal range, smeared across a two-second exposure and eaten from one
  corner by mould does not leave it anywhere to be read. Three attempts to MASK
  it all failed - crop, growing burn, placed burn - and the thing that beat it
  was not aimed at it at all. Re-render remains the clean answer if the clips
  are ever regenerated for other reasons; it is no longer blocking.
- **F2** Owner ruling on the brief's §7. 7.2 changes the most: the footage is
  vertical and a 16 mm gate is landscape. Ruled in principle - "let the gate be
  the wrong shape" - but the crop numbers above are now evidence for how much
  frame is available either way.
- **F3** **Re-curate against motion, not frames.** The twelve in the brief's §5
  were picked from ONE frame each, and the clips turn out to be multi-shot
  montages: `ch_36` opens on a colonnade and resolves into a title card reading
  ALEXANDRA OF MACEDON / INSPIRED BY TRUE ACCOUNTS - a trailer, not a landscape,
  and an automatic cut. `ch_19` leaves the water for a snorkeller at sunset,
  `ch_07` leaves the snow, `ch_24` ends on blown white. Five-frame strips for
  the shortlist exist; the selection has to be redone against them, and the
  brief's §5 table should be treated as a first pass that has already been
  partly falsified.
- **F4** **DONE.** `ProjectorProp` **extends** `TVProp` rather than replacing
  it, so `BroadcastDirector.sets`, `set_glow()`, the resident routines that
  switch one on like a person and the poltergeist that takes them all keep
  working untouched - none of that vocabulary ever cared whether the picture
  lands on glass or plaster. The inherited `glass` quad is now the LENS, so
  `_refresh()` lights it on power for free. **The wall is found, not authored**:
  the machine rays along its own facing and puts the image where it lands,
  sized by throw, so moving a projector moves its picture and one aimed at
  nothing stays dark. Each arrives with a reel already in the gate, picked
  deterministically per unit.
- **F4b** **Body built and the reels turn.** ~30 primitives: cast foot on two
  pads, a broad column, mechanism and lamphouse with six vents and a chimney,
  lens barrel with a brass focus collar, gate and two film rollers, speed knob,
  switch, crank stub, both reels on struts with flanges and a dark wound band,
  and cloth-braided flex. Procedural like the lamps rather than a Blender
  assembly, which is a deliberate match to `lamp_prop.gd` - revisit only if it
  needs to appear in the prop warehouse.
- **F4c** **CLOSED by ruling 2026-08-11: few machines, never two in a room,
  never moved.** Both risks were about crowding and mobility and neither can
  occur. The found-wall throw stands as-is.
- **F14** **Four projectors, all in case flats** - 2A Mina, 3B Omar, 5B Cal,
  6C Mae - plus the player's own in 4B. **The rule is that the machine is only
  in the flat of someone the building is currently about**, which makes it an
  instrument rather than an appliance and means finding one running is always a
  sentence. Nine was a television number; a 16 mm projector in a 1928 tenement
  is a middle-class machine in a working-class flat and every one has to be
  explicable.
- **F15** The Harukiya's karaoke set stays a **television** - the last one in
  the game. People sing at a screen, nobody sings at a wall, and a projector in
  a bar would fight the room's light all night.
- **F16** **The haunting no longer reaches through sets, and that needs saying
  in `poltergeist_library.gd`.** Its header still calls broadcast "the
  instrument closest to hand: every set in the Orison", which was true when
  every flat had one murmuring. With five machines that will not carry a
  haunting, and it does not need to - the Tenant's body is the acoustic graph
  (III.1), so pipes, wiring and lights reach every room. A rare projector
  threaded with a reel nobody loaded is a LOUDER sentence, not a weaker one.
  WalkTest's assertion has already been re-aimed to guard existence rather
  than reach. 16 mm Kodascope, not 9.5 mm Pathé
  Baby - 9.5 mm was chiefly France and Britain, 16 mm is what Americans used.
  **The screen is no longer part of the prop; the image lands on the room's own
  plaster** and breaks over corners.
- **F5** **DONE in first pass** - `game/shaders/projected_film.gdshader`, with
  `tests/FilmLookShot.tscn` to photograph it. `blend_add` is the load-bearing
  choice: a projector ADDS light to plaster and cannot make it darker, so black
  in the film is simply the wall, and the room has to be dark for the image to
  read. Carries gate weave, 17 fps silent flicker, additive grain, dust,
  falloff, **cigar burns** (the changeover cue - four frames, top corner) and
  **film burn** (ring, scorch, bare lamp). Still to do: wire it to a
  VideoStreamPlayer texture rather than a still, and drive `burn` from reel-end
  and from the Tenant.
- **F11** **THE PLATE, and it is the headline.** Ruled from Niepce 1826 /
  Cornelius 1839: the target is a long-exposure plate, not 16 mm. Built in
  first pass - `plate`, `tarnish`, `plate_lift`, `plate_warm/cool` in
  `projected_film.gdshader`. Tonal compression to a mirror, pewter duotone, and
  damage IN FRONT of the image (blotch, sparse wipe streaks, flecks, edge rot).
- **F12** **The long exposure is the mechanism and is NOT built yet.** Accumulate
  the video ~1-2 s so movement smears and only still things resolve - a walking
  figure loses their head. **Reuse `ArcadeMachine._build_phosphor()`**: same
  SubViewport + CLEAR_MODE_NEVER + low-alpha black rect, with the decay turned
  right down. Do not write a second accumulator. Previewed with ffmpeg `tmix`
  and it is the whole effect.
- **F13** **Reconsider the machine: magic lantern, not Kodascope.** A lantern
  projects glass slides, is older than film, is domestic, and matches "some
  forgotten past". Reels become slides in paper sleeves - a better collectable -
  and a slide that is not supposed to move at all, moving, is the horror.
  The 16 mm research stays on file if motion is preferred to breathing.
- **F5b** The projected-look pass, remaining: gate weave first (it does more than anything
  else), 16-18 fps silent flicker, sparse dust, a splice jump every 20-40 s,
  falloff and keystone. The projector is also a LIGHT - a flickering beam that
  puts the player's shadow inside the picture.
- **F6** Silent, with a mechanical clatter loop. The clips lose their audio,
  which is the point: **a film that has always been silent suddenly having sound
  is the Tenant** (III.1).
- **F7** Reels as found objects. Every projector arrives with one already in the
  gate, so nine machines seed nine clips and teach the system without a tutorial.
  Collection is global. **No completion reward** - if the set needs a prize, the
  reels were not interesting enough.
- **F8** `BroadcastDirector` inverts: it shuffles 37 clips today; under reels it
  plays what the player chose from what they found. The shuffle survives only
  for the Tenant, which is the difference between the machine you run and the
  machine that runs itself.
- **F9** Carry `WalkTest`'s `sets >= 8` duty across to projectors rather than
  deleting it - it is a floor on the haunting's reach, not a prop count.
- **F10** Re-examine the nine `TV_UNITS` reasons. Some survive the change and
  some do not: Teresa's set "runs for company while she sleeps" cannot, because
  a projector cannot be left running unattended.

## Q — The hand

- **Q1 SUPERSEDED 2026-08-15.** The owner rejected both the phone and the plain
  torch: Bible §VIII.5.j now rules a no-screen Vantry service radiophone with an
  attached work lamp and one amber ORDER jewel. Execute
  `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md`; do not make a modern radio or a
  military prop.
- **Q2 DONE 2026-08-15.** The carried beam is ordinary warm tungsten; the modeled
  lens, beam origin, cull mask, carry pose and falloff agree. **L** operates both
  the real light and its physical lever/rear LAMP jewel.
- **Q3 DONE.** Every `PhoneCarrier` / `Phone3D` / `PhoneOS`, camera-roll and
  cart-app consumer is classified in `game/docs/service_set.md`. Production
  instantiates none of the three; their source remains as measured history.
- **Q4 DONE.** `PlayerController` owns the device-neutral carried-light contract;
  `ServiceSetCarrier` carries a modeled, no-screen service set with no viewport
  inside the prop. Four proof views live in `art/renders/service_set_q4/`.
- **Q5 DONE.** ORDER reads the aggregate open-work state and never owns or
  advances lifecycle. Reported/discovered work and persistence remain owned by
  `WorkOrders` and are covered by their existing focused tests.
- **Q6 DONE.** The owner-approved rear green NET and red LAMP jewels report only
  the physical **R** radio/aerial and **L** inspection-lamp circuits. **E** is the
  universal world verb: seats release on a second press, and all 203 functional
  interactables (including 18 refrigerators) now own a reachable ray target.

## X — The haunting

Audited in `design/ORISON_HAUNTING_AUDIT.md`. Measured, not opined: the
instinct that something in here does nothing was right, but it is not an idle
system - **it is more than half the authored content.**

- **X1** **DONE - regated.** 0.12/0.34/0.62/0.86 became 0.10/0.24/0.40/0.62.
  The ordinary state of this game is **0.23 pressure**, and rung one is defined
  as "an anomaly small enough to be dismissed" - so every player not deep in a
  late campaign met this system *only* as things they were meant to dismiss,
  while `reenact` (47 acts) and `address` (18 acts) went unseen. **54% of the
  content was behind a wall.** A live case on a call now reaches reenact.
- **X2** **DONE - being ignored is the steepest term.** `_ignored_streak` went
  0.06 -> 0.14. It was worth less than standing still, which had the model
  backwards: every other term rewards a player already paying attention, and
  this is the only one that represents the building INSISTING. It is also the
  fairest curve here, because it escalates only for players who are missing
  things and resets the moment one lands.
- **X3** **Rebalance toward the undeniable.** 56 of 120 act slots (47%) are
  whisper, caption or sound; the acts that cannot be missed - vanish, fall,
  scatter, fault - are **7 of 120, under 6%**. Do not delete whispers; require
  that **every rung-3 and rung-4 entry contains at least one physical act.** A
  reenactment made of sound is a radio play.
- **X4** **Trim 18 ladders to 8.** `PoltergeistLibrary` serves a cast that was
  cut two-thirds away: §IV.1 ruled six cases plus Rhea and Nadia as sanctioned
  expansion, and under §III.1 the Tenant attaches to a CASE - so ten ladders,
  **40 act slots**, belong to residents who cannot be haunted. **Archive, do
  not delete**: it is good writing and two are already the expansion.
- **X5** `appliance_fit` is implemented and unreachable from any ladder. Wire
  it or cut it.
- **X6** Left alone deliberately: `DomesticWitnessSystem` and
  `BuildingPersonalityDirector` both looked like trim candidates and neither is.
  The witness clocks are per-apartment character objects and the personality
  director is what stops this being a random-number generator.

## N — The dream (narcolepsy maze)

The owner ruled the core function on 2026-08-13: narcoleptic onset, a terrifying
dark scramble and waking in 4B are part of every case loop. On 2026-08-15 the
owner approved the complete production design and clarified that dream secrecy
applies to the **title screen only**. N2's dimensioned ten-module substrate is
closed at `art/renders/dream_maze_n2/README.md`: 100/100 deterministic seeds,
seed-independent diversity measurement, 18 live provenance checks and 0
unresolved. K7's source-backed loop contract is closed in
`game/docs/core_loop.md`; dream design did not silently close it.

- **N3 DONE 2026-08-15.** The disposable 42.00 × 3.20 × 3.00 m control corridor
  closes Gate B without becoming production maze art. Eleven paired fixed seeds:
  lamp-on median 3.425 s, lamp-off 11.358 s, extinguished after acquisition
  11.225 s — **69.8% shorter** with light on and **7.800 s bought** by switching
  off. Real opaque collision blocks acquisition; an open end permits it;
  darkness never creates an indefinite safe state. Keyboard L, controller left
  shoulder and touch LAMP share `PlayerController.toggle_lamp()`. The diagnostic
  capsule casts shadows only and never renders in beauty. Proof, raw CSV and the
  exact drawing: `art/renders/dream_light_n3/README.md`.
- **N6** Implement the Mina maze profile using one invisible navigation body and
  a shadows-only borrowed silhouette. No monster mesh, face, attack animation,
  teleport, case-specific director or new Tenant.
- **N7** Implement Mina's three audible hazards—lift void, Vantry signal trunk
  and hollow runner—and prove bearing/type identification before contact. The
  five later hazards remain data sockets until the first run passes.
- **N8** Close the production Mina passage: 14–28 seconds, complete K6 state in,
  capture/fall/contact out, rebuilt waking scene, authored 4B bedside, existing
  factual refrigerator residue, accessibility variants, renders and 16.6 ms
  isolated-scene gate.
- **N9** Use Peter as the shared-profile proof. Change content, pursuit grammar
  and case truth without forking the maze, director, hazard or save owners.

## M — Materials and textures

- **M1** Supertiles and stable per-wall UV offsets. Explicitly **not** part of
  the plaster repair, which was fixed without them — an optional later
  anti-repetition enhancement, with a real VRAM cost to decide first.
- **M2** `family_mean_spread` is defined on the compiler side but has never run:
  one texture per material means no family to compare. If the planner ever emits
  texture variants, that gate is unexercised.
- **M3** Compiler textures are 128² at roughly 64 px/m, which is the deeper
  reason features come out large relative to the tile.

## C — Cast (ruled 2026-08-10, ORISON_BIBLE §IV.1)

Six residents carry cases: Mina, Peter, Juno, Cal, Omar, Mae. Rhea and Nadia
are the sanctioned expansion. The other twelve are case-less, **not absent** —
they keep their door, schedule, mailbox and place in the web.

- **C1** ~~Six bespoke case minigames.~~ **Superseded 2026-08-10:** the target
  is a mechanism, not a minigame — see `design/PROP_ACTIVITIES.md` §2. Cases
  express through objects you handle, not through bespoke rules modules. What
  each of the six cases *does* still needs deciding, but it is hours each rather
  than days.
- **C2** Per-resident data is built for 3–5 of the cast on most axes (hero
  models 5, life profiles 3, decor 3, wall art 3). Only animation profiles are
  complete at 18. Decide whether the case six get finished first.
- **C3** The twelve case-less residents need a defined minimum presence — door,
  light, schedule, signature sound, mailbox — so "case-less" reads as a person
  without a chapter rather than an unfinished resident.

## L — Light and decay

- **L1** Bulb burnout and renewal (`design/PROP_ACTIVITIES.md` §4). The
  mechanism is small; the design is the three fixture classes — yours, theirs,
  and the ones that never come back on — and a rate set slightly faster than a
  shift can clear.
- **L2** Bulbs onto the bodega shelf beside the valves, sharing the studio
  chore's errand. One trip, two reasons.
- **L3** Let the infection blow bulbs, so the permanent dark follows the active
  case rather than being tuned by hand.
- **L4** Check `LightRig`'s per-storey budget against fixtures going dark. Should
  be performance-positive, but it was written when the cap was 16 and wants
  re-reading rather than assuming.

## U — Unused and dead systems

From `design/AUDIT_UNUSED_SYSTEMS_REPORT.md` (AUDIT 2, run 2026-08-10). **That
document is the evidence — method, confidence, negative controls. This is the
queue.** Both P0s in it are already repaired: the monitor/signal-terminal split,
and the four isolated roof fixtures now terminating at a real riser.

- **U1** `B1_ROOM0_DOOR` is built data no runtime path reads — a control that
  silently controls nothing. **Owner fiction ruling required:** make
  `Room0.setup()` consume it as the threshold anchor, or remove it at the
  generator and state that Room 0 has no basement entrance. *The audit is
  explicit that deletion must not be chosen silently.* The dream brief does not
  need it either way: that entrance is not physical.
- **U2** `creature_index.json` and the harpy/oni assets — 6.2 MB, zero
  references, and the owner has ruled they are not in the cast. **The audit
  blocked this on the dream ruling; that blocker is now lifted** — the dream's
  antagonist is shapeless and drawn from `PoltergeistLibrary`, with no model,
  rig or animation, so nothing in it reintroduces them. Remaining question is
  only whether to delete or move them outside `game/` so `all_resources` cannot
  package them.
- **U6** The `smoke_detector` alias class has no reference of any kind, but
  external saves may name it. **Decide save compatibility before touching it.**

## P — Performance

- **P1** **Every station is over the 16.6 ms frame target**, all eight, measured
  2026-08-10 at 1440p. **DAYTIME NUMBERS (labeled 2026-08-14): the benchmark
  was unpinned until `ab120dc` and these ran in daylight; canonical pinned
  night is now authoritative and runs heavier at interior stations (harukiya
  3,975 objects by day, 7,662 by night on one build). Do not compare these
  directly with canonical-night results.** Cross-shop batching of the Passage
  hall stock is deferred INTO this project-wide item from M0.5 (owner ruling
  2026-08-14) and requires its own visual, lighting, culling, ownership and
  interaction proof; the 9 m per-buffer contract stands meanwhile.
  Worst is the **atrium eye at 42.05 ms** (27.8k objects,
  38.8M primitives) - it sees seven storeys at once and is the only station over
  40. Then street elevation 32.39, lobby 31.68, corridor F04 29.01. Mean **28.66
  ms** across the seven original stations.
  *This supersedes the 46.25 ms mean in `design/SHOP_INTERIOR_INVENTORY.md`,
  which predates the door-streaming pass; the street alone went 47.11 -> 32.39.*
  So the gap is about 1.7x, not the 2.8x first filed - real, but a third smaller
  than the record said, and concentrated in one station rather than spread evenly.
  **Start at the atrium.**
- **P2** **The atrium decomposed, 2026-08-11.** `PERF_DIAG_ONLY=1
  PERF_DIAG_STATION=atrium` runs it. Absolute times swing more than 2x between
  runs on the same machine and the same build, so read proportions, not
  milliseconds. Consistent across four runs:

  | toggle | frame time | object submissions |
  |---|---|---|
  | baseline | — | 27.4k |
  | all light shadows off | −11 to −19% | 24.2k |
  | all illumination hidden | −9 to −20% | 22.9k |
  | all geometry `cast_shadow` off | −24 to −38% | **4.3k** |
  | **all functional props hidden** | **−41 to −63%** | 6.3k |
  | **props drawn but not ticking** | **0%** | 27.3k |
  | props culled past 12 m | −15% | 25.0k |
  | every prop batched by material | ~0 | 26.4k |

  **It is CPU-bound, and the GPU is asleep.** Watched from outside with
  `nvidia-smi` during a run, the RTX 4080 sits at **210–1200 MHz of 3105**, 12–38
  W, 19–52% utilisation, 45 °C, through an 80 ms frame. Nothing here is a
  shader or fill-rate problem, and the 2x run-to-run swing is CPU contention,
  not thermal.

  **Four things are ruled out**, each measured rather than argued:
  - **User prop scripts are not the cost AT THIS STATION.** *Amended
    2026-08-13 by owner ruling: this is an atrium/street finding, not a
    building-wide law. The same harness at the ROOF makes silencing ticks
    worth −47%, the largest lever there. Read the four bullets below as
    scoped to stations that draw a lot; see §P6.* Silencing all 384 `_process`
    callbacks while leaving every prop drawn changed nothing. *Do not read the
    `proc` column as script time - it is TIME_PROCESS, the whole process step
    including engine submission, and misreading it cost an hour.*
  - **Batching is worthless as implemented.** Merging every prop in place
    removed 2342 meshes and moved submissions 27.4k → 26.4k. Only 22 of 56 prop
    scripts call `merge_static()`; finishing that job would buy nothing.
  - **Prop LODs are worth much less than they look.** Culling past 12 m recovers
    15% against 63% for hiding props outright, so the cost is the props **near**
    the camera, not the seven storeys overhead. The station comment ("sees seven
    storeys at once") has been misleading the diagnosis for a long time.
  - **Lighting is a minor term.** All shadows off, or all lights hidden, is
    worth under a fifth.

  **What is left is engine-side submission of prop geometry**, and the one lever
  that moves it is shadow casting: `cast_shadow` off across all geometry cuts
  submissions by **84%** (27.4k → 4.3k) for 24–38% of the frame. A policy of
  "small props that sit on surfaces do not cast" is the first cut. It is a
  **look** decision as much as a performance one, so it wants before-and-after
  shots in front of the owner rather than a unilateral change.
- **P3** Every figure here comes from one RTX 4080, which never leaves idle
  clocks during the benchmark. Mobile is unproven and the only export preset is
  Android - where the CPU-bound conclusion is worse news, not better.
- **P4** **The budget being measured is not the one documented.**
  `light_rig.gd:135-156` sets desktop to UNLIMITED (4096) / SHADOW_N (32) and
  honours `LIGHT_BUDGET`/`SHADOW_BUDGET`, then `building_root.gd:344-351` calls
  `set_budgets(...)` immediately after `add_child`, clobbering both.
  README:531-533 documents unlimited/32. ~~Play runs 14/8.~~ **CORRECTED
  2026-08-13: play runs 16/16.** `building_root.gd:344` is an if/else and
  `game_boot.gd:20,22` default `launch_mode` to CINEMATIC and `quality` to 0,
  so line 348 `set_budgets(16, 16)` is taken and the 14/8 at line 351 is
  unreachable; only `free_cam`, `lighting_debug_test` and
  `warehouse_teleport_test` set DEBUG, so no test escapes it either. WalkTest
  FULL prints "the nearest 16 of 104 eligible fixtures" and "circulation
  fixtures hold the budget (15 lit)", and 15 lit cannot happen under 14.
  `bcd6450` (2026-08-02) added the CINEMATIC branch and orphaned the else.
  Every perf comparison must pin this — at 16/16 — and the `LIGHT_BUDGET`
  sweep documented as the regression method does nothing in play. Worth
  fixing first: nothing prints the resolved budget, which is the whole reason
  a wrong number survived in three documents.
- **P5 CLOSED — FALSE POSITIVE 2026-08-14.** `project.godot:60` does leave
  occlusion culling enabled while the production tree contains exactly zero
  `OccluderInstance3D` nodes, but the assumed empty-pass cost is not measurable:
  current canonical-night street runs were 28.79/29.08 ms enabled and 28.79 ms
  disabled with `PERF_OCCLUSION_OFF=1`. Render populations drifted between the
  enabled controls, so even the 0.29 ms spread is noise rather than a saving.
  Godot short-circuits the empty system; the setting and WalkTest contract stay
  unchanged, ready for a future proved non-self-occluding solution. Also found:
  this Compatibility backend collapses `Viewport.get_render_info` calls into
  VISIBLE and reports zero SHADOW calls. `SubmissionCensus` now labels that as
  unavailable instead of claiming a false pass reconciliation.
- **P6** **P2's "user prop scripts are not the cost" is station-specific, and
  false at the roof.** Measured 2026-08-13 with the same harness: silencing all
  384 `_process` callbacks while leaving everything drawn is worth ~0% at the
  atrium and the street, and **−47% at the roof**. The roof draws 2,535 objects
  — half the harukiya's — and still misses budget at 20.41 ms. Where there is
  much to draw, submission dominates; where there is little, ungated per-frame
  work does. Gate prop ticking and `StreetTraffic._process` on visibility.
- **P7 DONE 2026-08-14.** `_update_floor_visibility()` now packs every derived
  Passage/atrium/exterior/all-floor and per-storey shell/actor answer into one
  exact region signature. Stable movement checks eight elevations and skips the
  old ~614-prop / 120-door scan; crossing any real boundary or changing
  `show_all_floors` reapplies immediately, while explicit diagnostic calls still
  force the gate. The production-scene microprofile is 0.003 ms/signature versus
  0.207 ms/full scan (0.204 ms avoided per stable physics tick). Same-build
  `PERF_VISIBILITY_CACHE_OFF=1` is the retained control. PassageVisibility 35/35,
  FinalMapRoute both directions, and WalkTest FAST/FULL x8/480 pass. The noisy
  28.79/29.58 ms street frame pair is only corroboration, not the attribution.
- **P8 PARTIAL 2026-08-13.** The original system was one storey-granular gate,
  not configurable streaming. M0.5 adds a real PASSAGE ownership envelope: F01
  hosts the hall while F02–ROOF, non-Passage actors and 170 foreign F01 site
  draws stay out of its frame; the separate STREET portal proxy stays eligible.
  ORISON room streaming, HLOD, distance LOD and notifier-based gates still do
  not exist. This is one proven zone boundary, not a general streaming system.

## I — Prop and set interaction review / the service wire

Owner ruling 2026-08-15; design contract in `design/PROP_ACTIVITIES.md`,
“THE SERVICE WIRE ANSWERS BACK.” This is a deliberate production pass, not a
license to add collision and popups to every wall panel. It enters the queue
after the currently sequenced dream work unless the owner explicitly promotes
it.

- **I4 — Complete the physical response pass.** For every matrix row not marked
  ambient, make E answer appropriately. OPERATE receives a reversible mechanism
  and authored click/clunk/scrape/hum; INSPECT receives a restrained close-look
  or material/audio acknowledgment; RESIST-REFUSE receives a visible/audible
  attempted action and specific reason. Preserve existing authoritative owners:
  the presenter may read refrigerator state, for example, but never open the
  door itself. No silent prompt, silent failure or generic animation pasted
  across unrelated mechanisms.
  - **LANDED 2026-08-15:** the first dishonest-silence batch now answers
    (F03 utility latch, chained Passage carts, busy toaster and jobless HARDWARE
    PAINT counter). The laundry batch follows the actual machine: five separate
    washer controls plus the airer cleat and a non-operating rinse inspection.
    All five task lamps now have a local key that the central LightRig cannot
    turn back on or charge against the active-light budget while open.
    All five line-fed picture receivers now operate their tuning knob while
    preserving the case-bearing signal instead of offering a false power cut.
    All 24 baked close-coupled closets regain one record-aligned cistern handle,
    one water cycle and truthful FULL/REFILLING copy without duplicating the
    porcelain floor geometry.
    All five baked valve radios regain a local knob, click, quiet programme bed
    and reversible power condition; case-anomaly props remain separate owners.
    All 21 wardrobes now own their actual paired doors at runtime. The rebuilt
    floor glTFs contain a hollow cabinet, rail and non-loot resident garments,
    but no duplicate baked leaves; E opens/closes both textured leaves with a
    creak and resident-private copy. The closed/open production pair lives in
    `art/renders/wardrobe_split_i4/`.
    The Harukiya jukebox now has separate selection-bank and coin-return ray
    owners, moving controls, sign response and a local spatial pickup cycling
    three shipped bar records. Its return stops only the cabinet; it never
    borrows the unlocatable WORS emitter.
    All 18 case-driven domestic clocks now own a neutral close inspection:
    the glass answers with a local tick and movement, while owner-result copy
    reports only visible live/disturbed condition and never prints a resident,
    case id, tell or solution. The lobby notice board and original Orison
    broadside likewise own one assembly-level target each, with a pinned-sheet
    or brass-fastener response instead of child collisions over every notice.
    The maintenance headquarters case wall now has one exact wall-sized target,
    a brass acknowledgement and live residue count; its slip explicitly says
    REVIEW ONLY and cannot advance an order or duplicate RealityCases state.
    `ServiceWireResponseTest.tscn` is the focused proof. I4 remains open.
- **I5 — Set-piece coverage.** Audit the eleven Passage shops, lobby/service
  desk, basement plant and laundry, representative apartments, roof, street
  furniture and the service set in hand. Give foreground ledgers, counters,
  crates, repair plates, machines and hero dressing an inspect/refusal contract
  where movement would be dishonest. Repeated architecture, inaccessible trim,
  rain dressing and bulk shelf stock stay ambient and must be explicitly counted
  as such rather than quietly omitted.
- **I6 — Deterministic proof gate.** Add a production-scene audit that fails on
  any registered E target without a valid card, any non-ambient matrix row with
  no reachable collision owner, any OPERATE row with no observable before/after
  state, or any RESIST-REFUSE row that returns silently. Prove all 18 fridges
  open and close, seating still releases on the second E, gameplay-bearing props
  preserve their existing transitions, and saved state reconstructs the correct
  condition line. The audit prints coverage by class and by zone with zero
  unattributed foreground heroes.
- **I7 — Render, usability and performance gate.** Produce paired captures in a
  kitchen, Passage shop, lobby, basement and street at 16:9, ultrawide and touch
  scale, including rapid interaction replacement and a long localized line.
  Prove the card never obscures the crosshair/interaction target or protected UI.
  The content library and areas add no per-frame prop callbacks; profile the
  presenter closed, visible and rapidly replaced. Run one Godot at a time under
  60 seconds: focused interaction audit, service-set test, maintenance counter,
  relevant case tests and WalkTest FULL x8/480. Document and commit the matrix,
  research ledger, data, code, captures and exact result before closing I.

## H — Housekeeping

- **H2** **`C:\FPSengine01` is not a git repository.** The entire compiler side —
  the world compiler, the providers, the arcade catalog build, the texture
  validation — is unversioned files on disk. `git init` and a first commit.
- **H3** `worldc clean --stale` has no test covering it.
- **H13** **Logical placement audit.** Is each object placed correctly, and does it belong there. Convention traps are listed in the brief (door markers are the hinge jamb; pendant markers are ceiling anchors with a drop). Note placement cannot lean on the router to prove a route is clear — see R6, residents walk through furniture. Brief: `design/AUDIT_BRIEF.md`.
- **H14** Doc/code drift on which shops keep the light on, three answers in
  three places: the build guide says four trades (laundry, diner, news,
  druggist awning) at `SHOP_INTERIOR_BUILD_GUIDE.md:37-39`;
  `gen_layout.py:4272-4274` gives leaf `open` to laundry and diner only,
  `locked` to news and `closed` to the druggist; and a third set (laundry,
  diner, news, pawn) drives the brighter lamp energies at `:4399`. Pick one.
- **H15** `shop_entry_test.gd:327-335` proves the NEWS & CIGARS proprietor
  restriction against **hardcoded world coordinates** (8.925 / 9.72, z
  26.85..30.45). Move that shop a metre and the assertions quietly become
  tests of empty pavement instead of failures. Re-anchor them to the marker.
- **H16** `SafetyNet.exempt_zones` is populated only inside the DEBUG-launch
  branch (`building_root.gd:452-461`), where `PropWarehouse` registers its
  hall. Any playable volume added outside the site box reaches release with no
  exemption and is rescued out of — the failure reads as a dead teleport,
  which is exactly the bug the comment at `safety_net.gd:33-38` records.
