# Fitted lift ceiling lamp

Evidence class: **INERT**

**art/blender/scripts/build_lift_ceiling_lamp.py** generates the editable
**art/blender/lift_ceiling_lamp.blend** and **game/assets/props/lift_ceiling_lamp.glb**.
A ceiling-seated plate, stepped brass bezel, closed opal bowl, three rounded
retaining straps and three slotted screws replace the old flattened sphere
and segmented tube ring in V2. The underside retains more than two metres of
headroom. The plate meets the existing ceiling underside without penetrating it.

The existing dome material and single cab light retain emission and lighting
ownership. No additional light, collider, save state or interaction is added.
V1 retains its original presentation. Existing brass and enamel material keys
are reused; the production dome material overrides the opal surface.

OrisonV2LiftLampTest checks four actual ceiling contacts, imported mesh bounds,
the bowl aperture and retained light count/output, then captures the fixture
from two views. Integration uses the existing indicator, mirror and title
Continue suites. Receipts live under **tmp/lift-lamp**. These are suite-run
receipts, not runtime-contract evidence or ledger promotion.
