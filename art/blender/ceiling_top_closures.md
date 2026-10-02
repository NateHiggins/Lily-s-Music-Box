# Uncovered ceiling upper closures

Evidence class: **INERT**

The actual ceiling owners have retained underside faces and no bodies. Where
an upper room floor or landing already owns their top volume, that ownership is
correct. Source inspection instead found uncovered areas at setbacks and shifted
rooms, including the ground-level roof over portions of the basement. These
closures add physical top volumes only in those uncovered areas.

**scripts/build_ceiling_top_closures.py** reads the retained blockout rooms,
dimensions and ports plus editable **service_alley.blend** pavement envelopes.
It subtracts actual upper floor/landing rectangles, each ceiling's owned ports,
the two production apron omissions and the completed roof bulkheads. Native
alley object transforms are composed from stored location, rotation and scale;
unlinked Blender objects have unevaluated world matrices. The native paver datum
is checked before their continuous pavement envelopes are excluded. Their
recessed joints, drainage, material and collision remain with the existing alley.

Twenty-three ceiling owners retain **246.391 m2** of uncovered tops, in
fifty-one bounded mapped pieces and 370 triangles. Source depth is 200 mm.
Editable bounds remain in **ceiling_top_closures.blend**. There are no artificial
culling caps, duplicate undersides or buried side faces at retained slab joins.
Existing concrete supplies the finish. Each rectangular, port-free piece has
one source-depth box body under **CeilingTopClosures**. The generator introduces
no new port, room, material key, gameplay state or simulation.

The first isolated inspection is deliberately preserved as failed at
**tmp/shell-readiness/ceiling-top-trial1.log.receipt.json**: the initial proposal
overlapped nine sampled alley paving points and contained one degenerate export
edge. The earlier volume-specific mapping helper also required more than eight
vertices, unsuitable for genuine single-quad upper surfaces. The new planar
inspection retains complete UV/normal/tangent arrays, finite unit orthogonal
bases, strict actual UV derivatives and metre scale, with a four-vertex minimum
and complete native indexed triangles. No existing helper or audit logic changes.
Rounded construction boundaries remove the degenerate edge without adding
unnecessary subdivision or changing a tolerance.

The revised trial passes **tmp/shell-readiness/ceiling-top-trial2.log.receipt.json**:
3,396 checks, 459 matching upper contacts, 459 reproduced earlier gaps, 459
retained undersides and zero foreground conflicts. All five trial frames were
directly inspected. The canonical generator uses no scratch JSON or trial asset.

The production inspection is
**tmp/shell-readiness/ceiling-top-production-inspection1.log.receipt.json**:
17,932 reported checks, the same 459 contacts/gaps/undersides, zero foreground
conflicts and zero overlapping volumes across 14,484 comparisons with every
actual retained room-floor and landing collision shape. All five production
frames were inspected, including the front setback, basement top, west light
slot, lobby underside and rear setback. These diagnostic views are not walking
or performance acceptance. Slab-edge seats, wall transfers, weather finishes,
roof drainage, infrastructure and wider shell readiness remain open.

The required complete clean candidate baseline is **202e55d**, preserved in
**tmp/foundations/202e55d-clean-board.json**. Normal basement, vertical, roof,
door/key reconstruction, alley and retained fabric routes remain required before
publication. Only one individually reviewed collision naming reference is
appended to the manifest. Reader NEW is zero. This report, native construction,
captures and wrapper receipts promote no runtime or ledger requirement. Heating
apertures remain parked while support and closure work continues.
