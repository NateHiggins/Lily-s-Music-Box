# REPORT — V2-APARTMENT-KITCHEN-ROUTE — 2026-10-12

Evidence class: **INERT**. Scoped route report; no ledger promotion.

Branch / starting HEAD: **main / 0f5d92ea**.
Owner decision required: **none**.

## Change and reason

The existing two-apartment route bypassed Mina’s kitchen. Its unfinished
extension initially aimed through the caption desk and then the solid wall
beside the kitchen opening. The completed extension passes between the work
tables, approaches the actual 810 mm opening at x=-12, visits the sink and
returns to the original door circuit. Furniture, walls, controller and
interaction geometry are unchanged. The spatial manifest registers the
sink identity and route coordinates as test dependencies.

## Verification

The production-composed windowed run **apartment-route3.log.receipt.json**
completed with **57 waypoints, zero route failures and zero script errors**.
One initial placement precedes ordinary controller movement for the full
route. The real player interaction ray and E input operate hot-only, mixed,
cold-only and both-off states. The route continues through both apartments,
opens and closes physical doors, and confirms the closed entry barriers.
Normal collision remains active. The archived input capture was reviewed;
the service-wire overlay remains visible because this is a gameplay route.

The preceding failed wall-approach receipt is retained as a diagnostic.
These wrapper receipts and route traces are not schema-2 runtime contracts
and do not promote apartment completeness. Existing bound surface evidence
still passes with zero defects; no rendering input changed. The reader gate
reports zero new unread fields. Clean candidate **25840bed** passes the recorded **09d0d75d** baseline
with zero regressions, all 17 protected paths unchanged, selector V2, and
zero lint errors. No exemptions were used. The clean temporary checkout
comparison used **--no-godot**; the canonical played route above supplies
the separate runtime result.

## Remaining work

Full V2 still has structural, program, runtime and human-navigation acceptance
requirements. The eleven-beat golden shift explicitly requires human acceptance.
This route closes the outstanding kitchen-access test extension only.

Packet: **art/renders/orison_v2/apartment_kitchen_route_20261012**.
