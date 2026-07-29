# Orison Apartments — Art Pipeline

Procedural authoring pipeline for the building described in the Master
Build Brief. Nothing is generated at game runtime: Python authors a
semantic model, Blender constructs deterministic geometry from it, Godot
assembles the exported scenes — and audio/props/graph all read the **same
coordinate-driven data model**, so pipes and sounds always correspond to
actual structure.

```
art/data/gen_layout.py ──► building_layout.json  (rooms, walls+openings,
        │                  stairs, elevator, functional-prop markers)
        ├─────────────────► acoustic_graph.json  (heating/water/electrical)
        ├─────────────────► prop_catalog.json    (conductor profiles)
        └─────────────────► material_catalog.json
art/blender/scripts/build_orison.py  (Blender 4.5 / bpy)
        ├─► game/assets/building/*.glb   (one scene per floor)
        └─► art/blender/orison_master.blend
game/  (Godot 4.5)  — see game/README.md
```

## Regenerating the building

```bash
# 1. layout (pure python, validates itself)
python3 art/data/gen_layout.py

# 2. geometry — either inside Blender 4.5:
#    blender -b -P art/blender/scripts/build_orison.py
#    or with the bpy wheel (pip install bpy==4.5.*, python 3.11):
python3.11 art/blender/scripts/build_orison.py

# 3. copy shared data into the game project
cp art/data/*.json game/data/

# 4. re-import in Godot (or just open the editor)
godot --headless --path game --import
```

Every step is deterministic: same inputs, same bytes out (glTF timestamps
aside). Inspect results in `orison_master.blend` before export.

## Coordinates

Meters. Blender: X east, Y north (street = −Y), Z up. Origin = center of
the ground-floor light court. Levels: B1 −2.80, F1 0.00 … F6 16.00, roof
19.20 (3.20 m floor-to-floor). Godot conversion is the glTF standard
(x, z, −y) — `GameBoot.b2g()` is the single conversion point; never
hand-rotate exported scenes.

## Naming guide

| pattern | meaning |
|---|---|
| `F04_walls-col` | floor 04, plaster wall mesh; `-col` = visible + trimesh collision on Godot import |
| `F01_stairs_ramp-colonly` | invisible collision ramp over stair steps (`-colonly`) |
| `F04_stairs` | visible stair steps, no collision (the ramp handles walking) |
| `F04_stairs_rail` / `_stairs_bal` | balustrade handrails / balusters (visual) |
| `F04_stairs_guard-colonly` | invisible fall guards along open well edges |
| `F04_wainscot` / `F04_floors_<mat>` | dado band; per-material floor finish overlays |
| `F04_furniture_<mat>-col` | lived-in furnishing boxes, one mesh per material |
| `*_walls_brick-col` / `*_walls_conc-col` | material split of the same category |
| `MK_F04_B_RADIATOR_01` | marker empty; Godot spawns functional props from the JSON, empties are for Blender-side inspection |
| room ids `F04_B_MAIN` | floor + stack + room kind |
| acoustic ids `F04_B_RADIATOR_01` | shared between layout markers, acoustic graph and spawned Godot nodes |

Materials are `M_<catalog key>` from `material_catalog.json` (blockout
colors carry the Material Bible's target roughness values).

## Milestone status

This is the **detailed architectural blockout**: Milestone 1 geometry,
the conductor/prop runtime from Milestone 2, plus the remodel pass — true
dog-leg stairs (20 risers/floor, 160 mm rise · 294 mm going, galleried
wells with balustrades and half landings between floors), baseboards,
cornices, corridor/stairwell wainscot, per-room floor finishes, facade
cornice and entry portal, basement pipe runs, and full lived-in
furnishing for every unit, and the atrium refactor: the light court is
one open switchback stair (B1→roof) around a guarded eye under a glazed
monitor and skylight, with the cores as elevator hall and utility rooms.
Verified by `game/tests/WalkTest.tscn` (64 checks, all passing): every
level walkable, the atrium physically climbable corridor-to-corridor by
the player capsule, elevator serves B1–F6, acoustic graph connected,
walkthrough tour flies and returns control. Generation-time validation
asserts furnishing completeness, kitchen facing agreement and prop
counts (switches = 2 × door leaves).

Whole-building geometry: 325 meshes, ~225k triangles, ~12 MB of glTF.

## Known limitations (deliberate, blockout-stage)

- Door and window openings carry frames, sills, glazing and hinged leaf
  props (Godot-side), but no paneled leaf/hardware modeling yet.
- `orison_asset_library.blend` (Geometry Nodes trim/pipe/blind assets)
  is not started; the box-built trim stands in. The build script's
  MeshBuf layer is where those assets will plug in.
- Fire escape, trash chute and Room 0 geometry are markers/labels only.
  Slab edges protrude 0.17 m past the exterior wall face (visible as
  bands) — reads as string courses for now.
- No UVs, textures, LODs or baked occluders yet; floor visibility in Godot
  is a coarse level-distance stand-in for real streaming/occlusion.
- No navmesh baking yet (players are direct-controlled; residents come
  later).
