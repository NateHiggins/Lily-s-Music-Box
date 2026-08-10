# AUDIT 1 — HOW TEXTURES ACTUALLY LAND ON OBJECTS

*Run 2026-08-10 after ceiling commit `6f5d916`. Audit only: no material,
prop, ingest, or generated asset was changed.*

```text
METHOD AND CONTROL RESULTS

- Built output was regenerated before inspection. art/data and game/data
  building_layout.json SHA-256 both equal
  5F9B2AA50B1925C19D1C84E98BA050DCFD7CEE40FBE36005BB4E125CE92A3C18.
- `ingest_material_sources.py --check`: 74 assigned source slots, 0 contract
  problems. It also reports 141 unassigned source images; that is inventory,
  not evidence that any of them should be shipped.
- MatLib exposes 32 runtime sets. Static tracing found 29 literal material keys
  consumed by GDScript-built props/building details, plus the finite dynamic
  elevator keys. Every current consumer resolves to a MatLib set and every
  file named by those sets exists. FAILURE MODE 1 (a live prop falling back to
  flat colour because its key lacks a runtime set) has no current instance.
- Warehouse evidence: warehouse_bookshelf.png, warehouse_fridge.png,
  warehouse_stove.png, warehouse_sink.png, warehouse_toaster.png and
  warehouse_boxfan.png in art/renders/audit_texture_landing/.
- In-situ evidence: stand_-9.4_10.9_-7.3_0_-8.png in the same directory,
  rendered with SCREENSHOT_STREAMING=1, authored lights and the player torch.
  No ambient override was used.

RANKED FINDINGS

P0 | game/scripts/material_library.gd:18; art/tools/ingest_material_sources.py:82; game/scripts/props/stove_prop.gd:88; game/scripts/props/fridge_prop.gd:150 | `enamel` is not one material in the two build paths. Blender's catalog key comes from `neon_porcelain` at 0.60 m/tile, while runtime props load the old `T_library_appliances_aged_enamel_*` plate at 1.00 m/tile. The runtime source itself has a dense raised stipple; the current stove, monitor-top, medicine cabinet and plumbing enamel read like sprayed plaster/concrete rather than smooth vitreous porcelain enamel. The same key is also pressed into service as a kettle's mineral deposit. | This is on large, close-read domestic objects throughout the building. It breaks material identity, makes runtime and baked objects disagree by 1.67x before per-prop multipliers, and cannot be fixed honestly with one global scale number. | Split the jobs before changing scale: a smooth chipped `enamel_appliance` for ranges/fridges/cabinets, a fixture-specific porcelain-enamel key if needed, and a placed `mineral_scale` deposit for the kettle. Stage the selected plates through MatLib and GODOT_STAGE so Blender and runtime consume the same source and meters-per-tile. Render one stove first under the ceiling rule's one-example discipline. | HIGH

P0 | game/scripts/material_library.gd:93; art/tools/ingest_material_sources.py:115; game/scripts/props/tap_prop.gd:78 | `porcelain` projects at 0.90 m/tile in MatLib but its catalog recipe is 0.40 m/tile. TapProp's 0.72 multiplier makes the runtime coverage 0.648 m where the equivalent catalog coverage would be 0.288 m: a 2.25x disagreement. In the sink warehouse render the bowls are matte and granular; in the 4B kitchen the basin belongs visually to the stippled counter instead of reading as fired vitreous china. | All 24 lavatories, 19 kitchen sinks and 23 shower receptors use this family. It is the most repeated close-hand material after painted metal. | Point runtime porcelain at the same processed plate as the catalog and use 0.40 m/tile as the physical baseline. If the plate still carries plaster-like relief, replace the source rather than hiding it with scale; porcelain needs broad smooth glaze, sparse crazing/mineral wear, and local chips. Approve one lavatory in warehouse and in situ before promotion. | HIGH

P1 | game/scripts/material_library.gd:97; art/tools/ingest_material_sources.py:122; game/scripts/props/kettle_prop.gd:70; game/scripts/props/bookshelf_prop.gd:99 | `wood_dark` is 1.20 m/tile at runtime and 0.60 m/tile in the catalog. It also serves both furniture carcasses and the much smaller wooden kettle bail. The warehouse shelves tolerate the broad grain; a hand-scale bail cannot. | A 2x path-dependent scale means a runtime shelf cannot match a baked walnut object, and shrinking the global key enough for the handle would make the furniture grain noisy. | Align the furniture key/source to 0.60 m/tile, then give hand-scale turned or bent wood its own `wood_handle` key around 0.20–0.30 m/tile. Do not compensate with unrelated per-call multipliers whose meaning reverses at each call site. | HIGH

P1 | game/scripts/material_library.gd:36; art/tools/ingest_material_sources.py:152; game/scripts/props/flue_breast_prop.gd:48 | `soot` is staged from the 1.20 m/tile `charred_surface` recipe, then MatLib projects that same bitmap at 0.55 m/tile. The runtime flue halo/cracks therefore compress the source detail to 46% of its authored physical coverage while baked chimney soot uses the catalog scale. | The player is meant to infer one connected flue from repeated residue. Different grain size between the masonry-owned and prop-owned deposits makes that connection look like two unrelated effects. | Make 1.20 m/tile the shared source truth. Use an explicit scale multiplier or a separate placed-deposit material only where a small thimble needs finer residue. Verify one flue breast beside its baked chimney masonry. | HIGH

P1 | game/scripts/material_library.gd:56; art/tools/ingest_material_sources.py:84; game/scripts/building/railing_polish.gd:14; game/scripts/props/case_door_prop.gd:49 | Generic `brass` is 0.50 m/tile at runtime and 0.25 m/tile in the catalog, while serving both long stair hardware and a 56 mm door knob. `brass_dull` is a separate, internally consistent staged key, so the disagreement is isolated to generic brass. | The same named metal changes oxide/grain scale by 2x across authoring paths, and one baseline cannot describe both rail-length streaking and hand hardware. | Reserve `brass` for the 0.25 m catalog plate and create/use a hand-hardware key for knobs and tokens if a close render shows the catalog plate too coarse. Prefer the already-consistent `brass_dull` where its lower metallic response is the intended finish. | HIGH

P1 | game/scripts/props/bookshelf_prop.gd:239-247; game/scripts/material_library.gd:11; game/scripts/material_library.gd:154-181 | BookshelfProp calls `smat()` and then sets `vertex_color_use_as_albedo` directly on the returned cached linen and paper materials. It does not call `.duplicate()`. The cache key currently includes tint and scale, so no existing non-book caller shares these exact `(key, white, 2.0)` instances; there is no observed collateral today. | This violates the cache contract and makes a later caller silently inherit vertex-colour multiplication according to construction order. It is a latent whole-family mutation, not a theoretical style complaint. | Duplicate both returned materials before enabling vertex colour. Add a test that obtains the base cache entry before and after a bookshelf build and proves it is unchanged. | HIGH

P1 | game/scripts/material_library.gd:102; art/tools/ingest_material_sources.py:126; game/scripts/props/bookshelf_prop.gd:239 | `linen` is already 20% broader at runtime (0.60 versus 0.50 m/tile), then the bookshelf passes scale 2.0, producing a 1.20 m repeat across book covers only 20–37 mm wide. The books consequently read from vertex tint, not from cloth weave. The same key also dresses towels and laundry fabric. | This is FAILURE MODE 3: one key is doing upholstery/household linen and book cloth at incompatible scales. The hero books preserve colour variation but lose the material cue that makes them books rather than painted blocks. | Keep household linen at its reviewed scale and add a `bookcloth` key with hand-scale weave (roughly 0.10–0.18 m coverage, to be measured from the source). Preserve the one batched cover mesh and vertex colours; the new shared material must be duplicated before its vertex-colour flag is enabled. | HIGH

P2 | game/scripts/material_library.gd:17-121; art/tools/ingest_material_sources.py:82-149 | Seven additional shared keys drift between runtime and catalog physical scale: `appliance` 1.00/0.85, `bakelite` 0.35/0.30, `fabric_warm` 0.70/0.60, `linen` 0.60/0.50, `metal` 0.90/0.80, `plant` 0.50/0.40, and `trim` 1.20/1.10 m/tile. The drift ranges from 9% to 25%. | Individually these are less visible than enamel/porcelain, but they prove meters-per-tile has two authorities. Every new prop can be correct in one path and wrong in the other without any check failing. | Generate MatLib's physical scale from the same material metadata/catalog source used by Blender, or add a contract test that compares every overlapping key and requires an explicit documented exception. Do not manually reconcile seven numbers without removing the dual authority. | HIGH

P2 | game/scripts/material_library.gd:28; game/scripts/props/fridge_prop.gd:153 | `chrome` is correctly 0.80 m/tile in both registries, but that one plate lands on refrigerator trim and hand-scale latch/fastener parts. The monitor-top warehouse render shows the body texture clearly while the chrome hardware reads principally as a flat specular value; its directional brushing is below useful scale on the smallest pieces. | Registry equality does not prove object-scale fitness. Hardware that should catch the torch directionally loses its manufacturing cue. | Keep `chrome` for sheet/trim and introduce a finer `chrome_hardware` only for parts below roughly 50 mm after a close warehouse approval render proves the improvement. This is lower priority because the current silhouette and highlight still read as metal. | MEDIUM

NEGATIVE FINDINGS / THINGS NOT TO "FIX"

- `glassish` remains Blender-only by design. No runtime prop requests it.
- `linen` is intentionally absent from GODOT_STAGE because MatLib consumes the
  existing T_library_furniture_* files. Adding it to GODOT_STAGE would create
  dead competing files, not repair the scale authority problem.
- All staged close-read additions from the recent prop passes — cast_iron,
  brass_dull, nickel_plated, mirror_aged, mica_heater, rubber_aged,
  zinc_liner and copper_aged — resolve through valid runtime paths. Their
  base scales match the ingest recipes.
- No shared MatLib mutation was found in the exterior batch path:
  orison_detail_pass.gd:307 duplicates before enabling vertex colour.
```
