# Apartment lighting category pass

Source integrated; runtime pending. No Godot launched.

Added 15 room fixtures, 15 physical switches and 15 standing anchors across
2A, 2B, 3B and 4B. All 26 detailed private/wet spaces now have exactly one room
circuit. Existing thirteen fixtures (including Omar's independent task lamp),
twelve switches and 173 anchors are preserved. Total lighting roster: 28
fixtures, 27 switches, including the existing basement laundry circuit.

New fixtures use the shared flush-dome family except Lena's living-room
pendant. Switches use the existing bakelite/porcelain plates and SwitchSystem;
LightFixtureProp and LightRig remain the power/budget owners. Throw and energy
values are initial source settings, not visually tuned results.

`../../work/v2_apartment_lighting_batch_01/build.py` checks room containment,
wall ownership and doorway/window clearance, capsule margins, fixture/furniture
footprint estimates, inward-facing switch orientation and eye-to-switch reach.
Neighbour-owned walls are allowed only when an uninterrupted segment exists.
Existing records are preserved and repeated application is byte-identical.
The checks were rerun against the subsequent seating/storage batch.

The prepared apartment batch harness now checks 26 room circuits, physical
plate dispatch, isolation from all other room fixtures, return throws and
retirement on two world reconstructions. The connected-world input harness
uses authored switch stances where present, retaining its capsule and actual
target-ray checks. Independent GDScript syntax parsing passes. These harnesses
have not run in the engine.

Remaining: physical reach/door sweeps, illumination and light leakage, budget
cost, material appearance, persistence and lifecycle acceptance. Existing
development lights remain. V1 is still the default; this does not close S2J or
establish full-building or visual acceptance.
