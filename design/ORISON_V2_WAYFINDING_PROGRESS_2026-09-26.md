# V2 stair wayfinding and lamp-readable lettering

Evidence class: **INERT**

REPORT - V2-WAYFINDING - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
12470e427341798d13b2bc43df31446057ed02cf (all three references).
Implementation HEAD is the commit introducing this report.

## Implemented scope

Both stair cores now carry enamel floor plates on all eight levels, sixteen
plates in total. Their positions derive from the core and primary stair
schedule. The ground public plate uses the east wall because its southern
threshold opens into the lobby. Basement plates identify the laundry, boiler
and workshop; ground plates identify street/watch and service access; roof
plates identify the way down. The old two floating floor labels remain in
development views but are disabled in the production runtime.

V2 glow no longer bleaches dark lettering under the service lamp. Its intensity
is 0.02, bloom is zero, and HDR threshold and luminance cap are both 2.0. The
existing debug light rig inherits that starting intensity instead of restoring
its V1 default during binding. Glow remains adjustable through existing debug
controls. Lamp energy, sixteen-metre throw, optical field, fog and Dream
settings are unchanged. Printed Label3D lettering remains flat dark ink on a
lit enamel plate; no texture lettering or new material key is introduced.

## Validation

The windowed wayfinding suite checks all sixteen plaques against actual wall
collision and unobstructed camera sightlines. It captures each rendered plate
and requires at least 3:1 contrast between the title ink and its backing, using
the fifth and seventieth luminance percentiles of the projected title crop.
This checks legibility without demanding white backgrounds in dim upper stairs.
These are declared camera stations, not a claim of walking the building.

Diagnostic captures reproduced unreadable lettering with production glow;
turning fog off alone did not resolve it. Disabling glow did. Early attempts
that left the light rig's old startup intensity in place still failed. The
final production run in tmp/v2-wayfinding/capped.log.receipt.json completes
sixteen plaques with zero failures, with title contrast from 3.73 to 10.12.
Basement, ground and upper-stair rendered captures were inspected.

Clean candidate verification uses the existing full static board baseline,
double import, and windowed wayfinding, primary-lamp comparison, vertical
walking route, actual title Continue and zoo suites. Logs and adjacent suite-run
receipts are under tmp/v2-wayfinding/verified. This is scoped engineering
evidence, not a runtime-contract or human acceptance receipt.

Five spatial inventory records are appended without changing older entries.
No protected path, selector behavior, save format or collision geometry changes.
This inert report promotes no completeness requirements. The baseline ledger
counts remain 7/8/127/42/151/153.

## Remaining scope and checkout

The signs identify stairs and levels, not a complete apartment directory.
Close lamp illumination still produces bright material highlights. Existing
H23 optical debt and unfinished campaign work remain. The canonical checkout
retains the owner's modified render notes and three untracked captures; those
files are preserved byte-for-byte and excluded from this work. No new worktree
or reference image is introduced. No owner decision is required.
