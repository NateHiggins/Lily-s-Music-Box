# K2-E — the landing must say which way is up

The fifth transition of the first minute, photographed in production from a
**fresh campaign** at the point where the stair forces a choice.

---

## The audit, measured by walking rather than by reading the mesh

A body driven with `move_and_slide` under production collision, from the F01
landing at **b(0.00, −2.60)**:

| Walk | Result |
| --- | --- |
| straight north | **blocked at y −1.88** by the well guard |
| west, then north | 0.15 → **1.60** — the half-landing |
| across, then east arm south | 1.60 → **2.90**, toward F02's floor at 3.20 |

**The climb is: west arm north, turn, east arm south.** Straight ahead is a
guard, and the arriving player must choose a side with nothing to go on.

Sampling the guard by height gives **solid z 0.4–1.0, open above 1.2** — a dwarf
wall with an open balustrade over it. That solid band is what the plate is
screwed to.

**What was visible from the choice point before this change:** K2-A's spine
plate, K2-D's corridor pair and both floor directories are all **blocked**. The
only clear things are the chandelier and a hall dome. Nothing named a floor.

**Does it recur upstairs?** Yes — the same core, guard and choice exist on
F02–F06, which is why the plate is built on all six.

## The change

**One landing plate per residential floor**, on the south face of the guard the
arriving player walks into, at **b(−0.35, −1.95, floor + 0.95)** — 0.72 m from
the choice point, inside a 70° frustum, read without turning.

| Floor | Legend |
| --- | --- |
| 1 | `FLOOR 1 — STREET` · `↑  2 — 6` |
| 2 | `FLOOR 2` · `↑  3 — 6` · `↓  STREET` |
| 3–5 | `FLOOR n` · `↑  n+1 — 6` · `↓  n−1 — STREET` |
| 6 | `FLOOR 6` · `TOP FLOOR` · `↓  5 — STREET` |

**And K2-D's reported F01 lie is corrected**: the fire plate read
`STREET LEVEL ↓` on the floor that *is* street level. It now reads
`STREET LEVEL — THIS FLOOR` on F01 and is untouched on F02–F06, where it is true.

**The glyphs are ↑ and ↓, which have no handedness.** K2-D lost a pass to a
left/right arrow whose meaning depended on which way the reader stood; a
vertical arrow cannot be inverted by standing somewhere else.

## Historical source and inference boundary

**This is an Orison-specific inference from an already established sign family,
and I am stating that boundary rather than dressing it up.** The building
already carries 17 brass unit numbers, 7 floor directories, 8 fire-direction
plates and K2-D's 6 corridor pairs. This is the same brass-framed painted board,
in the same voice, on a wall the building already owns. **No new historical
claim is made and none is needed.**

The surrounding context is the one K2-D documented — directional exit signage in
New York is a post-Triangle convention (the fire of 25 March 1911; the
Sullivan-Hoey Fire Prevention Law of October 1911; the Tenement House Act of
1901 already requiring fire safeguards), and the Orison is a 1912 building.
**I found no primary source mandating a floor-number plate on a stair landing**,
and this increment does not claim one.

## Conditions, declared

| | |
| --- | --- |
| Base | `f45e368` "Author the Orison household radio census" |
| Scene | production `orison_root.tscn`, fresh campaign |
| Camera | the player's own — body, eye and carried lamp agree with the frame |
| Clock | `DAYNIGHT=0` · Lamp off · HUD on |
| PLATE crop | `260x130+510+295` of 1280×720 |
| STREET crop | `430x60+430+380` |

The whole sheet was **re-shot on `f45e368`** after the branch was replayed onto
it, and every figure re-measured. The two commits since the required base touch
TASKS.md, one design document and a new `domestic_radios.json` — none of which
is in this stair's render path — but re-shooting settles it rather than arguing
it. All figures reproduced within 0.001.

## The floors, first

| A/A pair | whole frame | on its crop |
| --- | ---: | ---: |
| choice point | 0.0000481 | **0** (PLATE) |
| plate-and-arm | 0.000125 | — |
| fire plate | 0.0000155 | **0** (STREET) |

**No A/A pair has a single pixel differing above a 6% threshold** — the
whole-frame figures are sub-threshold dither from the animated dream layer
visible in the well. Both priced crops have a floor of exactly zero.

## Frames

| File | md5 | What it is |
| --- | --- | --- |
| `00_choice_control_a.png` | `c9323b052aa90d570c475485032053b2` | **A/A** at the choice point. |
| `00_choice_control_b.png` | `67f7b4bcf04c66a645572b706111edb5` | The same, untouched. |
| `01_the_landing_as_it_was.png` | `ab2be3f5f802479edbf46ed95817797f` | The landing **with the plate hidden**. |
| `02_the_landing_now.png` | `19307b459a967b09e5cf8b4e8d8d76bd` | The same instant **with the plate**. |
| `03_control_a.png` | `3d31d6865f7309f532a2a46822c56b2e` | **A/A** on the wide camera. |
| `03_control_b.png` | `07bb919ae59f3bcbe2f6fe85ffe36cba` | The same, untouched. |
| `04_plate_and_the_climbing_arm.png` | `6514a1fb2a0f483a747417ea51a4deb3` | The plate and the arm that climbs, together. |
| `05_fire_control_a.png` | `1305c1f32f418a2206cdd440e5173058` | **A/A** at the fire plate. |
| `05_fire_control_b.png` | `f5ff5bf1f998410d7ec49c1c63768810` | The same, untouched. |
| `06_street_level_as_it_was.png` | `38a344a5422f6ccce033747b1266dd08` | **The misleading line**: `STREET LEVEL ↓` on the street floor. |
| `07_street_level_corrected.png` | `f5ff5bf1f998410d7ec49c1c63768810` | The same plate, corrected. |
| `08_the_same_plate_on_floor_three.png` | `fdc51ca87bf3b65c8774c381ca8645cf` | Floor 3, where the wording differs because the building does. |
| `09_a_later_shift.png` | `beeddd31d0e9f2f4e3a5de7d2faceef6` | An ordinary walk through, nothing staged. |

Thirteen frames, twelve distinct; `07` is the same file as `05_fire_control_b`,
because the corrected plate *is* the shipped state.

## The claims

| Change | crop | RMSE | its floor |
| --- | --- | ---: | ---: |
| no plate → **plate** | PLATE | **0.123** | 0 |
| the same, whole frame | — | 0.0250 | 0.0000481 |
| `STREET LEVEL ↓` → **corrected** | STREET | **0.188** | 0 |

**One honest caveat on the whole-frame figure.** Hiding the plate changes a
711 × 321 region, far more than its own footprint, because the plate stands in
front of the stair pendant and occludes it. The PLATE crop is the number that
prices the legend; the whole-frame number is given so the difference is visible
rather than hidden.

## Discarded passes, and one withdrawn claim

1. **The plate at z 1.30.** Measuring the guard by height showed it solid only
   from 0.4 to 1.0; at 1.30 the plate hung in the air above the rail, which is
   exactly what the first frame showed. Lowered onto the solid band.
2. **The plate at x −0.80.** It stood **51° off the direction of travel**,
   outside a 70° frustum's ±35, so a man walking in never had it on screen.
   0.65 m of approach allows 0.65·tan 35° = 0.46 m of offset; −0.35 keeps it in
   frame and still clear of the carried device.
3. **A CLAIM I WITHDREW RATHER THAN DEFENDED.** An earlier version of the live
   suite asserted *"there is no way down from this landing"* on the strength of
   six walks that all ended at +0.00. Repeating them from 0.8 m further south
   sent one long diagonal — toward b(2.90, 3.10) — down to **−1.40**: mid-well,
   not the cellar floor at −2.80. Run **first** rather than sixth, that same
   walk reaches **+0.00**, which identifies it as the body carrying state
   between walks and entering the open well, not a flight. I could not separate
   the two cases robustly, so **the assertion is gone from the suite, the prop
   comment and the plate**: floor one now says only what is certain — street
   level is this floor, and up is 2–6.
4. **Placing my builder between K2-D's scan anchors.** K2-D's suite proves its
   own builder owns no player by scanning the source between
   `_build_stair_pair_plates` and `_build_front_directory`; my function landed
   in that gap and tripped it on a **comment**. Moved below
   `_build_front_directory`. Second time this exact anchor trap has been paid
   for in this series.

## What this does not do

- It does not touch the stair geometry, collision, lighting, or any lifecycle,
  objective, custody or access owner.
- It adds no light, no state and no save key.
- **It does not repair the next transition on F02**, as instructed.
