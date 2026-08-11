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
  `D` decisions · `A` arcade · `S` studio · `M` materials · `H` housekeeping.
- One line each. If it needs a paragraph it needs a brief in `design/`.

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
- **S5** Connect the studio to the Songbook as its capture half — the bar is
  where songs mutate, the studio is where a take is fixed. Ghost duets belong in
  the room that records. No pitch scoring. *Blocked by S4 and the Songbook's own
  order.*

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

Proposed in `design/ORISON_STREET_BRIEF.md`. **Not canon until the owner rules
its four open questions.** The demolition is done and committed; nothing below
is built.

- **T1** Owner ruling on the brief's §8: does the tear stay loud, does anything
  but traffic come out of it, is the tram on rails, and does traffic stop at
  night. *Blocks everything else here.* The night question in particular is two
  different games at 3 a.m.
- **T2** The traffic stream itself: instanced from the start (batching is worth
  nothing on this station), 95% credible 1928, 5% wrong and never acknowledged.
  Audible enough to cross by ear with the camera facing a door.
- **T3** The crossing rules: no death, no damage, no UI, no dedicated crossing
  point, gaps never longer than ~8 s. A hit is a shove and four seconds.
- **T4** The tears, as boundary. When they exist the lateral stage collision at
  x -20.10 / +20.60 retires into them and the street stops having edges.
- **T5** Re-place the bus shelter at a stop the traffic actually serves. Saved:
  4.4 x 1.4 m, 2.45 m roof, glazed back with centre mullion, timber bench, last
  at (-12.6, -25.55).
- **T6** Bring the arrival car back moving - the player gets out, it leaves into
  the east tear.
- **T7** Budget first. Street elevation is 33.28 ms against 16.6, CPU-bound on
  submission, and **lighting is the dominant term outdoors** (-33%, twice the
  atrium's). Headlamps and lightning are the expensive part, not the vehicles.

## P2 — The Passage (rehousing the shops)

Proposed in `design/ORISON_PASSAGE_BRIEF.md`. **Not canon until the owner rules
its five open questions.** Nothing built. This supersedes R2's street re-plan if
it is ruled in, so **do not start R2 until this is decided** - they are two
answers to the same problem and only one should be built.

- **PS1** Owner ruling. The expensive question is §8.1: all eleven units move,
  or the cheaper split that keeps the luncheonette, news & cigars and the
  pawnbroker on the street. *Blocks everything else here, and blocks R2.*
- **PS2** Naming discipline, decide before any code exists: `arcade` already
  means the cabinets (`game/scripts/arcade/`, §VIII.5.g). Fiction is "the Vantry
  Arcade"; **code must be `passage`.** Do not let a second `arcade` into the
  tree.
- **PS3** The hall itself: glass barrel vault, iron ribs, eleven units with
  shopfronts onto the hall. §8.3 - whether the roof is intact, holed, or sheeted
  over - is the biggest atmosphere decision in the document.
- **PS4** Pushcarts as the movable middle layer. They are the reason the hall is
  navigable rather than a corridor, and they must be shoveable.
- **PS5** **Carrying changes crossing.** The keystone of the loop: a crate slows
  you, blocks sprint and sits low in frame, so the return leg of an errand is
  harder than the outbound. Wires the Passage directly to section T with no UI.
- **PS6** Hours. Shuttered units and chained carts at night, and a 300 ft empty
  glass hall. Pair with T1's night question.
- **PS7** Carry R5's two protections across deliberately: the 181 per-shop
  buffers, and the deliberate NEWS CIGARS inaccessible proprietor side.

## F — Film (projectors instead of televisions)

Proposed in `design/ORISON_PROJECTOR_BRIEF.md`. **Not canon until the owner
rules its five open questions.** Nothing built.

- **F1** **BLOCKER, and worse than first filed. A crop cannot fix it.**
  Every clip carries a "Sora" watermark, and testing a crop proved the mark
  **moves within a single clip** - `ch_01` has it top-left at 1 s and floating
  mid-frame at the end. A crop of sides 10% / top 9% / bottom 20% cleared all
  fifteen shortlisted clips on an early frame and `ch_01` still showed it on a
  late one. That also kills option 3 (hide it in the projected-look pass), for
  the same reason: you cannot mask a moving target with a static gate.
  **Only a clean re-render works.** Everything else in this section can proceed
  in parallel, but no reel ships until this does.
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
- **F4** `ProjectorProp` replaces `TVProp`. 16 mm Kodascope, not 9.5 mm Pathé
  Baby - 9.5 mm was chiefly France and Britain, 16 mm is what Americans used.
  **The screen is no longer part of the prop; the image lands on the room's own
  plaster** and breaks over corners.
- **F5** The projected-look pass: gate weave first (it does more than anything
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

## N — The dream (narcolepsy maze)

Proposed in `design/ORISON_MAZE_BRIEF.md`. **Not canon until the owner rules.**
Nothing below should start before that ruling.

- **N1** Owner ruling on the brief. Three open questions remain at its foot, all
  about which poltergeist is in the dream and when. *Blocks everything else in
  this section.*
- **N2** Fractal maze generator: one seed per save, generated once at campaign
  start, room archetypes drawn from the Orison's own rooms. Must run the same
  overlap / footprint / door-width / door-swing audit `gen_layout.py` does.
- **N3** Narcolepsy onset system in the waking game: gradual and sudden, weak
  resistance, cataplexy on strong emotion, and the accessibility option forcing
  all onsets to be gradual.
- **N4** The light binary — on to see hazards and be found, off to be safe and
  blind. This is the entire verb set and wants prototyping before anything else
  is built around it.
- **N5** Eight hazards across positional, triggered, rhythmic and conditional,
  each with an audible tell that survives the light being off.
- **N6** Bind the pursuer to `PoltergeistLibrary` so the thing in the dream is
  the current case's poltergeist, not a new monster.
- **N7** If ruled canon, add the Rule of Signal exemption to `ORISON_BIBLE.md`
  so the dream is not later read as a violation of §VIII.

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
  2026-08-10 at 1440p. Worst is the **atrium eye at 42.05 ms** (27.8k objects,
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
  - **User prop scripts are not the cost.** Silencing all 384 `_process`
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
## H — Housekeeping

- **H2** **`C:\FPSengine01` is not a git repository.** The entire compiler side —
  the world compiler, the providers, the arcade catalog build, the texture
  validation — is unversioned files on disk. `git init` and a first commit.
- **H3** `worldc clean --stale` has no test covering it.
- **H13** **Logical placement audit.** Is each object placed correctly, and does it belong there. Convention traps are listed in the brief (door markers are the hinge jamb; pendant markers are ceiling anchors with a drop). Note placement cannot lean on the router to prove a route is clear — see R6, residents walk through furniture. Brief: `design/AUDIT_BRIEF.md`.
