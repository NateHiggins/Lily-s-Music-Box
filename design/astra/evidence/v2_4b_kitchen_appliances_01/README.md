# 4B kitchen appliances: source integration

Mounted the existing `F04_B_STOVE_01` gas range and `F04_B_FRIDGE_01` oak
icebox through the V2 domestic fitting loader, using new kitchen anchors and
separate approach positions. Original layout markers specify gas and a
non-monitor icebox; those identities are retained. The runtime implementations
already own oven/burner and icebox-door behavior and materials.

The loader now creates solid visual-bounds bodies for stoves and fridges as
well as sinks. Their existing interaction Areas remain responsible for player
ray targeting. This affects existing 2A/3B refrigerators and the 3B range too.
Bodies derive from initial constructed geometry; this does not add moving
door collision or claim fully validated open-door clearance.

Source checks pass for marker identity, unique anchors, preservation of all
previous fitting records, conservative appliance envelopes inside the kitchen,
separation between appliances, standing approach clearance and GDScript syntax.
The envelope estimates are not measured Godot mesh bounds. The earned boundary
harness now checks reconstructed appliance types, 4B unit ownership and solids.

**No Godot launched, per owner instruction.** Actual mounting, resource loads,
collision routes, door operation, controls, lifecycle and visuals are pending.
The next engine pass must include the previous 2A and 3B routes because of the
shared collision change. No gas-network simulation or saved appliance state
was added. The icebox retains its existing structural acoustic identity.

Kitchen completion remains open: the compact sink needs a properly supported
counter assembly before mounting, and room lighting and final presentation
still need work. No full-kitchen or V2 completion is claimed.
