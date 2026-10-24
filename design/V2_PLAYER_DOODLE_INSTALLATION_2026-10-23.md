# Owner rig and reflected idle

Evidence class: **INERT**. Installation and diagnostic review, not acceptance.

REPORT - owner-player-rig - 2026-10-23

Branch / HEAD: **codex/v2-acoustic-topology**, parent **b44d11f6**.
Canonical checkout **C:/PleaseRemainOnTheLine**; shared spatial manifest and
untracked street/tent/traffic work remain outside this checkpoint. Worktree is
not clean. Selector remains V2 with explicit V1 rollback. No ledger promotion,
clean candidate qualification or human acceptance is claimed.

## Installed result

The newest owner archive in Downloads was **Meshy_AI_Smiling_Stick_Figure_biped.zip**.
Its animated FBX, static FBX and supplied maps are preserved under
**art/source/player_doodle_20261023/**. The native Blender owner is
**art/blender/player_doodle.blend**, reproduced by
**art/blender/scripts/build_player_doodle.py**. The source inspection and build
record are in **art/reviews/v2_player_doodle_20261023/**.

Decimation before the armature reduces 198,520 triangles to 19,852, preserving
52 bones, authored UVs and the supplied 300-frame / 30 Hz idle. The rig is fitted
to the existing 1.524 m player height. Object-level FBX transform tracks are
removed; skeletal tracks remain. The custom **player_doodle** catalogue finish
uses the supplied albedo, normal and roughness maps, with loaded mip chains.
Source metallic data remains archived; the charcoal/paper finish is nonmetallic.

The visual follows the existing controller and adds no physical, inventory,
case or save authority. Render layer 16 excludes it from the first-person eye
and cached cube probes, while the existing single borrowed mirror view includes
it. Animation sleeps when no mirror is selected. Movement pauses the idle in
its initial pose; a proper walking/crouching animation remains outstanding.
No new camera, viewport or light is added for this character.

## Issue log

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Owner animated FBX | Import full source into the occupied world; avoidable mesh cost, medium | 198,520 triangles, 52 bones | Native 10% decimation before skin modifier | 19,852 triangles, zero degenerate UV triangles, inspected front/back/mid-idle native renders |
| FBX object orientation | First native build has incorrect vertical extent; high | Original **native_build.log** retained | Normalize signed head-to-hips axis and remove redundant object transform animation | Corrected **native_build_v2.log**, isolated upright Godot rig images |
| Imported skin visibility | Automatic rest AABB lies at foot level while the evaluated skin stands upright; high | **rig_v1** geometry/pose record and original **world_v1** missing-character images | Once-only conservative skeleton-space custom AABB | **world_v2** actual mirror images visibly contain animated head |
| Mirror review stance | Looking at glass obliquely shows the side of the room; diagnostic error | Original **world_v1** images | Find a self-view along the mirror normal using the full real player capsule, retaining basin/room collision | Clear actual stance and selected actual 3B mirror checked in **world_v2** |
| Review bone names | Three empty pose dictionaries cause the original review to fail; diagnostic error | **world_v1/review.json** | Use imported underscore names established in isolated rig bench | Three differing nonempty pose records in **world_v2/review.json** |

## Verification and limits

All engine runs used shared-lane wrappers and original failures remain.
**world_v1.log.receipt.json** reports failure; **world_v2.log.receipt.json**
reports a completed 157-second run with **PLAYER MIRROR REVIEW: PASS**, 18 checks.
These are wrapper **suite_run** receipts and an INERT diagnostic, not a
test-written schema-2 runtime contract.

The three player-camera images **world_v2/mirror_idle_1.png** through
**mirror_idle_3.png** were inspected. Real-time clip positions are approximately
1.11, 4.90 and 8.47 seconds; head/hand/foot transforms differ. An actual mouse
turn away stops the avatar animation. The existing bathroom mirror crops the
head around its lower region; these images do not demonstrate full-body motion.
The mirror's pre-existing grain/checker appearance and bright sconce remain
visible limitations. No claimed frame-time improvement follows from triangle
counts alone. A repeatable whole-world performance comparison is still required.

Catalogue append proof **catalogue_append_v2.json** verifies 292 existing runtime
texture files unchanged and updates 29 binding-only documents. It explicitly
preserves 820 existing stale bindings. The initial older refresh tool could not
find the legacy arcade-throat fixture and wrote nothing; the existing additive
rebind tool was then used. Eight additive-tool tests pass. Original material
persistence failure is preserved; adding the key to the catalogue generator
source makes the corrected one-test persistence run pass.

Final focused checks: 32 surface tools tests pass; all 1,383 referenced texture
imports satisfy the V2 policy. All 17 protected paths are unchanged after LF
normalization against the parent. Reader retains 33 NEW findings from unrelated
street/tent data, and physical source retention retains four findings on the
untracked street-tent and traffic model/settings pairs. No avatar finding remains
in that retention check. See **static_checks.json** and its raw logs. The full
gate board and candidate verifier were not rerun; no clean-candidate claim.

Open findings: realistic reflected locomotion/crouching, idle wrap continuity,
facial variants, reflected held-object presentation, broader mirror coverage,
performance qualification and the remaining started-work inventory. The supplied
idle is installed, not a claim that the whole player request or V2 is complete.

Decision needed from owner: none; resume measured bathroom movement work.

BLOCKED broad qualification remains incomplete; scoped installation reviewed
