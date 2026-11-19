# Boiler instrument connections and handle clearance

Evidence class: **INERT**

Close before views showed a closed water-glass handle passing through the tube
and a pressure-needle hub turned sideways relative to its dial. Four side rays
also passed through empty casing/column/gauge/blowdown joints. Blender-fabricated
bosses, nipples, union and packing nuts now join those parts. Two slim guards
seat in clips at the glass glands. The handle pivots project 50 mm forward onto
their spindles, clearing the glass and guards in open and closed poses. The
needle hub now faces its dial; its moving root is preserved.

Export **boiler_instruments.glb** from **art/blender/boiler_surface_refit.blend**
with **art/blender/scripts/export_boiler_surfaces.py**. The original fabrication
source is **boiler_instruments.blend**, built by **build_boiler_instruments.py**.
The fixed groups use the existing brass, steel and iron bindings. Their metre
UVs stay separate from the procedural batches, and collision derives from the
same triangles. Water level, witness, needle, valve actions, areas, maintenance
state, heat and saves retain their existing owners.

The focused production check passes four formerly empty mounting contacts and
four moving-handle poses, with actual triangle/collision comparisons. Before
and after views were directly inspected under **tmp/boiler-instruments**. The
first close view was obscured by the carried overlay and was recaptured with
only that overlay hidden. A local inspection fill exposes the small joints.
Final boiler/body/door/service-route/title candidate receipts belong under
**tmp/boiler-instruments/verified**. No runtime-contract acceptance is claimed.
