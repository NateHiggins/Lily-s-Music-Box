# Honed stair material verification — 2026-10-04

Evidence class: **INERT**

REPORT - V2-HONED-STAIR-MATERIAL - 2026-10-04

Branch / reviewed HEAD / origin/main / merge-base: **main** /
**47d78a011621aa25a3c1461649c9eddeff647c6a** /
**98ba522f2ae94c5db7ab9a176d308eed4a93b227** /
**98ba522f2ae94c5db7ab9a176d308eed4a93b227**.
The later metadata commit containing this report changes no runtime input.

Worktree clean at end: **yes**, after removing only untracked legacy importer
UIDs. The new regression test's own UID is committed. The owner's in-situ
catalogue stays unchanged at SHA-256
**1c97d690fd73325b00ae1f7ae84311bddd42dbd25bc10ae417830c8e3ef03525**.

Protected 17/17: **yes, unchanged against the merge-base**. Selector: **v2**,
with explicit **ORISON_BUILDING_ROOT=v1** rollback retained.
Ledger before -> after: **7 / 8 / 127 / 42 / 151 / 153** ->
**7 / 8 / 127 / 42 / 151 / 153**; requirements_changed: **none**.

## Result and bounded ownership

The existing **stair**, **stair_b** and **stair_c** families now use honed
marble pigment without the former repeated dirt/nosing bands. Their catalogue
chart remains **1.2 m**. Independent physical microrelief spans **0.16 mm**;
the owner's existing **2.5** relief factor remains. The semantic stair shader
now receives the same catalogue identity as an imported stair material, making
its physical height binding active. The named input is cached without mutating
the shared prop-library material. Mean colour stays within one 8-bit channel
value of the measured prior stone mean.

Stair geometry, supports, guard collision, routes, door mechanics, Mina,
schedules, save facts and lighting owners remain unchanged. The existing lamp
energy **6** and range **16** remain. This batch adds no service penetrations,
new catalogue keys or global material-table entries. The old raw marble plate
remains historical source art. Source provenance, the exact built-in ImageGen
prompt and rebuild commands are in **art/blender/stair_honed.md**.

Changes beyond the three material families are the scoped physical shipper,
the guarded texture-pin refresh tool, the actual-stair shader regression test,
its two new source-scanned asset references, and documentation. The arcade
manifest references only **stair_b** from this changed family: its three
existing texture hash/size pins and the registry's manifest hash were refreshed.
The guarded refresh checked every retained cell and protected input before
writing; cell glTF/BIN bytes, lineage and resource paths remain unchanged.
All earlier spatial dependency records were retained.

## Gates and rendered checks

The canonical in-place candidate verifier under **tmp/material-review/verified**
returns **MERGE-CANDIDATE 47d78a011621aa25a3c1461649c9eddeff647c6a**. It compares
the complete clean **98ba522f** board with **48 static/tools gates**:
**zero regressions**, reader **zero NEW**, spatial **zero drift**, and unchanged
ledger counts. Completeness exit **2** and the historical M11C1 protected-floor
hash tools-test exit **1** remain the known baseline findings. All other
static/tools gates pass; the three new **test_honed_stone_maps** cases pass.
The first material board's new test references and stale texture pins were
resolved before committing; that earlier board remains separately recorded.

- **HonedStairMaterialTest**: canonical verifier wrapper receipt
  **tmp/material-review/verified/godot/HonedStairMaterialTest_tscn.log.receipt.json**,
  exit **0**, completed; **294 surfaces, zero failures**. It checks real active
  height ownership, units, chart size and stable cache/shared-resource behavior.
- **Two-root matrix**: canonical verifier wrapper receipt
  **tmp/material-review/verified/godot/orison_v2_two_root_matrix_test_tscn.log.receipt.json**,
  exit **0**, completed in **154.03 seconds**; **44 checks**, all four production
  and rollback reconstruction combinations pass, including calendar, inventory,
  cases and optical facts.
- **Continuous vertical route**: wrapper receipt
  **tmp/material-review/vertical-route.log.receipt.json**, exit **0**, completed;
  **79 waypoints, zero failures** through both stair cores.
- **Actual delivered material comparison**: wrapper receipt
  **tmp/material-review/honed-production3.log.receipt.json**, exit **0**, completed;
  **608 checks, zero failures, 294 surfaces, twelve frames** at three occupied
  storeys' half-landings and flights. These are stationary capsule-clear
  inspections under the actual environment and existing lamp; the capture
  toggle hides the handheld device. Geometry owners remain identical.
- **Blender source comparison**: six flat/oblique images in
  **tmp/material-review/native-production**, directly reviewed with immutable
  before maps from **98ba522f**. No native source or geometry is regenerated.
- **Targeted rebuild**: **tmp/material-review/rebuild-determinism.json** records
  zero changes across **31 checked files**, including the unchanged three tread
  plates, plus unchanged catalogue/runtime material-table owners. The ingest
  audit reports **76 source slots, zero problems**.

The first two scratch capture attempts timed out after fixture errors: neither
has a suite verdict or contributes acceptance. All cited run receipts are
wrapper **suite_run** records, not schema-2 runtime contracts. This INERT report
and the captures confer no completeness-ledger promotion.

## Open work

This is a bounded stair finish acceptance. The broader geometry/material review,
independent bar/arcade service routes and distant-city closure remain open.
The concrete ImageGen study and the earlier plaster study are still scratch
alternatives; neither replaces production. Other unnamed semantic material
identities remain for their own material review. The unrelated old
**face_brick_c** height plate differs from a full shipper regeneration and
remains unchanged pending that review. The external output folders discussed
in the cleanup report remain intact, including the historical eighth export
required by an optional test class.

Decision needed from owner: **none for this completed stair batch**.

MERGE-CANDIDATE **47d78a011621aa25a3c1461649c9eddeff647c6a**
