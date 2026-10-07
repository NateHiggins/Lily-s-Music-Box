# Original Diner register and cigar display

Evidence class: **INERT**

The two original **storm_shop_luncheonette_register** and
**storm_shop_luncheonette_cigar_case** records retain their plan envelopes
and upper datums (**1.55m / 1.47m**). Four register feet and four display
posts fill the former **0.01m** gap onto the actual fitted **1.12m** serving
sheet. Hidden source reference boxes preserve the original poses.

The passive plated register faces the clerk's positive-X side. A joined
hollow drawer carcass, sloped key bed, 27 unlettered Bakelite heads with
brass stems, raised case, five blank mechanical indicator stocks and a
drawer handle replace the original solid box. The handle stays within the
source envelope. There is no payment or till-operation authority.

The cigar display has four closed **4mm** panes and a **4mm** lid inside
its original envelope, joined timber posts/floor and brass upper/lower
frames. Its chamber stays empty. Original glass tint, shipping maps and
culling remain; local plain-alpha blending is declared. No opening,
inventory, tobacco sale or invented stock.

Build with **art/blender/scripts/build_diner_till.py**. The editable native
source, construction JSON, fixture and generated GLB bind two assemblies,
**96** closed positive connected stocks, **seven** partitions, **16,992**
triangles and **eight** actual countertop contacts. Physical metre charts,
UV derivative tangents and existing catalogue finishes reach the imported
mesh. No shared material change, new material key or generated lettering.

Inspect with **art/blender/scripts/inspect_diner_till.py**. The inspection
explicitly updates loaded native transforms before testing all **43**
accepted partitions from eight stools, both receivers, counter and ledger.
Temporary context retirement covers **22** exact original boundaries
(**264** triangles) and nine exact old receiving owners (**836** triangles).
All other original context remains conservative. Actual stock and owner
rays prove all eight seats; no unintended native/context intersection.
An additional counter recheck with updated transforms also passes **38**
accepted partitions and eight contacts, without changing its geometry.

All **nine** isolated native frames and **six** composed focused frames
were directly reviewed. **OrisonV2DinerTillTest** passes **143** checks for
source retention, imported maps/collision faces, support, thin inner/outer
glazing, empty display/drawer chambers and the unchanged register maximum.
All six requested standing observation stations are clear. These samples
do not prove continuous service routes. Full committed verification is recorded below.

The initial native diagnostic assumed coplanar BVH pairs must exist;
the actual owner-ray check then exposed stale linked-object transforms.
Explicit dependency-graph updating fixes the inspection. Exact failed logs
remain diagnostic evidence. Existing strong lamp glare remains a separate
optical concern. Diner back bar/urns/shelves, pie case, griddle, fountain/
pumps, mixer, menu and fan still need fitting. Food/drink operation,
utilities, continuous routes and human acceptance remain open.

Committed source **ff21d436** passes the complete **48-gate/tools-test** comparison
and **nine** bound Godot runs with zero regressions. All **nine** native,
**six** focused and **70** final production frames were directly reviewed.
The exact source, actual observations, reconstruction, receivers, counter
and separate full key authority are retained in
**art/renders/orison_v2/diner_till_20261006**; report:
**design/V2_DINER_TILL_2026-10-06.md**. V2 remains incomplete.

Import-provenance correction: Godot normalized the import UID after initial
native review. The bounded builder refresh regenerates both source-bound
fixtures without changing the Till blend, GLB or runtime JSON. Fresh native
checks and all nine renders pass; candidate **7397ba6b** reruns Till
and the complete Diner/residency/key matrix. See
**design/V2_DINER_BACKBAR_2026-10-06.md** and its byte-bound packet.
