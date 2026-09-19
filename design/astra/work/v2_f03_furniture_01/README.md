# 3B individual furniture — source checkpoint

Base: `80262a365e9dcf421f3546a2637eb94e4576d8ad`. Godot and Blender stayed closed.

The explicit V2 runtime now mounts Omar's original `3B_abed`, `3B_workbench`
and `3B_wc` as individual assemblies. The bed preserves the 1.4 m width,
2.05 m length, turned posts, spindle head, bedding and household wood choice.
The bench preserves its steel legs, wood top, drawer and projecting vise.
The WC preserves its porcelain bowl, seat and close-coupled cistern.

`extract.py` selects the unchanged pure geometry functions from the production
Blender source using its AST. It executes only those selected definitions in
Python; it never imports bpy or launches an engine. `extraction.json` binds the
source and generated JSON hashes. Meshes contain 1004, 252 and 328 triangles
respectively. Coordinates convert Blender (x,y,z) to Godot (x,z,-y), and triangle
winding reverses for Godot while retaining outward normals. The runtime material
library supplies triplanar textures. The bench's source `floor_oak` material has
an explicit V2 alias to `oak_quartered`; this optical choice needs visual review.
Baked contact-shadow quads are omitted in favor of native lighting.

Placement authority stays in the blockout JSON. `placements.json` is a work
recipe for verification, not another production placement reader. The first
audit caught duplicated placement metadata in the mesh file; the final file
contains only consumed identity, kind, geometry, normals and collision bounds.
Both audit runs are preserved in `../../evidence/v2_f03_furniture_01` and `_02`.

The WC uses the existing BakedFurnitureInteraction flush/refill behavior,
prompt and service card. A small V2 subclass releases its water stream and
kills its active tweens on teardown. The original interaction implementation
is unchanged. Bed and bench are visible static collision assemblies; no new
sleep behavior, operable vise, repair job or case state is claimed.

The new source checks reproduce the extraction, verify finite geometry, unit
normals and winding, contain mesh/coarse-hull bounds within finished walls,
and check all F03 capsule stations against all eight added domestic objects.
The basin stance moves 7 cm toward the basin to clear the WC. The repair stance
and reservation move in front of the bench. Existing layout records are
preserved except those four named stance/station/reservation adjustments.
Protected floor meshes, original layout JSONs, selector and original root are
unchanged. GDScript syntax parsing passes with gdtoolkit; this is not native
compilation or an actual physics query.

The prepared connected-world fixture checks the visible furniture, collision
owners, malformed triangle rejection and WC's existing refill transition on
two constructions. It remains unrun, including audio and active-refill teardown.
Visual/material quality, actual movement/input, mechanism reachability and
save/reconstruction acceptance remain pending.

Final systemic authority, interaction carriers, interaction implementors and
audio audits and their self-tests pass. Data consumption still fails globally
but has no findings against the new furniture data or loader. Completeness
still reports 114 cutover blockers. Spatial dependencies and its live-repository
self-test fail, with 29 new failing references and 18 classification changes;
there are no vanished targets or unresolved save contracts. No baseline was
refreshed to suppress these outstanding reviews.

Next source work: Omar's categorized tools and repair-work interactions, clothes
storage/nightstand and other domestic details; then remaining F03 apartments.
V2 remains unfinished, and V1 remains the default.
