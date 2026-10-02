# Shifted ground core transfer frame

Evidence class: **INERT**

The ground public-core west wall sits one metre east of the basement laundry
boundary. The current source/native discovery leaves three stations on its
northern segment and one on the watch-wall end without support. The retained
lift enclosure occupies the southern run; extending a beam through it is wrong.

**scripts/build_ground_core_transfer.py** derives a 350 mm wide, 450 mm deep
I section beneath the northern source wall base, with a short westward watch
seat, two fitted H columns, cap/base plates, eight exposed plate anchor heads
and supplemental 700 mm footing pads beneath the retained landing slabs.
The southern column offsets east to preserve the west passage. The small
70 mm inner floor-edge band excludes the actual editable masonry envelopes.
New pads exclude the earlier foundation union. Original walls, apertures,
floors, landing bodies, equipment and simulations retain their owners.

Editable component bounds and complete closed union meshes remain in
**ground_core_transfer.blend**. The steel assembly is connected. Coplanar grid
divisions are dissolved before 1.5 mm external steel chamfers and native
triangulation. The final export has three bounded partitions and 1,884 triangles,
with no artificial culling caps. Orthonormal face projections retain metre UVs,
full precision and matching normal/tangent handedness. Existing concrete and
locally tinted **metal** supply finishes. Matching native triangle collision
preserves the open I sections; solid bounding boxes would invent material.

The first fit is preserved as failed at
**tmp/shell-readiness/ground-transfer-trial1.log.receipt.json**: the longer beam
intersected retained lift fabric and an edge band duplicated masonry. The
shortened trial passes twelve contacts and reproduced original gaps, eight
landing and eight footing contacts, with zero positive existing-body overlaps.
Export attempts with missing tangents or degenerate bevel points were rejected;
the final generator triangulates native faces and welds numerical duplicates.
No mapping tolerance or audit logic changes.

The initial route's return turn hit the retained open laundry leaf. Its failed
receipt remains **tmp/shell-readiness/ground-transfer-route-trial1.log.receipt.json**.
The corrected approach passes **ground-transfer-route-trial2.log.receipt.json**:
27 normal-input waypoints, both west passage directions, laundry entry/exit
and return to the initial landing. The first installed route also passes at
**tmp/shell-readiness/ground-transfer-production-route1.log.receipt.json**.
All three trial route frames were directly inspected. The initial installed
inspection passes 99 checks at **ground-transfer-production-inspection1.log.receipt.json**;
all six views were inspected. That view exposed crowded anchor heads, which
are moved onto clear margins of 260 mm plates in the final fabrication.

**game/tests/fixtures/orison_ground_transfer_stations.json** preserves the
original twelve negative samples and LF-normalized layout/native masonry
identity. The final inspection additionally checks eight exposed native anchor
tops and their live collision. The complete clean candidate comparison remains
required before publication.

The final 1,884-triangle production inspection passes 116 checks at
**tmp/shell-readiness/ground-transfer-production-inspection3.log.receipt.json**:
twelve matching wall seats and reproduced old gaps, eight landing contacts,
eight footing contacts, eight native/live exposed anchor tops and zero positive
existing-body overlaps. All six final views were directly inspected.
**ground-transfer-production-inspection2.log.receipt.json** retains eight failed
short anchor rays. **ground-transfer-anchor-diagnostic2.log.receipt.json** keeps
the diagnosis: collision faces contain every head, and longer rays hit the exact
tops. Godot 4.7 **core/math/geometry_3d.h:segment_intersects_triangle** multiplies
triangle area by segment length in its approximate-zero parallel test. The
30 mm segment falls below that threshold for the small chamfered heads. The
test now uses a 200 mm segment and retains the same first-hit owner and 30 micron
contact requirement. Native fabrication, mapping tolerances and audit rules are
unchanged by that probe repair. This is component contact evidence, not whole
shell readiness or structural capacity acceptance.

The final installed route passes 27 normal-input waypoints at
**tmp/shell-readiness/ground-transfer-production-route2.log.receipt.json**,
including actual player ray/prompt and input opening the retained laundry leaf
to its stop. Its three frames were inspected; the retained service-wire device
obscures parts of these route views, so the six construction views supply the
fabric inspection. Startup in the final focused inspection is 19,688 ms, a
diagnostic observation without matched-cache performance acceptance. Full
candidate validation and wider representative-view measurements remain open.

The actual post-closure survey and separate editable masonry reconciliation are
**tmp/shell-readiness/post-closure-contact1.log.receipt.json** and
**post-closures-source-continuity.json**. Their 92 unresolved stations are a work
list: below-base collision, slab embedment, source masonry continuity, source
paving envelopes and existing vent bores remain distinct. This frame targets
four local stations. Higher-storey transfers, wider support continuity, front
threshold backing, shell weather finishes and infrastructure remain open.
Heating apertures remain parked. Contact construction determines no load,
reinforcement or soil capacity and promotes no runtime/ledger requirement.

The clean complete candidate baseline is **244853b**, preserved in
**tmp/ceiling-closures/244853b-clean-board.json**. Only individually reviewed
new collision naming and route references are appended to the spatial manifest.
Required routes include the normal basement, vertical, roof, boiler, alley,
door/key reconstruction and retained fabric circuits. Wider raw architecture
and all seven location/utility phases remain open.
