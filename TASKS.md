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
  pipelines. **Default applied 2026-08-21 under the rule-of-cool licence:**
  the ingest's flat-surface check is now RELATIVE (range / mean ≤ 0.065). It
  had never been run against the shipping cellar concrete (6.0 % — stains and
  patches that are the material) and refused it the first time the source
  changed; plaster sits at 0.7–1.0 %. The owner may tighten the number.
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

- **G1 LOCAL CONTRACT LANDED 2026-08-15; the shared side remains.** The ruled
  III.2 split is now enforced where it exists: `SongResource.return_ratio`
  (data-tuned, > 1.0, default ×1.335), stored immutably as
  `reconstruction_ratio` on every kept version, and READ IT BACK auditions the
  composite recipients get — backing + vocal varisped together, no guess, no
  wow, one bus (`SongbookTest` proves all of it). `PhonautogramReader`'s
  fresh-guess reader now serves found traces only. What G1 still needs is the
  cross-player delivery of versions — that is G2's reframe plus G6a's gates,
  not more local playback work.
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
  This is now a direct A/B by ear: the title screen's shipped
  `clockwork_waltz_escapement_failure.ogg` (pure varispeed ×1.414, per
  `game/docs/title_screen.md`) vs `Moonlight_HAUNTED_FLOOR_x1335.mp3` (rigged).
  Bridge sequencing through 2026-08-20: `design/ORISON_SONGBOOK_BRIDGE_PLAN.md`.
- **G8** Scratch-vocal return test for the Moonlight/Dreamland candidate: a
  disposable vocal over the full 48k base, one complete take, ×1.335 true
  varispeed — that judges House Five checklist items 9-10 (the 2007 test).
  The base-only preview cannot pass or fail a candidate.

## B — The Harukiya rebuild (owner commission 2026-08-16)

Commission: do for the bar what the arcade got — substantially larger and
taller, a generous stair procession, a dense Akira-style detritus diorama on
the stair and landing, a decompressed couch/jukebox pocket, real social
sub-zones, back-of-house logic, ceiling architecture, layered light, traces
of use, and subtle Orison unease. A superb 1928 metropolitan bar-lounge.

**THE CANON THIS SITS ON.** `docs/harukiya_reference_notes.md` is a formal
evidence ledger with four headings — CANONICAL (visible in the Akira film or
surviving production art), INFERRED, NYC ADAPTATION, GAMEPLAY NECESSITY. The
bar IS Otomo's Harukiya, transplanted. **The owner's requested detritus is
therefore a restoration, not an invention:** littered treads, teal walls and
a soiled red rug are CANONICAL, from the stairwell frame. Every move this
rebuild makes gets filed under one of those four headings, and nothing moves
between headings silently.

- **B1 OWNER RULING 2026-08-16 — THE STAIR WIDENS MODESTLY, AND THE
  COMPRESSION STAYS.** The ledger records canonical circulation as "minimum
  ~850 mm, generally 950–1200 mm. **Never generous.**" The film's bar is
  cramped on purpose, so a fully generous procession would erase character
  the ledger protects. Three options were put to the owner; the ruling is the
  middle one: **widen the 1.15 m stair to roughly 1.6 m** — enough that two
  people pass, which reads generous *relative to the film* — and keep the
  descent tight and dense so that arrival is still compression, with release
  happening when the room opens. File as NYC ADAPTATION, with precedent: the
  2026-08-07 rebuild already took the room 6.8 → 9.2 m deep under that same
  heading ("what a New York operator did with a bigger cellar").
- **B1a AUDIT COMPLETE 2026-08-16 — AND THE FOOTPRINT CANNOT GROW.** A
  ten-agent audit surveyed the room, stair, social pocket, gameplay
  wiring, envelope and identity ledger, produced a fourteen-phase plan,
  and attacked it from three sides. **Two lenses returned UNSOUND, 18
  blockers.** Findings and the gating decisions:
  `design/HARUKIYA_RECONSTRUCTION_BRIEF.md`.
  **The headline:** the canon mass (`nbr_s2`, x −12.0..6.4,
  y −38.2..−28.32) is fixed and total plan gain is **+3.88 m², +2.7%** —
  the first objective cannot be met in plan. It CAN be met in section:
  the 3.55 m of generated brick above the room is the bar's own fabric
  and can stop being generated, giving three heights (2.65 m canonical
  low over counter/lounge/stage, 3.90 m middle, **5.17 m well** over the
  table floor) for **+47% volume, 556 m³ against 377.9**. Hard stops:
  `site_nbr_s2_soffit` z 3.33 (structural, not ours) and the whole-AABB
  strict-inequality street gate at z 2.80.
  **Do not cut geometry until the §5 rulings land** — one of them
  (identity dilution) changes what gets built, and the identity reviewer's
  verdict was that the plan named that risk and then committed it in every
  phase.
- **B1b THE RED DOOR WAS NOT RED — FIXED 2026-08-16.** Canon says
  "battered painted red steel" and names Otomo's teal-offset-by-red as the
  staircase composition, but `DoorProp._build_service()` painted every
  `exterior_service` leaf galvanized grey and ignored `finish_variant`
  entirely. The warmest note at the foot of the teal descent had been
  missing since the descent was built, and no test caught it because no
  test asserts a colour. `SERVICE_FINISHES` now carries variant 1 (oxblood
  enamel gone chalky, never pillarbox) and the marker selects it. WalkTest
  FULL and ShopEntryTest pass. **This needed no ruling: canon was explicit
  and the code disagreed with it.**
- **B2** The detritus diorama on the widened stair and landing. Density is
  the deliverable, but the owner's own bar applies: layered, meaningful
  accumulation implying use, neglect, improvisation, hidden labor or former
  glamour — never "messy as a substitute for design."
- **B3** Decompress the couch and jukebox pocket. Measure the failing gaps
  before moving anything; the jukebox should read as a local shrine, framed
  and approachable, not jammed.
- **B4** Room expansion, sub-zones, bar/backbar presence, back-of-house,
  ceiling architecture, materials, lighting, traces of use, unease — the
  remaining commission, sequenced after B1–B3.
- **B5** Preserve absolutely: the teal descent, the red steel door, the two
  arcade cabinets immediately left of the entrance, the deep canopy over the
  counter, the barrels and crowded pictures behind the backbar, the violet
  felt, and light that only ever comes from something you can point at.

## E — Entropy: the building gets dirty (owner direction 2026-08-16)

Design orientation, not yet a build. Brief:
`design/ORISON_MAINTENANCE_ENTROPY_BRIEF.md` (PROPOSAL — owner review
required). The pitch: dynamic grime, litter, burnt bulbs, wall damage,
clogged WCs, dripping taps and simple appliance faults, all restorable by
a maintenance worker with immediate visual feedback — **Sisyphean in
aggregate, instantly rewarding in the hand.**

- **E1 THE ARCHITECTURE IS THE SECOND SENTENCE, not the first.** The
  owner's follow-up is the real design: *strip the authored decal spread
  so the building is pristine, then simulate resident action and let the
  damage fall out of it.* Today wear is authored — `build_wear_decals()`
  bakes it into the glTF and `AtmosphericDecalPass` places residue from
  rules and unit hashes — so a designer decides the floor looks used.
  Under E1 the condition of the building becomes the **output of the
  eighteen residents already running routines, schedules, navigation and
  240 life sockets**. The building then tells the truth by itself: the
  stair people actually use wears, the corridor outside a struggling
  resident reads differently, and a case that changes behaviour changes
  the wear without anyone authoring it.
- **E2 "PRISTINE" DOES NOT MEAN "NEW" — do not strip the wrong layer.**
  The Orison is 1912, reopened 1928: sixteen years old at game start and
  never new during play. **Inherited patina stays baked** (the dished
  marble tread, the rail polished gold at hand height, wallpaper faded
  from the window) because that is architecture. **Accrued grime gets
  simulated.** The test: *could a person with a mop, a bulb and an
  afternoon undo it?* Yes → simulation. No → architecture.
- **E3 BURN-IN GENERATES THE PAST WITH THE SAME MACHINE.** Day one must
  not look sterile, but the answer is not to author a starting mess — it
  is to run the simulation forward for some weeks of unattended resident
  traffic and open on its output. One machine makes history and present,
  every mark still has a cause, and "how long the building went
  unattended" becomes a free difficulty dial.
- **E4 THE DRAW-CALL TRAP, named before anyone hits it.** One node per
  stain is hundreds of draws in the exact currency this frame is poorest
  in. Build on `MultiMeshInstance3D` per (surface class × floor), toggling
  instances — PS6's after-hours grilles already prove the shape at 1360
  instances. The surface recipe is solved too: `story_decal.gd` (atlas
  region → cached ImageTexture → QuadMesh, ALPHA_SCISSOR 0.08, shadows
  off). Godot's `Decal` node is not used anywhere here and this project
  renders on gl_compatibility — but **re-test before relying on either
  answer**, per the `light_projector` lesson that a documented engine
  limitation is a claim with a date on it.
- **E5 THE SIMULATION IS COARSE.** An accumulation model, not a footstep
  model: residents tick counters on authored anchors, a mark appears when
  a counter crosses a threshold, and the whole thing advances per shift on
  the existing schedule clock rather than adding a second one. Persist
  state per anchor id as a small integer and reconstruct visuals from a
  seed — never serialise a stain's transform.
- **E6 SUPERSEDED BY OWNER RULING 2026-08-16 — RESIDENTS FILE THE WORK
  ORDERS.** The first draft said ambient chores may never issue a work
  order. Too clean: in a real building people complain. Residents now
  react to observed condition by **filing work orders filtered through
  personality**, which gives the whole system a voice in the interface the
  player already carries instead of inventing a new one. Two classes share
  one `WorkOrders` lifecycle, separated by BINDING not mechanism: an
  authored case job comes from `MaintenanceJobLibrary`, binds to a case and
  may advance it; a resident-filed ambient order binds to a place and a
  fault, closes, improves the building, and **never advances a case, never
  satisfies an authored job stage, never gates progress**. Promote to an
  authored job the moment one becomes required.
  Personality is the cheapest characterisation available: the fastidious
  one files about a landing scuff within a day and files again; the stoic
  one waits until the radiator is stone cold in February and apologises;
  the furious one files immediately about the wrong fault; the invisible
  one never files at all, so the player only learns how bad it got by
  going up there. The inbox becomes a portrait of the residents as much as
  of the building — a first-ever order from someone who never complains
  should be alarming.
- **E7 MINIMUM PROVABLE SLICE, arcade-V1 discipline.** One corridor, one
  grime type, one mop, one bulb: seeded anchors in one MultiMesh with the
  station re-measured, a mop stroke that clears an instance **in the same
  frame**, a bulb replaced from stock bought at HARDWARE PAINT (closing
  the loop through the existing errand system), survival through real-file
  save/load, and re-soiling only across a sleep boundary — never in view.
  If that slice is not satisfying, breadth will not save it.
- **E8a OWNER RULING 2026-08-16 — THERE IS NO SCORE.** No meter, no
  percentage, no completion figure, no "building condition: 62%". The
  state of the Orison is legible **only by looking at it**. This is the
  one place where a UI number would destroy the entire feeling: a
  percentage converts a building you are caring for into a task you are
  failing, tells the player the global victory is theoretically available
  when E2's whole design says it is not, and replaces the evidence-reading
  the system exists to create with a glance at a corner of the screen.
  Applies to HUD, the ORDER device and any menu. Residents noticing is
  allowed (E8b); arithmetic is not.
- **E9 OWNER RULING 2026-08-16 — PURGATORY, AND MURPHY'S LAW IS A
  DIRECTOR.** *"This is purgatory. Apply Murphy's law and make it part of
  the horror."* This promotes entropy from a chore layer to a **horror
  system** and settles the Sisyphean question at the level of metaphysics
  rather than tuning: the building never comes right because that is the
  condition of the place, not because someone picked a decay rate.
  Sisyphus is not badly balanced; he is in the correct location.
  **The architecture the ruling implies — "when this happens is a gameplay
  decision":** *the simulation loads the gun, a director fires it.* The
  resident-traffic model decides what is ELIGIBLE to fail and how close it
  is; it never decides when. A separate owner, of the same family as the
  existing sleep-pressure and dream directors, picks the moment for
  dramatic effect. Pure simulation is arbitrary, pure scripting is
  predictable; this is neither, and it is tunable without touching wear.
  **The discipline that stops it becoming punishment:** Murphy's Law must
  be *dramatically* timed, never *punitively* timed. Test every instance
  by whether it makes a better story or merely a longer walk. It must
  never invalidate committed work, never undo a repair already made, and
  never fire during a protected interaction — `call_locked` and the dream
  boundary already define those windows and it respects them exactly as
  sleep onset does.
- **E10 OWNER RULING 2026-08-16 — APPLIANCES HAVE THREE STATES:** working
  → **functional but failing** → dead. The middle state is the whole
  point: it is the warning, the thing a maintenance worker is supposed to
  catch, and the thing Murphy's Law is allowed to punish you for ignoring.
  A radiator that knocks before it dies is a fair building; one that
  simply dies is a cruel one — the maze brief's fairness bar ("the player
  understands in the half-second before impact") applies here in slow
  motion. It also makes neglect legible as sound and behaviour long before
  it is legible as failure, which is free horror: the building complains
  for weeks before it stops.
- **E11 OWNER RULING 2026-08-16 — DIRT DOES BOTH.** A general grime accrues
  everywhere as the honest baseline of a working building, **and** it
  clusters where the fiction says: the bar after a night, the laundry, the
  stair everyone actually uses. Two layers, not a choice. Ambient means no
  surface is exempt and the mop always has somewhere to go; clustered is
  where the drama and the evidence-reading live. Separate MultiMesh
  instance sets with separate thresholds, so ambient stays coarse and
  cheap while the hot spots carry detail.
- **E8b STILL OPEN** (brief §9): does degradation advance per shift rather
  than per hour — the last unruled question.
- **E12 DONE 2026-08-20 — ORISON COMMENSALS RULING GATE.** The owner approved
  the bounded adversarial package in `design/ORISON_COMMENSALS_BRIEF.md` §10:
  tiered cast/taste caps; cat deferred; Room 0 exclusion and haunting precursor
  rejected; C3-only complaints/countermeasures; split visual/audio ownership;
  species-specific daylight with C1 night-only. C1 is licensed. C2–C4 retain
  their gates; no commensal carries signal or confirms a haunting.
- **E13 — GENERATED COMMENSAL C2 ANCHORS (BLOCKED BY E14 AND SHARED-FILE
  SCHEDULING).** After a successful C1, reserve an uncontended `gen_layout.py` pass
  and emit marker kind, species affinity and clearance-validated run-lines as
  generator facts. Never hand-edit JSON or put coordinates in runtime code.
  `gen_layout.py` is known contended ground: inspect shared index/worktree,
  confirm no other lane holds hunks, preserve them if it does, and stage every
  generator/output file by exact name. This is the PS12a lesson made an
  acceptance condition, not a note discovered after a conflict.
- **E14 DONE 2026-08-20 — COMMENSALS C1, MINIMUM PROVABLE SLICE.** One
  low-Hz waking `CommensalDirector`; moths at the two Orison entry lamps;
  mice-in-the-riser audio on one F02 run; one habituated light-switch roach
  scatter in 4B's kitchen; one static hoarding-base weed cluster. Stateless,
  deterministic per `(anchor, shift, seed)`, no save, pathfinding, collision,
  light, shadows, particles, per-creature nodes or case coupling. Prove motif
  separation, protected windows, zone/floor/roof gating and provenance from the
  existing street-lamp markers, 4B kitchen fixtures, riser identities and named
  hoarding geometry. Do not touch `gen_layout.py` in C1.
  Landed without a generator edit: three shadowless MultiMeshes, shared
  ambience playback and a switch-owner verdict. Focused proof is 19/19; tick is
  1.5 µs; matched `WeatherPerf` is +3 submitted objects and the two-run mean is
  +0.028 ms. Lobby/atrium/roof finals remain inside their A/A bands. Production
  frames, provenance and exact numbers: `art/renders/orison_commensals_c1/README.md`.
- **E15 — COMMENSALS C2, WAKING BREADTH (OPEN; C1 SUCCEEDED).** Add
  roosting pigeons and one proximity flush, rare validated rat gutter-runs,
  positional guano/web decals, and restrained Passage/B1 casts. Room 0 has no
  animal-exclusion rule. Maintain one
  MultiMesh per class per zone, hard submission caps and no runtime routing.
- **E16 — COMMENSALS C3, §E INTEGRATION (BLOCKED BY E15 AND ITS OWNER
  RULING).** Move pressure onto §E anchor persistence, route personality-
  filtered ambient complaints through the existing place/fault work-order
  binding, add period countermeasure errands, and let Murphy's director choose
  fair moments from eligible pressure. Never advance a case, undo a repair or
  fire during protected interaction/dream windows.
- **E17 — COMMENSALS C4, SEPARATELY RULED BREADTH.** Price and rule broader
  audio and the optional Harukiya mouser independently. The rejected haunting
  hush/flush hook is not part of this owner. Commensals never carry signal, imitate the motif,
  confirm a haunting, stalk the player or become dangerous.

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
- **L11 CLOSED 2026-08-16 — re-measured, and nothing was hiding.** The
  walkthrough punchlist blamed the 16-light per-object cap for F02_D and
  F05_D rendering black. It was right about the mechanism and was simply
  never re-run after the cap went to 128. `RoomLumaAudit` (which reads
  pixels back, unlike LightingAudit, which never looks at one) reports
  **PASS on both floors**, 20 rooms each, 4 exempt: the D units measure
  0.2–42.8% near-black against a 55% ceiling and mean luma 19–59 against
  a floor of 9. The prose is closed out with the table.
  **The lesson for the rest of P8:** a fossil can hide a *fixed* problem
  as easily as a live one, and the only way to tell is to re-measure.
  Observation left, not chased: three of four D rooms per floor carry no
  fixture and are readable on spill and window glow alone; both audits
  accept it.
- **L12 THE MOBILE LIGHT BUDGET IS STILL UNMEASURED.** Desktop dropped its
  budget on evidence; mobile kept `ACTIVE_N_MOBILE` / `SHADOW_N_MOBILE` purely
  because a tiler pays per fragment and nobody has put a phone in front of it
  (`light_rig.gd`, see #20). That is the honest position, not a finding. It
  wants confirming on hardware through the debug-panel sliders, and until it
  is, no mobile lighting claim in any doc is measured.
- **L14 THE RUNTIME LIGHT BUDGET IS 16/16 AND `UNLIMITED` IS DEAD TEXT.**
  Found 2026-08-16 by an adversarial review of a V4 lighting plan, after I
  had already written the opposite into HANDOFF from reading constants
  instead of callers. `light_rig.gd` declares `UNLIMITED = 4096` and its
  header narrates a desktop budget removal — but `building_root.gd:456-465`
  calls `set_budgets(16, 16)` (cinematic max quality) or `set_budgets(14, 8)`
  (every other path) immediately after constructing the rig, on every boot.
  There is no branch that leaves it unlimited. Empirically, every run prints
  `[LIGHT RIG] budgets resolved: 16 active / 16 shadow`.
  **Consequences:** real lights are scarce after all — sixteen active, and a
  new one EVICTS an existing one, so any lighting design must name its
  victim. The "measured at 16/16" tables across the docs were describing the
  live budget, not just a test condition; only the mechanism they blamed was
  stale. **Cleanup owed:** delete or correct `light_rig.gd`'s dead
  `UNLIMITED` narration and `building_root.gd:460-461`'s comment that
  "sixteen is the renderer's actual per-object ceiling" (it is 128) — a file
  that argues against its own caller is how this survived. And the rig
  already knows the lesson: it prints the resolved pair precisely because "a
  wrong budget number survived in three documents because nothing ever
  printed the one actually in force" (`light_rig.gd:328-330`). Read the
  print, never the constant.
- **L13 SHADOWS ARE THE SCARCE CURRENCY — RULED AND ENFORCED 2026-08-16.**
  `positional_shadow/atlas_size=8192` subdivides per caster, so every added
  shadow-casting fixture shrinks every existing shadow — raising the caster
  count while leaving the atlas fixed is how you make shadows worse by asking
  for more of them. **Owner ruling: a new fixture ships with
  `shadow_enabled = false` and has to earn a caster slot.**
  Authored fixtures already obey this by construction: LightRig ranks them and
  grants shadow through `LightFixtureProp.set_budget(..., with_shadow)`, so
  they cannot creep. The population that *can* creep is ad-hoc lights built
  directly in scripts, which answer to nobody — measured at **8** in the
  production scene (exterior moon, the carried service lamp, the entry
  composition rake, one further composition spot, four street-lamp omnis)
  against 16 LightRig-governed fixtures. LightingAudit now gates exactly that
  population (`UNGOVERNED_CASTER_BUDGET`); raising it is allowed and is the
  point, but it must be a deliberate edit naming the new caster, not drift.
  V4 lighting spends against this rule.

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
  joins the ordinary two-way stream at 2.0 / 99.0 selection weight. Its final
  projected body stays inside 5.8 × 2.05 × 2.30 m and embeds four dull material
  plates — side, rear, paint and the repaired shark-and-mustachioed-tuna panel
  — in one shared shadowless truck MultiMesh. The older separate sign batch is
  fallback-only and submits zero instances while the production GLB is present.
  There is still zero light, collision, stop rule, dialogue or permanent
  scenery. `PianoRepairTruckTest` now proves the landed mesh contract rather
  than the superseded box fallback; production-street frames are under
  `art/renders/piano_repair_truck/`.
- **T2g DONE — COACHWORK SURFACE.** Ordinary body and cab batches keep their
  authored per-kind tints but now take normal and roughness from `car_paint`,
  with zero metallic; tyres independently use matte `rubber_aged` and the one
  shared wheel mesh rises from 10 to 16 radial segments. No owner, draw, light,
  shadow or motion rule was added. Whole-frame change is below live-rain noise,
  but the foreground-vehicle crop is 10.4× its A/A floor. Contract and frames:
  `art/renders/traffic_paint/README.md`.
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
- **T9 PROPOSED — the street wall.** `design/STREET_WALL_PROPOSAL.md`: frame
  the arcade gate (its K0 host is one storey short, per the gateway
  proposal's own §3.1) and close the facade ring around the play area —
  three-layer system, eight-station survey evidence in
  `art/renders/street_facade_survey_v1/`, +0.5 ms perf contract, phases
  W1–W4. Awaits owner ruling on §6 (west-strip character, ghost-sign copy,
  lintel carry); W1/W2/W4 are not blocked by fiction questions.

### T-ENDS — one railway, two bottlenecks (owner proposal 2026-08-18)

Owner: *"lets have one end of the street limited by an overpass that runs close
to but slightly offset from 90 deg over the road? that would limit sightline in
that direction"* — and then, to find the other end an equivalent reason to
bottleneck view and traffic.

**This supersedes the atmospheric answer, and that is the point.** §4 of
`ORISON_STREET_BRIEF.md` records the owner's "tear in the universe" proposal
staged down to "quiet storm, hoarding and middle-distance loss". Haze is what
you use when the world runs out; architecture is what you use when it carries
on somewhere you are not going. The second reads better and costs less
apology — and it retires the hoarding at x −20.10 / +20.60 that the brief
itself calls honest and temporary.

**THE PROPOSAL: it is all one railway.** An elevated line flies over the east
end; the same line comes down to grade and crosses at the west. One piece of
world, one material family — riveted steel, creosoted timber, ballast, soot —
built twice. The Orison is caught between two crossings of one railway, and the
reason you cannot leave is infrastructure rather than metaphysics, which is
exactly the register §4 was reaching for when it warned that a screaming portal
spends the quiet the game runs on.

#### Why the skew is the whole idea, and 90° would not do

At a right angle the bents line up in perspective. From somewhere on the
pavement you get a clean shot straight down the line of columns and out the far
side, which is the one thing a terminator must never give you. **On a skew the
columns never align from any standing point on the street** — each hides a
different slice of what is behind it, and the occlusion holds as you walk.

It also breaks the street's own symmetry for free. The corridor is 16.3 m from
building line to building line (`BLDG_N` −12.0 to `BLDG_S` −28.316). At **79°**
the deck meets the north line **3.2 m** along the street from where it meets the
south, so the two pavements terminate at different points and the soffit reads
as a long trapezoid rather than a band. That asymmetry is what says the
right-of-way predates the street and did not care about it.

#### Where they go, and the systems payoff that decides it

`SPAWN_X` is 52.0 and vehicles are dropped past 56 (`street_traffic.gd:26`).
**Put both structures at that radius and they hide the spawn.** Traffic
currently pops into existence in open view at x ±52; under a viaduct's shadow
and behind a standing freight cut it *arrives from somewhere*. That is the
strongest argument for the whole proposal and it costs nothing extra.

- **EAST, the viaduct** — deck soffit ~6.2 m clear over the carriageway, deck
  ~1.4 m, so ~7.6 m to the parapet. The `ne` blocks run 11.5–21.5 m, so it
  threads *between* buildings rather than over them. Bents just inside each
  kerb; with the skew the north bent stands 3.2 m along the street from the
  south one. A train crossing is a moving occluder and a sound with no visible
  cause from the pavement.
- **WEST, the level crossing** — the same line at grade at about x −50, where
  `nw4` is already the *sooted* block, which is what stands next to a goods
  yard. Gates, a gateman's shanty, a signal, rails and ballast laid across the
  asphalt. **A standing freight cut is the total occluder**: boxcars parked
  across the crossing close the view completely and can leave.

#### What it gives the traffic system, which already wants it

The gap the player judges is currently produced by `MAX_WAIT` and
`GAP_SECONDS` — a promise with no cause. **Gates give it one.** When the gates
drop, traffic queues and then releases in a bunch, which is both a legible
reason for the gap and a better rhythm than a random one. The brief's §2 says
the crossing should be a texture rather than a challenge; a level crossing at
the end of the street is how a real road produces that texture.

#### Open questions for the owner

- Which end takes which. The soot on `nw4` argues for the yard in the west and
  is the only evidence either way.
- Whether a train is ever *seen* on the viaduct, or only heard. Only heard is
  cheaper, quieter and probably better.
- Whether the freight cut is scheduled or permanent. Scheduled costs a system;
  permanent is a wall wearing a good disguise, which the brief has already
  rejected once in another form.

#### Not costed

Nothing here is priced. It is new geometry at both ends of the heaviest floor
in the game, and §DP's rule applies — cost is recorded, not used as a veto —
but nobody has measured it and this entry should not pretend otherwise.

### T-GHOST — the truck's garbled skin as a haunting (owner idea 2026-08-18)

Owner, on being shown the repaired piano truck: *"the director can briefly
remove the fixed panel to reveal the garbled art to cause confusion and
disorientation to a viewer, unsure of what they saw."*

**The defect is already the asset, and it is already loaded.** The Meshy atlas
whose lettering is gibberish at every triangle budget is still on the mesh; the
readable sign is a separate material assigned last over 379 faces
(`build_traffic_vehicle.py`). Swapping that one material back reveals the
unreadable original underneath, on a vehicle already moving past at speed.

Why it is worth building: it is the cheapest possible haunting. No new asset,
no new system, one material swap on an object the player is not studying. And
it fails in the right direction — a viewer who catches it cannot check, because
the truck has gone, and the next one is correct. That is the register the whole
game works in, and unlike a flicker or a stinger it points at nothing.

**Accessibility, which is not negotiable and is easy to get wrong here.** The
brief bans flashing at photosensitive frequencies outright. A material swap
that returns within a frame or two IS a flash. So: the reveal holds for a
readable interval (of the order of a second, not a frame), happens at most once
per vehicle, and never repeats on a cadence. It should read as *doubt*, not as
strobe.

Owner decisions still open: whether the haunting director already has a hook
for street objects, whether it fires on being looked at or on not being looked
at, and whether the rear doors change with the flank or stay correct so the two
disagree.

### W-GLAZE / W-SHOW / W-JOINERY — the apartment windows (DONE 2026-08-18)

One job in three entries, all closed. Frames, measurements and the full
argument: `art/renders/windows_w1/README.md`. The owner's five separate
complaints had five separate causes; every one is fixed and measured.

**THE ENTRY THAT STOOD HERE WAS WRONG ABOUT ITS OWN HEADLINE.** It said "There
is glass. There is no joinery." There was always joinery: `build_wall()` emits
two jambs, a head, a projecting cill and a sash meeting rail per glazed
opening, plus a soldier lintel. Measured before touching anything —
`F02_stone_trim-col` is 996 tris = 83 boxes = 16 windows x 5 parts + 1 door x 3.
**That is the fifth count in this project taken over the wrong set**, and the
reason is worth keeping: those parts are generated in `build_orison.py` from
`walls[].openings[]` and never enter `building_layout.json`, which is where the
earlier pass looked. The blinds ARE in that file, so the blinds were all it
found. Lesson 4 of the last session, again, in the entry written to record
lesson 4.

**What was actually absent**, and it is the real answer to "reads as computer
generated": every window part was a rectangular prism SYMMETRICAL ABOUT THE
WALL CENTRELINE, because `box()` cannot build anything else. The cill projected
as far into the room as onto the street; the reveal was undressed; the glass
was one bare sheet in the middle of 350 mm of brick with a single rail across
it and no frame, no stiles, no sashes and no putty line.

**Built**, per glazed opening, outside to in: reveal lining, outer architrave
30 mm proud, label mould over the head, a cill that projects onto the street
and dies into the wall inside, with a sloped wash (`add_hex`) and a throating
under its nose, interior window board and architrave in timber, the frame in
its rebate, then a 1-over-1 double hung whose two sashes run in SEPARATE
PLANES. Mullions divide anything wider than 1.45 m, which the three 5.40 m
bands needed and never had. `off_box`/`off_hex` are the new primitives: a box
that is not symmetrical about the wall, and a box that can be sloped.

**The 56 decorative alcoves were checked and are correct as built.** Their
comment promises "a finished reveal and sill, never glazing", and
`build_orison.py:3130` gives them exactly four plaster returns lining the
aperture and nothing else. Nothing to do; recorded so nobody checks twice.

**W-SHOW had three causes, not one, and none of them was the blinds.**

1. `F01_glazing` and `F01_stone_trim` are whole-floor batches whose AABBs sit
   inside the 15.2 x 11.2 street-core envelope — **the core is the STREET
   REGION and the building stands inside it** — so the sweep indexed them as
   enclosed content and zeroed their layers from the carriageway. Now named in
   `ENVELOPE_BATCHES` by the identical argument the list already made for
   `window_glow`. Matched as SUBSTRINGS, which turned out to be load-bearing
   within the hour: giving the slats their own material moved them out of
   `furniture_trim`, whose extent reached z 37.57 into the Passage and had
   therefore always failed the containment test BY ACCIDENT.
2. `outside` asked `> 15.2 / 11.2` while the shell is 14.05 / 10.05, leaving a
   metre-wide band of pavement along every facade where the eye was neither
   outside nor on an interior storey — so the rule fell through to
   `absf(p.y - z) < 1.75` and culled the whole stack. `OUTSIDE_HALF_X/Z` are
   14.2 / 10.2 now. The rear porch decks sat in that band too.
3. The prop clause, **ruled open by the owner on 2026-08-18**: exterior views
   now keep every floor's props, not only F01's.

The previous commit blamed the blinds for W-SHOW. It was wrong — measured
in-engine, `F01_furnish_trim` was never street-core eligible.

**W-JOINERY's premise was also wrong, in a way that strengthens it.** It argued
from "these are the surfaces `window_glow` lights from behind".
`window_glow.OWN_WINDOW_PANELS := false` has been the ruling since 2026-08-05:
the Orison shows its own structure, lit by its REAL interior fixtures, and only
the neighbours get emissive panels. A real light behind a crowned slat is a
better reason to build the crown than a fake one was.

**Slats** are crowned sections, four spans across a fixed 50 mm chord, and they
turn: the old model held the chord level and changed the box's aspect instead,
so a closed blind was a stack of tall thin posts on edge. Its pitch also ran
BACKWARDS to its own docstring — `0.055 + 0.02 * tilt` opened the spacing as
the slats closed, so a shut blind covered 45% of its window.

**"blinds dont seem to be rendered from outside"** (owner, same day, after the
first frames). They rendered; they hung 450 mm behind the facade, a hand's
width into the room past the inner plaster, which was the only sane place while
the opening was a bare hole. Once the reveal was lined the lintel occluded them
from every pavement eye. They now hang off the frame, 30 mm clear of the sash,
cut to the daylight width (1.13 m — the old blind was WIDER than the hole it
covered). `gen_layout`'s two blind validation rules encoded the old mounting
and caught this in 132 places before a frame was taken; both were re-stated to
assert the new geometry rather than relaxed.

`sash` and `blind_slat` are their own catalog materials, plated by
`art/tools/build_window_joinery_maps.py`. **They belong in gen_layout's `MATS`,
not in `material_catalog.json`** — that file is generated, and the comment at
`gen_layout.py:10496` says so; hand-editing it cost one Blender run here.

**Cost, recorded not filtered (§DP):** 637,166 -> 715,550 render triangles
(+12.3%) and **1161 -> 1181 draws (+20)**, which is the axis §P's frame is
actually bound on. Collision +11,952 from the sash frames; slats do not
collide. The §DP trigger is still unmonitored — nobody has measured this build
on a desktop, so "dont worry about budget until we hit performance issues"
still has no off-switch.

**Regression net:** `StreetCoreVisibilityTest` 28/28 (up from 20, six checks
added), `PassageVisibilityTest` green, `WindowShot` 4/4 with a 0.000% control
noise floor against 11.8-31.5% at every station.

#### The instrument was the broken thing again, and this one is a trap for the next person

Diagnosing the visibility bug HEADLESS showed 41 draws indexed as enclosed on
an extent nobody had computed: the street-end hoardings at |x| ~ 20 m, the
driving rain, the roadway mist, every Vantry point batch. **Under Vulkan the
same nodes report real extents and are classified correctly** — no player has
ever lost the hoardings. The dummy renderer keeps no multimesh instance
transforms, so `get_aabb()` returns an empty box at the node's origin, and an
empty box at the origin is inside any envelope that spans the origin.

`_measured_world_aabb()` now refuses to classify anything it cannot place,
because every automated harness in this project runs headless and a gate that
hides forty-one street draws only when it is being watched is a measurement
waiting to be believed. Reconstructing the extent from the multimesh's own
instance transforms was tried and does NOT work: the dummy renderer returns
identity for every one of them.

This also explains the StreetTraffic fix of 2026-08-18 as the workaround it
was — right about the symptom, never reached the cause, which is why it did not
generalise to the six batches that arrived after it.

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
- **PS12 OWNER COMMISSION 2026-08-16 — THE ARCADE RECONSTRUCTION.** Rebuild
  the Vantry Arcade as a grand 1926 commercial building (Windsor Arcade
  ancestry). Authority: `design/VANTRY_ARCADE_RECONSTRUCTION_BRIEF.md`,
  phases V1–V6. **V1 (the nave raised) is BUILT and verified locally**:
  9.90 m ribbed glass nave, clerestory order, crossing lantern + pendant
  clock, south terminus + directory, throat vestibule, street frontispiece;
  full Passage battery + WalkTest FULL PASS; northbound measured **13.03 ms**
  at canonical pinned night — the PS9 accepted blocker station now passes the
  16.6 gate. Record: `art/renders/vantry_arcade_v1/README.md`. The V1
  `gen_layout.py` hunks + regenerated JSON/GLBs are HELD uncommitted pending
  the parallel session's in-flight W1 street wall in the same file (never
  publish another lane's WIP); commit V1 code immediately after W1 lands.
  **V2 (the rooms behind) is BUILT and verified locally** (2026-08-16):
  eleven rear stock rooms + borrowed lights over every back wall, the
  funeral chapel with parted drapes and chancel rail, service vestibules
  with real light-falloff darkness; battery + WalkTest FULL PASS,
  northbound 13.20 ms; content alarms deliberately raised (1300→1550
  records, AABB gate 9.0→10.5, mesh cap 280→310) with measurements in the
  comments. Record: `art/renders/vantry_arcade_v2/README.md`. V2 generator
  hunks (gen_layout.py + shop_interiors.py) join the V1 hold.
  **V3 (frames, plaques, the face) is BUILT and verified locally**
  (2026-08-16): bronze/nickel glazing families + opal transoms + brass
  tenant plaques per trade; daylight elevation review passed after two
  fixes (continuous sixteen-voussoir archivolt, stepped center attic
  crowning the skyline); PassageVisibilityTest now pins DAYNIGHT=0 itself
  after a wall-clock flake (went red purely because the machine crossed
  2 AM). Battery + WalkTest FULL PASS, northbound 13.54 ms. Record:
  `art/renders/vantry_arcade_v3/README.md`.
  **V3b (street respacing) is BUILT and verified locally** (2026-08-16, owner
  direction "space the arcade on the street better, move the subway exit"):
  measuring the east flank found V3's frontispiece pier base and the K1 kiosk
  plinth **interpenetrating** by 10x620x160 mm — a stale clearance, since K1
  measured its 1.10 m from the bare portal before anything projected from the
  face. The kiosk moved 18.10→18.55 for balanced 0.42/0.40 reveals, taking its
  stair, GROUND_HOLES entry, pavement cut and approach light with it; the
  assert now guards the reveals so the bug returns as a build failure. Full
  battery + WalkTest FULL + StreetContainment PASS. Record:
  `art/renders/vantry_arcade_v3b/README.md`. **Open, not ours:** the kiosk
  footprint overlaps the in-flight W1 flank wall band in plan — predates this
  and belongs to the W1/K0 reconciliation.
  **PS12a HOLD RELEASED 2026-08-16 (`f7963af`).** The generator, the
  regenerated JSONs and all eight rebuilt GLBs are committed; a clean
  checkout now builds the reconstructed arcade and the rebuilt Harukiya.
  About 39 of the 1163 added lines are the parallel session's W1 street
  wall, disclosed in the commit message rather than swept in silently —
  every test ran against that combined tree and passed. If that session
  reshapes W1 it merges normally on top. Historical note follows.
  **PS12a (was) HELD CODE — THE WHOLE RECONSTRUCTION WAS UNCOMMITTED.** V1+V2+V3+V3b
  live only in the working tree's `art/data/gen_layout.py` and
  `shop_interiors.py`, because those files also carry the parallel street-wall
  session's in-flight W1 upper storey and publishing another lane's WIP is
  banned. Everything else (records, renders, shot harnesses, test contracts,
  the `nocol` builder change) is committed. **The moment W1 lands, commit the
  generator hunks** — until then the repo builds the pre-reconstruction arcade
  from a clean checkout, and every render in `vantry_arcade_v1/v2/v3/v3b` is
  ahead of the committed generator. Verified integrated: both change sets
  coexist and the full battery passes on the combined tree.
  **PS12b KIOSK / W1 FLANK OVERLAP — not ours.** The subway kiosk footprint
  (now x 18.55..20.20) overlaps the in-flight W1 flank wall band
  (x 17.35..20.60, y −28.42..−27.92) in plan. It predates the V3b respacing
  and is unchanged by it. Belongs to whoever reconciles W1 with K0/K1; flagged
  in `art/renders/vantry_arcade_v3b/README.md`, deliberately untouched.
  **PS12c STREET ELEVATION IS STILL OVER GATE** at 25.80 ms vs 16.6 (pinned
  night). Pre-existing, unchanged by the reconstruction — the arcade's own
  three stations all pass. Belongs to project-wide P1, not to this lane.
  Next: V4 lighting hierarchy
  (bronze needs light to read; rear rooms get their half-light; the
  night-jewel state), V5 use/aging, V6 abnormalities + perf.

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
- **N6 DONE.** Mina's pocket pursuit uses one invisible navigation body and a
  shadows-only borrowed silhouette; `DreamPursuitTest` proves the lamp contract,
  collision and route without adding a monster mesh or combat owner.
- **N7 DONE.** The lift void, Vantry signal trunk and hollow runner are live;
  warning, contact/fall outcomes and directional captions are proved by the
  Hazard suite. **Perception proof repaired 2026-08-20:** the harness now finds
  each source through deterministic Atlas ancestry, stages the real pocket by
  authored socket and keeps its unique live id for the log; it injects neither
  a hazard nor geometry. All 60 approaches execute (20 per hazard), with 20/20
  warned, fair and bearing-true for each cue and no script warning or error.
  Routed worst margins are 1.16 / 1.13 / 0.93 s; doorway-only margins are
  0.65 / 0.13 / 0.92 s against 0.90 / 0.90 / 0.75 s owed. The machine
  precondition is closed again; Gate C's blinded-human 80% identification
  bullet remains open. The later sockets remain data until their cases.
- **N8 DONE.** Gate D plays the complete Mina shift through the production
  `CampaignShell` and real dream for capture, contact and fall, rebuilding the
  waking Orison at the authored 4B bedside with the factual refrigerator
  residue intact. The isolated dream station is below 16.6 ms.
- **N9 DONE 2026-08-20 — PETER PROVES THE SHARED PROFILE SEAM.**
  `peter_release_print` is slot 2 with the authored 38-second ceiling, dual
  gradual/sudden onset, Peter's borrowed silhouette, distinct shared-pursuit
  values and the exact truth “Uncertainty does not prevent action.” Reversing
  out of a real junction asks the existing `DreamRoomBuilder` to return the
  same remembered Orison room with one additional deterministic door; aged
  paper forms and oxblood decision marks make the demand legible under the
  existing lamp. The shared root forwards only `junction_reverse` to the shared
  Tenant's ordinary last-known-position owner. Mina's empty grammar is a true
  no-op; Peter inherits no Mina hazard by accident; no director, maze, pursuer,
  hazard or save owner was forked. `DreamProfileTest` 28/28, RoomBuilder
  175/175, Pursuit 39/39, Fractal 24/24, Hazard 42/42 and Atlas 26/26 pass.
  SleepPressure 20/20, DreamBoundary 39/39 and WalkTest FAST/FULL x8/480 pass;
  FULL retains its unrelated waking route/dummy-texture/safety-net diagnostics.
  Production A/A/A-B/light-off proof and the rejected broken-camera finding:
  `art/renders/dream_profile_n9/README.md`. This proves the dream content seam;
  it does not enable Peter's still-unbuilt waking case loop.
- **N10 DONE 2026-08-20 — DREAM SURFACE C–F + EMBRACE.** The persistent exposure field and
  organic front are landed. The 2026-08-20 target slice adds one batched
  dark-live growth surface for eligible hazards, registers every substantial
  tendril centerline back on its source `DreamHazard`, adds first geometric
  eyes, and furnishes every nonblank remembered room with mesh-only extracts of
  production Orison props. Live tissue keeps a low wine-purple afterglow and
  motion in darkness; the lamp remains the dominant antique-gold response.
  The conditional Vantry trunk is deliberately excluded. Checkpoints R1–R8
  below close relief, the deterministic eye family, torn breach, durable
  exposure, reflected gold, depth-zero view and capture presentation. Nothing
  licenses popping geometry, a second combat system or unmeasured draws.
  **Wall-architecture follow-up landed 2026-08-20.** Every remembered nonblank
  generation now carries a visual-only Orison interior shell: 140 mm skirting,
  canonical 1.32 m dado and framed corridor wainscot, 2.18 m picture rail,
  stepped cornice under the exact 3.015 m ceiling, live 0.91 × 2.13 m door
  casings and a pressed ceiling medallion. It is at most two MultiMesh draws per
  room and owns no collision, light, sound, interaction or navigation. Armed
  growth crawlers no longer terminate against a flat wall: shallow closed-lobe
  wall/ceiling grafts and fine capillaries overlap this millwork in the existing
  one growth surface, while only substantial registered limbs promise contact.
  `DreamSurfaceTargetTest` is 31/31; RoomBuilder 175/175, Hazard 42/42 and
  Lineage 21/21 pass. Two fresh 1440p dream profiles stay at 1.60–2.04 ms with
  a 172-call worst observed row. Proof and the rejected flat-membrane finding:
  `art/renders/dream_orison_walls_v1/README.md`. WalkTest FAST passes; two FULL
  x8/480 runs each fail one different waking traversal (roof monitor, then 2A
  bedroom), proving the long harness is currently unstable rather than giving
  this dream-only pass a clean integration result. **C remains open for actual
  tessera/grout/cracked-medallion relief, and D remains wholly open.**
  **Production-rendering integration, 2026-08-20.** The accepted target is an
  establishing-frame balance of roughly 60% recognisable 1928 Orison and 40%
  impossible organism, with one dominant breach, secondary connective growth
  and sparse eye accents. The execution order is now R1 readability plus a
  modular tissue/wet-film/living-gold substrate; R2 relief and architectural
  transition masks; R3 the seeded eye family; R4 the torn breach and cheap
  impossible depth; R5 bounded phase/warp states; R6 one view-only portal; R7
  a separate ruling on recursive or enterable faults. `DreamAtlas` remains the
  only topology owner and `DreamHazard` the only danger owner. Portal depth,
  eye density and distortion may scale by quality; navigation and hazard truth
  may not. Required debug views and the production validation-pocket contract
  are recorded in `design/DREAM_SURFACE_REDESIGN_BRIEF.md`.
  **R1 LANDED 2026-08-20.** All Klimt paint/ink/jewel/relief channels now obey
  the same durable `eaten` boundary as leaf, and architectural materials begin
  at 0.26–0.46 consumption, restoring the real Orison substrate. A reusable
  shader include supplies cellular tissue, tendon folds, wet microfilm and
  warped living-gold vessels to the existing single growth draw. A bounded cool
  lift, five-metre near black level and one warm practical establish nearby
  architecture without waking hazards. Ellipsoid and tube smoothing adds no
  submission. `DreamSurfaceTargetTest` 36/36, RoomBuilder 175/175, Hazard 42/42,
  Lineage 21/21; 1440p dream perf remains 0/4 over budget with a 1.94 ms worst
  row and 172-call worst row. Proof: `art/renders/dream_rendering_r1/README.md`.
  WalkTest FAST x8/480 prints PASS with the inherited null-layout error; FULL
  repeats the unrelated waking roof-monitor failure at z=2.9 while passing the
  2A bedroom, so the integration harness remains red/flaky rather than being
  reported clean.
  **R2 LANDED 2026-08-20.** Every Klimt architectural material now carries its
  authoritative room bounds and surface class. The existing durable field is
  biased toward real joints—floor/wall, corners, skirting, dado, picture rail,
  cornice, casings/lintels, shafts and ceiling rose—without becoming a second
  growth owner. The one submitted surface now has 82 mm tessera faces with
  narrow recessed grout, 9–12 mm parallax/normal relief, 26–42 mm concentric
  bosses and cracked nonmetallic leaf. Tesserae follow the spiral drawing;
  the rejected full-plane version read as black graph paper. Debug modes expose
  architecture pull, relief height and stage bands. Target 41/41, RoomBuilder
  175/175, Hazard 42/42, Lineage 21/21; real-window 1440p dream perf is 0/4
  over budget, 2.00 ms worst and 172 calls worst. WalkTest FAST and FULL x8/480
  both pass (FULL exit 0 in 43.9 s) while retaining their inherited logged
  diagnostics. Proof: `art/renders/dream_rendering_r2/README.md`.
  **R3 LANDED 2026-08-20.** Five seeded anchors per eligible danger now carry
  stable id/source, 0.76–1.34 scale, local orientation and roll, resting lid,
  long blink phase and one of four gaze behaviors. Four of five rest closed or
  half-lidded. Exactly one eye in the live batch may track the camera, moving
  only iris/pupil within 0.28 eye radius; the others hold root, branch-tip or
  room-centre attention. Plum lid, antique sclera, iris and pupil remain custom
  vertex data in the same one hazard surface: no draw, collision, light or
  danger owner was added. Two diagnostics expose rest/tracking and gaze class.
  Target 47/47, RoomBuilder 175/175, Hazard 42/42, Lineage 21/21; real-window
  1440p dream perf remains 0/4 over budget, 2.45 ms worst and 172 calls worst.
  WalkTest FAST passes. The first FULL run hit the unrelated timing-sensitive
  roof-monitor walk at z=2.9; the immediate fresh-process rerun passed and both
  retained inherited logged diagnostics. Proof:
  `art/renders/dream_rendering_r3/README.md`.
  **R4 LANDED 2026-08-20.** One deterministic dark-live hazard per batch now
  owns one dominant 1.28 × 2.24 m wound on its actual Atlas room wall.
  Eighteen-point torn plaster, six broken lath pieces, an interrupted living
  rim and seven rubble pieces are real geometry in the existing one hazard
  surface. Its one opaque flat face renders nine nested angular recession
  bands, false-depth cables and one vanishing eye: 87 mm physical depth reads
  as 32 m without another draw, room, camera, viewport or world. The wall and
  its collision remain intact; an authoritative ray proves it. Target 59/59,
  RoomBuilder 175/175, Hazard 42/42, Lineage 21/21; real-window 1440p dream
  perf remains 0/4 over budget, 2.16 ms worst and 172 calls worst. WalkTest
  FAST and FULL x8/480 both pass, with inherited logged diagnostics. Proof:
  `art/renders/dream_rendering_r4/README.md`.
  R4 handed off to the bounded R5 exposure/phase/warp pass recorded below;
  its ruling against geometry popping remains in force.
  **R5 LANDED 2026-08-20.** Architecture and anatomy now share one durable
  exposure controller: 0.10→0.34 infection, 0.48→0.78 rupture and 0.70→0.92
  flesh-to-living-gold. The R4 wound is always submitted and opens by stable
  ordered material coverage—no node, mesh, surface, collision or hazard pops.
  One rotational distortion field falls to zero at the tear and is capped at
  0.085 local UV. At retained 0.78→0.96 exposure, one 0.42-energy / 3.2 m
  shadowless room-local light returns gold independently of the current lamp.
  Target 71/71, RoomBuilder 175/175, Hazard 42/42, Lineage 21/21 and WalkTest
  FAST/FULL x8/480 pass. Fresh target-pocket perf control/exposed keeps exact
  object/call counts and remains 0/8 over 16.6 ms. Proof:
  `art/renders/dream_rendering_r5/README.md`.
  **R6 LANDED 2026-08-20.** One bounded 384 × 672 shared-world view now opens
  inside the existing wound only at retained high exposure. RoomBuilder owns
  the deterministic already-live destination and odd quarter-turn; the portal
  owns one camera and no room, graph edge, navigation, collision, light, sound,
  interaction or danger. Excluding presentation layer 20 from that camera
  makes recursion depth provably zero while the main camera still sees the
  one-surface wound. The real wall and collision remain intact. Target 92/92,
  RoomBuilder 175/175, Hazard 42/42, Lineage 21/21, Atlas 26/26, Fractal 24/24
  and WalkTest FAST/FULL x8/480 pass. The exact aperture-facing price is
  +0.18 ms lamp-off / +0.29 ms lamp-on, 0/4 over 16.6 ms. Proof:
  `art/renders/dream_rendering_r6/README.md`.
  **R7 CLOSED 2026-08-20 — DEPTH ZERO IS THE ANSWER.** No recursive or
  enterable breach is licensed. The Atlas already turns reproductive ancestry
  into traversal; nested entry would duplicate that play while creating a
  second collision/navigation/pursuit contract, and another rendered depth
  would add cost without a decision. Reopen only if a later case names a new
  verb or consequence the Atlas cannot express. The surface redesign queue is
  complete.
  **R8 LANDED 2026-08-20 — CAPTURE BECOMES INTERIOR.** One inward-facing
  0.68 m shell on the existing player camera closes monotonically from every
  screen edge over 1.5 seconds plus a 0.18-second hold. It preserves the lamp
  state the player chose, closes every existing batched eye, hides action HUD,
  collapses the acoustic room and moves the case signature into a non-spatial
  fifth position. Only then does the unchanged `capture` outcome reach the
  existing 4B wake/residue boundary. No camera, light, collision, hazard,
  topology or input was added. Multi-scale local-3D cells/folds/wet-film and
  cell-boundary capillaries replaced the first flat shell; POM, particles,
  extra eyes, tangent normals and vertex displacement were rejected by rendered
  controls. Focused contract 31/31; final integration results and exact 1440p
  price are in `art/renders/dream_embrace_v1/README.md`. N7's stale
  `DreamPerceptionTest` is repaired above and N9's Peter profile proof is closed
  above. The owner has since ruled the full order Mina, Peter, Juno, Mae, Cal,
  Omar. Friendship/romance and chosen re-meaning remain last.
- **N12 DONE 2026-08-20 — JUNO MAKES FEEDBACK LOAD-BEARING.** Slot 3 carries
  Juno's 50-second ceiling, dual onset, borrowed silhouette, distinct shared
  pursuit tuning and exact truth “Connection requires an open channel.” The
  initially open lamp channel schedules one delayed echo; a safe live joint
  becomes a reciprocal solid partition with compressed speaker cloth and four
  brass traces. Congeal refreshes shared Tenant attention once, while a sustained
  channel releases the FIFO-oldest partition silently. Mina and Peter remain
  no-ops, Juno arms no Mina hazards, and no case-specific runtime or save owner
  was added. Profile 38/38, RoomBuilder 175/175, Pursuit 39/39, Hazard 42/42 and
  Boundary 39/39 pass. The 1440p A/B is 6.60x its A/A motion floor. Proof:
  `art/renders/dream_profile_juno_n12/README.md`. This is dream-profile proof,
  not a waking Juno case.
- **N13 DONE 2026-08-20 — MAE SURVIVES TWO HISTORIES.** Slot 4 carries Mae's
  62-second ceiling, borrowed silhouette, distinct shared pursuit and exact
  truth “Contradiction is survivable.” Two resolved reciprocal branches return
  to one remembered junction and one stable antique id; each contributes an
  incompatible provenance without replacing the other. Only the first account
  refreshes Tenant attention and revisits are no-ops. No portal, duplicate room,
  case-specific owner, hazard or save record was added. Profile 46/46 and
  RoomBuilder 175/175 pass. Production A/A is 0.00640734; the first account is
  0.07140363 and the contradiction is 0.20516475. Proof:
  `art/renders/dream_profile_mae_n13/README.md`. This is dream-profile proof,
  not a waking Mae case. Cal is fifth and Omar sixth; their profile grammars and
  waking cases remain unbuilt.
- **N11 DONE 2026-08-20 — THE REPRODUCTIVE PATH.** The infinite path now has
  heredity and visible anatomy: bounded parent/child genomes, brood knots,
  parent umbilicals, prospective child helices, open birth-frames and sealed
  buds. One non-colliding `ArrayMesh` surface per live room, 0.065–0.105 Hz
  breathing, no camera roll or moving topology. `DreamLineageTest` is 21/21;
  production lamp/on/off evidence lives in
  `art/renders/dream_reproductive_path_v1/`. This does not silently close N10
  or the separately priced, still-unbuilt enterable RECURSION fault. Governing
  contract: `design/DREAM_REPRODUCTIVE_PATH_BRIEF.md`.

## FA — Dream fauna (FA2 COMPLETE)

- **FA0 DONE 2026-08-20 — RULING GATE.** The owner approved all five questions in
  `design/DREAM_FAUNA_BRIEF.md`: presentation owner, bestiary/register,
  harmless v1, R6 visibility, and F1/budgets. No fauna implementation is
  licensed before this gate closes. F1 alone is now licensed.
- **FA1 DONE 2026-08-20 — THE DREAM HAS A HARMLESS MICROBIOME.** Gilder's
  Buttons and four-footed Tessellates now run through one presentation-only,
  fixed-3-Hz density owner. Real lineage birth-frames publish their anchors;
  lamp/exposure feed the bounded crop and grazer records; unfed density dies
  back; the Tenant submerges nearby grazers; embrace freezes both batches.
  Two shadowless MultiMeshes add exactly 2 deep-pocket draws and 0.00–0.01 ms
  in the final same-yaw A/B, under the ruled +13/+0.5 ms ceilings. Focused
  proof is 14/14 and production A/A/A-B evidence is in
  `art/renders/dream_fauna_f1/README.md`.
- **FA2 DONE 2026-08-20 — THE HARMLESS TROPHIC LOOP CLOSES.** Wine Anemones,
  paired-helix Ribbonettes and one lens-faced animal-scale Loupe now join the
  FA1 crop/grazers through the same four-density owner and 96-instance cap.
  Five shadowless batches add only +3 submitted draws in the stable deep
  pocket (+4 in the waking view) and at most +0.15 ms across the measured
  stations, under the ruled ceilings. Focused proof is 16/16 and production
  A/A/A-B evidence is in `art/renders/dream_fauna_fa2/README.md`.
- **FA3–FA4 — DEFERRED BREADTH.** Succession and hyperdimensional families,
  then separately ruled audio. Dangerous fauna are excluded and require a
  future Gate-C-priced `DreamHazard` ruling.
- **FA-V0 DONE 2026-08-20 — VISUAL-SYSTEM COMPATIBILITY AND OWNER RULINGS.** The owner-
  directed silhouette/texture/style addendum is ingested in
  `design/DREAM_FAUNA_BRIEF.md` V1–V9. Before changing landed FA1/FA2, reconcile
  three real seams: `dream_fauna.gdshader` currently emits a small amount of
  gold/wine light although the new law says metallic gold never emits; each
  family currently owns a `ShaderMaterial` instance; MultiMesh custom data has
  four floats. Specify a packed vertex/custom channel and shared-shader-code
  boundary, prove dark readability without reopening R1–R6, and retain the
  96-instance/+13-draw/+0.5 ms contracts. Brief V9 closes the creative tension:
  FA3 names are style-approved but inclusion stays gated; the Loupe gets one
  carnelian anatomical iris without hazard ornament; the Bezel Beetle contains
  a shader-faked tiny Orison room; bounded family materials are allowed;
  PEARL life may cluster for readability; Deep Koi needs no GLB; and only tiny
  cute geometry may exceed 1 Hz. V10 records the completed adversarial audit:
  migrate to unshaded lamp-cone evaluation, expose bounded family materials to
  the existing root owner, adopt the exact packed instance/vertex-channel
  contract, preserve five batches and prove dark/edge/full-beam output against
  an equal-interval A/A floor. Its pre-C1 commensal appendix is superseded by
  landed C1 and changes nothing. Before FA-V1 the owner must rule: in-engine
  cached ArrayMesh parts versus V7's Python/Blender GLBs; the proposed lineage
  `0.018` < fauna `<= 0.10` < hazard `0.55` dark-glow law; and whether the
  legacy comparison selector survives through FA-V3. **Ruled:** cached in-engine
  ArrayMesh kit with named GLB exceptions; `0.018 < fauna <= 0.10 < 0.55`,
  tunable downward by proof; legacy selector removed at FA-V3 closeout.
- **FA-V1 DONE 2026-08-20 — PROCEDURAL CLOISONNÉ PART KIT AND SHADER.** The
  lighting model and packed channels now run on all five landed
  batches; gold has no emission or dark response, bounded wine survives
  darkness, and the unchanged root feeds the five surface materials through
  zero-draw binding nodes. Permanent batch `material_override` was measured and
  rejected at +24/+25 waking calls; the proved binding is at most +3 calls and
  0.01 ms. The cached in-engine kit now proves five attributed, one-surface,
  pinned-hash silhouettes at 128–702 triangles. Twenty-one focused checks, all shared dream
  regressions, WalkTest FAST/FULL and 24 production frames pass at
  `art/renders/dream_fauna_v3/README.md`. Slice C migrated Buttons,
  Anemones, Ribbonettes and Loupe. Compact half-float `CUSTOM0` is required:
  full float produced +23/+24 waking calls and indexing produced +45. The implemented order was
  to migrate only the lighting model
  and packed channels on the existing geometry: one maintained fauna shader
  plus include, one shared encoder/decoder, family material overrides visible
  to the existing molten collector, and a production-root three-light harness.
  Do not touch the lineage shader, dream root, room builder, lineage body,
  DreamWalk, profiles, GLBs or imports in this first slice. Then prove the ruled
  part pipeline on Tessellates alone before migrating the other four families.
  Build the remaining procedural forms from the landed cached
  curve/lathe/ribbon/aperture/gem kit with vertex region, curvature and joint
  weights and no bitmap skins or UV unwrap; Deep Koi remains a later named
  exception. Continue the shared cloisonné fauna include from
  GROUND/WINE/GOLD plus exactly EMERALD/CARNELIAN/LAPIS, habitat motifs,
  bone-lite gait, anisotropic groom, safe spatial moiré, wet transmission and
  the inverse-signature law: fauna cast no shadows; only the Tenant does.
  **DATED AMENDMENT 2026-08-20 — LOG, DO NOT DELETE:** “no bitmap skins” above
  records the FA-V1 checkpoint, but is no longer a forward constraint. Owner
  direction now permits AI-derived substance plates through the procedural
  masks; procedure still owns every semantic line, region, state and danger
  cue. `DreamFaunaTest` now records the same amendment rather than asserting
  sampler absence.
- **FA-V2 DONE 2026-08-20 — MIGRATE THE LANDED FIVE WITHOUT CHANGING THEIR GAMEPLAY.** Replaced
  primitive Buttons, Tessellates, Wine Anemones, Ribbonettes and Loupe
  presentation with the approved PEARL/HAND/CAT silhouettes while preserving
  the same density owner, birth frames, feeding, pursuit noninterference,
  Tenant hush, capture freeze, forgetting, harmlessness and save boundary.
  The production control proves no case-specific fauna owner or second ecology
  record; gameplay transforms, densities and save ownership remain invariant.
- **FA-V3 DONE 2026-08-20 — THREE-LIGHT STYLE PROOF AND CLOSEOUT.** Every migrated family has dark,
  beam-edge and full-beam production frames plus equal-interval A/A control.
  Silhouette, rim and pattern remain family-distinct; the proof enforces 70/20/8/2,
  one jewel organ, fixed scale classes, safe motion/luminance bands, no white,
  and no harmless decorative eye motif unless FA-V0 explicitly rules the Loupe
  exception. Focused/shared regressions, Walk FAST/FULL, A/A and same-build
  performance pass. The owner accepted the rendered silhouettes. Closeout
  removed `FAUNA_STYLE_LEGACY`, its callable selector and the legacy shader;
  the historical comparison PNGs remain evidence, not configuration.
- **FA-V4 DONE 2026-08-21 — COLLISION-FREE DREAMWALK INSPECTION.** DreamWalk's
  `F` now also names the nearest fauna instance in the crosshair cone through
  `DreamFaunaDirector.inspect_ray`, an analytical pick over the director's own
  submission record bounded by the real physics hit: family and batch slot,
  raw and decoded packed genome with named flags, live room key and density
  record, material facts (unset uniforms fall back to the shader default),
  shader path, compile state and shadow setting. `DREAM_WALK_PROBE=<dir>` is a
  windowed self-check that stands at the nearest creature, presses F and
  exits 0 only if the pick, compile state and GPU buffer agree. No collision,
  per-creature node, pathfinding or production UI was added; the suite asserts
  node/collision/light counts, realization signature and plan bytes are
  unchanged. Two pre-existing DreamWalk faults were fixed in passing
  (`int(null)` on every motif-less shader material, and `pad_decimals`
  truncating vectors). **Measured in passing:** on the Compatibility renderer
  `INSTANCE_CUSTOM` is four truncated half-floats, so the FA-V1 "two exact
  bytes" claim holds for the high byte only; the low byte (emergence,
  activity, pattern_jitter — presentation only) is quantized to 8–32 steps.
  `DreamFaunaChannels.compatibility_half` models it and the probe measured
  the model bit-exact against the buffer. DreamFaunaTest 28/28, Pursuit
  39/39, SurfaceTarget 105/105, WalkTest FAST PASS. Proof:
  `art/renders/dream_fauna_fa4/README.md`.
- **FA-V5 — LATER-FAMILY STYLE BREADTH (BLOCKED BY FA3 RULING).** Only after
  the FA3 owner gate, apply the style matrix to Jewelfruit, Spiralings,
  Chandelettes, Bezel Beetles, Deep Koi and Parliaments. Negative-space Koi,
  gestalt shards and the one recession-band gem window remain presentation
  techniques, not new cameras, worlds, hazards or topology.
- **IR-V0 — DREAM IRRADIANCE COMPATIBILITY GATE (DONE).** V12–V13 of
  `design/DREAM_FAUNA_BRIEF.md` ingest the
  three-state surface doctrine and unreliable service lamp. Review the exact
  compatibility design in `design/DREAM_IRRADIANCE_COMPATIBILITY_PLAN.md`
  before implementation. It evolves every dream surface continuously from
  neon anatomy on black, through translucent veins/wet rim, to molten full
  beam, using one pointwise scalar and one shared genome look-space. The
  proposed no-draw seam expands the existing exposure volume R8 to RG8: R
  remains durable exposure, G becomes reversible slope-limited direct
  irradiance; existing lamp uniforms and fauna packed channels remain intact.
- **IR-V1 — THREE-STATE SHARED SHADER PASS (DONE).** The common irradiance
  helper and genome controls now run through Klimt architecture, lineage and
  fauna without a new material, shader variant, sampler, draw, texture file or
  owner. Tenant shadow-only uniqueness, life-below-danger, the star/bloom
  ceiling, R1–R6, fauna gameplay/caps and every collision/topology/save
  boundary remain intact. The production harness proves a wall and one
  Tessellate through five-step blend sweeps plus equal-interval A/A.
- **IR-V2 — UNRELIABLE LAMP PRESENTATION (DONE).** The
  existing PlayerController lamp transient owner absorbs a deterministic
  campaign-seed/run-clock gutter below the unchanged switch boolean. Target
  `0.58..1.00`, mean `0.79 +/- 0.02`, maximum slope `0.30/s`, components below
  `0.75 Hz`, and `0.88..1.00` reach. Add a diagnostic phase pin, boundary tests
  proving zero Juno edges/pursuit/hazard changes, deterministic exposure, a
  fixed-camera luma trace, hazard-floor readability, energy-weighted Juno
  sustain with its mean-time retuned honestly, and a steady/gutter long-shadow
  beauty pair. The 108-second production trace measures `0.58..0.9998`, mean
  `0.7904`, maximum sampled slope `0.1474/s`, dominant `0.0554 Hz`, and no
  zero. Focused IR proof is 16/16; Exposure is 35/35; all 538 shared dream
  checks pass. Dream perf is 0/4 over budget at 2.21–2.44 ms with the existing
  48/77/133/172 calls. WalkTest FAST passes at x8/480; the FULL attempt was
  terminated without a result at the mandatory 60-second process limit, so no
  fresh FULL claim is made. Proof: `art/renders/dream_irradiance_v1/README.md`.
- **INC-V7 — CAL SURFACE INCARNATION (DONE).** Cal replaces Mae with exactly
  his active 17-map bundle through the same cache, shader include, collector,
  fauna and production root. Four existing thresholds receive a fading
  broadcast, the fifth drains irreversibly, and only the first handoff informs
  pursuit; topology, collision, hazards, room identity, saves and the disabled
  waking case remain untouched. Dial glass, bakelite, wax groove, valve mica,
  completed amber phrase, black wake, warm pressure and five fauna costumes
  are rendered with an A/A control. Proof:
  `art/renders/dream_incarnation_cal_v7/README.md`.
- **INC-V8 — OMAR SURFACE INCARNATION (DONE).** Omar replaces Cal with exactly
  his active 17-map bundle through the same owners. Every revisit adds one
  visible impossible fault to the stable room-machine without changing doors,
  topology, collision, hazards, identity or saves. Fault revelation does not
  refresh pursuit, so moving on preserves ordinary distance and inspection
  spends ordinary pursuit time. Tool steel, fatigue fracture, never-setting
  solder, workshop enamel, honest seam, laid-down pressure and five fauna
  costumes are rendered with an A/A control. The waking case stays disabled.
  Proof: `art/renders/dream_incarnation_omar_v8/README.md`.
- **INC-V9 — SIX-CASE PRODUCTION PROOF (DONE).** Joined contact sheets retain
  every case's production-root A/A, dark/oblique/molten ordering, five blends,
  signature and all fauna families. A paired six-case replay audit proves
  identical plan/pursuit/collision/hazard facts, clean save boundaries, no new
  owner and exact active-only 17-map / 96 MiB residency. All motion is sub-1
  Hz; per-case proofs retain anti-tiling, life-below-danger and shadows-only
  Tenant evidence. The six-case windowed benchmark is 24/24 under 16.6 ms,
  worst 2.87 ms. Proof: `art/renders/dream_incarnation_v9/README.md`.

## M — Materials and textures

- **M1** Supertiles and stable per-wall UV offsets. Explicitly **not** part of
  the plaster repair, which was fixed without them — an optional later
  anti-repetition enhancement, with a real VRAM cost to decide first.
- **M2** `family_mean_spread` is defined on the compiler side but has never run:
  one texture per material means no family to compare. If the planner ever emits
  texture variants, that gate is unexercised.
- **M3** Compiler textures are 128² at roughly 64 px/m, which is the deeper
  reason features come out large relative to the tile.

### M-AUDIT — material use audit (2026-08-17) — RAN, AND OVERTURNED ITS OWN PREMISE

**This entry previously claimed the pipeline had a hole. It does not, and the
claim was mine.** It was written from counts taken over the wrong sets, and a
six-lens audit plus direct measurement killed it. Recorded here in full rather
than quietly deleted, because the shape of the mistake is worth keeping.

What is actually true, each number computed:

- **The building is fully textured.** `build_orison.py:555` wires albedo (sRGB),
  roughness (non-colour) and a tangent normal map into every material before
  export. Of 249 catalog materials — 105 authored plus 144 `_b`/`_c`/`_d`
  variants auto-expanded at `build_orison.py:61` — **237 map to a real texture
  set and 12 are deliberately shader-only** (`glassish`, `screen`, the `fx_*`
  family). Zero missing maps, zero unmapped, zero orphans. It cannot silently
  degrade: `_validate_texture_catalog()` at `build_orison.py:117` checks
  coverage in both directions and `SystemExit`s the build.
- **There are two texture routes, not one.** Blender-built architecture is
  textured through the glTF. GDScript-built props go
  `GODOT_STAGE` (24 keys) → `T_ai_materials_*` → `RUNTIME_POLICY` (35) →
  `MatLib`. `GODOT_STAGE`'s own comment says why it is small — it lists
  surfaces that live *only* on GDScript props, which the Blender build never
  sees. It was never meant to carry the building.
- **No prop falls back to flat colour.** All 27 distinct material names
  requested across 178 request sites resolve to a textured set. The one dynamic
  site that could miss handles it deliberately: `elevator.gd:257` checks
  `albedo_texture != null` and builds its own rather than mutating the shared
  cached instance.
- The library is **not** uniformly 1024². `SHIP_PX` is albedo/normal 1024,
  roughness/height 512; 27 directories ship odd sizes (317², 322², 350², 690²,
  902², 972²).
- Normal maps are correctly OpenGL +Y across all 988 importers. That fear was
  unfounded; do not re-raise it.

**The lesson, which is the fifth time this project has learned it: the
instrument was broken, not the subject.** "105 catalog entries carry no texture
reference" is true and means nothing — the build side is exactly where that
catalog should be read, and it wires real textures from it. Before reporting a
pipeline as broken, find the path that *does* work and prove the surface is
flat on screen.

The audit did find one real defect, and it is a picture defect. See MP below.

### M-COVER — rethink coverage (owner request 2026-08-17; FRAMES DELIVERED AND **ADOPTED BY THE OWNER 2026-08-21** — "1 yes")

- **MC-P DONE 2026-08-21 — M-COVER INTO PRODUCTION.** `FloorCoveragePass` at build gives all 26 floor surfaces the promoted `floor_coverage.gdshader` with their own maps: cell-snapped hex for terrazzo (3 cells; `_c` 2), board rows for oak (14/tile, seams along V), plain hex for ceramic and concrete. Same surfaces and draws, no new texture; `FLOOR_COVERAGE=0` is the A. Before/after pairs at `art/renders/material_coverage_m/production/`; WalkTest FAST and LightingAudit PASS; 1440p perf A/B inside run noise. **Observed in passing for §P:** `Perf.tscn` at 1440p reports 6/11 waking stations over 16.6 ms on this machine in both the before and after runs (lobby 27–30 ms, atrium 41–43, street 38–40) — needs a quiet-machine rerun against the recorded gate numbers.


**What the frames say** (`art/renders/material_coverage_m/README.md`, nine
options × four stands from one camera each, production fixtures and the
carried torch, GPU medians in every label): the repetition the owner sees is
the **floors** — walls are per-wall compiled finishes and do not tile. The
terrazzo is one 4 m tile holding a 3 × 3 lattice of 1.33 m brass-divided
cells, so the generic tricks fail on it: mirror jitter doubles the edge strip,
hex-stochastic ghosts the lattice. **Cell-snapped hex** (three taps whose
offsets are snapped to the tile's own cell grid) keeps the lattice crisp and
shuffles the aggregate — the crack that showed in every tile shows once. For
oak, **per-board-row offsets along the grain** (one tap) keep every board
edge and remove the tile-period joint line, where hex cuts boards into
mis-registered segments. Self-detail at a second frequency adds grain but not
variety; supertiles were not needed. **Cost:** every option is within
+0.4 ms GPU of shipping at three stands and draw calls are unchanged; at the
lobby all probe variants including the one-tap control read +0.9–1.6 ms, an
order/thermal effect shared by the control, not a trick's price. No new VRAM
in any option. Per-room UV seeds were priced, not framed: they need the
builder to split floor meshes per room (≈ +16 draws per storey category) and
the same trick is reachable in-shader by hashing the room cell. The probe
shader and harness are `game/tests/coverage_probe.gdshader` /
`CoverageShot.tscn`; production adoption is one material class per floor
set and waits for the owner to pick from the sheets.

Original request, kept for the record:

> "rethinking our general coverage solutions as the tiling is not doing for me
> anymore in many cases."

Current surfaces are triplanar-projected repeats and they **read** as repeats.
M1 above proposed supertiles and was deferred on VRAM; that decision predates
both the dream shader and the fractal, and should be reopened rather than
inherited. Consider and *cost* each:

- Triplanar with per-axis scale and rotation jitter (cheapest, no new VRAM).
- Stochastic / hex-tiling to kill visible repetition outright — three samples
  per surface, so price it against §P's submission-bound frame before falling
  in love with it.
- Detail maps at a second frequency, so close-up and mid-distance do not share
  a feature size. This is M3's problem stated as a solution.
- Per-room UV seeds, so no two rooms tile identically.
- Decal-driven variation over a plain base (`atmospheric_decal_pass.gd` already
  exists and is the template).
- **The free one: the fractal already hashes a per-room id.** `DreamAtlas`
  computes a stable 64-bit identity per room and nothing downstream uses it for
  texture variation. A per-room seed is sitting there costing nothing.

Bring frames, not adjectives. Two shots of the same corridor under each option
beats any amount of argument about which sounds better.

### LF — THE LIVING FIELD (owner direction 2026-08-22)

> "I want it to flow over every nearby surface continuously, with an active,
> animated edge, leaving a viscous stain where it approaches and recedes like
> an active living thing; research how slime molds grow and design a
> procedural growth and spread system from that."

- **LF-1 DONE 2026-08-22 — THE ENCROACHMENT AS A SLIME MOULD.** Research
  and design in `design/LIVING_FIELD_BRIEF.md` (Physarum: shuttle streaming,
  fan front and vein network, chemotaxis and withdrawal, the slime trail as
  externalised memory — Reid 2012; the Jones 2010 particle model).
  `LivingField`: a 0.25 m 3-D field per case flat (trail / body / stain),
  Physarum agents in 3-D with a budget from the case's intensity, the body
  persisting for minutes and receding on starvation, the stain repelling
  and outliving it, a 14 s shuttle pulse; amortised relaxation, ~4 ms per
  worst-case tick. The surface's `living` state samples it on every material
  the case reaches: the body as the case's substance with a fizzing,
  fingering edge breathing with the pulse, the stain as a viscous film.
  `LivingFieldTest` 10/10; `art/renders/living_field/README.md`
  (2A at 3 / 15 / 45 s). `LIVING=0` restores the static encroachment.
- **LF-1b DONE 2026-08-22 — ANYWHERE, RADIANT, POOLED, A GRAVITY OF ITS OWN
  (second ruling).** One field per storey with a source per case and a
  per-source tint; every layered material on the storey binds it (walls,
  finishes, floors, trims, every prop); a volumetric glow in the surface and
  up to three OmniLights per storey at the organism's nodes; gravity pulls
  every heading and the body pools on the floor; `gravity_at`/`os_gravity`
  — the building's down bent by a drifting fbm with time as the fourth axis
  — sets pull, appetite, drips, lean and pooling; the dream's flesh and leaf
  where the body has held. `LivingFieldTest` 14/14; only the player's
  storey ticks in play. `art/renders/living_field/README.md` v2.
- **LF-2 DONE 2026-08-22 — THE GRAMMARS RIDE THE ORGANISM.** The surface
  samples the field before the grammar runs and hands `os_encroach` the
  organism's sheet (`ride`); every grammar's spread is
  `max(static × 0.45 foothold, organism × 0.8)`, so Peter's docket is filed
  where the body is, Juno's bands stand where it stands, Cal's arcs complete
  around it, Omar's cracks load where it loads, Mina's wick marbles inside
  it — and the body paint is a wet glaze over the ink where the grammar has
  drawn (`paint = living × (1 − membrane × 0.75)`) instead of a tint that
  flattens it. A grammar now shows on a foreign organism in the flat too
  (Juno's bands on Mina's violet). Taste fix with it: the stain's drip
  relief only where the film is thick (it read as contour rings across
  every ceiling). `art/renders/living_field/lf2_ride/sheet_lf2.jpg`; parse,
  encroachment 13/13, living field 14/14, WalkTest FAST green.
- **LF-3 DONE 2026-08-22 — THE ORGANISM IN SOMEONE ELSE'S FLAT.** Owner
  ruling: *"Juno will report it and it has the chance of making a fixable
  condition happen in the area."* `OrganismIncidents`
  (`game/scripts/reality/organism_incidents.gd`): a 2 Hz survey of whose
  body is inside whose flat on each living storey; a foreign organism held
  in a flat (≥ 6 live voxels for 20 s) makes that flat's resident REPORT it
  — a simple work order on the WorkOrders spine in their own voice (Juno:
  the patch cables; Lena: the skirting; Peter: a form), never for their own
  organism — and the report rolls a seeded 55 % chance (again every 45 s
  while it stays) of a FIXABLE CONDITION: the nearest domestic appliance
  goes to `FunctionalProp.FAULT` (Omar's intrusion fault) with a service
  point on it; E restores the appliance, closes the order and REPELS the
  organism from the flat (`LivingField.repel`: body scrubbed, agents
  starved, stain raised — the slime it avoids keeps it out). A report with
  no condition closes itself once the flat has been clear 30 s; 120 s
  cooldown per flat; ledger `organism_incidents` in RealityState, unfixed
  conditions re-arm on load. `OrganismIncidentsTest` 18/18; fired unprompted
  in WalkTest FULL (Lena 2B, Juno 2C). `ORGANISM_INCIDENTS=0` off,
  `ORGANISM_CONDITION=1|0` forces the roll, `ORGANISM_FAST=1` 2 s dwell.

### TB — THE TENTACLE, MODELLED IN BLENDER (owner direction 2026-08-22, MAJOR)

Ruling verbatim: `design/DREAM_TENTACLE_BLENDER_BUILD.md`. Take what the
procedural build learned and rebuild the creature as a **layered
deformable model**: the flesh is the load-bearing deformation mesh; eye,
suckers, gold skeleton, crystals, cilia and membrane are separate systems
constrained to it. The acceptance rule is the last line of the ruling —
**the finished model must look impressive in flat grey**, because shaders
reveal anatomy and must not be responsible for inventing it.

- **TB-1 OPEN — the neutral cage.** 1.6 m straight along +Y, 20–28
  longitudinal sections × 16–24 around, with the regional cross-sections
  already interesting BEFORE subdivision: muscular asymmetric root,
  broad/flattened proximal, the ocular station swelling at 42 %, a
  compressed post-eye section, a flexible mid/distal, a narrower but not
  string-like final third, a rounded tactile club. Clean quad longitudinal
  flow, density up at the orbit, bends, sucker field and root.
- **TB-2 OPEN — the real orbit.** Topology rebuilt so the socket is a
  concavity, not a sphere intersecting a tube: heavy dorsal brow, thick
  lower cushion, lateral muscular wall, asymmetric rear socket, compression
  folds radiating into the shaft. **Test: from 45° the complete sphere must
  not be reconstructible.**
- **TB-3 OPEN — the eye in four objects.** Globe (~36 mm, slightly
  irregular), a physically recessed iris with radial fibre/gold geometry, a
  pupil that is a real funnel catching no light, a separate corneal cap.
- **TB-4 OPEN — three lids with their own topology**, each visible at full
  open so the eye is never naked in a still.
- **TB-5 OPEN — 18 cilia from Bezier curves** in three collections, from
  modelled follicles, asymmetric, spring-friendly.
- **TB-6 OPEN — hero suckers**: 4–6 variants with base mound, raised rim,
  concave centre and inner lip, distributed over a ventral group in two
  staggered rows changing toward the club.
- **TB-7 OPEN — gold as an exoskeleton**: 20–40 individually recognizable
  elements, every large one rooted, each entry pushing the flesh in with a
  raised rim and compression folds so gold visibly emerges from INSIDE.
- **TB-8 OPEN — mechanical joints**: separate pieces with overlapping
  sockets so a 1–4 mm slide shows no gap; ball/socket, sliding overlap,
  nested plates, tendon into crystal hinge, telescoping spine. Grown, not
  manufactured.
- **TB-9 OPEN — dendrites by Geometry Nodes**, filling connective detail
  only; the silhouette stays art-directed.
- **TB-10 OPEN — 5–12 faceted crystal organs**, flat-shaded facets, bases
  in gold/flesh sockets, with an inner core mesh for the fake interior.
- **TB-11 OPEN — the root membrane** as its own radial mesh that can
  bulge, thin, stretch over the tip, cling and constrict.
- **TB-12 OPEN — the rig**: 24–32 deform bones (heavy proximal → ocular →
  flexible mid/distal → tip), B-Bones/spline IK, distributed twist
  (root 10 %, mid 30 %, distal 60 %), secondary rigs for eye, lids, ocular
  gold, cilia, hero suckers and membrane.
- **TB-13 OPEN — corrective shape keys** for the nine named deformation
  failures, plus 3–6 subdermal deformers for visible muscular sliding.
- **TB-14 OPEN — bake and masks**: sculpt → retopo → bake normal, AO,
  curvature, height, thickness, cavity; anatomy-following UVs; and the ten
  named vertex attributes exported so Godot never has to rediscover
  anatomy the model already knows.
- **TB-15 OPEN — clearance test** through the nine canonical poses before
  final polish.
- **TB-16 OPEN — the grey test**, which gates the whole programme.
- **TB-17 RULED 2026-08-22 — the procedural tentacle is SHELVED, and
  becomes grist.** Owner: *"let's shelve the procedural tentacle and maybe
  use it as the grist for many small tentacles we can spawn across a
  surface."* The shader-driven creature
  (`dream_tentacle_controller.gd` and its rig/behaviour/eye/gold systems)
  stops being the hero. Its real value is that it is CHEAP AND ENTIRELY
  PROCEDURAL — a limb with no authored asset behind it — which is exactly
  what a swarm needs. It is therefore re-purposed as **DF-13**, and the
  modelled creature (TB-1…TB-16) becomes the single hero.

- **DF-13 OPEN — SURFACE TENDRILS (from the shelved procedural limb).**
  Many small tendrils spawned across a surface where the Dream Field's
  cross-section meets it: each a scaled-down instance of the procedural
  rig and behaviour (a spine of a few joints, an emergence, a brief
  investigation of whatever is nearest, a withdrawal), driven by the same
  `DreamFieldState` and sharing the hero's material stack. This is what
  makes the encroachment read as **one body meeting our space in a hundred
  places at once** rather than a stain, and it answers DF-4's "high
  intensity → actual new anatomy" with anatomy that already exists.

### DF — THE DREAM FIELD (owner direction 2026-08-22, MAJOR)

Ruling verbatim: `design/DREAM_FIELD_DIRECTION.md`. *"The Dream Field is
not fog surrounding the antagonist. The Dream Field is the antagonist's
infinite body failing to fit into three dimensions."* The encroachment
stops being a shader on a wall and becomes the 3-D cross-section of the
same organism the tentacle belongs to — the tentacle is one limb pushed
deliberately through; the field is the rest of the body passing near our
dimensional surface. This supersedes the living-field's presentation
(LF-1/1b/2 stay as the growth simulation underneath).

- **DF-1 OPEN — the field itself.** `DreamFieldController` +
  `DreamFieldSDF`: a world-space scalar field `F(p, dream_w, t, seed)`
  built from smooth-min capsules, branching tubes, toroids, gyroid folds,
  flesh masses, filaments and mineral inclusions, domain-warped slowly.
  **Advance `dream_w`, don't translate**: the cross-section changes
  topology in place (`r_visible = sqrt(max(0, r_total² - dream_w²))`), so
  lobes divide, rings split, tendrils appear on both sides of a wall, and
  things vanish without going anywhere.
- **DF-2 OPEN — the air acquires anatomy.** `DreamFieldVolume`: FogVolumes
  with a custom fog shader — violet vascular volumes, gold light channels,
  **negative-density voids**, razor-thin luminous planes, 200 ms nested
  halos, travelling pressure fronts. Never purple smoke.
- **DF-3 OPEN — depth-aware reality distortion.** `DreamPhaseLens`:
  reconstruct world position from the depth buffer and distort ONLY where
  the field says, so the violation stays attached in 3-D. Six authored
  violations (refraction without glass, depth disagreement, spatial
  duplication, wrong parallax, spectral edge, temporal disagreement) — one
  at a time, never together.
- **DF-4 OPEN — incarnation, not corruption.** `DreamSurfaceReceiver` +
  world-space conversion in the layered surface: low → material change,
  medium → surface relief, high → **actual new anatomy**. Continuous
  across separate meshes because it is world-space.
- **DF-5 OPEN — three incarnation tiers.** Shader only; conforming surface
  growth meshes (folds, tendons, plaques, dendrites, vein cords) offset
  along the normal for real self-shadowing; full field anatomy with its own
  silhouette.
- **DF-6 OPEN — residue with memory.** `DreamResidueManager` /
  `DreamResiduePatch`: stamps carrying position, normal, radius, seed,
  intensity, birth time, `dream_w` at contact and material category, which
  spawn **anatomical events that interpret the object** — flesh between a
  radiator's fins, gold following a table's grain — then live a lifecycle:
  incarnation → organization (it becomes MORE coherent after the field
  leaves) → dimensional withdrawal → absence.
- **DF-7 OPEN — withdrawal is not alpha.** `DreamPhaseEvaporator`:
  cross-sectional collapse along `dream_w` (narrow, split, ring,
  disconnected islands, gone — never transparent), anatomical phase peeling
  in an impossible order, dither only in the last millimetres.
- **DF-8 OPEN — particles as cross-sectional debris.**
  `DreamBoundaryParticles`: gold fragments, membrane flakes, crystal
  facets, capillary filaments, on an nth-dimensional vector field — some
  moving toward the camera while shrinking.
- **DF-9 OPEN — the shadow tell.** Material and shadow desynchronized
  during withdrawal, with a surviving violet absence shadow. Rarely.
- **DF-10 OPEN — coupling.** One `DreamFieldState` shared with the
  tentacle: `dream_w`, `pulse_phase`, `attention`, `incarnation`,
  `mineralization`, `vascular_pressure`, `phase_instability`,
  `contact_activity`. The tentacle does not control the field; both are
  portions of one organism.
- **DF-11 OPEN — the body behind the wall.** Half a second in which a gold
  structure two metres across passes behind several rooms at once, their
  walls reacting in sequence, then recedes along `dream_w`. No hole ever
  exists. *The tentacle was never the creature — it was a fingertip.*
- **DF-12 OPEN — optional `DreamPhaseCompositor`** behind
  `DREAM_ADVANCED_PHASE_FX`, and the §17 performance strategy (a handful of
  active lobes, 4–8 lobes per receiver, pooled meshes/particles/lights/fog,
  four quality tiers).

### TL — MODEL 28-R, THE PLAYER'S INSTRUMENT (owner direction 2026-08-22, PRIORITY MAJOR)

Ruling verbatim: `design/MODEL_28R_DIRECTION.md`. *"The single most
obsessively realized functional object in the game… a machine with a
biography."* An alternate-1928 radio-telegram / electrical-maintenance /
inspection lamp that begins as real 1915–28 engineering (Eveready focusing
flashlight, Western Electric lineman's test set, Weston portable meter,
1920s crystal radio, Morkrum-Kleinschmidt printing telegraph converged
around 1926) and only gradually reveals that its engineers also built it to
diagnose faults in reality. Replaces the placeholder
`ServiceSetProp`/`ServiceSetCarrier` (424 lines of boxes and jewels).

Eight ruled phases, built in order (§76):

- **TL-1 DONE 2026-08-24 — historical silhouette.** The production-carried
  prop is now a 31.6 cm TYPE 28-R chassis with five separately owned
  landmarks: faceted focusing bezel with physical optics, arched Weston-like
  meter, glass galena detector, heavy dry-cell/service mass and mechanical
  telegram throat. Three shell plates sit on a dark internal frame with 36+
  slotted screw/washer pieces; the instrument face and wired service face are
  asymmetric. The existing lamp, radio, order and paper seams survive behind
  the new body. Focused contract: 9/9, 147 geometry owners. Forward+ production
  proof and a 0.00317172-RMSE A/A pair:
  `art/renders/model_28r/tl1_historical_silhouette/README.md`. This is the
  untextured historical chassis gate, not TL-2 mechanisms or TL-3 materials.
- **TL-2 OPEN — functional mechanism.** Flashlight + focus carriage, meter
  with damped needle, mode selector (`LINE CONT. BATT. FIELD WIRELESS
  RETURN`), tuning dial driving real capacitor plates, telegraph key,
  telegram printer, magneto crank, test leads. Success: it explains itself
  untextured.
- **TL-3 OPEN — material masterpiece.** Fifteen distinct material
  identities; nickel-over-brass plating wear, japanned lacquer, phenolic,
  leather, cloth braid, copper windings, ceramic, four kinds of glass;
  three spatial scales each. Success: a close-up still is photographable.
- **TL-4 OPEN — wear and history.** Authored, story-specific wear and a
  serialized life (a replaced crystal, one wrong-finish screw, a spliced
  cable, a previous technician's initials). Used, not "weathered."
- **TL-5 OPEN — audio and tactility.** Eight mechanical sound families,
  structure-borne transmission when held, first-person mass and inertia.
  Success: operating it unnecessarily is fun.
- **TL-6 OPEN — the RETURN subsystem.** Three-position detector turret,
  the chemical cell, violet glass apparatus, impossible galena, spectral
  inspection. The supernatural as another branch of electrical engineering.
- **TL-7 OPEN — reality inspection.** RETURN reveals Dream state THROUGH
  THE FLASHLIGHT (interference fringes, displaced outlines, geometry only
  in specular, latent writing, wrong depth) — never a detective-vision
  overlay, never a numeric readout.
- **TL-8 OPEN — the impossible telegram.** A message with no carrier, no
  line and no frequency, printed mechanically: solenoid → type → ink →
  paper. And the ruled unforgettable moment (§78): switched off, no power,
  one character struck, the needle moves, the filament glows violet.
- **TL-9 OPEN — the tentacle encounter (§77).** The meter reads flesh, gold
  and the eye differently; at the phase edge the spectrum leaves its scale;
  the creature notices the device — the eye tracks its beam, cilia react to
  the radio field, gold aligns with the receiver, the printer strikes one
  character. *The entity recognizes the machine.*

### DT — THE DREAM TENTACLE (owner directions 2026-08-22)

Rulings: `design/DREAM_TENTACLE_DIRECTION.md` (encounter and systems),
`_2.md` (hero material and anatomy), `_3.md` (Forward+ canonical).

- **DT-1 DONE — the limb through the wall.** Rig, behaviour state machine,
  contact sensor + target profiles, conversion into the living field, eye,
  halos, suckers, membrane, debug panel. `DreamTentacleTest` 20/20.
- **DT-2 DONE — Forward+ is canonical.** `compat-renderer-final` tagged;
  baselines and frametimes in `art/renders/renderer_migration/`; Forward+
  measured 2–3× FASTER on this building; fallback guard in BuildingRoot.
- **DT-6 DONE 2026-08-24 — the canonical hero pass**
  (`design/DREAM_TENTACLE_HERO_PASS.md`). P0 regional silhouette, P1 the
  gold rebuilt as twelve individual irregular meshes in five classes, P2
  the ocular station choosing the face that looks into the room and lids
  with visible resting silhouettes, P3 flesh separation (wet split from
  flesh, colour by depth, pores as darkening), P4 a physical travelling
  vascular bolus coupled through geometry, colour, SSS and film. P5/P6
  captured: eighteen acceptance stills and a 13 s player-lamp video
  (`art/renders/dream_tentacle/hero_review/`). **P7 CLOSED 2026-08-24:** the
  canonical contact sheet and eighteen frames were re-read against the brief,
  not against implementation claims. The gameplay-distance frame preserves
  regional silhouette; the settled eye frame makes the buried ocular station
  the subject; the sweep separates wet flesh, vascular depth, rigid gold,
  crystal and distal contact; and DT-5's later single-instance sequence makes
  the timing-dependent seek, flinch and withdrawal beats legible. No fourth
  source fault was invented after the three recorded P7 faults passed camera
  truth. P8/P9 are closed by DT-5's component and canonical-sequence proofs.
  **H1 DEFORMING-FLESH REST SPACE DONE 2026-08-24.** The shared surface no
  longer swims through the skinned cage: UV2 carries exact rest X/Z, strip V
  plus one bounded 8-bit residual carries Y, and the displaced ocular mask
  uses the existing anatomy alpha. All 17,115 imported cage vertices decode
  within 0.1374 mm while a distal bone moves 869.93 mm. Six production
  old/old/rest triplets clear their A/A floor; the path adds no sampler,
  material or draw and measures 1.552 ms versus the 1.553 ms control at the
  same 119 draws / 93,947 primitives. H1 still owes albedo, normal,
  detail-normal and rider UV/bakes. Proof:
  `art/renders/dream_tentacle/h1_rest_space/README.md`.
- **DT-3 IN PROGRESS — the hero material.** Real SSS (`sss_mode_skin`,
  thickness-driven transmittance), the film as clearcoat with its own
  normal, four colour frequencies, three normal scales, iridophores,
  papillae; gold rebuilt as a grown mineral skeleton (plates + dendrites +
  microscopic mineralization) with sockets in the flesh. Remaining:
  the ocular assembly (§C/§H — eye at 35–50 %, deep socket, orbital gold,
  three lids, 12+ cilia), the crystal organ (§G), the hero-patch frame set
  (§N).
- **DT-4 OPEN — QUALITY AUDIT AFTER FORWARD+ (owner 2026-08-22).** Every
  limit we imposed out of performance fear or Compatibility's ceiling —
  `max_lights_per_object`, shadow counts and atlas sizes, shadow-disabled
  fixtures, the governor's draw and prop-tier levers, `RELIEF_EXAGGERATION`
  and the parallax budget, LOD and streaming distances, the light budget in
  LightRig, disabled volumetrics/reflections — must be re-derived from the
  Forward+ numbers (corridor 13.6 → 4.6 ms GPU) and re-tuned to MAXIMIZE
  FINAL IMAGE QUALITY, not to protect a budget that no longer binds.
- **DT-5 DONE 2026-08-24 — BOBBING FOR APPLES + COMMUNICATIVE SEEK.** *"I want
  the tentacle to emerge along the EDGE of the encroachment and move along
  it like it's bobbing for apples into our reality, and the encroachment is
  the proximity to its body in the nth dimension; its emergence should
  intensify the local encroachment effect and give it more volume and
  tangibility, then pull back in. It is intentionally moving itself around
  searching the apartment building and trying to interact with the case
  owner and get them help how it can, but it doesn't understand our
  dimensional or biological limitations."* This re-frames the whole living
  field: the organism on the walls is not a slime mould the Dream sent —
  it IS the creature's body, seen where it comes close to our three
  dimensions. So: the tentacle emerges at the field's EDGE (the front,
  where the body is nearest), not at a node; it travels along that edge
  between emergences; each emergence swells the field locally — more body,
  more volume, more tangibility, the surface reading as thicker matter —
  and relaxes when it withdraws. Its errand is the case: it seeks the
  resident, tries to help by the only means it has, and its help is
  dimensionally and biologically wrong. Feeds LF-3's incidents (the
  "fixable condition" is the creature TRYING to fix something).
  **EDGE OWNER + LOCAL SWELLING LANDED 2026-08-24.** Unforced
  tentacles no longer borrow the three strongest interior nodes owned by the
  field lights. `LivingField` now caches 48 ranked source-attributed
  `body >= 0.45` isosurface fronts once per completed relaxation pass, and
  the existing placement owner chooses an exposed front at least 2 m from a
  claimed anchor before performing its unchanged real-surface raycast.
  Forced test anchors remain deterministic. During membrane bulge, emergence
  and orientation the limb now pressure-writes temporary source-attributed
  body into that same field; it births no agents, leaves no stain or save
  fact, and recedes under ordinary decay. `LivingFieldTest` is 18/18 and
  `DreamTentacleTest` is 22/22 (peak 1.00, 36 writes, 0.647 ms). A frozen
  same-process Forward+ A/A/treatment proves the bound production surface at
  `art/renders/dream_tentacle/dt5_field_pressure/README.md`: treatment RMSE is
  10.81x the live-render floor. **BOBBING/RELEASE LANDED 2026-08-24:** the first
  56% of the unchanged 3.4 s emergence interval now carries three distinct
  behind-membrane presses with full retreats and zero visible limb, then the
  chosen soft spot releases monotonically on a curve independent of visible
  length. `DreamTentacleTest` is 24/24 at 0.656 ms; one fixed-camera Forward+
  production run captures all three press/retreat pairs, release 0.19/0.45/
  0.68/0.94 and a 0.00000913426-RMSE frozen A/A control at
  `art/renders/dream_tentacle/dt5_bobbing/README.md`. **SYNAPTIC SEEKING RULED
  + LANDED 2026-08-24:** seeking is communicative sampling inspired by
  dendrites trying to form a synapse: distal micro-protrusion, dwell,
  secretion/sample, full local reconsideration, then a chosen narrow cleft,
  sequential stabilization, electrochemical pulse and secretion transfer.
  The root follows late; ban predator lunges and generic search sweeps. The
  existing LivingField conversion is the surface's wrong-dimensional response
  to that attempted communication, not a new transformer, agent or save
  owner. The behavior now performs three 0.9 s candidate-cleft cycles with
  distal sampling, dwell and full return goals before committing; contact
  emits an electrochemical event, aligns the existing vascular bolus to the
  club, briefly lights the contact organ, and CARESS emits secretion transfer
  through the unchanged transformer/LivingField seam. `DreamTentacleTest`
  passes 27/27 at 0.644 ms. One fixed-camera Forward+ run logged all six SEEK
  landmarks and both exchange landmarks; its three dwell/reconsider RMSE
  values are 0.0445907/0.0642438/0.0384303 against a 0.00000577702 frozen A/A
  floor. Proof: `art/renders/dream_tentacle/dt5_synaptic_seek/README.md`.
  **CANONICAL SEQUENCE LANDED:** one 53.7 s Forward+ production instance
  logged and captured all eleven physical landmarks from intact BULGE through
  progressive EMERGENCE, communicative SEEK, hover/exchange/secretion CARESS,
  distal-first FLINCH, curious player watch, membrane-gripped WITHDRAW and a
  sealed wall. The frozen sealed-state A/A floor is 0.00000913426 RMSE. Proof:
  `art/renders/dream_tentacle/dt5_canonical_sequence/README.md`. This closes
  DT-5 and DT-6 P8/P9. Together with the re-read P7 evidence above it closes
  DT-6, not a waking case loop.

### DO — DREAM ORGANELLE COMMUNICATION (owner ruling 2026-08-24)

- **DO-0 CANON LOCKED.** Every Dream entity — hero limb, margin palp/branch/
  cilia, flora, fauna, living architecture, case incarnation, pursuer and
  hazard — is an organelle or tissue expression of one larger
  hyperdimensional being. Local agency is local regulation, not a separate
  creature or faction. Cross-entity behavior is electrochemical signaling,
  secretion transfer, recognition, excitation/inhibition, repair, transport
  and resource allocation. Ban generic predator/prey and faction AI; apparent
  aggression must have an immune/rejection/inhibitory biological reading.
- **DO-1 COMPLETE 2026-08-24 — INTERACTION SEMANTIC AUDIT.** Every currently landed
  hero↔margin, margin↔margin, margin↔fauna, fauna↔fauna, hero↔fauna,
  organism↔architecture and pursuer/hazard interaction. Re-label each as a
  specific organelle function; identify any behavior that currently reads as
  independent animal combat or social simulation without a whole-body role.
  The map and owner-order rulings are now binding in
  `design/DREAM_ORGANELLE_COMMUNICATION.md`. No combat system contradicted the
  canon; the only vocabulary contradiction is the fauna density ledger's
  predator/consumed naming, ruled rename/reframe-only with balance and art held.
  **Semantic correction landed 2026-08-24 in `280a998`:** allocation, uptake,
  reclamation, reclaimable matter, signalling and inhibition now name the same
  byte-stable density system. `DreamFaunaTest` passes 28/28 with identical
  numeric output; no art or render behavior changed.
- **DO-2 COMPLETE 2026-08-24 — SHARED SIGNAL SEAM.** Extend the existing LivingField/margin
  broadcast/hero-event/EcologyDirector boundary with one transient signal
  packet carrying source, stimulus/function, position, strength, chemical
  family and excitation/inhibition sign. No pairwise director, agent owner or
  save record. Producers and consumers remain independently testable. The
  landed seam is a 32-slot reused ring on `DreamEcologyDirector`; the director
  stores/expires/queries only. Hero contact secretes, one idle palp probes,
  real contact recognizes once, sociable fauna presents receptors while a
  low-social individual ignores it, and neighbouring tissue answers after
  0.45 s. `DreamEcologyTest` passes 50/50; staged Forward+ proof and A/A are at
  `art/renders/dream_organelle_signal/README.md`. No attention or save seam moved.
- **DO-3 — DIFFERENT ORGANS, DIFFERENT ANSWERS (PALP / FAUNA / CILIA SLICE LANDED).** Route the same signal through
  bounded class-specific responses: palps seek/brace, cilia sample, fauna
  carry/groom/redistribute, flora open or secrete, architecture propagates,
  hero acknowledges, hazards reject or inhibit. Preserve each family's
  hyperdimensional rule and local autonomy; global synchronization remains the
  rare `DreamGlobalAttention` reveal. Deployed cilia now interpret the same
  recognition seen by fauna, close across it for 0.48 s, and return one typed
  `PULSE / VASCULAR` packet addressed to architecture. `DreamEcologyTest`
  passes 56/56 and the staged Forward+ proof plus A/A is in
  `art/renders/dream_organelle_signal/README.md`. Production
  `ApartmentEncroachment` now consumes the addressed reply exactly once and
  expresses it as local temporary `LivingField` pressure; `LivingFieldTest`
  passes 19/19 with no agents or stain added. Its visible production-root
  response remains DO-4 proof; do not claim it from the staged frame.
  **Owner ruling 2026-08-24:** flora is not blocked and does not need a new
  owner. Gilder's Buttons and Wine Anemones may become analytically
  addressable through the existing density slots; LC-5 supplies their
  opening/secretion response without nodes, collision, agents or save ids.
- **DO-4 COMPLETE 2026-08-24 — PRODUCTION PROOF.** The real Orison root now
  carries one deterministic fixed-camera conversation through hero secretion,
  palp adoption/contact, selective fauna receptor presentation, delayed
  neighbour conduction, cilia sampling and one addressed vascular reply that
  production LivingField architecture consumes once (14 existing cells
  pressurized). A real `player.world_modified` event then seizes 11/12 visible
  recipients without emitting a packet; partial release shows autonomy
  returning. `DreamEcologyTest` passes 61/61 and proves no case record,
  persistence setting, collision body/layer/mask/shape state, maze, pursuer or
  hazard owner moved. The measured A/A floor and eleven Forward+ frames are in
  `art/renders/dream_organelle_production/README.md`. This closes the shared
  downstream production proof, not the broader DO-3 recipient roster and not
  a waking case loop.
- **DO-D1 COMPLETE 2026-08-24 — FIXED BRANCH ANATOMY.** `_age()` no longer
  overwrites a newly created secondary branch with the primary appendage's
  0→1 emergence ramp. Branch `grow` is now invariant at 1.0 from its birth
  frame through unfolding, investigation, cilia work, retraction and folded
  removal; separation remains angular `unfold` only. The §12 executable proof
  asserts full-size birth data and a minimum `grow` of 1.000 across the entire
  constructed life, while its existing radius/axis checks hold volume and the
  folded arc. `DreamMarginTest` passes 59/59. No art, timing, topology or owner
  changed.

### LC — ACCELERATED ORGANELLE LIFECYCLES (owner ruling 2026-08-24)

- **LC-0 CANON LOCKED.** Every visible Dream organelle traverses accelerated
  folded/spore, bud, juvenile, mature, exchange, senescent, shed and stain/
  reclaim stages. Small lives target roughly 45–150 seconds; large encounter
  organs may hold stages for fairness. Local death is tissue withdrawal from
  our section of one being, not the death of a separate animal. Binding
  doctrine: `design/DREAM_ACCELERATED_LIFECYCLES.md`.
- **LC-1 COMPLETE 2026-08-24 — PURE LIFECYCLE CONTRACT.** The ownerless
  `DreamOrganelleLifecycle` classifies folded, bud, juvenile, mature,
  exchange, senescent, shed and stain stages; all retain complete anatomy.
  Food, ether, density, diversity and same/cross-class compatibility select
  asexual, sexual, pansexual or quiescent reproduction. Small-organ lives are
  clamped to 45–150 seconds; completed lives always increment the caller-owned
  stain record before a permitted new cohort begins. The helper owns no node,
  clock, world fact or persistence. `DreamOrganelleLifecycleTest` passes 14/14.
- **LC-2 COMPLETE 2026-08-24 — CLOSED ETHER LEDGER.** Each live fauna-room
  density now carries normalized `ethermoss`, `ether`, `living_tissue` and
  `death_stain` compartments. Light makes the mat exhale; activity inhales;
  senescence sheds; reclamation returns stain to moss. Transfers are bounded
  by their source and conserve total presentation mass over long runs. The
  same owner also advances one room cohort through LC-1 using this environment;
  no new clock, node, gas hazard, save fact or oxygen mechanic exists.
  `DreamOrganelleLifecycleTest` passes 16/16 and `DreamFaunaTest` proves the
  production density integration.
- **LC-3A / LC-3B COMPLETE 2026-08-24 — ACCELERATED FAUNA
  COHORTS.** All five landed families now derive stable transient
  `room/motif/slot#generation` addresses and staggered 45–150 second lives from
  the existing director. All eight stages are reachable; anatomy never scales
  from zero; reproduction changes only cosmetic genome salt and cannot change
  stage, family function, collision or hazards. LC-3B carries all eight stages
  through the two spare packed flag bits and gives complete tissue distinct
  sealed, turgid, uneven, mature, receptive, senescent, shed and stain
  postures/surfaces. One named production Tessellate is readable through the
  seven living stages at crouched gameplay distance; every fixed-subject ROI
  pair clears its 0.042495 A/A floor. `DreamFaunaVisibleTest` passes 21/21,
  `DreamFaunaLifecycleTest` 29/29 and baseline `DreamFaunaTest` 29/29. Proof:
  `art/renders/dream_fauna_lifecycle_lc4b/README.md`.
- **LC-4A / LC-4B COMPLETE 2026-08-24 — VISIT-PERSISTENT
  DEATH STAINS.** The fauna owner now coalesces genome, position and motif by
  lineage into bounded room memories. Ninety-one exercised deaths remain seven
  impressions, survive streaming/revisit byte-identically, clear with a new
  director and never enter `RealityState`, nodes, collision or save ownership.
  Forced overflow now proves the per-room oldest-first order and the global
  widest-room/lexical-tie order byte-identical across fresh directors. LC-4B
  spends one existing Gilder instance on a broadened violet-gold anatomical
  memory beneath its successor: no new batch, node or draw. The harness rebuilds
  a fresh production root with zero stains, prices a same-camera A/A pair, then
  photographs the first mark at 2.37× its local noise floor and returns four
  marks byte-identically after a real room revisit. Proof is at
  `art/renders/dream_fauna_lifecycle_lc4b/README.md`.
- **LC-5 COMPLETE 2026-08-24 — ETHERMOSS AND THE CLOSED BREATH.** The existing
  Gilder batch is now a broad composite mat whose count and spread follow the
  conserved `ethermoss` compartment; its complete fruiting anatomy never
  scales from zero. Every living family receives the same room `ether` byte.
  Buttons exhale an outward cold film over gold hyphae, ordinary tissue draws
  it inward, and Wine Anemones return death-stain matter through the same
  shader and owner. No gas volume, particles, node, collision, light, batch,
  draw owner or save fact was added. `DreamFaunaVisibleTest` passes 24/24,
  lifecycle 29/29 and base fauna 29/29. The travelling phase is 1.38× its
  equal-interval local A/A floor; the paired full-lamp control/effect holds 55
  draws with a +1.70% capture-process delta. Deep-gutter, lamp-off and room
  context are at `art/renders/dream_fauna_breath_lc5/README.md`. One still
  does not clear the noise floor and is not claimed; the phase pair is the
  visual proof. This also lands the approved DO-3 flora implementation.
- **LC-6 OPEN — ALL-ORGANELLE ROLLOUT.** Apply the shared stages through each
  existing owner in order: flora; palp/cilia; hero; architecture; incarnation;
  co-present pursuer/hazard. A stage vocabulary is not permission to move
  encounter timing, topology, case truth or save ownership.
- **LC-6A COMPLETE 2026-08-24 — PALP/CILIA STAGE POSTURES.** Top-level margin
  palps now draw 45–150-second tier lives through the shared eight-stage
  vocabulary. Every stage retains anatomy scale one: folded/bud reserve against
  the architectural surface, mature/exchange reach into the room, senescence
  droops and shed/stain return to a spent attached imprint. Branches do not gain
  a second life clock; their approved unfold, investigate, fine-cilia exchange,
  completion and retract sequence is classified with the same words. Stage and
  owner-clock progress reuse the two spare `palp_branch` components, so the
  existing one mesh/one draw remains one mesh/one draw with no node, collision,
  light or save fact. `DreamMarginLifecycleTest` passes 44/44, the production
  `DreamMarginTest` passes 57/57, and `ShaderParseCheck` passes. One fixed-camera
  Forward+ production-root Flat Ribbon clears its 0.000112 subject-ROI A/A floor
  by 60.80×–226.91× at every adjacent transition; exact frames and hashes are in
  `art/renders/dream_margin_lifecycle_lc6a/README.md`. **Still open in this
  owner:** environmental recruitment/reproduction and a visit-persistent
  post-removal architectural stain. Frame 08 is only the attached terminal
  posture and must not be cited as persistence proof.
- **LC-6B COMPLETE 2026-08-24 — MARGIN RECRUITMENT AND DEATH MEMORY.** A
  top-level palp now leaves a full-length, non-breathing anatomical secretion
  print in the existing margin owner before its live record is removed.
  Same-cell/family deaths coalesce; 24 visit-local records evict oldest-first,
  clear with the owner and never enter `RealityState`. The nearest eight spend
  reserved slots inside the existing forty-slot mesh, so no node, surface,
  draw, collision or light owner is added. A vacated tier slot can no longer be
  silently restocked: local field nourishment, tier density, mature same/cross
  morphology, diversity and the existing signal/cilia exchange activity select
  quiescent, asexual, sexual or pansexual recruitment through LC-1. A successor
  retains tier and organ kind/function; only bounded seed variation and
  generation change. `DreamMarginLifecycleTest` passes 61/61; production
  margin remains 57/57, ecology 61/61, shared lifecycle 16/16 and shader parse
  passes. Production-root live→shed and shed→stain changes clear the subject
  A/A floor by 348.96× and 300.12×; the stain ROI is byte-identical across its
  own A/A and after further owner work. Proof and hashes:
  `art/renders/dream_margin_death_stain_lc6b/README.md`. **LC-6 remains open**
  for flora beyond the landed fauna-owned mat, hero, architecture,
  incarnation, and co-present pursuer/hazard owners.
- **LC-6C COMPLETE 2026-08-25 — MODELLED HERO LIFE AND EMPTY SHEATH.** The
  production hero maps its approved encounter states onto all eight shared
  stages without a second clock, changed timing or anatomy scaling. Existing
  flesh and mineral channels visibly move from sealed reserve through
  perfusion, uneven juvenile calibration, mature work, cold addressed
  exchange, senescence and drained cross-section. A real secretion exchange
  selects pansexual recruitment; without one a return remains quiescent, and
  any recruited successor retains the hero's function. Complete withdrawal
  records a coalesced, visit-local empty sheath in the existing bounded
  24-patch residue draw; it never reaches `RealityState`. Focused proof passes
  10/10, the full production-root binding proof passes 7/7, hero rest-space
  remains 5/5, shared ecology remains 61/61 and shader parsing passes. Every
  adjacent living-stage frame clears its 0.0242785 subject-ROI
  A/A floor by 1.76×–6.00×. Proof and hashes:
  `art/renders/dream_hero_lifecycle_lc6c/README.md`. **LC-6 remains open** for
  architecture, incarnation and co-present pursuer/hazard owners; the landed
  fauna-owned ethermoss mat remains the current flora implementation.

### MBIO — SCALED-UP MICROBIOLOGY SENSORY PASS (briefed 2026-08-25)

Research and binding integration doctrine live in
`design/DREAM_MICROBIOLOGY_SENSORY_BRIEF.md`. The central rule is that Dream
organs do not see or hear like animals: photons become ion flux, adaptation
and motor asymmetry; sound becomes registered strain, shear, pressure and
membrane tension. Responses must show a local membrane event, finite-speed
relay and recovery. Audio playback never drives biology.

- **MBIO-1 COMPLETE 2026-08-25 — LIGHT STEP, SCANNING AND ADAPTATION.** The
  production player lamp now drives one deployed margin cilium carpet and the
  crystal-listener family through a shared ownerless receptor law: cone level
  and direction arrive quickly, adapted memory follows slowly, abrupt positive
  steps admit one photoshock, and darkness restores refractory sensitivity.
  Slow entry produces asymmetric scanning without shock; hard onset reverses
  the ciliary power stroke and the listener's internal resonator while its
  shell arrests; sustained light settles; later unreliable-lamp repetition is
  weaker. This exposed and repaired a real construction-order gap: the Dream
  field tried to bind the player before `BuildingRoot` created it, so the
  production owner now completes that binding immediately after player birth.
  The recipients add only uniform-array pose in their existing one-surface
  draws—no light, node, collision, field channel, case fact or save seam.
  Focused proof passes 16/16, production-root proof 12/12 and shader parsing
  passes. Forward+ response frames clear the 0.000000674 mean-absolute A/A
  floor by roughly 1,900–2,750×:
  `art/renders/dream_microbiology_light_mbio1/README.md`.
- **MBIO-2 OPEN — BOUNDED MECHANICAL PACKETS.** Extend the existing ecology
  signal ring rather than adding a director. Authoritative contacts publish
  impulse/scrape/sustained-hum mechanics from their real positions; receptors
  own substrate, morphology, distance and refractory interpretation. Prove
  locality, delayed propagation, deterministic eviction, recipient selectivity
  and no global-attention, pursuit, case or save mutation.
- **MBIO-3 OPEN — METACHRONAL AND ELECTROCHEMICAL MOTION.** Let neighbouring
  cilia organize through phase offsets, slow under load and locally reverse or
  arrest after a stimulus. Carry one finite-speed calcium/potassium-like band
  through existing palp, fauna and architecture materials. A simultaneous
  whole-room pulse fails the gate.
- **MBIO-4 OPEN — VESICLES, WRINKLES AND SLOW VIBRATION CONSEQUENCE.** Show
  addressed secretion as bounded membrane bleb → neck → release → uptake, and
  let ethermoss/death memory organize into branching transport wrinkles.
  Sustained vibration may bias growth or sporulation only after accumulated
  exposure; nothing dances to the soundtrack.
- **MBIO-5 OPEN — POOLED CELLULAR SONIFICATION.** Curate a small recorded
  membrane/channel/cilia/relay palette and reuse one positional voice pool per
  active room/encroachment. Prove voice ceiling, attenuation, silence for
  unknown assets, no feedback into mechanics and no per-organelle audio node.
- **MBIO-6 OPEN — INTEGRATED PRODUCTION ENCOUNTER.** Darkness → lamp scan →
  photoshock → adaptation → footfall mechanics → cilia/architecture relay →
  later vesicle or wrinkle consequence. Preserve the observation/communication
  loop; this is not combat and not a completed waking case loop.

### T4 — TEMPORAL BIOLOGY AND CONTROLLED ANACHRONISM (owner ruling 2026-08-24)

- **T4-0 CANON LOCKED.** The Dream being perceives time as a fourth-dimensional
  extent and can observe life and technology across eras and exotic higher
  space. She grows sensory life from those specimens, leaning heavily on
  microscopic mechanisms. The governing limitation is **complete access,
  incomplete interpretation**: no unearned case truth, prophecy, time travel,
  retroactive state or arbitrary future prop. Waking Orison remains 1927
  except for bounded encroachment evidence on existing historical objects.
  Binding doctrine: `design/DREAM_TEMPORAL_BIOLOGY.md`.
- **T4-1 COMPLETE 2026-08-24 — SPECIMEN LEDGER.** Twenty-three landed Dream
  organ families now record specimen, scale/era, whole-body function, specific
  misreading, runtime/proof owner, truth safety and evidence gap in
  `design/DREAM_TEMPORAL_SPECIMEN_LEDGER.md`. Its eight contradictions remain
  audit findings, not silent redesign authority; ten future recipient ideas
  remain explicitly unapproved. Integration refreshed DO-D1 and Juno T4-2 to
  their current landed status. No code, art or runtime owner changed.
- **T4-2 COMPLETE 2026-08-24 — FIRST TEMPORAL SENSORY PROOF.** Juno's existing
  delayed reciprocal partition now grows a fixed 21-receptor listening bed in
  three spatial response groups: tympanum, cochlear delay, period feedback and
  later phased-array observation embodied as one speaker-cloth/brass organ.
  The being mistakes every received channel for a request to answer. The same
  shared delay congeals it and sustained delivery releases it; no new clock,
  topology, collision, navigation, pursuit, hazard, save, screen, brand,
  future prop or owner exists. Frozen production A/A is 0.000000; partition
  and release both clear it at ~0.09694 RMSE. `DreamProfileTest` passes 65/65
  and `DreamIncarnationTest` 66/66. Proof:
  `art/renders/dream_temporal_juno_t4/README.md`. This extends the downstream
  Dream seam only, not Juno's waking case loop.
- **T4-3 COMPLETE 2026-08-24 — MAINTENANCE TEACHES THE VERBS.** Every authored
  maintenance activity now carries exactly one validated physical principle:
  radiator venting = `flow`, annunciator faces = `contact`, communicating
  boiler column = `pressure`. The schema admits only pressure, continuity,
  timing, regulation, contact and flow. These are factual waking tags, not
  input verbs or supernatural exposition, and create no Dream, case or save
  owner. `MaintenanceActivityTest` proves the mapping and rejects an arbitrary
  future reading. This supports the ruled one-third maintenance / one-third
  people-and-travel / one-third Dream observation-avoidance-communication
  rhythm without claiming the other two Service Round apparatus are live.
- **T4-4 OPEN — TEMPORAL EVIDENCE GATE.** Any new anachronistic element must
  document observation → misreading → embodiment, its existing runtime owner,
  its case-truth safety and its no-save/no-time-loop boundary. Reject arbitrary
  future silhouettes and decorative cybernetics even when visually attractive.

- **DE-§12 STEPS 8/9 INTEGRATED 2026-08-24.** Cherry-picked isolated commit
  `2bb81cf` as `90377f0`: secondary-branch cilia deploy as fixed-length folded
  anatomy, task completion owns a real beat, and retraction/folding follow it
  in order. `DreamMarginTest` passes 57/57; production proof and measured price
  are in `art/renders/dream_ecology_step12_cilia/README.md`.

### CT — CRITTER SKINS (owner direction 2026-08-21)

- **CT-1 DONE 2026-08-21 — FAMILY SKIN ATLASES FROM THE PLATES.**
  `art/tools/build_fauna_skins.py` composes one 1024² atlas per family
  (albedo, normal, mask R gold / G jewel / B wear) from the six cases'
  substance plates in the fauna's own `CUSTOM0` (body_t, angle) space;
  `dream_fauna.gdshader` samples it (wine-modulating, wire mask joins the
  procedural wire, normal via a derivative cotangent frame, NORMAL only —
  the fauna contract forbids PBR writes), bound per batch by the director
  (`FAUNA_SKINS=0` restores the procedural skin). Studio proof
  `DreamFaunaSkinShot.tscn`; `art/renders/dream_fauna_ct1/README.md`;
  DreamFaunaTest 28/28.
- **CT-2 — FA3 FAMILIES (OPEN).** An atlas recipe per sketched family as
  its part kit lands; the tool takes a recipe row, nothing else changes.

### MX — LAYERED SURFACE SYSTEM: maximum perceived geometric complexity per polygon (owner direction 2026-08-21)

> Extend our Godot material-library architecture around **maximum perceived
> geometric complexity per polygon**. Treat materials as layered surface
> systems, not simple albedo textures: albedo + OpenGL normal +
> height/parallax/POM + ORM (AO/roughness/metallic) + detail albedo/normal +
> reusable grayscale masks + emission, with optional clearcoat, anisotropy,
> SSS, decals, triplanar/world-space variation and shader noise. Make masks
> first-class reusable controls — damage, grime, moisture, oxidation, wear,
> corruption, gilding, emission, translucency, microdetail — that selectively
> blend secondary material states. Alpha-scissor/hash for genuine cutouts
> (torn edges, holes, mesh), not alpha blending. Tiers: microdetail → normal;
> convincing shallow volume → height/parallax; silhouette/deep volume → real
> geometry. Avoid polygons for what a shader sells, and automatically avoid
> aggressive parallax where grazing-angle artifacts or cost outweigh it. Even
> simple architectural meshes should read as deep, tactile, aged and
> materially complex under a moving flashlight, preserving the Orison's
> colour/art direction, with supernatural states layered on procedurally.

What already exists and folds in: the ingest derives height/normal/roughness
per set (`ingest_material_sources.py`); wall finishes are per-wall compiled
RGBA+normal+roughness with a survival mask in alpha (a mask already);
`floor_coverage.gdshader` (MC-P) and `wall_encroachment.gdshader` (WK-1) are
two material STATES bolted onto StandardMaterial3D surfaces; the dream's EN-1
probe is a third. MX makes them one system.

- **MX-0 DONE 2026-08-21 — SURFACE CENSUS.** `game/tests/SurfaceCensus.tscn`
  measures the booted building: 9,242 surfaces, 9,162 StandardMaterial3D /
  80 Shader; architecture albedo+normal+roughness only (AO 0, detail 0,
  height on 36 surfaces via `HeightmapPass`), 4,113 `MatLib` triplanar
  props, one authored mask (finish survival alpha), two states (coverage 26,
  encroachment 22), 803 alpha-blends vs 157 scissors. Swap point = the
  per-storey shared `M_<key>` materials (567) + `MatLib.get_mat`. Order for
  MX-4 decided: masonry + finishes -> floors -> trims -> glTF furnishing ->
  MatLib props. `art/renders/surface_census_mx0/README.md`.
- **MX-1 DONE 2026-08-21 — `orison_surface.gdshaderinc` + opaque / cutout
  shaders.** The stack as specified: base (R / glTF-G / packed ORM), mesh-UV
  or triplanar projection with the M-COVER modes ported, height calibrated
  in millimetres with offset or POM and the governor built in (grazing,
  distance, `parallax_budget`), self-detail or dedicated detail maps,
  emission, eight first-class mask fields (texture or procedural) each
  blending a state (damage tears cutouts, grime in cavities, moisture, wear
  on crests, oxidation, gilding, corruption = the dream's flesh, emission),
  BACKLIGHT / clearcoat / anisotropy, `debug_view`. Proof harness
  `SurfaceShot.tscn` (8 stands, two-pass GPU medians) and the record
  `art/renders/orison_surface_mx1/README.md`. Found and fixed on the way:
  height maps never spanned their range (runtime p5..p95 calibration) and
  the per-storey family variants had no height maps shipped (42 added).
  Still separate shaders: floor coverage and the 22 encroached finishes
  (MX-4 folds them in). Original spec follows.
- **MX-1 spec (kept for reference).** One maintained layered shader:
  albedo, OpenGL normal, height with parallax/POM, packed ORM, detail
  albedo/normal at a second frequency, emission; optional clearcoat,
  anisotropy, wrap-SSS; world-space box projection with the M-COVER
  anti-repetition modes as options; shader noise for variation. Mask slots as
  samplers OR procedural fields: damage, grime, moisture, oxidation, wear,
  corruption, gilding, emission, translucency, microdetail — each blending a
  secondary state (albedo/ORM/normal/height deltas) by its mask. Alpha
  scissor/hash for cutouts. Coverage, encroachment and the dream's flesh/skin/
  weld layers become states of this shader, not separate shaders.
- **MX-2 ruling 2026-08-21 (owner, on the MX-1 frames): "exaggeration is cool" —
  relief ships at 2.5x the calibrated millimetres (`SurfacePass.RELIEF_EXAGGERATION`).**
- **MX-2 DONE 2026-08-21 — THE TIER RULE AND THE PARALLAX GOVERNOR.** In the
  shader: grazing fade, distance fade, `parallax_budget`. In the building:
  `SurfacePass.govern` reads the viewport's measured GPU time every 0.5 s and
  steps the budget 0.25 down over 14 ms / up under 11 ms, pushed to every
  layered material (proof: at a 1 ms target it walked 1.0 → 0 in four steps;
  `SURFACE_TARGET_MS`, `SURFACE_BUDGET` pins it). The tier rule as shipped:
  microdetail → normal (every class); shallow relief → height, POM on walls /
  floors / wainscot, offset on ceiling / stairs / slabs / stone trim, relief
  per key in `SurfacePass.RELIEF_MM` × 2.5 (ruling); silhouette → geometry
  (no class crosses 25 mm). Draw-heavy tiers (furnishing, props) are opt-in
  by the same budget logic until the governor can spend per station. Spec
  kept below. Microdetail →
  normal; shallow volume → height/POM; silhouette → geometry, written down per
  class with the threshold in millimetres. POM auto-fades by view angle
  (grazing) and distance, and a per-station cost governor disables it where
  the measured frame cost exceeds the budget — the probe measures, the
  material obeys. Never a polygon for what the shader sells; never a shader
  for a silhouette.
- **MX-3a DONE 2026-08-21 — SOURCES SCRUBBED OF THE GENERATOR WATERMARK.** `scrub_source_watermarks.py` detects the sparkle at its fixed inset and unblends it from 61 Gemini sources (63 ChatGPT false positives rejected by measured alpha); 147 sets re-ingested and rebuilt. Run it on every new drop before `ingest_material_sources.py`.
- **MX-3 FIRST SLICE DONE 2026-08-22.** `art/tools/ship_surface_tables.py`
  ships all 79 catalog height maps stretched to their range, writes
  `game/scripts/generated/surface_calibration.gd` (relief_mm, tile_m per
  key; `material.json` gains relief_mm) which `SurfacePass` now reads, and
  packs the wall stencils into `textures/masks/wall_age.png` (R damage, G
  grime, B moisture, A wear) — the standing age on walls, finishes and
  floors at quiet amounts, one fetch. OPEN in MX-3: packed ORM, dedicated
  detail maps, the ingest writing stretched heights itself. Record in
  `art/renders/orison_surface_mx1/README.md` (MX-3 section).
- **MX-3 — INGEST V2 (the rest, OPEN).** Measured 2026-08-21: the ingest's heights are
  band-passed luminance spanning ~0.26 (face brick) to ~0.09 (concrete) of
  0..1 — the runtime calibrates by percentile for now; the ingest should
  write them spanning their range with `relief_mm` in `material.json`, and
  the generated set table should carry tile_m / relief_mm so `SurfacePass`'s
  two tables go away. The 42 variant height maps shipped unmipped (§MP).
  ORM packing, calibrated height scale per set
  (millimetres of relief, not "looks right"), detail maps at a second
  frequency, and a mask library generated from the existing stencil/overlay
  sources (`art/textures/wall_sources` already holds damage stencils and stain
  overlays). Sources stay scrubbed of generator watermarks
  (`scrub_source_watermarks.py`).
- **MX-4 — ROLLOUT BY CLASS WITH FRAMES (STEPS 1–3 SHIPPED 2026-08-21 via
  `SurfacePass` after `HeightmapPass`, relief at 2.5x by ruling, `SURFACE=0`
  the A: walls POM + self-detail; finishes self-detail; floors with M-COVER's
  coverage rule folded in as `COVERAGE_RULES` (FloorCoveragePass superseded,
  no longer applied) + POM + self-detail; wainscot POM; ceiling / stairs /
  slabs / stone trim offset parallax; trim / sash self-detail — ten classes.
  Frames `art/renders/orison_surface_mx1/floors/`. STEP 4 SHIPPED: glTF
  furnishing / furniture / retail / transit on the normal tier + self-detail
  — 14 classes, 1,004 surfaces on 678 materials, flat_4b 4.47 → 5.67 ms,
  gates PASS (`furnishing/sheet_flat_4b.jpg`). STEP 5 BUILT, OPT-IN: the
  batched props take the surface in triplanar mode by a deferred idempotent
  sweep after the builders settle (`SurfacePass.apply_props`, 4,274 draws on
  951 materials, pixel-identical) — but the draw-heavy tiers cost ~1 ms each
  at the 4B stand for nothing visible (a ShaderMaterial draw is dearer than a
  Standard one; props are 87 % of draws), so furnishing + props are behind
  `SURFACE_PROPS=1` until MX-2's station budget can spend it — then, by
  owner ruling ("it should reach the props"), ON by default with the
  governor's prop-tier lever, and `ApartmentEncroachment.reach_props` gives
  every layered prop in a case flat the case's states, clipped to the flat
  by the new `state_rect` (933 draws across six flats;
  `art/renders/apartment_encroachment_wk1/README.md` addendum). DONE
  2026-08-22: the 22 encroached finishes are a STATE of the one surface —
  WK-1's grammar ported into `orison_surface.gdshaderinc` as the
  `encroachment` group (`os_encroach`, membrane into the cutout alpha),
  `ApartmentEncroachment._material_for` builds through
  `SurfacePass.surface_for` with the finish recipe; `wall_encroachment.gdshader`
  kept as reference, nothing binds it; test 13/13. SIX GRAMMARS DONE 2026-08-22: `grammar` per case (wick / docket / standing wave / interference / tuning memory / fracture) with the case's tints; `grammars/sheet_six_grammars.jpg`. Found: the shader's exact `unit_rect` test had let only 2A encroach since WK-1 (other storeys' finishes sit 44 mm outside their rect) — 25 cm slack now. Metal states photographed on metal 2026-08-22 (`orison_surface_mx1/metal/`). Nothing open on this row.** Masonry and finish quads
  first (the flashlight sees them most), then floors, trims, props. Each class
  ships with before/after frames under the moving lamp from fixed stands, the
  perf station row, and an A/B switch; colour and art direction are preserved
  by construction (no albedo regrading), and the supernatural states prove
  themselves on top of the ordinary ones.

### MP — the unmipped runtime textures (FIXED 2026-08-17, verify before trusting)

**The one real defect the audit found, and it was making the game look worse,
not slower.**

Godot decides a texture's import settings when it first sees the file, and
ships `detect_3d/compress_to=1` — "the first time you notice this on a 3D
material, re-import it properly". That detection runs **in the editor**.
`MatLib` never puts a texture on a material in the editor; it calls `load()` at
runtime from a generated table. So the editor never noticed, `detect_3d` never
fired, and **90 of the 101 textures every runtime prop material uses kept their
2D defaults: `mipmaps/generate=false`.**

No mip chain is a picture problem before it is a memory one. A 1024² albedo
sampled at distance with no mips aliases, and on the triplanar surfaces MatLib
builds — corridor floors, the street — that reads as crawling shimmer whenever
the camera moves. It also silently voided
`textures/default_filters/anisotropic_filtering_level=4`: anisotropic filtering
selects *between mip levels*, so with no mips the 16× this project believes it
is spending, and which `project.godot:85` argues for specifically because
"corridor floors and the street are read at grazing angles almost exclusively",
was doing **nothing at all** on those surfaces.

Fixed by `art/tools/fix_runtime_texture_imports.py`, which derives its file list
from `material_sets.gd` so a material added to `RUNTIME_POLICY` tomorrow is
covered without anyone remembering this tool exists. 90 sidecars repaired, 90
re-imported, `--check` now passes 101/101.

**What was deliberately NOT done, and why.** The audit recommended
`compress/mode=2` to recover ~223 MB of VRAM. That is real and we are not doing
it, on the owner's ruling of 2026-08-17: *"dont worry about budget until we hit
performance issues on a desktop."* Block compression is lossy; at zero budget
pressure lossless is simply the better picture. It also sidesteps the 27
referenced textures whose dimensions are not multiples of four — block
compression cannot accept those, so a fix that flipped `mode=2` would appear to
succeed and silently leave them uncompressed. If a desktop ever does struggle,
that file is where to reverse this, and it is the single largest lever
available.

**VERIFIED 2026-08-18, with a control.** Evidence and method in
`art/renders/mipmap_verify/`. Flipping `mipmaps/generate=false` back on all 119
sidecars and re-importing moves **2.0–13.5% of pixels, max delta 62** against a
measured noise floor of **0.08–0.40%, max delta 15** — two runs of an identical
build. Thirty to a hundred and seventy times the floor.

Measuring the floor was not ceremony. The first pass showed ~13.5% for both this
and the glass A/B, which is exactly what a nondeterministic scene looks like —
traffic moving, weather drifting — and would have made both results worthless.
The scene turned out to be essentially deterministic. **Never report an A/B in
this project without shooting the same build twice first**; §P has already been
burned once by a perf "regression" that replication showed was noise.

The symptom is not staircase aliasing, it is speckle and a warm colour bias:
without a mip chain a minified texture never averages its texels, so it sparkles
and drifts off its true mean because the dark joints are missed by the sample
points. What is NOT established is which surface improved — the difference
window is street pavement, whose own materials come through the glTF and were
always mipped, so the change must arrive via MatLib-textured props in the same
pixels. That attribution was not traced.

### DP — the detail pass: making every object match its target

Owner, 2026-08-17: *"add detail to all objects to better match their targets,
both texture magic and improving the meshes with detail."* Fidelity, not
levels-of-detail — nothing here is about decimation.

**THE GOVERNING RULE, and do not quietly reintroduce a budget.** Owner ruling,
same day: *"dont worry about budget until we hit performance issues on a
desktop."* Detail is chosen by what an object needs to look like the thing it
is. Costs are recorded so that *if* a desktop ever struggles we know where the
weight went — they are not a filter. The background fact that makes this
comfortable is §P: the frame is submission-bound rather than fill-bound, so
geometry added inside a mesh that already exists and already has a material has
historically been close to free.

**The trigger condition now has an instrument, not yet a routine.** The waking
probe already includes the lobby and the 2026-08-18 dream branch establishes
1.71 ms / 45 calls before durable exposure and 1.90 ms / the same 45 calls
after it. What remains is to make those pinned A/A measurements a standing
per-session record and add a player-height carriageway station; the existing
"street elevation" eye is aerial and cannot stand in for play.

#### The measured geometry, which is lopsided

Parsed from the accessors in `game/assets/building/*.gltf`. **Corrected
2026-08-18: the first pass counted collision meshes as geometry.** Anything
whose name ends `-col` or `-colonly` is a collision hull that is never drawn,
and there are a lot of them — floor_01 alone carries 47,244 collision triangles
against 127,842 rendered.

| file | render tris | collision tris |
|---|---|---|
| floor_01 (lobby + retail street) | 127,842 | 47,244 |
| floor_02 | 72,492 | 8,148 |
| floor_03 | 73,228 | 7,992 |
| floor_04 | 73,658 | 8,328 |
| floor_05 | 70,776 | 8,220 |
| floor_06 | 70,386 | 8,700 |
| floor_b1 | 34,940 | 4,044 |
| roof | 23,676 | 2,688 |
| **total** | **546,998** | **95,364** |

**`F0x_stairs_bal` totals 186,576 rendered triangles — 34.1% of everything the
building draws.** That is higher than the 29% first quoted, because the
denominator was wrong in the other direction.

**ANSWERED 2026-08-18, and it goes the other way.** The spend is earned.
`_baluster()` at `build_orison.py:3526` builds a square die at each end, two
turned vase profiles by `add_lathe`, a twisted square centre given a quarter
turn per 120 mm, and a cast brass collar at the foot where the iron enters the
shoe rail. `BAL_PITCH` is 0.115 m — four-and-a-half inch centres, so no 100 mm
sphere passes, which is the actual code requirement for a guard. The handrail
beside it is a moulded four-course section, not a bar. The comment records the
reason it was built this way: without the collar the old 36 mm sticks "read as
dowels".

So the balusters are not a budget to raid — **they are the standard the rest of
the building should be measured against.** That inverts the plan below. The
question for every other family is no longer "what can we afford", it is "why
is this not built to the standard the stair already reached".

**But not via the "2-triangle shopfront", which was my misreading and is
withdrawn.** The 2-triangle meshes named `F01_retail_shop_*_fx_shadow` are
CONTACT SHADOW DECALS, one quad each, doing exactly the job a contact shadow
should. The shopfronts themselves are measured below.

#### The seven families, and their state

The per-family audit **did not complete** — it was killed mid-run by an account
spend limit, so what follows is the frame and the measurements, not the
findings. Treat each as an open question with a known starting point.

1. **Stairs and circulation** — the baluster question above; treads, nosings,
   risers, stringers, newels, and whatever `F0x_stairs_soffit_failed` (2 tris)
   is meant to be. The banister is a *motif* — there is a track called
   *Ribbons on the Banister* — so it earns real geometry.
2. **The architectural shell** — walls, floors, ceilings, openings. Carries the
   most screen area of anything. Key question: does any edge have a chamfer?
   Perfectly sharp edges are the loudest "this is untextured CG" signal there
   is, and a chamfer is nearly free inside a mesh that already exists. Then:
   door frames, stops, reveals, hardware; window sills, jambs, glazing bars;
   baseboards and picture rails as geometry rather than a texture stripe.
3. **GDScript props** (~60 scripts) — built from primitives: 75 `BoxMesh`, 50
   `CylinderMesh`, 40 `QuadMesh`, 23 `SphereMesh`, 11 `TorusMesh`, against only
   27 `SurfaceTool` and 5 `ArrayMesh`. What sells a period object is chamfers,
   panel lines, feet, handles, hinges, fasteners, grilles, a cord and plug, a
   maker's plate, and slight asymmetry. Almost none of that survives a box.
4. **The street and shopfronts — MEASURED 2026-08-18, and the answer is "same
   box, different sign".** Rendered triangles per shopfront: `news_cigars` 274,
   `photo_supplies` 274, `radio_service` 274, `model_laundry` 274,
   `pawnbroker` 286, `luncheonette` 560. Four are identical to the triangle,
   and their material buffers differ only by a `metal`→`chrome` swap. So the
   question DP asked has a numeric answer.

   **That is partly correct architecture and should not simply be "fixed".**
   Every trade comes out of one generator (`gen_layout.py:4375`) building one
   section: a 550 mm stall riser, plate glass to 2.05, a transom to 2.45, a
   sign band to 3.10. A real parade built at one time WOULD share a shopfront
   system, and the comment there is explicit that these are sections rather
   than painted flats. The trades are meant to be told apart by signage,
   awning, blade sign and materials, not by different carpentry.

   So the work is not "make six different shopfronts". It is: does the
   differentiation that exists actually read from the pavement, and what is
   the cheapest addition that carries trade identity? The candidates, none yet
   costed — glazing subdivision (a photographer's window is not a
   luncheonette's), what is IN the window, stallriser finish per trade, and
   whether signage is a flat quad or has dimension. 274 triangles for an entire
   shopfront next to 26,832 for one floor of balusters is the disproportion
   DP is about, and this is where it bites hardest.
5. **Furniture and fittings** — already batched per material
   (`F01_furnish_metal` 23,996 tris, `F02_furnish_wood_dark` 8,128,
   `ROOF_furnish_plant` 7,056), which is the one-material-per-buffer constraint
   at work and means adding detail to an existing piece is close to free. Does
   the furniture express *whose apartment this is*, or is every flat the same
   kit?
6. **Light, service and the building's guts** — fixtures, radiators, pipe runs,
   registers, switches, the boiler, the elevator. Small, close to the eye, and
   the things that make a building read as a building rather than a set:
   escutcheons, pipe hangers, valve bodies, register louvres, switch plates,
   chain pulls, bulb and filament shape. Silhouette is silhouette — texture
   cannot fake any of it.
7. **Texture magic** — what the surfaces are *not* doing. MP above is the first
   instalment. Still open, each needing a compatibility check before it is
   promised: **height maps** are authored for all 227 materials and
   `heightmap_pass.gd` is their only consumer — the height map never enters the
   MatLib path at all; **detail maps** at a second UV frequency
   (`detail_enabled`) are the standard cure for "reads as a repeat up close" and
   appear to be unused; **vertex colours** for grime and wear cost zero textures
   and zero draw calls; **emission** for signage, dials and the elevator call
   light; and the tiling-breakup question already open as M-COVER.

#### What the first verification pass actually showed (2026-08-18)

Shots taken at the street and the atrium, `SHOT_DIR` and `DAYNIGHT_FORCE`
being the two environment variables the harnesses read (`street_shot.gd:66`,
`day_night_director.gd:177`, which accepts `HH:MM`).

- **The glass maps ARE doing work — measured 2026-08-18, previously recorded
  here as unproven.** Flattening `generated/glass/normal.png` to a neutral
  (128,128,255), re-importing and re-shooting the same dusk stand moves
  **7.0–14.0% of pixels, max delta 62** against a 0.08–0.40% noise floor. So the
  drawn-glass waviness is not decorative-but-inert; it changes the frame.
  What was true and stays true is that it is SUBTLE BY EYE at night, and the
  earlier reasoning for why is still right — a uniform overcast sky reflected
  off a slightly bent surface is still uniform. It has most to give in a frame
  where glass reflects something structured. The A/B is how to check it without
  waiting for that frame: swap the map for a flat one, re-import, difference.
- **The atrium's "translucent hanging planes" ARE NOT TRANSPARENT AND ARE NOT A
  BUG. Recorded because I was wrong about it and the next person will be too.**
  Looking up the light court, large terrazzo and marble wedges appear to have
  the stair visible through them. They do not. Every one of the 1270 transparent
  draws in the scene was hidden at once and the wedges came back
  pixel-identical — mean delta 1.78 over the frame. They are opaque floor slabs
  and soffits seen from below in a dim court, with real railings standing in
  front of them. A low-contrast frame at 3 a.m. reads as translucency when it is
  only darkness.
  The test that settles this kind of question quickly: walk the tree, hide every
  `MeshInstance3D` whose material's `transparency != TRANSPARENCY_DISABLED`,
  re-shoot, and difference the two. If the thing survives, it was never
  transparent. Hiding candidates one at a time (glazing, the atrium shaft,
  `fx_shadow`) only ever narrows; hiding the whole class decides.

#### How we will know it worked

The in-situ practice already exists — `art/renders/insitu/shots.md` is 156 lines
of logged camera stands, and there are named review shots (`bookshelf_review`,
`boxfan_review`) showing the habit. Pick a stand per family, shoot it before,
shoot it after, and judge the pass on frames. `gen_layout.py` owns all
coordinates; generated `.json`/`.gltf` are never hand-edited, so geometry
changes go in there or in `build_orison.py`, then regenerate and re-import.

## EN — The Encroachment (owner ruling 2026-08-21; `design/DREAM_ENCROACHMENT_BRIEF.md`)

The owner ruled on 2026-08-21: M-COVER adopted; rule of cool is standing
licence for taste rows and the previously owner-gated items unless otherwise
directed; the dream's generated plates enter each case's waking apartment;
the dream is re-layered (grounded PBR base, purplish flesh, golden skin,
folding, molten golden welds that work as portals — "not a wavy golden shower
curtain"); the critters get detailed textures built from the plates already
made. The brief holds the verbatim ruling, the five-layer model and the order.

- **EN-1 — THE LAYER MODEL AS FRAMES (FRAMES DELIVERED 2026-08-21; awaiting the owner's read).** `DreamLayersShot.tscn` photographs the shipping Klimt surface and the EN-1 probe surface (`game/tests/dream_layers_probe.gdshader`: unwarped PBR base, wine/plum flesh with an edge, gold as a torn metallic skin over the flesh, a molten heat-gradient weld bead along the growth contour, a portal core in the bead) from one camera at latent/mid/high retained exposure, one layer at a time. The probe stack costs 0.70 ms GPU against the Klimt's 0.88 at the same state, no added draw. Sheet, frames, costs and what it does not decide: `art/renders/dream_layers_en1/README.md`. Next when accepted: re-skin the limbs/body from the same layers, then promote into `dream_klimt.gdshader` keeping motif only as wayfinding.
- **EN-1b DONE 2026-08-21 — THE LAYER STACK IN THE KLIMT SURFACE.** Merged
  into `dream_klimt.gdshader` after the ornament, incarnation and anatomy:
  base (raw plate, unwarped UV, own relief, not scar-gated, never on the
  eyes), flesh, skin, weld, portal from the probe; `layer_mask` 31 default,
  `DREAM_LAYERS=0` the pre-merge control. Found and fixed: Klimt wrote a
  world-space normal into NORMAL (view space) — the reason the lamp never
  reached the plaster. All dream contracts PASS;
  `art/renders/dream_layers_en1b/README.md`. The analysis that chose the
  merge follows. Not a
  switch: `_klimt_material` (dream_maze_builder.gd:634) could return the
  EN-1 probe with the same mapping `DreamLayersShot._swap_to_probe` uses
  (base maps, tile, exposure_gain), and the collector already feeds it —
  but the probe lacks `dream_incarnation.gdshaderinc`, and the Klimt
  surface now carries the six shared-dream incarnations through it, plus
  `unlit_reveal` (eyes only in light) and the scar lock (`exposure_gain`
  0 → hard step). So EN-1b is a merge INTO dream_klimt.gdshader (1,418
  lines): base unwarped PBR replacing the held-at-0.55 substrate, flesh /
  skin / weld / portal from the probe as layers between the incarnation
  surface and the ornament, the motif ornament kept as the skin's pattern,
  `unlit_reveal` and the scar lock untouched. Perf: the probe stack was
  0.70 ms vs Klimt 0.88 at the EN-1 stand. `DREAM_PLAIN=1` stays the
  control. Gates: DreamFaunaTest, the six incarnation tests, DreamWalk,
  DreamLayersShot (accept either shader name), perf_probe's Klimt count.
- **EN-2 DONE 2026-08-22 — THE WELD IS THE PORTAL.** R6's live feed and the
  breach's frame reach every molten surface (`_push_portal_to_welds`); the
  Klimt weld core opens on R6's wakefulness (`portal_live`) and shows the
  live view, the reflected-world plate standing in when R6 sleeps. Found:
  the probe's opening rule never fired on the seam (bead at drive 0.24,
  rule at gold phase 0.55). `art/renders/dream_layers_en2/README.md`; six
  dream contracts PASS. OPEN taste/perf rows: the weld vocabulary placing
  R6's camera; trim the ornament under the layers (merged high 2.1 ms
  asleep, 5.2 with R6 awake — R6's aperture price, not the shader's). Molten golden seams along fold lines, the portal-opening rule at high exposure, R6's bounded camera placed by the weld vocabulary; still depth zero, still non-enterable.
- **EN-3 DONE 2026-08-22 — FOLDS, both halves.** (Geometry half: `_solid_box` tessellates at 0.3 m, the Klimt vertex stage sinks wall vertices into the wall around the weld, inward only, collider untouched; all clamps PASS; `art/renders/dream_layers_en3/README.md`.) Surface half first:** The Klimt surface's bit 32 draws the grounded base into the weld along the field's gradient and creases the normal there — bounded, no vertex moves, Gate C re-run (Perception 20/20, Hazard 42, Surface Target 105). The geometry fold needs RoomBuilder to tessellate authored faces near a breach so a capped vertex displacement can bend the wall toward the seam inside the Atlas's promise; `art/renders/dream_layers_en3/README.md`. EN-2's taste row (R6's camera sways with the seam's flow) landed with it.
- **WK-1 DONE 2026-08-21 — THE FLATS FEEL THE ENCROACHMENT.** `ApartmentEncroachment` (presentation only, built by `BuildingRoot`) gives every case unit's perimeter finish quads `wall_encroachment.gdshader`: the same finish plus the case's first three plates as a creep clipped to the unit rect — the wicking substance rising from skirting and corners (restoring plaster over bare brick as a membrane), gilt along the torn survival edge, calm blanks at the late stage — driven by case stage, lifted by manifestation, settling to a residue when resolved; the authored anomaly prop is the beachhead. All six cases register (22 finish surfaces); `ENCROACH=0` / `ENCROACH_FORCE=mina:0.8` for A/B and frames. `ApartmentEncroachmentTest` 13/13. **In passing it found and fixed a builder bug:** perimeter finish quads faced into the brick on every side but west, so most of the building's plaster finishes had never rendered (punchlist 2026-08-21). Frames: `art/renders/apartment_encroachment_wk1/README.md`.
- **CT-1 — FAMILY SKIN ATLASES (OPEN).** Per-family packed skins for the landed five, built by script from the thirty dream plates and mapped to the part kit's authored regions; reviewed in the three-light harness. **CT-2** follows for each FA3 family as its part kit lands (FA3 is now licensed by the ruling).

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

## PRIORITY — OWNER RULING 2026-08-16

> **"Don't stress mobile stuff right now, let's make a working game
> first."**

Standing until reversed, and it re-sorts several open items:

- **Mobile is deprioritised, not abandoned.** L12 (the unmeasured mobile
  light budget) stops being a blocker and becomes a note. `light_rig.gd`
  keeps `ACTIVE_N_MOBILE` and its rationing — nothing is ripped out —
  but no decision waits on a phone any more.
- **Desktop-only trades are now takeable.** The first consequence landed
  immediately: the shadow atlas was refused at 16384 earlier the same day
  *solely* because it costs 1024 MB of VRAM against an unmeasured mobile
  budget. With that objection withdrawn it is taken — free in frame time,
  and it doubles every shadow's linear resolution while giving the caster
  budget real headroom. `project.godot` carries the reasoning and the way
  back (`atlas_16_bits=true` halves it to 512 MB).
- **Completeness beats polish.** Work that makes a shift playable
  end-to-end outranks work that makes an existing room better. In
  practice that puts **N7** — Mina's hazards, the run cap, the three wake
  outcomes — ahead of the Harukiya's remaining phases and ahead of the
  rest of the P8 sweep.
- **When mobile returns**, the first three things to re-measure are the
  atlas, `ACTIVE_N_MOBILE`, and every "measured" claim in the docs that
  was actually an argument (see L12).

## P — Performance

- **P9 — THE OPTIMISATION PASS, AND FIRST THE MEASUREMENT THAT LICENSES IT.**
  *Deferred here by the owner on 2026-08-18: "lets add optimization to a later
  task".* Nothing below is to be done opportunistically in the middle of other
  work; it is one pass, and it starts with the instrument rather than with a
  saving.

  **§DP's ruling now has an instrument, but not yet the recurring observation
  that makes it an off-switch.** The windows added 78,384 render triangles and
  20 draws (§W-GLAZE); the dream shader runs a dozen-odd fbm calls per pixel;
  the next breach/tentacle pass adds the first material submissions in that
  frame. The 2026-08-18 dream measurement is the baseline, not a perpetual
  waiver.

  **So the first deliverable is a number, not a saving:**
  1. **DONE:** the `PERF_DREAM=1` branch in `game/tests/perf_probe.gd` measures
     lamp-off/on at the waking room and deepest live pocket. Baseline 1.71 ms /
     45 calls; durable exposure 1.90 ms / the same 45 calls at 1440p.
  2. **PARTLY DONE:** the waking list already contains the lobby. Add a
     player-height **carriageway** station; the existing street-elevation eye is
     an aerial composition view, not a route the player can occupy.
  3. Recorded per session, at canonical pinned night, with the A/A control
     that §P has already been burned once for skipping.

  **Then, and only then, the sweep.** The known shape of this frame is that it
  is **submission-bound, not fill-bound** — frame time is identical at 720p,
  1080p and 1440p — so triangles inside a mesh that already exists are close to
  free and DRAW CALLS are the real currency. Two specific things are already
  waiting for that measurement:

  - **The 1,270 transparent draws** found during the atrium chase, including
    whole-floor batches at 5,000–6,500 m³ AABB sorted as single units. That is
    a latent sorting hazard nobody has priced, and it is the single largest
    unpriced thing in the waking build.
  - **P8's fossil sweep** (below) is the other half and is already written. A
    limit chosen for a reason that has expired is not a limit; P8 lists them.

  **What NOT to do.** Do not decimate, do not reintroduce a budget by the back
  door, and do not "optimise" anything that has not been measured to cost —
  §DP's whole point is that fidelity is chosen by what an object needs to look
  like the thing it is. The balusters at 186,576 triangles are the standard,
  not the raid.

- **P8 OWNER DIRECTION 2026-08-16 — AUDIT EVERY LIMIT FOR FOSSILS. Are we
  actually spending what we have?** The prompt was: make sure we have
  maximised our light, shadow "and any other parameter — number of raindrops
  or whatever — and are not erring toward unnecessarily low limits."
  **The instinct is already vindicated.** `building_root.gd:460-461` sets the
  16/16 light budget under the comment *"Sixteen is the renderer's actual
  per-object ceiling, so requesting more would only reshuffle winners."* That
  ceiling is **128** and has been for some time (L14). The budget was derived
  from a constraint that has since expired, and nobody re-derived it — so the
  arcade, the bar and every future room have been rationing sixteen lights
  for a reason that no longer exists.
  **The principle to apply everywhere:** a limit chosen for a reason that has
  expired is not a limit, it is a fossil. Each one below gets the same four
  questions — what is the value, what argument set it, is that argument still
  true, and what does measurement say the headroom is *now*.
  **The lever that makes this worth doing:** `project.godot`'s own measured
  note — frame time is IDENTICAL at 720p, 1080p and 1440p, so the frame is
  **submission-bound, not fill-bound**. Anything capped to protect the GPU is
  therefore capped against a bottleneck this game does not have, and is very
  likely free. Anything capped to protect DRAW CALLS is real and must stay
  earned by measurement.
  **The sweep list** (extend it; each needs its resolved value printed, not
  inferred — see L14 for why): the 16/16 and 14/8 light/shadow budgets and
  the dead `UNLIMITED` path; `max_lights_per_object` 128; positional and
  directional shadow atlas 8192 and both soft-filter qualities; MSAA and
  anisotropic (`project.godot` already calls these "bought for nothing" —
  confirm still true); rain and weather particle counts; the storm/sky
  quality dials; prop tick rate and the 12 m prop cull; occlusion-culling
  parameters; the 9 m shop-batch contract; texture and hero-model budgets
  (40k tri / 1K); the torch cookie (`COOKIE 512`, `BAKE_EVERY 0.10`); the
  arcade feed resolution (480x360 at 2x); LightRig's `ACTIVE_N_MOBILE`
  (unmeasured, L12); city-backdrop lit-window counts; resident count and
  routine tick rates; dream-maze module and hazard budgets.
  **Method, so this does not become a spending spree:** raise one dial at a
  time, re-run its owning perf station at canonical pinned night, and keep
  the raise only if it is visible AND costs nothing measurable. Record every
  result including the null ones — "measured, no headroom" is as valuable as
  a win, and is what stops the next session re-asking. Mobile is exempt from
  optimism until somebody measures a phone (L12).
- **P8a THE MEASURING INSTRUMENT WAS BROKEN — FIXED 2026-08-16, and this is
  why P8 exists at all.** `light_rig.gd` documents `LIGHT_BUDGET=14
  SHADOW_BUDGET=8` as the sweep for answering "is this budget actually
  costing anything?" — but `_ready()` read those env vars and `BuildingRoot`
  then called `set_budgets()` immediately after `add_child`, discarding them
  on every run. **The project's own method for re-deriving the light budget
  silently did nothing**, which is precisely how a budget justified by an
  expired per-object ceiling survived unexamined. `set_budgets` now lets an
  explicit sweep win and prints `[LIGHT RIG] sweep override: N active / M
  shadow`; with no env set, production resolves 16/16 exactly as before and
  LightingAudit passes. **A measurement tool that quietly no-ops is worse
  than no tool** — when auditing the rest of the P8 list, verify each dial
  actually moves before trusting a null result.
  **First indicative sweep** (canonical pinned night, 1280x720, single runs,
  so treat as direction not verdict — this machine is noisy and the house
  standard is fresh-process, 30 warm-up / 120 sampled, two runs each):
  | station | 16/16 | 32/16 | 64/16 |
  |---|---:|---:|---:|
  | atrium eye | 37.17 | 38.93 | 40.25 |
  | harukiya | 13.28 | 12.77 | 11.80 |
  | passage northbound | 14.26 | 16.97 | 13.61 |
  Harukiya and northbound move non-monotonically, i.e. noise — no evidence
  of cost there. The **atrium is monotonic** (+3.1 ms from 16 to 64) and is
  the one station that plausibly pays, which fits: it sees seven storeys of
  fixtures at once and is already the worst station in the game at 37 ms.
  Provisional read: **more lights look close to free everywhere except the
  atrium.** Confirm with the two-run house protocol before raising anything,
  and consider whether the budget should be raised globally or the atrium
  should keep a local cap.
- **P8b FIRST SWEEP RESULTS 2026-08-16 — one dial spent, one refused.**
  Paired runs at canonical pinned night, two samples per setting, same
  eleven stations.
  **MSAA 4x → 8x: SPENT.** Measured free — every station at or below
  baseline on the second sample (the first sample's +1.9 ms at two
  stations was this machine's familiar noise, and the second run put
  those same stations at 38.65 and 10.10 against baselines of 39.01 and
  10.18). It is the right dial to spend a free win on: the frame is
  submission-bound, not fill-bound, and this building is nothing but
  hard architectural edges that crawl at 720p.
  **Shadow atlas 8192 → 16384: REFUSED, and the refusal is the more
  useful result.** Also free in frame time — but a 16384 atlas at 32
  bits is **1024 MB of VRAM** against 256 MB at 8192, and *the frame
  timer cannot see that*. The project still targets mobile and that
  budget is unmeasured (L12), so this is the wrong risk to take on a
  number nobody has checked on a device. Revisit with
  `atlas_16_bits=true` (512 MB) or a real phone.
  **The refinement to P8's principle, learned here:** "raise what is
  free" is not enough, because *free in the instrument you happen to be
  holding* is not the same as free. Frame time misses VRAM, and
  submission cost is the opposite trap — `weather_fx.gd`'s own header
  warns that Compatibility "expands each particle into a costly
  submission", so `SPATTER_COUNT` is one of the few dials that hits the
  bottleneck directly and must NOT be raised on the "GPU is free"
  argument. Sort the remaining list by which resource each dial actually
  spends before touching any of them.
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
- **P4** **The 16/16 clobber remains undecided.** The visibility half closed
  2026-08-15: `LightRig.set_budgets` now prints the resolved pair at boot, and
  `game/README.md` documents that production resolves 16/16 via
  `building_root.gd`'s CINEMATIC branch (the code default UNLIMITED/32 never
  survives boot; corrected finding 2026-08-13, WalkTest's "nearest 16 of 104"
  is the observable). Still open: `bcd6450`'s orphaned else (`set_budgets(14,
  8)` is unreachable — no launch mode reaches it), and whether 16/16 is the
  *intended* desktop profile or an accident of the CINEMATIC default — that is
  a perf/look decision belonging with P1's measurements, not a doc fix.
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
    All 19 possessed domestic mechanisms now answer through the same owner that
    stages and restores their case movement. Sixteen distinct physical kinds
    share no generic copy: each has a researched mechanism fact, source ids and
    a local material response. Returned condition is limited to AT REST or
    VISIBLY ALTERED; case ids, resident names, tells and causes are excluded.
    Case authority cancels any restrained handling motion before applying its
    own tell, so inspection introduces neither a second truth store nor a
    competing animation owner.
    The front directory's existing assembly owner now depresses one real call
    button, rings on every press and distinguishes SOUNDED from STILL RINGING
    without choosing a resident or inventing call state. The Vantry reference
    clock answers through its actual sealed setting cover: a metal rattle and
    sourced line-clock condition, never a false winding or adjustment verb.
    All 14 baked loose-paper stacks and eight pinboards now have one exact
    record-aligned inspection owner. One paper corner lifts or one tack presses;
    no sheet/card receives its own collider. A closed 22-id table reconciles
    every generated record, including the bodega and Harukiya papers, to
    clue-safe visible category and authority copy. It never reads Mina/case
    state or prints paper contents. Period copy now cites William M. Kelly's
    1914 paper fastener and the Gillespies' 1921 thumb-tack tool directly rather
    than borrowing apartment-mailbox provenance.
    Mina's six case-specific targets now answer through their authoritative
    callbacks: the wrapper performs a distinct card, book, pencil, calibrator,
    time-clock or letter touch, calls the existing action exactly once and
    forwards only its result dictionary. Mina still owns every caption,
    calibration, visit and resolution transition. The unavailable letter keeps
    no prompt and no collision until recurrence enables it. Five direct period
    patents source the object facts; no presenter or wrapper gained a case flag.
    All eleven Vantry Arcade storefront signs now own one fascia-sized ray
    target, never a collision per word or glyph. Inspection gives the fixed
    assembly a brief enamel-lettering glint and a local tap. Shop name and
    trade remain generator facts; OPEN/CLOSED/NIGHT SERVICE and LIT/DARK are
    read through `PassageHoursDirector`'s public presentation boundary, so the
    sign neither copies the schedule rule nor invents stock, prices or economy.
    The ORISON blade, DRUGS wall cabinet and HARUKIYA stage neon now each own
    one reachable service inspection. The tall blade's target is its actual
    low transformer box; wall forms use one bounded frontage target, never
    glyph collisions. Copy reports live/dark glass, visible dead/dropout runs
    and transformer condition from the sign owner. Inspection is read-only and
    cannot compete with business-hours or Conductor control of the circuit.
    The remaining three hero sign owners now answer at assembly scale. HALF
    BAKED uses one valance plane and reports its real fluorescent dropout plus
    authored 24-hour condition; Harukiya uses its low arrow as the service
    point while its card follows the existing OPEN / AFTER HOURS / CLOSED
    director; the Orison identity plaque has an exact bronze-face target kept
    physically distinct from the landmark door. Each gives a material-local
    tap, one R028-sourced slip, and no letter, bulb, screw or kanji child owns E.
    The entrance marquee likewise answers as one assembly: a shallow look-plane
    sits proud of the outboard fascia at a standing angle, rather than putting
    collisions on glazing, fittings, letters or cresting. Its iron tap and
    R028 card report the rain-shedding prismatic tray, seated returns/tie rods
    and fixed two-lamp/fascia-wash arrangement without adding a light switch.
    Roof service now respects its existing endpoints. Each of the four central
    ventilators refuses at its named belt guard with a casing rattle, live/idle
    automatic-cycle state and an isolation requirement; E never starts or
    stops the motor, and rotors/rain caps remain ambient. Each of the five
    C-stack chimney breasts answers only at its removable iron thimble, reports
    sealed plaster/rings/resonance, and leaves both masonry and the
    Conductor-owned three-millimetre knock pose untouched. R037/R039 source the
    two families and production rays prove all nine authored endpoints.
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

## SR — The Orison Service Round

Owner direction and architecture: `design/ORISON_SERVICE_ROUND_BRIEF.md`.
Target mix over rolling active play is 1:1:1 hands-on maintenance, people /
travel / search, and observing / avoiding / eventually communicating with the
Dream organism. M1's shared activity contract and live radiator consumer are
proved at `art/renders/maintenance_service_round_m1/README.md`.

- **SR2 — Lobby annunciator consumer — COMPLETE 2026-08-24.** The real
  `LobbyPorterBoard` now exposes separate lift-dispatch and call-hardware ray
  targets. The authored flag-armature, contact-alignment and common-reset chain
  moves the board's actual flags, silver bridge and spindle through the shared
  activity presenter; preview/abort publishes nothing, and final commit emits
  only one mechanism result. The elevator game remains separate. The focused
  schema/run test passes 33 checks, the live test passes 12 including a boot of
  `orison_root.tscn`, and frozen A/A plus worked-state Forward+ proof is at
  `art/renders/maintenance_annunciator_sr2/README.md`.
- **SR3 — Boiler water-column consumer — COMPLETE 2026-08-24.** The production
  basement's real `BoilerProp` water-glass reach now opens the shared isolate,
  prove, witness and guarded-return chain. Preview moves two literal gauge
  cocks, the blow-down lever, water and witness marker without emitting boiler
  state; final commit alone proves the column and publishes its honest level.
  The focused activity test passes 33 checks, the three-consumer live test
  passes 18 including `orison_root.tscn`, and frozen A/A plus all four worked
  states are proved at `art/renders/maintenance_boiler_sr3/README.md`.
- **SR4 — First complete waking service round — COMPLETE 2026-08-24.** Lena's
  `WORK ORDER 002 — BORROWED BREATH` waits until Mina's opening job closes,
  arrives as a persistent line slip on the carried 28-R, and runs through the
  existing resident-interaction and `WorkOrders` owners. The legal order is
  call → Lena → 2B radiator inspection → lobby contact comparison → basement
  pressure comparison → 2B repair → deliberate Lena return reply. Wrong order,
  early mechanism completion, duplicate evidence and proximity closure are all
  rejected. `ServiceRoundDirector` stores no lifecycle and creates no Dream
  fact. Focused proof passes 13 checks, the strict job test remains green, the
  production-root live test binds all three real anchors, and Forward+ A/A / call
  / threshold frames are at
  `art/renders/maintenance_service_round_sr4/README.md`. SR5 inserts the shared
  Dream interruption; do not misreport this waking braid as that answer.
- **SR5 — Shared Dream answer — COMPLETE 2026-08-24.** The production
  radiator, annunciator and boiler facts enter the existing bounded signal bed
  as probe/recognize/pulse architecture packets. The complete phrase—not a
  route label, duplicate or partial sequence—earns the existing whole-body
  attention at the boiler and an architecture-owned secretion/vascular answer
  held by the existing F02 LivingField at Lena's radiator. Repair returns one
  idempotent recognition packet. The exchange adds no Dream director, entity,
  hazard, pursuit, presentation or save owner and creates neither lineage nor
  stain. Focused proof passes 10 checks; production-root proof passes 7; live
  Forward+ A/A and response frames are at
  `art/renders/maintenance_service_round_sr5/README.md`. This is the shared
  organism answering a waking route, not a completed waking case loop.
- **SR6 — Rolling attention ledger.** Measure primary-attention seconds across
  maintenance, people/search/travel and entity relationship; tune a complete
  40–50 minute sample to 33/33/33 ±5% without scheduling each minute.
  **SR6A instrumentation is complete 2026-08-24:** one telemetry-only ledger
  persists in `CampaignShell` across world swaps, applies explicit precedence
  (service > dialogue > meaningful waking Dream attention), defaults ordinary
  waking traversal/search to people, and counts the sole active Dream world as
  relationship. It retains a coalesced rolling 45-minute window, prints a
  census every five minutes, refuses a balance verdict before forty minutes,
  and writes no save fact. Focused arithmetic/ownership proof passes 11/11;
  maintenance, dialogue and campaign-boundary regressions pass. **SR6B remains
  open:** run and tune a real 40–50 minute playtest after SR7 supplies enough
  hands-on apparatus; do not certify the ratio from the synthetic arithmetic
  trace.
- **SR7 — Vertical anatomy expansion.** Add the dumbwaiter brake, elevator
  landing interlock, rooftop tank ballcock, mail-chute choke, fuse panel and
  watchman clock, in that order unless playtest compulsion changes the ranking.
  **SR7-A dumbwaiter holding brake is complete 2026-08-25:** because production
  had no dumbwaiter marker, shaft, prop or anchor, the first increment is one
  honest hand-authored lobby landing beside the porter board, not a fictitious
  multi-floor lift. Its five transferable verbs are take the strain, ease the
  pawl, prove the balance, seat the band and prove the bite. A slack rope
  refuses the pawl; the car cannot travel through a holding pawl; early release
  reports the danger without erasing the whole chain. Preview remains
  reversible and only `apply_maintenance_result` seats the band. The prop
  closes no job, advances no case and publishes no plant or Dream fact. Focused
  proof passes 28/28 and production-root proof passes 24/24. Forward+ evidence
  and measured subject-ROI A/A are at
  `art/renders/dumbwaiter_brake_sr7a/README.md`.
  **SR7-B elevator landing interlock is complete 2026-08-25:** the real F01
  passenger-elevator landing now exposes keeper, latch, roller, retiring cam,
  shut contact, locked contact, bridging wire and depth gauge as one literal
  service point. Its 34-second chain gauges the keeper, removes the jumper,
  trues the keeper, brings the door home and proves refusal with the door
  deliberately cracked. `circuit_continuous()` remains distinct from
  `interlock_holds()`: closed is not locked, and a bridge can lie only to the
  former. An unproved interlock preserves the old ride exactly; after an
  honest repair, the real car refuses to leave F01 whenever the landing door
  is not locked. Preview/abort restores, commit alone proves, and no job, case,
  plant, Dream or save owner is added. Focused proof passes 41/41 and the
  production root 39/39; two measured Forward+ A/A floors and the twelve-frame
  sheet live at `art/renders/elevator_interlock_sr7b/README.md`. **Still open:**
  only F01 is interlocked; the car gate has no contact; neither vertical
  apparatus is on the Service Round route; SR7-C is the rooftop tank ballcock.

## H — Housekeeping

- **H20 PRESENTER SWEEP AFTER THE TELEGRAM RESTYLE — DONE 2026-08-16, one
  nit left.** `b318d84` restyled several presenters in one pass and gave
  `ObjectiveTracker` a fabricated `"WORK ORDER / "` prefix on titles the job
  library already authors whole, which reddened GoldenLoopTest and
  MaintenanceJobTest and shipped only because the restyle's own test asserted
  the *font* and not the *text* (`service_set_test.gd:48`). Fixed on `66a00f3`.
  Every other text path that commit touched has now been audited: the only
  other `LABEL / VALUE` construction is `"PRESENT CONDITION / %s"` on a bare
  state name in `functional_prop.gd`, which is the idiom used **correctly** —
  a label added to a value, not to an already-labelled heading. No further
  stutter bug exists. **The one open nit:** `service_set_prop.gd:85` composes
  the modeled paper slip as `"WIRE %04d\n%s" % [n, title.to_upper().left(16)]`,
  and 16 characters truncates "WORK ORDER 001 — THE CHIRP" to "WORK ORDER 001
  —", trailing off on a dangling em-dash. Truncation on a narrow physical slip
  is right; stopping on punctuation is not. **RULED AND FIXED 2026-08-16:**
  trim to the last word boundary rather than reducing the slip to its number,
  because the number alone loses the thing the player is scanning for. The
  trim lives in `TelegramStyle.fit_slip()` — the class that exists for exactly
  this typographic grammar — and drops any separator left dangling at the cut:
  "WORK ORDER 001 — THE CHIRP" now reads "WORK ORDER 001", "CASE CLOSED —
  MINA VALE" reads "CASE CLOSED". A single long word still hard-cuts, which is
  the only honest option and dangles nothing. Note the HUD is a *different*
  and already-correct path: it uses Godot's `OVERRUN_TRIM_ELLIPSIS`, so its
  mid-word cut is signalled by the ellipsis. The slip's manual cut was the
  only unsignalled one.
  **The general lesson, worth more than the fix:** a styling commit reddened
  two gameplay suites, and the first suspect (`1f8faa0`, chosen by recency and
  subject-matter plausibility) was innocent. Bisect; do not profile the
  commit list for likely-looking culprits.
- **H21 FLAKY TEST FIXED 2026-08-16 — and the diagnosis is the lesson.**
  `ServiceWireResponseTest`'s "case latch and cart chain visibly moved"
  went red at random on an unchanged build (measured over three runs:
  0.0029 pass, 0.0000 fail, 0.0034 pass). Cause: the knob **rattles and
  comes home** — `case_door_prop` tweens it 0 → −0.24 in 0.07 s and back
  to 0.0 in 0.11 s — so its *resting value is exactly the value that
  fails*, and any single sample races a 0.18 s round trip. Polling until
  it crossed the threshold did not fix it either, which is what proved
  the tween sometimes never runs rather than merely running late. Now
  sampled every frame across the rattle window with the assertion on the
  **peak**, which is also the contract the check is named for: "visibly
  moved" is a claim about whether motion happened, not about where a knob
  is sitting when someone looks. Five consecutive passes, peak stable at
  0.017–0.020 against a 0.001 threshold (was 3× margin, now 18×).
  **A flaky test is worse than a failing one**, because it teaches the
  next person to shrug at red — and this one nearly got blamed on an
  unrelated edit that happened to be in the tree when it fired.
- **H2** **`C:\FPSengine01` is not a git repository.** The entire compiler side —
  the world compiler, the providers, the arcade catalog build, the texture
  validation — is unversioned files on disk. `git init` and a first commit.
- **H3** `worldc clean --stale` has no test covering it.
- **H13** **Logical placement audit.** Is each object placed correctly, and does it belong there. Convention traps are listed in the brief (door markers are the hinge jamb; pendant markers are ceiling anchors with a drop). Note placement cannot lean on the router to prove a route is clear — see R6, residents walk through furniture. Brief: `design/AUDIT_BRIEF.md`.
  - **H13-PRESENTATION — LIVE PRESENTATION AUDIT (INSTRUMENT BUILT AND FIRST RUN 2026-08-21; GENERATOR FIXES STILL WAIT).** `res://tests/PresentationAudit.tscn` boots production `BuildingRoot` with WalkTest's discipline and runs seven passes: live cross-class AABBs with an assembly whitelist (25 leads), authored-base support rays (16; every kitchen toaster base 215 mm inside the furniture hull), WalkTest's `[ART]` sweep verbatim, dressing-per-m² census with bottom decile (five zero-record rooms; 2D's bedroom), 1.4 m wall rays (5,783 rays, 0 see-through — lead closed), height-classified ceiling rays with the real `show_all_floors` toggle (the corridor 22% is the atrium light well plus one stray point per floor), and a windowed eight-station OrbitSweep (granted set direction-blind; 0/288 frames dropped a centre-in-view light — the "lights disappear with direction" lead is not gating, churn or culling). The 183-still harness rerun wrote 182 frames. Rows are in `design/walkthrough_punchlist.md` under 2026-08-21; proof, JSON and CSV at `art/renders/presentation_audit_h13/README.md`. The first generator fix landed the same day: `_toaster_marker`'s yaw-rotated offset stood every generated kitchen's toaster on its dishrack; it is in the run frame now, `_validate_kitchen_worktops` guards it, only the ten toaster markers moved (no GLB rebuild), and the re-audit is toaster-clean (support faults 16 → 6). The roof ventilator V-B, which the garden pass had buried in the east bed, now stands on open roof south of it (marker move). 2D/5D's empty rooms are the building's own vacancy rules; the 6A monitor overlaps are the prop's cable mesh through a 50 mm desk top. Remaining leads (bar speakers/songbook mounting, 4B closet/vestibule dressing) are taste calls for the walk, not generator defects.
