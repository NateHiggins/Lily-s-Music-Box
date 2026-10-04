# Roof falls, weather interfaces and independent property drainage

Evidence class: **INERT**

Classification: **ADAPTATION**. This record describes source construction and
bounded inspections. It does not establish drainage capacity, live water flow,
whole-building weather acceptance or a completeness-ledger promotion.

## Current construction

The original 200 mm structural slab, seven roof floor bodies, four parapet
owners, two moving doors, stair platforms, tank, four fans and 23 register
emitters retain their identity. The field rises above the 19.2 m structural
datum with a 6 mm toe, 4 mm finish and physical 1% falls along each authored
route coordinate. Affine pieces meet on the actual drainage divides. The full
fan curbs and tank-post boxes remain reserved. The visible roll finish contains
570 closed source stocks, 73 bounded partitions and 23,348 native triangles
over 635.3191 square metres. Buried contact faces remain in the editable source.

The public and service door curbs finish at 19.35855 and 19.32495 m. Original
1.1 m by 2.13 m leaves retain their live 100-degree motion. Their anchors rise
with the curbs; the fitted head and threshold remain under their original
fabric owners. The original AnimatableBody temporarily suspends synchronization
while its startup parent pose is fitted, then resumes normal door motion.
Moving rubber blades and sheet returns follow that body; fixed pan parts follow
the original fixed ironmongery. No duplicate door or lock authority is added.

Eight 240 by 120 mm open scuppers have 1.2 mm galvanized sheets and supported
405 mm beds, with 220 mm projecting cantilevers and 1% outfall. Their parapet
notches preserve the original wall bounds and top. Eight 152.4 mm bore leaders
have 56 measured facade supports: 784 closed source pieces and 120 bounded
partitions. The northern offset follows the retained recessed facade.

The 1.2 mm folded base flashing follows the actual field creases, preserves the
full door and scupper apertures, and has 470 closed pieces, 57 partitions and
5,972 triangles. It omits only shared fabric/contact faces at runtime. Only
physical crease edges split stocks; coplanar sampling edges no longer produce
degenerate dust faces. Scupper and Boolean wall polygons are triangulated
before native save and tangent export. All ten roof families retain metre UVs,
unit normals and tangent direction/handedness at actual imported precision.

The two retained bulkhead weather covers keep their original upper geometry,
gutters, outlets and wall plates. Their leader toes now sit 25 mm above fitted
flashing feet: public 19.3689 m above foot 19.3439 m; service 19.2739 m above
foot 19.2489 m. The source builder trims gutters from the immutable retained
native snapshot rather than trimming its own preceding output on each rebuild.

The separate property collector has 304.8 mm bore mains with 0.5% fall,
152.4 mm bore branches with 1% fall, eight receivers, two cleanouts, 58 main
saddles and 106 qualified soil reservations. Its 192 closed native stocks
produce 95 bounded partitions. A bolted blank at the known property boundary
ends the authored route; an unknown street main and live connection are not
invented. The existing alley collector, well and all foundations stay put.

Ten bounded, authored piecewise grade patches fit receiver and cleanout faces
to the original paving. The east cleanout retains its actual grade crease.
Provider cutouts and bed bottoms follow those patches. The 32 original front
paving masks and all classified city-ground masks remain unchanged. Only two
new front ports and four alley ports are added. The retained-grade reconciliation
updates verified front-provider hash bindings; foundation native geometry and
the original soil envelope remain unchanged. The soil is a conforming closed
union of its occupied cells, including split contacts, rather than disconnected
boxes with buried duplicate faces.

## Rebuild and independent inspection

All recipes are portable files in **art/blender/scripts**. Start with
**prepare_roof_drainage_grade.py**, then build falls, ports and leaders.
**prepare_roof_drainage_receivers.py** derives routes from those bound sources;
build receivers and export their reservations. Build base flashings, membrane,
plant weather, door weather and both retained bulkhead covers. Rebuild front
paving and alley groundworks, export the retained alley reservations, run
**reconcile_roof_drainage_ground_source.py**, then rebuild the city ground.
The ground compression step uses the bundled Node runtime through
**BLEND_ZSTD_NODE**. Hash-bound text is LF-normalized and marked **-text**;
binary native/GLB hashes use exact bytes. Generated glTF is never hand-edited.

The eleven independent **inspect_roof_drainage_*.py** readers reopen saved
native files and inspect stock closure, positive volume, bores, airways,
contacts, thickness, unchanged upper fabric and retained clearances. Diagnostic
context, cameras and lighting are not saved back. **inspect_orison_ground.py**
integrates the saved conforming triangles independently and compares them with
the occupied-cell volume, then checks retained foundation contacts.

Current native reports and renders are under **tmp/roof-drainage-review**.
Installed test receipts and captures are under **tmp/roof-drain-discovery**.
Wrapper receipts prove execution, not a schema-2 runtime contract. Direct
render review establishes this batch's local form and fit; the broader material,
sky, shop-services and architectural work remains open. Heating cuts stay parked
until the broader external shell is ready.
