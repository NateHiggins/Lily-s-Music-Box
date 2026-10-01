# Source-derived V2 city shells

Evidence class: **INERT**

**scripts/build_city_shells.py** reads the protected generated city plan and
builds 338 existing neighboring-building/roof/back solids. It does not regenerate
or edit the protected layout, V1 building assets, shop interiors or city ground.
The two north neighbors register to the current bodega and accepted service alley.
Bar and arcade coordinates remain in their common imported frame.

**city_shells.blend** retains separate editable source solids. Export joins only
within each building/material partition: 87 batches in **city_shells.glb**.
Transforms are applied in metres, with planar metre UVs, exported normals/tangents
and small single-segment arrises, capped at 8 mm. The production importer assigns
valid MatLib keys explicitly and gives each partition a matching triangle collider.

Source brick families map to **brick**; stone/concrete uses the existing **concrete**
runtime family. That is a provisional mapped finish, not final limestone acceptance.
Other mappings are **bronze**, **soot**, **metal** and **brass_mesh**. No unrecognized
runtime material silently falls back to color. MatLib's current triplanar physical
scale remains authoritative; UVs are prepared for supported future mapping work.

The structural contact suite samples broad surfaces. Microscopic bevel-tip ray
misses are outside that structural sample; no exact corner-contact claim is made.
Rendering, source composition, route evidence, performance observations and the
open city queues are in **design/V2_CITY_PRODUCTION_MAP_2026-10-01.md**.

Rebuild with Blender background mode and this generator, then use the Godot lane
for two imports and **OrisonV2CityCompositionTest.tscn** plus affected route suites.
Do not change global lighting or introduce a second simulation for these shells.
