# V2 remaining apartment spatial access checkpoint â€” 2026-10-13

Evidence class: **EVIDENCE**. Automated spatial-access proof only.

One production V2 world hosts nine independent apartment legs: 3A, 3B, 4A,
5A, 5B, 5C, 6A, 6B and 6C. Each leg receives one initial placement outside
its entry. All subsequent travel uses the ordinary standing player controller,
with collision enabled. This does not prove travel between floors.

Doors use the actual player target, click-grab, mouse motion and second-click
release. Collision queries plan routes; they do not move the player. Low-step
support and floor-edge sampling corrections are detailed in
**design/V2_APARTMENT_CLEARANCE_2026-10-13.md**. The only production layout
change rotates the 5B deck and its supporting table together.

## Executed room scope

- `F03_A_BATH`
- `F03_A_BED`
- `F03_A_KITCHEN`
- `F03_A_MAIN`
- `F03_A_PRIVATE_HALL`
- `F03_A_VESTIBULE`
- `F03_B_ALCOVE`
- `F03_B_BATH`
- `F03_B_KITCHEN`
- `F03_B_MAIN`
- `F03_B_PRIVATE_HALL`
- `F03_B_VESTIBULE`
- `F04_A_BATH`
- `F04_A_BED`
- `F04_A_KITCHEN`
- `F04_A_MAIN`
- `F04_A_PRIVATE_HALL`
- `F04_A_VESTIBULE`
- `F05_A_BATH`
- `F05_A_BED`
- `F05_A_KITCHEN`
- `F05_A_MAIN`
- `F05_A_PRIVATE_HALL`
- `F05_A_STUDY`
- `F05_A_VESTIBULE`
- `F05_B_ALCOVE`
- `F05_B_BATH`
- `F05_B_KITCHEN`
- `F05_B_MAIN`
- `F05_B_PRIVATE_HALL`
- `F05_B_VESTIBULE`
- `F05_C_BATH`
- `F05_C_BED1`
- `F05_C_BED2`
- `F05_C_KITCHEN`
- `F05_C_MAIN`
- `F05_C_PRIVATE_HALL`
- `F05_C_STUDIO`
- `F05_C_VESTIBULE`
- `F06_A_BATH`
- `F06_A_BED`
- `F06_A_KITCHEN`
- `F06_A_MAIN`
- `F06_A_PRIVATE_HALL`
- `F06_A_STUDY`
- `F06_A_VESTIBULE`
- `F06_B_ALCOVE`
- `F06_B_BATH`
- `F06_B_KITCHEN`
- `F06_B_MAIN`
- `F06_B_PRIVATE_HALL`
- `F06_B_VESTIBULE`
- `F06_C_BATH`
- `F06_C_BED1`
- `F06_C_BED2`
- `F06_C_KITCHEN`
- `F06_C_MAIN`
- `F06_C_PRIVATE_HALL`
- `F06_C_STUDIO`
- `F06_C_VESTIBULE`

The test-authored schema-2 contract records 781 passing checks (782 executed
including the final output-flush check), reaches
all 60 rooms and records zero failures. All nine route drivers and the
production root retire. Seven Texture RID shutdown warnings remain; this is
not a claim of resource-clean engine shutdown.

## Proof and limits

**art/renders/orison_v2/remaining_apartments_20261013/runtime_contract.json**
binds the production runtime, geometry/surface inputs, root test and transitive
helpers. The spatial validator checks those bindings, successful checks,
collision-bearing traces, room-contained actual positions and teardown.
**remaining.log.receipt.json** records execution only.

Earlier failures remain in **diagnostic/** within that packet. The final run
passes the previously intermittent 5C gesture; it does not establish that
intermittent input failures are eliminated. The earlier 2B closing observation
belongs to the separate existing-apartment contract and remains recorded.

This checkpoint grants spatial access for the listed rooms only. It grants no
whole-building route, appliance coverage, case completion, save/reconstruction,
human aesthetic acceptance or V1 retirement. Changed inputs expire the proof.
