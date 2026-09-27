# V2 beaded millwork profile

Evidence class: **INERT**

`build_millwork_profile.py` builds the editable Blender source and GLB under
`game/assets/props`. The normalized extrusion runs along local X with its
double-beaded face toward +Z. End caps are flat so scaling a long run does not
stretch an end bevel and open the existing butt joints.

The production millwork owner retains strip positions, lengths, heights and
projection limits. It rotates the profile into each room and clips it against
the same solid wall segments as before. Each room still uses one trim draw;
public wainscot retains its separate rectangular backing/frame batch. Existing
room material selection remains authoritative. No new collision or save state
is introduced, and this batch does not remodel doorway casings or panel stiles.

The existing floor-surface suite now checks transformed imported mesh bounds,
including rotated runs, instead of assuming every instance is an axis-aligned
box. It retains aperture, wall-height, maximum-projection and coplanar-panel
checks, plus real physics queries against the floor slabs. Windowed captures
hide the carried display for inspection while retaining production lighting.
One additional close-up uses neutral fill with the carried lamp off to inspect
the section itself; it is not a production-lighting acceptance view.
Logs, captures and suite-run receipts are under `tmp/millwork-profile`; this
reference does not promote ledger requirements or provide runtime-contract
evidence.
