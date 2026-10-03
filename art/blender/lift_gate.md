# V2 articulated car gate

Evidence class: **INERT**

**art/blender/scripts/build_lift_gate.py** generates the editable
**art/blender/lift_gate.blend** and **game/assets/props/lift_gate.glb**.
The library contains a rounded flat link, flanged pivot and open track
section. The V2 presentation places these in three shared mesh batches:
42 hinged links plus eight sliding carriers, 61 pivots and two tracks.

The old lattice sat at car-local Z 1.04, intersecting the landing leaves.
The replacement sits at Z 0.95, behind their rear face. The production
CarGate node still follows the existing door fraction. Its new child
cancels the old X squash, then uses that span to articulate a three-row
lattice. Links keep their length and cross section; pivot pins keep their
diameter. The resulting small height change is accommodated by vertical
carriers at the fixed upper track. The old primitive meshes remain hidden.

The original brass finish, moving car, landing doors, interlocks, collision,
input and saved state remain authoritative. The model adds no collision
body or independent opening state. No new material key, texture or baked
lettering is introduced. V1 retains its original presentation.

OrisonV2LiftGateTest samples closed, half-open and parked geometry with a
windowed renderer. It checks constant link length and thickness, endpoint
alignment with pivots, preserved pin dimensions and separation from the
landing leaves. Captures inspect both the car and hall sides. The existing
elevator route suite supplies actual input-driven passenger movement,
shaft-barrier contact and hall recall. Receipts and captures live under
**tmp/lift-gate**; this reference does not promote runtime ledger proof.
