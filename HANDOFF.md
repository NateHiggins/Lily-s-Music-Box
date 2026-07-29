# Handoff — Orison Apartments build (local continuation)

This document briefs a fresh Claude (or human) instance picking up the
Orison Apartments set build on a local machine. It covers the pipeline,
how to verify the build, exactly where work stopped, and the one open
defect with its full diagnosis so far.

## What this project is

*The Audio Virus* — a first-person Godot prototype set in the Orison
Apartments, a 1927 Midwestern brick apartment block, now aged to 2027.
The player is a support-line operator; sound propagates through the
building's physical infrastructure (heating risers, electrical, water,
structural, chimney flue) as an "audio virus". Design docs live in
`design/` and `art/docs/`; per-case content in the Case Network docs.

Three top-level projects:

| Path | What |
|---|---|
| `game/` | Godot 4.5 project (also verified on 4.7.1) |
| `art/` | Procedural pipeline: layout generator + Blender build scripts |
| `legacy_mobile_mvp/` | The old mobile MVP, kept for reference only |

## The pipeline (single source of truth)

Everything is coordinate-driven from **one** generator. Never hand-edit
geometry or the JSONs — change `gen_layout.py` and re-run the chain.

```
art/data/gen_layout.py
  └─> building_layout.json   (walls, rooms, furniture, markers)
      acoustic_graph.json    (heating/electrical/water/structural/flue)
      prop_catalog.json      (functional prop behavior profiles)
      material_catalog.json
        └─> art/blender/scripts/build_orison.py  (bpy → per-floor GLBs)
              └─> game/assets/building/*.glb
        └─> game/data/*.json  (same files, copied verbatim — Godot reads
                               them directly to spawn props/doors/player)
```

Rebuild steps:

```sh
# 1. regenerate layout (validates itself: overlap, footprint, door-width,
#    height-aware door-swing audit — a nonzero exit means a real defect)
cd art/data && python gen_layout.py

# 2. copy the four JSONs into the game
cp building_layout.json acoustic_graph.json prop_catalog.json \
   material_catalog.json ../../game/data/

# 3. rebuild GLBs — only needed if walls/furniture/openings changed
#    (marker-only changes skip this). Uses the `bpy` pip wheel (4.5),
#    or real Blender: blender --background --python art/blender/scripts/build_orison.py
python art/blender/scripts/build_orison.py

# 4. re-import + run the walk test (Godot 4.5 or 4.7.1)
godot --headless --path game --import
godot --headless --path game res://tests/WalkTest.tscn
```

Conventions that bite if forgotten:
- Meters, Blender axes (X east, Y north, Z up, street = −Y).
  Godot mapping: `GameBoot.b2g(p) = Vector3(p[0], p[2], -p[1])`.
- Mesh names ending `-col` import as visual+trimesh collision,
  `-colonly` as invisible collision.
- Aging/weathering is seeded (`random.Random(1927)` in `aging_pass`) —
  deterministic across rebuilds by design.
- Door markers carry `leaf` ("closed"/"open"/"locked"/"none"),
  optional `cabinet: true` (exempt from the swing audit), and optional
  `swing: "out"` (reversed hinge — currently only the street door).

## Verification

- `game/tests/WalkTest.tscn` — ~80-check suite: physics-verified walks
  (stairs, apartment 4B entry, street exit), elevator, acoustic
  propagation timing (riser sweep, flue-vs-riser race), prop behavior,
  Case 01 call flow. Exit code 0 = all pass.
- `game/tests/Screenshot.tscn` — renders documentation stills
  (`SHOT_DIR=<dir> xvfb-run godot --path game res://tests/Screenshot.tscn`
  on headless Linux; runs directly on a desktop). Copies live in
  `game/docs/screenshots/` — **stale for the current pass**, re-render.
- `game/tests/StreetProbe.tscn` — throwaway telemetry probe for the one
  open defect (below). Delete it once the defect is fixed.

## State at handoff

Merged in this pass ("century of aging + urban site + gap fixes"):
- `aging_pass(floors)` in `gen_layout.py`: 2027-era wear at every level —
  brick repairs/patches, corridor wear lanes, lino patch, the 5D fire
  (soot, boarded window, char), 3C boarded window, F04 window AC units,
  roof tar patches/dish antennas/masts/coping repairs, F01 damp line and
  rain streaks (split around the entrance).
- `site_pass(fl)`: walkable urban block — ground/sidewalk/curb/alley,
  three neighbor building masses + garages with lit windows, two
  streetlamps, hydrant, power pole + line, parked cars, bins. The block
  is deliberately crowded/limited; F01 floor node is always visible so
  the site renders from any floor.
- Kitchen cabinet doors in 4B (`F04_CAB_*`, `cabinet: true` markers).
- Radiators: ~1/3 render silver ("landlord's aluminum paint").
- Street door swings **outward** (`swing: "out"` end-to-end:
  `door()` → `collect_door_markers` → `building_root.gd` → `DoorProp`).
- Two new screenshot views: `b_16_street_level`, `b_17_alley_porches`.
- New walk-test checks: street exit, sidewalk/alley solidity, cabinets.

## ⚠ The one open defect — START HERE

`WalkTest` fails exactly one check: **"walked out onto the sidewalk"**.
The player cannot walk from the vestibule out the street door.

Diagnosis so far (all numbers are Godot world coords; z+ = street):

1. ~~Door sweep~~ **fixed**: the street door (`F01_DOOR_06`, hinge at
   (−0.455, 0, 9.795), opening x −0.455..+0.455) used to swing into the
   vestibule and shove the player into the corner pocket at
   (−0.98, 8.78) against the west vestibule wall. The `swing: "out"`
   plumbing fixed that — verified by probe: player is untouched at
   (0, 9.0) after the door opens to −100°, leaf tip parks at
   (−0.61, 10.69) over the stoop.
2. **Remaining blocker, unidentified**: driving straight from (0, 9.0)
   toward (0, 12.5), the player steps UP onto something and stalls at
   (0.0, y=0.388, z=9.493) — front of capsule at z 9.87, i.e. inside
   the wall band (F01 street wall spans z ≈ 9.59..10.0). Something
   ~0.375 m tall sits in the threshold. It is NOT the limestone water
   table (already split, gap x ±0.70 vs opening ±0.455) and NOT the
   stoop step (outside, z 10.0..10.38, h 0.09, top well below).

Next step, ready to run: `game/tests/street_probe.gd` already contains a
raycast scan (down-rays every 0.2 m along x=0, z 8.6→12.8) that prints
each surface height AND the colliding node's name — run
`godot --headless --path game res://tests/StreetProbe.tscn` and read the
`PROBE scan` lines to identify the collider. Candidates to check in
order:
- the limestone **entrance surround / door-step geometry** emitted by
  `build_wall` for brick-wall door openings in
  `art/blender/scripts/build_orison.py` (a sill/threshold block may not
  be suppressed for `sill: 0.0` doors);
- an `aging_pass`/`site_pass` furniture box crossing x ±0.455 near
  Blender y −9.6..−10.4 (grep `building_layout.json` for rects that
  straddle x=0 in that band);
- the wall opening cut itself not clearing to floor level in the F01
  street wall (check the door opening's boolean in the GLB).

After the fix: re-run WalkTest on 4.5 **and** 4.7.1 (fresh `--import`
each), expect zero failures, delete the probe (`street_probe.gd`,
`StreetProbe.tscn`), re-render screenshots into `game/docs/screenshots/`.

## Then what

The build brief's remaining threads, in rough priority:
1. Fix the street-exit defect (above) — the exterior is otherwise done.
2. Interior texture/material pass (everything is still flat-color PBR).
3. Occluder/HLOD pass to replace the coarse floor-visibility streaming
   in `building_root.gd`.
4. More Case Network content wired to the in-world call desk
   (`call_interface.gd` implements Case 01 end-to-end as the template).
