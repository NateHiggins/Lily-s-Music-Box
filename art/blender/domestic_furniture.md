# Shared native apartment seating and tables

Evidence class: **INERT**. Build guide and scoped visual QA.

Seventeen source-equivalent variants serve 103 existing furniture actors:
38 chairs, three sofas, 17 nightstands, seven round tables, 35 rectangular
tables and three coffee tables. This includes 57 original V1 records, 23
existing V2 interpretations and 23 completion-home copies. Each variant's
original surface arrays and bounds are compared by both builders before sharing;
a changed source or completion template refuses the build until regrouped. Existing
poses and nonvisual owners remain; the five previously fitted work tables are
excluded from these new libraries.

The seating library has 50 closed stocks, eight partitions and 37,376 triangles.
Its continuous bentwood hoops, dished seats and floor-cut spindles retain the
source chair control points. Sofas keep their lengths, cushion counts and seat
heights, with rounded upholstery, seated cushions, hidden arm supports and fine
attached welts. The table library has 127 closed stocks, 24 partitions and
44,424 triangles. Hollow aprons, turned legs, supported drawers and thin glass
replace source primitives. Coffee-table fins are cut to the actual floor and
existing normalized glass-height planes. Nightstand books and glasses retain
their original extents.

Use the two **build_domestic_*.py** scripts, their inspectors, and
**inspect_domestic_furniture_context.py** before rendering or importing. The
context uses actual V2 anchors and storey heights: 418 floor bearings and 41
retained tabletop-stock contacts. Neighbours use the new native libraries,
accepted work tables, other source triangles, or conservative bounds for
model-only fixtures. All candidate neighbour AABBs are separated in this
installation; there were no positive broad-phase pairs requiring BVH rejection.
Floor planes come from source room rectangles and are confirmed by engine rays.

Native checks include closure, connected construction, metre UVs and normals.
They now also enforce the engine's absolute edge-length budget, with a small
preflight margin: 49 micrometres and 0.0048 maximum edge-ratio deviation.
Wide turned table stock uses 96 radial sectors. This resolves the first engine
run's two 51.45-micrometre UV excesses without loosening any engine gate.

Existing oak, linen, trim, paper, brass and glazing materials remain registered
owners. Local tint values are explicitly linear light; the runtime encodes them
to sRGB for **StandardMaterial3D.albedo_color**. This corrects the initial dark
runtime result while matching the native material intent. No new maps or global
material policy changes are made. Clear glass retains the existing Fresnel
approximation without refraction.

The world owns one native factory through root metadata. It prepares both
assets once, shares immutable meshes/materials/collision shapes across exact
variants, and gives every actor its own nodes. Main and completion homes share
the same resources. Existing StaticBody3D identities remain. The factory and
all 103 actors retire with the world; no global resource cache is introduced.

One serial **OrisonV2FabricationBatch.tscn** run selects **domestic_seating**,
**domestic_tables**, **surface_stock**, **signal_terminal**, **work_tables**,
**reading_nook** and **task_lamps**. Capture the first two modules. The final
run passes 5,476 module checks plus 20 batch checks in 69.58 seconds. Twenty-one
native views and seventeen final room views are reviewed. Seven texture RIDs
still remain at shutdown; this is not a clean-stderr or whole-room acceptance.

Packet: **art/renders/orison_v2/apartment_furniture_20261007**. Remaining storage,
kitchen fittings, fixed light bodies and broad room finish/light balance remain
in the V2 pass. Reuse the shared-variant workflow for the next furniture batch.
