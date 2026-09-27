# V2 lift handrails

Evidence class: **INERT**

**art/blender/scripts/build_lift_handrails.py** generates the editable
**art/blender/lift_handrails.blend** and **game/assets/props/lift_handrails.glb**.
The real-size assembly fits the installed 1.55 by 2.2 metre production car.
It replaces the three eight-sided primitive grips with rounded brass rails,
closed ends and ferrules. Six flanged stems support the rails, including two
new rear-wall supports. Each flange carries two physically slotted fasteners.

The 36 mm flanges fit the exposed 40 mm wall course below the chair rail.
Their rear faces sit on the car walls; rail centres retain the existing
920 mm height and 73 mm wall offset. Existing brass material, moving car,
collision, controls and state remain authoritative. V1 retains its original
visuals. The assembly adds no collision or interaction authority.

OrisonV2LiftHandrailsTest checks the six mounting faces against actual car
wall collisions and captures the installed rear rail and mounting detail.
The passenger route suite checks all seven stops and ordinary crossings.
Run receipts and captures live under **tmp/lift-handrails**. They are
suite-run evidence, not schema-2 runtime-contract promotion.
