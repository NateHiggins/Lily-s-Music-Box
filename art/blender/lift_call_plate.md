# V2 lift landing call station

Evidence class: **INERT**

Rebuild with `blender -b -P art/blender/scripts/build_lift_call_plate.py`.
The editable source is **art/blender/lift_call_plate.blend**; the runtime
asset is **game/assets/props/lift_call_plate.glb**. Fabrication parts remain
separate in Blender. Export combines the rounded brass plate and stepped,
bored collar into one mesh, the two recessed slotted fixings into another,
and retains the porcelain button cap as an independent third mesh.

All geometry is real-size. The plate footprint remains 100 by 170 mm, with
its flat rear at local Z zero. The V2 presentation locates each shaft wall
from the same solid fixture records that build it. This removes the old
30 mm gap caused by using the thicker V1 wall offset. The original call area
moves with the plate and retains its dimensions and input ownership. The
cap moves 3 mm axially inside the bored collar and existing input envelope.

The production elevator retains all travel, stop, interlock and request-lamp
authority. It exposes direct references to its existing plate, button and
area, and emits a presentation signal for a hall-button press. Repeated
presses cancel the previous visual tween; neither animation nor geometry
creates another request, saved field, collision body or gameplay state.
The existing brass and request-light materials stay attached; the fasteners
use the existing nickel_plated catalogue finish. There are no new texture
assets, material keys or baked labels. V1 retains its primitive visuals.

OrisonV2LiftControlsTest inspects all seven installed controls, shared mesh
identity, input envelopes, real wall contacts and eye-height reach rays.
It calls the production interaction entry point and samples the pressed
Tween pose explicitly so a slow initial render cannot skip the detent;
repeat cancellation and spring return use the live clock. Windowed captures
show installed and close-up rest/pressed poses under neutral inspection fill.
The existing OrisonV2ElevatorRouteTest supplies ordinary input, moving-platform
rides, hall exits, shaft-barrier contact and hall-button recall. Logs and
suite-run receipts live under **tmp/lift-controls**; this reference does not
promote runtime ledger requirements.
