# Roof slab edge and parapet bearing

Evidence class: **INERT**

The shell-readiness survey found the roof slab stopped at the room footprint,
280 mm inside the outer masonry face. The retained 250 mm parapet extended
125 mm outside that slab edge. Twelve actual physics rays reproduced the
recessed slab-height band. This is a construction interface correction, not
whole-shell acceptance or a structural-capacity calculation.

**scripts/build_roof_edge_support.py** derives four 200 mm-deep rim strips from
the existing **roof_source.json** deck bounds and V2 wall/slab dimensions. The
inner edge meets the original deck footprint; the outer edge follows the
retained masonry reach. Decks, parapets, coping, plant and service apertures
retain their source positions and owners. No occupied space is added.

**roof_edge_support.blend/glb** retain editable native geometry and 28 bounded
export pieces, 240 triangles. No end caps are added at culling divisions.
**roof_edge_support_construction.json** records the exact source bounds.
Active metre UVs, normals, tangents and the existing concrete material are
checked after full-precision Godot import. No material or lighting pipeline
extension is introduced. Coarse concrete variation remains a finish issue.

The focused production inspection reports **466 checks**, twelve rim contacts,
twelve parapet-base bearings and twelve reproduced before-state rays, with
zero failures. Existing deck and new rim footprints have zero area overlap.
The three final views in **tmp/shell-readiness/rim-inspection1** were directly
inspected. Its wrapper receipt is **rim-inspection1.log.receipt.json**. Normal
roof/vertical routes and clean-baseline candidate verification remain required
before publication. These probes make no runtime-contract or ledger claim.

The wider readiness discovery samples 1,030 original masonry wall-base stations.
747 have all three upward-surface contacts at the sampled datum; 283 have an
incomplete contact. Those are preliminary findings requiring source and rendered
inspection. Lintels are omitted, and the method does not resolve slab embedment,
intentional bridges, geology or structural capacity. Foundations, setbacks and
remaining room/exterior interfaces remain open. Heating cutouts are parked
until the affected shell is settled; see **heating_distribution.md**.

Initial generator tangent-hook and survey capture-call errors are retained in
**tmp/shell-readiness**. Their failed runs are not acceptance evidence. This
batch must pass its exact committed candidate check before being published.
