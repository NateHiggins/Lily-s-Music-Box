# V2 boiler access and physical controls

Evidence class: **INERT**

REPORT - V2-BOILER-ACCESS - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
19fc03487840499483041b8bbbbb9ca76542f35f (all three references).
Implementation HEAD is the commit introducing this report.

## Change and ownership

The production boiler inherited the inspection anchor's one-metre height and
faced away from the authored control stance. Its old apparatus and water-column
placeholder collisions also remained live. The runtime now grounds the model
on the authored basement level, faces its existing control stance and retires
only those two placeholder bodies. The production boiler's collision remains
solid. Semantic reservations and the separate breeching/flue remain unchanged.

The firing door, ash door and draft damper now use the existing PropControlArea
adapter with distinct prompts and the existing BoilerProp mechanisms. The
damper's ray target follows its visible assembly. Door targets fit their
physical faces, preventing the upper door volume from intercepting a ray aimed
at the lower door. Ordinary controls return the existing service-wire card;
the water-column activity retains its modal owner and abort behavior. No new
heat simulation, inventory, repair job, fuel source or save owner is added.

## Validation

The windowed physical route descends the existing primary stair, opens the
boiler-room fire door, checks real floor support, opens and closes both plant
doors independently, walks around to the damper, observes the existing hot-tap
and radiator output change, returns to the glass, cancels and completes the
production maintenance activity, and exits with ordinary collision. The scoped
route passes 17 waypoints with no failures or script errors. Maintenance slider
targets are submitted through the production director; this is not a blind
player test of the activity instructions.

Rendered firing-face, glass and damper captures were inspected. Logs and
adjacent suite-run receipts are under tmp/v2-boiler. Earlier failed approaches
and the fixture's initial collision-node inspection error remain recorded and
are not counted as passing runs. Nine reviewed spatial references are added
without changing any previous classification. The prompt-carrier tests pass
without expanding their legacy baseline. Clean candidate verification performs
two imports, compares the complete gate board, and repeats relevant runtime
routes. These observations do not promote schema-2 runtime-contract evidence.

## Remaining scope

Night-time iron close-ups still read poorly under the carried lamp's current
aim; that is a visible lighting limitation, not an accepted beauty pass. Coal
delivery remains static architecture. Continuous fuel and draft settings still
use the existing plant lifecycle rather than a new persistent boiler-state
adapter. Existing H23 and historical gate debt remain distinct. Owner render
notes and three images are preserved outside this change. No owner decision
is required for this slice.
