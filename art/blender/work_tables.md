# Native apartment work tables

Evidence class: **INERT**. Build guide and scoped visual QA.

Five existing furniture actors receive **work_tables.glb**. Their semantic
anchors, poses, passive ownership and child props remain unchanged. The
original six V1 records supply four tables; the terminal desk retains its
existing V2 nine-stock interpretation. Source plan and construction fixture
identify that distinction.

**build_work_tables.py** and **work_tables_geometry.py** produce 110 closed
stocks, 13 metre-mapped partitions and 21,072 triangles. Splayed feet are cut
flat without changing the working heights. Fitted stretchers, drawer shells,
cabinet hangers, a passive vise and folded sheet pedestals replace primitive
blocks. Six drafting-plan footprints and both short rolls are retained; plan
stacks now touch their supporting layer and rolls have hollow interiors.

The new **oak_work_surface** catalogue key uses an unmodified generated albedo
and Blender-derived roughness and physical microrelief proxies at 0.9 metres
per tile. The texture contains no lettering. Analytic height is ±18 micrometres;
the runtime normal multiplier is 0.35. These maps are not a measured scan.
Existing material entries, optical policies and 185 shipped maps are unchanged.

Run the builder and **inspect_work_tables.py** through
**run_fabrication_batch.py**. Set **WORK_TABLES_RENDER=0** for native preflight.
The inspector checks closure, connected stock, UV metrics, normal hemispheres,
22 floor contacts, all 772 lamp-foot samples on these tables and support for
15 retained tabletop props. Six Cycles views show the actual materials.

In the serial Godot lane, use **OrisonV2FabricationBatch.tscn** with
**ORISON_FABRICATION_MODULES=work_tables,reading_nook,task_lamps** and
**ORISON_FABRICATION_CAPTURES=work_tables**. This shares one production world
for native partitions, physical bearings, all five original lamps, Vantry
interaction and teardown. The final recorded run passes 2,058 checks but
reports seven texture RIDs at shutdown. The warning remains open.

Review packet: **art/renders/orison_v2/work_tables_20261007**. Retained desktop
props, the Vantry cabinet, lamp supply cords, nearby furniture and room finishes
still need work; these frames do not accept whole-room photorealism.
