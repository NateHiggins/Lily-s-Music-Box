# H13 — live presentation audit (the instrument, and its first run)

Built and first run 2026-08-21 on Godot 4.7.1 Compatibility. `TASKS.md`
§H13-PRESENTATION asked for **one instrument, not another defect ledger**;
this is `res://tests/PresentationAudit.tscn`. It boots the production
`BuildingRoot` with WalkTest's discipline and asks the *live* scene the
questions the 2026-08-20 data sweep could only ask the JSON.

```
godot --headless --path game res://tests/PresentationAudit.tscn     # six physics/data passes
godot --path game res://tests/PresentationAudit.tscn                # + OrbitSweep (real window)
AUDIT_OUT=<existing dir>   AUDIT_ORBIT_STEP=30   AUDIT_SKIP=overlap,support,...
```

Exit code is 0 when every requested pass ran and 1 only if the building
failed to boot. Findings are `[AUDIT]` lines and `presentation_audit.json`
(+ `orbit_sweep.csv`), both in this directory from the run below. The
punchlist rows derived from it are in `design/walkthrough_punchlist.md`
under 2026-08-21.

## Passes and what the first run measured

Boot: `gl_compatibility`, 8 floors, 13,897 named nodes, 0 script/shader
errors in both headless and windowed runs.

### overlap — live cross-class AABBs

453 marker-spawned props (their *drawn* AABB, from mesh instances) against
each other and against 2,344 baked rect boxes from the layout, penetration
> 3 cm, minus an assembly whitelist (appliances on a sink's drainer, lights
inside soffits/canopies, pipes/switches/doors). **25 cross-class
interpenetrations** (49 whitelisted, 0 same-class):

| lead | rows | depth |
|---|---:|---:|
| toaster × kettle in 1A, 1D, 3D, 4C, 6C kitchens | 5 | 133–152 mm |
| `ROOF_VENT_FAN_B` inside `roof_bed1` (and its soil) | 2 | 420 mm |
| `F06_6D_SHOWER_01` × `6D_rolledrug` | 1 | 154 mm |
| 6A monitors × `6A_deskwall` / desk-wall legs | 5 | 50–120 mm |
| `F02_2C_STOVE_01` × three `k_hob_tape` strips | 3 | 55 mm |
| `F03_D_SPEAKER_01` recessed 50 mm into `3D_booth_n` | 1 | 50 mm |
| `F02_A_MONITOR_01` × `F02_A_LAMP_01` | 1 | 56 mm |
| `F01_BODEGA_RADIO` 50 mm into `retail_bod_floor` | 1 | 50 mm |
| `F01_BAR_SONGBOOK` into the bar dado and two gallery frames | 3 | 45–60 mm |
| `F02_C_MONITOR_01` × `2C_bench`, `F04_B_LAMP_01` × `desk_legs`, WC sink × towel | 3 | 50 mm |

Furniture authored as `asm` records with only an anchor (`chair`, `crate`,
`bed`…) has no size in the layout and is not in this pass; its footprint
lives in the generator.

### support — authored base vs collider

91 free-standing marker props, one ray from 0.30 m above the **marker
origin** to 0.50 m below it, excluding the prop's own bodies. The mesh AABB
bottom is deliberately *not* the reference — cords and skirts hang below a
base by design and are reported only as reach. **16 outside ±30 mm:**

- **every kitchen toaster** (1A, 1D, 2A, 3A, 3D, 4A, 4C, 5A, 6A, 6C): base
  sunk **215 mm** into `F0x_furnish_hull` — one systematic authoring offset,
  the same lead the data sweep called toaster/dishrack congestion;
- `F01_KARAOKE_SPK_1` sunk 230 mm into the hull, `F01_KARAOKE_SPK_0` and
  `F01_BAR_SONGBOOK` with **no collider within 0.5 m** below the base;
- `F04_B_STOVE_01` sunk 100 mm, `F01_BODEGA_RADIO` sunk 50 mm into the
  bodega floor, `F02_A_LAMP_01` sunk 75 mm into `Service_2A_papers` (its
  mesh reaches 340 mm below the base).

### art — WalkTest's `[ART]` sweep, verbatim

55 pieces; 8 with something within 34 cm in front, 9 with nothing solid
within 40 cm behind. Identical to WalkTest's standing result; the landing
memory art accounts for seven of each.

### density — dressing records per m², bottom decile

127 rooms, median **0.54 records/m²** (layout furniture minus pipes,
switches, blind slats and site batches, plus marker props minus lights).
Five rooms hold **zero** dressing records in the data: `F02_D_BED`
(27.7 m² — only a switch inside its rect), `F02_D_OFFICE`, `F05_D_OFFICE`,
`F04_B_CLOSET`, `F04_B_VESTIBULE`. The five F02–F06 corridors sit at
0.08/m² (17 records over 205.7 m² each), `F01_STORAGE_C` at 0.07/m²,
`B1_ELECTRICAL` 0.10, `F04_ATRIUM` 0.14. The data sweep's "zero empty rooms"
counted every record class; counting only dressing, 2D's bedroom is empty
unless something spawns there at runtime outside the layout.

### walls — 1.4 m rays across every authored wall

5,783 rays at 0.25 m spacing across every wall ≥ 0.4 m long, 0.35 m either
side at 1.4 m, skipping 2,234 samples inside authored openings (windows and
doors read permissively as `[at − w/2, at + w]`). **0 see-through samples
on any floor.** The perimeter wall-gap lead is closed by measurement.

### ceilings — who closes the room above the eye

Five upward rays per room (centre + quarter points) from standing eye,
3.6 m reach, classified by *height* (a ceiling at +3.015 and the slab
underside at +3.02 are 5 mm apart — the eye cannot tell them apart and
neither can a ray), beside the data's ceiling-rect coverage, with the hit's
owning floor node kept as evidence. The production `show_all_floors` gate is
flipped off for real at each room's eye and the floor above's visibility
read back. **17 of 127 rooms fall short of a closed ceiling:**

- **The corridor "22% without a ceiling rect" is the atrium light well.**
  F02–F06 corridors: data 79%, 2/5 rays open — one inside the atrium rect
  (by design), one in a point belonging to no room. That second point is
  the only thing left to look at; the rest of each corridor meets the slab
  above at ceiling height.
- All six atria: open above, stair ramps caught by the other rays — by
  design.
- `F0x_C_BED2` on every floor: data 96%, every ray still meets a surface at
  ceiling height, the slab above is visible at standing eye — reads as bare
  ceiling, not a hole.
- Rays never found a "slab hidden by the visibility gate at standing eye":
  the gate keeps |eye − floor above| < 1.75 m visible, and a standing eye is
  1.6 m under it.

### orbit — eight stations × 360° yaw × three pitches (window only)

288 frames: perf_probe's eight interior stations (lobby, atrium eye,
corridor F04, apartment 4B, roof, harukiya, arcade cluster, passage throat),
yaw 0–330° in 30° steps at pitches −20°/0°/+20°. Per frame the CSV logs the
LightRig granted set (fixtures lit above 0.05 energy), the lights the
engine's own culler (`instances_cull_convex`) returns for the camera frustum,
the granted lights whose AABB meets the frustum, the strict subset whose
*centre* is inside every frustum plane, and the mean luma of each screen
sixth. The plane convention is measured at start (a point 5 m ahead reads
inside: planes face outward).

**Result: the granted set is direction-blind and nothing in view is culled.**
At a fixed eye the granted set never changed with yaw or pitch; the only
variation at lobby, atrium and corridor F04 is `F01_STREETLAMP_04` crossing
the 0.05 line (lit 1/36, 33/36, 26/36 frames, last energies 0.075 / 0.455 /
0.054) — a flicker, not a grant. **Granted lights with their centre in view
that the culler dropped: 0 of 288 frames at all eight stations.** The 1–3
"box meets frustum but not culled" rows per frame sit at frustum corners,
where a plane-by-plane box test over-includes; the strict metric is the one
that answers the lead. Screen-sixth luma ranges per station are in the CSV
and JSON (roof peaks at 0.16, harukiya at 0.53).

So "lights disappear with view direction" is **not** visibility gating, not
LightRig rank churn and not frustum culling at these eight stations. What is
left for that symptom is per-object light assignment on merged meshes
(`max_lights_per_object`, raised to 128 on 2026-08-16) and fixture flicker —
neither of which this sweep can see, and both of which a room-by-room look
with `LightingDebugTest` can.

### the 183-still harness, rerun

`WalkthroughShots.tscn` with `SCREENSHOT_TEST_CAMERA_LIGHT=1` wrote **182**
frames in this run (the established count was 183; one fewer diagonal is
produced from the current layout — a room under 20 m² or a corner now
occupied). Frames are in the session scratchpad, not committed; they are
the eyes for the punchlist rows above.

## The first generator fix the instrument earned — every toaster

`_toaster_marker`'s callers rotated its −0.38·cw offset by the run's facing
yaw while the dishrack, mug and kettle were placed unrotated, so every
south- and east-facing run (yaw 180 / −90: 1A, 1D, 2A, 3A, 3D, 4A, 4C, 5A,
6A, 6C — all ten generated kitchens) put the toaster at +0.38·cw, on the
drainer. That is both audit rows at once: the 133–152 mm toaster×kettle
overlaps, and the "base sunk 215 mm into `furnish_hull`" — the toaster was
standing inside the **dishrack's** collision hull (the kitchen's own hull
tops out at 0.92 m, 25 mm over the worktop, and never was the culprit).

Fix in `gen_layout.py`: the offset is now in the run's world frame like the
clutter's. A new `_validate_kitchen_worktops` refuses any toaster within
0.19 m of its unit's dishrack, mug or kettle (toaster half-length plus
dishrack half-depth; 4B's hand-authored 0.20 m kettle spacing keeps its own
48 mm check). Run against the OLD layout it fails 21 times, which is the
premise; on the new one it passes. Regeneration moved exactly the ten
toaster markers (and their ten electrical nodes in `acoustic_graph.json`);
walls, rooms, ceilings, slabs and all 7,242 furniture records are
byte-identical, so no GLB rebuild was needed. Copying the generator's output
also brought `game/data/material_catalog.json` up to date — `40cbe01` added
`sash` and `blind_slat` on 2026-08-18 and never copied the file over.

Re-audit after the fix (`presentation_audit_after_toaster_fix.log`):
overlap rows **25 → 20** (toaster rows 5 → 0), support rows **16 → 6** (all
ten toasters gone; the six that remain are the bar/bodega speakers and
songbook, the 2A lamp and the 4B stove). WalkTest FAST PASS, LightingAudit
PASS (127 spaces), 0 errors.

`toaster_1A_before.png` / `toaster_1A_after.png`: the 1A counter from
`@-8.4_1.45_2.5:0|-14` under its own fixtures and the phone, old layout
swapped in for the first frame. Before, the toaster is wedged into the
dishrack beside the kettle at the range end; after, it stands on the
drainer end.

## Second generator fix — the roof ventilator in the garden bed

`ROOF_VENT_FAN_B` was authored at (−4.0, 8.2) as one of the 1928
reopening's four ILG-pattern roof ventilators, one per bathroom riser. The
later roof-garden pass laid the east raised bed (`roof_bed1`, x −4.6…0.6,
y 7.4…8.9, 0.42 m tall) and its first geranium box over that spot, so the
motor stood 420 mm inside the planter. Everything south of that bed is open
roof except a watering can at (−4.95, 6.90), so the fan now stands at
(−3.6, 6.75): clear of bed, soil, plant and can by ≥ 0.2 m, still on its
riser's side of the roof, and a marker move only — no GLB rebuild.
Regeneration changed one marker and its ventilation-graph node and nothing
else. Re-audit: overlap rows **20 → 18**, the two roof rows gone; support
rows unchanged at 6. WalkTest FAST PASS, LightingAudit PASS, 0 errors.

`roof_fan_before.png` / `roof_fan_after.png`: the north parapet from
`@-2.0_20.9_-5.2:25|-18`, old layout swapped in for the first frame.

## Third fix — two bases authored on the wrong surface

Both are z omissions, not placements. `F04_B_STOVE_01` (the player's own
range, hand-authored in 2026-08) was placed at floor level while the
`4B_stove_plinth` it stands on is 0.10 m tall; `F01_BODEGA_RADIO` was
placed at 0.0 while `bod_floor` lays a 0.05 m lino finish there. The range
now sits at z + 0.10 and the radio at 0.05. Two markers and their graph
nodes changed; no furniture, no rebuild. Re-audit: support rows **6 → 4**,
overlap rows 17. WalkTest FAST PASS, LightingAudit PASS, 0 errors.
`stove_4B_before.png` / `stove_4B_after.png` from `@-9.25_10.95_-7.4:0|-16`.

The support rows that remain are the bar's karaoke speakers and songbook
terminal, which are wall- or stage-mounted by intent and report "no
collider below the base" or a hull under a cabinet — a look, not a fix —
and the 2A lamp whose base sits 75 mm into the service papers on its desk.

## What the remaining rows turned out to be

- **2D and 5D's empty rooms are authored.** `gen_layout.py` lists 2D as
  "sealed since 1927: nobody dresses a tomb" and 5D as "vacant (fire
  damage)"; the density census's `F02_D_BED`, `F02_D_OFFICE` and
  `F05_D_OFFICE` zeros are the building's fiction, not an omission. 4B's
  closet and vestibule (2.1 / 2.8 m²) remain the only undressed rooms with
  no such rule.
- **6A monitors "into" the desk wall** are the monitor prop's mesh — its
  stand/cable hangs 222 mm below the authored base — passing through a
  50 mm desk top and the end frames; the bases themselves sit 10 mm above
  the top. Cosmetic, and a prop-mesh question rather than a placement one.
- **Bar/bodega speakers and the songbook terminal** report no collider
  below their base because they are wall- or stage-mounted props; the
  "sunk 230 mm" karaoke speaker and the 50 mm bodega radio are the two in
  that group still worth a look in the frame.

## Instrument corrections made during the first run

- `kitchen_linear` is a linear light (`F01_BAR_LT_CAN0`), not a counter run;
  it moved to the light kinds, which are whitelisted for overlap wholesale.
- The support ray first measured the mesh AABB bottom and called every
  toaster and monitor "clipped ~215 mm" — a hanging cord drags that bound
  down. It now measures the authored base and reports mesh reach as info.
- The ceiling pass first classified by collider ownership and called every
  100%-covered room "slab above"; ownership is kept as evidence and height
  plus data decide.
- The orbit pass first tested a range *sphere* against the frustum and
  called one spot light per station "dropped by the culler"; it now tests
  the light's own AABB (what the culler tests), measures the plane
  convention instead of assuming it, and reports the strict centre-in-view
  metric beside the box one.
- "Granted set churns" was first printed for a set that differed over
  *time*, not direction; the pass now names the fixture and its frame count.
