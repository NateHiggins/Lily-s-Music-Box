# REPORT - Vorticella maintenance guide-bells - 2026-10-26

Evidence class: **INERT**

The implementation and palette-preserving mottling are merged on main in
**e774453fe977b546e058fcac0b29f7eebd93a4b2** (PR **48**). This report supersedes
the blocked checkpoint status; it does not promote completeness-ledger claims.

## Integration state

Implementation candidate: **84b2955d5b3a346f4288ba0ec1e74888a21cf923**.
Its tree is identical to the merged commit's tree. The candidate verifier used
base and merge-base **293ef013a31863bd90a2f337392219151f15cd29**.
Final evidence preservation branch: **codex/guide-bells-complete-20261026**,
based on **d0c18f36**. This follow-up changes documentation and review artifacts
only. Runtime and asset sources have not changed since the verified merge.

Worktree clean at start: **yes** for the temporary evidence checkout.
The canonical shared checkout remains dirty with unrelated parallel work;
its three task-owned route/test copies were reconciled to merged main, with
previous copies backed up under **tmp/guide_bell/pre_reconcile**. No shared
branch switch, bulk staging, stash, or unrelated restoration was used.

Protected 17/17: **unchanged against implementation merge-base**. Selector
remains **v2**, with explicit V1 rollback. The protected receipt is unchanged.
Ledger blockers before -> after, respectively: FIRST_SLICE_TECHNICAL **7 -> 7**,
GOLDEN_SHIFT_V2 **8 -> 8**, FULL_BUILDING_STRUCTURAL **110 -> 110**,
FULL_BUILDING_RUNTIME **42 -> 42**, PRODUCTION_CUTOVER **134 -> 134**,
V1_RETIREMENT **136 -> 136**. requirements_changed: **none**.

## Implementation

The read-only adapter requests physically supported routes through authored
rooms, portals and stairs. Capsule sweeps and continuous floor samples reject
walls, closed doors and missing support. Placement and passing use the same
route-distance authority. A failed query produces no trail.

Up to eight sessile cells attach at clear architectural seams, at least 2.75 m
apart along the route. They point along the route and keep repair controls clear.
The strict passing margin is 0.55 m, confirmed for 0.4 s. Germination, wilting
and retraction take 1.3, 1.6 and 0.85 s. Consumed positions do not regrow on
backtracking. Cancellation, invalidation and unloading clear owned resources.
Private Euplotes presentations do not join the tardigrade hunting authority.

The native model contains eight meshes and 21,208 triangles, with zero collapsed
UV triangles. The final export SHA-256 is
**37a11af34f0bbe81aaf07c57a7de52f69f88036cf6a4d0769cb7736a35debdfd**.
The independent Blender generator, custom PBR maps and loaded mipmaps are
included. Soft multiscale membrane density and roughness variation provide the
requested mottling; thinner patches transmit more scene light, while the rim
stays thicker and senescence increases clouding. This is not a uniform fade.

The tardigrade/Euplotes shared membrane and tentacle gang membrane/tissue use
the same mean-preserving brightness and roughness variation. Existing species
colors, anatomy and hunting behavior remain intact. Both generators and their
runtime maps are on main; the tentacle handoff patch is historical evidence.

## Resolved checkpoint findings

The original composed-world route crossed too near the rear stair guard and
exited into the stair-head cabinet. The merged provider places its crossing
midway inside the authored turn clearance and ends the upper approach clear
of the cabinet. It shares those points with the world test. Collision and
support requirements were retained; no blockers were ignored to force a route.

The final independent export was imported twice and rendered in the verified
candidate. On 2026-10-26 its front, side, back, lamp-off, wilt, retraction and
clean frames were inspected, together with the installed radiator approach.
The former failing world receipt remains as historical checkpoint evidence;
use the **final** subdirectory for the successful result.

## Gates and scoped evidence

All final guide-bell evidence below is in
**art/reviews/vorticella_guide_bells_20261025/final**:

- **optical_runtime_contract.json**: 60 checks pass; no engine errors. Exercises
  lifecycle, optics, owned symbionts, physical route negative controls, cleanup,
  save-state preservation and actual radiator grab/motion/release input.
- **world_runtime_contract.json**: 17 checks pass; no engine errors. Includes
  the composed primary stair route, installed placement, monotonic distance,
  static attachment, control clearance, cancellation and unchanged job state.
- **optical_suite_run.json**, **world_suite_run.json**, **import1_suite_run.json**
  and **import2_suite_run.json**: completed process runs, exit 0. These are
  wrapper evidence, separate from the schema-2 runtime contracts.
- Both runtime contracts' LF-normalized test-source hashes match merged main.
- **implementation_verification.json** and **implementation_verification.md**:
  clean fresh candidate, zero gate regressions, 17 protected paths unchanged,
  no design lint errors, MERGE-CANDIDATE. This verifier used **--no-godot**;
  runtime was exercised separately by the receipts above. The spatial manifest
  was regenerated during integration and was the one changed gate file.
- The unchanged native UV receipt is **../native_uv.json**.
- Tardigrade/Euplotes: 103 checks pass; tentacle mottling: 381 checks pass.
  Their review images and runtime receipts remain in
  **art/reviews/cellular_mottling_20261025**.

Evidence limits: world observation positions are fixtures, not an end-to-end
played traversal. Moving lifts are not accepted as route edges; when no valid
stair alternative exists, guidance stays absent. The world run emits a texture
RID warning at whole-world teardown; the isolated guide-bell owned-resource
checks pass. No whole-building leak-free claim is made.

Changes outside the expected file boundary: **none by this follow-up**.
Open implementation findings from the checkpoint: **resolved**.
Decision needed from owner: **none**.

Implementation merged; final evidence preserved and stale blocked status retired.
