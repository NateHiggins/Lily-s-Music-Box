# Generated material texture workflow

This directory turns AI-generated **base-color source plates** into
repeatable, reviewable texture sets. Image generation is an art step; map
derivation and validation are local and deterministic.

## Workflow

1. Choose or add a material in `materials.json`. Keep physical scale,
   roughness, and prompt intent in the manifest rather than in chat history.
2. Ask Codex to generate that material, or print the canonical prompt:

   ```powershell
   python tools/material_textures.py prompt plaster
   ```

3. Save the selected generated plate as
   `art/textures/source/<material>.png`.
4. Process it:

   ```powershell
   python tools/material_textures.py process plaster
   ```

5. Review `generated/<material>/preview_2x2.png` at 100% and from across the
   room. Reject obvious center seams, recognizable repeated features,
   directional light, perspective, implausible scale, and excessive contrast.
6. Review in Blender/Godot under several light directions before accepting it.

The processor writes:

- `albedo.png` — sRGB base color, with no intended lighting information
- `roughness.png` — linear data centered on the authored catalog roughness
- `height.png` — conservative luminance-derived microdetail, not true geometry
- `normal.png` — OpenGL-style tangent normal derived from the height map
- `preview_2x2.png` — fast repetition/seam review
- `material.json` — scale, paths, and measured opposing-edge error

## Generation rules

Generate a flat, orthographic, square material plate. Require seamless edges
and prohibit perspective, borders, objects, text, watermarks, highlights,
shadows, ambient occlusion, and baked directional light. AI-derived height and
roughness are estimates: use them subtly and override them with authored or
photogrammetric maps when physical accuracy matters.

The source image remains in `source/` for provenance. Never regenerate over an
accepted source silently; preserve the prior image with a version suffix and
review the new version before promoting it.

## Stains, wear, furniture, and appliances

`surface_library.json` defines a second library. Furniture and appliance
finishes produce the same four-map PBR set. Stains and wear produce neutral
grayscale masks so their tint, intensity, roughness response, and blend mode
remain editable in the consuming material.

```powershell
python tools/surface_library.py prompt stains/water_bloom
# save to art/textures/source_library/stains/water_bloom.png
python tools/surface_library.py process stains/water_bloom

python tools/surface_library.py prompt furniture/walnut
# save to art/textures/source_library/furniture/walnut.png
python tools/surface_library.py process furniture/walnut
```

Processed assets are written under `art/textures/library/<category>/<name>/`.
`catalog_mapping.json` is the explicit bridge from every
`material_catalog.json` key to a generated texture set. A `null` mapping is
intentional for shader-defined glass and emissive screens.

## In-engine wiring (build_orison.py)

The Blender build gives every generated mesh a `UVMap` layer via
deterministic world-scale box projection: each polygon's dominant normal
axis picks the projection plane and world meters divide by the set's
`meters_per_tile`, so oak boards run continuously across a room, fabric
never twists between adjacent faces, and the coordinates survive the
glTF trip as `TEXCOORD_0`. Brushed metals (`chrome`, `metal`) swap U/V
on vertical faces so the grain falls vertically on appliance fronts.

`get_material()` wires albedo (sRGB) -> Base Color, roughness
(non-color) -> Roughness, and normal through a Normal Map node at 0.35
strength — a plain Principled pattern the glTF exporter reduces cleanly.
Catalog color/roughness remain the fallback for unmapped materials and
metallic always comes from `material_catalog.json`.

### Catalog -> texture set mapping

`catalog_mapping.json` is the **single mapping authority**: every one of
the 39 catalog materials appears in it, mapping to a set under
`generated/` or `library/`, or to `null` for the four intentionally
shader-only materials (`glassish`, `screen`, `fx_ao`, `fx_shadow` — glass,
emissive screens and the fake-GI decal quads). `build_orison.py` loads it
at startup and refuses to build if a mapped set is missing maps or
metadata, or if the mapping and `material_catalog.json` disagree in
either direction. 35 of 39 materials are texture-backed — including the
rugs, paper, plants, porcelain, ceramic tile, brass, artwork, painted
trim and balusters that earlier passes left flat.

UV handling is declarative per material (`UV_MODE_BY_MAT`): world-scale
dominant-axis projection by default, `vgrain` (U/V swapped on vertical
faces) for brushed metals so the grain runs upright on fronts, and
`unit` 0..1 quads for framed artwork and the fx decals. Ceramic tile
meets grout-to-grout wherever faces share the world projection plane.

### Stain & wear overlays

The glTF exporter cannot serialize mix-node graphs, so overlays are
pre-composited by `tools/compose_overlays.py` into
`generated/_overlaid/<key>/` (albedo + roughness only; normals stay
clean). `get_material()` automatically prefers the overlaid variant.
Current restrained passes: plaster (scuffs + chipped paint), concrete
(water bloom), soot (soot haze), enamel/appliance (grease speckle),
galvanized metal (rust runs), wainscot (chips + scuffs). Overlays are
per-material and tile-global; spatially selective damage would need
per-face masking or decals — out of scope for this pass, by design.

### Adding another material

1. Add the entry to `materials.json` (scale, roughness, optional
   `size`), synthesize or generate a plate into `source/<key>.png`
   (`tools/synth_plates.py` has the procedural recipes), then
   `python tools/material_textures.py process <key>`.
2. Map it in `CAT_TEX` in `art/blender/scripts/build_orison.py`.
3. Optionally add an overlay pass in `tools/compose_overlays.py`.
4. Rebuild. Floors export as `GLTF_SEPARATE` with one shared
   `game/assets/building/textures/` directory (deterministic `T_*`
   names staged via `art/textures/_export/`), so each map exists once
   on disk and in VRAM instead of being embedded per floor.


## Runtime prop materials (game/scripts/material_library.gd)

GDScript-built props (radiators, washers, fixtures, appliances) resolve
the same shared exported textures under
`game/assets/building/textures/T_*` through `MatLib.get_mat(key, tint,
scale)`: one cached `StandardMaterial3D` per (key, tint, scale), world
triplanar mapping at the set's physical `meters_per_tile` so primitive
meshes tile at architectural scale with no per-mesh UV work, albedo +
roughness + normal (0.35), catalog metallic scalars. Tints multiply the
maps — a dark tint turns galvanized sheet into painted cast iron. Props
swap their prototype flat colors via `FunctionalProp.retexture()`, a
color-matched table pass that leaves emissive surfaces (bulbs, screens)
alone. The toaster keeps scalar materials intentionally: its shell
material is animated at runtime (gleam/heat) and owns its own values.
