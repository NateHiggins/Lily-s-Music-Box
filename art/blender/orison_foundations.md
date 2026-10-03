# Orison foundation contact repair

Evidence class: **INERT**

The shell-readiness survey found actual exterior ground-wall bases without
native upward contact or a retained structural collision volume. Its discovery
is preserved under **tmp/shell-readiness**. Source-only ceiling volumes remain
separate findings: they are not physical bodies or finished load paths.

**scripts/build_orison_foundations.py** reads the original **PreServiceMasonry**
construction in **exterior_masonry.blend** and the retained blockout dimensions,
rooms and risers. It expands the outer leaf to the complete 350 mm wall profile,
then excludes basement room envelopes, original basement wall profiles and
riser footprints from the ground stems. It introduces no service cuts.

The recipe has nineteen unioned stem rectangles, **-3.4 to -0.2 m**, and
fifty-one unioned footing rectangles, **-3.8 to -3.4 m**. The nominal footing
width is 700 mm under a 350 mm wall. These are modeled construction dimensions;
soil bearing, reinforcement, load capacity and full vertical support remain
unresolved. Existing room, portal, coal-delivery and service authorities stay
with their retained owners.

**orison_foundations.blend** retains editable bounds and one welded complete
union: 4,222 quads, zero non-manifold edges. Its export has seventy-four pieces,
8,444 triangles, maximum four-metre extent, metre UVs and corrected tangent
handedness. Shared interior faces and artificial culling caps are omitted.
The existing concrete material is assigned by the production module. Each
piece has matching native triangle collision under **Foundations**; bounding
box collision would fill the preserved steps and exclusions. Final import
retains full precision. No new material key or simulation is introduced.

The earlier source-bound survey fixture is retained in
**game/tests/fixtures/orison_foundation_stations.json**. It binds the original
layout with LF-normalized hashing and the actual masonry binary. The focused
production inspection **tmp/shell-readiness/foundation-production-inspection1.log.receipt.json**
passes 1,119 checks: sixty-one closed ground stations, 183 new native/physical
contacts, 183 reproduced earlier gaps with only the added foundations excluded,
ninety-six basement masonry footing contacts, and zero actual native surface
intrusions into ten occupied basement masks. The remaining fifty-one deficient
ground stations and higher-storey contact findings remain open. Four rendered
production diagnostic views were directly inspected; below-grade views are
inspection positions, not public walking routes. The west gap is narrower than
the player capsule. Upper rear setback gaps remain visible in the final view.

Startup observations are 21,948 ms in the earlier volume discovery and 19,286 ms
in the focused production run. They are single observations with different
inspection work, not a performance improvement claim. The first inspection's
RenderingServer totals are not a representative player-frame census; the
committed test reports the viewport's visible pass instead. Below-grade surface
finish and construction joints need no broad decorative pass at this stage.

The required clean candidate comparison uses the complete genuine
**de69156** board at **tmp/roof-closures/de69156-clean-board.json**. Foundation,
basement, boiler, alley, roof, vertical, key-reconstruction and retained fabric
routes must pass before publication. Only the two individually reviewed new
spatial references are appended; audit logic and prior records are retained.
This report, its captures and wrapper receipt promote no runtime requirement.
Heating apertures remain parked until shell support and closure work settles.

Published **202e55d18a402305675307b11c9b19184dca049b** passes the complete
47-gate comparison against **de69156**, with zero regressions, NEW zero,
protected 17/17, V2 default/V1 rollback and requirement statuses retained.
All twelve windowed suites bind to the candidate: Foundations, BasementRoute,
BoilerRoute, BoilerInlet, BoilerDoorSwing, ServiceAlley, RoofRoute, VerticalRoute,
ResidentKeyRoute, ExteriorMasonry, VentilationFabric and Blockout. The basement,
roof and vertical circuits pass 88, 51 and 79 waypoints respectively. Resident
keys retain their schema-2 two-world contract, 84 waypoints and 55 checks.

The final report is **tmp/foundations/verified/verification.json**; its genuine
complete clean board is **tmp/foundations/202e55d-clean-board.json**. All four
final foundation diagnostic frames were directly inspected in the verifier's
absolute capture directory. The bound inspection repeats the 1,119 checks and
contacts above; its one-view census records 7,283 visible-pass draws and
3,970,521 primitives, startup 20,611 ms. These diagnostic counts do not accept
player-route performance. Only the reviewed two manifest additions changed;
no audit rule, prior classification, baseline or protected source changed.
The next work is uncovered lower-ceiling tops, slab-edge seats and transfers.
Whole-shell, infrastructure and material refinement remain open.
