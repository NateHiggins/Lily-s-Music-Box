# W1 — the apartment windows

*2026-08-18. Closes W-GLAZE, W-SHOW and W-JOINERY, which were one job.*

The owner reported, across three messages:

> "some of the windows on the orison are missing their treatment and glass
> entirely" … "i was referring to the outer windows on the orison from the
> exterior as well" … "when i look at the orison from the street the treatment
> on all the lower windows disapear, when i stand next to the building the top
> floors disapear but the window treatments appear" … "the textures on all the
> window parts need updating and the geometry reads as computer generated" …
> "blinds dont seem to be rendered from outside"

Every one of those is a separate cause. They are all fixed and all measured.

---

## THE BRIEF WAS WRONG ABOUT THE MAIN THING, and it is worth saying first

`TASKS.md` W-GLAZE opened with **"There is glass. There is no joinery."** That
is false, and it was the fourth count in this project taken over the wrong set.

The joinery has always existed. `build_wall()` emits, per glazed opening, two
jambs, a head, a projecting cill and a sash meeting rail, in limestone on
masonry and in trim on plaster, plus a soldier-course lintel. Measured out of
the shipped asset before anything was touched:

| `F02_stone_trim-col` | 996 tris = 83 boxes |
|---|---|
| 32 jambs | 16 windows × 2 |
| 16 heads | |
| 16 projecting cills | |
| 16 meeting rails | |
| 3 door surround boxes | one door |

The reason the earlier pass could not find it is that these parts are generated
in `build_orison.py` **from `walls[].openings[]`** and never appear in
`building_layout.json`, which is where they were looked for. The blinds are in
that file, so the blinds were all anybody found.

**What was actually absent** is why it read as computer generated, and it is
one structural fact: every window part was a rectangular prism SYMMETRICAL
ABOUT THE WALL CENTRELINE, because `box()` cannot build anything else. So the
cill projected as far into the room as onto the street, the reveal was
undressed, and the glass was one bare sheet in the middle of 350 mm of brick
with a single rail across it — no frame, no stiles, no sashes, no putty line.

---

## What the frames show

Pairs are the SAME BUILD at the SAME STATION on the SAME pinned clock
(`DAYNIGHT_FORCE=14:20`), differing only in `building_root.gd`. The control
frames are two exposures of one scene: **noise floor 0.000%**, so every number
below is signal.

| station | pixels changed | what changed |
|---|---|---|
| `01_carriageway_elevation` | 31.52% | the whole elevation |
| `02_carriageway_ground_windows` | 13.07% | a hole in the brick becomes a window |
| `03_against_the_facade` | 11.81% | the stack above the viewer comes back |
| `04_window_close` | 19.39% | |
| `05_from_the_room` | 15.86% | |

`before/02` is the owner's report exactly: a raw opening in the brick with the
stair hall visible through it, no cill, no architrave, no sash, no glass.
`after/02` is a window.

`night/` is the same set at 22:10. It is dark on purpose and is NOT a defect:
`window_glow.OWN_WINDOW_PANELS := false` has been the ruling since 2026-08-05
— the Orison shows its own structure lit by its real interior fixtures, and
only the neighbours get emissive panels. **This corrects W-JOINERY's premise**,
which argued from "these are the surfaces `window_glow` lights from behind".
They are not; the real room fixtures light them, which is a stronger version of
the same argument and is why the crown was worth building.

---

## The three causes

### 1. The street sweep was eating the building's own face

`_index_street_core_geometry()` indexes any F01 draw whose world AABB is
"fully in the street core", 15.2 × 11.2 × [-0.50, 2.80]. **The core is the
STREET REGION and the building stands inside it**, so `F01_glazing` and
`F01_stone_trim` — whole-floor batches — passed the test and had their layers
zeroed the moment the player stepped onto the carriageway. That is every pane
of ground-floor glass and every limestone jamb, head, cill and meeting rail on
the storey.

Both are named in `ENVELOPE_BATCHES` now, by the identical argument the list
already made for `window_glow`: *"the designed view of occupied rooms from
outdoors"*.

**Matched as substrings, not whole names, and that turned out to be load
bearing within the hour.** Giving the slats their own material moved them out
of `furniture_trim`, whose extent reached z 37.57 into the Passage and had
therefore always failed the containment test *by accident*. The moment they had
an honest extent of their own they became enclosed content and vanished from
the street — the fix for one half of the report created the other half.

### 2. `outside` was a metre bigger than the building

The floor rule asked `absf(p.x) > 15.2 or absf(p.z) > 11.2`, borrowed from
LightRig's street core. The shell is 14.05 × 10.05. So a band of pavement more
than a metre wide ran along every facade in which the eye was **neither
outside nor on any interior storey**, and the rule fell through to the
active-storey window `absf(p.y - z) < 1.75`, which keeps the floor at your feet
and culls everything above it. You could not see the building you were leaning
on. The rear porch decks at |z| 10.05–11.35 sat inside that band too, so the
fire escape hung off a building that was not there.

`OUTSIDE_HALF_X/Z` are now 14.2 / 10.2 — 150 mm clear of the masonry, which is
all the old metre was ever buying.

### 3. The prop clause, and this one was the owner's call

Exterior views kept every floor's SHELL and only F01's CONTENTS, so a lit
apartment three storeys up was an empty room behind glass. Ruled open to every
floor on 2026-08-18; the exterior term now matches the floor rule exactly. The
Passage term stays F01-only because the Passage *is* F01.

---

## What was built

Per glazed opening, outside to in: reveal lining, outer architrave standing
30 mm proud, label mould over the head, a cill that projects onto the street
and dies into the wall inside with a sloped wash and a throating under its
nose, interior window board and architrave in timber, the frame in its rebate,
and then sashes — a 1-over-1 double hung in two separate planes, upper
outboard of lower, so the meeting rails actually meet. Mullions divide anything
wider than 1.45 m, which the three 5.40 m bands needed and never had.

Slats are crowned sections now, four spans across a 50 mm chord, and they
**turn**: the old model held the chord level and changed the box's aspect
instead, so a closed blind was a stack of tall thin posts standing on edge.
The pitch also ran backwards to its own docstring — `0.055 + 0.02 * tilt`
opened the spacing as the slats closed, so a shut blind covered 45% of its
window. It tightens with the turn now.

`sash` and `blind_slat` are their own materials
(`art/tools/build_window_joinery_maps.py`) instead of `trim`, the paint on
every skirting board in the building. The sash is held deliberately darker than
the slats: the first pass put both near 0.82 albedo and the frame disappeared
into the blind it is always seen against.

### The blinds were 450 mm behind the facade

Owner: *"blinds dont seem to be rendered from outside"*. They rendered. They
hung a hand's width **into the room** past the inner plaster, which was the
only sane place while the opening was a bare hole — and once the reveal was
lined and a frame went in the rebate, the lintel occluded them from any
pavement eye. They now hang off the frame, 30 mm clear of the sash, cut to the
daylight width (1.13 m, not 1.34 m — the old one was wider than the hole it
covered). The generator's own two blind rules were re-stated rather than
relaxed: they had encoded the old mounting, and they caught this in 132 places
before a single frame was taken.

---

## Cost, recorded rather than filtered — §DP

| file | render before | after | delta | draws |
|---|---|---|---|---|
| floor_b1 | 38,852 | 41,924 | +3,072 | 83 → 84 |
| floor_01 | 174,018 | 182,946 | +8,928 | 529 → 532 |
| floor_02 | 79,836 | 92,700 | +12,864 | 91 → 94 |
| floor_03 | 80,500 | 92,596 | +12,096 | 104 → 107 |
| floor_04 | 81,254 | 93,230 | +11,976 | 100 → 103 |
| floor_05 | 78,324 | 91,308 | +12,984 | 101 → 104 |
| floor_06 | 78,366 | 92,454 | +14,088 | 97 → 100 |
| roof | 26,016 | 28,392 | +2,376 | 56 → 57 |
| **total** | **637,166** | **715,550** | **+78,384 (+12.3%)** | **1161 → 1181** |

Collision 95,364 → 107,316 (+11,952), from the sash frames; the slats
deliberately do not collide.

**+20 draws is the number that matters** — §P's frame is submission-bound
rather than fill-bound. For scale, `F0x_stairs_bal` alone is 186,576 triangles
and §DP calls it the standard the rest of the building should be measured
against. **The trigger condition is still unmonitored**: nobody has measured
this build's frame on a desktop, so the owner's "dont worry about budget until
we hit performance issues" has no off-switch. That is unchanged by this work
and it is still the largest thing nobody is watching.

## The instrument was the broken thing again, for the sixth time

Chasing the visibility bug headless showed 41 draws indexed as enclosed on an
extent nobody had computed — the street-end hoardings at |x| ≈ 20 m, the
driving rain, the roadway mist, every Vantry point batch. **Under Vulkan the
same nodes report real extents and are classified correctly.** The dummy
renderer keeps no multimesh instance transforms, so `get_aabb()` returns an
empty box at the origin, and an empty box at the origin is inside any envelope
that spans the origin.

No player has ever lost the hoardings. The guard stays because every automated
harness in this project runs headless, and a gate that hides forty-one street
draws only when it is being watched is a measurement waiting to be believed.
Reconstructing the extent from the multimesh's own instance transforms was
tried and does not work — the dummy renderer returns identity for every one of
them, which lands the whole batch back on the origin.

## Reproduce

```bash
cd art/data && python gen_layout.py && cp building_layout.json ../../game/data/
```
```bash
python art/tools/build_window_joinery_maps.py
```
```bash
"/c/Program Files/Blender Foundation/Blender 5.2/blender" -b -P art/blender/scripts/build_orison.py
```
```bash
SHOT_DIR=<abs> godot --path game res://tests/WindowShot.tscn
```

`SHOT_DIR` is required and the harness refuses without it —
`street_shot.gd:66` writes to `/street_N.png` and fails silently, which is a
trap worth not re-entering. `SHOT_HIDE="sash,blind,glazing"` hides a whole
class at once, which is how the night frames were cleared of my own geometry as
a suspect in one run rather than three.
