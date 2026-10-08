# Fixed interior and passage lighting

Evidence class: **INERT**

The Blender family fits 199 existing light actors: 133 authored room fixtures
and 66 retained bar/passage fixtures. Twenty-seven native variants contain
438 closed stocks, 133 material/component partitions and 480,680 unique
triangles. All actors share immutable variant meshes within their world.

The original LightFixtureProp owns switching, saved state, flicker, conductor
response, audio, swinging bodies, light/bounce nodes and emissive envelopes.
Fixed ceiling and wall mounts remain under the actor while lamp bodies retain
the original swing node. Native opal stock shares the original dynamic bulb
material. Original actor anchors and circuit identities remain unchanged.

Fitted rods, cords and brackets meet retained ceiling, stair, wall and fascia
surfaces. The basement service-core fitting uses a local presentation offset
beneath the service stair landing, with 2.74 metres of clearance above the
lower landing. The west bar sconce is raised above existing framed pictures.
The 3B sconce sits beside the window opening and its halo is sized to its globe
beside the live medicine mirror. Superseded bar lamp brackets are retired;
the eight canopy-stay partitions and two original long rods remain.

All maps already exist in the material catalogue. Bronze-sheet maps replace
the oversized brass crust pattern locally; no global key or texture changes.
Geometry has metric UVs, explicit normal/tangent charts and closed stock.
No generated lettering or source photographs are used.

Run build_fixed_lighting.py, inspect_fixed_lighting.py,
inspect_fixed_lighting_context.py and inspect_fixed_lighting_city_context.py
in one run_fabrication_batch.py process. Review render_fixed_lighting.py views
before importing. Use the fixed_lighting module in OrisonV2FabricationBatch
for one shared production world. ORISON_FIXED_LIGHTING_CAPTURE_IDS restricts
only corrective screenshots; every fixture still receives validation.

The six existing alley/shed lamps, uninstalled V1 forms, wider material and
lighting calibration, and whole-building acceptance remain separate work.
See design/V2_FIXED_LIGHTING_2026-10-08.md for receipts and limitations.
