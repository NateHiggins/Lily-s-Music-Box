# K2-F — the floor number is not the apartment

The sixth transition of the first minute, photographed in production from a
**fresh campaign**, at the point where the player steps off the stair onto F02
holding an order that says *unit 2A* and stands in a building that, until this
change, told them only *floor 2*.

---

## The audit, measured by climbing rather than by reading the mesh

A body driven with `move_and_slide` under production collision, up K2-E's
flight, arrives on F02 at **b(2.50, −2.26), z 3.20**. From that arrival, a ray
from the player's own eye:

| What the order needs | Distance | Visible? |
| --- | ---: | --- |
| `F02_DOOR_02` — the 2A door | 7.95 m | **blocked** |
| `BrassApartmentNumber_2A` | 7.92 m | **blocked** |
| `FloorDirectory_F02` | — | **blocked** |
| `FireDirection_F02` | — | **blocked** |
| `StairDirectionPair_F02` (K2-D) | — | **blocked** |
| `LandingPlate_F02` (K2-E) | 2.90 m | **clear**, yaw −96.2° |

**Exactly one cue is legible from the arrival, and it named the floor and
nothing else.** The order says 2A; the building said 2. A floor number is not an
apartment.

### Does it recur?

Yes, on every residential floor, and the recurrence is not uniform:

| Floor | West of the stair | East of the stair |
| --- | --- | --- |
| 1 | 1A | 1D |
| 2 | 2A 2B | 2C |
| 3 | 3A 3B | 3D |
| 4 | **4A** | **4C 4D** |
| 5 | 5A 5B | 5C |
| 6 | 6A 6B | 6C |

**Every unit door in the building stands at x ±5.33.** The split is real
architecture — two arms off one core — which is why one shared rule is both
cheaper and more truthful than six hand-authored legends. Floor 4 is the proof
that the rule is read rather than asserted: it is the odd floor, and the sign
says so.

## The change

**One line added to K2-E's landing plate, in K2-E's voice, on K2-E's board.** No
new sign family, no new prop, no new owner.

```
                     FLOOR 2
          ←  2A  2B          2C  →
              ↑ 3 — 6     ↓ STREET
```

**The sides are derived, not declared.** `_build_apartment_numbers` already
walks the production doors and records `{DoorProp: unit}` in `_numbered_doors`;
the units line reads that dictionary and sorts each unit by the sign of
`door.global_position.x`. The legend therefore **cannot drift from the
building** — move a door and the plate moves with it. Nothing about the A/B/C/D
convention is hard-coded.

**Handedness, settled by measurement rather than by intuition.** The plate faces
due south (`rotation.y = 0`), so its reader faces north; the reader's left is
building −x, which is west. K2-D lost an entire pass to a left/right arrow whose
meaning inverted depending on where the reader stood, so this one is asserted
against the doors themselves in the live suite, not against a comment.

## Historical source and inference boundary

**This is an extension of an already established Orison sign family, and I am
stating that boundary rather than dressing it up as a statute.** The building
already carries 17 brass unit numbers, 7 floor directories, 8 fire-direction
plates, K2-D's 6 corridor pairs and K2-E's 6 landing plates. This adds one line
of text to a board that already exists, in the same brass-and-painted-enamel
idiom, on a wall the building already owns.

**No new historical claim is made and none is needed. I found no primary source
mandating a directional apartment index on a stair landing, and this increment
does not invent one.** The surrounding context is the one K2-D documented and
K2-E carried forward: directional signage in New York multiple dwellings is a
post-Triangle convention (the fire of 25 March 1911; the Sullivan-Hoey Fire
Prevention Law of October 1911; the Tenement House Act of 1901), and the Orison
is a 1912 building. That justifies the *idiom*, not this particular plate.

## Conditions, declared

Captured through the canonical wrapper of
`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`, and migrated onto `ShotHarness`
because this suite was being changed anyway.

```powershell
pwsh -NoProfile -File tools/run_godot_capture.ps1 `
  -Scene res://tests/UnitDirectionShot.tscn `
  -ProjectPath <worktree>/game `
  -ShotRoot <worktree>/art/renders/first_minute_k2f `
  -RunName production_02 -ExpectedFrames 11 -TimeoutSeconds 60 `
  -Resolution 1280x720
```

| | |
| --- | --- |
| Base | `19adcda` "PHONE-B: put the ordinary house line in production" |
| Run | `production_02/` — receipts, metrics, manifest and contact sheet beside the frames |
| Scene | production `orison_root.tscn`, fresh campaign |
| Camera class | **playable** — the player's own body, eye, carried service set and streaming origin all agree with every frame |
| Clock | `DAYNIGHT=0` · lamp off · **HUD hidden by name** |
| Resolution | 1280×720 |
| EXACT box | `[578, 356, 117, 9]` — the measured difference bounding box |
| UNITS crop | `[555, 340, 160, 40]` — that box with margin |
| PLATE crop | `[470, 290, 320, 150]` — the whole board, and the protocol-conformant claim crop |

**Every figure below is linear-RGB RMSE from `tools/measure_shot_sheet.py`.**
Earlier revisions of this file quoted sRGB-space numbers from ImageMagick; they
are not comparable, and have been replaced rather than set beside these.

**The crops were derived from this run's own difference bounding box before
anything was priced**, and the box is **identical at 6 % and at 20 %**: the
change has no low-amplitude spread beyond its own 117 × 9 footprint.

PLATE is the crop the protocol's framing guideline asks for — 320 × 150, larger
than the 160 × 120 floor, and the whole subject. UNITS and EXACT are tighter
diagnostic crops, and the declared exception is simple: **the glyphs that change
are 9 pixels tall.** Any crop big enough to satisfy the guideline necessarily
dilutes them, so all three are reported and the reader can watch the dilution
happen.

Origin moved **six times** while this task was in flight — `5653d70` →
`f21e1bf` → `4962a4b` → `35b7e84` → `b66fdde` → `94abe8d` → `19adcda`. The
branch was replayed onto each new head and the sheet re-shot on each. None of
those commits touches this stair's signage, and none overlaps a file this task
edits.

## What the capture receipt actually revealed

| Stage | Elapsed | Protocol target |
| --- | ---: | --- |
| `production_ready` | **32.519 s** | ≤ 18 s, hard warning at 24 s |
| `owners_resolved` | 32.522 s | ≤ 4 s — 0.003 s here |
| `lamp_and_camera_settled` | 36.950 s | ≤ 6 s warm-up — 4.4 s here |
| `overlays_hidden` | 36.972 s | — |
| eleven captures | 36.972 → 42.692 s | 0.35 s each budgeted, 0.52 s actual |
| `finish` | 42.692 s, **11.3 s of scene margin** | ≤ 54 s |

**Boot is the cost, and it is 8.5 seconds past the protocol's hard warning.**
That is a repository-wide property of `orison_root.tscn` rather than something
this sheet can trim, and it is why the old blind eight-second HUD wait was
dangerous rather than merely wasteful: at 32.5 s of boot, eight idle seconds put
the run at roughly 50.7 s against a 60 s ceiling. An earlier attempt at a
sixteen-second settle **did** blow the ceiling, and wrote five of eleven frames.

## Three contaminants this sheet found in its own measurements

**1. The HUD keeps its own clock, and elapsed time is not a fix.** This sheet
was once priced with a difference box of **671×288 centred on the objective
card, not on the plate**: the arrival toast was still fading when the world
froze, because that overlay decays on real time rather than on
`Engine.time_scale`. The blind wait that hid the symptom is gone. Two owners are
now switched off **by name** — `ObjectiveTracker` and the player's
`TelegramHud` — and every other `CanvasLayer` outside the player is swept as a
backstop (twelve layers, including `FourthWall`, `TouchControls` and
`ServiceRoundDialogue`). Literal waits fall from **14.7 s to 3.4 s**.

That contaminated measurement also produced a **wrong explanation that the fix
retired**: with the toast still decaying, the 6 % box spread to `781x543`, and
the obvious story was that two bright labels were changing the stairwell's
indirect light. They are not. The halo was the toast's tail.

**2. A leading control cannot see drift that starts after it.** On `b66fdde`
the before/after pair suddenly measured a `894x663` difference. Holding the
change constant — comparing two *units-on* frames from the same camera — showed
**0.0334 of drift with nothing under test**. The sheet now carries a **trailing
control** taken immediately after the priced frame, so the floor **brackets**
the pair rather than merely preceding it.

**3. A sweep that flatters the frame is worse than no sweep.** The first version
of the overlay hide swept *every* `CanvasLayer` in the tree. The carried service
set is composited through a `CanvasLayer` of its own — `service_set_carrier.gd`
renders it into a `SubViewport` and shows it on a layer — so that sweep **took
the device out of the player's hands in all eleven frames**. It made frame 04
look better, because the detector stopped occluding the plate's left label,
which is exactly how it was caught. This is a playable camera; an evidence sheet
does not get to quietly put the lamp down. The sweep now stops at the player,
and that run was discarded and retaken.

## The floors, first

Every claim is priced against a control **on the same camera at the same crop**.
No floor is shared across stations.

| Control | crop | linear RMSE |
| --- | --- | ---: |
| arrival, leading (`00_a` vs `00_b`) | PLATE | 0.0000190 |
| arrival, leading | UNITS | 0.0000022 |
| arrival, leading | EXACT | **0.0000000** |
| arrival, spanning (`00_b` vs `02_c`) | PLATE | **0.0000000** |
| arrival, trailing (`02` vs `02_c`) | PLATE | 0.0000034 |
| corridor station (`03_a` vs `03_b`) | whole frame | 0.0007028 |

These are **real repeated renders**, not one image written twice: every frame in
this run is a distinct file. The corridor floor is 0.0007 — down from **0.136**
before the HUD was hidden by name, which is the clearest single measure of what
that change bought.

**Frames 05, 06 and 07 have no local control and therefore appear in no pair.**
They are production-placement context. They do not borrow the arrival or the
corridor floor, and no RMSE is reported against them anywhere in this sheet.

## The claims

| Change | crop | linear RMSE | floor | ratio | declared minimum |
| --- | --- | ---: | ---: | ---: | ---: |
| no units line → **units line** | PLATE | **0.0287** | 0.0000190 | **1513×** | 0.005 / 3× |
| the same | UNITS | **0.0787** | 0.0000022 | **35931×** | 0.010 / 3× |
| the same | EXACT box | **0.1940** | 0.0000000 | — | 0.010 / 3× |

`measure_shot_sheet.py` reports **PASS, 11 frames, 9 pairs, 0 failures**.

**One caveat on the ratio column, stated because the tool cannot state it.** A
floor of exactly zero makes the `min_floor_ratio` gate vacuous — `value < 0 × 3`
is never true — so on the EXACT crop the real gate is the absolute minimum,
0.010, which the measured 0.194 clears by 19×. The PLATE row is the one where
both gates bite: it clears the absolute minimum by 5.7× and its own floor by
1513×.

**No luma warnings.** Black fraction peaks at 0.018 against a 0.65 inspection
threshold, and clipped fraction is 0.000000 in all eleven frames.

## Frames

All eleven inspected at full size. `production_02/contact_sheet.png` tiles them.

| File | What it is | Role |
| --- | --- | --- |
| `00_arrival_control_a.png` | the reading position | **A/A** |
| `00_arrival_control_b.png` | the same, unchanged | **A/A** |
| `01_arrival_before.png` | units line hidden — an order that says 2A, a building that says 2 | **A/B** |
| `02_arrival_after.png` | the same instant, same light, with the units line | **A/B** |
| `02_arrival_control_c.png` | after the priced pair, so the floor brackets it | **A/A** |
| `03_corridor_control_a.png` | the turned-head station | **A/A** |
| `03_corridor_control_b.png` | the same, unchanged | **A/A** |
| `04_the_way_the_glyph_points.png` | plate at frame right, west corridor at frame left | **context** |
| `05_the_2a_door.png` | the door reached, at the west end of the arm | **context** |
| `06_floor_four_reads_its_own_floor.png` | `FLOOR 4` · `← 4A` · `4C 4D →` | **context** |
| `07_a_later_shift.png` | an ordinary walk through the landing | **context** |

Per-frame SHA-256, byte size and luma percentiles are in
`production_02/shot_metrics.json`; the process receipt is in
`production_02/capture_receipt.json` and the scene receipt in
`production_02/scene_capture_receipt.json`.

## What the frames do not show, stated plainly

1. **Frame 04 is context, not a claim.** Its station carries no state change, so
   it is named context rather than dressed as an A/B pair. It also cannot show
   both subjects square-on, and no camera can: the plate faces due south and the
   corridor it points down runs due west. This is the reading position with the
   head turned 38° left — plate 31° right of the axis, corridor mouth 37° left,
   both inside an 88° frustum. **The carried service set occludes the plate's
   left label at that angle**, so `2C →` is legible in it and `← 2A 2B` is not.
   Frame 02 is where the legend is read.
2. **The work-order card is absent from every frame, by choice.** That the order
   names unit 2A is asserted in `UnitDirectionLiveTest` as a string comparison,
   which is a better place for it than a photograph.
3. **The brass 2A number is present in frame 05 but not legible**, a small dim
   plaque on an unlit corridor wall at 1.5 m. That is not a defect in the
   photograph; it is the reason the landing plate has to carry the information
   at all.
4. **The arrival is not the reading position.** From b(2.50, −2.26) the plate is
   2.90 m away at **65° off its own normal** — 0.62 m of board foreshortened to
   0.26 m. The cameras stand where a player crossing toward the west corridor
   actually passes, 1.35 m out and square. **The plate is visible from the
   arrival and read a step later**: the live suite asserts the first half with a
   ray, and does not assert the second half with an adjective.

## What this does not do

- It adds **no light, no collision, no interaction area, no audio, no script, no
  case step, no work order and no save key**. The focused suite asserts each of
  those on the built plate, and scans the builder's source for
  `RealityState`, `commit(`, `WorkOrders`, `RealityCases`, `first_shift`,
  `ritual`, `job_stage`, `leaf_state`, `OmniLight`, `randf`, `randi`, `tween`
  and `set_meta`.
- It does not touch stair geometry, collision, lighting, or any lifecycle,
  objective, custody or access owner.
- It does not open the 2A door, mark Station 2, or make the tour key less
  optional — the live suite re-asserts all three after the walk.
- **It does not repair the balustrade**, which the owner has flagged and which
  belongs to `art/data/gen_layout.py`, outside this lane.
