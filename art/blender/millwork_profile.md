# V2 beaded millwork profile

Evidence class: **INERT**

`build_millwork_profile.py` builds the editable Blender source and GLB under
`game/assets/props`. The normalized extrusion runs along local X with its
double-beaded face toward +Z. End caps are flat so scaling a long run does not
stretch an end bevel and open the existing butt joints.

The production millwork owner retains strip positions, lengths, heights and
projection limits. It rotates the profile into each room and clips it against
the same solid wall segments as before. Each room still uses one trim draw;
public wainscot uses a recessed rectangular backing batch and a separate Blender
frame batch. The frame section has a broad face, recessed quirks and beveled
shoulders; horizontal rails and caps face into the room, while stiles rotate
the same section vertically. Flat ends meet at the existing butt joints. Existing
room material selection remains authoritative. No new collision or save state
is introduced. Doorway casings remain for a later pass. Each public room adds
one frame draw, with no per-piece nodes or collision bodies.

The existing floor-surface suite now checks transformed imported mesh bounds,
including rotated runs, instead of assuming every instance is an axis-aligned
box. It retains aperture, wall-height, maximum-projection and coplanar-panel
checks, plus real physics queries against the floor slabs. Windowed captures
hide the carried display for inspection while retaining production lighting.
Additional baseboard and wainscot close-ups use neutral fill with the carried
lamp off to inspect the sections; these are not production-lighting acceptance
views. Both select unobstructed stations using actual physics sightline probes.
The checks cover imported frame geometry, room-facing orientation on all walls,
retained backing, aperture bounds and non-overlapping frame fronts.
Initial trim receipts are under `tmp/millwork-profile`; the frame refinement
logs, captures and suite-run receipts are under `tmp/wainscot-frames`. This
reference does not promote ledger requirements or provide runtime-contract
evidence.
