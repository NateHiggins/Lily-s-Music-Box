# K2-D — one floor up is not a direction

The fourth transition of the first minute, photographed in production from a
**fresh campaign** at the pose the paper comes off the spindle.

---

## The audit, and it found a lie rather than a gap

From the acceptance pose — **b(4.84, −2.27, 1.62)**, facing the register — the
player knows "Unit 2A, one floor up" and can see nothing that says which way.
Every existing cue, measured:

| Cue | Distance | Yaw | Occlusion | In a 70° frame? |
| --- | ---: | ---: | --- | --- |
| K2-A's spine plate | 5.06 m | −113.8° | blocked | no |
| stair (ramp collider) | 5.59 m | +154.9° | blocked | no |
| floor directories F01/F02 | 12.5 m | +141.3° | blocked by the stair itself | no |
| **`FireDirection_F01`** | **5.19 m** | **+88.5°** | **clear** | **no** — just outside ±35 |
| corridor dome 04 | 3.16 m | −99.8° | clear | no |
| lobby chandelier | 7.84 m | −128.8° | blocked | no |

**And then the real finding.** `FireDirection_F01` is the building's only stair
sign on the floor. Its readable face looks **west**, so a reader stands in the
east corridor facing **east**, and their **left is north**. It read:

> ←  FIRE EXIT — STAIRS

Measured at body height on **all six residential floors**, the east corridor's
west wall is **unbroken from y +4.4 to y −6.8** and opens only at
**y −9.2 … −7.2** — six open samples per floor, **every one south of the plate,
none north of it**.

> **The building's only stair sign pointed away from the only route to the
> stair, on every floor.**

**And there is a second, honest trap.** Sampling the same wall by height shows
it is **solid from z 0.2 to 1.0 and open only from z 1.2 to 2.0** at
y −0.6 … −1.4. That is a **borrowed-light window with a sill at about 1.1 m** —
you can *see* the stair through it from the desk, and you cannot walk there. The
destination is visible in a direction that is not a route.

## The change

Two plates, one owner (`WayfindingSignagePass`), no new object type:

1. **The arrow is corrected.** `FIRE EXIT — STAIRS  →` — a reader facing east
   has south on their right, and south is where the corridor opens.
2. **The plate gets its pair**, on the corridor's **west wall at x 3.56**,
   directly opposite the register, **facing east** so it is read head-on the
   moment a man turns from the desk — **1.29 m away, 176° behind him, zero blind
   walking**. A reader facing west has south on their *left*, so this one
   carries `←  STAIRS / ALL FLOORS`. **Both plates point at the same opening
   from opposite sides of the corridor**, which is what a paired plate is.

One per residential floor, six in all. No new prop type, no state, no script, no
save key, and no change to K2-C's card — the world now answers it.

## Historical source and inference boundary

**Documented.** Directional exit signage in New York is a post-Triangle
convention: the [Triangle Shirtwaist Factory fire of 25 March 1911](https://www.famous-trials.com/trianglefire/971-trianglecodes)
killed 146 workers, and the reform that followed produced new egress standards
and the first ratified Exit-sign codes; the
[Sullivan-Hoey Fire Prevention Law](https://labormovement.blogs.brynmawr.edu/1911/12/11/factory-laws-in-new-york-city/)
followed in October 1911, and the
[Tenement House Act of 1901](https://villagepreservation.org/2016/04/11/tenement-house-act-of-1901/)
had already required fire safeguards in new buildings. The Orison is a 1912
building — put up directly into that reform.

**Not documented, and I say so.** I found **no primary source mandating a
directional stair plate** of this kind in a New York multiple dwelling, and this
increment does not claim one. The historical claim here is deliberately thin
because **the object is not new**: the building already carries eight of these
brass-framed plates. What changed is one glyph that disagreed with the geometry,
and one plate added on the opposite wall of the same corridor.

**Orison-specific inference:** that a corridor with the watchman's desk in the
middle of it carries the direction on both walls.

## Conditions, declared

| | |
| --- | --- |
| Base | `ce0dcc3` "Record derived presentation and legibility contracts" |
| Scene | production `orison_root.tscn`, fresh campaign |
| Camera | the player's own — `player.global_position = from − player.camera.position`, so body, eye and lamp agree |
| Clock | `DAYNIGHT=0` · Lamp off · HUD on |
| PLATE crop | `300x160+490+290` of 1280×720 |
| ARROW crop | `420x90+430+300` |

Crops were taken from the measured difference bounding boxes (296×148+464+301
and 233×44+540+308), not chosen by eye. **One frozen instant**: the shift is
opened and the paper taken thawed, then time stops and every comparison is an
A/B on that instant.

The whole sheet was **re-shot on `ce0dcc3`** after the branch was replayed onto
it, and every figure re-measured. That commit changes one design document and
can move nothing here; re-shooting settles it rather than arguing it. All
figures reproduced within 0.001.

## The floors, first

| A/A pair | whole frame | on its crop |
| --- | ---: | ---: |
| desk camera | **0** | — |
| turned camera | 0.00853 | **0** (PLATE) |
| fire-plate camera | 0.0000135 | **0** (ARROW) |

The desk pair is exactly zero. The other two are not: both look into the stair
well through the borrowed-light window, where something animates. **Every claim
below is priced on a crop whose own floor is exactly zero**, and the
whole-frame figures are given so the reader can see the difference.

## Frames

| File | md5 | What it is |
| --- | --- | --- |
| `00_acceptance_control_a.png` | `f7c77b5b1b7de572fa12df7e5ccb6454` | **A/A** at the acceptance pose. |
| `00_acceptance_control_b.png` | `f7c77b5b1b7de572fa12df7e5ccb6454` | The same, untouched. |
| `01_turned_control_a.png` | `459b3b263424d5edd846ad93a4f79174` | **A/A** after the one turn. |
| `01_turned_control_b.png` | `df4ba18fffa5300b0dfbe9187d5db13b` | The same, untouched. |
| `02_the_turn_before.png` | `601545e76df5faee85a48a1b18df676d` | The turn **with the plate hidden**. |
| `03_the_turn_after.png` | `df4ba18fffa5300b0dfbe9187d5db13b` | The same instant **with the plate**. |
| `04_the_plate_and_the_opening.png` | `9ed25bca1f2cdbfea3e850c222ef0527` | The plate and the opening it points at, together. |
| `05_fire_plate_control_a.png` | `ee6cc2e20177a8e4226ada0cbc99053d` | **A/A** at the fire plate. |
| `05_fire_plate_control_b.png` | `40783fc31b672d532ae15d8f8ae1068d` | The same, untouched. |
| `06_the_arrow_as_it_was.png` | `81df05d9d0f5ed638dbd218ad0d909af` | **The misleading cue**: the arrow pointing north. |
| `07_the_arrow_corrected.png` | `40783fc31b672d532ae15d8f8ae1068d` | The same plate, corrected. |
| `08_a_later_shift.png` | `973d5be7b89f050bfe43e21e71518bb6` | An ordinary walk-through, nothing staged. |

Twelve frames, ten distinct. `03` is the same file as `01_turned_control_b` and
`07` is the same as `05_fire_plate_control_b` — the A/A controls *are* the
"after" frames, because the after state is the shipped state.

## The claims

| Change | crop | RMSE | its floor |
| --- | --- | ---: | ---: |
| no plate → **plate**, from the one turn | PLATE | **0.171** | 0 |
| the same, whole frame | — | 0.0391 | 0.00853 |
| **old arrow → corrected arrow** | ARROW | **0.182** | 0 |

`03_the_turn_after.png` is the frame that carries the increment: the plate
reading `← STAIRS` on the left, **and the stair itself visible through the
borrowed-light window on the right, in a direction you cannot walk.** The sign
exists to resolve exactly that.

`06_the_arrow_as_it_was.png` is the misleading competing cue the audit asked
for, and it was already in the building.

## Discarded passes

1. **Adding a plate on the east wall beside the desk.** The desk *faces* the
   east wall, so anything on it is edge-on — the same reason the existing fire
   plate is unreadable from there. The pair had to go on the opposite wall.
2. **Building the pair in vitreous `_enamel`.** K2-A already paid for this on
   this exact wall: against warm plaster it photographs as a black glossy
   rectangle and reads as a flat screen on a 1912 wall. Painted board, as K2-A
   settled.
3. **Trusting a basis-sign derivation for the arrow.** My first read of the
   plate's facing printed `−basis.z` and described the *back* of the sign,
   which would have had me "correcting" a correct arrow. The direction was
   settled by rendering the plate and looking at it, then re-derived to match.
4. **Assuming the visible stair was reachable.** The opening seen from the desk
   is a window, not a doorway — solid z 0.2–1.0, open 1.2–2.0. Sampling the wall
   only at body height had already told me it was solid; sampling by height told
   me why it looked open.

## What this does not do

- It does not touch K2-C's card, the chirp, the route geometry, any door, or any
  owner's state.
- It does not make the tour key or STATION 2 mandatory.
- **It does not repair the next transition**: once the player is through the
  opening and on the landing, nothing yet says which of the flights goes up to
  2A, and the F01 plate still reads `STREET LEVEL ↓` on a floor that *is* street
  level. Both are reported, not fixed.
