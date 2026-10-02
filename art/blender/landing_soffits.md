# Exposed landing undersides

Evidence class: **INERT**

The production floor-face filter removed the underside of every landing slab,
including slabs above open stair and lift cores. The retained box collision
closed these surfaces while the rendered slab was open. This also prevented
physical pipe-support seating against the visible underside.

## Source and construction

**game/scripts/building/orison_v2_platform_soffits.gd** extends the existing
source-driven platform mesh. It subtracts actual lower-room ceiling footprints,
including their authored openings, at the same elevation. Of the **65** source
platforms, **64** need an additional underside partition; one is already wholly
covered by a retained room ceiling. The original top/side triangles, UVs,
tangents, material and single box body remain. Slab dimensions and circulation
authority remain in **game/data/orison_v2_blockout.json**.

This is a repair to source-built architectural slabs, not a new prop. No native
Blender model or copied texture is needed. The added underside uses the existing
**trim** ceiling recipe, metre-scaled planar UVs, downward normals and a rightward
orthogonal tangent basis. ArrayMesh returns approximately **15.26 microradians**
of axis quantization for these normals/tangents; the inspection allows **30**,
while retaining unit-length and orthogonality tolerances of **one** microunit.
This storage tolerance does not relax geometry or contact checks.

## Inspection, failures and limits

**tmp/landing-soffits/before.log.receipt.json** completed its construction
inspection with **566** missing faces at **585** stations across all platforms,
no duplicate faces, and **1,301** checks. The final focused
**tmp/landing-soffits/after-3.log.receipt.json** completes with **1,557** checks,
**585** single-owner surfaces, zero missing or duplicate faces, zero failures,
and matching retained collision within **0.1 mm**. Additional checks inspect
mapping and both material partitions on every changed platform. The first two
after runs already passed all surface/contact checks but rejected the compressed
normal basis using an overly tight axis comparison; their receipts are retained.

Four production-windowed views inspect basement, second-floor, third-floor and
service-core undersides with the retained player lamp. The final frames in
**tmp/landing-soffits/after-3/** were directly inspected. The older before frames
have HUD paper over part of the view; they are not matched exposure comparisons.
The service-core view is a covered-ceiling control. Warm, bright lamp response
and the exposed stair/support interfaces remain final-polish/raw-interface work.
No global lighting correction is included.

Focused startup was **20.04 s** before and **19.53 s** after. These single-run
observations are not stable performance measurements. There are **64** additional
material partitions. The test positions its camera for construction inspection;
it does not prove a normal-input walk or grant runtime-contract/ledger evidence.
Existing route suites and a clean in-place candidate comparison must pass before
publication. All six location phases and heating distribution remain open.

The complete pre-commit **47**-gate board compares with the genuine clean
**e93b9c2** board with zero regressions, reader NEW **0**, unchanged requirement
statuses and unchanged existing gate failures. Spatial and systemic audits pass
without new classifications or altered baselines. Final binding verification is
written to **tmp/landing-soffits/verified/verification.json** after the named
commit, with the focused scene and existing blockout, vertical/basement/roof,
door-casing, ventilation, hot-water and resident-key suites.

The owner's **art/renders/insitu/shots.md** bytes and absence of captures
**shot_024** through **shot_028** are preserved. The protected selector, V1 rollback,
accepted service/gameplay states and earlier native fabrication remain intact.
