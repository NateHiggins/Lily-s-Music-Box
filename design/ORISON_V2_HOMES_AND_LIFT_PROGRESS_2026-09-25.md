# V2 remaining homes, passenger lift and shared roof ventilation

Evidence class: **INERT**

REPORT - V2-HOMES-LIFT - 2026-09-25

Branch / base / origin/main at start / merge-base: main /
3df38d70c9f6e1ad74d621af5dff9c189e831d3d (all three references).
Implementation HEAD is the commit introducing this report.

Owner render notes and shot_024 through shot_026 remain excluded. Verification
preserves those four files with byte-checked backups, temporarily cleans only
their paths, and restores them. No additional checkout is created.

Protected 17/17: no protected path edited. The V2 selector and explicit V1
rollback remain unchanged. Historical evidence is not rewritten.

Ledger before -> after: 7/8/136/50/159/161 -> 7/8/127/42/151/153.
Requirements changed: staff sanitation; six occupied unit programs and their
entry/living/cooking/sanitary/sleep/storage obligations; two sealed-unit programs.
Worktree clean at end: implementation paths committed; the four owner files
above retain their original local state.

## Implemented scope

The existing passenger elevator now occupies its authored shaft and serves
seven stops, B1 through F06. Moving car, call buttons, cabin controls, door
interlocks and obstruction handling remain the production elevator system.
Landing slabs are cut around the well. Shaft walls, jambs, headers and a pit
provide physical separation. Cabin floor and alarm controls now have prompts.
The final transform is established before creating the synchronized bodies;
otherwise the car's visual transform and physics transform diverge.

Remaining occupied homes 1A, 1D, 2C, 3D, 4C and 4D gain authored rooms,
windows, physical production doors, reused furniture, taps, showers, toilets,
stoves, fridges and switched lights. The staff restroom faces the service hall.
Sealed homes 2D and 3C retain locked physical doors. No new biography, case or
resident authority is introduced. Source projections preserve unrelated records.

Four existing automatic roof ventilators serve 23 passive ceiling registers.
Their audio emitters use installed V2 anchors rather than V1 coordinates.
Guarded service inspection preserves the existing refusal and automatic motor
ownership. Solid curbs prevent walking through the plant. This does not claim
complete modeled duct branches, electrical distribution or lift machinery.

Public routes now pass around the real shaft. The watch/core doorway moves
along the same wall to the front approach, clear of the shaft. Mina's authored
route graph and current player-route fixtures use those physical passages.

All room lights share one switch owner and the existing household save owner.
New circuits default when absent from old saves; old saved settings retain
their identities. No campaign files are converted or overwritten by tests.

## Gates and evidence

The source-only reader reports zero new unread fields. The spatial review adds
449 dependencies from the new source/consumers/tests and 151 existing target
resolutions gaining V2 placement. Authority and preservation classifications
remain unchanged; four pre-existing cleanup opportunities remain recorded.
Projection preservation, shaft aperture and consumer-anchor tests pass.

The ledger recognizes the new authored programs, including the staff restroom
and eight previously absent unit programs. Its dynamic room obligations expand
from 204 to 240. The separate completion-interiors spatial checkpoint records
the executed room routes and promotes 43 obligations to SPATIALLY_PROVEN.
No obligation is promoted to RUNTIME_PROVEN by these wrapper receipts or images.
These changes do not claim human acceptance, whole-building proof or retirement
authorization.

Approved serial lane logs have adjacent .receipt.json files under
tmp/v2-completion. Executed focused runs include:

- elevator4: seven stops, riding, exit/re-entry, closed landing barrier,
  recall through actual player input and access to upper apartment halls;
  64 waypoints, zero failures.
- rooms7: all six occupied homes plus staff sanitation, both central bedrooms
  and storage/work rooms; 144 waypoints, zero failures, including independent
  hot/cold controls. This supersedes rooms5, teresa1 and rooms6.
- mail1, laundry1, vertical1 and apartments1: 16, 17, 79 and 45 waypoints,
  zero failures through existing production routes.
- ventilation1: four motors, 23 register emitter positions, automatic running,
  E inspection/refusal, solid curbs and locked apartment barriers; zero failures.
- roof1: both roof stairs/doors, tank repair activity and return; 47 waypoints,
  zero failures.
- golden1: existing first-shift ritual, inspection, hardware procurement,
  return and physical repair; 92 waypoints, zero failures.
- household: 105 checks of actual save storage and reconstruction, old-save
  defaults, and immediate circuit-event capture; zero failures.
- title: six actual Continue-launch checks; zoo: 48 teleport/pointer/return
  checks; both pass windowed.
- mina-laundry: outward and return scheduled journeys, 130.7 metres and 7,097
  capsule/door checks, with no failures. The first mail test caught a desk
  corner-cut; after adding the clear turn, mina-mail2 passes both journeys,
  100.8 metres and 5,607 capsule/door checks.

Windowed home, bathroom, roof plant and interaction frames were inspected.
Early runs found shared-wall duplication, an obstructing table and a stove
blocking the kitchen cross-passage; those were corrected. Blockout tests now
stop on schema refusal instead of cascading into null-node errors and timing out.

Final current-source and committed verification receipts supersede the focused
iteration logs above. The candidate verifier compares against the clean base
board and repeats selected runtime suites in this canonical checkout.

## Remaining work

Basement support rooms, continuous basement service-stair access, lift machinery,
modeled service distribution and brighter primary voxel lighting remain work.
New homes reuse existing assemblies and do not claim a finished resident art
pass. The supported first case remains Mina's existing maintenance loop.
Known H23 optical/ecology seams remain separate from construction validation.
The existing zoo renderer teardown warning also recurs: 422 unpaired-light
messages versus 338 in the prior cutover run. It is not relabeled as an H23
acceptance or hidden by the passing 48 gameplay assertions.

Owner decision: none required for this implementation slice. Continue the
remaining architecture and lighting work without waiting for another prompt.

Changes outside expected boundary: roof generator record ordering now preserves
other construction owners; its new cross-owner regression test prevents a valid
projection from making another owner's freshness check stale. Headless lamp
composition skips GPU-field allocation when no rendering device exists while
retaining the ordinary light and thermal owner.
Checkpoint-bound sources use LF hashes and explicit -text attributes.

MERGE-CANDIDATE: the commit introducing this report on main.
