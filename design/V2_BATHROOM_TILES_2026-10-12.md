# REPORT — V2-BATHROOM-TILES — 2026-10-12

Evidence class: **INERT**. Material and UV implementation report.

Branch / starting HEAD: **main / 0496af9a**. Combined clean comparison baseline:
**06e74bf4**. Owner decision required: **none**.

## Changes

The V2 wet-room architecture retires its old ceramic and subway-tile bindings
in favour of two dedicated catalogue materials. The replacement wall material
uses a 3-by-6-inch running bond; the floor uses regular 2-inch hexagons.
A fresh generated ivory glaze is a low-amplitude pigment ingredient. One
analytic joint layout generates colour, roughness, height and normal together.
The tile faces carry subtle kiln variation, not large baked grime islands.
Original source textures remain available for unchanged V1 and other consumers.

The new material recipes disable the inherited stochastic tile mixing,
self-detail repetition and generic wall-age mask. Existing explicitly placed
wear decals remain. The floor chart corrects the rectangular periodic cell's
aspect ratio so hexagons retain their physical shape. Both finishes have real
mipmapped 1024-pixel maps under the V2 compressed import policy.

Wet-room slabs, wall segments, cut openings, far-face skins and continuous wet
chase reveals now use a shared building-space UV phase. Their grout courses
remain aligned across independently built pieces. Dry-room charts retain their
local origin. Geometry, collision, source bounds and gameplay owners are unchanged.

## Review and verification

The first surface run identified wet chase reveals that still used default
box UVs. The focused preview also corrected the review camera's conversion
from building coordinates into the connected world. These failed diagnostics
are retained as wrappers and are not acceptance evidence. A second check
corrected the review to exclude the floor mesh's separately finished plaster
underside; its UV chart is not a tile surface. No threshold was loosened.

The final shared review checks every loaded wet-room tile draw, all 19 authored
wet floors, common chart phase, material layer state and actual loaded mip
chains. Three installed bathrooms supply corner and floor captures, with a
small temporary warm fill light for readable finish inspection. This is scoped
material review, not whole-room photorealism or human navigation acceptance.
The final combined run passes **26,433 checks, zero failures** with zero
unresolved surfaces: 23,465 draws, 16,167 meshes, 5,827 materials and 453
textures. Surface evidence independently validates with zero defects. Save/reconstruction passes all 113 checks and the 19-room apartment circuit
passes all 154 checks. The 43-room completion circuit passes 335 checks and
the roof circuit passes 175 checks. Both renewed contracts independently validate.
Clean candidate **8996abf2** passes comparison against **06e74bf4**: zero
regressions, four improvements, all 17 protected paths unchanged, V2 selector
retained and zero design lint errors. The verifier reused the source-bound
Godot proofs described above; it did not launch additional Godot suites. One completion diagnostic failed the fixed 0.6-second door-stop
wait in 1A. The completion driver now waits on the actual open, settled leaf
(up to three seconds), preserving the same input path, angle tolerance and
checks; its rerun passes.

The additive catalogue audit proves 207 existing runtime texture files unchanged.
Six current construction/fixture bindings were refreshed; pre-existing stale
bindings remain stale. No unrelated asset gained renewed acceptance. The reader
audit reports zero new unread fields. Three new review room references are
appended to the spatial manifest without changing old records or thresholds.

## Remaining scope

Full V2 remains incomplete. The open roof batch is included in the same final
clean comparison. Its new source purposes close one structural requirement;
its 175-check route provides spatial and scoped machinery proof only. The
remaining whole-building runtime, narrative and human requirements stay open.
Owner modifications remain outside this batch, so the canonical tree is not
claimed clean. Existing seven Texture RID shutdown leaks remain unresolved.

Packet: **art/renders/orison_v2/bathroom_tiles_20261012**.

## Material sources

Built-in **image_gen** produced **art/textures/material_sources/bathroom_ivory_glaze.png**.
The exact prompt is retained in **art/renders/orison_v2/bathroom_tiles_20261012/generation.json**.
The derived PBR sets are **art/textures/procedural/bath_wall_tile** and
**art/textures/procedural/bath_floor_tile**, built by **art/tools/build_bathroom_tiles.py**.

## Owner interaction ruling

The same source commit records RUL-013 in the Bible and the ruling index.
Direct manipulation is now binding design direction; runtime migration is
pending. The old input-based route checks above certify only their stated
geometry/material/navigation scope, not the new grab/move/release contract.
The follow-up report commit adds the ruling to the repository working rules.
