# Astra pause and resumption — 2026-09-19

Evidence class: **INERT — handoff; promotes nothing**

The owner requested a pause to conserve tokens. This is a local WIP checkpoint, not a merge candidate. The Godot lane is free; all native runs finished, and all three agents stopped. No push, merge, selector change or release was performed. Resume from this checkpoint; do not repeat the accepted critter merge or restart reconciliation from the old prompt's HEAD.

## Repository and preserved state

- Production: **C:/ov/astra-main-acdb4be**, branch **codex/astra-reconcile-20260919**. This handoff is committed with the navigation WIP. Its parent is **2dbd020e5f290cbc4c3d81c75307c71e023f2b22** (tested audio/save repair).
- origin/main and merge-base remain **acdb4be42e5d973df623c3545aacde95855a1d07**. Selector remains **v1**; the seventeen protected main assets are unchanged. No fetch was added solely for this pause; fetch and record movement before resuming integration.
- Earlier checkpoints: **9b937ac** reconciliation, **55e99dc** renderer/equipment, **bcff0a5** systemic audit, **2dbd020** audio/save. Accepted critter merge is **65b5ebf**. Main has not been moved.
- Preserve the existing unrelated generated untracked UIDs. This WIP adds only the two new owned test UIDs, taken from the diagnostic imports. Do not add all, reset, stash, clean or alter historical branches/backups/propref.
- Diagnostic tree **C:/ov/astra-r1-runtime-55e99dc** is deliberately modified, not pristine HEAD55. It now contains the tested audio/save changes and current nav/test sources. Its DoorProp comment placement differs from production, with identical executable code. Keep it for exact receipt reconstruction.
- Evidence: **C:/ov/astra-r1-evidence** and **C:/ov/astra-review-20260919**. Preserve **C:/PleaseRemainOnTheLine-propref**, including ignored raw shoots and unique references.

## The immediate remaining defect

The original F06 error is reproduced at Sacha Reed's legitimate paced position in 6A: (-8.25416,16.03,4.251141) to the public lift wait (1.925,16.03,7.4). Furniture pruning stranded an internally connected nine-node component. The WIP adds at most eight room-derived candidates, admits only actual component bridges, and proves conservative body clearance, authored walls/slabs/holes and physical support. Original blocked furniture exits remain cut.

Thin authored floor finishes at 16.017/16.021 are below the actual 16.03 foot plane. The new room/portal proof admits them while preserving the original short-direct support policy. Original portal-adjacent edges and validated endpoint attachments now use the actual resident Body (.28 radius,1.55 height), because the conservative .33/1.65 envelope touches a switch at this valid start. Only actual DoorProp._body RIDs may be excluded for prospective managed-door paths. New room detours and direct shortcuts exclude no colliders. Fixed frames and closed elevator panels remain blocking. The source contains no production F06-specific exception.

The resulting static route clears the actual Body, but **the physical walk still fails**. The final diagnostic independently identifies only **F06_DOOR_02/HingedLeaf** in start/end overlap after 442 physics-frame movement steps (~7.22 seconds). The door is open=true, moving=true, local angle1.1477325 radians (~65.76 degrees); the resident moves from (-6.3876724,16.03,1.7087089) toward (-6.3702688,16.03,1.7068768), path leg4, door_cycle1. Movement excludes **zero** colliders. This is a real opening-leaf collision, not a waived test margin.

**Next edit has not been applied:** ResidentRoutines._manage_home_door currently marks cycle1 immediately after requesting opening, even when DoorProp ignores that request while moving, and callers immediately move. Make it report passage readiness and gate its five existing route-follow callers until the actual door is open and settled. Keep far/no-door/already-open traversal valid, respect locked refusal, retry a request refused during closing, and leave closing behind a passed resident asynchronous. Preserve the existing DoorProp tween, lock, audio and interaction owners. Add actual translated owner controls and replay the identical F06 diagnostic; do not add a fixture sleep or collider exclusion. Physical fully-open clearance still needs the actual after-run.

ResidentRoutines is unchanged, raw SHA256 **2a34334b157d0c895437b03d9d88c6a21cfc5645329bb0104bee248540642d3a**. Its exact before bytes are saved in **nav_detour_controls/door_motion/resident_routines_before.gd**.

## Native results and exact scope

All paths below are under **C:/ov/astra-r1-evidence**. These are scoped harness results and bound suite_run wrappers, not schema-2 runtime_contract promotions.

| Evidence | Result |
|---|---|
| nav_detour_controls/portal_body/before_room | 66/70, four expected frame/lift physical-refusal failures against prior88dd nav; empty stderr |
| nav_detour_controls/portal_body/after_room | 70/70, current nav; empty stderr |
| nav_detour_controls/portal_body/before_f06 | 15/18, three physical-route/movement failures |
| nav_detour_controls/portal_body/after_f06 | 18/19; static route passes, actual opening-leaf walk fails |
| nav_detour_controls/portal_body/contact_diagnostic/direct | 37/37, empty stderr; four new public-route controls restore meaningful public API coverage |
| nav_detour_controls/portal_body/contact_diagnostic/f06 | 18/19; exact leaf/angle contact above; one inherited found-art warning, no ERROR/SCRIPT ERROR |
| nav_detour_controls/portal_body/consumers_initial/lift_waiting | Existing 4D consumer40/40; inherited found-art warning only |
| nav_detour_controls/portal_body/consumers_initial/passage | 26 actual [ok] checks,0 failures; wrapper counts one PASS summary; inherited warning only |

**nav_portal_body_independent.json** (SHA256 **7ec5ea597e5b6ed77907e611710f778764dfdec0452309f3ec98dba9e3c35849**) independently binds seven original portal/control/consumer runs to retained raw sources and reconstructed runtime manifests. It covers the initial33-check direct test, not the later37-check/contact runs. The reader independently reviewed the four new public-route assertions and found the coverage defect closed, but did not finish independently auditing those latest native receipts. Root verified the37-check receipt with run_receipt.py; F06 verification reports only its actual nonzero exit. Do not describe that failed receipt as a pass.

Earlier retained failures and controls: original room island; first detour still unreachable; floor-finish before52/56→after56/56; missing optional synthetic JSON in that first finish pair is explicitly recorded (logs/source still bind). Later writer-fixed support run supplies its real JSON. The full collision validation in the portal diagnostic measured1.611 seconds including~763ms room detours,52 nodes/176 links building-wide. These observations are not composed performance acceptance.

Frozen production raw hashes at pause:

| Source | SHA256 |
|---|---|
| resident_nav.gd | bae793e4058c2b895815c28a39b6e87f09f83fcda863a825f9ed45cda767bf13 |
| resident_nav_room_detour_test.gd | a91befcd861304f014904aa5ed28270b4c0f0a783bdba58f50e52184aa812a76 |
| resident_f06_route_test.gd | c87dfd2b357574c4dcd4c90b2af21a05c1b1d9c727bdb3912b562ba31d11cc7a |
| resident_nav_direct_segment_test.gd | c385d9cb00dfc2146349bbf8e8c0120d4f83dd13de2f92636b5b537d38146551 |

These raw worktree hashes bind the diagnostic sources; Git's normal text checkout may change line endings. Preserve snapshots when verifying old wrapper hashes.

## Reconciliation already completed

The full provider matrix with isolated per-invocation saves passes26/26 with four real same/cross-provider direct save/load transactions, equal semantic facts, both shells retired and owned successful bundles cleaned after receipt. No renderer/script/resource ERROR remains;14 inherited found-art warnings remain. Evidence **provider_matrix_isolated.log.receipt.json**, actual **provider_matrix_isolated_receipt.json**, **TEST_SAVE_ISOLATION_INVESTIGATION.json**, **provider_matrix_isolated_independent.json**. Actual matrix schema is **orison.m11c2.production-matrix.v1**, not schema2 runtime_contract.

Door audio ownership before6 failures/12→after12/12, calendar52/52 twice, external storage probe25/25, verbose headless production critter70/70 with95 weak decoder references retiring in two frames and no exit-resource errors. These results are committed at2dbd020; production storage was not changed. See **native_followup_independent.json** and the main reconciliation report for exact binding limits.

The latest fresh committed static verifier is still **verification_9b937ac/verification.json**, not this WIP:11 named regressions/208 improvements,36 tools-test files passing,17 protected paths unchanged, selectorv1, no doc lint errors, --no-godot. Ledger obligations remain7/8/136/50/159/161 versus main7/8/84/52/107/109; all78 changed requirements are explained in the report. Seven visible test REVIEW findings and their aggregate remain unbaselined. **gate_changes_independent_review.json** completes independent review of21 gate paths; later systemic corrections have58 passing adversarial tests and unchanged65 live findings. No regression override was used.

The new nav fixtures' spatial-manifest rows remain **pending**. The older external five-row insertion packet is stale and must not be applied. This WIP was not given a full current board or fresh-candidate verifier; do not claim current spatial gate success. Review/add only exact new test/review records, preserving every preceding row and order.

## Resume sequence

1. Read AGENTS.md, DOCS.md and this handoff; fetch main and inspect named status. Do not indiscriminately stage the preserved generated UIDs.
2. Finish the measured door-readiness repair and its before/after owner controls. Root owns the one Godot lane; status then lane.ps1 batch, never direct Godot. Rerun F06 actual zero-exclusion traversal; retain all red evidence.
3. Recheck existing lift/F01-haunt/Passage consumers and both production critter modes after final source changes. New physical endpoint guards may expose other real route requests; diagnose rather than waive. Source review notes _near_home still samples blindly; this is an unmeasured follow-up risk, not a claimed new failure.
4. Review current fixture spatial rows, copy only owned UIDs, commit the finished navigation batch, then run a new fresh committed --no-godot verifier. Use a NEW unused short work-dir: verify_candidate.py force-removes reused worktree paths. Never reuse preserved diagnostic worktrees. Keep all17 protected blobs and selector unchanged.
5. **final_native_prepared/** selects15 affected suite executions plus two imports. Update its source_ownership for the direct fixture and any routines changes; regenerate the stale spatial packet. Materializer creates SHOT_DIRs and refuses dirty/wrong-commit/existing output. Matrix env **M11C2_MATRIX_RECEIPT**; calendar **CAMPAIGN_CALENDAR_RECEIPT_PATH**. Both fresh imports must finish before suites. Inspect each stdout/stderr and verify each wrapper in the actual tree. No historical fresh55 result becomes a fresh final pass by implication.
6. Once the foundation is trustworthy and remaining debt explicit, apply **inspection_prepared/**'s reviewed16-file patch after source-hash checks. Seven Python tests passed; native WarehouseRegistration, new corrected-before five-bearing shoots, normal ArcadePropShot and WarehouseTeleport remain unrun. No production inspection repair has been applied.
7. Continue the authorized reusable Blender prop provider, whole-family waves and V2 mandate. Do not end at an isolated demo. No cutover, public release or blocked-candidate merge/push is authorized by this pause.

## External Blender preparation only

**prop_provider_prepared/PROP_VISUAL_PROVIDER_API_PREPARATION.md** and source snapshot specify existing-host named parts, catalog UV/material recipes, actual scoped MultiMesh batching and explicit SurfacePass/case/living admission. Do not import the side-effectful monolithic build_orison.py, duplicate a field, alter protected floor providers or assume original GLB bytes ship in a Godot PCK.

**prop_provider_prepared/code/** contains a strict pure-Python GLB/manifest validator and independent adversaries, frozen in **final_49.source/** with **final_49.tests.receipt.json**:49 run,48 pass,one explicit Windows symlink-creation privilege skip,zero failures/errors. Core SHA256 **2039bcb48b9c6d33baaeecbbd46b32c85c44dd91e192e971abd2e714b2e4d803**. Old false accepts for tangentW=0 and uint8 restart index255 are retained and now refused, with valid controls. No actual Blender export/model/import/determinism/runtime provider/art acceptance exists yet. An external WIP loader, prop_provider_prepared/code/prop_source_loader.py, was written before the final agent interruption at pause (22,899 bytes; SHA256 81f7bcd91f18020341a3527238152e270bd08119f5e6268ac16a90b1c9d7423f). It is untested and independently unreviewed; no loader test file or receipt exists. Preserve it as unfinished preparation and do not treat it as part of the frozen49-test validator result.

The seven-family door census, actual WaveA before frames and critique/reference review are retained externally. Actual legacy hero is.91×2.13, swing_out=true, finish2; V2 F01_DOOR_06 is a different1.10×2.13 blockout door. Preserve existing installed orientations, mechanics, household recipes and catalog-only materials. Finish whole families and installed/performance checks as requested.

Accepted critter motion remains retained. Correction from the subsequent warehouse integration: ApartmentEncroachment has accepted critters and LivingField/DreamFieldController owners but no DreamExposureField owner. Ordinary V2 RG8 ownership/storey integration remains queued; neither carried beam RGBA16F nor LivingField substitutes for it. See **design/astra/DREAM_ECOLOGY_WAREHOUSE_2026-09-19.md** for the new live sixteen-species debug exhibit, native evidence and current continuation boundary. S2J/L1D and wider acceptance remain unchanged.

Full task source: **C:/Users/nate_/.codex/attachments/70824682-0354-4e8b-8170-d647016d16bf/pasted-text.txt**. Its earlier authority attachments and mandate remain active. The original full request has already been read; do not redo completed reconciliation based on superseded prompt hashes.

**BLOCKED — paused at owner request; F06 opening-leaf collision, new fixture spatial review, and final fresh committed verification remain unfinished.**
