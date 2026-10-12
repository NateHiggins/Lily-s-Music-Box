# V2 apartment spatial access checkpoint — 2026-10-12

Evidence class: **EVIDENCE**. Automated spatial-access checkpoint only.
Status: **19 rooms reached through ordinary production movement; runtime and human acceptance remain separate.**

## Executed scope

The test instantiates one production-selected V2 world and runs two existing
controller routes. Each floor leg has exactly one initial placement. All 89
subsequent waypoints use ordinary movement with collision enabled: 57 through
2A/2B on F02 and 32 through 4B on F04. There is no claim of walking between
floors. Resident scheduling is paused for this focused player-access test.

The following rooms have successful actual controller positions within their
current authored boundaries. These are the only spatial promotions claimed:

- `F02_A_BATH`
- `F02_A_BED`
- `F02_A_KITCHEN`
- `F02_A_MAIN`
- `F02_A_PRIVATE_HALL`
- `F02_A_VESTIBULE`
- `F02_B_BATH`
- `F02_B_BED`
- `F02_B_KITCHEN`
- `F02_B_MAIN`
- `F02_B_PRIVATE_HALL`
- `F02_B_VESTIBULE`
- `F04_B_ALCOVE_APPROACH`
- `F04_B_BATH`
- `F04_B_CLOSET`
- `F04_B_KITCHEN`
- `F04_B_MAIN`
- `F04_B_PRIVATE_HALL`
- `F04_B_VESTIBULE`

## Interaction evidence and limits

Doors are operated through the real player ray, prompt and E input. Closed
apartment entries recover their solid barriers. The 2A and 4B kitchen valves
exercise hot-only, mixed, cold-only and both-off states. The 4B route also uses
the lavatory valves, shower/curtain and toilet flush/refill, and reaches the
closet. The 2B leg proves physical room access and doors; it does not exercise
all household appliances. The 4B sleeping alcove is not visited or promoted.

The final test passes **154 checks, 19 room positions and 89 waypoints**, with
zero failures and zero script errors. The root and both route drivers retire.
Godot reports seven Texture RID leaks at shutdown; this checkpoint does not
claim resource-clean teardown. It does not grant case completion, disk save
reconstruction, whole-building navigation or human acceptance. The reviewed
input captures retain the gameplay service-wire overlay and are access
illustrations, not an aesthetic acceptance packet.

## Bound proof and invalidation

Test: **game/tests/OrisonV2ApartmentAccessContractTest.tscn**.
The test-authored schema-2 contract is committed at
**art/renders/orison_v2/apartment_access_20261012/runtime_contract.json**.
The accompanying **final.log.receipt.json** is only the wrapper execution
record. The earlier unpromoted diagnostic lacks the added geometry binding.

The SPATIAL_ACCESS checkpoint channel validates the receipt before admitting
any room: current runtime and geometry/surface digests, normalized hashes for
the root and transitive test helpers, passing checks, actual movement traces,
room containment and measured root/driver retirement. An unvisited room cannot
be promoted by adding its name here. Changed geometry or route code expires
this proof until reverified. The channel grants spatial proof only.

Eight mutation tests cover stale helpers, omitted dependencies, changed runtime
or geometry, failed/short walks, invented room claims, retained roots and malformed
receipts, including actual ledger admission and expiry. The existing 108 ledger
tests also pass. Clean candidate **6faf490e** passes against the recorded
**4be49f1d** baseline with zero regressions, all 17 protected paths unchanged,
selector V2 and zero document lint errors. No exemptions were used. The
comparison ran in the clean temporary checkout with **--no-godot**; the bound
runtime receipts above provide the separate execution proof. The four changed
gate files were reviewed: they add validated spatial intake and dependency
records, test rejection of stale or invented claims, and isolate the historical
acceptance fixture from the new checkpoint. No runtime or human acceptance
threshold is relaxed. Fifteen requirement statuses improve, reducing structural
blockers from 115 to 103 and production-cutover blockers from 132 to 120.
The comparison is retained in the packet as **verification.json** and
**verification.md**.

## Remaining scope

The first-slice runtime and surface qualifications remain separately bound.
Other rooms, floor circulation, service continuity, case authority contracts,
human navigation and the eleven-beat golden-shift acceptance remain open.
No owner decision is requested by this checkpoint.

## Bedding geometry renewal

The current test-authored room receipt was renewed after the October 12 bedding
polish, with the same rooms, route scope and passing check counts. Its wrapper
is **art/renders/orison_v2/bedding_polish_20261012/final-apartment-access.log.receipt.json**.
The original wrapper and images above remain historical; this renewal grants
no additional requirement status or human acceptance.

## Roof-program runtime renewal

The room receipt was renewed after the roof purpose and carried-light rotation
changes, with the same 19 rooms and 154 passing checks. Its wrapper is
**art/renders/orison_v2/roof_program_20261012/apartment-access.log.receipt.json**.
Earlier wrappers and images remain historical; the scope is unchanged.

## Bathroom tile renewal

The same 19-room, 154-check circuit passes after the bathroom tile/UV update.
The current receipt is bound to those inputs; its wrapper is
**art/renders/orison_v2/bathroom_tiles_20261012/apartment-access.log.receipt.json**.
Scope and acceptance thresholds are unchanged.
