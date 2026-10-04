# Honed stair marble

Evidence class: **INERT**

The existing catalogue families **stair**, **stair_b** and **stair_c** now use
quiet honed marble pigment. The former source baked repeated nosing wear and
dirt bands into the tile, so the same stripes appeared across half-landings.
The delivered finish removes those stripes while keeping the existing 1.2-metre
chart and approximately the same mean colour. Stair geometry, guard bodies,
stringers, supports and player collision remain their original owners.

## Source and rebuild

**art/textures/ai_sources/stair_marble_honed.png** is a 1254-square RGB source
generated with the built-in ImageGen tool on 2026-10-04. It contains pigment,
with no lettering, baked edges or reference photograph. The old
**stair_marble_worn.png** remains as historical source art. No new catalogue
key or global runtime material-table entry was introduced.
The raw source SHA-256 is
**d437ba9d55ea430c96e0de347881810e2297f413c0c78a93664301308ec85735**.

The generation prompt was:

> Use case: photorealistic-natural. Asset type: a single production PBR
> base-color source plate for aged honed white marble on the stairs of a 1927
> apartment building. Create a SQUARE seamless texture swatch seen perfectly
> orthographically, filling the entire image edge to edge. The swatch covers
> exactly 1.2 metres square. Natural chalk-white to pale warm-grey calcite with
> a few irregular fine cool-grey mineral wisps and faint diffuse cloudy
> inclusions, flowing loosely on a diagonal, with varied forked branching that
> reads as genuine stone. Restrained colour contrast; most of the surface
> remains calm. Very fine visible crystalline grain. Subtle age within the
> material, no dirt edge. This is flat base colour under perfectly even diffuse
> scan illumination: no highlights, cast shadows, ambient occlusion, bevel,
> perspective, rounded edges, rim, objects, cracks, chips, stair treads, grout,
> panels, borders, text, numbers, letters, logos, watermarks, reflective room,
> or repeating regular contour loops. Seamless all four edges. Photoreal
> material structure, not an illustration, contour map or synthetic noise. Do
> not include any stair shape or nosing wear band; those belong to geometry and
> local wear masks.

Rebuild the three existing families with:

    python art/tools/ingest_material_sources.py --slot stair_marble_honed
    python art/tools/ship_surface_tables.py --key stair --key stair_b --key stair_c
    python art/tools/ingest_material_sources.py --check

For the arcade cell manifest, the **stair_b** family is the only changed
marble input it references. After a reviewed material change, use
**art/tools/rebind_catalog_textures.py --base &lt;reviewed-before-commit&gt;
--key stair_b --write** to refresh its three existing texture hash/size pins
and the registry's manifest pin. The tool validates every retained cell and
protected input, refuses unrelated texture drift, and preserves resource paths,
lineage and all geometry. It does not replace an export or establish runtime
proof. The new regression test's two asset paths were appended to the spatial
dependency manifest; all earlier records remain.

The ingest flattens illumination and blends tile boundaries. Independent,
periodic microrelief spans **0.16 mm**; its tangent normal derives from the
same height field in metres. Mineral pigment does not carve trenches. Roughness
is authored separately around **0.448**. Normal, roughness and height maps are
512-square. Base albedo is 1024-square; the two synthesized family albedos are
972-square. The shipper preserves physical height pixels and units instead of
stretching them again. The owner's existing **2.5** runtime relief factor remains.
Scoped shipping retains the complete calibration table and avoids rewriting
unrelated height plates or wall masks.

The semantic stair factory now supplies a stable named copy of the stair
catalogue material to SurfacePass. Previously its unnamed prop-library input
did not bind height calibration. The shared MatLib resource is not mutated.
Other semantic material identities are outside this bounded change.

## Inspection

Six Blender source-map comparisons use identical metre charts and external
lighting, with immutable before maps extracted from **98ba522f**. Twelve game
captures compare the old delivered maps with the new production material at
three source-owned half-landings and flights. The actual game environment and
lamp remain unchanged; the carrier capture toggle hides the handheld device.
The review checks **294** real architectural surfaces, physical calibration,
mesh-owner preservation and clear capsule stations: **608 checks, zero failures**.
These stationary captures do not prove walking routes.

Local records are under **tmp/material-review/native-production** and
**tmp/material-review/honed-production3**. The first two capture attempts have
separate timed-out receipts after scratch-fixture errors; neither supplies a
verdict. **HonedStairMaterialTest** checks active height binding on the real
294-surface stair population and preserves the cache/shared-material contract.
The Python **test_honed_stone_maps** suite checks pigment independence, physical
normal scale and byte-preserving height shipping. Wrapper receipts and this
note remain INERT and confer no completeness-ledger promotion.

The independent plaster and concrete studies remain scratch alternatives.
Their present appearance is too flat to replace production finishes. An
unrelated old face-brick-family height plate was observed to differ from a full
shipper regeneration; it remains untouched pending a separate material review.
