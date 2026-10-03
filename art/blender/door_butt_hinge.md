# V2 articulated butt hinges

Evidence class: **INERT**

**art/blender/scripts/build_door_butt_hinge.py** generates the editable
**art/blender/door_butt_hinge.blend** and **game/assets/props/door_butt_hinge.glb**.
Each of 105 V2 domestic and service leaves receives three five-knuckle hinges,
with separate fixed pins, moving barrels, edge-mounted leaves and slotted
fasteners. Mirrored mesh sets serve both hinge faces without negative scaling.
The two leaves face the jamb and door edges when closed and unfold with the
existing moving body. They are not flat straps pasted across the door face.

Both fixed and moving barrels now use the actual body hinge offset. Previously
the visible fixed barrels always used the negative offset, leaving a 52 mm
axis error on opposite-swing doors. The body pivot, collision, swept-volume
checks, locks, sounds and swing timing are unchanged. Static and moving halves
join their existing material batches. V1 keeps its original presentation.

OrisonV2DoorHingeTest checks the final batched barrel geometry on 315 installed
hinges, compares both axes through three actual body poses on every door, and
captures the two open hinge faces. Domestic-route and resident door-safety
suites cover ordinary operation. Logs and suite-run receipts live under
**tmp/door-hinges**. No runtime-contract or ledger promotion is claimed.
