# V2 lift floor indicator

Evidence class: **INERT**

**art/blender/scripts/build_lift_indicator.py** generates the editable
**art/blender/lift_indicator.blend** and **game/assets/props/lift_indicator.glb**.
The old circular dial extended above the car ceiling and hid its upper legends.
The replacement uses a shallow half-round brass case, recessed enamel face,
tapered needle, pivot cap and two ceiling mounts. The whole case fits beneath
the ceiling and ahead of the gate. Lettering is runtime Label3D, not baked art.

The existing car-height calculation still drives the original needle node.
The seven destinations come from the production lift. V2's face and needle
orientation read from basement on the left to the top stop on the right. No
travel, input, collision, save or interlock authority changes. V1 keeps its
original visual presentation and shared drive logic.

OrisonV2LiftIndicatorTest checks actual ceiling contact at both mounts,
housing clearance, all seven stop labels and thirteen stop/midpoint needle
poses. Windowed views inspect readability from inside the cab. The existing
passenger route checks ordinary input and collision-bearing crossings.
Receipts live under **tmp/lift-indicator**; this reference grants no runtime
ledger promotion.
