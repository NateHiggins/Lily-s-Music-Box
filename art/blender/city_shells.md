# Source-derived V2 city shells

Evidence class: **INERT**

**scripts/build_city_shells.py** reads the protected generated city plan and
builds 335 existing neighboring-building/roof/back solids. It does not regenerate
or edit the protected layout, V1 building assets, shop interiors or city ground.
The two north neighbors register to the current bodega and accepted service alley;
the northeast row registers beyond the existing construction-shed route boundary.
Bar and arcade coordinates remain in their common imported frame.

**city_shells.blend** retains separate editable source solids. The current export
is rebuilt by **scripts/build_city_closure.py** into **city_closure.blend** and
**city_shells.glb**. It joins the four intersecting parapet stocks per building
into 25 closed rings, retaining all 335 source stocks and 84 material partitions.
See **city_closure.md** for the original-corner survey and fitted inspection.
Transforms are applied in metres, with planar metre UVs, exported normals/tangents
and small single-segment arrises, capped at 8 mm. The production importer assigns
valid MatLib keys explicitly and gives each partition a matching triangle collider.

Source brick families map to **brick**; stone/concrete uses the existing **concrete**
runtime family. That is a provisional mapped finish, not final limestone acceptance.
Other mappings are **bronze_sheet**, **soot**, **galvanized_roof** and **brass_mesh**.
No unrecognized runtime material silently falls back to color. Local material
duplicates consume the exported metre charts and exact catalogue maps. The shared
MatLib cache, physical tile scales, normal strength and lighting remain intact.

The structural contact suite samples broad surfaces. Microscopic bevel-tip ray
misses are outside that structural sample; no exact corner-contact claim is made.
Rendering, source composition, route evidence, performance observations and the
open city queues are in **design/V2_CITY_PRODUCTION_MAP_2026-10-01.md**.

For a closure rebuild, retain the immutable source native and run
**scripts/build_city_closure.py** in Blender background mode. Running the older
source generator also replaces the export; the closure generator must follow it.
Any source change requires rebuilding affected foundations and rooftop hardware
against that source. Use the Godot lane for two imports and
**OrisonV2CityClosureTest.tscn**, **OrisonV2CityCompositionTest.tscn** and affected
hardware/controller suites.
Do not change global lighting or introduce a second simulation for these shells.
