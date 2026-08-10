# TEXTURE REPAIR AND PERFORMANCE PLAN

*Design only. Based on `AUDIT_TEXTURE_LANDING_REPORT.md` and measurements of
the built Godot asset tree on 2026-08-10. No texture or runtime behavior is
changed by this document.*

## Outcome

Make a material mean the same physical thing in Blender and in runtime-built
props, remove the concrete-like treatment from enamel and porcelain, preserve
useful household variation, and reduce texture residency/bandwidth without
adding draws or a bespoke shader zoo.

This is primarily a **memory, loading, cache-bandwidth and image-stability**
repair. The current RTX 4080 probe is resolution-independent and CPU-bound on
draw submission; texture work must not be sold as the cure for the remaining
39–48 ms active-floor frame. It should make the game markedly safer on smaller
GPUs and Android, reduce stutter, and stop distant surfaces shimmering.

## Measured baseline

- `game/assets/building/textures`: **978 PNGs / 720.8 MiB**.
- **622.9 million source texels**; approximately **1.80 GiB** decoded at the
  base level using the source channel formats.
- Current Godot imports inspected for albedo, normal and roughness use
  `compress/mode=0`, `vram_texture=false`, and `mipmaps/generate=false`.
- A VRAM-compressed set with mipmaps is roughly **0.6–0.85 GiB** before the
  content reductions below, depending on desktop/mobile block format.
- **243 wall-finish maps** are 81 unique walls times albedo, normal and
  roughness.
- **42 exact duplicate files in 33 groups waste 38.2 MiB on disk** and become
  separate texture resources because they have separate paths.
- Physical-scale disagreements currently reach 2.25x (`porcelain`), 2x
  (`wood_dark`, `brass`), 1.67x (`enamel`) and 0.46x (`soot`).

## Architecture: one material contract

`ingest_material_sources.py` becomes the sole author of a material's source
plate, canonical texture paths, metres-per-tile, map sizes, normal strength,
metallic/roughness scalars, alpha policy and import tier.

It emits a generated runtime manifest beside `material_catalog.json` and a
small generated GDScript constant consumed by `MatLib`. `MatLib.get_mat()` and
its cache API remain stable; the hand-written `SETS` table goes away. Blender
continues to resolve through `catalog_mapping.json`, but both outputs are made
from the same material metadata in the same run.

A hand-authored exception file may specify optical behavior or a deliberately
different PBR scalar. It may not repeat metres-per-tile or texture filenames.
The generator fails if an exception attempts to create a second scale
authority.

Aliases share a canonical file path instead of copying identical bytes under
new semantic filenames. For example, `brass` and `brass_dull` may share maps
while retaining different metallic/roughness values. Godot then loads one
texture resource for both.

## Semantic repair

The overloaded keys are split before any scale is tuned:

| New role | Owners | Physical coverage | Treatment |
|---|---|---:|---|
| `enamel_appliance` | ranges, monitor-tops, medicine cabinets | 0.60–0.85 m | Smooth vitreous glaze, sparse chips/crazing; no stucco relief. |
| `porcelain_fixture` | sinks and shower receptors | 0.40 m | Broad smooth glaze with local mineral wear. |
| `mineral_scale` | kettle interiors, faucet deposits | placed decal/mask | Non-tiling deposit; never used as object enamel. |
| `wood_furniture_dark` | cases, shelves, clock bodies | 0.60 m | Furniture-scale walnut grain. |
| `wood_handle` | kettle bails and hand-scale wood | 0.20–0.30 m | Tight turned/bent grain. |
| `linen_household` | towels, airer and domestic fabric | 0.50 m | Existing household weave. |
| `bookcloth` | book covers | 0.10–0.18 m | Fine weave that survives a 20–37 mm spine. |
| `soot_surface` | chimney/flue masonry | 1.20 m | Shared large deposit field. |
| `soot_deposit` | small thimbles and placed halos | 0.30–0.55 m | Local deposit, preferably a mask/decal. |
| `brass_architectural` | rails and long trim | 0.25 m | Directional age at architectural scale. |
| `brass_hardware` | knobs, catches, tokens | measured after render | Fine hand wear; reuse `brass_dull` where appropriate. |

The ambiguous bare `enamel`, `wood_dark`, `linen`, `soot` and `brass` names
become deprecated aliases during migration, then validator errors once every
consumer has moved. A name must encode the physical class, not merely color.

The bookshelf's two cached materials are duplicated before enabling vertex
colors. That is a correctness fix, not a visual variation system.

## Runtime texture budget

Use the source at 2048 for synthesis and seam repair, then ship by projected
need:

| Tier | Albedo | Normal | Roughness | Typical use |
|---|---:|---:|---:|---|
| Architecture hero | 1024 | 1024 | 512 | brick, plaster, floors, large wood |
| Close domestic | 1024 | 512–1024 | 256–512 | enamel, porcelain, stove, sink |
| Hand-scale prop | 512 | 512 | 256 | knobs, rubber, bookcloth, Bakelite |
| Unique wall condition | 512–1024 albedo only | shared base | shared base | per-wall staining/stripping |
| Placed decal | projected-size cap, alpha | usually none | usually none | grease, scale, soot halo |

No 4K supertiles. Large-scale uniqueness comes from stable UV offsets,
orientation, vertex tint and sparse placed decals—not sixteen times the
memory. Low-frequency illumination is removed from tileable albedo and family
means remain normalized so offsets cannot produce a patchwork grid.

### Wall finishes

The 81 wall-specific finishes keep their unique albedo because that carries
the authored stripping/stain history. They stop shipping 81 unique normals
and 81 unique roughness maps. Those channels use the shared plaster,
wallpaper and brick bases; hero damage requiring real relief remains geometry
or a sparse decal. This removes **162 texture resources** without flattening
the wall's story.

### Variants

Color variants may keep distinct albedo where the difference survives a room
render. They share base normal and roughness maps unless the physical surface,
not merely its color/layout, is different. Variants invisible at player
distance become deterministic tint/offset choices instead of additional map
sets.

## Godot import policy

All 3D material maps receive deterministic import settings before the final
Godot import:

- VRAM-compressed texture mode, with desktop and ETC2/ASTC platform output.
- Mipmaps enabled for every repeating 3D material and wall finish.
- Normal maps explicitly imported as normal data, never color data.
- Albedo remains sRGB; normal, roughness, height and masks remain linear.
- UI, text, cards and deliberately pixel-exact screens stay outside this
  policy and retain lossless/non-mipped rules where appropriate.
- Alpha decals use a separate preset so compression does not destroy their
  edges.

Because this repository ignores `*.import`, the policy must be reproducible,
not an editor-only click. Add a small pipeline step that patches/generated
Godot sidecars after the initial scan and before the final `--import`, then
validates the resulting options. The build command performs both imports on a
fresh clone. A local editor default is convenience only, never the contract.

Channel packing is deferred. Packing roughness into albedo alpha saves a
sampler but not reliably enough memory under block compression to justify
changing every StandardMaterial and alpha rule. Texture arrays/custom atlas
shaders are also rejected for this pass: they add shader permutations and mip
bleed while the measured frame problem is already draw-call bound.

## Implementation sequence

1. **Instrument first.** Add a report command for file count, texels, decoded
   estimate, exact duplicates, canonical resources, imported compression and
   mip status. Record current startup, working set, RenderingServer video
   memory (where supported), and the existing 1080p/1440p stations.
2. **Unify authority without changing appearance.** Generate MatLib data from
   the ingest manifest, canonicalize alias paths, add registry/scale tests,
   and prove renders are byte- or pixel-equivalent where no material was
   intentionally changed.
3. **Repair one stove.** Introduce `enamel_appliance`, render its warehouse
   specimen and 4B in situ under authored light/torch/streaming, and obtain
   approval before promoting it to the family.
4. **Repair one lavatory.** Do the same for `porcelain_fixture`; approve glaze,
   grain and mineral wear before all 66 plumbing markers inherit it.
5. **Split hand-scale jobs.** Add bookcloth, wood handle, soot deposit and
   hardware brass. Fix the bookshelf cache mutation. Verify the smallest
   owner of each key, not the largest.
6. **Apply import policy.** Enable compression/mips/normal handling, compare
   near and distant renders for banding, block artifacts and shimmer, then
   profile desktop and Android export.
7. **Collapse redundant maps.** Canonical aliases, shared variant
   normal/roughness, and shared wall-finish channels. Remove obsolete files
   only after a clean rebuild proves nothing references them.
8. **Promote and gate.** Run the complete pipeline, FULL WalkTest,
   LightingAudit, warehouse families and fixed current-floor screenshots.

## Automated gates

- Every runtime material key resolves to a generated set and existing files.
- Every key shared by Blender and MatLib has exactly one metres-per-tile.
- No deprecated ambiguous key remains at a call site.
- No shared cached material changes after any prop family is instantiated.
- Repeating 3D maps are VRAM compressed and mipped; normal maps carry the
  normal import flag.
- Albedo/normal/roughness dimensions obey their declared tier.
- Exact duplicate content has one canonical runtime path unless an explicit
  exception explains why not.
- Wall finishes own at most one unique albedo/mask each and no private normal
  or roughness plate.
- The pass does not increase visible material surfaces, draw calls, or shader
  variants at any benchmark station.

## Acceptance targets

- Enamel and porcelain read smooth and fired under a grazing torch; chips and
  crazing are local evidence, not full-surface sandpaper.
- Book spines show cloth at hand scale; walnut furniture retains broad grain.
- Baked and runtime examples of the same key match physical feature size.
- No repeating luminance grid is visible across a 3x3 tile view.
- Runtime texture count: **<= 600** initially, with no quality-critical map
  removed merely to hit the number.
- Runtime source payload: **<= 400 MiB**.
- Estimated compressed texture residency including mipmaps: **<= 400 MiB on
  desktop and <= 250 MiB in the Android tier**.
- No new 2048/4096 tileable building texture ships without a measured
  screen-space exception.
- Current CPU-bound frame stations do not regress by more than measurement
  noise; loading and texture-upload stalls improve measurably.

## Approval checkpoints

There are three visual approvals, each deliberately narrow:

1. one stove (`enamel_appliance`),
2. one lavatory (`porcelain_fixture`),
3. one sectional bookcase (`bookcloth` plus corrected cache ownership).

Only after those three survive warehouse and in-situ comparison should the
mechanical registry/import optimizations promote across the building.
