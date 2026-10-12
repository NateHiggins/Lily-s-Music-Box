# V2 roof access spatial checkpoint — 2026-10-12

Evidence class: **CHECKPOINT**. Status: **IMPLEMENTED — SCOPED SPATIAL PROOF**.
This checkpoint records the current played roof circuit and both access cores.
It does not grant runtime authority, human acceptance or whole-building navigation.

## Exercised spaces

The existing production-controller circuit ascends from F06 through
`ROOF_PUBLIC_CORE`, opens and closes the original public door, crosses
`ROOF_DECK_WEST`, and approaches the existing tank service mechanism.
It then walks through `ROOF_DECK_SOUTH`, `ROOF_DECK_SOUTHEAST`,
`ROOF_DECK_EAST`, `ROOF_DECK_NORTHEAST`, `ROOF_DECK_NORTH` and
`ROOF_DECK_MIDDLE` to `ROOF_SERVICE_CORE`. The original service door opens,
the service stair descends to F06 and ascends again, and the same circuit returns
through the public door and public stair to its F06 start.

Final **roof1.log.receipt.json** completes windowed in **206.31 seconds**:
**53 walked waypoints, zero failures and zero script errors**. Only the initial
F06 placement is explicit; all subsequent walked legs use production movement
and collision. The test checks fitted floor at roof targets, all four solid
perimeter barriers, a physical capsule stop at the west parapet, and the open
chimney mouth with actual masonry collision. No noclip or disabled collider
supplies the walked route.

The existing tank's ordinary player E opens its maintenance interface. Aborting
restores mechanism state and movement; reopening uses the same player interaction.
The test submits the existing director's authored verbs, observes the serviced
valve/overflow state and returns to the original stairs. It does not claim that
all service verbs were driven by physical input, or that lift servicing exists.

## Geometry, finish and scope

Existing native tank, guarded lift machinery, deck and roof weathering are
retained. Primary PBR material sampling now uses authored UVs. Source-owned
procedural wall/slab charts preserve physical metre scale without changing
position, topology, normals, tangent handedness or collision. The composed
surface sweep checks the whole loaded V2 world independently of this route.

The morning west-roof, deck/bulkhead and serviced-tank frames were inspected.
The neutral Blender tank/drive review and separate production noon plant views
show the existing models with their current UV-sampled maps. The machinery
bulkhead remains dim; these images do not certify finished photorealism or
adequate maintenance task lighting. Finish calibration remains an art review item.

The route writes a trace and wrapper suite-run receipt, not a schema-2 authority
receipt. No save/reconstruction, denial or resource-retention status follows
from it. Separate current first-slice authority proof remains separately scoped.
At this earlier checkpoint, generic source purposes did not identify the
tank/machinery functions. The subsequent October 12 roof-program spatial access
checkpoint records the source-owned purposes and a new bound nine-space route.
That later proof supplies the current scoped coverage.

Packet: **art/renders/orison_v2/uv_application_20261012**. Full V2 remains incomplete.
