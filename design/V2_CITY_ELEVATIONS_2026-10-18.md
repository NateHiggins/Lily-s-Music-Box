# V2 city elevations, 2026-10-18

Evidence class: **INERT**. Construction and qualification record; no additional acceptance grant.

The city pass is installed and all five original qualification jobs pass against
the current source. Surface qualification passes 37,903 checks; service repair and
disk reconstruction pass 360; home access passes 909 across 62 rooms and nine legs;
upper access passes 989 across 69 rooms and 11 legs; the six-floor landing walk
passes 41 checks with one initial placement. All five packets are independently
validated with zero errors. Clean candidate aae34b06 passes the complete board
comparison with zero regressions, 14 improvements and all 17 protected paths
unchanged. The original verifier packet is archived under
**art/reviews/v2_city_elevations_20261018/verified/**. Publication is recorded in
**V2_CITY_ELEVATIONS_REPORT_2026-10-18.md**.

The old city conversion preserved repeated setbacks and heavy cornice bands while
omitting window elevations. The new **build_city_elevations.py** adapts 25 retained
building footprints into continuous main elevations with at most one upper setback.
The 31 former terrace steps become 14. Seventeen neighbouring blocks have window
stock on every elevation; eight distant blocks use closed mapped masonry on their
secondary outward elevations and concentrate detail on the principal city-facing walls.

The source has 2,984 built windows, 260 mm masonry reveals, recessed closed panes,
painted five-piece sash, projecting stone sills and lintels, and separate shade
backings at varied heights. Upper walls use existing custom running-bond brick or
limestone with authored building palettes; provisional base stone/concrete aliases
use catalogued limestone. Parapet bodies use masonry with retained coping faces.
Equal stock/tint combinations share local materials. No new texture images, baked
photographs, lettering, emission, gameplay actor or simulation authority are added.

Production mounts **city_elevations.glb** in place of **city_shells.glb**. The old
export and the editable **city_shells.blend** and **city_closure.blend** remain
required construction dependencies, and are not mounted alongside the replacement.
The protected generated layout, shop voids, base occupation reservations, final
roof planes and roof equipment authorities remain. Native charts and the validated
import policy preserve physical texture scale and normal/tangent frames.

The final native export contains 227 material partitions and 505,287 triangles.
Its builder checks every roof-bearing footprint and every recessed pane in the
actual native mesh before exporting. All 1,205 bearing samples and 2,984 pane
samples pass within 100 micrometres. These are source checks, not runtime proof.

The first composed city run is retained as a failed diagnostic: 80 pane probes
used source Y instead of source Z for their vertical offset, and two plate corners
of **site_ne4_guy1** lost support when the **site_ne4_c0** cornice band was retired.
A fitted local closed stone seat now carries the overhang without restoring the
full band or overlapping the adjoining terrace top. Original hardware and contact
targets are unchanged. Upper-window captures now require a real clear first-hit
sightline past the retained construction canopy.

The corrected original surface3 run measures 25,809 draws, 16,783 meshes, 6,126
materials and 497 loaded textures, with zero unresolved UV/PBR/mipmap surfaces.
It also passes all 400 elevation continuity rays, 1,205 complete roof-footprint
samples, 80 pane stations and three window-camera sightlines. Fourteen current
city/clearance/entrance frames were inspected and published with the unmodified
test-written contract, exact wrapper and byte-matched raw logs. Equal-finish caching
removes 207 material instances versus the first city run. Seven standing Texture
RID shutdown warnings remain; no new texture image is introduced.

The landing checkpoint's clean comparison exposed a stale front-trim discovery.
The original windowed **FrontTrimLayoutProbe.tscn** reproduced all 9,085 instances
exactly; only source provenance changed. That genuine renewed discovery is installed.
All surface/service/home/upper/landing proofs were then renewed by their original
tests. No previous runtime receipt was repinned. The clean checkout independently
matches the current production and surface input hashes.

Source and current render review records are under
**art/reviews/v2_city_elevations_20261018/**. Full V2 and human acceptance remain
incomplete. Finite distant ground/horizon continuity, atmospheric flattening,
repetitive stock, strong carried-light hotspots and simple artwork remain broader
appearance work. This scoped pass does not establish whole-city photoreal quality,
traffic safety, access to all shop interiors or a continuous whole-building shift.

The subsequent service-circulation repair is recorded separately in
**V2_SERVICE_CIRCULATION_2026-10-18.md**. It fits the missing F01 approach and
two riser bypasses, renews the native exterior masonry and proves the full
basement-to-roof-and-back route. All five broader original qualification jobs
are renewed again after that source change. The four rebuilt pavement/city
exports remain byte-identical, preserving this city appearance review.
