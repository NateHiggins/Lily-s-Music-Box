# V2 architecture and infrastructure continuation prompt

Evidence class: **INERT**

This is a reusable work instruction, not acceptance evidence. Paste the text
below into the continuation chat. Read the linked repository reports for the
latest verified commit and remaining findings before changing anything.

---

Continue building V2 in **C:/PleaseRemainOnTheLine**, on canonical **main**.
Work autonomously until completion or a concrete issue requires my intervention.
Finish the raw architecture and infrastructure of the Orison, bodega, shopping
mall/Vantry Arcade, street, bar, and remaining cityscape. Organize the work into
clear location buckets with explicit ownership of their shared boundaries.
Make them read and function as one continuous place. Design and model in Blender
efficiently, preparing photorealistic final assets and texture mapping from the
start. Finish structural and spatial problems before a broad decorative pass.

Read **DOCS.md**, **AGENTS.md**, **design/ORISON_BIBLE.md**,
**design/V2_FABRICATION_HANDOFF_2026-09-29.md**,
**design/V2_ARCHITECTURE_HANDOFF_2026-09-27.md**, and
**art/blender/v2_fabrication_coverage.md**. The Bible governs period, location,
scale and world identity. Inspect the actual checkout and receipts; historical
handoffs are not substitutes for current source or rendered inspection.

Preserve the outward boiler-door fix, installed boiler pipework, street-connected
service alley and gentler waking flashlight (energy 6, range 16). Keep existing
gameplay, persistence, shop hours, stock, resident schedules, maintenance,
interactions, Dream boundaries and V1 rollback. Retain accepted Blender assets,
hero, organelles and sixteen intentional critter placeholders. The owner removed outdated **shot_024.png** through **shot_028.png** and their
capture-log entries on October 1. Do not restore those captures from verification
backups. Preserve any new unrelated work found at the start of the next session.

## First establish the production map

Inventory the composed V2 runtime, not just the 200-room blockout. Walk and
render each location from player height, map active and dormant geometry, and
record which source owns every shell, aperture, floor, collision and system.
Use the existing inventory and capture tools; avoid recreating accepted assets.
Separate verified completion, visible defect, intentional simplification,
unimplemented connection, and uninspected work. Keep a small actionable queue
per bucket and one shared transition register. Do not promote the completeness
ledger based on screenshots or this plan.

The main source map includes:

- **game/data/orison_v2_blockout.json** and the V2 runtime/blockout scripts for
  Orison architecture; **art/blender/scripts** for editable asset generators.
- **game/data/orison_v2/exterior/regions.json**, **street_frame.json**,
  **exterior_geometry.json**, **shop_buckets.json**, and
  **game/data/orison_v2/world_connection.json** for registered exterior frames,
  street geometry, bodega state and the front threshold.
- **game/scripts/building/orison_v2_exterior_cell.gd** and
  **orison_v2_passage_region.gd** for the actual composed city. The arcade currently
  loads thirteen cells including its passage and eleven named shops; inspect
  the complete roster and retained service authority before editing.
- **game/data/floor_01_cell_registry.json**, **art/data/building_layout.json**,
  runtime **game/data/building_layout.json**, and their authoritative generators
  for imported city cells. The registry contains **shop_bar**, but the current
  V2 passage CELLS list does not. Trace the bar's actual runtime inclusion,
  intended location and route before reusing or connecting it. Do not assume a
  registered asset is already playable or invent a replacement mall topology.

## Location buckets

| Bucket | Structural scope | Required interfaces |
|---|---|---|
| Orison | Foundations, complete exterior shell, roof closures, party walls, slab edges, occupied rooms, public/service stairs, lift shafts/landings, basement, plant rooms, all door/window reveals and physical supports | Front vestibule/street; rear service door/alley; roof/risers; arcade or other authored connections |
| Bodega | Storefront, threshold, structural shell, glazing, shop floor, counter backing, stock/service areas, ceiling and service distribution; retain established scale and shop state | Sidewalk/display frontage; delivery approach; adjacent party walls; accessible counter and service circulation |
| Shopping mall / Vantry Arcade | Continuous passage shell, roof/ceiling support, shop bays, columns, storefronts, grilles, service routes, stairs or level changes where authored, eleven existing shop connections | Street portal; each shop threshold; shared utilities; open/closed-hours circulation; residency boundaries |
| Street scene | Continuous sidewalks, curbs, road, drainage grades, paving edges, street-facing foundations, entrances, construction shed and existing transit approaches | Orison, bodega, arcade, bar, service alley, street crossings and boundary continuations |
| Bar | Locate and inspect the existing bar cell; finish its shell, entry, back bar structure, floor/ceiling, service/storage and sanitary connections supported by the design | A physically aligned public entry and service route, correct city frame, coherent neighbors and any authored narrative boundary |
| Remaining cityscape | Adjacent buildings, party walls, courtyards, rooflines, alleys, transit edges, skyline and intentional distant closures | Continuous street wall, plausible backs and roofs, safe route limits, sightlines without exposed empty backs or floating scenery |

Use a seventh shared-infrastructure register across these buckets: heating,
water supply/return, drainage, ventilation/exhaust, power/conduit, lift equipment,
communications and deliveries. Trace each relevant system from source through
distribution to endpoint. Model supports, sleeves, access space, joints,
penetrations and service clearances. Keep existing simulations authoritative;
visual completion must not create a second simulation or fictional live control.
Do not add modern systems that conflict with the Bible's period and technology.

## Seamless transitions are a deliverable

For every connection, record both owners, source frame/transform, shared datum,
threshold height and width, wall thickness, opening dimensions, door hand and
swept volume, floor/collision ownership, service crossings and loading boundary.
Reuse semantic anchors and registered frames. Give each shared surface and
collider one owner. Remove duplicate floors, sealed openings, overlapping
facades, tiny gaps, floating trim and abrupt unmotivated material changes.

Walk each connection in both directions at normal speed and camera height.
Check headroom, capsule clearance, every moving-door pose, stairs, landings and
delivery access. Repeat relevant routes with shop grilles open and closed and
across unload/reload boundaries. Check light, exposure, reflections, weathering
and acoustic continuity at doors; retain intentional acoustic separation.
Inspect oblique views and a few overhead views to catch disconnected geometry,
but never substitute an overhead render for a successful walking route.

## Efficient Blender fabrication and mapping

Build reusable dimensional modules for walls, corners, piers, lintels, reveals,
slabs, roof edges, stairs, storefront bays, thresholds and service fittings.
Use scripted Blender generation, linked data, collections and instancing where
appropriate. Keep editable .blend sources, reproducible generators and exported
assets together. Keep transforms, metre scale, pivots and material slots stable.
Do not hand-edit generated glTF or generated source/data. Regenerate from its
actual authority. Use simple solids where they already describe the correct
structure; spend geometry on silhouettes, openings, edge profiles and close
contact details. Avoid unnecessary subdivision, invisible internals and huge
joined meshes that defeat culling. Partition exports by location and existing
streaming ownership, with shared module meshes and practical collision meshes.

Model believable thickness, small bevels that catch light, construction joints,
termination details and supported assemblies. Use repeatable metre-based UVs,
consistent texel density, deliberate grain/brick orientation, sensible seams,
trim sheets and atlases where they reduce cost. Reserve unique UVs and high/low
bakes for assets that need them; provide a separate nonoverlapping lightmap UV
set only when the chosen pipeline uses it. Verify the exported active UV channel,
normals, tangents and material assignments in Godot, not only in Blender.

Prepare for photorealism using the existing material catalogue and ingest
contract: **art/data/material_catalog.json**, **runtime_material_sets.json**,
**game/scripts/material_library.gd**, **surface_pass.gd**, generated material
sets/calibration and the current lamp optical/shadow system. Inspect what those
systems actually support. Catalogue material names and runtime MatLib keys are
not interchangeable; an unknown runtime key silently falls back to plain colour.
Use valid mapped keys and add genuinely needed ones through the catalogue.

Evaluate useful techniques deliberately: calibrated albedo/roughness/normal
maps, restrained AO, physically scaled height/parallax, macro and micro variation,
trim textures, decals or vertex masks for localized dirt, curvature-driven edge
wear, dampness at plausible sources, directional grain, masonry bonds, glazing
thickness and selective reflection detail. Keep dirt and damage tied to gravity,
use, drainage and construction. Avoid baked directional light in base colour,
indiscriminate metallic response and uniformly noisy wear. Lettering remains
Label3D; no generated texture words, numbers or logos. Reference photographs
inform form only and are never baked, projected or committed.

Use the supported render features that improve the result at an acceptable
cost: existing layered surfaces and optical transport, appropriate normal versus
parallax tiers, reflection and shadow budgets, instancing/batching, LOD/HLOD where
supported, occlusion and residency/culling. Measure representative player views
and transitions before and after. Do not assume ray tracing, virtual textures or
new lighting systems are available. Prototype any pipeline extension in a small
measured example before adopting it. Preserve the gentler flashlight; fix material
response locally instead of compensating with global lighting changes.

## Work order, checks and stopping rule

Start with a connected-route audit and the highest-impact structural defects.
Complete Orison shell/threshold closures and the shared street/entry interfaces,
then bodega, arcade, bar connection and surrounding city structure in dependency
order. Finish infrastructure routes with each affected shell. Deliver small
reviewable location batches, updating the queue and transition register after
each. Do not spend the whole run repeatedly polishing already accepted props.

For each batch: inspect sources and prior evidence; model; regenerate; import
twice; render production views; inspect them directly; test affected openings,
collision, moving parts and continuous routes; fix findings; run required gates;
commit named paths; verify the candidate against a complete clean main baseline;
push when verified. Use only approved Godot lane runners, one process at a time,
with bound log receipts and windowed captures. Do not disturb another holder.
Require zero new unread fields, zero gate regressions, preserved protected paths
and selector rollback. Register only individually reviewed new spatial references.
Use runtime_contract receipts when claiming runtime requirements; wrapper runs
and captures alone do not grant completeness. Lint all design documents.

Finish each bucket with a source/asset inventory, rendered before/after examples,
tested connecting routes, measured performance observations, outstanding defects
and exact verified commits. Keep "raw architecture complete", "infrastructure
complete", "mapping prepared", and "final material/render polish complete" as
separate evidence-backed states. Complete the raw architecture and infrastructure
across all buckets before declaring this phase finished. Continue autonomously;
ask only when an unresolved canonical design decision, missing external input
or actual authorization boundary prevents meaningful progress.
