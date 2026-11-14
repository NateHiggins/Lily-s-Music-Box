# 4B apartment entry: source integration

F04_DOOR_03 now mounts the existing apartment-entry DoorProp with unit 4B,
preserving the authored frame, left hinge, 0.91 m width and 2.13 m height.
Its production leaf begins closed and opens inward into the vestibule. The
existing apartment subtype supplies its painted joinery and entry hardware;
no new lock, save-state or acoustic-door policy is introduced.

The source check preserves all eight earlier adapter specifications and the
layout and shared DoorProp files. Its sampled collider bounds include the
26 mm hinge setback and leaf thickness through the 100-degree opening, and
remain inside the vestibule or the closed threshold thickness. These are
geometry estimates, not physics sweeps or visual acceptance.

OrisonV24BDoorRouteTest is prepared for the actual V2 runtime. It uses one
initial placement on F04, then normal player movement and interaction rays
to open the entry, hall, bathroom and closet doors, enter each space, return
to the public hall and close the entry. It closes the bathroom door after
leaving, clearing its projecting leaf from the return path down the hall.
It checks the physical opening stops
and the restored closed collision barrier. The earned-wake harness also
checks the entry's reconstruction and apartment identity.

**No Godot launched.** The new route and reconstruction checks have not run;
engine compilation, targeting, player clearance, hardware sweeps, materials,
lighting and captures remain pending. Previous route receipts predate these
solid doors. The default world remains V1.

Run `python design/astra/evidence/v2_4b_entry_door_01/check_source.py` for the
repeatable source geometry and preservation checks. Independent GDScript
syntax parsing was also used; it does not establish Godot type correctness.
