# REPORT — V2-KITCHEN-SINKS — 2026-10-12

Evidence class: **INERT**. Implementation report; no completeness promotion.

Branch / starting HEAD: **main / d7950cad**. Clean gate baseline: **09d0d75d**.
Owner decision required: **none**.

## Changes

The V2 kitchen faucet uses an editable native Blender bridge, rounded cross
handles, porcelain H/C indexes, separate valve pivots, glands, swivel union
and a continuous curved neck with an actual downward water passage. Existing
TapProp water, boiler, sound, stopper and ownership mechanisms remain active.
The inherited lavatory and shower implementations retain their existing form.

Standard sinks receive bearing rails and adjustable saddles connecting their
rim/drainboard to the existing low frames. The 3B pilot, which had no passive
sink stand, receives a separate native physical frame under its original tap.
The compact rolled lip is raised 12.5 mm to bear on the 905 mm 4B worktop;
its bowl, valve controls, outlet, water surface and collision follow that fit.
The three compact bowls in 1A, 3D and 4D previously reused full-size stands.
Their source plan now selects a 935 x 410 mm frame supporting both bowl and
retained drainboard, with separate 901.5 mm board and 905 mm rim bearings.
The native storage builder owns this variant, including its collision.
All 41 previous storage mesh partitions retain identical exported attributes.
The original sink castings and drainboards remain procedural in this batch.

The new catalogue **faucet_nickel** finish replaces visibly coarse nickel on
these faucets with quiet color, fine wiping marks and four-micron relief.
Two additional loaded 512-pixel maps provide albedo and roughness; the generated
material contract reuses the byte-identical existing normal map. Imported
textures use the V2 compression/mipmap policy. Fixed stock is batched by finish,
while each hot/cold handle retains its own mechanical pivot.

## Verification and scope

The Blender export contains 60 closed positive-volume source stocks across
two faucet sizes, the shared bearing assembly and the 3B frame. Its 31,776
triangles pass strict exported tangent/UV validation. Native faucet closeups
and the support assembly with a retained-basin envelope were rendered and
reviewed. The neutral envelope is a review aid, not a replacement sink asset.

The shared production-world review exercises every authored kitchen sink:
separate hot-only, mixed and cold-only flow; actual valve targeting rays;
filling a stopped bowl and draining it; one boiler supply; retained state;
and physical contact with the existing stand or countertop. Render captures
cover standard, compact, upper and rear-wing placements. Final surface run: **25,480 checks, zero failures, zero script errors**,
covering all 18 authored kitchen sinks. The loaded inventory contains 23,519
draws, 16,266 meshes, 5,831 materials and 445 textures, with zero unresolved
surface findings. The first-slice save/reconstruction contract also passed all 113 checks.
Clean candidate **6edaaef7** verified with zero regressions against the
recorded **09d0d75d** baseline, all 17 protected paths unchanged, selector
V2 and zero document lint errors. No regression exemptions were used. The
comparison ran in the clean temporary checkout with **--no-godot**; the
canonical bound runtime receipts above supply the separate runtime proof. The first clean
check exposed default import parameters on the unused duplicate faucet normal
map. Its parameters now match the shared normal map, and fresh bound runtime
qualification passes. The batch workflow now requires named staging and the
all-tracked V2 import checks before final captures, including unused duplicates.
The complete native-storage contract is included in the shared run, covering
all 52 retained storage actors as well as the newly fitted variant. Its asset
contains 42 partitions and 122,648 triangles; strict export validation passes.
The surface evidence binding now includes the kitchen, front-façade and
storage review helpers, so changing those tests invalidates their proof.

The first diagnostic run exposed an incorrect BoxShape-only test assumption:
existing native stands use triangle collision. Contact checks now inspect
their actual triangle faces, without broadening contact tolerance. Initial
runs are retained as failed diagnostics, not acceptance evidence.

Additive-material provenance verification retained all 205 previous runtime
map files unchanged and refreshed four current bindings. The additive operation left 804 older
stale bindings unchanged. Native storage was subsequently regenerated and
verified separately; unrelated stale evidence gains no renewed acceptance.
The unrelated unfinished apartment-route edit remains outside this batch.

## Remaining work

Full V2 remains incomplete. Room narratives, remaining asset families and
completion/route requirements continue under the existing plan. This report
covers the kitchen faucet, bearing fit and retained water interactions only.
