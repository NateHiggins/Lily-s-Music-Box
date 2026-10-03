# V2 service-lamp coverage

Evidence class: **INERT**

REPORT - V2-LAMP-COVERAGE - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
23a653391f784060efcf220ca05193a4c1c85c7a (all three references).
Implementation HEAD is the commit introducing this report.

## Implemented scope

The waking lamp reaches sixteen metres, with a 1.45 multiplier on the
existing thermal model's cone angle. Base energy remains 24. The shared
carried instrument rests at four degrees pitch and six degrees yaw so its
modeled lens aims toward the interaction area rather than below and beside it.
The pose applies wherever the existing carrier is used; the wider cone and
longer range belong to waking V2. Dream and inspection energy remain unchanged.

There is still one real carried light, one logical switch and one saved thermal
state. The voxel observation reads the actual delivered angle, energy and pose.
No ambient fill, new fixture, save field or ecological exposure owner is added.
Participating-air and dust volumes keep their existing local bounds; the longer
surface-light range does not imply building-wide volumetric illumination.

## Validation and limits

Windowed captures under tmp/v2-lamp-coverage show the firing face and rear draft
damper illuminated by the physical lens. Widening alone improved surrounding
coverage but left the central control poorly lit; the corrected carrier pose
resolved that in the inspected views. The boiler route now lets the carried
lamp settle after its scripted instant camera turns and checks that every
interaction target lies inside the central half of its cone.

The driver regression checks that widening preserves thermal state and that
the voxel observation follows the real cone. The primary-light suite compares
rendered lamp-off and lamp-on surfaces with room fixtures disabled in a home,
the basement and on the roof. Approved serial runners record logs and adjacent
suite-run receipts. Clean candidate verification repeats two imports and the
final lamp, boiler, optical-owner and zoo checks, with a full baseline board.
These are scoped observations, not schema-2 runtime-contract promotion.

All seventeen protected paths remain unchanged. Reader audit has zero new
unread fields; spatial inventory reports clean without changing its manifest.
Ledger before/after remains 7/8/127/42/151/153; no requirement is promoted.
Existing H23 debt and the broader unfinished architecture/campaign remain.
Physical occlusion still leaves areas behind machinery dark. The owner's
render notes and three captures are preserved outside this commit. No owner
decision is required for this slice.
