# Ventilation wall, chase and masonry seats

Evidence class: **INERT**

REPORT - ORISON VENTILATION FABRIC - 2026-10-01

This construction report records a bounded geometry batch. It grants no
completeness-ledger, airflow, pressure or complete infrastructure acceptance.
The six location queues and other utility networks remain open.

## Source and ownership

The published slab batch **8eb96c7faa1c2d5e112e5871fe48181c6acd5166** left
**118** sampled route/structural-owner triangle intersections, **48** affected
draws and **399** first physics hits. Floors and ceilings were clear in its
150 mm sampled volume. Actual room walls, the west chase and the outer masonry
still occupied the ducts. This batch resolves those structural crossings while
retaining the four motors, 23 passive grilles, source route, duct collision
owners, roof height and existing gameplay/maintenance authority.

**art/data/orison_v2/ventilation_fabric_source.json** owns **67** bounded room
wall openings, **15** west-chase openings and **26** outer-leaf opening volumes.
**tools/build_v2_ventilation_fabric.py** projects only those tables into the
existing blockout. It preserves other owners' records and commutes with the
roof and domestic/service projectors. Its three tools tests exercise ownership,
idempotence, round-trip preservation and rejection of foreign/duplicate records.

Each room opening names its space and side. The blockout validates its bounds
against that owner and subtracts it from existing wall segments, preserving
their stable mesh/body paths, material and collision authority. The existing
riser builder consumes the authored chase ports. **build_exterior_masonry.py**
subtracts only the outer-leaf volumes from its native source-derived solids.
It retains the original **340** exposed edges, **104** corner records, **71**
window spans and **2** outer door spans, two material partitions and source frame.
No protected legacy cell or facade generator is regenerated.

Single-precision Vector3 arithmetic originally left closing plates smaller than
one micrometre at exact owner boundaries. Box subtraction now declines to emit
pieces at or below **10 micrometres**. The airway triangle/ray tests remain
strict; this is construction rounding below any authored detail, rather than
a relaxed obstruction test.

## Fitted lining and fixture separation

**build_ventilation_fabric_lining.py** intersects each opening with its original
structural seat and subtracts **196 mm** clear route volumes. The resulting
**2 mm** steel fits the **200 mm** clearance around the existing **194 mm** seam
bands. Longitudinal chase slots, transverse penetrations and bent junctions
share the same continuous clearance. Cutters extend beyond each segment end
to avoid false caps. Overlapping steel volumes are deduplicated and internal
faces omitted. No guessed outer-masonry AABB is used: its native
**PreServiceMasonry** collection retains editable original construction datums.
Window/door gaps and existing chase ports are excluded from lining seats.

Opening the chase exposed additional candidate hanger stations. Their coarse
ceiling bounds admitted unsupported plates, including corners over slab gaps.
**orison_v2_duct_supports.gd** now requires actual ceiling-triangle contact
across both plate footprints. The strengthened independent imported-mesh test
checks all eight actual top corners, in addition to the existing underside,
ceiling, mapping and headroom checks. **support-refined.log.receipt.json** passes
**452** checks with **63** supported stations (**A 8 / B 9 / C 31 / D 15**),
eight instanced draws and unchanged shared fitting geometry. Unsupported
positions are omitted, not disguised as ceiling attachments. Remaining exposed
spans and wall/chase bearing alternatives still require a support/access audit.

The lining has four geographic metal partitions mounted beneath the existing
**VentilationDucts/Stack_A** through **Stack_D** owners. It adds no collider,
interaction, light, sound or simulation. Existing MatLib **metal**, metre UVs,
native export handedness and full-precision import metadata are retained.

The wider bore check found four additional C-stack wall-edge intersections
missed by the initial 150 mm sample. The two bath north walls receive explicit
branch/stem cuts. The retained **F03_3D_SHOWER_01** and **F04_4D_SHOWER_01**
receptors move **60 mm** into their rooms, from local Z **-11.90** to **-11.84**,
clearing the north stack. The original first-floor kitchen flush dome moves
**200 mm**, from Z **-6.30** to **-6.10**, clearing the public-restroom branch.
Their models, IDs, controls, source properties and persistence stay authoritative.
Future water supply work must fit their revised physical mounting positions.

## Inspection and validation scope

Discovery before/after files are under **tmp/vent-wall-ports**; the earlier
slab-only trace is preserved as **before-fabric.json** and **before-overlaps.json**.
The initial cut trace reached zero within its 150 mm volume; the full-bore
discovery then exposed the four C-wall edges and a shower lip. The first actual
fabric suite subsequently exposed the fourth-floor shower and kitchen dome.
Those findings are preserved, not treated as passing evidence.

**OrisonV2VentilationFabricTest** checks the entire **172 mm** inner duct volume
on all **59** nonzero graph legs, all **23** plenum interiors and **531** corner/
centre physics rays. It tests actual transformed triangles, including nearby
fixtures and the new lining, rather than treating a draw's bounding box as
solid. Roof-fan internals and passive grille mouths retain their separate
imported throat/motor tests. It also checks imported metre UV, normal, tangent
direction and handedness for both masonry partitions and all four lining draws.
The shell and fixtures beside openings retain their existing collision owners.

The first attempt had a test-script type-inference error and reached the
runner's 180-second ceiling without a suite verdict. It was corrected; its
receipt is retained. **fabric-final.log.receipt.json** completed with **173**
checks, **59** legs, **23** plenums, **531** physics samples, **77** relevant
draws and **16,846** tested triangles: zero obstructions/failures. All sixteen
roof/throat/branch/fixture views were inspected directly. Bath-wall cuts and
shower-side clearance are concealed in those player views; actual geometry and
physics checks establish their fit. The east upper branch and some roof views
are dark under the existing lighting; they are not final render acceptance.
The kitchen view shows the separated dome and fitted wall collar. Startup
**19,632.212 ms** is a single observation, compared with earlier cut discovery
**19,531.234 ms** and failed fixture-test **19,834.584 ms**, not a stable timing
benchmark. Candidate-bound outcomes must pass before publication.
The carried lamp remains energy **6**, range **16**; all
views use existing scene lighting with no fill or global compensation.

The native lining is **165,747 bytes**, GLB **481,788 bytes**, **4,682** triangles
and **4** visual draws. The exterior native is **495,367 bytes**, GLB **932,680
bytes**. These are construction costs, not frame-time acceptance. Representative
startup observations and direct image inspection are recorded with final checks.

## Binding and continuation

The complete clean baseline is **tmp/vent-fabric-audit/8eb96c7-clean-board.json**.
Published **bfaeb9d15b4ee763ffab43075980679429bca06b** passes the complete
**46-gate** board, zero regressions/new unread fields, **17/17** protected paths,
unchanged requirements and the V2 default with explicit V1 rollback. Nine
candidate-bound suites pass under **tmp/vent-wall-ports/verified**. The first
two attempted city scene names did not exist; those runs grant no city proof.
The confirmed **OrisonV2CityCompositionTest** passes **1,253** checks and **450**
contacts under **tmp/vent-wall-ports/city-corrected-verified**, whose clean
verification has zero blocking findings. **validation-index.json** links the
ten passing bound suites on that unchanged candidate and preserves both naming
failures. The resident-key route's own schema-2 contract passes **84** waypoints
and **55** checks; hot water passes **1,738** checks. The board includes
one new projection test gate; no existing gate or test is weakened. Only the
individually reviewed new test references enter the spatial manifest; its five
historical cleanup opportunities remain preserved. Owner capture bytes/absences
remain unchanged and un-staged. In-place checks do not establish fresh-checkout
autocrlf/import behavior. Wrapper receipts and captures are not runtime contracts.

Continue support/access review, source/distribution/endpoint construction for
heating, water/drain, power, lift and communications/delivery, and the independent
bar, bodega and arcade systems. Keep raw architecture, infrastructure, mapping
preparation and final render/material polish as separate evidence-backed states.
