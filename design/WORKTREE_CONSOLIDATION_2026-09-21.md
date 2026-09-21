# Worktree consolidation — 2026-09-21

Evidence class: **INERT**

## Result and authority

The owner requested one shared development line before making V2 the playable
default, and confirmed Godot was closed and game agents paused. All 18 registered
checkouts were inventoried. Seventeen secondary checkouts were removed only after
their local files were backed up and verified. The one remaining checkout is
**C:/PleaseRemainOnTheLine**, on **main**, advanced to **647923f3d0bf51cd5cbe104234e5a53366f6f477**.
Branches were retained; no unique feature branch was blindly merged or deleted.
Windows initially held the two retired Claude directories open. If those empty
shells remain under .claude/worktrees, they contain no files and are not registered
worktrees; the old Claude sessions must be reopened in the canonical checkout.

This is repository housekeeping, not runtime acceptance or a V2 default cutover.
No gameplay, generated asset, or protected spatial authority changed in this step.

## Recovery

The local archive is **C:/ov/worktree-rescue-20260921**. Its main and supplemental manifests record
140,449 verified file records totaling 40,098,604,676 source bytes (before deduplication).
Every saved file was SHA-256 checked. Exact committed bytes may reference retained
Git blobs instead of duplicate files. Preservation tags use
**archive/consolidation-20260921/**, with one tag per old checkout and a main tag.
Original Git status and per-tree manifests are retained. Source status, size and
modification time were checked again before each removal.
Git hit a Windows long-path limit during removal of the old Astra checkout.
Its remaining files were independently checked; supplemental manifests preserve
overlong files omitted by Git's original inventory. A physical file census was
added to the remaining preflights. Recovery includes these supplemental records.

The archive's README.md and restore_files.py explain extraction into a new empty
folder. They never overwrite the current project. The archive is local only and
contains reference imagery and ignored files that must not enter Git. Rebuildable
.godot, Python/test and node_modules caches were excluded. Existing ignored files
in the primary checkout, including its Godot executable, remain in place.

## Usable versus superseded

| Former checkout | Saved HEAD | Disposition |
|---|---|---|
| C:/PleaseRemainOnTheLine | 89ab096f | Retained as the canonical checkout; stale surface commits are patch-equivalent to main. Local art/source edits archived. |
| C:/ov/astra-main-acdb4be | 1af772e6 | Useful unmerged resident-door checkpoint 1af772e; retain branch. Physical crossing still fails; not merge-ready. |
| C:/ov/astra-r1-main | acdb4be4 | Committed work already on main; any local extras archived. Retired. |
| C:/ov/astra-r1-runtime-55e99dc | 55e99dc4 | Diagnostic source edits archived. Old runtime verification checkout retired. |
| C:/ov/astra-r1-verifier/b-acdb4be4 | acdb4be4 | Committed work already on main; any local extras archived. Retired. |
| C:/ov/astra-r1-verifier/c-9b937ac3 | 9b937ac3 | Committed work already on main; any local extras archived. Retired. |
| C:/ov/c-147f9b10 | 147f9b10 | Aborted, locked initialization; physical files preserved and committed base tagged. Retired. |
| C:/ov/c-65b5ebf1 | 65b5ebf1 | Committed work already on main; any local extras archived. Retired. |
| C:/ov/c-d5a35763 | d5a35763 | Committed work already on main; any local extras archived. Retired. |
| C:/ov/critter-v3-int | 5983a800 | Committed work already on main; any local extras archived. Retired. |
| C:/ov/pause | 647923f3 | Committed work already on main; any local extras archived. Retired. |
| C:/ov/reconcile-dev | 72d7740f | Useful developer follow-up 72d7740; reconcile selectively because its TASKS IDs collide with current main. |
| C:/PleaseRemainOnTheLine/.claude/worktrees/golden-shift-v2-verify-c72c73 | 282db60c | Golden-shift change is patch-equivalent to main; retired. |
| C:/PleaseRemainOnTheLine/.claude/worktrees/orison-spatial-deps-8441ac | cd2eb936 | Committed work already on main; any local extras archived. Retired. |
| C:/PleaseRemainOnTheLine-astra | 4e3e1077 | Old accepted work is on main; two local modifications and evidence archived. Retired. |
| C:/PleaseRemainOnTheLine-optical-field | 4aa45850 | Optical-light branch retained: six unique patches plus two patch-equivalent commits. Requires deliberate integration and validation. |
| C:/PleaseRemainOnTheLine-propref | 733c1e5f | Reference imagery preserved locally, not committed. Reference checkout retired. |
| C:/PleaseRemainOnTheLine-s2 | efc5d61f | Accepted voxel base is on main; local Dream source/shader/test edits and deleted gitlink recorded. Retired. |

The resident-door checkpoint remains outside main because its real service-door
crossing still collides despite passing focused tests. The optical-light branch
and local S2 edits need source reconciliation against the accepted main ecology;
retaining them is not an assertion that they are production-ready. The old critter
integration and review checkouts add no missing committed feature to main.

## Next V2 work

The owner has authorized V2 as the default. At this consolidation checkpoint the
selector still defaults to V1. V2 composes production gameplay services but lacks
the BuildingDebug/warehouse composition expected by the ZooVisit launcher. Carry
the supported debug controls and zoo into V2, validate actual title launch and
walkable routes, then change the default and its current-contract checks together.
Historical evidence must remain historical. Keep explicit V1 rollback available.

All game agents should resume from the canonical checkout and current main.
Temporary isolated verification checkouts should be removed after their run;
the retired paths are not active development locations.
