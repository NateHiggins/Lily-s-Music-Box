# Exposed room-floor slab undersides

Evidence class: **INERT**

Support discovery below the north-wing radiators and ground-floor west branch
found rendered room slabs open underneath where no lower-room ceiling exists.
The already published landing repair cannot cover these separate source owners.
This extension restores exposed room-slab faces while retaining every original
walking surface, body, aperture and material.

## Ownership, geometry and mapping

**orison_v2_platform_soffits.gd** now also builds room-floor underside footprints.
The source floor openings are subtracted first. Existing lower ceilings and the
accepted platform footprints retain priority; earlier source room-floor owners
then retain priority over overlapping room footprints. **54** room floor draws
need an additional underside material partition. The remaining floors already
have another underside owner or no exposed footprint.

The original top/side arrays and single or compound slab bodies remain. The
new surface uses the existing **trim** ceiling recipe with metre-scale planar
UVs, downward normals and orthogonal rightward tangents. No native prop, new
material key or bitmap is added. The helper applies only to production geometry;
the standalone review blockout retains its original boxes.

## Construction observations and limits

**tmp/heat-distribution/room-soffits-4.log.receipt.json** completes with **2,881**
checks and zero failures: the retained **585** landing stations plus **468**
stations over all new room-slab triangles, complete mapping/material arrays and
the original physical owners. Source opening and preceding-owner subtraction
leave one horizontal rendered owner at each sampled new surface.

The first two runs reported three roof first-hit differences. They identify
retained **ExteriorMasonry** at **18.995 m**, **5 mm** below the roof slab's
**19.000 m** underside. The named slab bodies independently meet their faces
within **0.1 mm**. The test retains the three foreground observations and queries
the slab body separately by excluding other bodies from that query only. It
changes no production mask or body and grants no obstacle-clearance/walk claim.
Landing probes continue to use their original whole-world first-hit check.
The earlier failed receipts are retained, not counted as passing proof.

Production-windowed views use the retained lamp with no global lighting change.
The first two additional cameras filled their frames with the surface and do
not show its perimeter; revised cameras inspect the north and west edges.
The focused test verifies the actual active underside materials on all **64**
changed landings and **54** changed room slabs. The revised north and west frames
show their perimeters and were directly inspected. Final bound candidate frames
remain required. Warm lamp response and finish refinement remain in the open
polish queue.

Observed focused startup was **21.36 s** while a four-thread Blender trial ran,
versus **19.83 s** and **19.49 s** in earlier room-slab trials. These single-run
observations, including the concurrent CPU load, are not a performance acceptance
claim. The additional **54** partitions and their culling bounds are recorded.
No runtime-contract or completeness promotion follows from these static probes.
Full comparison against the genuine **47**-gate clean **fc3b90d** board and
binding route/ventilation/service/key regressions are required before push.

Heating's physical routes, fitted sleeves, supports, expansion and chase access
remain open. Temporary native pipe trials stay under **tmp/heat-distribution/**;
their failed conditioning attempts are not installed assets or acceptance.
The protected paths, V1 rollback and the owner's six capture-file decisions are
preserved. The six location phases remain open.
