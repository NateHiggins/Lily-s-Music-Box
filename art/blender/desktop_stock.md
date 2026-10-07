# Native desktop stock and Vantry

Evidence class: **INERT**. Build guide and scoped visual QA.

All 55 original passive tabletop records now use one prepared native asset:
1,171 closed stocks, 130 material partitions and 520,548 triangles. Ten recipes
cover mugs, dish racks, papers, headphones, jars, parts trays, books, cables,
containers and the site model. Existing identities, poses, support owners and
passivity remain. Thin shells, curved handles, bound pages, individual washers,
formed trays and continuous cable jackets replace primitive stock. Twenty-eight
source container overlaps are separated within their existing supports.

The surface-stock builder and its local/context inspectors check 129 bearings
across 26 supports, using native work tables, retained furniture triangles and
source-asserted drainboard ribs. Native stock and neighbouring lamps are checked
for intersection. Existing catalogue maps receive local finish parameters;
clear containers use the existing Glazing shader. This is a transparent Fresnel
approximation without refraction. No new maps or catalogue keys are added.

The Vantry builder produces 107 closed stocks, six partitions and 25,644
triangles, with four bearings on its actual native desk. Its subclass preserves
the original terminal actor, interactions, stage transitions, scope, meter
pivots, annunciator, light and dynamic material owners. Fixed cabinetry and the
ValveBank glass mesh receive native geometry. Three hollow valve envelopes have
seated sockets, cathodes and plates. The existing meter needles are placed on
their original pivots, repairing the old keep-global reparent error.

Five task-lamp variants retain exactly their physical triangle positions,
scene graph, switch/emitter datums and original behavior. Their revised corner
normals, continuous turned-stock charts and local metal finish remove radial
faceting and texture stripes. The dependency comparison refreshes only the
lamp-native hash in reading-nook/work-table provenance; those dependent assets
are unchanged and their earlier visual acceptance is not renewed.

Use **run_fabrication_batch.py** with the surface-stock and signal-terminal
builders, their local/context inspectors, then renderers. The shared
**fabrication_chart_batch.py** vectorizes metric charts with the original
float32 fallback; **fabrication_normals.py** preserves sharp edges while
averaging adjacent curved faces. All existing metric/tangent checks remain.
The 55-prop builder took 22.16 seconds in one combined run and about 40 seconds
under another load; these are observations, not a controlled benchmark.

After one import for changed exports, use the serial Godot lane with modules
**surface_stock,signal_terminal,work_tables,reading_nook,task_lamps** and captures
**surface_stock,signal_terminal**. Script/metadata fixes need no import. The
final batch passes 3,759 module checks plus 16 batch checks in one world.
Its wrapper takes 58.13 seconds. Seven texture RIDs still leak at shutdown.

Review packet: **art/renders/orison_v2/desktop_stock_20261007**. Native form and
composed appearance are reviewed; broad room lighting, neighbouring furniture,
external lamp cords and whole-building material acceptance remain open.
