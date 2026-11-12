---
name: character-hair-development
description: Build, refine, export and qualify character hair across Blender and Godot, including head-fitted card styles, dye accents and cast batches. Use for character hair appearance or integration; use the existing asset and shader skills for unrelated modeling or materials.
---

# Character hair from native source to the game

Preserve the approved character and improve the requested hair. Artistic
approval, native export correctness and production runtime qualification are
separate outcomes. Report each against the exact revision actually reviewed.

Use [Blender asset development](../blender-asset-development/SKILL.md) for native
modeling/export, [Godot development](../godot-development/SKILL.md) for runtime
integration and [textures and shaders](../godot-textures-and-shaders/SKILL.md)
for shared appearance. Those skills own repository rules, lane execution,
surface requirements and evidence mechanics; do not create parallel policies.

## Establish the source and current contract

Find the character's installed head, editable rig, existing hair, style file,
builder, shared shader, actual runtime loader and latest accepted evidence.
Record the source/export/image hashes, transform frame and intended replacement
parts. Preserve facial shape keys, skin weights, animations and the current
76-bone ABI; hair work adds no bones. Identify whether hair is rigidly Head-bound
or skinned through the existing rig before choosing an attachment strategy.

For the shared card workflow, resolve the current builder and schema through the
producer's latest batch freeze. The evolving working builder is
`C:/ov/reports/npc_rig/hair_cards_pilot/hair_cards.py`; cast styles live in
`C:/ov/reports/npc_rig/hair_cards_cast/styles/` and review batches under
`C:/ov/reports/npc_rig/hair_cards_cast/`. Read the actual source and selected
style before invoking it. A directory or contact sheet alone is not a freeze.
Do not copy Lily's r25 numeric bob settings into a universal cast template.
Until a generalized batch is frozen, treat its schema and output as candidates.

Read [pilot lessons](references/pilot-lessons.md) when taking in the Lily/Stacy
sources, repairing tangents or recoloring exported images. They explain proven
failures and point to their original artifacts; they are not a cast style schema.

## Build and refine a recognizable cut

Fit in the character's measured Head frame and verify the resulting world-space
placement; applying head normalization twice can move or resize the cut. Keep
the opaque scalp cap beneath layered cards. Use head-relative dimensions and
the maintained style controls for length, parting, comb direction, wave and
curl where supported. Preserve distinct short cuts, waves, coils, fringes and
pinned arrangements rather than changing only color on one silhouette.

Review the hairline, crown, temples, ears, nape, part and silhouette from front,
back, profiles and elevated angles. Inspect scalp leaks, floating roots,
intersection with eyes/face/clothes, repeated strips and clumps that disappear
from the back. Use neutral and grazing/back lighting before judging only a
flattering pose. For dye/streaks, trace the visibly exposed forelock through
alpha-aware rays; mirrored UV regions or hidden cards can put the dye on the
wrong side. Review the actual visible result.

Keep textures on UV0 and root-to-tip semantics on the second UV channel
(Blender UV2 / glTF TEXCOORD_1). Verify root=0 and tip=1 after glTF's V flip.
For this intake family, keep atlas dimensions at most 1024 with gutters that
survive filtering, sRGB albedo and linear data maps. Use the shared material
owner; cap/card response and root-tip motion must not drift into copied shaders.

## Export and admit the actual result

Explicitly select the hair objects and required rig/root. Inspect exported node
and primitive inventories: source-scene selection has previously leaked the
body into a hair-only GLB. Export card alpha as MASK, then verify that value in
the GLB; BLEND caused the wrong export behavior. Inspect cap and card bindings,
encoded images, UVs and all indexed triangles, not just Blender node intent.

Run the existing strict exported tangent checker. For supported static card
sources needing derivative repair, use the native exporter below, which retains
smooth normals through per-corner tangent and normal guides. Compare final triangle
positions, normals, both UV channels, counts, transforms and images against the
declared original. A unit/orthogonal tangent alone does not establish a correct
UV derivative. Keep failed outputs and record any actual geometry/normal change.

For the supported static two-object card/cap source, inspect and use
[the native derivative exporter](../../../art/blender/scripts/export_character_hair.py).
Its current contract refuses modifiers, weights and shape keys. For skinned hair,
use an independently qualified source/export path that preserves the existing
rig and skin data; this helper does not support that repair. Read the helper's
invocation and emitted sidecar before use, then run
[the static export audit](../../../art/tools/audit_character_hair_export.py)
with an output report. It requires the adjacent hash-bound native snapshot and
export receipt, or an explicit `--reference` export, to detect truncated output.
Inspect the report's failures and declared comparison scope. Its UV1 range
check does not prove root/tip direction, and PNG inventory does not prove dyed
RGBA identity; verify those separately. Export success alone does not admit the
asset, and the static audit grants no runtime or artistic acceptance.

Reopen the saved native source and reimport the delivered GLB. Review attachment,
normal response and representative motion extremes. Stop an invalid candidate
before scheduling more renders of it; fix or replace the exact failing input.

## Qualify through the production owner

Freeze native inputs before Godot intake. Verify imported material/shader
bindings, alpha/culling/shadows, actual image channels, loaded mip chains, UV2
semantics, tangents and bounds. Exercise the real Head-driven attachment and
motion path at rest, intermediate and extreme poses, including head turns and
existing facial animation. Check roots remain attached while tips move, with
no independent clock/pose authority or new hair bones.

Review the installed character in the intended game composition, including
Harukiya where applicable, at relevant camera distances and lighting. A gallery
or native control does not prove that installation. Record changed draw,
transparency and shadow cost when materially affected. Use the existing runtime
contract receipt mechanism for behavioral claims; retain artistic review as a
separate decision. Leave unexecuted checks explicitly unqualified.

## Cast work with a shared producer

When extending the cast with Fable, agree named ownership before edits: one
owner maintains the shared generator/shader and per-character styles; the
integration owner handles intake, attachment and qualification. Iterate in
small groups (the current cast plan uses five), review a coherent owner sheet,
then take a hash-bound freeze into integration. Reuse unchanged control evidence;
renew only checks whose inputs or claims changed. Do not overwrite another
owner's batch or render invalidated inputs while its producer is revising them.

Close each handoff with named source/style/export paths, the freeze and approval
provenance, executed native/runtime checks and any remaining qualification gap.
