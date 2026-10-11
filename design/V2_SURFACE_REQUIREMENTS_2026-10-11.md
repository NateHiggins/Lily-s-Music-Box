# V2 surface requirements

Evidence class: **INERT**. Owner direction and production rule, not acceptance.

The owner directed on 2026-10-11: "I want all of the surfaces in V2 to have
properly UV applied fully custom PBR surfaces, mip mapped as efficiently as
possible. Update, retire, or replace legacy textures that don't meet
requirements. Make sure everything currently included passes and make a rule
to make sure new additions pass muster."

## Standing rule (RUL-012)

Every physical surface included in V2 must have authored, finite UVs with
nonzero area for every nondegenerate geometric triangle. Charts must preserve
physical material scale and appropriate grain direction. Triplanar projection
does not waive the mesh UV requirement. Native geometry and UV repairs belong
in Blender source and reproducible recipes; do not hand-edit generated glTF.

Each surface uses a registered, custom material recipe with source provenance,
physical tile scale, albedo, roughness and OpenGL normal maps. Uniform metallic
values are legitimate for homogeneous materials; mixed exposed metal/coating
requires a spatial metallic treatment. Roughness and normal data are linear;
albedo uses the correct color space. Preserve mechanical/stateful emission,
liquid motion, transparency and cutout behavior when replacing legacy finish.
Do not replace semantically different substances with one generic tile.

The registered clear-glass shader has zero diffuse albedo by its physical
dielectric recipe. It requires the custom glass roughness and normal maps;
an empty black albedo image would add no information. This narrow recipe
does not waive maps on tinted, painted, opaque or other transparent stock.

All sampled surface maps, including height, masks, decals and material details,
need complete loaded mip chains and mip-capable filtering. Use shared maps and
resources where substance and scale agree. Use efficient GPU compression with
visual review, preserving normal-channel conventions. The owner's current
efficiency direction supersedes the earlier blanket lossless-only preference
for V2 surface imports. A quality exception must name its actual defect and
affected map; it cannot disable mipmaps or exempt an entire material family.

Labels, interface composition, live screen render targets, light halos and sky
projections are inventoried separately from physical PBR surface maps. Named
storm volumes, lamp scattering particles and projected film light likewise
remain optical effects. Reservation volumes are development overlays. Their
special sampling must still be reviewed. This distinction does not exempt a
lamp housing, a television case, a glass pane, water, or a display's physical
screen surface. Lettering remains separately authored under RUL-008.
Gas-flame and steam-volume effects likewise retain their named optical role,
emission/transparency behavior and separate review. Merely hiding or marking
a physical surface as an effect does not satisfy the gate.

New and changed additions must pass source-map/import checks, native UV checks,
composed-world coverage and loaded-map checks, and rendered appearance review
before acceptance. A discovery run exiting zero means only that inventory was
written. It never means its recorded defects pass. Existing debt is repaired
or retired, not grandfathered. Any incomplete scope is reported explicitly.

## Implementation and verification

**art/tools/fix_runtime_texture_imports.py --v2 --check** checks all shipped
building surface images, including unique wall finishes, height and masks.
Run without **--check** to apply the policy, then import through the Godot lane.
Import settings are source-controlled so fresh checkouts retain the policy.
The original default command retains its older dream/runtime-table scope.

**game/tests/OrisonV2SurfaceInventory.tscn** enumerates loaded MeshInstance3D,
MultiMesh and particle draw surfaces, active and overlay materials, shader
map bindings and next passes, finite UVs,
collapsed triangles and actual loaded mip chains. It includes dormant geometry
and prefetches the passage. Its JSON must pass **tools/audit_v2_surfaces.py**;
the scene itself writes a schema-2 runtime contract after these checks,
representative captures, retained sash motion/tag-size checks and owner teardown.
An inventory alone is never acceptance.

The gate board runs **tools/v2_surface_evidence.py**. It independently checks
the runtime contract and inventory and requires reviewed render hashes. A
digest binds qualification to scripts, scene/data changes, shaders, image/model
assets, source recipes and authored import parameters. Text is LF-normalized;
cache destinations, generated import UIDs, ingest caches and locally extracted
GLB textures are excluded. Authored source assets must be staged before
qualification; new nonignored source additions are also fingerprinted. Changed inputs
invalidate the pass, including additions and removals. Re-run the combined
windowed scene once, review its renders, and replace the qualification packet.
Do not waive a stale qualification by comparing it to a red baseline.

The material generator shares byte-identical images only within the same PBR
channel. Each material retains its substance, physical scale and optical
policy. Different pixels automatically stop sharing. V2's seven former baked
contact-shadow cards are retired; the retained owner nodes have empty visual
meshes so residency bookkeeping and teardown continue to work.

GPU compression and mipmaps follow the
[Godot image import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html).
Existing custom shaders sample normal RGB, so the initial V2 compression
policy preserves those channels. RGTC requires consumers to reconstruct Z;
switching formats without checking those consumers would corrupt shading.

The saved packet records the current tested scope and reviewed appearance;
it does not claim gameplay completion, save reconstruction, or that every
surface has been inspected from every possible viewpoint.
