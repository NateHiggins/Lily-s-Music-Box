# Grabbed stock: precision transforms

Primary click grabs the selected part; the next primary click releases it.
Space enters the owner's supported static inspection view. The camera remains
fixed and the free cursor continues to select individual mechanisms.

For a grabbed free object in inspection:

- Mouse drag translates in the camera plane; the wheel moves in depth.
- X, Y or Z selects an axis in the object's owner frame. Rightward or upward
  drag advances that axis, including when it points toward the camera. Press
  the same key again to return to camera-plane movement. The wheel also follows
  the selected axis.
- Hold the secondary mouse button to rotate: horizontal/vertical drag gives
  yaw/pitch and the wheel gives roll. With an axis selected, drag or wheel
  rotates around that axis instead.
- A small coloured notch on the existing reticle shows the selected axis
  (X red, Y green, Z blue); an arc shows rotation. Authoritative obstruction
  feedback remains on the same reticle. No second targeting scan is used.

The book's exposed upper spine selects whole-book manipulation. Its cover and
the lower single-axis turning grip remain separate mechanisms. Bottles inherit
the same stock controls; their caps keep their constrained turning grips.
Loose nozzles expose all six transforms. A nozzle engaged in the receiving
pilot/thread retains that mechanical constraint; withdraw it before tilting.

## Owner contract

This extends the existing `kind: free` descriptor. Translation still calls
`read` / `write` in `frame` coordinates. Optional `read_basis` / `write_basis`
callbacks expose orientation in the same frame. The controller proposes a
rigid rotation and reads back the owner's accepted basis; it never reparents,
rescales or directly transforms the part. The owner retains collision, thread,
inventory, mechanism and save rules. Owners without rotation callbacks keep
their existing constraints. Hinges and sliders are not converted to free stock.

Library stock and the loose fire nozzle implement these callbacks. Library
poses already persist their orientation. The nozzle household record now
stores its full loose basis and still accepts historical five-field records;
nonfinite, nonrigid and contradictory threaded orientations are rejected.

The FPS pickup/aim path continues outside inspection. Precision-axis gestures
are scoped to inspection so they cannot consume ordinary movement/look keys.
