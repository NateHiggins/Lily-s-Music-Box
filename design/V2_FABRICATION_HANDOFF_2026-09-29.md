# V2 fabrication continuation — 2026-09-29

Evidence class: **INERT**

REPORT - V2 FABRICATION / BOILER CORRECTIONS - 2026-09-29

## Branch and verified scope

Canonical checkout: **C:/PleaseRemainOnTheLine**, **main**. Started from
**1d2b4fb6d2f289387d7287be8270632e90603c15**, which matched fetched origin/main;
there was no newer work. Completed source changes are in:

- **643c161b0f4e3aadb44fdcba576478476eb4d801** — both boiler doors swing outward;
  their solid plates follow the same hinges.
- **1ec300d18d5b89a6406bef03923502de6459ef55** — editable Blender breeching, production integration,
  contact tests and a regenerable V2 fabrication index.

Both commits were verified in place against complete clean preceding-main
boards, then pushed. The documentation commit containing this handoff follows
the second commit; its final local/remote identity belongs in the delivery
message and Git history rather than a self-referential hash in this document.

Worktree clean at end: no. Preserve **art/renders/insitu/shots.md** and
**shot_024.png** through **shot_028.png**. Verification made checked backups
under ignored tmp directories and restored all six exact owner byte streams.
No rescue archive or reference-image bytes were committed. No worktree was
created. Generated untracked import UIDs were removed after verification.

Protected 17/17: yes, with the already-authorized selector default retained.
Selector: **v2**; explicit **ORISON_BUILDING_ROOT=v1** rollback remains.
Ledger before -> after: **[7,8,127,42,151,153] -> [7,8,127,42,151,153]**;
requirements_changed: **[]**. No new runtime-contract acceptance is claimed.

## Completed coverage and sources

The owner's reported door defect affected both the firing and ash leaves.
Negative local Y rotation drove their positive-X free edges through the boiler.
Both immediate and tweened paths now swing outward. Moving plate collisions
were added; the fixed plant and all maintenance/state owners remain.
The focused production test samples fourteen moving poses, compares actual
merged triangles and physical contacts, checks closing and immediate restore.

Three hollow six-gore elbows replace the sphere joints in the boiler flue.
The first mouth seats on the real horizontal smoke collar. Straight pipes and
slip bands join their tangent ends; bend collision uses the same triangles.
The pipe library has 170 mm outer radius, 3 mm walls and 270 mm bend radius.

- Generator: **art/blender/scripts/build_breeching.py**.
- Editable source: **art/blender/breeching.blend**.
- Export: **game/assets/props/breeching.glb**.
- Runtime placement: **game/scripts/building/orison_v2_boiler_flue.gd**.
- Door authority: **game/scripts/props/boiler_prop.gd**.
- Notes: **art/blender/breeching.md**, **art/blender/boiler_door_swing.md**.
- Coverage decisions: **art/blender/v2_fabrication_coverage.md**.
- Structural/installation index: **art/blender/v2_fabrication_inventory.json**;
  regenerate with **python tools/inventory_v2_fabrication.py**.

The index includes all 200 semantic spaces and ten structural tables, plus
thirteen installation/program data files, building asset references and
Blender generator locations. It is discovery, not an assertion of completed
geometry. The focused run also emits a live mesh/material census beside its
captures. That census observed 11,378 geometry nodes, 9,812 visible in the scene
tree; composed/debug content and intentional simple primitives are included.

## Material and performance decisions

No new bitmap, catalogue key or shader was introduced. Breeching keeps
**cast_iron** and **metal**, resolved through MatLib and the generated material
table. It has metre UVs; variable pipe lengths are baked into mesh vertices
and UVs so the existing local triplanar projection does not stretch with
MeshInstance scale. The broader architectural SurfacePass, calibrated layers,
lamp/voxel integrations and carried HUD are unchanged.

The three elbow instances share their mesh, with 12,672 triangles total.
Their two material surfaces add three draws relative to the three former
single-surface sphere joints. The library export is about 303 KB. The live
census retains render counters, but those include multiple passes/viewports;
no controlled full-building frame-time comparison or performance acceptance
has been completed.

## Verification and rendered evidence

**tmp/boiler-doors/verified/verification.json** and **verification.md** contain
the accepted door candidate result, complete gate board, protected-path checks,
double import and bound receipts for BoilerDoorSwing, Blockout, BoilerRoute
and TitleContinueActualLaunch. **tmp/breeching/verified** contains the same
roster with Breeching in place of BoilerDoorSwing.

Both boards: ledger remains INCOMPLETE/exit 2 by design; spatial, systemic,
period, reader, carriers, rulings and every tools test pass. Reader has zero
new unread fields; board comparisons have zero regressions. The spatial
manifest adds only the reviewed new test references/camera station and elbow
name template. Existing classifications and gate logic are unchanged.

Numbers requested: **BOILER DOOR SWING: doors=2 animated_samples=14 failures=0**;
**BREECHING: elbows=3 collision_contacts=18 elbow_triangles=12672 failures=0**;
production **V2 BOILER SERVICE: 17 waypoints; 0 failures**. The route exercises
actual E controls, both door states, draft/heat response, water-column proving
and return through the fire door. All cited completed suites have adjacent
**.log.receipt.json** files. Wrapper receipts are suite-run evidence, not
runtime-contract proof.

Inspected captures: **tmp/boiler-doors/shots**, **tmp/breeching/shots** and
**tmp/breeching/route-shots**. Detail views use a local inspection fill;
route views use the actual carried lamp and readable physical paper HUD.
The first pre-change route hit its 60-second ceiling. Its rerun failed the
lamp-settle assertion; neither is counted as passing. Subsequent completed
production routes and candidate routes passed without loosening that test.

## Remaining work and exact continuation

The user's full geometry and texture/mapping request is **unfinished**. The
coverage document is the next work queue, not a substitute for implementation.
The boiler still needs a fabricated body/firebox interior; the outward-door
views expose the existing shallow throat treatment. Broader fixtures, roof
machinery, ducts/supports, public furnishing, apartment variants and all
uninspected space installations remain. Reuse the accepted lift, window,
millwork, roof-tank/coping/chimney, wet-fixture and critter work.

The coordinated texture pass has **not begun**. Its material families and
current production binding decisions are recorded in the coverage document.
Complete geometry first, then validate representative material families under
production lighting before broad rollout. Do not interpret existing texture
bindings as completed mapping or material acceptance.

Known preserved limitations: static window sashes and tank lid; decorative
lift emergency-stop presentation; exterior wall-thickness issue from the
prior handoff; no new gas/fluid simulation. Existing TASKS H23 and historical
M11C1 debt remain. No full zoo, continuous-shift or whole-building visual
acceptance claim is made for these scoped boiler batches.

Decision needed from owner: none for the remaining authorized routine work.
Check fetch/status before continuing, preserve owner files, obtain a clean
current-main board or extract the clean candidate_board from the last verified
JSON, use named-path commits, and push only verified work.

## Launch and zoo

From PowerShell:

```powershell
cd C:\PleaseRemainOnTheLine
Remove-Item Env:ORISON_BUILDING_ROOT -ErrorAction SilentlyContinue
$env:ORISON_TITLE_DEBUG = "1"
pwsh -File tools/lane.ps1 run -Scene res://scenes/ui/title_screen.tscn -Windowed -Runner long -TimeoutSeconds 1500 -LogPath tmp/v2-play.log
```

Choose Debug Building, F1, GO — teleports, Dream zoo or Dream ecology.
Leave camera exits inspection; Building return restores the prior building
position/view. F1 closes the controls; backtick releases/recaptures the pointer.
Direct zoo launch:

```powershell
pwsh -File tools/lane.ps1 run -Scene res://scenes/debug/ZooVisit.tscn -Windowed -Runner long -TimeoutSeconds 1500 -LogPath tmp/zoo-play.log
```

For explicit rollback set **$env:ORISON_BUILDING_ROOT = "v1"** before launch.
Use the lane status/wait support when occupied; never close another Godot.
The accepted hero, organelles, sixteen critters and reserved bays remain.

Last implementation verdict: **MERGE-CANDIDATE 1ec300d18d5b89a6406bef03923502de6459ef55**.
