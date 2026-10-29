---
name: blender-asset-development
description: Build, repair, UV-map, bake, export, and review Blender assets for this project's Godot pipeline. Use for physical props, architecture, mechanisms, and deforming asset presentation; not unrelated image generation or gameplay-only changes.
---

# Credible construction, measured presentation

Read [DOCS.md](../../../DOCS.md), applicable repository rules and the affected
asset's source plan before authoring. Follow the
[batch workflow](../../../art/blender/v2_batch_workflow.md) and
[surface requirements](../../../design/V2_SURFACE_REQUIREMENTS_2026-10-11.md).
Use a lightweight pass for small repairs; improve the requested object without
adding unrelated systems. Preserve the owner's atmosphere and rule of cool.

## Inspect the installed object

Find its builder, editable blend, export, runtime loader, material catalogue,
part names, transforms and existing evidence. Verify the Blender executable
version: older README examples are not proof of the installed API. Determine
which file actually drives the game before replacing a plausible-looking asset.
Keep mechanical, collision, inventory, save and narrative owners intact.

Measure the occupied opening, support faces, neighboring geometry, player
clearance and moving-part pivots. Use project metre coordinates and its existing
Blender-to-Godot conversion once. A floor-contact ray does not prove continuous
solid support; a bounding box does not prove a door gap is blocked or clear.

## Author construction, then optimize its presentation

Build comprehensible attachment chains: casing to backplate to fasteners to
support, bearing to shaft, coupling to receiving seat. Intersecting primitives
alone do not explain manufacture. Keep meaningful closed stocks and working
partitions editable; batch static exports by material where ownership permits.
Use mesh/BMesh construction for repeated stock instead of thousands of operators.

Spend geometry on silhouettes, near-camera relief, cast shadows and operable
parts. Bake smaller relief only where it survives the intended viewing distance.
Triangle budgets, bevel widths and texture sizes in example briefs are starting
points, not universal limits. Measure draw calls, transparency and shadow cost
as well as triangles. Do not turn every decorative part into an actor.

Reuse helpers under `art/blender/scripts`: `frame_mitre_geometry.py` for full-depth
45-degree frame joints; `fabrication_chart_batch.py` and `fabrication_uvs.py` for
metric charts; `fabrication_grain.py` for stock grain; `fabrication_normals.py`
and `check_exported_tangents.py` for shading/export derivatives. Preserve curved
rest-length charts where appropriate. Read each helper's actual contract first.

Drive a moving stock around its measured local mechanism axis with an explicit
pivot. Euler channels on an already tilted stock can rotate about the wrong
axis; compare closed, intermediate and endpoint poses after export.

## Surface and export decisions

Keep material and shader ownership in the existing shared pipeline. Bind
registered materials, maps and reusable preview presets rather than embedding
copies of runtime shader logic or scattering hard-coded palette, optical and
material-response values through asset builders. Resolve existing appearance
parameters from their catalogue or source material; make any necessary preview
binding reusable and data-driven.

Blender studies own geometry, UVs, semantic attributes and deformation. Runtime
lamp gating, optical attenuation, observer privacy and state-dependent effects
remain with their runtime owners unless the task explicitly authorizes shader
development. Use existing native materials or clearly labelled diagnostic
materials for CPU review; record missing renderer effects instead of recreating
them to make a preview look finished. A Blender preview does not qualify the
runtime shader or its behavior.

Use registered custom PBR recipes, physical UV scale, grain along each stock,
linear data maps and the existing OpenGL normal convention. Primary maps must
sample the authored charts. Reuse suitable maps before allocating another atlas.
When baking, establish the evaluated low mesh, tangent basis, cage, padding and
target image explicitly. Curvature is an authored/derived mask, not an assumed
portable bake operator. Check packed channel meanings in the actual consumer.

Model coating and exposed substrate separately in material response: painted
iron is not uniformly bare metal; contact wear can polish or abrade a finish.
Keep optical glass separate from opaque trim. Never replace working glass with
an alpha cutout just because a generic example recommends it. Reference photos
inform form only; no photo pixels enter exports. Generated textures carry no
lettering; use the established separately authored lettering owner.

Preserve hinge/bearing origins and independent movable partitions on export;
an assembly snapping datum is not every part's pivot. Never hand-edit generated
glTF. Record source/builder bindings and review the saved blend, final float32
export and Godot import, including UV degeneracy, tangents and loaded mipmaps.
Apply import/compression exceptions only to demonstrated defects and register them.

For planar extrusions, derive winding from the actual tangent/up/outward frame;
facade and dial frames can have opposite handedness. Check named front normals
and mechanical layer clearances in transformed float32 exports, then the loaded
result. Bind newly reused geometry helpers in the family's source provenance.
If Windows blocks direct export replacement, prefer the existing validated
temporary-export path with bounded replacement; retain the original failure.

## Verify in a bounded batch

Finish native diffuse/grazing/back-side and motion-extreme review before a
combined Godot capture. Include a failed or deliberately wrong control where it
can expose a real weakness. For deforming assets, check rooted attachments,
contained parts, normals and representative intermediate poses at each LOD;
sampled poses are not proof of every possible deformation.

Use `--python-exit-code 1`; stop on command failure or nonempty failure lists.
Then follow the Godot skill and shared lane for imported appearance, affected
actual manipulation and persistence. Reuse unchanged evidence, retain failures,
and distinguish native checks, runtime contracts and owner artistic acceptance.

## Project learning sources

Read only what the task needs; these are evidence and examples, not blanket budgets:

- [Door example and adapted plan](../../../design/V2_FRONT_ENTRANCE_REMODEL_2026-10-27.md): trim allocation, close-up hardware, coating and glass corrections.
- [Heating workflow](../../../art/blender/heating_distribution_workflow.md): hash-bound native review, glTF round trip, precision exception and composed support interfaces.
- [Astra creature rebuild](../../../design/astra/DREAM_CRITTER_BLENDER_REBUILD_2026-09-19.md): rooted anatomy, per-component topology, LOD/pose checks and existing-controller presentation.
- [Claude lived-in pass](../../../design/CLAUDE_APARTMENT_LIVED_IN_PASS.md): resident specificity with bounded draws/obstruction; visual, simulated and interactive functionality are separate claims.
- [Passage pull and oak](../../../design/V2_PASSAGE_PULL_AND_OAK_2026-10-25.md): hardware seated on real stock, resolved physical grain scale, actual first-event hand motion.
