# V2 fitted mortise door hardware

Evidence class: **INERT**

**art/blender/scripts/build_door_knob_set.py** generates the editable
**art/blender/door_knob_set.blend** and **game/assets/props/door_knob_set.glb**.
The V2 domestic-door installer supplies one shared imported mesh to 105 entry,
interior and service leaves. Each face has a rounded backplate, turned knob,
spindle collar, two slotted screws and a real keyhole opening. Backplates sit
on the actual 44-millimetre domestic or 52-millimetre service visual slab.

Domestic panel moulding moves inward to leave a clear lock stile around the
new hardware. Service diagonals span between their rails rather than ending
across the lower backplate corner. The existing paint, brass, moving collision, hinge setback,
clearance checks, locks and interactions remain authoritative. Hardware joins
the existing static leaf material batches. V1 keeps its original hardware and
panel dimensions; storefront pulls and cabinet knobs are outside this batch.

OrisonV2DoorKnobTest probes the imported keyholes and the final batched leaf
meshes, checks both faces against actual moving leaf collision and captures
three installed families with inspection fill. Domestic route and resident
door-safety suites cover existing operation. Logs and suite-run receipts live
under **tmp/door-knobs**; no runtime-contract or ledger promotion is claimed.
