# Native task lamps

Evidence class: **INERT**. Build guide, not completion evidence.

The five explicit V1 lamp markers supply the library's five silhouettes.
**art/blender/scripts/build_task_lamps.py** builds editable closed construction,
metre UV charts and **game/assets/props/task_lamps.glb** in one Blender process.
**task_lamps_geometry.py** contains the local manufacturing recipe. Existing
catalogue maps supply brass, nickel, iron, enamel, bakelite, cord, glass and wood.
There are no generated letters, labels or new material keys.

The 206 closed stocks form 34 material partitions and 61,596 triangles. Shades
are thin hollow shells with rolled rims, rather than closed solid cones. The
green variants have cased canopies and yokes. Friction joints have knurled
screws; the architect has ball sockets and a short counterweight. Each cord
enters the head and base; arm clips support its run. The original local switch
key remains a separate partition at the original pivot.

The architect's lower fulcrum rises 80 mm on a real pedestal to clear the
tabletop with its counterweight. Its elbow, wrist and emitter retain their
original datums. This is an **ADAPTATION**. The bench's old collision ceiling
was 10 mm above its visible tabletop; its authoring bounds now end at the
actual 0.91 m top. The lamp's placement and furniture's visible mesh stay fixed.

**inspect_task_lamps.py** checks closed connected stock, positive volume,
surface-connected assemblies, metre charts, all fifteen base samples and the
three actual visible bench bearings before producing ten detail views. Set
**TASK_LAMPS_RENDER=0** for fast preflight. Run it through the shared fabrication
batch runner after the builder. Linkage and base probes do not certify final
appearance: review the renders and the production-world captures.

**native_task_lamp.gd** extends the unchanged **LampProp**. It overrides visual
construction only, imports actor-local meshes, duplicates material owners and
keeps the original moving key. The inherited script still owns personality,
spotlight, budgeting, switch state, interaction, service card and audio. The
native opal bulb follows the existing light's delivered output. V1 keeps its
procedural bodies. Only the existing V2 bench lamp currently uses this library.

Run the **task_lamps** module in **OrisonV2FabricationBatch** to compare all five
native variants against their original LampProp behavior in one world load,
then check the installed lamp's physical support and capture its room/detail.
Use one warm import after asset changes; script-only changes need no import.

Four original lamps still need source-derived V2 supports and electrical
identity placement. The external supply cords also remain unfinished. The
library, one installed actor and these bounded checks do not complete V2 or
certify the wider household furniture pass.
