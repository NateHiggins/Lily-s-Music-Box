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

## 5. Later the same day

- **Copy-only snapshot of the work that exists in no ref.** Every modified
  tracked file and untracked non-.uid file in the main checkout (2,081 files,
  803 MB, on codex/dream-surface-s1 at 89ab096), the dream-voxel worktree
  (149 files, 58 MB, codex/dream-voxel-v1 at efc5d61) and the s1f worktree
  (119 files, 23 MB) was copied to
  C:/PleaseRemainOnTheLine/.claude/worktree-archive/no-ref-snapshot-2026-09-19/
  with a sha256 manifest and a patch of the tracked changes, zero mismatches.
  The source trees were not modified (the main checkout's status was
  byte-identical before and after). This is insurance, not a substitute for
  committing that work to a branch.
- **The held session worktrees carry no unique archive data.** All files
  under their own .claude/worktree-archive (34, 34 and 10) are byte-identical
  to files in the main checkout's archive. Removing them now depends only on
  whether their sessions should be archived.
- **Before shoots of every prop family** at 733c1e5: 69 specimens, 336
  frames, receipt binds, in
  C:/PleaseRemainOnTheLine-propref/art/renders/prop_review/all_2026-09-19/before
  (Wave A alone is also at .../wave_a_2026-09-19/before).
- **Evidence-class headers** added to twelve non-evidence v2 documents and to
  the session plan; the one Astra's branch also edits
  (ORISON_V2_SHARED_FRAMES_RULING) was left alone. DOCS.md gained rows for
  AGENTS.md, the pipeline tools, the ledger, the rulings index and the prop
  brief; design/next_session_plan.md gained a 2026-09-19 pickup.

## 6. How much of the reader-gate backlog is real

The reader gate (tools/audit_data_consumption.py) credits a data field only
when a production script that names the data file's res:// path also names
the field. That is deliberate: a same-named key elsewhere must not pass for a
reader. It also means a field read through a loader's returned dictionary, an
autoload's API or a record id is reported unread.

Of the 1,295 FIELD_UNREAD findings at 1c1c578:

| class | findings |
|---|---:|
| field name appears nowhere in production code | 662 |
| field name appears only in scripts other than the file's loader | 633 |

A stratified sample of 40 from the second class (three from each of the ten
largest files, ten from the rest) was traced through the actual data flow,
then every verdict was re-checked by a skeptic told to refute real reads.
No verdict was overturned.

| verdict on the 40 | count |
|---|---:|
| real runtime read the gate misses | 22 |
| the data file itself has no runtime reader | 10 |
| same name, different data: truly unread | 8 |

So roughly half of the second class, on the order of 250 to 440 findings, is
the gate's blind spot rather than dead data. The first class was not sampled;
it can contain the same blind spot where a record id is only ever read through
a variable.

The misses fall into three patterns, cheapest first:

- **Record ids treated as fields.** Keys of id maps (prop_catalog kinds,
  music_catalog residents and tracks, reality_cases ids, resident_schedules
  residents, reality_rules ids, maintenance_activities ids) are looked up
  through a variable. The gate already has a per-schema identity-map
  declaration (DYNAMIC_MAP_PATHS_BY_SCHEMA); extending it to these files
  removes the false positives without weakening the rule.
- **A dictionary handed one hop to another script.** The loader passes the
  parsed data or a sub-dictionary to a method of another class
  (building_root.gd to WallArtLaw.legal_spot and SwitchSystem.build; the dream
  profile to DreamHazardField and the room builder). Crediting reads through
  that parameter needs parameter-flow tracing, not a file-level rule, or
  unrelated same-named keys would pass too.
- **An autoload API called with a literal key** (AudioPolicy with a cue id).

The ten "no runtime reader" results name whole files: material_catalog.json
and runtime_material_sets.json are shipped mirrors of build-time inputs
(generate_runtime_materials.py reads the art/data twin and writes
game/scripts/generated/material_sets.gd), and creature_index.json,
house_english_lexicon.json, lobby_notices.json and resident_hero_models.json
had no runtime loader for the sampled field. One sampled real read,
building_layout.json wet_clearance, only relays the value into a meta that
nothing reads. Recommendation: extend the identity-map declarations first,
re-baseline, then decide whether the one-hop rule is worth building; do not
treat the current 1,308 as a count of dead data. This is TASKS.md H22.

## 7. Decisions carried out (owner delegated them, 2026-09-19)

- **The work that existed in no ref now has one.** Committed through a
  temporary index, so the source trees, their indexes and their checked-out
  branches were not touched (hashes identical before and after), and pushed:
  backup/main-checkout-wip-2026-09-19 (e06270f, on 89ab096; 13 modified and
  1,762 untracked files, Codex's .codex_tmp scratch excluded) and
  backup/dream-voxel-s2-wip-2026-09-19 (d8a57d0, on efc5d61; 8 modified and
  141 untracked). These are backups, not integrations: the owning agent
  should still commit its work properly and then the backup branches can go.
  The snapshot's first pass had skipped one non-ASCII filename (a music file);
  it was added, and the backup branches were built from NUL-separated paths.
- **codex/lamp-optical-voxel-field was pushed** to origin; it was the only
  copy of the lamp-optics line.
- **Three reports landed on main as history** with INERT headers:
  ORISON_V2_M10_RUNWAY_REPORT_2026-08-28 (closing main's two dangling
  citations), ORISON_V2_DRY_RUN_REPORT_2026-08-30 and
  ORISON_V2_DRY_RUN_SECOND_REPORT_2026-08-30. Kept, not dropped, because the
  third dry-run report on main refers to them; their figures are marked as
  dated.
- **Fourteen branches deleted** after an annotated tag
  archive/2026-09-19/<branch> was pushed for each head (restore with
  `git branch <name> archive/2026-09-19/<name>`): claude/admin-int1-interaction-contract,
  codex/integrate-admin-arch2, claude/dream12-cilia-4376ed,
  claude/ethos-authority-audit, claude/ledger-evidence-intake,
  claude/runner-exit-truth, codex/lamp-optics-l1, codex/dream-surface-s1e,
  codex/dream-surface-s1f, codex/dream-surface-s2 (and its local twin s2d),
  claude/dream-boundary-harness-fix, codex/orison-v2-dry-run-20260830 and
  codex/v2-dry-run-2. The commit main cites as evidence is also tagged
  archive/cited/d070076. Five of these existed only locally before; their
  tags now put them on origin too.
- **Eleven more worktrees removed** by the same archive-then-remove rule
  (untracked and ignored non-cache files moved to
  .claude/worktree-archive/sweep-2026-09-19/<name>/ with sha256; 78 files
  under the held worktrees' own .claude/worktree-archive were byte-identical
  to the main archive and were not duplicated). The four sessions whose
  folders they were ("ORISON-V2-M11C2 floor_01 production cut closure",
  "Room layout workbench", "Floor landing rehearsal for Orison v2",
  "Mangement") were archived; they can be restored from the Archived list.
- **Deliberately left:** the golden-shift worktree and its local branch,
  because they are the working folder of the "Developer" session, which was
  not part of the decision (its report is on main and its head is tagged);
  codex/dream-surface-s1, because the owner's main checkout has it checked
  out; codex/dream-voxel-v1 and codex/lamp-optical-voxel-field, which are
  unique, active lines; the two external dry-run artifact directories outside
  the repository.
- Worktrees: 34 at the start of the day, 7 now.

One triage agent wrote temporary status listings to its own session
scratchpad, outside the repository; no repository, ref or worktree was
changed by the triage.
