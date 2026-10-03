# Remaining V2 homes and staff sanitation — spatial checkpoint

Evidence class: **SPATIAL CHECKPOINT**

This checkpoint grants spatial evidence only. It is not a schema-2 runtime
contract, human acceptance, whole-building navigation/performance proof or
retirement authorization. It supersedes earlier absence reports only for the
rooms explicitly listed below.

## Executed method

The production V2 root built the authored geometry and reused production
furniture, doors and fittings. OrisonV2CompletionInteriorsTest passed 144
waypoints with zero failures in a windowed Forward+ run. Each home begins with
one explicit placement in its outside hall; thereafter the actual player walks
through its entrance, living/distribution spaces, every bedroom, kitchen,
bathroom and storage/work room, then returns. Door handles and independent
hot/cold valves receive ordinary E input. No noclip, collision removal, added
fill light or replacement test geometry is used. Staff sanitation is tested
from the real service hall in the same way.

The new southwest storage doorways enter from bedrooms, clear of kitchen
counters. Central household storage and both bedrooms are included. The
independent blockout test passed 2,013 assertions, including authored identities,
wall-extension ownership, exterior-window placement and existing route gates.
Source projection tests preserve unrelated records and keep the lift well open.

Logs and suite-run receipts: tmp/v2-completion/rooms7.log and
rooms7.log.receipt.json; blockout2.log and blockout2.log.receipt.json.
The route's measured coordinates and collision contacts are in
 tmp/v2-completion/rooms7/route.json. Windowed bedroom, bathroom and storage
frames in the same directory were visually inspected. These wrapper receipts
and images support this spatial checkpoint; they are not runtime_contracts.

## Spatially checked rooms

| Home | Authored spaces reached by the route |
| --- | --- |
| 1A | `F01_A_VESTIBULE`, `F01_A_MAIN`, `F01_A_PRIVATE_HALL`, `F01_A_BATH`, `F01_A_KITCHEN`, `F01_A_BED`, `F01_A_STUDY` |
| 1D | `F01_D_VESTIBULE`, `F01_D_MAIN`, `F01_D_KITCHEN`, `F01_D_BED`, `F01_D_PRIVATE_HALL`, `F01_D_BATH` |
| 2C | `F02_C_VESTIBULE`, `F02_C_MAIN`, `F02_C_STUDIO`, `F02_C_PRIVATE_HALL`, `F02_C_BATH`, `F02_C_KITCHEN`, `F02_C_BED1`, `F02_C_BED2` |
| 3D | `F03_D_VESTIBULE`, `F03_D_MAIN`, `F03_D_PRIVATE_HALL`, `F03_D_BATH`, `F03_D_KITCHEN`, `F03_D_BED`, `F03_D_STUDY` |
| 4C | `F04_C_VESTIBULE`, `F04_C_MAIN`, `F04_C_STUDIO`, `F04_C_PRIVATE_HALL`, `F04_C_BATH`, `F04_C_KITCHEN`, `F04_C_BED1`, `F04_C_BED2` |
| 4D | `F04_D_VESTIBULE`, `F04_D_MAIN`, `F04_D_PRIVATE_HALL`, `F04_D_BATH`, `F04_D_KITCHEN`, `F04_D_BED`, `F04_D_STUDY` |
| Staff | `F01_STAFF_RESTROOM` |

## Limits

Separate elevator, public-stair, roof, mail, laundry and first-repair suites
exercise shared circulation, but this room checkpoint does not merge their
partial routes into a single full-building proof. Sealed apartments remain
locked and their interiors are not admitted here. New homes reuse existing
assemblies and do not claim completed resident-specific art, new cases,
complete service distribution or a heating installation in every new room.
Existing optical/ecology debt is unchanged.

## Source binding

These LF-normalized hashes identify the tested source and construction inputs
for this checkpoint. Later edits need new verification; this document is not a
blanket acceptance of future geometry.

- game/tests/orison_v2_completion_interiors_test.gd: 200c0dd78daf14ec84b7c2e633aaaf8f28939bea45b9b99d9ea600ae8c87cfab
- art/data/orison_v2/completion_interiors_source.json: 83d9eab3bfdb91ed01778eae64a9b4796af1d70d794f378b402b985d7605ba76
- game/data/orison_v2/completion_interiors.json: e79cf7de051bdf25ac16c9c7c3a8bb2c7f3165c9e5b071d376ebe60a7491642b
- game/data/orison_v2_blockout.json: f4133c2df4d296897e105a609ebbb9a95602571e5cf3a2f9517605242a952e7e
