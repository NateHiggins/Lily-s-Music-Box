# Basement foundation and coal fabrication

Evidence class: **INERT**

The lowest primary stair inherited the open central landing used upstairs.
Twelve downward rays missed all floor collision, and the before render showed
an open void. **B1_PRIMARY_STAIR_BASE** now fills only that missing rectangle
through **vertical_services_source.json** and its existing projection builder.
The passenger lift pit is outside this rectangle and remains unchanged.
This flat concrete slab is intentionally simple geometry, not a Blender prop.

The coal delivery now installs **coal_heap.blend** / **coal_heap.glb**, rebuilt
with **art/blender/scripts/build_coal_heap.py**. The closed faceted mound,
angular surface lumps and scattered pieces replace fourteen stepped boxes.
The old fixture identities remain, with their rendering and collision disabled.
The new single mesh has 2,910 triangles and collision from its rendered faces.
The existing chute, pavement cover and boiler firing authority are preserved.
Metre UVs and the existing soot finish are retained; the brown appearance under
the production lamp still needs the coordinated material pass.

Focused windowed runs completed with zero failures: foundation 12 contacts and
11 walking waypoints, including the primary stair; coal nine contacts and 32
waypoints through the delivery route. Clear player-height renders were directly
inspected. Before/after evidence is under **tmp/basement-foundation** and
**tmp/coal-heap**. Final candidate checks belong under
**tmp/basement-foundation/verified**. Wrapper receipts are suite-run evidence,
not runtime contracts or whole-building acceptance.
