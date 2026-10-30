# OPEN TASKS

The shared queue. Everyone working on Orison writes here.

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

Current scope follows Bible §VIII.5.o and the owner's October 27 decisions in
`design/V2_TASK_RELEVANCE_REVIEW_2026-10-27.md`, amended by Bible §VIII.5.p.
**The complete new V2 prologue is the next playable milestone.** Codex owns it
in the canonical checkout; the separately authorized city Codex chat is actively
building in **C:/ov/city**, not waiting for the prologue. Reconcile those branches
and qualify their combined sources before main integration. Audio listening,
save boundaries, weather art and frame-time stalls remain V2 gates. No release
or task deadline is set. Existing route/save gates remain qualification fixtures, not the final
narrative's mandatory mission sequence. Finish V2, then the murder-year game;
maintenance is secondary investigative content. Funding and marketing are retired.

- **K-V2-CITY-REVAMP — City Codex and canonical Codex: qualify the combined city/prologue candidate before main promotion.** Qualified city construction **6e5e9a7a** and documentation **9aece84e** are reconciled with prologue **0ed03a87** in pushed **ded0aa81**; they are not on main. The city-only continuous route passed237 checks/199 waypoints and source-bound surfaces42,667 checks, with empty shutdown stderr. Combined native source preflight passes12 fixtures after measured consumer-equivalence review; separate branch receipts do not qualify the combined world. Canonical Codex owns fresh combined surface/input/route and candidate verification; city runtime sources are frozen while its agent prepares separate native building/vehicle candidates. Remaining unique buildings, bridge, shore/curb/ballast detail, roof views and artistic acceptance stay open; do not treat the stale138 count as a renewed survey. [Construction, evidence and limits](design/V2_CITY_CONTEXT_REPORT_2026-10-19.md); [reconciliation](design/V2_PROLOGUE_2026-10-28.md#city-reconciliation-checkpoint--october30). No calendar deadline.


- **K0-ENGINE — PRIORITY / CONTINUOUS: WRITE THE ENGINE WE ARE DISCOVERING.**
  Treat this project as an evidence-producing engine-development programme,
  not only a game. Beginning now, maintain a durable, source-linked knowledge
  ledger covering: subsystem ownership and contracts; data-driven construction
  patterns; deterministic simulation and save boundaries; rendering,
  performance and proof instrumentation; content/compiler pipelines; test and
  render-sheet methods; failed approaches and why they failed; Godot-specific
  constraints; what is Orison-specific versus reusable; and the seams that
  would need stable APIs, documentation, packaging, licensing and support to
  become a standalone tool. Record decisions when learned, with commit/test/
  measurement evidence and migration cautions. Before the next project, turn
  the ledger into an engine requirements document and extraction plan; do not
  prematurely generalize production code or let productization destabilize the
  current game. Living record: `design/ENGINE_KNOWLEDGE_LEDGER.md`.

- **K0-LANGUAGE — INVESTIGATIVE CLARITY: HOUSE ENGLISH IS INVESTIGATIVE
  EQUIPMENT.** Build the source-grounded alternate-history occupational contact
  language specified in `design/HOUSE_ENGLISH_LANGUAGE_STRATEGY.md`. Prototype
  only the opening shift first: semantic source records, 10–25 teachable terms,
  evolving comprehension, plain/parallel accessibility surfaces, resident
  idiolects and cultural review. Never turn immigrant identity into phonetic
  caricature, obscure safety/navigation facts, or let presentation own story
  state. Scale only after blind players infer and act on a novel instruction.

- **K0-PHONE — PHYSICAL COMMUNICATION: THE HOUSE HAS LINES, NOT GENERIC
  PHONES.** Execute `design/HOUSE_TELEPHONE_ECOLOGY_BRIEF.md`: a physical F01
  apartment-house board, period-correct 4B suite set and message-bureau custody,
  trustworthy 3D subscriber set, completed public booth, and only the
  professionally justified private subscribers. Route existing call/report
  owners through transient lamps, cords, bells, jacks and slips without
  duplicating jobs, cases, dialogue or persistence. Teach House English's
  line/order/carrying/A–B vocabulary through ordinary operation before the
  first impossible connection. Ship in PHONE-A…F slices with production-live,
  accessibility, performance and quantitative render gates.

- **K0-AUDIO — LAUNCH BLOCKER / PRIMARY GAMEPLAY FEEDBACK: MAKE THE HOUSE
  ANSWER CLEARLY.** Execute `design/SOUND_AS_GAMEPLAY_AUDIT.md`. Establish the
  golden-shift listening baseline before bulk tuning; then ship an authored bus
  tree, composable mix-state owner, semantic cue catalog, pooled priority and
  concurrency policy, Vantry audibility vertical slice, interaction/state
  vocabulary, cached room/portal propagation, weather/radio arbitration and
  caption/accessibility parity. Preserve source ownership: props decide what
  happened, audio policy decides how competing truths remain intelligible.
  Sound must convey source, direction, acceptance/refusal and state without
  becoming louder, busier or an omniscient objective system. AU-0 through AU-3
  gate the Early Access golden shift; AU-4 through AU-6 complete M3/M6 polish.

- **K2 — FRESH-SAVE GOLDEN SHIFT.** Play the eleven M2 beats from curb to 4B
  wake without console, debug panel, noclip or source knowledge. Record the
  exact first missing or unclear player-facing transition; do not infer it from
  a green unit test.
- **K3 — ELEVEN-BOUNDARY SAVE MATRIX.** Save and reload after every golden-shift
  beat. Prove the immediate practical intention, job/case owner and physical
  world state reconstruct correctly at each boundary.
- **K4 — ROUTE POLISH INTAKE.** After K2 produces a stable route, promote only
  route-visible `blocker`/`ugly` rows from `design/walkthrough_punchlist.md`
  into bounded M3–M6 tasks. Wishes remain in the evidence ledger unless a
  playtest promotes them.

Status and sequencing rationale:
`design/MILESTONE_RECONCILIATION_2026-08-26.md`. M1's shared spine is already
implemented and documented in `game/docs/core_loop.md`; K is now an integrated
product proof, not another spine rewrite.
---

- **K-POST-V2-YEAR — After V2 construction and qualification, build The Year You Died: nonlinear temporal forensics across the murder year, with a unified calendar/evidence interface and deterministic event-driven world states.** Owner-directed big goal; [brief](design/THE_YEAR_YOU_DIED_POST_V2_2026-10-26.md). The INERT treatment and outside-review revisions are merged in PR87/PR90, not built gameplay. After V2, implement its dated carriers/free-order investigation with property-law review, positive-case scrutiny, trans-reader review, resident read-aloud and owner humour acceptance still open; preserve all settled choices and proposed-only Option A. Do not divert current V2/weather closure into implementing this next phase.

- **K-V2-PRECIPITATION — Codex, queued after current prologue integration: finish moving-field/first-use attribution and precipitation presentation.** Rain/snow visibility, deterministic lightning, wetness, fallout and lens moisture are already merged in PR66 with source-bound surface, weather-route and isolated two-world save evidence; do not repeat that construction or call its original candidate gates pending. Long activation/first-view stalls and artistic acceptance remain open. Reproduce on the combined current sources before choosing a repair; preserve indoor cover, readable companion/UI and calendar/publication/save owners. [Results and original failures](design/V2_SKY_WEATHER_INTEGRATION_2026-10-24.md).

- **K-V2-ANNUAL-SKY-ART — Audit the full November 1928–November 1929 weather year across hours, seasons, regimes, genera, rare phenomena and seeds.** Reuse the existing 2,190 six-times-daily renders, measure coverage/repetition separately from artistic judgment, add targeted sunrise/twilight and weak-combination renders, and implement evidence-supported cloud/lighting fixes. Preserve the authored weather schedule. No claim that fifty classifications constitute fifty accepted formations.

- **K-V2-SKYWATCH — Codex, queued: finish installed rooftop club/telescope/BBQ gameplay and the remaining astronomical detail.** PR67 already merges relief Moon/phases, five-planet and 9,096-star analytical foundations; PR68 adds cloud-flow/ice/twilight/mirage and fictional airship presentation. Do not rebuild those foundations or describe all airships/city optics as absent. Next survey current roof/city access, mount reviewed stock and exercise actual telescope controls; Leonids, precision/magnified optics, lunar softness at 0.1-degree FOV and final artistic acceptance remain open. Preserve roof plant, weather-inspector access and clock ownership. [Requirements and limits](design/V2_SKYWATCH_ASTRONOMY_2026-10-27.md); [story connection](design/THE_YEAR_YOU_DIED_POST_V2_2026-10-26.md#v2-prerequisite-skywatcher-club).

- **K-V2-FILM-CADENCE — After weather integration and Smooth-mode performance diagnosis, preview optional Smooth / Cinematic 24 / Early Film 18 presentation.** Step eligible visual poses only; preserve responsive camera, direct manipulation, physical companion readability, campaign clock rate, simulation and animation-event authorities. No low-rate whole-world viewport or default engine cap. Optional weave/flicker/period grading must protect text and support motion/flicker-free viewing. [Analyzed owner brief and acceptance boundaries](design/V2_SKYWATCH_ASTRONOMY_2026-10-27.md#queued-presentation-experiment-early-film-cadence). Actual native-refresh performance remains a target, not an established result.

- **K-V2-FRONT-FACADE — Canonical Codex: finish entrance/facade integration and qualification.** Selective portal candidate **f4d73ddd** preserves unrelated facade arrays and original door/sign/light/save owners. Corrected occupied review passes673 checks with actual grab/mouse/release and six inspected captures; original fixture failures are retained. Next reconcile facade/window findings against installed interiors, complete source-bound surface and current-main candidate/regression renewal, and obtain artistic review. Native/diagnostic passes do not close the full facade. [References, evidence and limits](design/V2_FRONT_ENTRANCE_REMODEL_2026-10-27.md).


- **K-V2-FIRST-VIEW-HITCH — Reduce the occupied route's remaining stalls.** Current passage publication repair registers finished cells across frames: four native 124-waypoint completion frames fall from 101.626–104.983 to 63.053–65.229 ms, with zero route failures. Typical p95 remains about 65 ms and a 101.068 ms cold/other spike remains; this does not establish whole-route FPS improvement or full renderer/physics attribution. Timed native resource release is only about 10–11 ms, not the dominant 100 ms hitch. [Measured controls, original failed short diagnostic and passing residency/surface renewal](design/V2_COOPERATIVE_NATIVE_FITTING_2026-10-23.md#october-28--cooperative-passage-publication). Keep atomic fitting, deferred engine costs, cold spikes and source-bound qualification open. Screenshot readback stays outside collection; process/physics monitors are one-second peaks. [Prior resident/inventory query repairs and limits](design/V2_BACKGROUND_HOUSEHOLD_SAVES_2026-10-23.md#october-27--inventory-reads-during-resident-reconstruction); [city-route baseline](design/V2_CITY_CONTEXT_REPORT_2026-10-19.md#eight-block-height-repair-and-surface-renewal--october-28-utc). Weather/surface qualification does not close performance debt.

- **K-V2-PROLOGUE — Canonical Codex: finish An Unfortunate Development through normal V2 entry.** City checkpoint and main94ef1638 are reconciled. Domain/save121, manually hosted full-route287 and corrected temporal identity/reload/skip regression67 checks pass with empty stderr; original population failures remain recorded, and their exact cause is not established. Next finish the running real-title whole route, complete affected city/surface checks and compare against the clean115-gate main baseline before promotion. Keep reload boundaries, stall attribution, readability and human acceptance open; preserve exact dialogue, friendly existing Tardi shader/greeting,17-second timing and all input/draft/gameplay/save authorities. [Actual results, original failures and current limits](design/V2_PROLOGUE_2026-10-28.md). No calendar deadline.
- **K-V2-BATH-WINDOW — Reconcile the existing 4B sanitary opening with adjacent installed rooms.** Its semantic exterior flag does not establish an outdoor sightline: October29 rendered finale review sees retained interior stock beyond it. Survey ventilation/lightwell intent before geometry changes. The finale stages at the existing bedroom exterior window; see `design/V2_PROLOGUE_2026-10-28.md`.
- **K-V2-TIME-REGISTER — Add the companion's folding temporal readout and integrated flux-capacitor homage.** Recommended next external Blender batch, authoring not yet assigned: compact register first, mechanically supported three-branch capacitor/glass module second, fitted to the installed phone-scale bot without another chassis refit. [Ready-to-send fabrication brief](design/V2_PROLOGUE_2026-10-28.md#proposed-external-time-register-batch--october29). Open it with the temporal command; use authoritative departure/passing/destination data, preserve readable paper/keyboard, rotor/arm/cassette clearance and right-third framing, and measure added cost. Registered PBR/loaded mips, separate lettering and restrained accessible emission; no copied photo pixels, film labels, new clock, fuel or light authority. Annual local-date destination correction is implemented; native construction, runtime integration and artistic acceptance remain open.

- **K-V2-WINDOW-DEPTH — Explore a depth/interior-mapping shader for the city background windows.** Prototype the illusion of varied, fully furnished occupied rooms using deterministic per-window seeds, plausible period layouts, depth/parallax and restrained signs of occupancy. Compare approaches on existing generic building stock; check street, rooftop and narrow-FOV views, glazing/foreground occlusion, LOD transitions, repetition and same-settings frame-time cost before proposing broad rollout. Reuse the existing city/material/clock owners; avoid per-window viewports or treating implied occupants as resident/story facts. Exploration queued after current repairs, not an implemented interior system or a new release deadline.

- **K-V2-ENTRY-SMALL-STOCK — Canonical Codex: integrate delivered boot scraper and umbrella stand/tray after current repairs.** External native authoring is delivered at C:/ov/asset-prototypes/orison-entry-small-stock-20261029/: 3,676 triangles/2 partitions and 4,624/6; all76 delivery-manifest hashes verified, placement/service previews inspected. Next selectively replace only F01_vestibule_umbrella_stand and mount the scraper through blockout-root coordinates, bind existing local catalogue finishes, verify pavement anchoring/full door sweep/player/mailbox access and loaded UV/mips/collision/cost. Keep separate tray datums for possible later direct manipulation; no new water, inventory, save or boot-cleaning mechanic. [Intake, proposed transforms and limits](design/V2_FRONT_ENTRANCE_REMODEL_2026-10-27.md#small-stock-delivery-intake--october29). Native reports are not Godot or artistic acceptance; no deadline. Delivery includes boot_scraper.blend/.glb, umbrella_stand.blend/.glb, CONSTRUCTION_REPORT.md and five CPU previews; integration remains open. Recommended next external batch is K-V2-TIME-REGISTER (register, then glass-covered capacitor), not another entrance replacement; fabrication is proposed, not assigned. Other proposed entrance replacements remain deferred.

- **K-V2-PLAYER-FACES — Codex: generate and integrate original player expressions, starting with the V2 intro sequence.** Research meme-face history for expressive economy and reaction timing; retain the supplied androgynous drawn character, camera-linked gaze and readable face lighting. Next survey the native facial UV region, author a consistent expression sheet and bounded atlas, then connect witnessed prologue beats and inspect actual mirror playback, pause/reload and rendering cost. [Initial sequence, research and verification scope](design/V2_PROLOGUE_2026-10-28.md#player-expression-sequence--october29). Queued; no generated faces, runtime verification or artistic acceptance yet. No deadline.


- **K-V2-HOSE-CLOSURE — Canonical Codex, after current prologue qualification: close remaining installed hose use and maintenance gaps.** Reuse the October27 ten-waypoint union/extraction/charge/spray/disk proof; do not repeatedly rerun unchanged hose controls. Survey full-distance payout and bounds/cabinet clearance, release snapping, flat unpressurized skin, valve-sustained charge with independent nozzle lever, purchased gasket/protectant transfer and actual dressing, and only still-missing impact/wetting. Preserve inexpensive stored/resting presentation and inventory/payment/work-order/save owners. Measure and exercise affected gaps, then renew affected qualification; no whole-hose artistic acceptance. [Current proof and limits](design/V2_HOSE_INSTALLED_MAINTENANCE_2026-10-24.md); [residuals](design/V2_HOSE_SPRAY_READABILITY_2026-10-24.md).

- **K-V2-BOOK-NOOK-CLOSURE — Canonical Codex: qualify remaining book presentation, handling and installed nook coverage.** Native format categories, flexible paperback wrappers, deformed attached pages,30-title editing and61 varied nook copies are already implemented; do not restart the completed conversion or plant/rug/access repair. Inspect remaining print/contact appearance, first-use cover stalls, free-floating static interaction, shelf-slot return and reload through the real pickup owner; preserve publishers/layouts, selected art and existing keepsakes. [Current shelf proof](design/V2_NOOK_SHELF_DRESSING_2026-10-24.md); [binding/editorial history](design/V2_BOOK_EDITORIAL_AND_BINDING_2026-10-22.md). Wider coverage and artistic acceptance remain open.

- **K-V2-INTERACTION-COVERAGE — Canonical Codex: close exact-part targeting and general held-object/manipulation coverage in existing V2.** Survey authoritative reticle available/grabbed/blocked/inspectable/travel-limit states, free-cursor inspection, pickup-to-hand and XYZ translation/rotation with release snapping for fittings. Exercise real click/motion/release, pause/focus and intermediate saves across installed families; no duplicate targeting scans or legacy-toggle acceptance. Preserve easy doors, player accommodation and slow self-close; environment sweeps only where gameplay useful. [Established repair/coverage inventory](design/V2_STARTED_WORK_CLOSURE_2026-10-23.md).

- **K-V2-RADIO-SHOPS — Canonical Codex: finish all-shop radio settlement and useful resident staffing after current repairs.** Reconcile installed hardware purchasing with remaining point-of-sale adapters and employment assignments; exercise actual payment, supplies handoff, interruption and validated save/reload without adding duplicate finance/inventory or online-service authority. Research/native candidates are not all-shop delivery. [Existing programme and limits](design/V2_RADIO_SHOP_NETWORK_2026-10-22.md).

- **K-V2-RESIDENT-CLOSURE — Canonical Codex and resident-route owner where confirmed: reconcile V1-derived heroes and simultaneous preferred bar places with current V2 attendance.** Eighteen-model/idle and bar-approach family preflight exists; it does not prove all residents navigate or socialize in production. Preserve merged Juno/Nadia routes (PR85) and isolated draft PR53 Rhea/Guests work; establish ownership before integration, then verify actual navigation, distinct places/circulation, conversations, materials, saves and measured crowd cost. [Family proof and limits](design/V2_RESIDENT_CAST_AND_BAR_PLACES_2026-10-24.md). Do not infer an active owner from a branch's existence.

## D — Unresolved decisions and integration

**D1–D4** travel with the deferred studio brief below. **D5** was answered by the
relative-luminance default; **D6**'s cabinet decision is retired with that plan.
Neither changes period pub games or the separate mechanical fortune-teller.

- **D7** **Integrate the backed-up work** (2026-09-19): the main checkout's
  and the dream-voxel worktree's uncommitted work is now safe on
  backup/main-checkout-wip-2026-09-19 and backup/dream-voxel-s2-wip-2026-09-19,
  but it is still not integrated anywhere. The agent that owns each should
  commit it properly; then delete the backup branches. Both still exist on
  the remote as of 2026-10-25. The golden-shift half of this row is answered:
  the owner approved that cleanup on 2026-09-19, its branch is tagged
  `archive/2026-09-19/claude/golden-shift-v2-verify-c72c73` and its worktree is
  gone. `design/REPO_HOUSEKEEPING_2026-09-19.md` §7.

## A — The mechanical fortune novelty

Playable video cabinets remain retired. **A2/A4–A10** and the old cabinet-specific
plan are cancelled by the owner; original sources/programmes are preserved.
The future redesign remains deferred, separate from **A11**, which stays in V2.

- **A11 — BUILD “THE HOUSE HEARD BIG,” ONE 1927 MECHANICAL FORTUNE
  NOVELTY.** Owner-approved; execute `design/ORISON_FORTUNE_TELLER_BRIEF.md`
  and the audited owner contract in `design/HOUSE_HEARD_BIG_ORCHESTRATION.md`.
  Do not restore a video-cabinet cluster. Mechanism: John J. Scharli Jr., US
  1,621,756 (filed 1925,
  granted 1927), a coin-controlled fortune-teller whose mechanical head nods
  yes or shakes no according to the coin's path. Alternate: the 1926 Mills
  legend-wheel fortune/vending machine, US 1,586,455. Compare against a compact
  bagatelle/trade stimulator and mutoscope only with pre-1929 primary evidence;
  familiar coin-op pinball silhouettes are presumptively too late. One object,
  one cheap mechanical loop, bounded sound, no viewport, and no story authority.
  Audit the obsolete `orison_original_advert_lobby_v1.png` source at the same
  gate: default recommendation is archive as concept provenance and remove its
  unused runtime prop after reference migration, not rescale it into production.

## G — Local music and found traces

Preserve local songs, recording/reconstruction and listening. The phonautograph's
existing playback/trace rules remain in Bible §III.2 and the Songbook references;
archiving a completed local-contract note does not change those rules.
Network distribution, phrase duels and the House Rig audition are deferred below.

- **G3** A trace is an OBJECT, like a reel: findable, carryable, losable. Some
  are already in the building and the player did not make them.

- **G4b** The sleeves are the hook and they are deliberately thin: "for M." with
  four residents whose name starts with M, a WORS sleeve with the date rubbed
  out, one found behind the pipes, one with no sleeve at all. **Nothing in the
  bar can resolve any of them.** What the basement studio should be able to do
  is say something about a trace the bar cannot - a cleaner read, a second
  voice, a date - and that is the errand.

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

- **E13 — DEFERRED AFTER V2: GENERATED COMMENSAL C2 ANCHORS (BLOCKED BY E14 AND SHARED-FILE
  SCHEDULING).** After a successful C1, reserve an uncontended `gen_layout.py` pass
  and emit marker kind, species affinity and clearance-validated run-lines as
  generator facts. Never hand-edit JSON or put coordinates in runtime code.
  `gen_layout.py` is known contended ground: inspect shared index/worktree,
  confirm no other lane holds hunks, preserve them if it does, and stage every
  generator/output file by exact name. This is the PS12a lesson made an
  acceptance condition, not a note discovered after a conflict.

- **E15 — DEFERRED AFTER V2: COMMENSALS C2, WAKING BREADTH (OPEN; C1 SUCCEEDED).** Add
  roosting pigeons and one proximity flush, rare validated rat gutter-runs,
  positional guano/web decals, and restrained Passage/B1 casts. Room 0 has no
  animal-exclusion rule. Maintain one
  MultiMesh per class per zone, hard submission caps and no runtime routing.
- **E16 — DEFERRED AFTER V2: COMMENSALS C3, §E INTEGRATION (BLOCKED BY E15 AND ITS OWNER
  RULING).** Move pressure onto §E anchor persistence, route personality-
  filtered ambient complaints through the existing place/fault work-order
  binding, add period countermeasure errands, and let Murphy's director choose
  fair moments from eligible pressure. Never advance a case, undo a repair or
  fire during protected interaction/dream windows.
- **E17 — DEFERRED AFTER V2: COMMENSALS C4, SEPARATELY RULED BREADTH.** Price and rule broader
  audio and the optional Harukiya mouser independently. The rejected haunting
  hush/flush hook is not part of this owner. Commensals never carry signal, imitate the motif,
  confirm a haunting, stalk the player or become dangerous.

## S — Basement studio (deferred after V2)

**D1–D4 / S1–S5 / related G2/G4b**: preserve installed space and listening systems;
defer expansion, storage cages, staffing and echo-return choices. Later survey the
actual V2 room before authoring a restoration desk, chamber or dead-channel chore.
Receiving local/shared versions must not acquire a new basement-visit gate.
Source: `design/ORISON_STUDIO_BRIEF.md`; original requirements remain in Git.

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

### W — Current glazing and joinery gaps

The historical W-GLAZE/W-SHOW/W-JOINERY completion and measurement journal is
archived in the pre-trim source. Preserve optical materials, room reveal/seals,
source-owned joinery, loaded UV/mipmap requirements and any still-reproduced
appearance/access defects under the current V2 surface audit. Do not treat old
pictures or a technically passing surface contract as owner appearance approval.
`design/V2_SURFACE_REQUIREMENTS_2026-10-11.md` governs new city windows as well.

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

## F — The street film tent

- **F-RELOCATION — Complete the requested period one-person film tent beside the
  bar, retire the three mounted apartment projectors and their abandoned leads,
  and verify entrance, sidewalk and subway access.** Preserve current film
  decoding, source programmes, power, case/haunting and save authorities while
  relocating presentation. A candidate tent is not an installed, qualified venue.
  See `design/V2_STARTED_WORK_CLOSURE_2026-10-23.md` and the current runtime's
  `orison_v2_projectors.gd`. Do not restore old machine counts or apartment rules.
- **F3 — Retain unresolved motion-based content curation.** Inspect complete
  clips, not a single frame; remove incompatible trailers/titles from a shortlist.
- **F5/F11/F12/F5b — Reconcile unfinished film/plate presentation with the tent.**
  Keep any still-missing long-exposure accumulation, optical wear, gate weave,
  keystone, projector beam and state-driven burn as explicit gaps after checking
  the current renderer. Reuse existing accumulators rather than duplicate one.
- **F6/F7/F8 — Preserve film audio semantics and the unresolved reel-selection
  work.** Local chosen programmes/found objects remain distinct from the Tenant
  running a machine. No invented collectible, reward or haunting reach follows
  from this queue cleanup. The magic-lantern alternative in **F13** is historical
  proposal material, not a reason to replace the owner's nickelodeon direction.

Historical completed parts and superseded **F2/F4/F4b/F4c/F14/F15/F16/F9/F10**
placement/count assumptions are archived by source commit in the review record.

## Q — Direct manipulation

Historical **Q1–Q6** completion notes are archived. The current contract remains
primary-click grab, constrained mouse motion, next-click release and supported
inspection. Actual input, pickup/held-book behavior, focus and interruption
requirements remain under **I**, **K** and AGENTS.md; old toggles prove none of them.

## X — The haunting

Audited in `design/ORISON_HAUNTING_AUDIT.md`. Measured, not opined: the
instinct that something in here does nothing was right, but it is not an idle
system - **it is more than half the authored content.**


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

## N — Installed dream content

Historical completed **N3/N6–N13** notes are archived, not deleted from the game.
The future murder-year campaign uses maintenance and dream material as optional
investigations; it has no mandatory repeating repair/narcolepsy sequence. Current
V2 route/save qualification and protected conversations remain unchanged. New
defects in installed content still enter **K4/I/H** from actual evidence.
See Bible §VIII.5.o and `design/THE_YEAR_YOU_DIED_POST_V2_2026-10-26.md`.

## FA — Installed fauna, with new breadth deferred

- **FA-V2-GAPS — Retain repairs and acceptance gaps for installed creatures.**
  Preserve the native tentacle encounter, Tardi, microscopy, local autonomy and
  accepted contact/dissolution behavior. Use current family records and their
  stated limits; historical fauna contracts do not qualify all of V2.
  `design/CREATURE_MAIN_INTEGRATION_2026-10-26.md` is the integration baseline.

**FA3–FA4 / FA-V5 / CT-2**, related unbuilt **E13/E15–E17/DF/DT** breadth and new
families are deferred. As gameplay uses appear, vet them and add bounded work;
do not treat this as cancellation of installed ecology or approved future people.

## M — Current surface, device and creature gaps

- **M1** Supertiles and stable per-wall UV offsets. Explicitly **not** part of
  the plaster repair, which was fixed without them — an optional later
  anti-repetition enhancement, with a real VRAM cost to decide first.
- **M2** `family_mean_spread` is defined on the compiler side but has never run:
  one texture per material means no family to compare. If the planner ever emits
  texture variants, that gate is unexercised.
- **M3** Compiler textures are 128² at roughly 64 px/m, which is the deeper
  reason features come out large relative to the tile.

- **M-V2-TENTACLE-GAPS — Reconcile TB1–TB16 and DT3/DT4 against the installed
  native family and newer owner briefs.** Keep only remaining anatomy, ocular/
  crystal details, attachment, deformation, surface, collision and rendering
  acceptance gaps; do not restart completed cage/rig/bake construction. Compare
  earlier requirements rather than silently mark them all done. Source:
  `design/DREAM_TENTACLE_BLENDER_BUILD.md`, `design/HERO_TENTACLE_REMAINING.md`,
  `design/TENTACLE_GANG_SURFACE_COMPLETION_2026-10-26.md` and the PR63 baseline.
- **M-V2-ORGAN-GAPS — One installed field/organ/lifecycle gap list for DF/DO/LC.**
  Preserve signal-specific answers, local autonomy, field/optical occlusion,
  withdrawal/residue, stage handoff and save/case truth boundaries. Reconcile
  **DO3/LC6** residuals with completed substeps; defer unbuilt breadth unless a
  vetted gameplay use needs it. Historical scripts, packets and receipts remain.
- **M-V2-MICROSCOPY-GAPS — Track only current installed-family acceptance and
  repair limits.** The completed **MBIO1–MBIO6** construction journal is archived;
  use `design/V2_TARDIGRADE_MICROSCOPY_2026-10-25.md`, current Tardi records and
  `design/CREATURE_MAIN_INTEGRATION_2026-10-26.md`. The external impossible-organ candidate remains INERT/research-only: review is not authorization to install or alter the established friendly prologue specimen. Do not repeat accepted anatomy
  and field construction just because its historical checklist is long.
- **TL-GAPS — Finish the current autonomous companion, physical paper/keyboard,
  controls, sound, lamp and readable presentation against their actual owners.**
  October28 refit: approximately phone-sized, close to the face, contextual right
  third framing; flight-path body language with puttering/weaving and effortful
  upright correction, steady for reading/typing. Recheck native proportions,
  arm fit, mirror scale, lamp alignment and actual input. Direction and current
  limits: `design/V2_COMPANION_TERMINAL_2026-10-24.md`.
  Reconcile legacy **TL2–TL5** mechanism/material/wear/tactility goals rather than
  rebuild the retired handheld shell or restore ink/heat instructions. Preserve
  protected typing drafts, pause, power, memory and validated campaign state.
  Source: `design/V2_COMPANION_PHOSPHOR_2026-10-25.md` and companion integration
  records. **TL6–TL9** (RETURN, reality inspection, impossible correspondence and
  creature recognition) remain unresolved narrative capabilities for explicit
  story-fit reconciliation, not silently completed or cancelled features.
- **TL-VOCAL — Give the companion a learned synthetic speaking voice.** Owner
  direction2026-10-29: begin with Speak & Spell-inspired babble and original
  16-bit game-inspired laughs, crying, emotive whines and other reactions;
  indirectly acquire English through interaction, mimicking any word it hears.
  Preserve articulate physical-printer dialogue and existing narrative/input
  owners. Learn from actual witnessed utterances, never future/offscreen text
  or the companion's own babble; persist learning through validated campaign
  storage. Use existing voice-volume control, bounded playback and cooldowns;
  do not silently enable a microphone. First complete the current crossing
  repair, then integrate and audition this voice. The crossing checkpoint is now
  pushed; voice learning/playback remains unimplemented. External October29 sound
  research and 19 source-supported finalist recordings are in
  **C:/ov/reports/companion_sound_research_20261029/**; audition, item-specific
  rights recheck and contextual assignments remain open, with uncertain archival
  clips held out. The original synthetic sketch is also unaccepted. No blanket
  legal clearance or artistic approval is implied.
- **MX3/MX4 — Retain actual material-ingest and rollout gaps.** Verify calibrated
  height/relief, tile scale, ORM/detail/mask authoring and still-unaccepted classes
  against the installed pipeline. Recheck old missing-map/42-height assertions;
  do not blindly repeat old triplanar rollout, disable PBR or restore obsolete
  Compatibility budgets. Archived MX specifications and the material catalogue
  remain the reference, not another current-state claim.
- **MP/DP — Keep surface quality and loaded-mipmap verification active.** Preserve
  close-up detail, material scale/grain, UVs, normal calibration, optical glass,
  side-correct moisture and loaded texture requirements. Use
  `design/V2_SURFACE_REQUIREMENTS_2026-10-11.md` and actual same-settings renders.
  Old floor-repetition, glass-map and translucent-plane journals are references;
  archive disproved premises and promote only still-reproduced defects.
- **T4-4 — Preserve the temporal-evidence gate for future organ/anachronism work.**
  Record observation → misreading → embodiment, runtime owner and case/save/time
  boundaries. Future forensic time travel does not silently transfer authority
  to a visual effect or license arbitrary future props.

Completed **MC-P/LF/DT/DO/LC/MBIO/T4/CT/MX** clauses are archived with their
source/evidence pointers. Both contradictory **CT-1** queue entries are retired
as a historical atlas-status duplicate, not renewed V2 artistic acceptance.
Standing material specifications remain in the Bible, catalogue and surface
requirements; this queue is for outstanding work.

## EN — Encroachment presentation

- **EN1 — Owner appearance review remains open.** Historical frame delivery is
  not human acceptance. Compare the actual installed layer/portal/fold behavior
  and any still-live artistic concerns before preparing another bounded review.
  Source: `design/DREAM_ENCROACHMENT_BRIEF.md` and the original EN records.

Completed **EN1b/EN3/WK1** and completed portions of **EN2** are archived. Retain
any still-reproduced portal-camera, fold placement or ornament/performance issue
under the current installed-family gap audit; old timing numbers are not targets.

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

- **C4 — Future harpy and succubus/oni characters with in-world cultures.**
  Preserve the rigged originals and walk libraries in `art/source/held_characters/`.
  Vet actual gameplay uses and develop the cultures/roles before adding runtime
  characters; today's eighteen-resident roster stays unchanged. The earlier U2
  assumption that these were disposable non-cast assets is superseded.

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

## P — Current measured V2 performance

- **P1 — Follow K-V2-FIRST-VIEW-HITCH with current occupied-world evidence.**
  Separate scripts, physics, loading/streaming, shader compilation, render
  submission, shadows and private-viewport costs; retain cold/warm distributions
  and actual input. New city work must measure its incremental cost on the same
  route/settings and preserve visual detail through measured tradeoffs.
  October28 frame-linked passage attribution isolates atomic fitting calls up
  to37.446ms despite the8ms cooperative budget; split/reduce that work without
  relaxing source/collision validation. See the dated section in
  `design/V2_COOPERATIVE_NATIVE_FITTING_2026-10-23.md`; probes are not a repair.
- **P2/P3/P6/P8 — Historical leads, not automatic prescriptions.** Reproduce
  relevant occlusion, shadow, mirror/reflection and tier/culling issues in the
  current V2 composition before optimizing. Keep any reproduced defects active;
  archive old V1 station numbers, rejected fixes and superseded budget levers.

The next release is desktop-only. **L12** and mobile parts of **P1/P4** are not
near-term delivery gates; existing export/source configurations remain until
deliberate cleanup. Explicit V1 rollback/protected paths remain intact.
Measured repair history: `design/V2_BACKGROUND_HOUSEHOLD_SAVES_2026-10-23.md`.
Performance/counter procedure: `.agents/skills/godot-development/SKILL.md`.

- **P-BODY-MESH-LOD — Implement authored body-mesh switching alongside detail
  omission.** Design: `design/V2_TRAFFIC_BEHAVIOUR_2026-10-24.md` §9. After the
  current cleanup/measurement checkpoint, pilot one measured traffic stock:
  optional versioned visual schema, true near/mid/far body mesh sets, Blender
  export/validation, projected-size selection with hysteresis, bounded MultiMesh
  migration and ready fallback. Preserve existing gameplay/part/save owners,
  native index LOD, critter budgets and relevant mirror/telescope/inspection
  detail. Compare cold/warm same-settings frame distributions, draws, triangles,
  shadows and memory; inspect actual rendered transitions and affected input,
  then qualify the candidate. Roll out only where measured benefits justify it.
  **QUEUED: design only; no runtime implementation or acceptance yet.**

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


**SR6/SR7 — Deferred after V2:** retain the rolling attention ledger and
vertical-anatomy expansion briefs, but finish current route, maintenance,
accessibility and reload repairs first. Existing authorities stay installed.

## H — Housekeeping


- **H2** **`C:\FPSengine01` is not a git repository.** The entire compiler side —
  the world compiler, the providers, the arcade catalog build, the texture
  validation — is unversioned files on disk. `git init` and a first commit.
- **H3** `worldc clean --stale` has no test covering it.
- **H13** **Logical placement audit.** Is each object placed correctly, and does it belong there. Convention traps are listed in the brief (door markers are the hinge jamb; pendant markers are ceiling anchors with a drop). Note placement cannot lean on the router to prove a route is clear — see R6, residents walk through furniture. Brief: `design/AUDIT_BRIEF.md`.
  - **H13-PRESENTATION — LIVE PRESENTATION AUDIT (INSTRUMENT BUILT AND FIRST RUN 2026-08-21; GENERATOR FIXES STILL WAIT).** `res://tests/PresentationAudit.tscn` boots production `BuildingRoot` with WalkTest's discipline and runs seven passes: live cross-class AABBs with an assembly whitelist (25 leads), authored-base support rays (16; every kitchen toaster base 215 mm inside the furniture hull), WalkTest's `[ART]` sweep verbatim, dressing-per-m² census with bottom decile (five zero-record rooms; 2D's bedroom), 1.4 m wall rays (5,783 rays, 0 see-through — lead closed), height-classified ceiling rays with the real `show_all_floors` toggle (the corridor 22% is the atrium light well plus one stray point per floor), and a windowed eight-station OrbitSweep (granted set direction-blind; 0/288 frames dropped a centre-in-view light — the "lights disappear with direction" lead is not gating, churn or culling). The 183-still harness rerun wrote 182 frames. Rows are in `design/walkthrough_punchlist.md` under 2026-08-21; proof, JSON and CSV at `art/renders/presentation_audit_h13/README.md`. The first generator fix landed the same day: `_toaster_marker`'s yaw-rotated offset stood every generated kitchen's toaster on its dishrack; it is in the run frame now, `_validate_kitchen_worktops` guards it, only the ten toaster markers moved (no GLB rebuild), and the re-audit is toaster-clean (support faults 16 → 6). The roof ventilator V-B, which the garden pass had buried in the east bed, now stands on open roof south of it (marker move). 2D/5D's empty rooms are the building's own vacancy rules; the 6A monitor overlaps are the prop's cable mesh through a 50 mm desk top. Remaining leads (bar speakers/songbook mounting, 4B closet/vestibule dressing) are taste calls for the walk, not generator defects.
- **H22** **Reader-gate loader/consumer split.** The gate credits a field
  only in a script that also names the data file, so a field read through a
  loader's returned dictionary counts as unread (darts_panel.gd reads the
  trivia card's "q" and "blurb"). Of 1,295 unread fields at 1c1c578, 662 are
  named nowhere in production code and 633 are named only outside the loading
  script; see `design/REPO_HOUSEKEEPING_2026-09-19.md` §6 for the sampled
  estimate before changing the gate or the baseline.
- **H23** **Close the voxel-light seam.** Two voxel lights now sit side by
  side by owner ruling: the earlier presenter and Astra's critter binding.
  Three suites fail at their boundary and are accepted by name, not fixed:
  DreamZooWarehouseTest (placeholder species), DreamVoxelV1Test (shared
  field allocation) and DreamCritterVoxelBindingTest (shared sampler
  channels). Merging the two lights should close all three; see
  `design/REPO_HOUSEKEEPING_2026-09-19.md` section 9.

- **H25** **Capture receipts still conflate lane-busy and timeout.**
  (Found 2026-09-19, re-verified 2026-10-25.) The serial runner returns 73 for
  lane busy, 124 for a ceiling kill and 78 for could-not-run, but
  `tools/run_godot_capture.ps1` maps only 73, to `BUSY_OR_TIMEOUT`; a 124 kill
  is recorded as `FAIL`, and 73 can no longer mean a timeout. Split the receipt
  status into BUSY, TIMEOUT and FAIL and retire the combined label. It changes
  capture-receipt vocabulary, so whoever owns that schema makes the call; the
  comment in that script now states the real behaviour rather than the old one.
- **H26** **GoldenLoopTest cannot run under explicit v2.**
  (Found 2026-09-19, re-verified 2026-10-25.) `game/tests/golden_loop_test.gd`
  still loads `res://scenes/building/orison_root.tscn` literally instead of
  asking **BuildingRootSelector**, so the only end-to-end eleven-beat harness
  is v1-world evidence whatever the selector says. Route it through the
  selector, or retire it in favour of a schema-2 runtime-contract suite.

- **H-CODEBASE-SIZE — Codex, continuous: reduce only newly audited excess files/bytes without weakening recovery or current evidence.** PR76–79 already consolidate 25,740 plus 4,878 source copies and retire 734 historical images with indexed recovery; that cleanup is complete, not a reason to repeat it. Next measure current residual consumers/size before selecting another bounded batch. Preserve editable/runtime assets, current acceptance packets and shared history; no branch deletion. [Scope and recovery](design/AUDIT_UNUSED_SYSTEMS_REPORT.md#october-28--historical-evidence-storage-cleanup).


- **H-LOCAL-HANDOFF — Canonical Codex: finish app-owned temporary-baseline cleanup after this chat is handed back to Local.** Preserve codex/v2-prologue-20261028 and the clean baseline evidence; verify current app attachment, Git/index and reparse targets before archiving only the temporary v2-baseline worktree. The app previously refused archiving its calling chat's primary checkout; the owner's promised handoff is not proof it happened. Never remove other agents' worktrees/branches or bypass that refusal.
- **H-SKILL-EXCHANGE — Canonical Codex: verify the authorized Claude skill exchange and retain useful demonstrated lessons.** Godot, Blender, textures/shaders and pixel-art canonical skills exist under .agents/skills; confirm thin Claude adapters and reciprocal project notes rather than creating duplicate guides or claiming exchange from file existence. Keep general lessons separate from Orison-specific authorities; validate changed skills and links. This is tooling follow-through, not permission to edit Zorda gameplay.

## Deferred after V2 — preserved scope, not current blockers

- **G1 shared side / G2 / G6a / community S5:** network song distribution after
  V2; keep local songs, found traces and immutable playback. Consent, moderation,
  report/block, takedown, retention and platform controls remain prerequisites if
  public/friends sharing is resumed. `design/ORISON_SONGBOOK_BRIDGE_PLAN.md`.
- **G6 / related G8:** phrase-duel and lyric-book expansion after V2; retain the
  existing private music work. `design/ORISON_SONGBOOK_PHRASE_DUEL_BRIEF.md`.
- **G7:** defer the House Rig audition/decision; current sound and Music Bible
  authority remain. No added bass/distortion chain is silently approved.
- **A12:** future arcade redesign remains a commitment; the old cabinet-specific
  plan is cancelled. Do not restore cabinets ahead of that redesign.
- **E13 / E15–E17 / FA3–FA4 / FA-V5 / CT-2 / unbuilt DF/DT/LC breadth:** preserve
  current creatures; vet additional families as real gameplay uses appear. Keep
  explicit prerequisites and no new unchecked story/save/time authority.
- **SR6/SR7:** rolling attention and additional vertical anatomy are deferred;
  current route, maintenance and save repairs remain active above.

## Queue provenance and standing rules

October 27 owner decisions and exact pre-trim source references are in
`design/V2_TASK_RELEVANCE_REVIEW_2026-10-27.md`. Completed/superseded text is
recoverable from Git; original failures, receipts and assets are not erased.
The Bible, AGENTS.md, skills and existing references own standing rules. In
particular the deliberate pointer-release contract remains binding in
`design/REPO_HOUSEKEEPING_2026-09-19.md` §10; H24 was a rule, not unfinished work.
Funding, marketing and the fundable-release task are retired. Save reliability,
accessibility, responsive controls, visual quality and honest qualification remain.
