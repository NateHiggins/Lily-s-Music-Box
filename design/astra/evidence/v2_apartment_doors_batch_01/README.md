# Apartment door category pass and occupancy repair

Source integrated; runtime pending. No Godot launched.

Eight production DoorProp leaves now replace the 2A and 2B placeholders. All
sixteen authored doors serving the four detailed apartments now use the shared
leaf implementation. The existing nine domestic/service specifications remain
unchanged. New entries carry their household identity and apartment subtype;
room doors retain their dimensions, jambs and positive-scale handedness.

Two 2A swing sides change deliberately. The hall leaf opens into the private
hall, keeping Mina's main-room cross-route clear. The bath leaf opens into the
bathroom, keeping the narrow hall usable when she leaves it open. The bedroom
approach continues farther west before turning north, clearing its open leaf.
Mina's existing NPC door API now covers her four home doors as well as the
existing laundry and bodega doors. No teleport or collision bypass was added.

The review also corrected the previous seating batch's incomplete occupancy
model. The case-owned caption desk and calibrator table are separate from the
domestic furniture dataset. Several newly placed pieces overlapped them. The
writing desk/chair move to 2A's bedroom and its dining group moves to the south
end of the main room. Seven anchors change; the case owners, evidence objects,
furniture geometry, materials and counts stay intact. The seating generator now
includes both case tables and the evidence approach path. Its earlier placement
receipt did not prove freedom from these separately owned objects.

Source validation:

- Eight new leaf colliders sampled at 0.5-degree intervals across their full
  100-degree sweep, against furniture, estimated fitting hulls and case tables.
- 1,647 samples of Mina's F02 graph checked against the open leaves, with a
  0.30-metre radius including her clearance margin.
- 3,755 samples of the prepared continuous 2A/2B player route checked against
  those owners and the appropriate open/closed leaves. Standing points also
  clear each moving leaf's sweep, using a 0.38-metre radius including margin.
- Seating and lighting generators rerun after the corrections; repeatability,
  preservation of unrelated source records and independent GDScript syntax
  checked. The updated seating receipt includes 2,906 approach samples.

Prepared runtime checks: OrisonV2ApartmentDoorRouteTest uses one initial F02
placement, ordinary movement and actual target rays/input to visit both homes,
open all eight doors and verify closed entry barriers. Mina's process is paused
only inside that player-route fixture; her separate timetable test checks that
she opens her interior doors herself. The composition harness now covers all
sixteen apartment leaves and teardown with active door tweens. Case-placement
and golden-repair routes explicitly open the newly solid 2A entry.

No prepared engine check has run. Source sweep checks do not cover every jamb,
decorative hardware edge, physics contact or motion tolerance. Actual passage,
NPC timing, close-target visibility, light/material appearance, acoustic state,
persistence, performance and lifecycle remain pending. V1 remains the default;
V2 is not complete or art-accepted, and S2J remains open.

Continue in category batches: remaining storage and surface props, a complete
wall/room-program audit, and the twenty source unit IDs without detailed V2
apartment spaces. Include all separately composed collision owners in subsequent
placement reviews, not only the domestic furniture dataset.
