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
| `*_walls_brick-col` / `*_walls_conc-col` | material split of the same category |
| `MK_F04_B_RADIATOR_01` | marker empty; Godot spawns functional props from the JSON, empties are for Blender-side inspection |
| room ids `F04_B_MAIN` | floor + stack + room kind |
| acoustic ids `F04_B_RADIATOR_01` | shared between layout markers, acoustic graph and spawned Godot nodes |

Materials are `M_<catalog key>` from `material_catalog.json` (blockout
colors carry the Material Bible's target roughness values).

## Milestone status

This is **Milestone 1: Architectural Blockout** plus the conductor/prop
runtime from Milestone 2. Verified by `game/tests/WalkTest.tscn` (18
checks, all passing): every level walkable, apartments inside the shell,
front stair physically climbable by the player capsule, elevator serves
B1–F6, acoustic graph connected.

Whole-building geometry: 46 meshes, ~15k triangles, ~850 KB of glTF.

## Known limitations (deliberate, blockout-stage)

- Door/window openings are true holes with lintels/sills but no leaf,
  frame or glass modules yet; apartments use one shared partition
  archetype, so stack areas are uniform (~78 m²) rather than the brief's
  52–86 m² spread. The A/B/C/D archetypes specialize in Milestone 2.
- `orison_asset_library.blend` (Geometry Nodes trim/pipe/blind assets)
  is not started; blockout boxes don't need it. The build script's
  MeshBuf layer is where those assets will plug in.
- Basement pipe tunnel, fire escape, trash chute and Room 0 geometry are
  markers/labels only. Slab edges protrude 0.17 m past the exterior wall
  face (visible as bands) — cosmetic at this stage.
- No UVs, textures, LODs or baked occluders yet; floor visibility in Godot
  is a coarse level-distance stand-in for real streaming/occlusion.
- No navmesh baking yet (players are direct-controlled; residents come
  later).
