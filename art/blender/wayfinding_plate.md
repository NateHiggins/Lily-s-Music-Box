# V2 wayfinding plate hardware

Evidence class: **INERT**

All sixteen stair floor signs share `wayfinding_plate.blend` and its exported
GLB under `game/assets/props`. Rebuild with Blender in background using
`-P art/blender/scripts/build_wayfinding_plate.py`. The Blender source retains
separate editable parts; the export batches them into three material meshes.

The 1.3 by 0.48 metre enamel plate has rounded corners, a rolled brass border,
four washers and recessed slotted screw heads. Four backing spacers reach the
existing wall plane at local z = -0.025 m. The enamel face stays at z = 0.0125 m,
behind Label3D lettering at z = 0.016 m. Floor titles use the existing Courier
Prime Bold font at 96 px, with 40 px bold Courier directions, to keep solid ink
strokes readable under the service lamp. No texture contains text.
Existing enamel_appliance, brass and rubber_aged catalogue materials are used.

The existing wayfinding owner retains floor names, directions and lettering.
Its wall-normal offset now uses partition thickness, matching the actual core
outline builder, instead of core thickness. This removes the old 55 mm mounting
gap without changing wall selection or sign height.
There is no new interaction, save state, light source or collision.
The shared hardware does not change stair traversal geometry.

The windowed `OrisonV2WayfindingTest` checks all four spacer seats against actual
wall collision on every sign, retains the unobstructed sightline check, and
measures title contrast with the production carried lamp and foreground device
display hidden so its paper cannot contaminate the sign crop. Its views are declared
inspection stations, not a walked route. Captures and adjacent suite-run receipts
include one separate oblique hardware view with neutral fill; that view is not
used to establish production-lamp readability. The logs and captures
are under `tmp/wayfinding-hardware`. This document does not promote completeness
requirements or supply runtime-contract evidence.
