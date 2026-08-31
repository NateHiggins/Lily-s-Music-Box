# Orison v2 M11C0 floor-01 independent-loadability cut rehearsal — 2026-08-31

Evidence class: **TECHNICAL CHECKPOINT — DISPOSABLE REHEARSAL — PRODUCTION CUT REFUSED**

## Disposition

M11C0 has completed the requested source census, target-partition design,
whole-node disposable split, independent cell-load rehearsal, exact
recomposition checks, dangerous-seam inspection, teardown exercise, protected
boundary comparison, and audit closure.

The rehearsal mechanism works. The proposed production partition is not yet
proved by the current export. The protected **floor_01.gltf/.bin** contains
**134 lineage-unresolved legacy primitives**, including specific demonstrated
cross-owner furniture, material, wear, and wall batches. Keeping that
remainder whole permits an exact disposable recomposition but prevents
independent Orison and exterior residency.

Recommendation: **REVISE THE PARTITION BEFORE PRODUCTION MUTATION.**

No production asset, layout, selector, runtime composition, project setting,
or historical evidence changed. M09, selector cutover, v1 retirement,
production-layout replacement, and production asset mutation remain
unauthorized. Nothing in this checkpoint is a merge to main.

## M11B human acceptance predecessor

Before M11C0 work, the owner verdict for M11B was recorded in
**design/ORISON_V2_M11B_HUMAN_ACCEPTANCE_RECEIPT_2026-08-31.md** and in the
M11B checkpoint. Commit **a9e455bfede9f89193c9acd0796eb8fc5a0c3548** records
**PASS — HUMAN ACCEPTED** for the F02/F04 service openings.

The accepted non-blocking debt remains: unusually dark service areas; a
tightly framed F04 core-side view; the unresolved southern riser choke; and
the absent F03 lateral service hall. That human verdict does not authorize the
floor-01 cut rehearsed here.

## Baseline and expected ledger movement

The first M11C0 write began from a clean worktree on
**codex/orison-v2-m11c0-floor01-cut-rehearsal** at M11B acceptance parent
**a9e455bfede9f89193c9acd0796eb8fc5a0c3548**. Its merge base with the
requested M11B base is exactly
**0ea23bfd1296a3779773886b1fc062f10288fa23**. The recorded **origin/main** was
**c2dc01771bc25b07f5dcf7a6040102345b8c57d5**. The committed selector was and
remains **v1**.

The declared ledger movement was **zero requirements and zero promotions**.
M11C0 is a disposable rehearsal, so newly specific ownership or consumer debt
does not constitute completeness evidence.

The baseline completeness audit contains **150** requirements:
**ABSENT 51, HUMAN_ACCEPTED 1, PROGRAMMED 44, RUNTIME_PROVEN 34, SHELL_ONLY 2,
SPATIALLY_PROVEN 18**. Blocker scopes are **0 / 1 / 86 / 45 / 101 / 103**.
Final counts are identical.

## Source-owned partition ruling

The deterministic source census classifies **5,286/5,286** records exactly
once. The smallest defensible production partition is 17 cells:

- Orison F01 interior;
- a separately owned Orison facade shell shared by Orison and exterior
  residency;
- street/site common;
- Passage common;
- bar and bodega; and
- eleven independently owned Passage shops.

Passage's legacy proxy and gateway belong to the street cell; Passage depends
on that boundary rather than duplicating it. Passage owns the common arcade,
aisles, openings, and party-wall work after the portal plane. Each shop owns
its inward threshold and shop volume. A geometry-free F01 composition host
must preserve production services and gameplay authority independently of
geometry residency.

Before any real export, the **42 walls, 565 site lights, and one slab** that
lack durable source identities need stable IDs and explicit ownership. The
production exporter must inherit owner from each source record and batch by
owner before material. Rehearsal content hashes are comparison provenance
only.

The complete target and safe-current rules are recorded in
**design/ORISON_V2_M11C0_FLOOR01_PARTITION_MANIFEST_2026-08-31.json**; the
source and consumer reasoning is in
**design/ORISON_V2_M11C0_FLOOR01_OWNERSHIP_CENSUS_2026-08-31.md**.

## What the disposable cut proves

The external splitter refuses geometry inference and assigns every current
whole node, mesh, and primitive exactly once. The safe-current partition has
17 files, but one is **CELL_LEGACY_MIXED** with all 134 lineage-unresolved
primitives.

The materialized split proves:

- **531/531** nodes and primitives assigned exactly once;
- no duplicate or omitted primitive;
- canonical node name, transform, world-bound, material, attribute, index,
  and payload equivalence;
- exact source/recomposition primitive and node-name multisets;
- independent import of every safe-current file;
- recomposition with the same 522 imported mesh primitives, 182,610 estimated
  render primitives, 380 collision objects, 380 collision shapes, and world
  bounds as the original; and
- deterministic public teardown with no second-cycle growth or shutdown leak.

The safe-current cell descriptors and BINs are **13,310,907 bytes** versus
**12,703,334 bytes** for the monolith. Measured overhead contributors include
**156 extra accessor records**, **367 extra material records**, repeated
texture/image descriptors, 17 sampler records, per-cell scene/asset metadata,
and buffer payload/alignment effects. The 304 texture files remain one shared
library.
Detailed per-cell costs and hashes are in the immutable machine receipts at
**art/renders/orison_v2/m11c0_floor01_cut_rehearsal_01/**.

## What it does not prove

The rehearsal does not prove:

- independent Orison-interior, facade-shell, or exterior residency;
- owner-first source rebatching of the 134 lineage-unresolved primitives;
- the facade-shell/interior collision or navigation seam;
- unique runtime semantic ownership after the target cells replace the
  monolith;
- bidirectional PlayerController navigation across future target-cell seams;
  or
- production streaming, gameplay CPU frame cost, or VRAM cost.

The session selector is consulted during reconstruction but is not serialized.
Durable semantic route, threshold, and return-anchor state does not depend on
GLTF node paths or raw coordinates, so the census identifies no save migration.
That is not a runtime alias proof.
**F01_DOOR_06**, **F01_BODEGA_DOOR**, **F01_BAR_DOOR**,
**PASSAGE_PORTAL_LT_W/E**, and each **SITE_SHOP_*** identity family still need
unique-owner resolution after a real target-cell export. The v1 bodega door
and v2 bodega threshold identities may not be conflated merely because they
refer to related locations.

## Runtime consumer work exposed by the rehearsal

The complete source/runtime census found these production consumer families:

| Consumer | Required production-cut work |
| --- | --- |
| BuildingRoot floor loader | Keep one geometry-free F01 host and replace the single PackedScene geometry load with an audited cell registry. |
| BuildingRoot indexing/visibility | Replace monolithic subtree/spatial classification and whole-F01 visibility with residency/cell-registry queries. |
| F01 host passes/directors | Keep generated/runtime authorities on a persistent host and make spatial scanners residency-aware; the instantiated FloorCoverage pass is dormant and is not counted as a current runtime consumer. |
| OrisonDetailPass | Keep its lobby/service actors, resident/floor detail, and nested domestic radios on persistent composition hosts or semantic owners, not unloadable geometry cells. |
| VantryPointNetwork | Parent F01 point batches and the Teresa shutter to the persistent host or semantic owner registry. |
| ExteriorDetailPass | Put persistent F01 site visuals/collision into governed cell or shared residency. |
| ResidentNav | Validate against the active semantic residency set rather than assuming complete loaded-world collision. |
| M11A exterior cell | Preserve it as an independent surface/semantic-data composition; do not absorb or duplicate it in the floor cut. |
| Save/reconstruction | Keep the selector session-only; preserve durable semantic route, threshold, and return-anchor facts without GLTF node paths or raw saved coordinates. |

These are production-cut prerequisites, not authority to redirect runtime
ownership during M11C0.

## Dangerous seams

The partition declares one geometry owner for every inspected boundary:

| Seam | Owner | Rehearsal result |
| --- | --- | --- |
| Orison south shell / street | facade shell | Original/recomposed hit, class, and position signatures match; target-cell owner and navigation are unproved. |
| Street / Passage portal | street common | Two safe-current contact signatures match; this does not prove the future owner or traversal. |
| Passage / shop aisles | Passage common | Two safe-current signatures match, but the aisle-side ray first contacts shoe-shop collision at 0.55 m; Passage ownership and navigation are **UNPROVEN**. |
| Bodega / street | street common plus bodega threshold | Two safe-current contact signatures match; target-cell ownership and traversal are unproved. |
| Facade shell / interior | facade shell | **UNPROVEN**; current wall/glazing/trim batches mix perimeter and internal emissions. |

The first three original/recomposed visual pairs are byte-identical. The
bodega pair differs in **20/1,440,000 pixels**, while geometry, collision,
bounds, draw calls, and visible primitives remain equal. The difference is
reported rather than hidden or called byte-identical.

## Runtime, timing, and teardown

The disposable runtime harness reports **PASS_WITH_UNPROVEN_SEAMS** because
target-cell seam ownership and navigation are intentionally not counterfeited.
Original and recomposed topology match; all eight authored rays have the same
hit/clear result, collider class, and contact position. The Passage/shop
observation described above is collision-equivalence evidence only, not
Passage-owner proof.

Two same-process warmed cycles settle with second-cycle growth of **0 objects,
0 resources, 0 nodes, and 0 orphans**. The deferred final boundary is **-6
objects, 0 resources, 0 nodes, and 0 orphans** relative to the warmed control.
No tracked scene, composition, PackedScene, query, space-state, or World3D
owner survives, and no ObjectDB/resource shutdown warning is emitted.

Warmed monolith loads measure **2,356.628 ms** and **2,334.087 ms**; matching
recompositions measure **2,348.914 ms** and **2,337.143 ms**. Instantiation is
approximately **14.2–14.8 ms** in both forms. Independently releasing and
loading all 17 cells sums to **11,329.751 ms** and **11,216.678 ms**; that
diagnostic is not a production schedule. CPU frame and VRAM figures are
unavailable. Forward+ capture GPU samples are recorded per frame in the
validation receipt and not generalized to gameplay.

## Validation and protected boundary

Focused suites pass **13/13** source-ownership checks, **5/5** splitter checks,
and **5/5** harness-contract checks. The source audit, materialized split,
runtime harness, and capture process all exit **0**. The packet contains all
eight matched 1600×900 Forward+ frames and their process, camera, hash, draw,
GPU, topology, collision, and teardown receipts.

All four static audit suites pass: completeness **99/99**, spatial **51/51**,
systemic **34/34**, and data **14/14**. Repository audits remain truthful:

- completeness exits **2** with the unchanged 150-row ledger and blocker
  scopes;
- spatial exits **0** with the unchanged **3,684** records and no drift;
- systemic authority exits **0** with the unchanged **59** findings and no new
  actionable or policy violation; and
- data consumption exits **1** with reviewed historical debt exactly unchanged
  at **1,289 unread fields, 11 unread files, 2 monotonic-only durable values,
  and 1 malformed record**.

The selector assertion is **v1**. Final bytes match the pre-write baseline for
**17/17** protected paths: both layouts, the selector, and every F01–F06/B1
GLTF/BIN. That comparison is durable and machine-readable in
**design/ORISON_V2_M11C0_PROTECTED_FINAL_RECEIPT_2026-08-31.json**. The
expected and actual completeness movement is zero. The evidence packet's
**partition_binding_receipt.json** binds the committed source manifest to the
materialized copy and splitter input hash. **runtime_process_receipt.json**
binds the clean process exit, stdout/stderr, warning scan, and runtime receipt.
**committed_packet_receipt.json** maps the external cut/capture run to every
immutable repository-relative artifact and Git-normalized blob hash.

Checkpoint evidence-impact exits **0** with **requirements_changed = []**.
The validation receipt's independent evidence-impact check also exits **0**
with an empty changed set. Neither document promotes a ledger row.

## Decision

The mechanism is suitable for a later provenance-aware rehearsal, but the
partition needs revision at the source/export boundary before any protected
mutation. The next rehearsal must remove **CELL_LEGACY_MIXED**, load the 17
target cells themselves, adapt every named dependent consumer in disposable form,
and prove the actual shell/interior and navigation seams.

**REVISE THE PARTITION BEFORE PRODUCTION MUTATION.**
