# V2 native apartment composition checks

Evidence class: **INERT**. Section 7 implementation report; no ledger promotion.

Starting main / origin: **d5836438**. Clean verification baseline: **a64b8f87**;
the intervening commit archives unchanged route verification and ledger statuses.
Source candidate: **a7693b6b**.

The current apartment baseline completes both production-world construction
cycles with **26,885 checks, 194 failures and zero script errors**. All failures
come from seven obsolete assertion classes: one box per fixed object (**46**),
old extracted material-surface counts (**12**), standard-only wood casts (**18**),
optical-glass lookup by old index (**6**), override-only receiver finishes (**100**),
override-only plant finishes (**10**) and the old four plant material identities
(**2**). Native Blender partitions and
the composed lighting shaders have replaced those representations.

The revised test requires every named native partition exactly once under its
original source actor, with the specified variant and semantic material key.
It verifies each partition's actual active material, including the composed
opaque/cutout shader's albedo, roughness and normal texture bindings against
its own catalogue recipe. Native finishes retain mesh-chart projection. The
plant's five partitions preserve cane support, foliage/ribs, soil and terracotta;
the cane's registered finish is oak rather than the retired timber identity.

Each native solid partition needs exactly one enabled collision shape matching
its visible triangles and transform. No extra enclosing collider is allowed.
Every kitchen cupboard stays at its original wall mount and all collider vertices
remain inside its 0.7 m-high upper-cabinet envelope. The old category roster,
source attribution, household control, heating/water, player-ray, radio isolation,
projector, save-neutral interaction and two-world teardown checks are retained.
No production geometry, material, collision, authority or source data changes.

The test now checks texture-backed standard and registered shader finishes,
finite complete noncollapsed UV arrays, normal/roughness bindings and mip-capable
standard filtering. Windowed runs additionally measure actual complete loaded
mip chains. Headless runs explicitly report that this GPU proof was not measured;
the dummy renderer cannot supply all compressed mip levels. The standalone
surface qualification remains the stronger exhaustive triangle-area/filter gate.
The shader UV-mode check reads the actual RenderingServer default when no
material override was assigned, rather than treating an unset value as an integer.

Final **apartments-native3.log.receipt.json**: completed windowed in **234 seconds**,
**410,280 checks, zero failures and zero script errors**, including per-vertex
cupboard collision-envelope checks across both reconstruction cycles. The output
**apartment_batch.json** confirms that actual loaded mip chains were measured.
The receipt's root-test SHA-256 exactly matches the committed candidate bytes.
The original failed baseline and final log, stderr, wrapper and output are archived
at **art/renders/orison_v2/apartment_native_checks_20261011**.

Fresh verification: **a7693b6b** against **a64b8f87**, complete clean fresh
checkout, **53 gates, zero regressions**, unchanged ledger statuses, **17/17**
protected paths unchanged and selector V2. No gate implementations changed.
**verification.json** archives the result. Verification used **--no-godot**
to reuse the successful canonical runtime above, whose committed root-test hash
was independently checked, and unchanged input-bound production surface reviews.
The earlier retrofit attempts are diagnostic only and are not acceptance evidence.

Production inputs are unchanged. The prior full surface qualification and the
first-slice authority/save/reconstruction proof remain bound; no repeat capture
or unrelated Godot suite is required. The wrapper apartment receipt is **suite_run**,
not **runtime_contract**, and grants no new spatial/runtime ledger status.
Broad V2 remains incomplete: blockers **0/1/127/35/144/146** across first slice,
golden shift, full structure, full runtime, production cutover and V1 retirement.
Decision needed from owner: none for this batch.

MERGE-CANDIDATE a7693b6b6601b833e13ad3c49cfe53716aca6d6e
