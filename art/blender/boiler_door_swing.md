# Boiler door swing correction

Evidence class: **INERT**

The owner identified the firing door opening into the boiler. Both existing
leaves extend along positive local X from a vertical hinge on the front
negative-Z face. Their negative Y rotations carried them into the casing.
BoilerProp now rotates the firing leaf outward 95 degrees and the ash leaf
outward 82 degrees, using the same direction for tweened and immediate poses.
Their geometry is still script-built; this correction is not a completed
Blender fabrication of the boiler.

Each plate now carries a box collider on its existing moving hinge. The
stationary boiler envelope and control areas retain their owners. Latches and
small hinge barrels remain visual details outside the plate collision.

OrisonV2BoilerDoorSwingTest exercises both production controls, samples fourteen
animated poses, checks the actual merged triangles against the casing, probes
the open plates with physics rays, compares visual/contact distance, closes
both leaves, and checks the immediate pose path. Player-height lamp and detail
captures are written under **tmp/boiler-doors/shots**. The detail camera hides
the carried set for an unobstructed inspection; gameplay retains it.

The batch uses the clean **1d2b4fb6d2f289387d7287be8270632e90603c15** board in
**tmp/breeching/base-board/board.json**. Final verification belongs in
**tmp/boiler-doors/verified/verification.json** with bound suite-run receipts.
These are scoped regression checks, not runtime-contract evidence or a
completeness-ledger promotion. Broad boiler fabrication, the firebox interior,
and the coordinated material pass remain outstanding.
