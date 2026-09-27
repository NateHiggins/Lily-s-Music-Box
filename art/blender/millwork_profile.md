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
is introduced. Each public room adds
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

## Domestic doorway surrounds

The same Blender source now includes a stepped DoorCasing section with a
shallow hollow and raised outer bead. The production-only door-casing adapter
adds six profiled runs and three reveal liners per domestic opening, replacing
the three visible box frames with two material batches. The source frames stay
hidden with their original dimensions for existing schema/review consumers.
Liners span the actual 140 mm partition thickness; the 18 mm casing backs
touch both wall faces. Uprights retain the existing 90 mm width and stop at
the head, leaving the authored opening completely clear. The material remains
the architectural frame material; no new material key or texture is introduced.
Room trim now subtracts the casing envelopes from its runs. This includes
baseboards, picture rails, wainscot backing/frames and perpendicular corner
returns in narrow vestibules, so these surfaces do not break through the casing.

The adapter runs after the domestic/upper/completion door owners have mounted.
It leaves their DoorProp leaf, hinge, locks, interaction and collision intact.
Exterior, storefront and lift surrounds remain outside these batches.
The production root disables the old colored debug portal masses that otherwise
show through the new joinery; portal labels and standalone review cues remain.
OrisonV2DoorCasingsTest requires a windowed renderer to read live MultiMesh
transforms. It checks actual collision wall support behind all casing runs,
both face orientations, clear-opening bounds and separation from room trim.
Windowed captures show
installed doors with the production lamp and one separately lit joint detail.
The existing apartment-door route tests ordinary input-driven walking, opening
and closing. Logs and wrapper receipts are under `tmp/door-casings`; these do
not promote the runtime completeness ledger.

## Service doorway surrounds

Service leaves now use a separate Blender ServiceCasing section: a broad metal
face with rounded shoulders, fitted to the same opening and wall envelope.
The existing cast_iron material supplies its dark finish. A separate, real-size
Blender screw/washer mesh has a cut slotted head and beveled rim. Sixteen steel
fasteners secure each surround, eight on each face; hardware is never stretched
with the normalized frame extrusions. Washer backs seat on the 18 mm frame face.
Service frames use three draws per opening, replacing the three original boxes.

The existing casing suite also checks service profile identity, fastener count,
unscaled hardware, washer contact and frame backing for every screw. Its room
views retain the production lamp; a hardware close-up uses separate low fill.
The public-door suite exercises shut-door collision, ordinary opening and
crossing from both sides of the ground-floor service route. Logs, renders and
suite-run receipts for this pass live under `tmp/service-frames`.
