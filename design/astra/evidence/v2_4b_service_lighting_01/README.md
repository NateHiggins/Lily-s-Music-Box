# 4B kitchen and private-hall lighting source pass

Added flush-dome ceiling fixtures and physical switches for `F04_B_KITCHEN`
and `F04_B_PRIVATE_HALL`. They use the existing RoomLighting loader,
SwitchSystem circuit bindings, fixture materials and floor light budget.
The kitchen plate sits beside its main-room opening. The hall plate faces
into the hall from its west wall, near the main-room door.

Initial settings use the existing flush-dome energy scale of 1.25, with
5.2 m kitchen and 4.0 m hall range limits. These are starting source values,
not visually tuned results. Existing fixture and switch records are unchanged.

Source checks pass for unique room-contained anchors, wall-adjacent switch
placement, clearance of the kitchen's 0.81 m doorway, exactly one fixture per
new circuit, preservation of existing circuits and GDScript syntax. The earned
wake harness now includes both switches in its direct toggle/restore checks.

Reservation audit confirmed that playable V2 already disables reservation
volume display, and those volumes are constructed without movement collision.
No reservation deletion or hidden geometry workaround was needed.

**No Godot launched, per owner instruction.** The new fixtures and assertions
remain untested in the engine. Pending checks include physical switch approach
and ray targeting, room/floor budgeting, actual kitchen worktop illumination,
hall/bath/bed route readability, wake reconstruction and visual inspection.
The source work does not retire existing development lights or establish final
room presentation, saved circuit state, full-apartment completion or release
acceptance.
