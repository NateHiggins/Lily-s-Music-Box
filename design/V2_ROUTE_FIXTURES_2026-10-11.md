# V2 shaft-clear route fixtures

Evidence class: **INERT**. Section 7 implementation report.

Starting main / origin: **d9b68621**. Verification baseline: **d62ef031**,
its complete clean board reused unchanged; the intervening commit is an archive.

Two standing route failures were caused by test waypoints through occupied
geometry. The current M08E baseline reproduces a blocked move from
**(1.467546, 0.230791, -3.057791)** toward **(0, 0, -1.5)**, against
**PASSENGER_SHAFT_EAST**. The target lies inside the passenger shaft. The
integrated fixture's **x=1.4, z=-2.5** stair-exit point also overlaps that wall
with the review capsule. No shaft wall or collision needs removing.

Both fixtures now use the established north-of-shaft approach at **z=-3.45**
and west-side clearance at **x=-1.8**. Stair exits use the upper landing before
crossing the core. All ritual/service destinations, stair flights, adapter,
save/reload, acoustic and compatibility assertions remain. No tolerance, capsule,
physics algorithm, production waypoint, geometry or material is changed.

Final long-runner receipts:
**m08e-route2.log.receipt.json**, 85 seconds, eight assertions and zero failures;
**integrated-route1.log.receipt.json**, 46 seconds, twelve assertions and zero
failures. M08E walks the complete boiler-to-ritual-to-2B-to-porter-to-boiler-to-
radiator route. Integration walks continuously from street to bedside through
three storeys, with original adapter/acoustic teardown and save compatibility.
These are isolated review-world routes, not full production-world navigation
acceptance. Wrapper suite_run receipts grant no ledger promotion.

The original failing baseline remains in the packet. One retry reached the
serial runner's default 60-second ceiling; it has no verdict. Its completed
long-runner retry is the final M08E evidence. A mistyped scene request also
failed to start and is diagnostic only.

Spatial consumers: zero drift. Two source and one packet Git attributes preserve
hash-bound bytes across Windows checkouts. Production runtime inputs are
unchanged: the first-slice proof and prior surface reviews remain valid.
Ledger blockers remain **0/1/127/35/144/146**. Broad V2 completion, human review,
services and acoustics remain open. Decision needed from owner: none.

Packet: **art/renders/orison_v2/route_fixtures_20261011**.
Fresh verification: **a64b8f87** against **d62ef031**, clean fresh checkout,
53 gates, zero regressions, no changed gate files, 17/17 protected paths
unchanged, selector V2 and zero lint errors. Requirement statuses are unchanged;
the first-slice technical scope remains clean. **verification.json** archives
the result. Fresh verification reuses the two completed bound runtime suites
with **--no-godot**; unchanged production visuals need no recapture.
The generated completeness ledger is refreshed to these current statuses.

MERGE-CANDIDATE a64b8f87a1a176b50df064d928c77523e7d43fb0
