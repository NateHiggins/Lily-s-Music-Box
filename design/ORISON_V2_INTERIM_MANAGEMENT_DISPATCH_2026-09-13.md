# Orison v2 interim management dispatch — 2026-09-13

Evidence class: **DISPATCH RECORD — INERT — PROMOTES NOTHING**

Written by interim management after evaluating every v2 branch and worktree
against **origin/main** at **c2dc017** (2026-08-30). Identifiers are bold,
never backticked, so this file cannot promote a ledger row. Verified with
the evidence-impact command before commit.

## 1. Where the rebuild actually is

**main** has not moved since 2026-08-30. All eleven dry-run prerequisites
are cleared there (ADMIN-PREREQ-1 at **5c1a96a**, recursive reader scan at
**c2dc017**). Gates re-run today on main: completeness exit 2 with scopes
0 / 1 / 86 / 45 / 101 / 103; spatial 0 clean; systemic 0; period 0; reader
exit 1 (intentionally red, 1,290 unread fields, 11 unread files); the four
tool suites pass.

Everything since then lives on one linear Codex chain, 24 commits ahead of
main, merge base **c2dc017**, no conflicts possible because main is the
base:

| Step | Branch | Result | Human |
|---|---|---|---|
| Third dry run | codex/orison-v2-full-rebuild (**3855fa5**) | PASS — AUTHORIZE FIRST BOUNDED LANDING | accepted |
| M11A first exterior cell | codex/orison-v2-m11a-first-exterior-cell (**0429c07**) | 35/35 objective, 4/4 capture; bodega bucket, resolver, seams | accepted (M11A-A receipt) |
| M11B F02/F04 service openings | codex/orison-v2-m11b-service-openings (**a9e455b**) | data-driven openings, detector narrowed; exposes F03 hall debt | accepted |
| M11C0 cut rehearsal | codex/orison-v2-m11c0-floor01-cut-rehearsal (**edc18ff**) | REFUSED production cut: 134 lineage-unresolved primitives | n/a |
| M11C1 owner-first export | codex/orison-v2-m11c1-owner-first-export (**503465d**) | 5,286/5,286 sourced, 17 cells, 5 seams PASS — AUTHORIZE REAL CUT | n/a |
| M11C2 real cut | codex/orison-v2-m11c2-real-floor01-cut (**46d40e9**, no remote) | assets committed; consumer redirect UNCOMMITTED; receipts PASS; checkpoint PENDING | pending |

Two earlier dry-run receipts sit on unpushed single-commit branches
(codex/orison-v2-dry-run-20260830, codex/v2-dry-run-2). They are history,
superseded by the third run; land them or archive them, they block nothing.

Unrelated Codex lanes (dream surface, lamp optics, astra) share the main
checkout, which is dirty with their work. Not touched, not evaluated here.

## 2. Findings on the in-flight M11C2

The M11C2 worktree has been dirty and untouched since **2026-08-31 11:52**,
thirteen days. The work is substantively done and was never closed:

- Frozen receipts all say PASS: production matrix 26/26 checks, 0 failures;
  matched legacy/cell capture PASS; route PASS. The draft checkpoint still
  reads PENDING in every table.
- Uncommitted: BuildingRoot geometry-free F01 host and registry redirect
  (+194 lines), SurfacePass weak-user release (+116), CampaignShell public
  world teardown (+98), the registry and configuration scripts, four Godot
  test scenes, the capture merger, the harness-contract suite, the packet.
- Python gates in that tree today match main (2 / 0 / 0 / 0 / 1). Every
  tools test passes except the prompt-carrier suite: **legacy_uncovered 1**,
  a new legacy "[E]" carrier at maintenance_shop_counter.gd:29 introduced by
  the M11A commit. It passes on main. This is a T2 contract violation riding
  inside an already human-accepted commit.
- The matrix receipt shows cells minus legacy **ready_and_settle_ms
  +344.1** with load and instantiate equal. The registry hashes the asset
  manifest, the 15.7 MB lineage, the alias manifest and all 34 cell files,
  then parses the full lineage JSON, at every boot. Production boot is
  already 27.7–33.2 s against a 24 s ceiling.
- Lifecycle final delta from warmed: objects +101, resources +7, flagged
  "observational". The draft requires zero retained owners. The two
  statements must be reconciled, not averaged.
- Push weight: 86.6 MB uncompressed, of which two different 15.7 MB
  lineage blobs and an 8.1 MB generated lineage. Not LFS. The remote has
  refused large pushes before.
- Godot rewrote 25+ texture .import files in that tree (line endings) and
  minted 7 .uid files; neither may be committed as-is.

Cell asset hashes in the committed manifest verify against the committed
files. Registry: 17 cells, default mode owner_first_cells, rollback mode
legacy_monolith injected only for tests. Selector v1 everywhere.

## 3. Findings on main that the chain did not touch

- The Sept-3 "hour one, zero geometry" item was never done. **unit.2B.entry**
  and **f01.watch_station** are PROGRAMMED on built, walked, owner-accepted
  spaces; no admitted checkpoint backticks their ids. Two of the 86
  structural blockers, no geometry. **Correction (later the same day):**
  the stale **B1_PUBLIC_LANDING_E** claim is NOT gone; management misread
  the M10 queue line as the stale row. The M08E spatial-owners checkpoint
  still backticks an id that exists only in the layout's platforms array,
  which the audit's identity universe does not read. Clearing it is a tool
  change, not a checkpoint change.
- The period audit is in no standard battery; the dry-run plan and the
  handoff list five gates and omit it. It was silently red for a day.
- The reader gate remains a report, not a gate: 1,302 blocking, zero
  exceptions, wired to nothing. Triage before baseline stands.
- Wave 2 of the simulation programme (the unread with / route / outfit
  fields in resident_schedules.json: 415 / 26 / 10 values) is still the
  highest aliveness-per-line item and needs no geometry. Claude lane.
- Beat 4 of the golden shift has a fiction/catalog conflict: TASKS.md says
  buy the part at the bodega; the maintenance catalog places the capsule at
  hardware_paint; M11A's bodega counter therefore answers NO OPEN ORDER.
  Owner decision, recorded below.

## 4. Rulings made by interim management (owner may override)

1. **Runtime may hash-bind lineage; it may not parse it at boot.** No
   production reader consumes a lineage field. Move the production lineage
   beside the M11C1 ownership sidecar under art/data, keep its SHA-256 in
   the asset manifest.
2. **No new legacy "[E]" carriers, including inside accepted commits.** Fix
   before merge; the baseline is frozen at 186.
3. **The prompt-carrier suite and the period audit join the standard
   battery** listed in every checkpoint from now on.
4. **A dirty tree is not a state a task may end in.** Close, or report
   BLOCKED with the tree committed to its branch.

## 5. Dispatch queue (serial; each reports before the next starts)

| # | Task | Gate to start | Deliverable |
|---|---|---|---|
| 1 | ORISON-V2-M11C2-CLOSE | now | closed checkpoint, pushed branch, MERGE-CANDIDATE sha or BLOCKED |
| 2 | ORISON-V2-M11D-ZERO-GEOMETRY | after 1 reports | checkpoint backticking the vestibule and watch ids; 86 to 84 |
| 3 | ORISON-V2-M12A-STREET-THRESHOLD | after owner merges the chain | apron, vestibule, lobby cell on +z; human packet |
| 4 | ORISON-V2-M12B-F03-SERVICE-HALL | after 3 reports | F03 lateral service hall as data; riser choke resolved or re-scoped |

Held in the Claude lane, not dispatched to the developer: reader-gate
triage; Wave 2 schedule readers; the streaming manager now that independent
addressability exists; battery documentation fix.

## 6. Decisions the owner must make

1. Merge the M11 chain to main once task 1 reports MERGE-CANDIDATE.
   Recommendation: yes, one merge, after the carrier fix.
2. Answer the M11C2 packet's human question (matched seams and route).
3. Which shop stocks the beat-4 part: bodega (fiction) or hardware_paint
   (catalog). K2 stays deferred until answered.
4. Whether light_provenance prose reaches a player surface (standing).
5. Confirm or override ruling 1 on lineage placement.

## 8. Review of the M11C2-CLOSE report (2026-09-13, later the same day)

The developer reported MERGE-CANDIDATE **6d918a7** (pushed, 27 ahead of
main, merge base c2dc017, three close commits 3ef15f5 / dbdb762 / 6d918a7).
Management re-verified rather than accepted:

- Confirmed: remote equals HEAD; worktree clean; checkpoint holds zero
  backticks and evidence-impact reports it inert; Python gates on the
  commit are 2 / 0 / 0 / 1 / 0 with the six counts unchanged; reader at
  1,302 blocking; carrier fixed at maintenance_shop_counter.gd:29; the
  lineage now lives under art/data/m11c2, is hash-bound and never parsed;
  the .gitattributes scope protects the cell files (a fresh checkout hashes
  shop_bar.gltf identically).
- Confirmed by reproduction: GoldenLoopTest 87/87 with the same two failing
  checks in the developer's tree at 6d918a7 **and on main at c2dc017** after
  a proper re-import ("restored objective presents the authored title",
  "the objective now directs the player to Mina, not another part"). This
  is a main defect nobody saw because the suite is in no battery. Not
  attributable to the chain.
- Instrument note: management's first main run died on a fake "Nonexistent
  function minute_now" from a stale worktree class cache dated Aug 28. The
  toolchain trap, not the code.
- **One blocking gap, understated in the report as open finding 3.** In a
  fresh `git worktree add` of 6d918a7 the committed suite
  test_m11c2_floor01_production_export.py fails: the asset manifest's
  authoritative_inputs hashes were computed from the developer's working
  copies of build_orison.py and generate_owner_first_candidate.py, which
  carry mixed line endings (a few LF lines inside CRLF files). A fresh
  checkout of the same commit yields all-CRLF files and different hashes.
  The exporter's check mode rebuilds the manifest from the current tree, so
  it fails on the same fresh clone. Same platform, not cross-platform. The
  owner's merge tree would fail this suite. Required before merge: hash
  authoritative inputs as Git-normalized content, regenerate the manifest,
  and prove the suite and the registry boot in a fresh worktree of the
  commit, not the working tree.

Verdict: MERGE-CANDIDATE stands subject to that one correction and a
re-report. M11D may start in parallel; it needs no Godot.

## 9. Review of the correction re-report and of M11D (2026-09-13, evening)

**M11C2 at 89df0e0** (29 ahead of main). Management re-verified in a fresh
`git worktree add` of the correction commit 798292c: the export suite
passes 11/11; all 17 protected files hash identical to the prewrite
baseline; .gitattributes is unchanged and no shared .py source received an
attribute; tools/run_godot_long_suite.ps1 is committed. The fresh-worktree
Godot registry boot was NOT reproduced by management: the machine's Godot
lane was held by another project's test run (jawbreaker) across two
attempts and an eight-minute wait. The developer's logged fresh-worktree
run (import twice, registry PASS, lineage_parsed false, configure 116.9 ms)
is accepted on the strength of the Python reproduction and the unchanged
runtime files. Former open finding 3 is closed. Verdict: MERGE-CANDIDATE
**89df0e0** stands.

**M11D at be81264** (one commit, one file, based on main). Management
copied the checkpoint into a main worktree: evidence-impact admits it and
changes exactly two rows (**f01.watch_station** and **unit.2B.entry**,
PROGRAMMED to SPATIALLY_PROVEN); the six scopes move 0/1/86/45/101/103 to
0/1/84/45/100/102 with the document present and return with it absent.
Exactly two backticked ids. Verdict: MERGE-CANDIDATE **be81264** stands. It
merges independently of the chain.

Standing corrections to this record: the stale identifier on main is
**B1_PUBLIC_LANDING_E** (see the correction in section 3); management's
earlier claim that it was gone was wrong, and the developer caught it.

Next dispatch while the owner decides on the merges: ORISON-V2-M11E-HYGIENE,
two tool-lane items on main that need no owner decision and no geometry:
teach the completeness identity universe to read the layout's platforms
array so the stale B1 row resolves honestly, and repair
ServiceWireResponseTest, which reads a property main removed on
2026-08-27 and then hangs to a 124. GoldenLoopTest's two failing checks
stay parked on the owner's beat-4 decision.

## 7. Report format required from the developer

    REPORT - <task id> - <date>
    Branch / HEAD / origin/main / merge-base:
    Worktree clean at end: yes|no (list anything left)
    Protected 17/17: yes|no      Selector: v1
    Ledger before -> after: <six counts> -> <six counts>; requirements_changed: [...]
    Gates (real exit codes, -LogPath): completeness / spatial / systemic /
      period / reader / each tools test / each Godot suite with its PASS line
    Numbers management asked for:
    Changes outside the expected file boundary, and why:
    Open findings not fixed:
    Decision needed from owner:
    Last line: MERGE-CANDIDATE <sha> | BLOCKED <reason> | NEEDS-OWNER <question>
