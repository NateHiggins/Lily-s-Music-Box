# Reading nook and fitted task lamps

Evidence class: **INERT**. Build and inspection guide.

The fifteen original basement records now form one Blender composition:
the rug, three seats and aprons, two cushions, folded throw, coffee table,
57-volume shelf, three table books, mug and plant. The composition rotates
180 degrees onto the existing north basement landing, at the V2 floor datum.
Original source records stay intact.

**build_reading_nook.py** and **reading_nook_geometry.py** produce 304 closed
stocks, 31 finish partitions and 58,596 triangles. Books have separate covers,
spines and page blocks; the mug and pot are hollow; glass rests on padded
wood fins; cushion welts use continuous frames around their corners. Existing
catalogue and source maps use metre UVs with grain along the boards.
There are no new material keys or generated letters.

The original shelf placed two boards above short uprights and buried low books
behind the seat. The fitted rack retains every book on three supported levels
above the seat, extending its four uprights. Glass stays at 365 mm; contents
and lamp rest on that visible surface. Rug and feet meet their real supports.
These adaptations are recorded in **art/data/reading_nook/source_plan.json**.

The existing native lamp library now serves all five original identities.
**tools/build_v2_task_lamp_installations.py** derives variants and household
names from V1 markers and projects fitted support-local positions. Four new
actors belong to their furniture; the existing bench actor remains. All five
electrical graph positions follow the actors and restore on teardown.
LampProp continues to own lights, switches, audio and interaction.

The 2A lamp moves 225 mm across the desk to clear retained headphones.
The 4B lamp fits the front corner while the mounted terminal moves 75 mm
toward the back edge. Its semantic marker, operator stance and call owner stay
intact. The 2A and 5A tables use exact visible collisions so their enclosing
boxes cannot hide the actual bearing surfaces.

Run the builder, **inspect_task_lamp_installations.py**, then
**inspect_reading_nook.py** through **run_fabrication_batch.py**. Preflight
checks 965 foot samples, 38 actual neighbouring partitions/props, 13 terminal
envelopes, 29 reciprocal contacts, closed stocks and metre charts. It rejects
smooth normals crossing their triangle hemisphere, catching twisted welts
before import. **READING_NOOK_RENDER=0** skips the four Cycles views.

Run **reading_nook,task_lamps** in **OrisonV2FabricationBatch**, capturing
**reading_nook**. One world checks geometry, bearings, player lamp rays,
actual terminal entry/release, standing clearance and graph/actor teardown.
The accepted run has 1,842 checks, zero failures and empty stderr. The shared
harness supports post-teardown validators without another world load.

External supply cords and the wider apartment furniture/material conversion
remain open. Apartment captures still show original low-detail furnishings;
they do not certify whole-room photorealism. Basement samples are not a route
contract. See **design/V2_READING_NOOK_2026-10-07.md** for receipts.
