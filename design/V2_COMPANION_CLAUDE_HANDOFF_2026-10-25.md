# Claude handoff: finish and integrate work already started

Evidence class: **INERT**. Continuation instructions, not acceptance evidence.

The owner requests prioritizing committed, integrated checkpoints over new
features while Codex's usage runs low. Continue existing repairs and verification;
do not expand scope or claim V2 complete. Routine reversible work is authorized.

## Read first and protect the shared work

Read DOCS.md, AGENTS.md, applicable ORISON_BIBLE sections including VIII.5.j/k/l
and the 2026-10-25 companion amendment, art/blender/v2_batch_workflow.md,
design/V2_COMPANION_VOICE_AND_CALENDAR_2026-10-25.md and
design/V2_COMPANION_PHOSPHOR_2026-10-25.md. The latter records original failures,
rejected performance experiments, measured limits and the exact continuation.

Canonical C:/PleaseRemainOnTheLine has substantial other-contributor WIP on
codex/v2-acoustic-topology. Do not reset, switch, stage all, stash, overwrite or
commit that work indiscriminately. Inspect its current status and coordinate
ownership before integrating it. Several assets there are older than main.
The owner's newer front-door question exposed a real checkout mismatch:
canonical front_facade.glb hash began CEBEA37F; main/companion began 9EF70DC4.
Preserve the newer native leaf and main's loader, which retires the old hinge.

Owned companion checkout: **C:/ov/v2merge24**.
Branch: **codex/v2-phosphor-companion-20261025**.
Draft PR: https://github.com/NateHiggins/Lily-s-Music-Box/pull/46 .
PR 42 is already merged; PR 46 is the remaining open PR at this checkpoint.
All companion changes are committed and pushed, apart from this handoff while
being written. Main **f18d87c8** has now been merged into the branch, preserving
Tardi microscopy/guidance and the newer resident work. Reconciliation commits
are **c60f8632** and **9d0b32eb**. The former briefly committed conflict markers
after a failed resolution assertion; the latter fixes the manifest by retaining
the companion record plus all five incoming main records. Current JSON parses
and the spatial audit reports zero drift. Do not use c60f8632 alone.

## Implementation present; distinguish its evidence

- The V2 autonomous bot replaces the retired handheld path. Charcoal physical
  paper has green phosphor letters; existing printer and authoritatively owned
  radio, power, inventory, work orders, dialogue and save systems remain.
- A compact native formed case and keyboard retain the 137 mm reading pane.
  Two counterrotating coaxial helical linen screws replace the wide side rotors.
  Full manufactured envelope is 196.82 mm versus 488 mm previously. Geometry is
  63 primitives / 46,564 triangles versus 61 / 42,920: no cost improvement claim.
- Camera-relative foreground framing keeps one native rig in the same World3D,
  with bounded flight cues. Main camera excludes the device layer; the cropped
  viewport presents it. Physics controls retain their original owners. Reading
  framing improves the keyboard/paper width ratio from 1.7824 to 1.3682.
- The original gameplay flashlight now originates at the bot's native lens and
  converges on the surface under the centre reticle, independently of 2.1 m hand
  reach or a held mechanism. At most one body-only optical ray per physics tick
  while enabled; no aiming queries while off. L retains its original authority.
  A separate private photographic fill only illuminates the device render layer;
  it has no shadows, GI or volumetric fog contribution.
- The elaborate Vantry Night Stock shader is only a proposal, not implemented.

## Results already executed

All raw local artifacts are under **C:/ov/reports/v2phosphor25**. Committed
archives with manifests are under
**art/reviews/v2_companion_phosphor_20261025/framing**. Preserve original failures.
Wrapper suite_run receipts and local observations are not runtime_contract proof.

1. Pre-framing phosphor baseline at **7c442119**: occupied correspondence **88
   checks pass**, two world reconstructions, empty stderr. See
   **preframe_main20_control.log.receipt.json** and the test-written
   **preframe_main20_control/companion_correspondence_contract.json**. This does
   not qualify foreground/compact changes. Earlier original native 2,210 and
   legacy writer 51 pass; those exact historical source bindings remain intact.
2. Final compact native mechanism family: **2,230 pass**, empty stderr. Native
   form reviews inspected; round hardware seats, aerial/screw clearance and
   one-millimetre knob/bearing gap repaired. This is not played-world acceptance.
3. Latest physical hand version 7: **86 pass, one fail**, acquire does not move
   lamp. The trace contains actual mouse motion after acquisition. Earlier
   versions 5/6 have 2/8 failures. Preserve all; do not dismiss the last failure
   as external input without proving it. Input flushing corrected an earlier
   fixture defect where queued clicks arrived after moving to another control.
4. Surface lamp version 3: **21 pass**, empty stderr, screenshot inspected.
   Includes real L off/on input, no queries off, near/3.5/6 m surfaces, turned
   camera, stale hand-hit independence, native emission and per-tick reuse.
   **lamp_surface_v3.log.receipt.json**. The version-2 fixture parse failure is
   retained; it was corrected with an explicit Vector3 type. Local diagnostic.
5. Full static board on **681784e3**: all tools tests pass, reader NEW zero,
   unchanged six blocker counts **7 / 8 / 110 / 42 / 134 / 136**. Original board
   is REGRESSED solely for the lamp test's new spatial camera-station record.
   That explicit record was registered; scoped retry has zero drift. Neither
   that retry nor a dirty diagnostic board is clean candidate verification.
6. After newer-main reconciliation, **reconciled_spatial.json** reports clean,
   with zero new/failing/stale/class-change/vanished/save-unresolved records.
   Fresh imports and a local lamp replay are queued in **handoff_batch.json**;
   consult the final appended result before assuming they ran or passed.

## Blocking repairs and exact next steps

1. Reproduce and resolve the remaining physical hand acquisition-motion check
   without bypassing real input, changing gesture semantics or weakening gates.
   Diagnostic: res://tests/CompanionWorldHandBench.tscn . Current test emits
   bounded input traces and hand_failure JSON on failure. Exercise actual grab,
   mouse travel and next-click release; legacy toggles are insufficient.
2. Run res://tests/CompanionSessionBench.tscn and
   res://tests/CompanionSessionOwnershipBench.tscn . Inspect actual rendered paper,
   folding keyboard, free cursor, protected dialogue, draft retention and lamp.
3. Run res://tests/CompanionSessionWorldTest.tscn windowed with a long runner.
   Earlier foreground attempts failed the next exchange because controller A
   submitted and then PlayerController polled Interact to grab a door behind the
   UI. Current session consumes its editor-owned Interact before releasing the
   text lease; this repair has NOT passed the occupied-world regression yet.
4. Earlier occupied ABBA visibility experiments produced 44 null-material
   renderer errors before typing. Current foreground-hidden mode hides the
   viewport rather than transferring the same instrument into the main camera.
   This single-presentation-owner repair has NOT been qualified in that world.
   Run complete visible/hidden paired costs; retain real frame distributions,
   vsync/cap/settings and original failures. No global performance gain claimed.
5. Stop-on-failure batches v5/v6/v7 never launched their later preview, ownership
   or world legs. Do not promote queued tests. No current whole-console pass.
6. Capture a clean current-main baseline board, run the required full gates and
   candidate verifier against a clean integrated candidate, check protected 17
   paths and V2 selector/V1 rollback, and lint changed design docs. Resolve genuine
   regressions; preserve baseline debt explicitly. Merge coherent passing work
   to main and push. Never merge the entire draft merely because local native or
   lamp checks passed. A separately qualified phosphor-only checkpoint may be
   split from 7c442119 if appropriate, preserving newer main and pending work.

Godot exclusively through tools/lane.ps1 or approved shared-lane runners. Never
kill another contributor's process. Use -Windowed for actual mouse/render tests,
give every run -LogPath, preserve wrapper receipts and test-written contracts.
Fresh imports twice before suites. Existing **compact_batch_v7.json** supplies
the suite names/settings, but its test set predates the new lamp diagnostic.
Original regression artifacts are immutable; do not repin them to new sources.

## Broader unfinished work

The owner's larger V2 requests remain active: whole-world performance and repair
coverage, companion final framing/readability, full input/save/world regressions,
and the earlier detailed art/interaction backlog. Read the existing continuation
documents rather than assuming all older requests are done. No new feature scope
was started at this checkpoint. The canonical WIP still needs owner-aware
integration. No human acceptance or V2 completeness is claimed.

## Final handoff verification

On reconciled **9d0b32eb**, the shared-lane handoff batch completed both imports
and the windowed lamp diagnostic. All three wrapper receipts report completed
with exit zero; lamp observations contain **21 passing checks**, and lamp stderr
is empty. Receipts are **handoff_import_1.log.receipt.json**,
**handoff_import_2.log.receipt.json**, **handoff_lamp.log.receipt.json** beneath
the external report root above, also preserved in the committed handoff archive.
No console/world qualification is implied. No owned Godot process or lane waiter
remains after this batch. Generated untracked UIDs are archived externally and
removed only from the owned checkout; nine import sidecars have only line-ending
churn and are restored to their committed content. Canonical WIP is untouched.

## Other open Codex chats audited for the owner

The owner's subsequent request was to inspect other open Codex chats for relevant
unmerged work and archive those without it. The available local listing exposed
three other Codex chats. Its remote **durable** host reported unavailable; that
host was not audited. Unrelated ChatGPT conversations were not changed.

| Exact chat title | Repository evidence | Action and remaining work |
|---|---|---|
| Build tentacle gang maintenance deal | **codex/tentacle-gang-20261025**, **4facb1e5** implementation and **3a01ac1d** handoff; both absent from main | Kept open. Read **design/TENTACLE_GANG_ACCEPTANCE_FOLLOWUP_2026-10-25.md**. First-use hitch was reported reduced from 793 to 22 ms with 381 checks passing; RID verification, full surface qualification and the newer colorful goo/char/purple-smoke retreat remain pending. Integrate this work separately from the old acoustic branch's divergence. |
| Add Vorticella guide-bell trail | **codex/vorticella-guide-bells-checkpoint-20261025** is three commits ahead of **f18d87c8**: **4fd63138**, **5a83747c**, **e8874736** | Kept open. Includes palette-preserving tardigrade/Euplotes mottling, guide-bell implementation/tests and LF-stable tissue metadata. The latest chat reports one failing building stair-route test. Preserve its original failure and inspect committed tests/reports before integration. |
| Lamp | Original **10e3d0b** is unmerged historical work, superseded by main's **63f89f30**, **b9593d1f**, **710a12bb** and **120c8fc9**; all four replacements verified ancestors of main | Chat archived with the app's thread-archive tool. No branch or worktree removed. Its previous audit explicitly advises against merging the obsolete optical branch. Newer tentacle/guide-bell briefs are preserved in the respective implementation chats and repository briefs. |

At this audit the canonical checkout had advanced to **3a01ac1d** on
**codex/v2-acoustic-topology**, with substantial remaining WIP. Do not assume it
still has the earlier 7a548239 HEAD. This audit performed no repository merge,
worktree deletion or shared-WIP staging. Tardi lunch branch **f18d87c8** matches
main; the tentacle and guide-bell checkpoints do not. The companion PR remains
draft with the blockers documented above. Recheck all refs before integration.

The remote host became available on a subsequent listing. Both exposed remote
sessions were read in full and archived through the Codex thread-archive API:
**01a173a3-f785-76b8-a040-d21590b25039** produced companion PR 42, verified
MERGED as **6a0b6d66**; its remaining integration work is tracked by this chat
and PR 46. **01a173a7-5450-7224-946c-5f3e0d148028** contained advice only and
no repository implementation. Neither session had unique relevant unmerged
code. These remote sessions exposed UUIDs as their listing titles. No personal
advice transcript was copied into the repository. Total archived: three Codex
sessions, including Lamp. The two unfinished encounter chats remain open.

## Additional owner goal: reduce repository and codebase footprint

The owner explicitly added reducing file count and overall codebase size to the
ongoing V2 goals. Pursue this alongside correctness, performance and completing
existing work. Measure tracked file count, source-code bytes, asset/evidence
footprint and shipped-package size separately; fewer files alone is not proof of
less complexity or faster runtime. Prefer proven obsolete generated copies,
exact duplicates and repeated implementation that can use an existing owner.
Preserve behavior, editability, dynamic asset bindings, save/gameplay authorities,
original failure evidence and receipt-bound source hashes. Do not minify code or
combine unrelated modules merely to lower the count. No deletion is authorized
solely by an apparent unused-reference search.

Keep immediate work separate from active integration owners: begin with read-only
inventories and a reviewed cleanup list. The current read-only integration and
footprint notes are outside all checkouts at
**C:/ov/reports/integration_readonly_20261026T004311Z**. Their UTC directory date
falls on October 26; the owner's local date is still October 25. These notes do
not qualify any runtime or authorize deleting evidence. No source cleanup or
Godot execution was undertaken for this amendment.


## Owner amendment and checkout reconciliation — 2026-10-26

**Preserve the acceptance baseline.** PR #63 merged at **2fb02d84**. Start with
**design/CREATURE_MAIN_INTEGRATION_2026-10-26.md**; it records completed work,
evidence, and remaining limits. Inspect current Git state before changing anything.

**Keep the patched Vulkan engine configured.** Read
**tools/engine_patches/README.md** and verify **.godot-engine.json**. An official-engine
fallback can reintroduce the seven Texture RID leaks. Run Godot only through the
repository lane wrappers.

**Protect the installed Tardi visibility fix.** The lamp shadow camera must exclude
the separately composited device layer while retaining world occlusion. Preserve
the regression coverage for both visibility and real blockers.

**Continue from the intended creature behavior:** frantic, independent tentacle
searching and mutual contact; apparatus caressing; strong directional recoil and
sustained struggle during dissolution; flowing rainbow metallic goo, char, floor
sinking, and purple smoke. Preserve the owner's shader refinements.

**Reconcile the dirty checkout before new development.** Preserve staged assets and
outstanding edits using named-path commits. Compare against main before deciding
what is redundant. Never bulk discard or overwrite another agent's work.

**Distinguish accepted work from remaining debt.** Creature and surface qualification
passed; unrelated whole-game gates remain red. Reuse existing evidence for unchanged
code, and render affected behavior after changes. Do not call the whole game
production-ready based on these receipts.

### Reconciliation actually performed

The canonical checkout is now clean **main**, at **2fb02d84**, with its patched
engine configuration retained. The old acoustic branch was already an ancestor
of main. Its staged assets were preserved in **22b714cc**, then the explicitly
named remaining paths in **8a9be624**. The annotated recovery tag
**recovery/canonical-pre-reconcile-20261026** is pushed to origin. The obsolete
local and remote **codex/v2-acoustic-topology** branches were removed after checking
remote ancestry and tag durability. This is a recovery checkpoint, not a merge
of all historical variants over newer main.

The raw-byte backup and original index are retained outside the repository in
**C:/ov/reports/canonical_reconcile_20261026**: 1,055 files, 108,647,722 bytes,
verified individually against the backup archive. The prior audit identified
416 main-exact files, 18 LF-equivalent files, 48 nonidentical variants, and 573
main-absent files (569 generated UIDs plus two anatomy review images and two
sampler diagnostic files). No conflicting main UID was committed. Older lamp
and Tardi test variants omit the accepted visibility repair; main's versions
were deliberately retained. Unintegrated variants remain recoverable from the
tag and must not be replayed wholesale. A three-hour-old empty index lock had no
live Git owner; it was moved into the external recovery directory before commit.

PR #62 remains the separate weather-panorama candidate, based on **2fb02d84**.
Its historical matched roof profiling shows a worst callback reduction from
123.287 to 3.890 ms, not a whole-game frame-budget claim. The current test-only
input host now copies and checks 26 rendering settings; its 25.21-second rendered
probe passes with empty stderr. Current full-world qualification is still pending.
The first integrated surface survey timed out at 1,500.41 seconds with five
movement failures and no final runtime contract. The first service-station roof
run timed out at 700.17 seconds; its batch stopped before sky and reconstruction.
Original failures remain in **C:/ov/reports/weather_profile29**. No deadline,
collision authority or production rendering setting was weakened.

The owner withdrew the request to archive this chat. Continue reconciliation and
remove the weather worktree only after its live jobs finish and its outstanding
work has been merged or safely retained. Never remove unrelated worktrees.
Native-resolution fullscreen is the owner's preferred future debug mode only
where it does not interfere with their mouse/display; this preference is not yet
qualified. Existing timed comparisons retain their matched original settings.


### Reconciliation closeout — 2026-10-26, 21:15 Eastern

PR #64 merged the safe handoff update at **8e722838**. Its documentation-only
candidate **d61c8f67** passed in-place verification against the complete clean
**2fb02d84** baseline: **114 gates, zero regressions, 17/17 protected paths
unchanged**, selector V2, clean lint and no ledger promotions. No Godot run was
repeated for that unchanged runtime. The verifier is retained in the weather
recovery archive; this final paragraph is a subsequent documentation-only update.

The weather candidate was preserved, not merged. The pushed annotated tag
**recovery/weather-panorama-unqualified-20261026** resolves to
**d447b2fd709d724f1774a41182a85f54ce037650**. It retains the entire panorama cache /
mipmap patch, test-only host, original failures, measurements, current reports
and the **299-member, 20,500,193-byte** roof-review archive. All 249 previous
members were verified unchanged. PR #62 is **closed without merge**. Both local
and remote **codex/v2-weather-preview-profile-20261026** branches and the exact
**C:/ov/v2merge24** worktree were removed after checking the remote recovery tag,
clean worktree and terminal jobs. The temporary PR #64 branch is also removed.
Other contributors' worktrees were left intact. The canonical checkout remains
on main; both checkout and origin equality are checked again after this update.

Final focused results on the pinned custom Vulkan engine: roof **43 checks /
207.64 seconds**, sky **59 / 40.35 seconds**, actual saved-world reconstruction
**41 / 264.30 seconds**, all passing. Roof and reconstruction stderr are empty;
sky retains the known cam_noel_witches placement warning. The reconstruction
owns a schema-2 runtime contract for its actual two-world disk save/load and
tracked teardown, not CampaignShell, native manipulation, performance routes
or whole-game acceptance. The second full surface survey still times out at
**1,500.52 seconds** after five gallery movement failures, without a final runtime
contract. These focused passes therefore do not qualify the weather merge.
The storm captures still need visual polish. Do not call weather or V2 complete.

Both isolation monitors retain the active input desktop, but record a brief
cursor-clip change during the surface run, before the noncapturing weather batch
starts Godot. Attribution is unproven; do not claim zero observed interference.
No native-resolution fullscreen run was performed. The owner's fullscreen
preference applies only where it does not interfere, and remains unqualified.

Continuation: inspect current main and the two recovery tags before editing.
Reproduce the gallery timeout in a suitable pointer-safe rendered environment;
resolve its cause without weakening movement deadlines or collisions. Recover
only reviewed named weather changes from the weather tag, renew actual surface
qualification and rendered review, then verify a clean candidate. Never replay
the canonical recovery snapshot wholesale: it includes older variants that
would undo accepted Tardi optics, plus generated metadata intentionally kept
out of production main. Raw-byte recovery, original index and all new run logs
remain at **C:/ov/reports/canonical_reconcile_20261026** and
**C:/ov/reports/weather_profile29**. The Godot lane was free after all owned jobs
finished. This chat was not archived.
