# SR7-O — the seal is not the charge

**Status: production-rendered proof complete.**

Base **`80dce46`** "Put the measured moon in the sky". SR7-N was confirmed
landed as `d0ca178` — byte-identical to the commit it replays — before this
branch existed; `origin/main` then moved three more times in Codex's
celestial lane, and the branch was replayed onto the new head with the whole
sheet re-shot there. The moon moves this interior by **0.000257** — small, but
this sheet's floors are EXACT zeros and its smallest non-zero claim is 0.000892,
so that drift is nearly a third of the faintest thing measured here. A sheet
carried across it would have been a stale sheet.

Captured 2026-08-26 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn` — the F03 stair landing, on the
board the building already draws. Shot through the player's own camera, lit by
the core's own pendant. No proof-only light, mesh, material, camera rig or
production owner.

## The thesis, and it is a byte identity

**A hose is not water was a conjunction. This is a non-implication:**

```
sealed()    = cap_on AND seal_wired            what an inspection sees
charged()   = acid_present AND bottle_seated   what a recharge leaves
will_lift() = loose_cap_free                   what makes it work

sealed() AND charged()  DOES NOT IMPLY  usable()
```

As found, the extinguisher is **sealed and charged and correctly heavy and
inert**. The lead-and-wire seal is unbroken, the tag is hanging, the bottle is
in its cage with four ounces of oil of vitriol in it, a pound and a half of
bicarbonate is dissolved in two and a half gallons of water underneath — and
the little cap that must lift off the bottle's neck when the vessel goes over
has been seized. Nothing is missing. Nothing is loose. It cannot work.

**Four frames on this sheet share one SHA-256** — `1f0de3f77e49…`:

| Frame | What it is |
| --- | --- |
| `00_board_control_a` | the unit **as found**: dead |
| `03_hefted_no_change` | the same unit, **after being lifted and weighed** |
| `10_sound_and_sealed` | the same unit, **repaired and re-sealed**: sound |
| `13_restored_after_abort` | the same unit, **aborted back to the fault** |

A dead extinguisher, a weighed one, a working one and an aborted one are
**literally the same file**. On the declared vessel crop, 410×610 px of nothing
but copper and brass, dead-to-sound measures **0.000000** while a refusal on
that same crop measures **0.112**.

## Where it hangs, and why

### The audit

| Question | Answer |
| --- | --- |
| Existing extinguisher geometry | **One object, and it is not an extinguisher.** `orison_detail_pass.gd` batches a flat red box at b(−2.76, −3.10) that is 0.34 wide × **0.08 deep** × 0.70 tall, on **all eight floors**, and its own comment calls it an "extinguisher cabinet". |
| Is it a cabinet? | **No.** 80 mm cannot hold a 2½-gallon vessel 230 mm across. It is a **backboard** — the painted plate an extinguisher hangs in front of. |
| Any functional owner? | **None.** No prop, data record, job, activity, case, inventory item, save fact, signal or fire owner. Searched by vocabulary across every `.gd`, `.tscn`, `.json` and `.py`; the only other hits are SR7-N's header quoting that same comment and the Dream's unrelated business of extinguishing lamps. |
| Layout furniture? | **None.** The only "bucket"/"fire" hits are a B1 ops chemical bucket, a bar accessory, a shop soda fountain, three buckets in flat 3C, and the exterior fire escapes. No extinguisher. |
| Relationship to SR7-N | **Adjacent lane, nothing shared.** SR7-N is a fixed wet standpipe station on F01's east wall whose lesson is a conjunction of joints. This is a portable chemical vessel on F03's south wall whose lesson is a non-implication. No file, signal, predicate, record or term in common — asserted in both directions by reading each other's source. |
| `WorkOrders`? | **No.** See *Ownership*. |
| `MaintenanceActivityLibrary`? | **No.** See *Ownership*. |
| Periodic or reported? | **Periodic.** Nobody complained about this extinguisher. It is found on a round, and its output is a condition written on a tag. |
| Reuse, supersede, or leave? | **Reuse, precisely.** The batched box stays exactly as it is on all eight floors; the functional apparatus is placed on **one authored instance** of it and reads it as the backboard. Nothing is redrawn and nothing is superseded. |

### Every number read off the board

| Quantity | Source | Value |
| --- | --- | --- |
| board centre | batched at b(−2.76, −3.10) | **x −2.76** |
| board depth | 0.08, so its front face is | **y −3.06** |
| board height | z+0.70 to z+1.40 | bottom edge **z+0.70** |
| prop origin | that face, at that edge, on F03 | **b(−2.76, −3.06, 7.10)** |
| landing | solid south strip of the well | y −3.16…−1.46 |
| stair doorway | south wall opening | x −1.6…1.6 |
| clearance to the west jamb | measured live | **0.99 m** |
| projection into the landing | vessel front at local z 0.248 | leaves **1.35 m** |
| F03 core pendant | `F03_ATRIUM_FRUIT_1` | **3.18 m** — the closest any floor's core light comes to this board, against 3.95 on F01 |

**Why F03.** The board exists on all eight floors and this hangs on one. F03's
is the only instance a man could read by the stair's own light. It is also two
floors above SR7-N's standpipe cabinet — 5.90 m between the two props, measured
live — which keeps two different fire apparatus from being mistaken for one
lane.

### What it costs the frame

Asserted on the production instance: **0 realtime lights, 0 collision bodies**,
7 `Area3D` reach volumes that report overlaps and stop nothing. No per-frame
raycast, no physics, no unique texture — every surface is a `_pmat` colour on
shared primitive meshes.

## Mechanism, and what is documented

| | as found | documented by |
| --- | --- | --- |
| the cage | spring clips under the cap, holding the bottle | **J. M. Miller, US 883,326** (filed 30 Apr 1906, patented 31 Mar 1908): clips "formed of resilient wire … so as to provide a cage for confining an acid bottle"; the bottle "is inserted into the cage by passing the same downward through the ring 5"; the clips "support the same when the casing is inverted". |
| **the loose cap** | **seized** | The same patent, and it is the sentence this apparatus turns on: "The usual **LOOSE CAP** 12 is provided for closing the neck of the bottle and has the shank 13 which extends into said neck to prevent the cap from falling out of place when the extinguisher is inverted." Loose, and merely retained. Its failure mode is written into its own description. |
| the charge | alkaline solution in the tank, acid in a small receptacle | **H. M. McCaslin**, assigned to **American La France Fire Engine Company**, **US 1,182,186** (filed 25 Feb 1916, patented 9 May 1916): "an alkaline solution carried by a tank and a quantity of acid carried in a separate smaller receptacle in the tank, so as to be mixed with the alkaline solution for creating a gas for forcing liquid through a suitable discharge opening." |
| the family | soda-acid, American origin | **A. M. Granger of Boston, US 258,293** (filed 15 Sep 1881, patented 23 May 1882), cited for the family rather than this unit's mechanism — Granger breaks the bottle by "a torsional strain" where this one lifts a cap off it. |

**The valve of this apparatus is its own destruction.** There is no verb that
turns it over. Inverting a soda-acid extinguisher is not a test of the
mechanism, it *is* the mechanism: the cap lifts, the acid goes into the soda,
and you are holding a spent vessel over a wet landing. There is no pressure
gauge to read because there is no pressure until you commit, and this apparatus
does not invent one.

**And weight cannot see the fault — not approximately.** Nothing is missing, so
the faulted unit and the sound one do not weigh *almost* the same, they return
**the same float**. The focused suite asserts that as an equality rather than a
tolerance, and `heft_pounds()` is proved by source-read to consult not one owned
fact and to contain no branch at all.

### What is *not* claimed

I could not verify a pre-1928 rule requiring annual recharge or any dated
inspection interval. **The apparatus therefore asserts no schedule**: no due
date, no interval, no overdue state, no calendar, and the focused suite scans
the code for `due_`, `overdue`, `interval` and `next_inspection` to keep it
that way. The tag records a condition found at an hour and nothing about when
anybody should come back. Projecting a modern inspection cadence onto 1928 was
the easiest sentence available here and it is not in the file.

The charge proportions (1½ lb bicarbonate to 2½ gallons; an 8-ounce bottle half
filled with acid) come from the **later** patent record and retrospective
accounts, and are used for the weight arithmetic only — they are not claimed as
a verified 1928 specification. The "lead and wire" seal is likewise described in
retrospective accounts of the period hardware rather than in anything I could
verify from before 1928.

**Orison inference:** that the batched plate is a backboard; that this building
hangs its extinguisher on the F03 landing; the enamel charge plate; the pencil
on the tag. **Authored fault:** that this particular unit's loose cap was seized
at some past recharge.

## Definitive frames

All 1280×720. SHA-256 truncated to 32 hexadecimal characters. Three cameras:
the board, the neck, and the shelf.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_board_control_a.png` | `1f0de3f77e4943db549e4f5a9e3bf95e` | **As found**: copper vessel on the authored board, sealed, tagged, charged — and dead. |
| `00_board_control_b.png` | `1f0de3f77e4943db549e4f5a9e3bf95e` | **Byte-identical** — the board camera's A/A floor. |
| `01_cap_control_a.png` | `fcc16ea85be640d3750be3356db01510` | The neck, the lugs and the lead-and-wire seal. |
| `01_cap_control_b.png` | `fcc16ea85be640d3750be3356db01510` | **Byte-identical** — the neck camera's A/A floor. |
| `02_shelf_control_a.png` | `95c6da80a8bfd3fa5d6cf0ea7ba2b0fc` | The shelf, empty, as found. |
| `02_shelf_control_b.png` | `95c6da80a8bfd3fa5d6cf0ea7ba2b0fc` | **Byte-identical** — the shelf camera's A/A floor. |
| `03_hefted_no_change.png` | `1f0de3f77e4943db549e4f5a9e3bf95e` | **Hefted — and the same file as `00`.** Weight settles nothing. |
| `04_cap_refused_by_seal.png` | `ca92c44a1c16d9ab8c09b4ed21b57d23` | **Refusal**: the wire takes the pull and the cap lifts the width of the seal and stops. |
| `05_seal_cut.png` | `60927bd1b83adeac9659405ac4e7cf6e` | The seal cut away. |
| `06_cap_off_cage_up.png` | `8aa3e3098206e9a869e7c11646465814` | **The cage comes up with the cap** — clips, hoops, the bottle, its lead cap, its acid level, and the open neck below. |
| `07_bottle_drawn.png` | `32375d35f32eee40abeaadeefbe22c89` | The bottle out of the clips, standing on the shelf. |
| `08_diagnosis_bottle_comes_up.png` | `3aca687dfbd5929fc365737d5a15578d` | **THE DIAGNOSIS.** You lift at the little cap and the bottle comes with it. |
| `09_cap_worked_free.png` | `024cc7ddae6536b5d6bf9f458b01e124` | Worked free: the cap rides proud of the neck. |
| `10_sound_and_sealed.png` | `1f0de3f77e4943db549e4f5a9e3bf95e` | **Repaired, seated, capped and re-sealed — and the same file as `00`.** |
| `11_tag_signed.png` | `cee517b1a7122f48794cea505832c0de` | The tag, written. |
| `12_invert_refused.png` | `f8ba513af59803d22a571903262a2ca9` | **Refusal**: it tips on its hooks and it does not come off them. |
| `13_restored_after_abort.png` | `1f0de3f77e4943db549e4f5a9e3bf95e` | Abort — **and the same file as `00`.** |

Seventeen frames, **eleven distinct files**. Three of the collisions are A/A
floors. The fourth is a four-way tie, and it is the increment's whole argument.

## Pricing

Normalized RMSE, ImageMagick 7.1.2. **All three A/A floors are exactly
0.000000, confirmed by matching SHA-256** — this scene is fully deterministic,
so every number below is measured against a true zero rather than against a
noise floor.

### Whole frame

| Pair | RMSE |
| --- | ---: |
| board control A → B | **0.000000** |
| neck control A → B | **0.000000** |
| shelf control A → B | **0.000000** |
| **as found → hefted** | **0.000000** |
| **as found → repaired and re-sealed** | **0.000000** |
| **as found → restored after abort** | **0.000000** |
| the seal cut | 0.000892 |
| the cap off, cage up | 0.0460 |
| the bottle drawn | 0.0194 |
| the cap worked free | 0.00673 |
| the tag signed | 0.00193 |
| REFUSAL — the wire takes the pull | 0.0247 |
| REFUSAL — the bottle comes up with its cap | 0.0241 |
| REFUSAL — it will not go over | 0.0585 |

### Declared crops

| Subject (crop) | Change | RMSE |
| --- | --- | ---: |
| the vessel `410x610+466+28` | A/A floor | **0.000000** |
| the vessel | **DEAD → SOUND, at the vessel itself** | **0.000000** |
| the vessel | REFUSAL — it tips and does not come off | **0.112** |
| the seal `320x50+478+422` | A/A floor | **0.000000** |
| the seal | the lead-and-wire seal cut away | 0.00645 |
| the seal | **REFUSAL — the wire takes the pull** | **0.0218** |
| the loose cap `170x240+582+134` | A/A floor | **0.000000** |
| the loose cap | it works free and rides proud | 0.0319 |
| the loose cap | **REFUSAL — the bottle comes up with it** | **0.0687** |
| the tag `70x44+464+298` | A/A floor | **0.000000** |
| the tag | the tag is written | 0.0334 |

The vessel crop is the sheet. **410×610 pixels of copper and brass, and the
difference between an extinguisher that works and one that cannot is
0.000000 — while tipping that same vessel fourteen degrees on its hooks scores
0.112.** The fault is not photographable. The refusal is.

## Sheets that were discarded, and what discarded them

1. **A layout with the shelf on the west.** The stair core's west wall is only
   0.38 m from the board, so the drawn bottle stood in a corner no reader could
   get in front of and the sheet's own camera would have been inside plaster.
   The shelf, the drawn bottle and the tag were moved **east**, toward the
   doorway, and the hose moved west to make room — a placement change forced by
   a camera that could not legally stand anywhere.
2. **A first board frame that cropped the cap and buried the charge plate.**
   Backed the camera off from 1.30 m to 1.54 m and narrowed to 36°.
3. **A diagnosis frame nobody could read.** The bottle was dark amber against a
   dark vessel and its lead cap was indistinguishable from its neck. The glass
   was lightened, the acid level darkened, the lead cap enlarged, and the lift
   pose increased from 62 mm to 78 mm and from 0.14 to 0.24 rad. The declared
   crop went from unmeasurable to **0.0687** against an exact-zero floor.

The refusal-bleed bug SR7-N's measurements found is not repeated: this harness
calms the instrument after every refusal frame, which is why `05_seal_cut` and
`09_cap_worked_free` carry their own state and not the previous frame's pose.

## Executable proof

Every run through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, output redirected and only filtered results read. **Zero parse errors,
zero script errors, no timeouts.**

- **`ExtinguisherTest.tscn`: PASS 209/209**, exit 0.
  - Three predicates, and `will_lift()`'s body — read out of the source file —
    never mentions the seal, the cap, the acid, the bottle, `charged` or
    `sealed`.
  - **Bottle present is insufficient**: seated, full, and dead. Emptying it
    changes `will_lift()` not at all.
  - **Cabinet appearance is insufficient**, twice: once as found, and once in a
    state the mechanism itself allows — a cage screws down as sweetly empty as
    full, so the unit can be reassembled and re-sealed with the bottle standing
    on the shelf and will still refuse, pointing at the cage.
  - **Seal intact is insufficient**: it will not certify, and the cap will not
    turn under the wire.
  - **Weight is insufficient**, proved rather than rejected: the broken unit
    and the sound one return the *same float*, and `heft_pounds()` is shown by
    source-read to consult no owned fact and contain no branch.
  - **You may not certify a cap you have not lifted**: with the mechanism
    forced sound and nobody's hand on it, the tag still refuses.
  - **There is no test**: `invert()` refuses as found, refuses when sound, and
    refuses after the tag is signed; the code contains no `discharge`, `spray`,
    `psi`, `pressure_`, `gauge`, `suppress` or `water_level`.
  - Three ordering rules, every one of them mechanical; everything else is free
    order and reaches the same record.
  - **Six different refusal poses**, walked and collected.
  - Abort restores all nine owned facts, forgets that anybody lifted the cap,
    and **cannot retract** the published fact.
  - The code reaches no `WorkOrders`, `RealityCases`, `RealityState`,
    `MaintenanceInventory`, `MaintenanceActivityLibrary`, `FirstShiftDirector`,
    `CoreLoopDirector`, `ObjectiveTracker`, `ScheduleDirector`, `SwitchSystem`,
    `WatchStationNetwork` or `maintenance_items`, and declares no `required`,
    `must_visit`, `checklist`, `objective`, `completion`, `waypoint`,
    `onboarding`, `due_`, `overdue`, `interval` or `next_inspection`.
  - **SR7-N is a control, not a foundation**: neither file references a single
    symbol of the other, in either direction.
- **`ExtinguisherLiveTest.tscn`: PASS 72/72**, exit 0. On the real Orison: the
  prop sits on the board's own centre line, at its measured front face and
  bottom edge, on F03's real landing, 0.99 m clear of the real doorway jamb,
  leaving 1.35 m of landing, 3.18 m from the real core pendant. It adds **no
  light and no collision body**. The whole inspection works on the production
  instance. **SR7-N's cabinet is byte-for-byte what it was, published nothing,
  and its line is still not made up.** No work order issued or closed; the live
  job spine byte-identical and `has_open_work()` unchanged; no case moved; **not
  one save key moved**; not one door leaf moved; not one lamp changed power; the
  watch line recorded nothing and the extinguisher is not on it; the tour key
  never left its hook; the night register byte-for-byte what it was.
- **`InteractionInventory`: functional 282/37**, up one instance and one family
  for the extinguisher, from SR7-N's 281/36. Non-functional rises 756 → 763 in
  the *same* 25 families: those seven are this apparatus's seven reach areas,
  which land in the existing shared `prop_control_area.gd` row rather than
  starting a family of their own.
- **SR7-N re-run as a control on this branch: `FireLineTest` PASS 163/163,
  `FireLineLiveTest` PASS 66/66** — unchanged, with the extinguisher in the
  building.
- Every other suite green with the extinguisher in the building:
  `WatchPairTest` 118/118, `WatchPairLiveTest` 42/42, `WatchStationLiveTest`
  38/38, `WatchRegisterLiveTest` 40/40, `TourKeyLiveTest` 39/39,
  `NightRegisterLiveTest` 64/64, and Codex's `FirstShiftRitualTest`,
  `FirstShiftOpeningLiveTest`, `FirstShiftOpenLineLiveTest`,
  `FirstShiftCustodyTest`, `CoreLoopTest`, `CelestialEphemerisTest`,
  `LiveWeatherServiceTest` and `PeriodRealityLayerTest` all PASS with 0
  failures.
- **`WeatherSkyTest`: PASS (0 failures)** — but only after a `--import` pass.
  On the first run in this worktree it reported 5 failures, all of them "No
  loader found for resource" against `orison_clear_milky_way_half_dome_4k.png`
  and `lroc_color_poles_1k.jpg`. Those are assets Codex added in the very
  commits this branch is based on; their `.import` records are tracked but the
  imported binaries did not yet exist here. Two `--import` passes and the suite
  passes clean. **Environmental, not a code failure, and not this increment's**
  — reported so nobody chases it.
- **`WalkTest` (FAST): 239 pass, 2 fail** — `boiler's long parts list stays
  merged (23 meshes)` and `production spine loads the one authored job, the
  chirp hunt`. Both **pre-existing**, attributed by the sharpest test
  available: the same head and the same tree with the placement block in
  `orison_detail_pass.gd` reverted, so the extinguisher is not in the building
  at all, gives **the identical 239 pass and the identical two named
  failures**. The file was restored byte-for-byte afterwards (SHA-256
  `3bc6dbe4929bd699…`). Neither failure is in the F03 stair core: one is a B1
  boiler mesh merge and the other is the job library.

## Ownership, in one line each

- **`WorkOrders` — consulted, deliberately not used.** A work order in Orison is
  a *reported* fault with a unit and a symptom, and an open one counts toward
  `has_open_work()`. Nobody reported this extinguisher; it is found on a round,
  which is periodic duty rather than reported repair. Issuing a job for it would
  invent an entry in the sole job library and make an optional inspection show
  up as open work. The live proof asserts the spine did not move.
- **`MaintenanceActivityLibrary` — consulted, deliberately not used.** Its verbs
  are `turn`, `align`, `hold_release` and its panel drives a stepped sequence.
  Lifting at a cap to find out whether it is loose is not a step in a sequence;
  it is a hand on a thing, which is the `PropControlArea` idiom SR7-G…SR7-N use.
  No activity was added and `maintenance_activities.json` is untouched.
- **`MaintenanceInventory` — rejected on its own header text.** It writes to
  `RealityState.data.maintenance_items`, which is a save fact, and this
  increment adds none.
- **SR7-N's `FireLineCabinetProp`** — read non-mutatively by two tests as a
  control. Never imported, never called, never edited.
- **The batched backboard** — reused exactly as drawn, on one instance, on all
  eight floors untouched.
- **Its own condition** — owned entirely, nine facts, snapshot and restore under
  the same two method names `MaintenanceActivityPanel` uses.

## Limitations

- **One board of eight carries an extinguisher.** The other seven still show the
  batched plate with nothing on it, which is now slightly odd rather than
  neutral. Hanging more is a placement, not a design change.
- **Nothing consumes `extinguisher_inspected`.** No director, no case, no save.
  That is what makes the inspection genuinely optional, and it also means a
  freed cap is forgotten on reload.
- **The repair is idealised.** A cap seized by acid fume would in practice be
  replaced from stores rather than worked free with the fingers; modelling that
  would have meant an inventory item and therefore a save fact, so the apparatus
  treats "work it free" and "fit a proper loose cap" as the same motion and says
  so in its own prompt.
- **No pre-1928 maintenance cadence is asserted**, because none was verified.
  The apparatus is therefore a condition-finder and not a scheduler, and it has
  no opinion about how often anybody should come.
- **The seal is a small subject.** Cutting it scores 0.000892 whole-frame and
  0.00645 on its declared crop — real, and honestly the least dramatic number on
  the sheet. Wire is thin.
- **The stair core is dim**, honestly so. F03's board is the best-lit instance in
  the building and it is still a 1928 stair landing at three in the morning.
