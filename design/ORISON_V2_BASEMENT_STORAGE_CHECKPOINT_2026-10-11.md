# V2 basement resident storage spatial checkpoint — 2026-10-11

Evidence class: **CHECKPOINT**. Status: **IMPLEMENTED — SCOPED SPATIAL PROOF**.
This checkpoint covers resident-storage spatial use only. It grants no
RUNTIME_PROVEN authority, whole-building navigation or human acceptance.

## Physical correction

`B1_RESIDENT_STORAGE` now contains seventeen resident cages; the eighteenth,
4A, occupies `B1_STORAGE_NORTH_BAY`, reached from the existing east aisle.
All eighteen have 1.50 × 2.10 m clear fixed-panel dimensions. Their original
open/folded gate fabric remains open; no new cage keys or quests are invented.
The central aisle is 1.09 m and the east aisle 1.12 m. The south-row gap retains
the actual west wet stack. The existing controlled room door is retained.

The north bay uses a 1.20 m opening in the shared boundary. Exterior masonry
is regenerated from the schema to remove its obsolete leaf across that opening.
Above-ground masonry triangle geometry, normals and UVs compare equal at
0.00001 tolerance; this is a measured tolerance, not byte identity.

Sixteen existing native resident stock anchors retain their models and meanings.
Their installations move into the corrected bays; 4A's case turns into the new
bay. Native vertex bounds, floor bearings and fixed-panel clearances are reviewed
in Blender. 2C and 4D retain their existing empty cages. No stock is fabricated
as proof of a gameplay inventory or locked-trunk interaction.

## Native construction and rendered proof

Five shared modules each separate timber and iron, giving ten source-owned
native parts. Timber has longitudinal metre UV charts; fasteners, feet and
hinges use the existing neutral iron catalogue PBR recipe. The imported native
asset has 7,268 triangles and zero collapsed UV triangles with ordinary import
compression. Native visible mesh shapes provide cage collision.

The Blender overview, central aisle and north-bay images were inspected before
the final Godot run. The composed resident-storage view shows timber grain,
open gates, original labels and the usable central aisle. The handheld device
obscures its right side; it is not evidence of all stock or all surfaces.

Final **route4.log.receipt.json** completes windowed in **165.22 seconds**,
with **104 walked waypoints, zero failures and zero script errors**. The original
production controller walks to every cage and returns, including the new north
bay, through the controlled room door. The same route preserves the electrical
service abort/reopen/complete, shop, laundry, boiler and stair legs. No noclip or
collider disabling supplies a walked leg.

The route trace and suite-run wrapper prove this scoped played route. This test
does not write a schema-2 runtime authority receipt, so no save, reconstruction,
denial or resource-retention claim follows from it. Separate first-slice and
surface receipts are renewed for changed production inputs.

Packet: **art/renders/orison_v2/basement_storage_20261011**. Earlier rejected
routes are diagnostic only. Full V2 remains incomplete.
