# Upper resident and kitchen surface objects

Adds 29 source-authored objects, bringing fixed surface dressing to 55 records:
eleven kitchen mugs/dish racks, Nadia's site model/two paper groups/two mugs,
Cal's headphones/lead, Iris's solvents/studies, Sacha's headphones/cans/papers/mug,
Jonah's draft/references/cold coffee, and Mae's oddments/catalogues.

All geometry comes from the existing authored assemblies, preserving per-ID
variation and material identities. Nadia's model uses her model table; the
additional papers avoid the plans already baked into her drafting table. Her
second mug uses the plan shelf. Sacha's objects use his existing desk. Cal, Iris,
Jonah and Mae currently use their existing dining tables as shared work surfaces;
this does not claim that their separate equipment and workroom programs are done.
The six kitchen drainboards receive only their source objects; Mae has no extra
mug invented. The original kitchen aggregates remain uninstalled.

The generator in `work/v2_upper_surface_props_01/build.py` reconstructs from
`2953357`, appends 12,712 source triangles, and preserves all previous records.
Checks include four-corner support contact or native drainboard ribs, room
containment, existing furniture/accessory/detail overlap, room-door sweeps,
material availability and clearance of baked tabletop details. Objects follow
actual supports and add no collision, input or persistence owner. The runtime
loader admits the six upper households and the existing site-model assembly.

The final serial Godot apartment regression passes **18,332 checks**, with empty
stderr. It checks all 55 surface objects, transforms, material surfaces, rejected
missing/duplicate supports, established household systems and two-world teardown.
The first run exposed a stale lower-only test counter dictionary; that test was
stopped, the counter roster was expanded, and the complete suite was rerun.
`apartment_batch.log` retains the rejected attempt; only `apartment_batch_final`
is completion evidence.

`surfaces_01` contains fourteen unedited 1280x720 production views, one per
support group. The campaign is November 10, 1928 at 20:00. Player movement/input
are frozen, but native room lighting and the live carried voxel field remain
active. No fill lights, replaced materials or hidden architecture are used.
`comparison.png` is a labelled, resized contact sheet. All views were inspected:
the model, papers, mugs, dishes, desk and table objects are visible on their
supports. Iris's transparent solvent vessels remain faint, and strong window
highlights/shadow transitions remain material/lighting review items. The held
lamp obscures part of some close views; this is not full visual acceptance.

Run retained-evidence/source verification without Godot:

```powershell
python design/astra/work/v2_upper_surface_props_01/check.py
```

`receipt.json` binds source and log/capture hashes. Furniture, layout, fittings,
heating, bathroom/accessory records, material catalog, runtime root and selector
are preserved. Continue wall storage, bookshelves and resident equipment/media,
then remaining residential/shared/service programs, utilities and migration.
V2 is incomplete; V1 remains default and S2J remains open.
