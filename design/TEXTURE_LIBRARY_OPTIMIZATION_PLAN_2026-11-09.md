# Texture library optimization plan

Evidence class: **INERT**. This is a plan, not a receipt. It changes no texture,
material or runtime behaviour, and it proves nothing about any requirement.

Owner request, 2026-11-09: optimize the texture library, remove deprecated
textures, compress, and standardize on one material library.

The plan takes over the unfinished parts of
`design/TEXTURE_REPAIR_AND_PERFORMANCE_PLAN.md` (2026-08-10). That plan's import
policy has mostly landed. Its single material contract never did, and the library
has roughly quadrupled since then.

RUL-007, RUL-008 and RUL-012 apply throughout. Nothing here relaxes the V2 surface
requirements. Every step is verified by rendering, not by reading code.

## 1. Where we are (measured on main fab23c9e3, 2026-11-09)

The audit script, its full output and the list of candidates are in
`C:/ov/reports/texture_audit_20261109/`. They are outside the repo.

**Size.** There are 2,414 shipped image files: 1,546 MB as source files, which
grow to **3,296 MB once Godot has imported them**.

- Textures are about 73% of the estimated 4.5 GB Windows build. The remainder
  is mostly 1.0 GB of meshes from imported `.glb` files.
- `assets/building/textures` is 1,434 files and **2,819 MB** imported.
- In that folder, albedo is 890 MB, normal 889 MB, roughness 601 MB, and other
  maps 434 MB.
- Models embed only 67 images (22 MB). Almost every surface binds a loose
  library texture at runtime.

**Compression.**

- 1,510 files are VRAM-compressed with mipmaps (BPTC/S3TC). That is correct for
  3D surfaces.
- 717 files are lossless without mipmaps. These are mostly UI and newspaper art,
  which is correct.
- **138 files are lossless with mipmaps, 210 MB.** 127 of them are dream
  surfaces. These are 3D surfaces stored at about 4x the size BPTC would need.
- All 410 normal maps have Godot's normal-map compression switched off, so they
  are stored as ordinary BPTC colour. Switching them to RGTC costs nothing in
  size and keeps more detail, but only shaders that sample with `hint_normal`
  can read it. Each shader must be checked first.
- **321 of the 421 roughness maps are stored as full RGB.** A roughness map
  carries one channel of information, but each of these costs as much as an
  albedo.

**Resolution.**

- 1,162 textures are not a power of two. The common sizes are 972, 781 and
  1254. Their mip chains end in uneven, filtered steps, and the extra sizes
  create cache variety.
- 19 textures are larger than 2048 px.
  - The worst is one character skin: **8192×8192, 85 MB imported**, for a figure
    seen at room distance.
  - The 4K sky domes stay lossless, at about 100 MB together.

**Duplicates.** There are **97 groups of byte-identical files, with 113 extra
copies costing 255 MB imported.**

- Most are book-cover normal and roughness maps copied once per colour.
- Library materials have twin copies under different prefixes.
- A soffit map exists twice, once named "failed" and once named "test".

**Deprecation is not provable statically.**

| How the texture is reached | Files | Imported |
|---|---|---|
| A `res://` path or UID appears in a scene, resource, script or data file | 980 | 755 MB |
| Only the file's stem appears, so paths are built at runtime (MatLib, wall finishes) | 1,128 | 1,977 MB |
| Only its folder is referenced | 246 | 554 MB |
| No reference at all (41 sit in `.gdignore` folders and never ship; the rest are previews, sky source pieces and one ephemera sheet) | 60 | 10 MB |

Of the 1,434 building textures, only 373 (940 MB) are named by the generated
MatLib `SETS`. The other 1,061 (1,879 MB) are reached some other way, or not at
all. Only a load trace can tell those apart.

**Material authority is split eight ways.**

- `art/data/material_catalog.json` has 190 keys. `game/data/material_catalog.json`
  has 108 keys and has fallen 82 keys behind it.
- `art/textures/catalog_mapping.json` has 334 entries, and the generated
  `material_sets.gd` has 129 `SETS`.
- The V2 JSON recipes are separate again: `surface_stock`,
  `owner_finish_profiles`, `ground_finish`, `service_alley_finish` and
  `bar_ceiling_finish`.
- Models use **229 distinct material names. Only 44 of them are catalogue keys.**
  Case variants also exist (`Iron`/`iron`, `Brass`/`brass`, `Steel`/`metal`).
- There are 145 calls to `StandardMaterial3D.new()` across 67 scripts, and 99
  shaders.

## 2. Target: one material registry

There will be **one registry**: one record per material id. Every other table
becomes either generated from it or retired. Each record holds:

- id, substance and provenance (RUL-007)
- status: `live` or `retired`
- shader recipe: `standard`, `orison_surface`, or a named optical recipe such as
  clear glass
- map set: albedo, normal, packed ORM or roughness, and optional
  emission/height/mask
- physical tile size in metres, normal strength, and metallic/roughness scalars
- alpha policy
- import tier (see section 3)
- variant parents: book colours and resident tints become a parent and a tint,
  not new texture sets

Generated from the registry:

- the runtime set table, replacing both `material_sets.gd` and the game
  catalogue copy
- Blender's `catalog_mapping.json`
- the `.import` presets for each tier

Hand-written exceptions may change optics only. They may not give a second
scale or a second file name. This is the 08-10 rule, now enforced.

Rules for everything else:

- **Model material names must be registry ids.** The Blender export checks this
  and fails on an unknown name. The 185 current non-matching names are mapped
  once, in a single alias table that only shrinks.
- **Scripts ask MatLib for materials.** A `StandardMaterial3D.new()` call stays
  only where it builds state or optics: emission tied to a mechanism, liquids,
  glass, or debug output. Each one left gets a one-line reason that the gate
  reads.
- The V2 JSON recipes keep their placement and assembly data. Their finish
  values move to registry ids.

## 3. Import tiers

These are the only tiers. The registry assigns one to every texture.

| Tier | Use | Settings |
|---|---|---|
| `surface` | albedo and ORM on 3D surfaces | VRAM compressed (BPTC desktop, ASTC Android), mipmaps, size limit 1024 (2048 only when registered) |
| `surface_normal` | normal maps | VRAM, mipmaps, same limit as its albedo; RGTC only for shaders that sample with `hint_normal` |
| `hero` | faces, the moon, close character skins | VRAM, mipmaps, limit 2048 |
| `sky` | sky domes and panoramas | VRAM high quality (BPTC), mipmaps off; lossless only if the banding test fails |
| `ui` | UI, newspaper, book plates, comic | lossless, no mipmaps, size limit at display size |
| `data` | lookup tables, weather fields, masks read as data | lossless, linear, no sRGB |

All sizes are powers of two. Roughness, metallic and AO pack into one ORM map,
or roughness goes into a single-channel map at half the albedo's size. Section 6
asks Lily which.

## 4. Phases

Each phase lands as its own small PR with a board baseline and a render
comparison. Each phase is reversible on its own.

**Phase 0: instrument (no content change).**

1. Commit the audit as `tools/audit_textures.py`. It writes sizes, tiers,
   duplicates, references and registry coverage to a `board.json` section.
2. Add a **load trace**: a runtime flag that logs every texture
   `ResourceLoader` hands out.
3. Collect the trace from:
   - the FULL V2 walk
   - the vertical and street routes
   - the city walk
   - the dream suite
4. Sort every texture into `v2_live`, `dream`, `ui` or `never_loaded`. A texture that only V1 code names counts as `never_loaded`.

That sort is the only acceptable evidence that a texture is deprecated.

**Phase 1: free wins (no visual change expected).**

- Fold the 113 exact duplicates into one file per group. References are
  rewritten, and the registry gains aliases. This saves **about 255 MB**.
- Move the 127 dream and 11 other lossless-with-mipmaps 3D textures to the
  `surface` tier. This saves **about 150 MB**.
- Delete the soffit "failed" and "test" maps and the other obvious scratch files,
  after the trace confirms they are never loaded.

**Phase 2: right-size.**

- Re-export the 8K character skin at 2K, and audit the rest of `characters/`
  the same way. This saves **about 80 MB**.
- Resample non-power-of-two maps to the nearest power of two (972/781 to 1024 or
  512, 1254 to 1024), regenerating from the source plate rather than
  resampling the derived file.
- Pack AO, roughness and metal into one ORM map per material (ruling
  `tex_roughness`). This saves **about 450–600 MB**.
- Test the sky domes for banding at BPTC; keep the lossless copy only where it
  bands. This saves up to **about 70 MB**.

**Phase 3: retire.**

- Textures traced as `never_loaded` on every route move to
  `C:/ov/holding/retired_textures` with a manifest, and are then removed from git
  (ruling `tex_retired`).
- Textures that only V1 code names go with the V1 retirement (ruling
  `tex_v1_textures`).

**Phase 4: unify.**

1. Build the registry from the two catalogues, the mapping and `SETS`, then
   generate the outputs and prove them byte-identical to today's (round trip).
2. Then map the 185 non-catalogue model material names through the alias table.
3. Migrate the scripts in batches, by room or system, following
   `art/blender/v2_batch_workflow.md`.
4. Book colours and resident tints become variants of one parent. That removes
   most of the 155 `library_*` texture sets.

**Phase 5: gate.**

Add a tools test to the gate board that fails new work on any of these:

- an unregistered texture or material
- an import that does not match its tier
- a non-power-of-two surface map
- a duplicate file
- a surface map over its tier's limit
- a model material name that is not a registry id

Existing debt is baselined so that main is not turned red. The reader gate
(`audit_data_consumption.py --baseline`) covers the registry's new fields.

## 5. Expected result

| | Now | After phases 1–3 |
|---|---|---|
| Imported textures | 3.3 GB | about 1.5–2.0 GB (depends on the trace) |
| Windows build | ~4.5 GB | ~2.7–3.2 GB |
| Material authorities | 8 tables + 145 inline materials | 1 registry + generated outputs + named exceptions |

Bigger gains in VRAM residency follow from ORM packing and the 1024 surface cap.
These matter more on Android and smaller GPUs than on disk.

The frame is still bound by draw calls, so none of this is sold as a frame-rate
cure.

Meshes are the other 1.0 GB of the build: they could be compressed and their
LODs pruned. That is outside this plan and belongs in its own.

## 6. Lily's rulings (2026-11-09, answered in Omni)

1. **`tex_v1_textures`: "Retire V1 entirely and remove its textures."** This
   overrides the 2026-09-21 direction to keep the explicit
   `ORISON_BUILDING_ROOT=v1` rollback, and the selector protection in RUL-004.
   - Retiring V1 is bigger than textures. It covers the selector, the V1
     building generator, the scenes and tests, and the 17-path protected receipt.
   - So it gets its own plan and a RULINGS.json entry that supersedes the rollback
     clause, before any V1 file moves.
   - For this plan, the load trace drops the V1 rollback walk. Textures that only
     V1 loads are retired with the V1 code, not kept.
2. **`tex_roughness`: pack AO, roughness and metal into one ORM map per
   material.**
   - Phase 2 builds the ORM channel packing into the registry generator: AO in R,
     roughness in G, metal in B, linear.
   - Materials set `roughness_texture_channel` and `metallic_texture_channel`
     against the one map. The Orison surface shader samples the same map.
   - Uniform metal stays a scalar, as RUL-012 allows. The channel stays white or
     black.
3. **`tex_retired`: move them to `C:/ov/holding/retired_textures` with a
   manifest, then remove them from git.**
   - Phase 3 copies each retired texture there with its `.import`.
   - The manifest records path, SHA-256, size and the load-trace evidence.
   - The phase verifies the copy byte for byte before `git rm`.

A fourth ruling filed with this plan, `public_2d_art_source`, is handled
separately: the folder is untracked in its own PR, with a copy kept outside the
repo.

## 7. Measured corrections (2026-11-09, after phases 0–2)

The phase 0 trace and the first two phases measured what the section 4 and 5
estimates had guessed. Several were wrong. Where this section and an earlier one
disagree, this section stands.

- **V2 loads its whole texture set at startup.** All 19 V2 and city routes load
  the same 749 textures (1,571 MB imported). Cell streaming changes nothing
  about texture residency. Work order w6eebc7c1c94b covers that.
- **Phase 1 is about 86 MB, not 400 MB.**
  - The 126 dream maps that are lossless with mipmaps are packed substance data
    under a tested residency ceiling (`dream_incarnation_plate_test`). They are
    the `data` tier, not a mistake.
  - The city prop and piano-truck maps are not tracked files. Godot extracts
    them from the `.glb`, and git ignores them, so their compression, and about
    20 duplicate groups, can only change in the model export.
- **Pins are narrower than they looked.** The September whole-tree evidence
  snapshots under `design/astra/evidence` are history, not live checks.
  - Tests and tools pin 263 textures.
  - The generated tables are pinned by many more fixtures:
    `runtime_material_sets.json` by 106, `material_sets.gd` by 69, the art
    catalogue by 58, the mapping by 53 and the generator by 51.
  - Phase 2 removed 18 more duplicates and capped Evelyn's unused 8K model skin,
    about 130 MB. V2 overrides every resident's model material, so that skin is
    never drawn.
- **ORM packing saves nothing at full size.** The library has no metallic maps
  and one AO map. Roughness maps are already stored at the smallest compressed
  size per pixel.
  - An ORM map at the albedo's size costs the same as today's roughness map.
  - The 593 MB of roughness shrinks only if the packed map is smaller than the
    albedo. Half size saves about 440 MB.
  - The resolution is filed as ruling `tex_orm_resolution_20261109`.
- **The generator already shares byte-identical images** between material
  sets (`generate_runtime_materials.py`, by channel). The duplicates left after
  phase 2 are reached through other routes: V2 recipe JSON, extracted model
  textures, and aliases.
- **One registry pass** (ruling `tex_registry_pass_20261109`, answered "go for
  it" in chat).
  1. The registry is introduced first. It regenerates today's catalogues and
     mapping byte for byte, so no fixture changes.
  2. The ORM change, the remaining folds and the renewal of the pinned fixtures
     then land together as the one pass.

| | Before | After phases 0–2 | If ORM goes to half size |
|---|---|---|---|
| Imported textures | 3,310 MB | about 3,090 MB | about 2,650 MB |
| Retiring V1 textures (ruled) | | | a further 790 MB |
