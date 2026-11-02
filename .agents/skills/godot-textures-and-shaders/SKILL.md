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

## Use the local image generator for candidates

This project has a local SDXL base1.0 runner at **art/tools/imagegen.py**.
Use it for appropriate raster candidates rather than assuming image generation
requires a remote service. Read its current CLI and the
[local-generation guide](../../../tools/PIPELINE_TOOLS.md#local-image-generation)
before a batch. A documentation or planning request does not require a render.

Run from the repository root with any Python; the script relaunches its worker
in **C:/devkit/imagegen/venv** and uses the cached model offline. The optional
**ORISON_IMAGEGEN_HOME** selects another installed environment. Inspect an
existing setup before installing or downloading anything.

The public command queues GPU slices through the shared Godot lane itself.
Do not wrap it in a second lane acquisition, load SDXL manually, or invoke its
internal **--lane-slice** worker directly. Current settings are24images per
slice,900seconds per slice and240minutes queue wait; check the script if these
change. Jobs yield the lane between slices. Respect holds and other owners;
preserve actual busy/timeout results. Logs are under the output's **logs/**.

For material work prefer an explicit batch recipe. The runner's default
negative prompt was written for monochrome illustrations: it includes
**colour**, **photograph** and **3d render**. Do not inherit that preset blindly
for a colored albedo. A job's **negative** string replaces that default.

Example **jobs.json** in a private candidate directory:

```json
[
  {
    "id": "limestone_albedo_v1",
    "prompt": "orthographic flat diffuse material swatch, warm pale limestone, fine mineral variation, uniform neutral illumination, continuous texture across the frame",
    "negative": "text, letters, numbers, logos, signature, watermark, border, perspective, cast shadows, specular highlights, isolated objects",
    "width": 1024,
    "height": 1024,
    "steps": 30,
    "guidance": 7.0
  }
]
```

```powershell
python art/tools/imagegen.py --batch C:/ov/reports/texture_candidates/jobs.json --out C:/ov/reports/texture_candidates/limestone_v1 --seeds 2
```

**--prompt**, **--id**, **--width** and **--height** support simple single-job
studies; don't invent **--size** or **--dry-run** for this SDXL command. Use
**--help** to check syntax without loading a model. Batch jobs also accept their
own **seeds**, **steps** and **guidance**. A seed countN generates indices0..N-1,
not a requested arbitrary seed. Output is **id_sN.png** plus a JSON sidecar.
Keep the batch recipe too: the current sidecar omits guidance and isn't a full
environment fingerprint.

Existing PNG names are skipped without comparing the new prompt or recipe.
Resume an unchanged job; give changed recipes a new ID or versioned directory.
Do not mistake a stale existing image for the new result. Inspect each selected
image, including seams, unwanted lettering, baked light and physical feature
scale. A seamless-looking prompt does not establish actual tiling.

Generated art is a candidate, not a ready PBR set. Route accepted material art
through the existing catalogue/recipe owner; derive and calibrate roughness and
normal relief from manufacture, rather than treating RGB as every map. Keep
lettering separate, use references only within their allowed scope, retain
provenance, then verify imported maps, metric sampling and loaded mips in Godot.
Only selected production assets enter the repo, not model caches or whole seed
galleries. Dedicated likeness/LoRA tools have different models, flags and privacy
boundaries; inspect their own instructions instead of passing SDXL options to them.

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


## Native semantic and small-stock intake findings

- Godot can strip custom glTF attributes or sanitize punctuation in marker names.
  Verify actual imported bindings. Unique marker positions can recover original
  glTF identities once; shared segment corners require whole-triangle identity
  and private corner splits. Preserve loaded positions, winding, normals, UVs and
  tangents; never rewrite the GLB or rebuild semantic meshes every frame.
- Tiny manufactured parts can lose metric UV/tangent accuracy to import
  compression. Compare loaded edge ratios and tangent derivatives with the
  exported values. Disable compression only for demonstrated affected assets,
  not as a global quality prescription.
- Use the maintained PBR sampler ABI when extending physical shaders. A
  photograph can use a normalized secondary chart while its paper keeps metric
  primary UVs and registered roughness/normal maps. Keep alpha/development state
  with its existing mechanism; an image is not a blanket PBR exemption.
- Movie output dimensions can initialize before later fullscreen changes.
  Inspect both the native viewport capture and encoded movie; a cropped or
  differently sized movie does not prove the game's framing. Separate offline
  fixed-step recording budgets from real-time interaction/performance checks.
