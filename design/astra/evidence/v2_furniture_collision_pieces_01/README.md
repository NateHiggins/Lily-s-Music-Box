# Collision follows desk and counter pieces

The new terminal desk and sink counter previously used one solid box around
each assembly. That box filled the desk's open centre and the counter's sink
opening. Their generators now emit `collision_boxes` from the same explicit
blocks used for visible geometry: nine desk pieces and twelve counter pieces.
The existing V2 furniture loader creates those shapes on one StaticBody3D per
assembly. Other records retain the previous single-box behavior.

The optional data is currently allowed only for desks and counters. Validation
rejects empty/oversized lists, malformed or non-finite coordinates, inverted
boxes and pieces outside the declared assembly bounds. Visual geometry,
materials, anchors and interactions are unchanged.

Source checks confirm bounded positive-sized pieces, byte-identical repeated
generation, unchanged previous records and visual geometry, and GDScript
syntax. Points in the desk centre and sink opening were inside the previous
full collider but lie outside all new pieces; points on the worktops remain
inside collision. These are source checks, not engine physics results.

The earned wake test now includes an under-desk ray that must remain clear
and an upward ray that must hit the desktop, preventing a false pass caused
by accidentally removing all desk collision. These assertions are pending.

**No Godot launched, per owner instruction.** The change adds 19 collision
shapes across the two bodies. Runtime shape behavior, physics cost, actual
player/prop clearance, terminal and sink targeting, and Dream/wake retirement
still need validation. The sink itself retains its own fixture collider; this
change removes the counter's extra obstruction. It does not implement seated
movement or guarantee a player capsule can pass under the desk.

This supersedes the coarse desk/counter collider limitation in the earlier
source packets; their historical checks remain unchanged. Regenerate with
the existing terminal-desk and sink-counter build scripts.
