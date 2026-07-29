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

## Blender integration boundary

The current procedural meshes do not carry UV coordinates. These files are
therefore intentionally **not yet connected** in `build_orison.py`. The next
integration pass should add deterministic box/projected UVs with
`meters_per_tile` from the generated `material.json`, then connect albedo,
roughness, and normal nodes in `get_material()`. Do not connect textures before
that UV work: glTF cannot preserve Blender's generated-coordinate mapping as a
portable substitute.
