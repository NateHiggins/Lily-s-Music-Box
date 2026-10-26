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
