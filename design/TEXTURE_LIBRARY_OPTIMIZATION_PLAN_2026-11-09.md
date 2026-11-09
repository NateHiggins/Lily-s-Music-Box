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
- status: `live`, `v1_only` or `retired`
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
   - one V1 rollback walk (`ORISON_BUILDING_ROOT=v1`)
4. Sort every texture into `v2_live`, `v1_only`, `dream`, `ui` or `never_loaded`.

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
- Decide roughness packing (section 6). This saves **about 450–600 MB**.
- Test the sky domes for banding at BPTC; keep the lossless copy only where it
  bands. This saves up to **about 70 MB**.

**Phase 3: retire.**

- Textures traced as `never_loaded` in every route move out of `game/` to a
  holding folder outside the repo, with a manifest. They are not deleted; git
  history keeps them anyway.
- `v1_only` textures stay until Lily rules on the V1 rollback (section 6).

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

## 6. Decisions for Lily (filed as rulings)

1. **V1 rollback textures.** Textures only V1 uses can either keep shipping, or
   be left out of the V2 export while staying in the repo so the explicit
   `ORISON_BUILDING_ROOT=v1` rollback still works from source.
2. **Roughness storage.** Pack AO, roughness and metal into one ORM map (one
   texture per material instead of up to three). The alternative is a
   single-channel roughness map at half resolution, a smaller change.
3. **Retired textures.** Move them to a holding folder outside the repo with a
   manifest, or simply remove them from git, since history keeps them.
