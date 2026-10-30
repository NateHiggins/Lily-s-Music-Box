---
name: godot-textures-and-shaders
description: Author, repair, integrate, and profile Godot textures, PBR materials, spatial/sky shaders, glass, and optical effects using this project's shared material pipeline. Use for surface appearance or shader behavior; use the Blender skill for native mesh and UV authoring.
---

# Intentional surfaces, measured rendering

Read [DOCS.md](../../../DOCS.md), applicable Bible rulings and
[surface requirements](../../../design/V2_SURFACE_REQUIREMENTS_2026-10-11.md).
Use the [Godot development workflow](../godot-development/SKILL.md) for runtime
integration, lane use and evidence. Keep small repairs small. Preserve the
owner's painterly atmosphere, expressive glass, readability and established
character appearance; physical plausibility supports the direction rather
than overruling it. Research proposals are not implementation authorization.

## Find the actual appearance owner

Trace the installed loader, material slots, overrides, next passes, shader
includes, texture generator, catalogue record and import sidecars. Inspect
runtime bindings: editing an unused candidate or merely supplying a texture
does not prove it is sampled. Determine the pinned executable and renderer
from project evidence; consult matching official documentation or engine source
when shader/API behavior is uncertain. Do not copy online shader syntax blindly.

Keep shared appearance parameters in their existing catalogue, material or
effect owner. Do not recreate runtime optical logic in Blender builders, scatter
palette constants across callers, or create another material registry. Generated
tables are outputs: change their source recipe and regenerate through the
existing pipeline. Reuse suitable maps and includes before adding files.

MatLib returns cached shared materials. Do not change their projection, tint,
textures or flags in place. Use the existing V2 local-binding policy; duplicate
only where local ownership requires it. Preserve live-control references and
independent world teardown. Restoration caches must not retain retired owners
indefinitely. Test a second world or unrelated consumer when shared ownership
changes; an identical resource type is not sufficient grounds for an exemption.

## Build the material at its intended scale

Physical PBR maps must sample authored, finite, noncollapsed UV charts at their
declared metre scale and grain direction. Triplanar projection is not a UV repair.
For topology, chart or baked tangent repairs use
[Blender asset development](../blender-asset-development/SKILL.md); never patch
generated glTF. Compare physical edge lengths as well as triangle UV area:
finite UVs and correct tangents can still carry badly scaled charts.

Use registered custom albedo, roughness and OpenGL normal recipes. Distinguish
albedo color-space conversion from linear roughness, masks and normals; check
the actual imported channels, sampler hints and scalar factors. Avoid double
gamma conversion or assuming Blender numeric colors equal runtime output.
Treat painted coating and exposed metal separately where the surface needs it.
The registered clear-glass zero-diffuse exception is narrow, not permission to
omit maps from other surfaces. No lettering in generated textures; retain the
separate authored lettering owner. Reference photographs inform form only.

Choose relief from manufacture: weave, timber grain, glaze, casting skin,
working marks or glass construction. Declare physical feature size, height,
normal convention and strength in the recipe. Reuse
`art/tools/material_relief.py` where appropriate. Do not convert every pigment
variation or baked shadow into a bump. Move sub-resolution relief into an
appropriate roughness response instead of creating glittering normal noise.
Silhouette, seams, holes and substantial bevels belong in geometry.

Check complete mip chains on loaded textures, including masks and details;
import settings alone are not proof. New maps can arrive with2D import defaults;
check generated sidecars with `art/tools/fix_runtime_texture_imports.py --v2 --check`
and repair missing requirements through that owner before loaded verification.
Review mip-capable/anisotropic filtering
at grazing angles and distance. Choose compression compatible with the actual
consumer: an RGB normal sampler cannot silently consume a two-channel normal
format without reconstruction. Register only demonstrated, narrowly scoped
quality exceptions; never disable mipmaps to hide a defect.

## Shader behavior and optical boundaries

Classify physical surfaces separately from sky, particles, screen composition
and named optical projections. That classification cannot exempt a physical
housing, pane, liquid or display surface. Preserve literal glass tint, alpha,
culling and depth behavior; a missing intentional albedo is not a milk-glass
defect. Inspect opaque/transparent layering, moving-view refraction and both
sides. Screen-reading refraction does not establish nested transparency or
true caustics. Keep opaque trim out of transparent passes where appropriate.

For vertex deformation, keep physical UVs separate from semantic coordinates
(for example rail fraction and height). Verify imported axis/UV conversions,
attachments, normals and tangent handedness at intermediate poses. Update
bounds and interaction/query presentation where deformation requires it, using
the existing authoritative mechanism state. Avoid per-frame mesh rebuilding
or duplicate target scans when a shared parameter suffices.

Animated weather and astronomy consume authoritative fractional campaign time,
not a new clock or unqualified scene uptime. Check pause, reverse traversal
and return to a date. Preserve lamp gating, real world occlusion, observer
privacy and pose ownership in composited creature/device effects. Brightening
an effect or disabling depth testing is not a visibility repair by itself.

## Verify the actual failure, then the composed result

Start with the smallest useful loaded family bench: map identity, UV scale,
tangent derivatives, mips and actual shader bindings. Inspect diffuse, grazing,
back-lit and motion-extreme renders with the production light. For pixel noise,
separate texture aliasing, raymarch step/jitter artifacts, temporal instability
and overexposure; compare still frames and motion before choosing a remedy.
For skies, sample relevant hours/seasons/regimes and deterministic return dates;
recipe counts or noon galleries do not establish annual visual diversity.

Measure cold/warm frame-time distributions on the same occupied route and
settings before expensive changes. Attribute texture loading, compilation,
CPU updates, render passes, overdraw, shadows and private viewports separately
where instrumentation supports it. Keep screenshots/PNG encoding outside timed
routes. Prefer bounded samples, reusable resources and inactive effect shutdown;
do not trade away atmosphere based on average FPS or an isolated shader bench.

Run Godot only through the repository lane with the pinned patched engine.
Runtime-composing MultiMesh checks need the windowed backend here. Finish related
native work before the combined capture; freeze inputs during qualification.
Use the surface requirement's existing import audits and composed inventory when
the changed scope requires them. Renew source-bound evidence after changed inputs;
do not waive stale qualification or weaken a failed assertion to make it pass.
Reuse unchanged evidence and avoid unrelated suite repetitions.

Report implementation, executed checks, observed appearance, performance limits
and unverified scope separately. Keep original failures. Parsing, a wrapper
receipt and a native preview are not runtime qualification; a test-written
schema-2 contract is not the owner's artistic acceptance.

For deliberately low-resolution glyphs, sprites or physical tile displays, use
[Godot pixel art](../godot-pixel-art/SKILL.md) as well; its sampling choices do
not replace the loaded-mipmap requirement for world PBR maps.

## Read relevant project lessons, not the entire history

- [Shared finishes](../../../design/V2_SHARED_FINISH_OWNERSHIP_AND_ARCADE_RETIREMENT_2026-10-24.md): cached ownership and literal glass.
- [Construction normals](../../../design/V2_CONSTRUCTION_NORMALS_2026-10-20.md): physical relief, compression and loaded verification.
- [Resource lifetime](../../../design/V2_PORTRAIT_RELOAD_AND_UV_LIFETIME_2026-10-24.md): reconstruction and retired resources.
- [Tardi microscopy](../../../design/V2_TARDIGRADE_MICROSCOPY_2026-10-25.md): shared lamp optics and isolated review limits.
- [Living Sky](../../../design/V2_SKY_WEATHER_INTEGRATION_2026-10-24.md): scheduled presentation, actual coverage and remaining artistic qualification.
