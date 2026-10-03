# V2 roof water tank and service approach

Evidence class: **INERT**

REPORT - V2-ROOF-PLANT - 2026-09-25

Branch / base / origin/main at start / merge-base: main /
29a3078576115374ea116b26d6d6cabe398e691d (all three references).
The implementation HEAD is the commit introducing this report.

Dirty tree before work: owner render notes and shot_024 through shot_026.
Those four files are excluded from this change. Committed-tree verification
temporarily preserves them in an ignored, hash-checked backup and restores
them afterward. Imports create untracked UID sidecars; only those generated
sidecars are removed. No additional checkout is created.

Protected 17/17: no protected path edited. Selector remains V2 with explicit
V1 rollback. Historical evidence and current requirement gates are unchanged.

Ledger before -> after: 7/8/136/50/159/161 -> 7/8/136/50/159/161.
Requirements changed: none. The tank is a fixture, not proof of the entire
roof tank/machinery program. Suite-run receipts do not promote requirements.

## Implemented scope

The roof source now projects a raised 2.8 by 2.2 by 2.3 metre timber tank,
four 1.6 metre iron supports, lid, binding bands and an open overflow butt.
These reuse the existing tank dimensions and shipped timber/iron materials.
All masses have corresponding collision. The new V2 placement clears the
public door and the west/south perimeter walks.

The runtime mounts the existing RoofTankBallcockProp at an authored service
anchor. Its float, valve, overflow, maintenance director and guarded repair
result remain the existing production systems. Ordinary E reaches the service
control from the deck; abort restores the mechanism and releases movement.
Completing the activity stops the overflow and returns movement.

This is instance-local maintenance. It creates no campaign job, saved repair,
or apartment water source. The existing boiler/hot-water authority is unchanged.

## Gates and executed checks

The initial full static board at tmp/v2-roof-plant/board found only two new
test references missing from the spatial manifest. Both were reviewed and
admitted. The final spatial scan is clean with the same four pre-existing
cleanup opportunities. In total the manifest admits eleven tank dependencies
and updates three existing tank resolutions to include V2; preservation
obligations are unchanged. Reader gate: zero new unread fields. Roof projection
check and both generator tests pass. The existing m11c1 runtime-rehearsal hash
failure remains baseline debt; no exception or weakened gate was added.

The approved lane ran double import, then windowed route and title tests.
Logs below have adjacent .receipt.json files:

- tmp/v2-roof-plant/route3.log: 47 waypoints, zero failures. Real movement
  through both roof stairs/doors, maintenance approach and E entry, abort and
  re-entry, five production director verbs, input release, live controller
  stopped by a support, collider rays through all four supports and the tank,
  perimeter/deck traversal, and return to F06. Maintenance verb values are
  submitted through the director; this does not claim mouse-driven repair.
- tmp/v2-roof-plant/title.log: actual title Continue, six checks, zero failures.
- tmp/v2-roof-plant/blockout.log: 1,563 PASS lines, exit zero.
- tmp/v2-roof-plant/ballcock.log: existing mechanism/activity regression passes.

Rendered wide/close tank views in tmp/v2-roof-plant/shots3 were inspected.
Early test iterations incorrectly expected the five-foot player to hit the
1.6 metre tank underside and aimed a body ray through an iron band. Checks now
use the real support and an unobstructed patch of tank body respectively.
No collider was removed to make traversal pass.

The final committed-candidate verifier writes tmp/v2-roof-plant/verified,
compares against the clean 29a3078 board, repeats the roof/title/blockout suites,
and binds those receipts to the committed candidate. Its machine-readable
result is authoritative for final verification status.

## Remaining work and decisions

Roof lift machinery, the four shared ventilation stacks, other unfinished
architecture, brighter primary voxel lighting and known H23 seams remain open.
The new tank is readable in the morning render; night visibility remains poor.
This report does not claim the whole building or roof program is finished.

Changes outside expected boundary: none. Decision needed from owner: none.

MERGE-CANDIDATE: the commit introducing this report on main.
