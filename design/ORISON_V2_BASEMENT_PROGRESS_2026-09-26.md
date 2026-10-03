# V2 basement service architecture

Evidence class: **INERT**

REPORT - V2-BASEMENT - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
eb08c79928fe6aaf3b7abe386e813602a9a47e01 (all three references).
Implementation HEAD is the commit introducing this report.

## Scope

The basement now has a dry electrical room, maintenance shop, separate coal
annex, eighteen resident storage bays and the lower service-stair connection.
Seven production service leaves include the formerly placeholder boiler fire
door. Existing door metadata is retained. The electrical leaf opens outward.
Its recessed entrance contains the swing, keeping it out of the narrow boiler
corridor instead of pushing the player against the opposite wall.
The shop reuses the existing repair bench, toolboard and parts shelf. Coal
geometry reuses the existing Blender coal-heap assembly and soot material.
Storage uses timber partitions and Label3D unit labels; it creates no inventory
or new resident quest. The live wet-stack shaft remains clear.

The existing fuse-panel activity opens through E, supports cancellation and
completes through the existing maintenance director. Its local safety state
does not become a new campaign job, save owner or building-power authority.
Five switched light circuits join the existing household owner, bringing the
persisted roster to 182 controls. Existing saves default the new circuits.

Actual controller tests found and fixed a gap between the basement east and
north landing slabs. The lower service stair also gains sufficient approach
space, with its switch attached to the revised wall. No collider is disabled
to make those passages work. The original boiler apparatus stays in place.
Opening-axis validation now refuses malformed records before construction; a
missing axis previously threw during wall building without preventing startup.
Focused mutation checks cover missing and invalid axes.

## Validation and evidence limits

Approved lane logs, windowed captures and adjacent suite-run receipts are in
tmp/v2-basement. These are scoped checks, not schema-2 runtime-contract proof.
Earlier failing routes remain recorded; they are not counted as passing runs.
Storage and workshop renders were inspected; the first workshop capture found
the toolboard below the bench, and its mounting height was corrected.

The complete working gate board reports zero regressions against the clean
eb08c799 board. Reader audit has zero new unread fields. The 240-requirement
ledger retains blocker counts 7/8/127/42/151/153; three source obligations move
from absent to programmed. No historical evidence is promoted or rewritten.
The existing M11C1 runtime-rehearsal hash failure remains baseline debt.

Executed regression receipts include laundry (17 waypoints), household saves
(105 checks), lift2 (64 waypoints) and golden (92 waypoints), all with zero
failures. The lift's first invocation hit the default 60-second runner ceiling
and reported no verdict; lift2 completed within the approved serial ceiling.
The blockout suite passed 2,067 checks after the initial double import.
The updated blockout2 receipt passes 2,070 checks, including the opening-axis
mutations. The final route9 receipt passes 88 live waypoints: normal descent
from F01, all eighteen bays, the recessed panel-room door, cancellation and
completion of fuse service, both lower service-stair flights in both directions,
coal-room access and return through the production boiler fire door. Corrected
workshop, panel, storage and coal-room renders were inspected. Early malformed
opening and obstructed-route attempts are retained as failures.

The spatial manifest adds only reviewed dependencies for these rooms, apparatus
and tests. Four existing electrical-room references gain a V2 target without
changing their preservation classifications. Historical evidence is untouched.
This inert report promotes no ledger requirement. The source now programs the
previously absent electrical, maintenance-shop and coal-room obligations.

## Remaining scope

The coal annex has no exterior delivery chute or simulated fuel supply. Storage
gates are folded static architecture, without lock or inventory interactions.
The fuse repair is local to the current building instance. The shop's furniture
does not create new repair jobs. Continuous modeled ventilation branches and
roof lift machinery remain unfinished. Existing H23 and historical M11C1 debt
retain their separate status; this is not a claim that every historical gate
or the entire building programme is complete.

Protected paths, the V2 default and explicit V1 rollback remain unchanged.
Owner render notes and shot_024 through shot_026 remain outside this commit.
No permanent worktree or reference-image asset is added. No owner decision is
needed for this scoped construction.
