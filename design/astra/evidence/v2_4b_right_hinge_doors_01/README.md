# 4B right-hung doors: source integration

The private-hall and bathroom openings now mount the existing DoorProp leaf,
replacing their blockout Hinge subtrees while retaining the semantic frames.
Both authored openings are 0.81 m wide, 2.13 m high and right-hung. The adapter
places the hinge at positive half-width and rotates the leaf root by PI,
then reverses the local swing direction. This spans the original opening
without negative physics scale and retains each opening's intended swing side.
Existing left-hung placement is unchanged; DoorProp itself is unchanged.

These production leaves begin closed. They replace previously open, non-solid
blockout leaves, so real interaction and passage checks are required. The 4B
entry door is not part of this change.

Source geometry calculations check hinge/latch placement and opening direction
for both doors, preserve the left-hinge formula, and estimate hall leaf-tip
clearance from the terminal desk with an 0.08 m allowance. This is not a swept
physics or hardware-clearance test. Independent GDScript syntax parsing passes.

The earned-wake harness now checks both production leaves and their closed
hinge/latch transforms. Its pending desk physics rays also now convert their
building-local coordinates through the blockout root into world coordinates;
the earlier source-only rays incorrectly treated those coordinates as world
positions. These runtime assertions have not run.

**No Godot launched, per owner instruction.** Pending work includes engine
compilation, ordinary door targeting/opening, player passage through the hall
and bathroom, swept leaf/hardware clearance, reconstruction and visual checks.
No saved door state, room completion or V2 default cutover is claimed.
