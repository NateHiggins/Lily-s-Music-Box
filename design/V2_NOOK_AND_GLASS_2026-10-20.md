# Glass optics repair and retained reading-nook stock

Evidence class: **INERT**. Implementation and diagnostic review; no ledger promotion.

Subsequent qualification: **V2_QUALIFICATION_RENEWAL_2026-10-20.md** records the
current composed surface PASS, 40,122 checks and zero failures. The board and
qualification debt described below belong to the earlier checkpoint; broader
route/runtime renewal and integration remain separate.

The ordinary architectural glass shader disabled refraction, attenuated its
already shallow normal texture by 0.035, and sampled the roughness texture's
constant white red channel instead of its authored green channel. The nook's
separate StandardMaterial3D consumer also omitted refraction. Forward+ was
confirmed on the actual Vulkan/RTX 4080 device; this was not a project renderer
selection problem. Existing cut, reeded and frosted cabinet treatments already
refract in the loaded renderer and were retained.

The architectural shader now uses full authored normal strength, green-channel
roughness and normal-driven screen refraction. It carries already-lit scenery,
retains native specular lighting and rejects foreground samples near silhouettes.
The nook's alpha-glass source material now enables engine refraction. Neither
path adds an independent light, animated distortion or another texture. Screen
refraction excludes transparent scenery and off-screen information; this does
not solve nested transparent vessels or caustics. See the
[Godot screen-reading documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html).

**V2GlassOpticsBench** compares six production materials against identical opaque
striped scenery using the production carried voxel lamp. Baseline and corrected
captures include bare scenery, mapped glass and flat normals. Architectural
mapped-versus-flat mean RGB difference rose from 0.000102 to approximately
0.0154 in the fixed 85-pixel central sample. This is a diagnostic under a fixed
camera, not an appearance score or whole-world proof. The test also checks actual
Forward+ availability, loaded maps and complete mip chains. The final required
effects run passes, as do the imported clock and separate lamp receiver tests.

## Retained work completed before the glass steering

The original fifteen nook anchors remain. Sixty retained static book reserves
and the cushion's face-down reader now contain 61 independently movable,
readable copies of 26 shared casebound titles. An authored programme pins copy
IDs to titles; rare personal editions are excluded. Native production adds 351
closed parts without scaling the old dimension reserves. Six existing pressed
bookends support occupied levels. Their upturned heels sit outside the full
book-depth envelope; actual foot thickness raises bearing positions with
350-micrometre clearance. No collision exceptions are used.

Three loose collections inherit existing stock, grab, inspection, opening,
snapshot and validation authority. Copies have separate physical and title IDs.
The existing household books domain discovers these owners and persists them
through its original disk writer. Initial rest uses the existing one-shot pose
synchronization; extracted books wake and can topple neighbours. Fused static
covers and page blocks were removed. All original non-visual anchors remain.

Source review loads the actual nook and native books together. External stock
contacts pass; four source views show the rack, pile and tented reader. All 26
featured spreads and five contact sheets were visually inspected. The source
review mesh hash still matches the final rebuilt asset. The original V1
distribution remains; further visual variety is a polish option.

## Diagnostic record and limits

Review packet: **art/reviews/v2_nook_and_glass_20261020/index.html**. Original
stdout/stderr bytes are retained beside wrapper receipts and covered by the
portable receipt-hash regression. These are **suite_run** receipts, not schema-2
runtime contracts.

- **nook-bench1**: 2,242 checks, one failure finding a standing hand approach.
  Its floor-only datum put the capsule inside the eight-millimetre rug. The
  driver now raycasts actual floor/rug support and retains the real capsule and
  safety margin. No furniture or player geometry was changed to pass it.
- **nook-bench2**, then **nook-final** after the optical correction: 2,251 checks,
  zero failures each. Actual grab/Space/extraction/turn/open/release, native UVs,
  tangents, loaded PBR mips, initial contacts, print layouts and fresh collection
  snapshot reconstruction pass. This isolated fixture is not a room route.
- **nook-regression-core**: original library bench, 766 checks, zero failures.
- **nook-installed1**: 254 checks, zero failures in 333.03 seconds. The full
  composed suite exercises ten existing case controls and original household
  disk/save/new-world reconstruction, including all three new collections.
  It precedes the glass-only correction; unchanged save and hand authority
  results are reused. It is not current whole-world optical qualification.
- **after2**: six-material diagnostic, required effects and mip checks pass.
  **clock**: 163 checks, zero failures. **lamp**: 25 checks, zero failures.

REPORT - V2-NOOK-GLASS - 2026-10-20

Branch: **codex/v2-fire-fitting-checkpoint**, based on **083cb3b5**.
Main/merge-base: **82887a14**. Implementation remains on the checkpoint branch;
it has not been integrated into shared main. Protected source paths are outside
this batch (17/17 unchanged against main); selector remains V2 with explicit V1 rollback. Ledger before/after:
**7/42/110/8/134/136**; requirements_changed: none. Main baseline remains
**0/25/21/1/38/40**.

The retained full board has 100 gates: 96 PASS, three FAIL, one INCOMPLETE.
One failure was the unstaged new native model/import pair; the subsequent
admission rerun passes all 331 references after named staging. Other failures are the branch's stale composed
surface qualification and two existing completeness assertions. The ledger has
117 baseline regressions. Reader reports zero new unread fields; spatial audit
reports no new references. The optical correction needs fresh surface
qualification before merge. All 36 focused nook/surface tests and four original
library tests pass, including portable receipt hashes. The 53-asset precision
import policy passes; the final reader still has zero new unread fields.
Import-only CRLF churn was restored after byte comparison and unrelated generated
legacy UIDs were archived under ignored tmp. The reviewed checkpoint has no
remaining implementation edits. This checkpoint is not merge-ready.

Changes outside the nook: shared architectural glass shader, reader identity
classification limited to the exact new file's two dynamic maps, reviewed
spatial references, import policy, regression tests and source provenance.
No additional owner decision is needed. Whole V2 completion, composed
qualification and human appearance acceptance remain open.

BLOCKED - pre-existing branch cohort/surface qualification and ledger regressions.
