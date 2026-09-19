# Repository housekeeping - 2026-09-19

Evidence class: **INERT - MANAGEMENT RECORD - PROMOTES NOTHING**

Interim management, on the owner's approval of 2026-09-19 ("remove yes,
merge yes, clean yes"). This records what changed on main, which worktrees
were removed and where their files went, and what a read-only triage of the
stale branches found. Nothing in the triage has been acted on: every branch
deletion below is a recommendation for the owner.

## 1. Merged to main

| commit | what |
|---|---|
| 266bbbb | pipeline tools (gate board, run receipts, candidate verifier, doc lint, lane broker, lane ledger, rulings) |
| d9daa75 | prop reference pass, 2026-09-18 brief, shed fixes, family review kit |
| d99c19e | spatial-manifest classification of the prop warehouse shot's camera aim, caught by the verifier on the merge |
| e399454 | runtime-contract ledger: first-slice blockers 0 -> 7, seven demotions (owner-approved recount) |
| 6818963 | the 2026-09-13 interim management dispatch record |
| 6b3a897 | trivia deck made strict JSON; its seven now-visible unread fields recorded in the reader baseline |

Every merge was checked with tools/verify_candidate.py in a fresh checkout
before it was pushed: protected 17/17, selector v1, Godot suites exit 0 with
binding receipts, no regressions other than the named, accepted recounts.
Ledger on main now: 7 / 8 / 84 / 52 / 107 / 109.

The trivia fix found a reader-gate limitation worth triage: darts_panel.gd
reads the card's "q" and "blurb", but the gate credits readers only in the
script that loads the data file.

## 2. Worktrees removed

Sixteen worktrees whose HEAD is on main and that had zero content changes.
Every untracked and ignored non-cache file was moved, not deleted, to
C:/PleaseRemainOnTheLine/.claude/worktree-archive/sweep-2026-09-19/<name>/
with a MANIFEST.json of sha256 values, each hashed before and after the move.
Caches (.godot, __pycache__, .ruff_cache) were not kept.

| worktree | files archived | MB |
|---|---:|---:|
| PleaseRemainOnTheLine-admin-arch3-verify | 0 | 0 |
| PleaseRemainOnTheLine-v2-landing-inspect | 0 | 0 |
| PleaseRemainOnTheLine-m11d | 0 | 0 |
| PleaseRemainOnTheLine-prereq1 | 1,483 | 1.5 |
| PleaseRemainOnTheLine-ecology-cognition | 0 | 0 |
| PleaseRemainOnTheLine-genetic1 | 0 | 0 |
| PleaseRemainOnTheLine-v2-full-rebuild | 1,487 | 3.2 |
| PleaseRemainOnTheLine-v2-m11a-first-exterior-cell | 1,487 | 3.2 |
| PleaseRemainOnTheLine-v2-m11c0-floor01-cut-rehearsal | 0 | 0 |
| PleaseRemainOnTheLine-v2-m11c1-owner-first-export | 1,487 | 3.2 |
| PleaseRemainOnTheLine-v2-m11c2-real-floor01-cut | 1,504 | 3.2 |
| PleaseRemainOnTheLine-ledger-honest | 0 | 0 |
| PleaseRemainOnTheLine-v2-m11c1-runtime-scratch | 28,306 | 6,050.8 |
| .claude/worktrees/v2-composition-census | 1,724 | 182.2 |
| PleaseRemainOnTheLine-open-shift | 1,713 | 3.2 |
| PleaseRemainOnTheLine-m10 | 1,725 | 4.4 |

Most archived files are Godot-generated .import files. The M11C1 runtime
scratch archive holds the disposable rehearsal's materialized copies; the
M10 archive holds untracked dream-surface renders.

**Held, not removed:** three worktrees are the working folders of inactive,
unarchived sessions ("ORISON-V2-M11C2 floor_01 production cut closure" and
"Room layout workbench" in room-layout-workbench-9c1f14; "Floor landing
rehearsal for Orison v2" in juno-kells-dream-profile-5c8621; "Mangement" in
sweet-swartz-dd09f3). Removing them would leave those sessions unable to
reopen in place. Each also carries a 2.5 GB copy of the 2026-08-28 sweep
archive under its own .claude/worktree-archive, which must be compared with
the main checkout's archive before anything is removed. Also kept:
C:/PleaseRemainOnTheLine-propref (it holds the git-ignored reference
photographs and full-size shed frames the prop review kit uses).

## 3. Stale-branch triage (read-only; one analyst and one skeptic per group)

Verdicts after the skeptic's check. "Superseded" means the substance is on
main; "contained" means another kept branch holds every commit.

| branch | verdict | recommended action |
|---|---|---|
| claude/admin-int1-interaction-contract | superseded (main 7cc3b5f) | delete local and remote |
| codex/integrate-admin-arch2 | superseded (main b8bf0fe) | remove its clean worktree, delete branch |
| claude/dream12-cilia-4376ed | superseded (main 90377f0) | delete local and remote |
| claude/ethos-authority-audit | superseded (main 51a0619) | delete local and remote |
| claude/ledger-evidence-intake | superseded (main d344fd9) | delete local and remote |
| claude/runner-exit-truth | superseded | remove worktree (only .uid churn), delete local and remote |
| claude/dream-boundary-harness-fix | code superseded (main b813b1a) | **owner:** main's design/ORISON_GENETIC_MEMORY_2026-08-29.md cites commit d070076 itself as evidence; tag it or keep the remote before deleting, or the citation dies |
| codex/lamp-optics-l1 | contained in codex/lamp-optical-voxel-field | remove its clean worktree, delete branch |
| codex/lamp-optical-voxel-field | unique, active | keep; it has no remote backup, so push it |
| codex/dream-surface-s1e | contained (patch-identical in s1f and voxel-v1) | delete local and remote, remove worktree |
| codex/dream-surface-s1f | contained (ancestor of voxel-v1) | delete local and remote; five untracked render-probe folders in its worktree need archiving first |
| codex/dream-surface-s2 (+ s2d) | contained in codex/dream-voxel-v1 | delete |
| codex/dream-voxel-v1 | unique, human-accepted, awaiting integration | keep; **owner:** its worktree C:/PleaseRemainOnTheLine-s2 has 8 modified source files and 31 untracked S2D-S2J/C1 paths that exist in no ref |
| codex/dream-surface-s1 | contained | **owner:** it is checked out in the main checkout, which holds uncommitted work that exists in no ref (below) |
| claude/golden-shift-v2-verify-c72c73 | unique report | land its one additive, inert report (282db60) to close two dangling citations on main, then remove |
| codex/orison-v2-dry-run-20260830 | owner decision | keep the dated re-measurement as history or call it stale; then remove |
| codex/v2-dry-run-2 | owner decision | keep the unexplained v1 atrium object-count drop as a perf lead or drop it; then remove |

## 4. Risks the owner should know about

- **The main checkout holds work that exists in no ref.** C:/PleaseRemainOnTheLine
  is on codex/dream-surface-s1 with 13 modified tracked files (including
  art/data/building_layout.json, art/data/gen_layout.py, floor_03 glTF/BIN
  and art/blender/orison_master.blend) and about 280 untracked paths. Among
  them are design/ORISON_F03_OMAR_APARTMENT_CHECKPOINT_2026-08-28.md with its
  evidence and decisions JSON, the F03 Omar and dream-trunk shot suites,
  game/data/dream_maze_layout.json, art/blender/dream_tentacle.blend, five
  music files, a brochure image and about 230 renders. A disk failure or a
  careless clean loses them. Nobody but the owner should touch that tree;
  committing it to a branch is the fix.
- **The dream-voxel line's newest work is uncommitted** in C:/PleaseRemainOnTheLine-s2.
- **codex/lamp-optical-voxel-field is local only.**

One triage agent wrote temporary status listings to its own session
scratchpad, outside the repository; no repository, ref or worktree was
changed by the triage.
