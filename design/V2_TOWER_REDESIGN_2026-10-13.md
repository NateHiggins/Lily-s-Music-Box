# REPORT — V2 ROOF TOWER — 2026-10-13

Evidence class: **INERT**. Implementation and scoped visual review; this
report grants no new room, runtime, roof-program or human acceptance status.

Branch / starting HEAD / origin-main / merge-base: **main / 0e1184f8 /
e0b0dd29 / e0b0dd29**. Comparison baseline:
**tmp/v2-toilet-inspection-20261012/gates/board.json**. The shared checkout
contains unrelated existing work; only named tower, service and proof paths
belong to this change. Publication uses the existing checkpoint branch.

## Changes and boundary

Owner request: make the Orison roof tank resemble the classic Warner Brothers
tower. The native Blender recipe now produces a 2.20 m diameter riveted steel
vessel, dished underside, shallow conical roof and vent, reaching 4.70 m above
the original roof datum. An elevated circumferential catwalk, fixed ladder,
guardrails with a ladder opening, four uprights and low crossed ties replace
the rectangular stave-box silhouette. Ivory enamel and dark iron reuse the
existing custom catalogue maps with physical metre UV charts and mip filtering.
No generated texture, new material key or branding was needed. A follow-up
owner request adds the fitted service redesign and repairs the open lid rim.
The tank and cap now have closed sheet thickness, including a returned eave
and inward-facing cone. Native manifold and upward-ray checks prove that the
underside is actual geometry with downward normals.

Form reference: [Warner Bros. tower photograph](https://www.roadtrippin.fr/californie/los-angeles/warner-studios.php).
Reference imagery was not downloaded, baked, projected or committed.

The existing semantic fixture records remain the placement and service anchors.
Their old rectangular vessel, flat lid and straight binding-strip collision is
retired at mount. Actual imported tank/catwalk/trestle faces now supply collision
under the original **ROOF_TANK_BODY** owner. The original four post colliders,
native footings, weather boots and overflow collector remain. The dished bottom
meets the existing fire-feed bore; two round balance connections meet the retained
ballcock chamber. No maintenance state, save schema, overflow behavior or
interaction owner was replaced. The fixed ladder adds no new climbing action.

The retained service instrument's native payload now has a slotted round enamel
float chamber, narrow brass guards and collars, round linkage, compact cast
valve saddle, inlet unions, painted hollow overflow downpipe and open brass
outlet. Its upper and lower balance connections and overflow takeoff enter the
new vessel. Physical collars/stays attach the chamber to the post and catwalk
guard; the overflow pipe has its own chamber straps. All moving nodes, lever
weight, float, valve state, witness stream, reach area and live materials that
change during service retain their original owners. The shared instrument
builder and its generated fixture are regenerated, not edited GLB payloads.

## Verification

Native renders were reviewed before engine review. The first installed close-up
exposed upper braces intersecting the dish; these were removed before qualification.
The remaining ties sit below the vessel. Final captures use the production sky
with the carried flashlight disabled. The separate neutral Blender image shows
the finish without warm scene illumination.

The native comparison verifies 59 post, rivet and collector objects unchanged
at micrometre precision against the starting committed model. The independent
roof-weather inspector also reopens the new tank source and passes its 48 native
beveled-leg contacts, retained bearings and seals. Historical drainage provenance
already named an older tank file at the starting revision; it was not silently
repinned. Its actual contact checks were rerun.

The first surface inventory found two tank partitions with collapsed UVs: joined
stocks had different UV-layer names. The builder now gives every stock the same
metre chart name and asserts one exported layer. The native inspector checks
every exported triangle; the focused test checks the actual imported UV arrays.

The first apartment renewal stopped at the small 2A hot-valve target. Its harness
aimed before waiting for a physics tick, allowing eye motion to shift the ray.
It now re-aims from the actual settled eye position before checking the real
target and sending input. No collision bypass or direct mechanism writer was
added. The complete contract is rerun rather than counting the interrupted leg.

The final focused production test passes **36 checks / 12 walked waypoints**.
It walks from F06 through the actual roof door to the
service stance, checks curved collision at the authored radius, empty former
box corners, all four original solid posts, and unobstructed access to the
original overflowing ballcock. It writes a run trace and wrapper receipt,
not a schema-2 runtime-authority receipt. Both upward probes hit the real lid
underside with downward normals. All five imported tank partitions have finite,
noncollapsed UVs. **tower-service.log.receipt.json** records the final run;
the committed packet carries the same wrapper as **tower.log.receipt.json**.

Review packet: **art/renders/orison_v2/tower_redesign_20261013**. The neutral
full assembly and underside/detail views show construction and finish. The
installed views record the production shadowed service approach; they are
not bright studio lighting or whole-roof photoreal acceptance. The existing
seven Texture RID shutdown warnings persist; no global GPU-retirement claim
is made.

Final source-frozen receipts in **tmp/v2-tower-20261013**:

- **apartments-release.log.receipt.json**: 268 checks, 19 rooms, zero failures.
- **contracts-release.log.receipt.json**: 113 checks, including actual disk
  reconstruction and retained authority behavior, zero failures.
- **surfaces-release.log.receipt.json**: 26,435 checks, zero unresolved surfaces.
  Census: 23,695 draws, 16,215 meshes, 5,841 materials and 453 loaded textures.
  The source-bound surface packet independently revalidates with zero defects.

The canonical apartment-access and first-slice schema-2 receipts are renewed
at their existing packet paths. **surface_requirements_20261011** carries the
new inventory, technical findings and four reviewed images under **tower_**
names. No texture maps were added; the existing mipmapped catalogue is shared.
The eight new spatial consumers were reviewed and registered without changing
any existing manifest record or relaxing an audit. No new ledger promotion is
claimed. The broader V2 completion goal remains open.

The complete static gate board at **tmp/v2-tower-20261013/gates/board.json**
reports **NO REGRESSIONS** against the prior clean comparison board at
**tmp/v2-toilet-inspection-20261012/gates/board.json**. All tools tests pass,
with zero new unread data fields. All 17 protected paths are unchanged from
the starting commit. Ledger counts remain 0 / 1 / 102 / 34 / 119 / 121 across
240 requirements; this roof work does not claim broader V2 completion.
No owner decision is required for this change.
