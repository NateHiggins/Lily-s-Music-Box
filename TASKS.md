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
- **L11 STALE DIAGNOSIS TO RE-MEASURE — the per-object cap is gone (but
  the runtime budget is not; see L14).** `max_lights_per_object` is 128
  (was 16), so nothing can evict a fixture by AABB overlap any more. `design/walkthrough_punchlist.md` still blames that
  mechanism for F02_D/F05_D unit interiors rendering black in BOTH
  WalkthroughShots passes. Re-run both passes: either those stills are now
  correct and the punchlist item closes, or the black rooms have a different
  cause the cap explanation has been hiding for months. Do not close it by
  argument. Prose corrected in place 2026-08-16 across `photoreal_target.md`,
  `walkthrough_punchlist.md`, `PROP_ACTIVITIES.md`, `FINAL_MAP_REDESIGN_BRIEF`
  §10ab, `gen_layout.py` and `exterior_detail_pass.gd`; the current-state
  authority is HANDOFF.md. **Historical "measured at 16/16" tables are
  accurate records of test conditions — never rewrite those.**
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
- **T9 PROPOSED — the street wall.** `design/STREET_WALL_PROPOSAL.md`: frame
  the arcade gate (its K0 host is one storey short, per the gateway
  proposal's own §3.1) and close the facade ring around the play area —
  three-layer system, eight-station survey evidence in
  `art/renders/street_facade_survey_v1/`, +0.5 ms perf contract, phases
  W1–W4. Awaits owner ruling on §6 (west-strip character, ghost-sign copy,
  lintel carry); W1/W2/W4 are not blocked by fiction questions.

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
  **PS12a HELD CODE — THE WHOLE RECONSTRUCTION IS UNCOMMITTED.** V1+V2+V3+V3b
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
- **H2** **`C:\FPSengine01` is not a git repository.** The entire compiler side —
  the world compiler, the providers, the arcade catalog build, the texture
  validation — is unversioned files on disk. `git init` and a first commit.
- **H3** `worldc clean --stale` has no test covering it.
- **H13** **Logical placement audit.** Is each object placed correctly, and does it belong there. Convention traps are listed in the brief (door markers are the hinge jamb; pendant markers are ceiling anchors with a drop). Note placement cannot lean on the router to prove a route is clear — see R6, residents walk through furniture. Brief: `design/AUDIT_BRIEF.md`.
