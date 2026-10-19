# REPORT - V2-FIRE-NOZZLE-DETAIL - 2026-10-19

Evidence class: **INERT**. Scoped implementation report, not acceptance.

Branch / HEAD / origin/main / merge-base: main / 82887a14 / 82887a14 /
82887a14. Worktree clean at end: **no**. Shared inherited V2 changes remain;
this fire batch is uncommitted and unpushed. The durable named-path list is
**tmp/v2-fire-hand-20261019/owned_paths.json**. Original proof and sources are
in **art/reviews/v2_fire_nozzle_detail_20261019**.

Protected 17/17: working files unchanged against HEAD, checked with normalized
text; historical protected receipt unchanged. Selector: V2 default, existing
explicit V1 rollback retained. Ledger before/after: not rerun; no new
runtime_contract or requirement promotion is claimed. Full V2 goal remains
active. No external blocker or owner decision prevents continued work.

## Changes and measured results

Six Blender-built parts replace the plain cone and rod: a turned hollow
barrel with valve chamber and outlet lip, saddle-shaped gland, thrust washer,
solid spindle, hex nut and one continuous forged lever with a bored eye and
rounded grip. Original barrel and lever draw parents remain. The original
lever pivot moves to its outboard spindle; its angle, maintenance facts,
household state, hand ownership and certification authority stay intact.
Detail fitting precedes native hand-collider construction.

Native construction checks six closed positive-volume meshes, 65 lever
positions without crossing the barrel/gland/spindle, permitted planar
washer/nut bearings, 16 actual gland/barrel bearing rays within 0.1 mm,
open barrel and lever bores, positive stock, UVs and exported tangents.
The initial gland had a 0.17 mm saddle gap; additional radial sampling fixes
the surface rather than relaxing the tolerance. Both native review images
were inspected before publication through the owning builder.

Default Godot compression stretched charts by up to 20.04% and broke tangent
derivatives. The measured exception is confined to this GLB. All six loaded
meshes now pass metric UV and tangent checks; registered custom brass and
iron retain active normals and actual loaded albedo/roughness/normal mips.

| Gate or run | Original observed result |
| --- | --- |
| Reader baseline | NEW 0 after explicit consumption of both finish definitions; no audit exception |
| Surface requirements tools tests | 26 tests PASS, 134.684 s |
| Native publication | native6 source/hash closure and exported tangent validation PASS |
| Nozzle support probe4 | Eight stationary supported poses and moving-support drop PASS, 7.42 s |
| Nozzle support probe5 | Adds actual inward receiver collision positive control; PASS, 15.71 s |
| Focused washer programme | Actual grab, carry, seat, unthread, removal and restoration PASS |
| Full nozzle_detail_stock6 | 267 checks; nozzle coupling, fold, rack and original hand programmes all PASS; 144.32 s; no script errors; empty stderr |
| Composed nozzle_detail_voxel1 | Eight 1080p posed installed/off frames and 33 lighting/clearance checks PASS; no script errors; seven texture-RID shutdown warnings |
| Completeness, spatial, systemic, period, full gate board, clean candidate verifier | Not rerun; broad qualification remains outstanding |

Each Godot result above has its original **suite_run** wrapper receipt in
the packet. These are scoped diagnostics, not schema-2 runtime-contract
proof or evidence that all V2 requirements are complete.

## Repairs outside the immediate visual boundary

The annular collision helper now reads actual imported arrays rather than
rounded triangle faces and supports transverse spindle/lever axes. It keeps
their bores open. Receiver exclusions use a real assigned RID array; mutating
the query property's returned array had not applied those exclusions.

All eight loose nozzles now settle without the earlier station-dependent
ejection. New support contacts are confirmed on the following physics tick:
a moved node transform could otherwise be cached against an old broadphase
contact and leave the nozzle floating when its floor moved away. The focused
probe shows the rotated nozzle dropping approximately 30 mm onto that moved
support. No bearing tolerance was widened.

Original failure logs remain. The new lever legitimately occludes the old
barrel pick ray; the input test now targets the exposed outlet collar. The
washer driver rounds OS cursor warps, checks arrival more tightly and finds
a real visible annulus pixel instead of assuming one fixed 3D rim point
survives rasterization. It still uses actual target queries, grabbing, mouse
motion and release. Player interaction code was not changed for these fixes.

## Open findings and merge status

Human appearance acceptance remains **OPEN**. Native and Godot renders have
been reviewed, but the close backplate reflection remains harsh. The composed
lighting fixture freezes scripted state; its preset views are not evidence
of natural settling. Separate physics probes establish the eight supported
poses. Future final presentation should warm up physics before freezing.

The inward-stop probe reaches the real nut collider, but its added contact
query costs roughly eight seconds relative to the shorter probe. Profile
and optimize this before claiming acceptable contact performance. Seven GPU
texture-RID shutdown warnings persist even after a four-render-frame drain;
renderer resource lifecycle remains unqualified. Older intermittent cursor
failures are preserved and are not universally declared solved by one pass.

True 50-foot hose length, deployment/refolding, physical tag certification,
broader surface/access/disk proof and clean-baseline regression qualification
remain outstanding. No decision is needed from the owner. Implementation
continues autonomously; this report does not change the active goal's status.

BLOCKED for merge: remaining fire-batch and broader V2 qualification; work continues.
