# REPORT — V2-KITCHEN-CASTINGS — 2026-10-12

Evidence class: **INERT**. Scoped geometry report; no completeness promotion.

Branch / starting HEAD: **main / 99c9e1a7**.
Owner decision required: **none**.

## Change

All 18 kitchen sinks now use one of three native Blender castings: standard
with drainboard, compact with drainboard, or the compact countertop bowl.
The former separate flat box walls and square lips are retired from the V2
kitchen factory. The new continuous closed shell has coved corners, a rolled
rim, a rounded splash panel and an actual through-drain. Longitudinal rounded
drainboard crests drain toward the bowl over a sloped surface. A ferrule and
thin strainer bridge leave the throat open rather than painting a dark disc.

A rubber plug visibly lifts clear of the ferrule and parks beside the drain.
Its existing stopper flag remains the only water authority. Hot/cold controls,
boiler supply, ownership and save state retain their original mechanisms.
The transparent water surface now follows rounded corners. The old separate
rust/mineral pucks are removed from these kitchen bowls. Existing registered
porcelain glaze, nickel and rubber PBR maps supply the finish; no new textures
or catalogue keys are introduced.

## Bearing fit and native review

The castings contain 37 closed positive-volume stocks and 16,100 triangles.
Strict exported UV/tangent verification passes. Three complete variants, a
bowl detail and both support assemblies were rendered in Blender and reviewed.
Actual casting rays prove the drain remains open and the underside bearing
height is retained.

The first composed capture passed technical checks but exposed a rear rail
inside the standard bowl. It is retained as a rejected visual diagnostic.
The standard upper rails are narrowed and shifted beneath the rolled edge;
the compact frame has lowered bowl rails, narrow outboard saddles and fitted
end bearings. Actual support vertices and face centres pass 3,160 oriented
clearance/sightline checks against the native castings. Foot positions and
drainboard bearing planes remain unchanged. Four support partitions changed
in the faucet asset; its other 56 meshes are byte-identical. Only the compact
frame partition changed in domestic storage; all other 41 partitions retain
identical exported geometry. Storage now has 653 closed stocks, 42 parts and
123,024 triangles.

## Runtime verification

The final composed surface run passes **25,570 checks with zero failures and
zero script errors**. The loaded inventory contains 23,465 draws, 16,167 meshes,
5,827 materials and 445 textures: 54 fewer draws and no additional loaded
textures relative to the faucet batch. The first-slice save/reconstruction contract passes all **113 checks**. The shared
surface review now checks actual loaded casting triangles at the drain and
bowl floor, plug seating and parking, rounded water geometry, and the prior
hot/cold/fill/drain/bearing checks for every authored sink. Filled and empty
views cover standard and compact bowls. The complete retained native storage
suite runs in the same production world.

The reader audit reports zero new unread fields and spatial dependencies are
clean. Clean candidate **4be49f1d** passes against the recorded clean **25840bed**
baseline with zero regressions, no gate changes, all 17 protected paths
unchanged, selector V2, and zero lint errors. No exemptions were used. The
comparison used **--no-godot** in a clean temporary checkout; the canonical
bound runtime receipts above supply the separate runtime evidence. Existing owner work remains
outside this batch. The prior apartment walking route is not rerun or claimed
current after these geometry changes.

## Remaining scope

Full V2 remains incomplete. This batch supplies native sink casting geometry
and its fitting/interaction checks, not whole-world aesthetic acceptance or
completion of the remaining structural, runtime and human-navigation gates.

Packet: **art/renders/orison_v2/kitchen_castings_20261012**.
