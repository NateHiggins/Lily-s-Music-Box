# Harukiya resting pets

Original static first pass for Judge (old tan dog) and Lafitte (orange-and-white cat).
No rigs, animal AI, interactions, new save fields or downloaded reference pixels.
Judge belongs on the board inside the real counter recess; Lafitte has one shelf identity.

Authoritative editable sources are judge.blend, lafitte.blend and ../harukiya_pet_counter.blend.
Their original PBR images are packed. The runtime manifest owns source positions, exact counter
retirement and imported surface contracts. Existing wood_dark/timber recipes bind the counter;
PetFur/PetSkin/PetEye catalogue entries describe the original asset-owned packed maps.

Export an edited saved pet with Blender5.2 in CPU background mode:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python art/blender/scripts/export_harukiya_pet.py -- --repo C:/ov/ldv --source art/blender/harukiya_pets/judge.blend --out C:/ov/reports/pet_revision/judge.glb
```

The exporter selects only the static pet, retains UV/tangent semantics through the shared
static derivative helper and validates the exported frame. It does not render or overwrite
the blend. Rebuild the primitive anatomy studies with build_harukiya_pets.py -- FRESH_DIRECTORY;
build_harukiya_pet_counter.py -- FRESH_DIRECTORY produces the original closed recess stocks,
exact source-face witness and concave collision faces. Fresh remeshing is not promised byte-identical:
use the delivered saved source when revising the installed asset. Never hand-edit generated GLB.

Review related native views on the hidden shared lane before Godot captures. Refresh asset hashes
and the independently inspected surface manifest after export; retain original failed witnesses.
The counter cavity must remain concave: never convex-hull across it or erase source faces by bounds.
The composed surface inventory includes finite cavity/flank/board/top probes and pet views;
these probes do not assert exhaustive animal animation, continuous support, gameplay or art acceptance.

November15 draft: all native views reviewed. CPU/saved-source strict exports, engine compilation
and nearby actual-bar fixture120/0 pass, including loaded PBR/mips and exact pet mount/restore.
Full-world production surface qualification798/0 and patched-engine nearby fixture120/0 pass.
The source-bound packet is published; all23 frames reviewed. Candidate44e8fb359 passes with zero regressions; PR298 merged b48b002db.
This is a technical static first pass, not played/artistic acceptance. Judge is dark and partly
occluded by the retained footrail; the cat standing diagnostic is canopy-obstructed.
Private originals and failed witnesses: C:/ov/reports/harukiya_pets_20261115/.

The raw source witness retains its glTF -col suffix. Godot name-suffix import
strips it from the runtime draw name while creating the separate collider;
the runtime retirement manifest must name that actual imported draw.

Layout regeneration retains all eight pet catalogue entries; the persistence test
exposed the initial omission and now passes. Source-bound surface qualification02
renews798/0 after that correction; original failed candidate and old runs retained.
