# SR7-P — seven empty boards are a story

**Status: production-rendered proof complete.**

Base **`b0a9df0`** "Keep every neighbour in one atmosphere". SR7-O was
confirmed landed as `3889f0a` — verified content-identical to the commit it
replays, for every source path — before this branch existed; `origin/main` then
moved twice more in Codex's celestial and atmosphere lanes, and the branch was
replayed onto each new head. **The whole sheet, including its bare-board
baseline, was re-shot on this base**, because the atmosphere commit moves this
interior by up to 0.0012 and the floors below are exact zeros.

Captured 2026-08-26 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`. **Every one of the eight boards
is photographed from the same standing place on its own floor's landing, with
the same lens**, so the only thing that can differ between two frames is what is
actually on the wall. No proof-only light, mesh, material, camera rig or
production owner.

## The problem, photographed before it was fixed

SR7-O hung one working soda-acid extinguisher on F03's backboard and left the
other seven boards bare. `before_f01_bare_board.png`, `before_f02_bare_board.png`
and `before_f06_bare_board.png` are what those looked like: a flat painted
rectangle with nothing on it, which reads as unfinished level dressing rather
than as a building.

## What is on each board now

| Floor | Condition | Why this one |
| --- | --- | --- |
| B1 | **STRIPPED** | Its board is in a corner of the cellar stair that **nothing lights** — the first sheet photographed it black — so it is the wrong place to put a story. The cellar's real fire protection is elsewhere in the building. |
| F01 | **HUNG** | The lobby floor is what anybody important walks through, so this one still has its vessel. |
| F02 | **EMPTY BRACKET** | Bracket bolted up, vessel gone out of it, a service card left on the strap. |
| F03 | *working* | SR7-O's apparatus. **Nothing passive is drawn here** — the builder returns before it draws. |
| F04 | **EMPTY BRACKET** | The same, one floor up. |
| F05 | **HUNG** | One upper floor simply still has its own. |
| F06 | **STRIPPED** | Bracket and vessel both gone: four bolt heads and the paint the straps kept clean. |
| ROOF | **STRIPPED** | And for a reason none of the others has. See below. |

**THE DISTRIBUTION IS DELIBERATELY NOT A RULE.** Two floors kept theirs, two
were emptied, three have nothing left, one is inspected. A rule — one condition
per floor, or an even split — is exactly what would make seven boards read as
procedural repetition again, which is the thing this increment exists to fix.
The focused suite asserts the split is uneven.

**AND NONE OF THE SEVEN CARRIES A TAG.** SR7-O's board has an inspection tag and
an enamel charge plate on it; these have neither, because nobody has inspected
them. A hung vessel with no tag is the weakest claim in the building — which is
what keeps an intact silhouette from reading as readiness, and the focused suite
scans the code for `Label3D`, `_letter`, `TAG`, `INSPECT`, `CHARGE`, `seal` and
`certif` to keep it that way.

## The vocabulary is shape, and that was a measurement

The first sheet photographed all eight boards from the same standing place, and
the light across them runs from **near-black in the B1 stair core to open
daylight on the roof bulkhead**. A dust shadow a few per cent lighter than the
board would have been invisible on half the floors. So every condition here is
something with an edge that catches light and throws a shadow:

* **HUNG** — a copper vessel on two iron straps and a foot rest. Deliberately
  plainer than SR7-O's: no cage, no cap knurl, no hose, no charge plate, no tag.
  A copper pot on two straps.
* **EMPTY BRACKET** — the same straps and foot, with nothing in them, the paint
  the vessel kept clean showing through, and a pasteboard service card on a wire
  hanging from the upper strap.
* **STRIPPED** — bracket and vessel both gone. What is left is the paint the
  **straps** kept clean, drawn in the bracket's own shape — two bands and a foot
  rather than one anonymous rectangle — and the four bolts nobody drew out.

Two colour corrections were forced by measurement rather than taste: the batch's
shared trim material **lifts** vertex colour so hard that 0.255 grey rendered as
bone and the straps read as wood, and its metal material **darkens** so hard
that 0.60 copper rendered as a black mass. Both were measured back to where they
read as painted iron and as metal.

## Historical grounding

**DOCUMENTED, PRE-1928** — carried over from SR7-O and unchanged here: the
soda-acid vessel is a straight-sided copper cylinder whose charge is two and a
half gallons of aqueous bicarbonate solution with a small acid bottle in a cage
under the cap (J. M. Miller, US 883,326, filed 30 Apr 1906, patented 31 Mar
1908; H. M. McCaslin for American La France, US 1,182,186, filed 25 Feb 1916,
patented 9 May 1916). That the charge is **water** is the only period fact this
increment needs beyond SR7-O's.

**ORISON INFERENCE** — that a superintendent with more boards than vessels robs
the ones nobody looks at; that the boards on the two floors anybody important
uses keep theirs; and, for the roof, that **a vessel holding two and a half
gallons of water does not spend a New York winter on the outside of a stair
bulkhead on an open deck**. The water is documented; how this building responded
to it is inference, and is labelled as such.

**AUTHORED** — which specific board is bare, which carries a bracket, which
carries a vessel; the service card; the bolt heads; the shape of the paint the
straps kept clean.

**EXPLICITLY NOT CLAIMED.** No statutory count, no placement rule, no inspection
interval, and nothing projected backward from a modern standard. This increment
asserts only what is on a wall.

## What it costs

Every one of the seven conditions is drawn as entries in **the same per-floor
MultiMesh batch that already draws the board, the standpipe and the pipe
brackets**. Measured in production: **28 batches, 686 instances, 20 materials**
across the whole building — 24.5 instances per batch, which is what batching is.

* **no new node** — proved on the real tree: sweeping every `Node3D` in the
  building for anything standing within 0.45 m of a board finds **exactly one**,
  and it is `F03_EXTINGUISHER_STAIR`. The seven passive boards own nothing.
* **no Area3D, collision, light, physics, `_process` or persistence** — true by
  construction, because the builder cannot create a node at all: the focused
  suite reads its code with comments stripped and asserts it contains no
  `Node3D`, `MeshInstance3D`, `Area3D`, `CollisionShape`, `StaticBody`,
  `RigidBody`, `Light3D`, `.new(`, `add_child`, `set_process`, `_process`,
  `RayCast` or `PhysicsServer`.
* **no new material and no unique material per instance** — everything goes
  through `_box` and `_cylinder`, which append to batches that carry per-instance
  vertex colour on one shared material each.
* **the backboards themselves are untouched.** Not one number in the batched
  board changed.

## Clearance, measured on the real building at all eight boards

| Quantity | Value |
| --- | ---: |
| board centre / front face | x −2.76 / y −3.06 |
| deepest passive projection (the bracket's front strap) | 0.27 m |
| leaves, of the landing's 1.70 m depth | **1.35 m** |
| clear of the stair doorway's west jamb | **0.99 m** |
| inside the landing's west edge | 0.23 m |

Identical at every floor, because the board is identical at every floor. The
live suite asserts all three at all eight.

## Definitive frames

All 1280×720. SHA-256 truncated to 32 hexadecimal characters.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_b1_control_a.png` | `fdef5d7dc2ffcd9d150dc15fa0001f23` | B1's board, and the sheet's A/A control at the start of its run. |
| `00_b1_control_b.png` | `fdef5d7dc2ffcd9d150dc15fa0001f23` | **Byte-identical.** |
| `01_board_b1.png` | `fdef5d7dc2ffcd9d150dc15fa0001f23` | **STRIPPED** — and the same file as the control, because the control *is* this board. An unlit cellar corner, honestly reported as unlit. |
| `02_board_f01.png` | `363d330e5ba2b41976c4b62e4131ea73` | **HUNG** — copper vessel on two iron straps, no tag. |
| `03_board_f02.png` | `ec206c5ee9224101034dec7fff755825` | **EMPTY BRACKET** — straps and foot, nothing in them, a card on the strap. |
| `04_board_f03.png` | `9f85225a312ef2e8fc11e89835b54c5f` | **THE CONTROL**: SR7-O's working apparatus, photographed and never operated. Visibly richer than the passive vessel. |
| `04_f04_control_a.png` | `4d19def0c07c71e66d9966b1ae33c0b2` | F04's board, and the A/A control at the far end of the run. |
| `04_f04_control_b.png` | `4d19def0c07c71e66d9966b1ae33c0b2` | **Byte-identical.** |
| `05_board_f04.png` | `4d19def0c07c71e66d9966b1ae33c0b2` | **EMPTY BRACKET** — same file as its own control. |
| `06_board_f05.png` | `d95cd32c2ba3479cabb17ebf7918f275` | **HUNG** — the second vessel, on a different floor. |
| `07_board_f06.png` | `6d3de8aa84cc392279cd01616347edbf` | **STRIPPED** — two clean bands, a foot band, four bolt heads. |
| `08_board_roof.png` | `660100d76b4ac06d40469d468557d2b3` | **STRIPPED**, in daylight on the bulkhead's plaster. The clearest stripped frame on the sheet. |
| `09_context_f03_working.png` | `5eee77b8af3c32e3758dcfd0710a5306` | The working board in its stair core, from along the landing. |
| `10_context_f04.png` | `9212e5fcd67fdc2b5e49dfdc8d00175c` | An emptied board in the same view, for the sightline. |
| `before_f01_bare_board.png` | `46fbee9dc1e099e2243fdecbf51eaf3f` | F01 **before**: a flat painted rectangle. |
| `before_f02_bare_board.png` | `b1297489e5c641c8ca9f9f66cde958b2` | F02 **before**. |
| `before_f06_bare_board.png` | `443a0e7eeed2a7b3ff542032e9cc78c5` | F06 **before**. |

Seventeen frames, thirteen distinct files. Both collisions are A/A pairs that
double as their own board frame — the controls are not separately staged. The
three "before" frames were shot on **this same base** with the placement call
reverted, so every number below compares like with like.

## Pricing

Normalized RMSE, ImageMagick 7.1.2. Declared board crop **`300x580+490+50`**,
which is the board plus the margin a bracket and a vessel cap project into.

### A/A floors — exactly zero, by matching SHA-256

| Control | Whole frame | Board crop |
| --- | ---: | ---: |
| B1 A → B | **0.000000** | **0.000000** |
| F04 A → B | **0.000000** | **0.000000** |

The scene is fully deterministic, so every number below is measured against a
true zero rather than a noise floor.

### Bare board → its authored condition, on the declared crop

Each board against **its own** bare baseline: same camera, same floor, same
light, only the condition differs.

| Board | Condition | RMSE |
| --- | --- | ---: |
| F05 | HUNG | **0.0320** |
| F01 | HUNG | **0.0241** |
| F02 | EMPTY BRACKET | **0.0154** |
| F04 | EMPTY BRACKET | **0.0137** |
| ROOF | STRIPPED | **0.00889** |
| B1 | STRIPPED | 0.00814 |
| F06 | STRIPPED | 0.00543 |

Every board moved. The ordering is the vocabulary's own: a vessel changes a wall
more than a bracket, and a bracket more than the paint it used to cover.

### Not seven clones — and this needed the right instrument

A whole-frame RMSE between two *different floors* measures the floor, not the
condition: B1 is nearly black and the roof is in daylight, so F06-vs-ROOF scores
0.0742 for two boards in the **same** condition. That comparison is worthless
and is not used.

The instrument that works is the **condition delta**: for each board, subtract
its own bare baseline first, which cancels that floor's light and wall, then
compare deltas. Same condition should be close; different conditions should not.

| Pair | Condition | RMSE of deltas |
| --- | --- | ---: |
| F06 ↔ ROOF | same (stripped) | 0.0467 |
| F02 ↔ F04 | same (bracket) | 0.0653 |
| F01 ↔ F05 | same (hung) | 0.1318 |
| F05 ↔ F04 | **different** | 0.1533 |
| F01 ↔ F06 | **different** | 0.1897 |
| F01 ↔ F02 | **different** | 0.1993 |
| F02 ↔ F06 | **different** | 0.2113 |
| F05 ↔ ROOF | **different** | 0.2220 |

**Every same-condition pair (0.0467–0.1318) is smaller than every
different-condition pair (0.1533–0.2220), and the two bands do not overlap.**
The seven boards are three conditions, not seven copies and not seven one-offs.

**B1 IS EXCLUDED FROM THIS TABLE, AND HERE IS WHY.** Its bare-to-condition
change is 0.00814 — the faintest on the sheet, because nothing lights that
wall — so normalising its delta amplifies mostly noise, and B1 ↔ F06 scores
0.1674 for two boards in the *same* condition, which would straddle the bands.
That is a measurement failing on an unreadable subject, not two conditions
failing to differ, and dropping it silently would have been the dishonest move.
B1's board is declared unreadable in this sheet and is not used to prove
anything about legibility.

## Sheets that were discarded, and what discarded them

0. **A sheet shot on the previous base.** Codex's "Keep every neighbour in one
   atmosphere" moves this interior by up to 0.0012, against A/A floors that are
   exact zeros. The whole sheet **and its bare-board baseline** were re-shot on
   the new head rather than carried across.
1. **A sheet with the story on B1.** The first pass hung a vessel on the cellar
   board because the cellar is where fires start. The frame came back **black**:
   nothing lights that wall. The condition was moved off B1 and B1 was given the
   least visually demanding one, and the sheet now says plainly that B1's board
   is not legible rather than pretending it is.
2. **A sheet where the bracket read as wood.** Iron at 0.255 grey rendered
   bone-coloured through the shared trim material — brighter than the copper it
   was holding. Measured down to 0.088.
3. **A sheet where the hung vessel was a black mass.** Copper at 0.60 rendered
   darker than the board behind it through the shared metal material. Measured
   up to 0.88.
4. **A stripped board that was one anonymous rectangle** of cleaner paint plus
   four specks — exactly the tiny-detail-only storytelling the brief warns
   against. Replaced with the bracket's own shape: two bands and a foot.
5. **A wide context camera moved in too close**, which put the pier between the
   lens and the board. Returned to a framing with a clear sightline.
6. **A thirteen-frame single run** that hit the runner's sixty-second ceiling
   after five frames. The sheet is now shot in two halves, each carrying its own
   A/A control pair.

## Honest weaknesses

* **B1's board is not legible and this sheet does not claim it is.** Nothing in
  the cellar stair lights that wall with the player's lamp off. Its frame is
  shipped as it is.
* **The context frames are for sightline, not for legibility.** At that distance
  the board is roughly 40×70 px; the head-on frames carry the legibility claim.
* **The two `HUNG` vessels are the same object twice.** They differ only by
  floor and light. That is deliberate — two floors that kept theirs should look
  like two floors that kept theirs — but it is the least varied thing here.
* **Seventeen frames include two three-way duplicates**, because each A/A
  control pair is also that board's own frame.

## Executable proof

Every run through `tools/run_godot_serial.ps1`, one instance, 60-second ceiling,
output redirected and only filtered results read. **Zero parse errors, zero
script errors, no timeouts.**

- **`ExtinguisherBoardsTest.tscn`: PASS 91/91**, exit 0.
  - The table names eight boards, one per authored floor, and every condition is
    one this file can draw.
  - **Exactly one board is `working`, and it is F03**; the builder returns before
    drawing on it, so a passive vessel can never appear behind SR7-O's apparatus.
  - Three passive conditions, each used, unevenly distributed, covering all seven
    non-working boards.
  - The builder creates no node of any kind and reaches no owner, lifecycle,
    signal, snapshot or persistence — scanned on its code with comments stripped,
    so the claim is about the code and not about the prose describing it.
  - **No passive condition carries a tag**, a plate, a seal or any lettering.
  - SR7-O references nothing of SR7-P's, and exactly one extinguisher script
    exists in `scripts/props`.
- **`WalkTest` (FAST): 239 pass, 2 fail** — `boiler's long parts list stays
  merged (23 meshes)` and `production spine loads the one authored job, the
  chirp hunt`. Both **pre-existing**, attributed by the sharpest test available:
  the same head and the same tree with the placement call and builder reverted,
  so no passive condition is drawn at all, gives **the identical 239 pass and
  the identical two named failures**. The file was restored byte-for-byte
  afterwards (SHA-256 `763660bc02a8bd94…`). Neither failure is in a stair core.
- **Controls, all green with the seven conditions in the building:** SR7-O
  `ExtinguisherTest` 209/209 and `ExtinguisherLiveTest` 72/72; SR7-N
  `FireLineTest` 163/163 and `FireLineLiveTest` 66/66; `WatchPairTest` 118/118,
  `WatchPairLiveTest` 42/42, `NightRegisterLiveTest` 64/64; Codex's
  `FirstShiftRitualTest`, `FirstShiftOpeningLiveTest`, `CoreLoopTest`,
  `CelestialEphemerisTest` and `PeriodRealityLayerTest` all PASS with 0
  failures.
- **`InteractionInventory`: functional 282/37, nonfunctional 763/25 —
  UNCHANGED from SR7-O.** Seven passive conditions were added to the building
  and the interaction inventory did not move by one instance or one family,
  which is the cleanest single number for "these own no interaction".
- **`WeatherSkyTest`: PASS (0 failures)** — but only after a `--import` pass.
  Its first run here failed one check with "No loader found for resource" against
  `eso_gigagalaxy_galactic_half_dome_4k.jpg`, an asset added by `1a57ab7`, the
  very commit this branch is based on: its `.import` record is tracked but the
  imported binary did not yet exist in this worktree. **Environmental, in
  Codex's lane, not this increment's** — reported so nobody chases it.
- **`ExtinguisherBoardsLiveTest.tscn`: PASS 56/56**, exit 0. On the real Orison:
  **exactly one** node in the building carries SR7-O's script and it is
  `F03_EXTINGUISHER_STAIR`; it is found sealed, charged, not liftable, not
  usable, untouched, having published nothing, and is **byte-for-byte what it
  was** at the end of the run. Sweeping every `Node3D` for anything standing at a
  board finds that one apparatus and nothing else — **each of the seven passive
  boards owns no node at all**. 28 batches carry 686 instances on 20 materials.
  All eight boards keep 1.35 m of landing, 0.99 m of doorway clearance and 0.23 m
  inside the west edge. SR7-N's fire-line cabinet is in the state SR7-N left it
  with its line not made up and nothing published; the job spine carries only the
  one authored job it already had; SR7-P wrote no save key; 248 lamps are
  powered; the watch line recorded nothing; the tour key is on its hook.
