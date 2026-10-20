# Workspace consolidation and recovery

Evidence class: **INERT**. Housekeeping report; no V2 acceptance or ledger change.

The owner's cleanup request retires four redundant Git worktrees. The sole
registered checkout is **C:/PleaseRemainOnTheLine**, on
**codex/v2-acoustic-topology**. Its build source remains **6472266b**; subsequent
publication changes only this report, its map entry and cleanup records.

| Retired checkout | Retained head | Recovery ref suffix |
|---|---|---|
| **C:/ov/envimpl** | **3e957e1d** | **envimpl** |
| **.claude/worktrees/godot-dev-reference-manual-911b93** | **9a83ac02** | **godot-dev-reference-manual-911b93** |
| **.claude/worktrees/interesting-booth-8088c2** | **cd2eb936** | **interesting-booth-8088c2** |
| **.claude/worktrees/orison-v2-environment-design-778e17** | **3e957e1d** | **orison-v2-environment-design-778e17** |

All four heads are pinned under **refs/archive/workspace-cleanup-20261020/**.
Original branches remain. The two unique unmerged heads also have a verified
Git bundle; they were preserved, not silently merged or discarded. The old
reference/app branch has nine commits outside main; the environment head has
two, including the Otis work and a Bible ruling requiring later integration
review. The detached environment checkout duplicates that retained head.

Recovery files live at **C:/ov/workspace-archive-20261020/**. Each checkout has
**local-files.zip** and a per-file SHA-256 manifest. All 1,393 untracked and
non-cache ignored files are preserved, including temporary work, captures and
compiled app outputs. The archives total approximately 1.01 GB. Committed files
remain in the shared Git database and their recovery refs. Only regenerable
Godot and Python bytecode caches were excluded from ZIP preservation.

Git unregistered the reference/app checkout but left part of its directory.
A second verification matched 9,933 remaining files to the retained Git blobs
or earlier archive and preserved 3,653 further raw variants in a verified ZIP.
Automatic approval review then blocked recursive deletion, without a more
specific reason. The safer alternative moved the remaining directory intact to
**godot-dev-reference-manual-911b93/remaining-checkout** inside the archive.
It is no longer a registered or active workspace. No application was stopped.

The retired checkouts contained approximately 57.5 GB of logical file data.
That is not a measured disk-free increase: archives and the approximately
3.43 GB intact orphan remain. Native toolchains, prior recovery archives,
clean baseline boards and the canonical checkout's import cache are retained.

Restore a checkout using its full recovery ref with **git worktree add --detach**
at a short path, then extract the corresponding ZIP into that checkout. The
archive's **README.txt**, **inventory.json**, **completed.json**, and per-checkout
manifests describe the original paths and hashes. The orphan's separate ZIP and
verification retain every additional remaining variant.

Verification: Git lists exactly one worktree; all four retired source paths are
absent; every recovery ref resolves to its recorded head; all local ZIP hashes
match; **git bundle verify** passes. The canonical tracked source was clean
before this report. No runtime test was repeated for housekeeping-only changes.
Original applications and unrelated untracked canonical files remain.

REPORT - WORKSPACE-CLEANUP - 2026-10-20

Branch / source HEAD / origin/main / merge-base: **codex/v2-acoustic-topology** /
**6472266b** / **69235f4f** / **69235f4f**. Publication is report-only.
Worktree clean at end: tracked files clean after commit; unrelated untracked
artifacts and generated UIDs remain. Protected source and selector unchanged.
Ledger statuses and existing proof-expiry findings are unchanged. No new Godot
run, runtime acceptance or human appearance/listening acceptance is claimed.
Review record: **art/reviews/workspace_cleanup_20261020/cleanup.json**.
Decision needed from owner: **none**. Continue the V2 build in the sole checkout.

BLOCKED FROM MAIN INTEGRATION: broader acoustic branch qualification remains; housekeeping is complete.
