# V2 complete powered-wringer washer rebuild

Evidence class: **INERT**. Implementation report; no whole-building acceptance.

The owner rejected the control-only washer prototype for unconvincing form,
incorrect mechanical fitting and poor textures. That prototype is superseded
by a complete reproducible Blender assembly, not accepted as the final model.
The retained **B1_WASHER_01** and **B1_WASHER_02** actors still own service,
NPC, sound, mechanical and household-save behavior.

The rounded-square galvanized tub has real sheet thickness, rolled edge,
hollow interior and a bored floor drain. Four bolted angle legs carry the
motor cradle, gearbox and swivel column. A fixed rear deck carries the inlet
unions and valve supports; a shorter hinged cover clears the swivel post.
The fixed deck follows the rounded cover corners rather than leaving gaps.
The retained supply and drain hoses meet the new unions and outlet.

The wringer has bored bearings, centered rotating shafts, a sliding upper
bearing carriage, guide slots, a moving crosshead and a helical pressure screw.
Its pressure foot stays on the carriage saddle through pressure adjustment
and safety release. The rollers rotate around their shafts instead of orbiting
the swivel. Safety release disengages drive and raises the upper carriage;
tightening cannot override the trip. The reset lever re-latches with drive off.

Native mesh intersection sampling produces a conservative lid-clearance table.
Both hand movement and service tweens use that table. The wringer swings from
-75 to +90 degrees; full 82-degree lid opening needs it swung aside. An open
cover stops the wringer returning through it. Restoring legacy poses clamps
incompatible lid angles to the new physical clearance without rejecting the
old three- and four-field save formats. This checks internal lid/wringer fit;
it does not certify every nearby obstacle or continuous room navigation.

Four new catalogue finishes provide fine galvanized zinc, warm white enamel,
clean brass and restrained rubber, with separately authored roughness and
normal maps. The zinc albedo is a new generated source, copied unchanged;
no reference photograph is baked. All new stock has metric UV charts and
native-export tangent validation. A focused imported-mesh check found 96
collapsed UV triangles under compression; this asset now preserves UV precision.
The other assets retain their existing import policies. All 12 shipped maps
have loaded mipmaps. Additive material provenance verifies that the 213
pre-existing texture files are unchanged; six old construction/fixture records
receive provenance-only updates with existing drift preserved.

Primary click acquires a visible part, mouse motion changes its constrained
position and another click releases it. Independent fill cocks, drain and two
drive levers retain fractional settings. Water quantity follows both fill and
drain; this is a local tub simulation, not a new hydraulic or spill network.
Nine-field household records retain those settings and reject invalid states.
Legacy click methods return the existing wire card without operating anything.

Verification passes for this washer scope. Historical rejected/failed/timeout
receipts remain in **tmp/v2-next-20261013**. Neutral native review images are in
**art/renders/orison_v2/washer_controls_20261013**. Studio images establish form
and fitting; installed captures establish production placement and appearance.
This report does not promote any completeness-ledger requirement.


The final complete asset has 39 finish primitives and 100,078 triangles;
native tangent agreement is at least 0.9999999504. The imported asset has zero
collapsed charts and all 12 new maps have mipmaps. The focused installed suite
passes 134 checks, and the windowed manipulation bench passes 95. Refreshed
schema-2 production contracts pass apartment access (268 checks, 19 rooms),
service/save (113 checks) and surface qualification (26,435 checks, zero
unresolved surfaces; 23,745 draws, 16,226 meshes, 5,843 materials, 465 textures).
The complete 55-gate board has no regressions against the preceding tower
checkpoint board. One test-only texture-path template was registered after
review; the spatial gate was rerun and unchanged checks reused explicitly in
**gate_board.json**. Reader NEW remains zero. Ledger blockers stay
**0 / 1 / 102 / 34 / 119 / 121** across 240 requirements.

The seven existing Texture RID shutdown leaks remain visible in the composed
run receipts. A failed headless interaction diagnostic is not the windowed
PASS. An early serial washer run hit its 180-second ceiling and reported no
verdict; the final long-runner diagnostic completed in 185.68 seconds. No
runtime receipt was repinned by hand. The native/installed review packet and
canonical surface packet supersede the rejected prototype, without claiming
human acceptance, continuous basement navigation or a complete V2 world.


## Section 7 publication report

REPORT - V2-WASHER-REBUILD - 2026-10-13

Branch / candidate / origin/main / merge-base: **main** / **1ab265bed8c5a942403081b0684d490674873a71** /
**e0b0dd293325a49c207785888112262a4990e474** / **e0b0dd293325a49c207785888112262a4990e474**.
The follow-up documentation commit does not change production or render inputs.
Worktree clean at end: **no**. Unrelated inherited artifacts, line-ending-only
changes and rejected prototype files remain unstaged. Exact current paths are
recorded in **tmp/v2-next-20261013/left-dirty-paths.json**. Named paths only were
staged; no unrelated work was cleaned or included.

Protected 17/17: **yes**, all unchanged against this merge-base. The previously
authorized default is **v2**, with explicit V1 rollback retained.
Ledger before -> after: **0 / 1 / 102 / 34 / 119 / 121** ->
**0 / 1 / 102 / 34 / 119 / 121**; requirements_changed: **none**.

Gates: **art/renders/orison_v2/washer_controls_20261013/gate_board.json** records
all 55 actual gate results, including every tools test. All pass except the
existing incomplete ledger (exit 2); baseline comparison has no regressions.
The reviewed test-only asset template caused one initial spatial comparison
finding; its exact fixture was registered and that gate rerun (exit 0).
The board explicitly records reuse of unchanged checks after this manifest
update. Reader NEW: **0**. No clean-main merge-base verifier run is claimed.

Godot receipts and PASS lines:

- **washer.log.receipt.json**: WASHER CONTROLS: PASS; 134 checks; 0 failures;
  completed, exit 0, 185.68 seconds. This is a diagnostic suite_run receipt,
  not whole-building runtime acceptance.
- **bench.log.receipt.json**: DIRECT MANIPULATION: PASS; 95 checks; 0 failures;
  completed, exit 0.
- **native_uv.log.receipt.json**: 100,078 triangles, zero collapsed UVs,
  zero unmipped new maps; completed, exit 0.
- **tmp/v2-next-20261013/apartments-full.log.receipt.json**:
  V2 APARTMENT ACCESS CONTRACT: PASS; 19 rooms; 268 checks; 0 failures; exit 0.
- **tmp/v2-next-20261013/contracts-full.log.receipt.json**:
  ORISON V2 M08F RUNTIME: PASS checks=113; exit 0.
- **tmp/v2-next-20261013/surfaces-full.log.receipt.json**:
  V2 SURFACE QUALIFICATION: PASS; 26,435 checks; 0 failures; exit 0.

Runtime proof is in the test-written schema-2 canonical apartment, first-slice
and surface contracts, freshly bound to unchanged production/render inputs.
Numbers: two washers, 39 native finish primitives, 100,078 triangles, four new
catalogue finishes, 12 mipmapped maps; 213 previous shipped textures unchanged.

Changes outside prop/art boundaries: an additive material provenance update in
six existing fixture/construction files; one targeted UV import policy; the
surface, access and service/save evidence refresh; three reviewed test-only
manifest records; focused test scenes; and a cheap script-compilation preflight
with batch-workflow documentation. They support this rebuild and do not alter
spatial authorities. Open findings: existing Texture RID shutdown leaks,
broader navigation and human visual acceptance, unfinished V2 ledger items.
Decision needed from owner: **none for this checkpoint**.

MERGE-CANDIDATE 1ab265bed8c5a942403081b0684d490674873a71
