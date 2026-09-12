# Apartment dining, work seating and storage pass

Placement correction: the subsequent `../v2_apartment_doors_batch_01/README.md`
packet identifies and repairs four overlaps with separately owned case tables.
The generator/receipt/inventory here now reflect those corrected placements.
The initial checks described below did not include those case owners.

Source integrated; runtime pending. No Godot launched.

Added 19 pieces across all four detailed apartments:

- Four meal tables and eight dining chairs.
- Mina's writing desk and three work chairs, including Omar's source stool
  identity and the player's desk chair.
- Lena's compact fabric-repair worktable and two vertical storage shelves.

Thirteen pieces retain existing source assembly identities and specifications.
The three-piece 4B meal group and three 2B work/storage pieces are newly authored
uses of the established assembly families, not claimed as extracted placements.
The 2B worktop is a compact 1.6-by-0.5-metre surface with a separate dining table;
it does not reproduce the old 2.5-metre planning block. Work chairs are parked
beside work areas so existing standing interactions remain usable. Sitting and
movable-chair mechanics are not introduced.

Furniture totals increase from 28 to 47. The pass adds 27 anchors, including
eight approaches. Existing furniture, fittings, semantic bindings and materials
are preserved. The V2 loader now accepts chair, round-table and rectangular-table
records through its existing static-furniture path. No shared prop is rewritten.

Composition review found that five 2B planning blocks remained visibly solid
after real furniture and fittings were installed. The playable runtime now hides
and disables the fabric-table, kitchen-run, bed, storage and bath masses only
after both replacement loaders succeed. Standalone gray-box scenes retain them;
the semantic mass nodes remain available. The batch harness asserts retirement
on each reconstruction. Earlier source receipts did not establish this behavior.

`../../work/v2_apartment_seating_batch_01/build.py` extracts geometry without
Blender or Godot, checks materials, finite coordinates, source-hull non-overlap,
room margins and clearance anchors, and samples 2,621 points along Mina's
existing graph and selected 3B/4B approach paths against the new furniture.
Omar's prepared domestic route now follows the west aisle around his meal group.
Regeneration is byte-identical and prior records are preserved. Independent
GDScript syntax parsing passes for the affected loader, root and test scripts.
Updated inventory is in the work packet's `apartment_inventory.json`.

These are geometric source estimates, not actual passage tests. Furniture hulls
remain coarse; chair/table knee clearance, new route execution, physical light
switch targeting, dynamic doors, materials, draw cost and teardown remain
unverified. The prepared batch harness covers all dining groups and mounted
furniture alongside sanitary, lighting and active-interaction teardown checks.

Next category passes: domestic storage gaps and smaller surface props, physical
doors across the detailed apartments, and the remaining source-unit room
programs. Twenty source unit IDs still lack detailed V2 apartment spaces. V2 is
not complete or art-accepted, S2J remains open, and V1 remains the default.
