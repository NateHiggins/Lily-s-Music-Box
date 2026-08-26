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

| | |
| --- | --- |
| Base | `19adcda` "PHONE-B: put the ordinary house line in production" |
| Scene | production `orison_root.tscn`, fresh campaign |
| Camera | the player's own — body, eye and carried detector agree with the frame |
| Clock | `DAYNIGHT=0` · lamp off · HUD on |
| Freeze | physics off → aim → lamp off → 1.6 s real → process off → `time_scale = 0` → **8 s real settle** |
| EXACT box | `131x17+447+529` of 1280×720 — the measured difference bounding box |
| UNITS crop | `185x55+420+510` — that box with margin |
| PLATE crop | `330x160+350+465` — the whole board |

**The crops were derived from the measured difference bounding box before
anything was priced**, and the box is **the same at 6 % as at 20 %**: the change
has no low-amplitude spread beyond its own 131 × 17 footprint. The crops are
re-derived on every base, because the framing is not stable across them — the
plate sat at (578, 356) on `35b7e84` and at (447, 529) on this one, from changes
outside this lane. A crop declared on one base and reused on the next silently
prices empty wall, and two figures were caught doing exactly that.

Origin moved **six times** while this task was in flight — `5653d70` →
`f21e1bf` → `4962a4b` → `35b7e84` → `b66fdde` → `94abe8d` → `19adcda`.
The branch was replayed onto each new head, and the whole sheet re-shot and
every figure re-measured, five times over. None of those commits touches this
stair's signage, and none overlaps a file this task edits; two of them
nevertheless changed what the sheet had to prove, as below.

### Three contaminants this sheet found in its own measurements

**1. The HUD keeps its own clock.** The sheet was priced once with a difference
box of **671×288 centred on the objective card, not on the plate**. The arrival
toast was still fading when the world froze — that overlay decays on **real
time**, not on `Engine.time_scale`. A real-time settle with the world stopped
takes the HUD region's residual to **exactly 0**. Priced before that, this sheet
would have measured its own HUD.

That contaminated measurement also produced a **wrong explanation that the fix
retired**: with the toast still decaying, the 6 % box spread to `781x543`, and
the obvious story was that two bright labels were changing the stairwell's
indirect light. They are not. With the settle in place the 6 % box collapses
onto the labels themselves.

**2. A leading control cannot see drift that happens after it.** On `b66fdde`
the before/after pair suddenly measured a `894x663` difference. Holding the
change constant — comparing two *units-on* frames from the same camera — showed
**0.0334 of drift with nothing under test**, so the new household wireless props
were still settling when the old wait expired. The sheet now carries a
**trailing control** shot immediately after the priced frame, so the A/A floor
**brackets** the pair rather than preceding it. All three arrival controls are
now byte-identical to one another.

**3. And the turned-head camera has a floor this sheet does not hide.** Its A/A
pair measures **0.136**, and the difference bounding box is `360x170+22+38` —
the objective card, not the stair. Moving the camera moves the body, and the HUD
answers to where the body is, so the card re-settles after each camera move.
`04_the_way_the_glyph_points` is taken third, after that pair, and sits within
**0.000595** of the control immediately before it. **Nothing is priced on that
camera**; frame 04 is context, and its floor is stated rather than cropped
away.

## The floors, first

| A/A pair | whole frame | UNITS | PLATE | EXACT box |
| --- | ---: | ---: | ---: | ---: |
| **leading** (`00_a` vs `00_b`) | **0** | **0** | **0** | **0** |
| **spanning** (`00_b` vs `02_c`) | **0** | **0** | **0** | **0** |
| **trailing** (`02` vs `02_c`) | **0** | **0** | **0** | **0** |
| corridor (`03_a` vs `03_b`) | 0.136 — the HUD | 0.000330 | 0.000329 | 0.000382 |
| corridor, settled (`03_b` vs `04`) | 0.000595 | — | — | — |

**All three arrival controls are one identical file.** Before the priced pair,
after it, and spanning it, the frozen world did not move a single bit. That is
the strongest statement this sheet can make, and it is the camera every number
below is priced on.

The corridor camera is the exception, and it is reported rather than trimmed:
its floor is the objective card re-settling after the camera move, and it is
**not** a floor under any claim.

## Frames

| File | md5 | What it is |
| --- | --- | --- |
| `00_arrival_control_a.png` | `a4e867d038c6a4ca282a8340b4dede95` | **A/A** at the reading position. |
| `00_arrival_control_b.png` | `a4e867d038c6a4ca282a8340b4dede95` | The same file, bit for bit. |
| `01_arrival_before.png` | `5c40b1811d5cd296ca09db7c13292aa1` | The landing **with the units line hidden** — an order that says 2A, a building that says 2. |
| `02_arrival_after.png` | `a4e867d038c6a4ca282a8340b4dede95` | The same instant, same light, **with the units line**. |
| `02_arrival_control_c.png` | `a4e867d038c6a4ca282a8340b4dede95` | **Trailing A/A**, taken after the priced pair — identical to the leading control. |
| `03_corridor_control_a.png` | `95db500cb94466d69f8710be9ca22005` | **A/A** on the turned-head camera. |
| `03_corridor_control_b.png` | `aed4da14a3a756960405c41dc3075b8b` | The same, untouched. |
| `04_the_way_the_glyph_points.png` | `fc2c1c4829c3599abafe5a3c85275436` | **The cue and its destination in one frame** — plate at frame right, the west corridor open at frame left. |
| `05_the_2a_door.png` | `2a85bcd438df76a13272f609ba7e5590` | **The door reached**, at the west end of the arm the left glyph points down. |
| `06_floor_four_reads_its_own_floor.png` | `897e4f2e29be91d8ca570b1cb5647391` | **Recurrence**: `FLOOR 4` · `← 4A` · `4C 4D →`. |
| `07_a_later_shift.png` | `51cbdcc78da657d3ac4503d2d5fe5170` | An ordinary walk through the landing, nothing staged. |

Eleven frames, **eight distinct**: `00_a`, `00_b`, `02_arrival_after` and
`02_arrival_control_c` are one and the same file. The frozen world is genuinely
still, and **the "after" state is simply the shipped state** — so the controls
and the answer frame are one photograph. Only `01_arrival_before` shows
something a player never sees.

## The claims

| Change | crop | RMSE | its floor |
| --- | --- | ---: | ---: |
| no units line → **units line** | EXACT box | **0.183** | 0 |
| the same | UNITS | **0.0860** | 0 |
| the same, on the whole board | PLATE | 0.0378 | 0 |
| the same, whole frame | — | 0.00904 | 0 |
| the HUD, during that change | HUD region | **0** | 0 |

**The whole-frame figure is small because the change is small.** Two lines of
text on a 1280×720 frame move about 0.24 % of the pixels; the exact-box figure,
**0.183 against a floor of exactly zero**, is what prices the legend. The 6 %
difference box equals the 20 % box, so nothing outside those two labels changed
at all.

## What the frames do not show, stated plainly

1. **Frame 04 cannot show both things square-on, and no camera can.** The plate
   faces due south; the corridor it points down runs due west. This frame is the
   reading position with the head turned 38° left — the plate 31° right of the
   axis, the corridor mouth 37° left, both inside an 88° frustum. **The carried
   detector covers the plate's left label at that angle**, so `2C →` is legible
   in it and `← 2A 2B` is not. Frame 02 is where the legend is read.
2. **The brass 2A number is present in frame 05 but not legible**, a small dim
   plaque on an unlit corridor wall at 1.5 m. That is not a defect in the
   photograph; it is the reason the landing plate has to carry the information
   at all.
3. **The arrival itself is not the reading position.** From b(2.50, −2.26) the
   plate is 2.90 m away at **65° off its own normal** — 0.62 m of board
   foreshortened to 0.26 m — which is why the first pass of this sheet
   photographed a landing with no legible sign in it. The cameras stand where a
   player crossing toward the west corridor actually passes, 1.35 m out and
   square. **The plate is visible from the arrival and read a step later**: the
   live suite asserts the first half of that with a ray, and does not assert the
   second half with an adjective.

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
