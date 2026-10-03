# V2 wall switch

Evidence class: **INERT**

Rebuild with `blender -b -P art/blender/scripts/build_light_switch.py`.
The editable source is **art/blender/light_switch.blend** and the runtime asset
is **game/assets/props/light_switch.glb**. The source models a moulded Bakelite
plate, backing gasket, cut screw recesses, slotted nickel screws, a hollow
toggle collar and a separate porcelain-tipped **TogglePivot**.
The .blend keeps fabrication parts separate; export batches the stationary
hardware while retaining the independent moving toggle.

The rear face and 120 by 180 mm footprint match the previous V2 plate.
Both toggle detents remain inside the existing interaction envelope. Existing
catalogue finishes supply the skin; there are no new textures or material keys.
The room-lighting loader replaces its two primitive visual meshes with this
shared asset in the main and completion-interior rosters.

SwitchSystem retains room power and audio authority; household state retains
save authority. The visual subscribes to circuit verdicts, animates between
two detents, and reads restored fixture state after a live load/reset. It adds
no collision owner, lamp, maintenance state or new saved field. V1 retains its
baked plate geometry.

**LightSwitchModelTest** examines the installed V2 roster, shared meshes,
vertex clearance and unchanged collision count; uses an authored eye-height
ray; checks both throws, rapid reversal and live saved-state restoration;
and captures the installed switch in a windowed run. The existing
**OrisonV2UpperLightingTest** checks physical approaches, isolated circuit
effects and save behavior throughout the upper floors.
