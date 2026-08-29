# Orison v2 floor-landing rehearsal checkpoint — 2026-08-29

Status: **MACHINERY PROOF PASS — READY WITH FOUR NAMED CAVEATS**

Task: DEV-REHEARSE-1. Base: `origin/main` at `3aa3764` ("Tell the spatial
owner that naming decides what proves anything"), clean tree.

This checkpoint proves **our tools**, not a building. No real geometry was
built. Every experiment ran against scratch copies of the v2 layout passed
through `--v2-layout` and temporary fixture paths;
`game/data/orison_v2_blockout.json`, the real scenes, the schema, the
production scripts, the committed checkpoints and evidence packets,
`BuildingRootSelector` and the ethos baseline were never modified.

**Identifiers below are deliberately bold, never backticked.** This file
carries the `CHECKPOINT` marker, so the completeness ledger admits it as
evidence; backticking a synthetic F05 id here would file it as stale
evidence against the real ledger, and backticking a real id would promote
it. `--evidence-impact` on this file exits 0 and adds no stale rows — that
was verified before it was committed, and is itself part of the rehearsal.

## What was rehearsed

A synthetic **F05** at 12.8 m: two apartments (**5A** west, **5B** east)
with the six domestic minimums each, a programmed landing, the passenger
core, a service core, the service spine, three leaves, fourteen cased
openings, two radiator anchors, four platforms, two lift landings and the
two F04→F05 U-stairs. Ten variants were generated from it — one correct
and nine each carrying exactly one deliberate fault — and run through the
completeness ledger, the spatial dependency audit and
`orison_v2_blockout.gd`.

Baseline at `3aa3764`, for every delta below: completeness exit **2**
(FIRST_SLICE_TECHNICAL 0 · GOLDEN_SHIFT_V2 1 · FULL_BUILDING_STRUCTURAL
**80** · FULL_BUILDING_RUNTIME 45 · PRODUCTION_CUTOVER 95 · V1_RETIREMENT
97); spatial dependency audit exit **0**, clean; systemic-situation
authority exit **0**.

## Probe results

| # | Probe | What the machinery reported | Right? |
|---|---|---|---|
| 1 | A correctly built floor | Exactly seven requirements moved ABSENT → PROGRAMMED — **floor.F05**, the four **circ.F05.\*** rows, **unit.5A**, **unit.5B** — and nothing on any other floor moved. Twelve *new* requirements appeared (the two units' six minimums each). | **Yes** |
| 1b | Structural blocker count | FULL_BUILDING_STRUCTURAL went **80 → 92 (+12)**. Building a correct floor *raises* the count, because the twelve new minimums are PROGRAMMED and require SPATIALLY_PROVEN. | **Yes, and counter-intuitive** — see caveat C1 |
| 2 | Refusal until a properly-named checkpoint backticks the ids | A `..._M11_F05_FLOOR_REPORT_2026-08-29.md` backticking all 23 ids: *"NOT evidence (report prose, not a milestone record) — changes no requirement status"*, exit **0**. A `..._M11_F05_GRAYBOX_CHECKPOINT_...md` with identical content: *"admitted as evidence (marker CHECKPOINT, epoch 2) — CHANGES 18 requirement(s)"*, exit **1**, listing each PROGRAMMED → SPATIALLY_PROVEN move before anything was committed. A properly-named checkpoint whose prose claims the floor is complete but backticks *no* ids: admitted, **0** changes, exit 0. | **Yes** |
| 2b | Credit when the checkpoint lands | Committing the checkpoint moved all 18 and took FULL_BUILDING_STRUCTURAL **92 → 74** and FULL_BUILDING_RUNTIME **45 → 43**. Net effect of one correct, checkpointed floor: **80 → 74 structural**. | **Yes** |
| 3 | A room with no door or opening | Deleting the only opening into **F05_A_BATH**: the bath reported SHELL_ONLY (*"no door or cased opening connects it"*), **unit.5A.sanitary** SPATIALLY_PROVEN → SHELL_ONLY, **unit.5A** → SHELL_ONLY, **floor.F05** → SHELL_ONLY, +3 structural blockers. The checkpoint still backticked the bath and **did not rescue it** — geometry beats prose. | **Yes** |
| 4 | An apartment missing its minimums | Deleting 5B's kitchen, bath and bedroom: **unit.5B.cooking**, **unit.5B.sanitary** and **unit.5B.sleep** each reported ABSENT with *"No &lt;function&gt; purpose among this unit's v2 spaces"*, citing the program row — by purpose text, never by id token. The stale-evidence detector separately named the three backticked ids that had vanished. | **Yes**, with caveats C2 and C3 |
| 5 | An anchor outside every room | **F05_ORPHAN_BENCH_01** at (30, 0.9, 30) reported in `anchor_only` as *"anchor with no containing programmed space"* and counted in the summary. It was **counted but never named** in the default or markdown output — fixed here (T1). It creates no blocking requirement; it is advisory. | **Yes after T1**, with caveat C4 |
| 6a | Duplicate id | `orison_v2_blockout.gd` refuses: *"invalid or duplicate id: F05_A_MAIN"*, pushes the error, returns before `_build_palette`, builds nothing. | **Yes** |
| 6b | Id referencing a level that does not exist | Refuses: *"F05_B_BED references missing level F07"*, builds nothing. | **Yes** |
| 6c | Overlapping rooms | **Not refused.** Widening **F05_B_MAIN** to swallow **F05_B_PRIVATE_HALL** validates clean and builds both rooms' slabs, ceilings and walls interpenetrating. `_validate_layout` has no overlap rule; the only overlap checks in the repo are the two hardcoded ones in `game/tests/orison_v2_blockout_test.gd`, scoped to F04 and to `["B1", "F02"]`. | **No** — defect D1 |
| 6d | Door connecting a space that does not exist | **Not refused.** A leaf whose `connects` names a non-existent space validates clean and builds; the wall it should have pierced is built solid, so the door is a frame against a blank wall. | **No** — defect D2 |
| 6e | Stair naming a level that does not exist | **Not refused by validation** — the stair record carries `from`/`to`, not `level`, so the level check never sees it. A bad `to` is never read at all and builds silently. A bad `from` throws *"Invalid access to property or key 'F07'"* on stderr inside `_build_u_stair`, which aborts that one call and continues: the scene finishes, prints `ORISON V2 BLOCKOUT: 68 spaces / 24 doors / 51 anchors`, joins the selector group, **exits 0**, and quietly has no stair. | **No** — defect D2 |
| 7a | New semantic ids, spatial dependency audit | Exit **1**. Eleven **NEW unclassified (FAIL)** records for the F05 ids that also exist in the v1 universe, plus **54 classification changes** across 30 files nobody touched. | **Yes, but mislabelled** — fixed here (T2) |
| 7b | Genuinely new v2-only ids | **F05_LANDING**, **F05_PUBLIC_CORE**, **F05_A_VESTIBULE**, **F05_SERVICE_HALL** and the rest are **invisible** to the audit while they live only in the blockout — that file is a universe authority, and its own defining ids are definitions, not dependencies. Adding two to `OrisonV2AnchorAdapter.REQUIRED` made them appear immediately as production records: RUNTIME_LOOKUP / SEMANTIC_ANCHOR / MUST_PRESERVE_ID / HIGH. | **Yes, and deliberate** — see caveat C5 |
| 7c | Deliberate `--update-manifest` | +13 records, 0 removed. Layout ids classified PRESERVE_OR_ALIAS, adapter-contract ids MUST_PRESERVE_ID. Re-run exits **0**, clean. | **Yes** |
| 8 | Construction in Godot | The correct F05 layout builds through `orison_v2_blockout.gd` with an empty `failures` array, 301 top-level children, and the `orison_v2_blockout` group joined. Every F05 space, leaf (with hinge and latch), radiator anchor, the F04→F05 primary stair and the passenger lift landing resolve by name; a west wall segment sits on the declared 12.8 m storey; the two declared core voids correctly carry no slab. All six review scenes — blockout, F01, F02, F04, integrated and M08E spatial — load and instantiate. 64 checks, 0 failures, exit **0**. | **Yes** |
| 8b | The committed suite, unchanged | `res://tests/OrisonV2BlockoutTest.tscn` prints `ORISON V2 BLOCKOUT TEST: PASS` and exits **0** against the real layout, before and after this work. | **Yes** |

## The 54 "authority-class changes" are not what they said they were

Every one of the 54 was a `resolved_target` re-resolution — `floor` →
`floor+v2_blockout`, `F05/room` → `F05/room+v2_blockout` — with the
authority class **identical** before and after. They fired because the
blockout is a second universe authority, so declaring F05 rooms there
changes how *pre-existing* references in `game/data/acoustic_graph.json`,
`game/data/fixture_light_map.json`, `game/data/light_provenance.json`, six
production scripts and fifteen tests resolve. The drift report printed all
of them under the single label *"authority-class changes (FAIL)"*, which
reads as an authority regression on files the floor owner never opened.
The label is corrected in T2.

## Defects and caveats

**D1 — Overlapping rooms build silently. BROKEN.**
`_validate_layout` checks rect *validity* (four numbers, x0&lt;x2, y0&lt;y2)
but never rect *disjointness*. A floor whose rooms overlap validates, builds
and looks plausible in a review scene. The two existing overlap assertions
are hardcoded to F04 and to `["B1", "F02"]` in
`game/tests/orison_v2_blockout_test.gd`, so a new floor gets no check at
all. **Fix:** generalise `_all_rooms_non_overlapping` to every level in the
layout. **Owner:** the spatial-construction owner (ChatGPT) — the fix is in
`game/tests/`, which is the schema/test lane, not ours. Not fixed here.

**D2 — Referential integrity is unchecked, and it fails silently. BROKEN.**
Nothing verifies that a door's or opening's `connects` names real spaces,
that a window's `space` exists, that a lift landing's `shaft` names a real
riser, or that a stair's `from`/`to` name real levels. Measured: a leaf
pointing at a non-existent space builds as a frame against the solid wall
it should have pierced; a stair whose `from` names a missing level throws
inside `_build_u_stair`, and because a GDScript runtime error aborts only
that call, the build continues, prints its success census, joins the
selector group and **exits 0** with the stair simply absent. The engine's
loudest failure mode here is a stderr line nobody is reading. **Fix:** one
foreign-key pass in `_validate_layout` over `connects` / `space` / `shaft`
/ `from` / `to`, appending to `failures` like every other rule. **Owner:**
the spatial-construction owner (same lane as D1). Not fixed here.

**C1 — Landing a correct floor raises the blocker count before it lowers
it.** 80 → 92 on geometry alone, then 92 → 74 when the checkpoint lands.
Read as a regression, this will look like the floor broke something. It did
not: the twelve new rows are the two apartments' domestic minimums, which
cannot exist as requirements until the unit exists. Always compare with
`--baseline` and read the *ids*, never the count alone.

**C2 — Gutting an apartment improves its unit-level status.** Unit status
is worst-of across the unit's spaces, and deleting the weak rooms removes
them from the worst-of. **unit.5B** stayed SPATIALLY_PROVEN while three of
its six minimums were ABSENT. The per-function rows caught it, so the
ledger as a whole is honest, but the unit row alone is not a summary of the
unit. **Owner:** program management, to decide whether `unit.<id>` should
be floored by its own minimums. Not changed here — changing it would move
live requirement statuses on the shipped ledger.

**C3 — Purpose text is matched as a literal phrase, and this already bites
the shipped building.** The entry minimum needs the contiguous string
"privacy and distribution" or "weather lock". **F02_B_VESTIBULE**'s
purpose reads *"2B privacy, coat storage and distribution"* — the comma
breaks the phrase, so **unit.2B.entry** is ABSENT today on a built,
traversed, human-accepted vestibule. It is one of the 80 structural
blockers. Symmetrically, *"coat storage"* in that same purpose silently
satisfies the **storage** minimum. **Owner:** the spatial-construction
owner, for the purpose text; program management, if the predicate should
become phrase-tolerant. Not changed here — loosening a predicate to admit
a room is exactly "adjusting a tool to make a bad floor look good".

**C4 — An orphan anchor blocks nothing.** ANCHOR_ONLY is a status on the
documented ladder, but `_find_anchor_only` only populates an advisory list;
no requirement carries the status and no scope is blocked by it. Named now
(T1), still non-blocking. **Owner:** program management.

**C5 — v2-only ids are invisible to the dependency audit until a consumer
names them.** Deliberate and documented in `SECONDARY_AUTHORITIES`, but it
means "run the dependency audit after building the floor" will report far
less than a floor owner expects: only the ids that collide with the v1
universe. The audit becomes meaningful for the new vocabulary at
composition time, not construction time.

**C6 — Eight of twelve count assertions in the committed Godot suite break
the moment any floor lands.** `game/tests/orison_v2_blockout_test.gd`
asserts exact table sizes. Against the correct F05 layout:

| table | suite asserts | today | with F05 |
|---|---:|---:|---:|
| levels | 5 | 5 | 6 |
| spaces | 50 | 50 | 68 |
| doors | 21 | 21 | 24 |
| openings | 19 | 19 | 33 |
| platforms | 24 | 24 | 28 |
| lift_landings | 8 | 8 | 10 |
| stairs | 7 | 7 | 9 |
| anchors | 48 | 48 | 51 |

windows, envelopes, fixtures and capsule_stations are unchanged only
because the synthetic floor declares none. **Owner:** the
spatial-construction owner, in the same commit as the floor.

## Tooling changes made here

All three are reporting/documentation corrections in the tooling lane. None
changes a status, a threshold or an exit code; each is covered by a new
test. Suites went 77/48/34 → **81/51/34**.

- **T1 — name the findings the ledger already found.**
  `tools/audit_orison_v2_completeness.py` counted `anchor_only_findings`
  and `stale_checkpoint_ids` in the summary and carried them in `--json`,
  but never named them in the default or markdown output. A floor owner
  running the gate saw `anchor_only_findings: 1` and had no way to learn
  which anchor. New `render_findings()` prints both in the default output
  and as a `## Findings` section in `--markdown`.
  Tests: `test_orphan_anchor_is_named_not_just_counted`,
  `test_stale_checkpoint_identifier_is_named`,
  `test_a_clean_layout_prints_no_findings_section`.
- **T2 — say which classification changed.**
  `tools/audit_orison_spatial_dependencies.py` printed three distinct drift
  causes under one label, "authority-class changes (FAIL)". The label is
  now "classification changes (FAIL)" and each row names its cause
  (`authority X -> Y`, `gameplay_binding X -> Y`, `resolved_target X -> Y`)
  via the new `class_change_cause()`.
  Tests: `test_classification_change_rows_name_their_cause`,
  `test_authority_change_row_says_authority`,
  `test_class_change_cause_helper_prefers_the_strongest_cause`.
- **T3 — the `heuristic` flag never capped anything.** Both the tool
  docstring and `design/ORISON_V2_COMPLETENESS_LEDGER_GUIDE.md` claimed
  heuristic conclusions "can never promote a requirement past PROGRAMMED".
  The code has no such cap, and the shipped ledger depends on that:
  **unit.2B.storage** is SPATIALLY_PROVEN today on a grammar-derived
  mapping. The flag qualifies which spaces were *taken to belong* to the
  unit, not the status they may reach. Prose corrected in both places;
  the code is unchanged, because adding the cap would demote the
  owner-accepted 2B and permanently block every unit outside
  `UNIT_PREFIX_EXACT` no matter what evidence lands.
  Test: `test_heuristic_mapping_does_not_cap_the_status`.

The dependency manifest is **unchanged**: the `--update-manifest` rehearsal
ran entirely inside a scratch repository root.

## How to land a floor — playbook

1. **Build the geometry.** Spaces need `class`, a non-empty `purpose`, a
   valid `rect`, and a door or cased opening reaching every room. A space
   with no entrance is SHELL_ONLY and drags its unit and its floor down
   with it; the only exception is a `core`-class space on a level a stair
   or lift landing reaches, and a deliberate `open_shell` (an apron, a
   landing void), which is excluded from the floor's worst-of.
2. **Write purpose text against the predicate, not against taste.** The
   ledger matches purpose as a literal substring. Entry needs *"privacy and
   distribution"* or *"weather lock"* — unbroken, no comma inside the
   phrase. Cooking needs *"cooking"*, sleep *"sleep"*, storage *"storage"*,
   sanitary *"sanitary"* or `class: "wet"`, living any of *"living"*,
   *"rest"*, *"meeting"*, *"conversation"*. Circulation needs *"decision"*
   or *"landing"*, *"passenger lift"* or *"primary stair"*, *"service
   lift"* or *"service stair"*, and *"maintenance"* / *"service"* /
   *"delivery"*. Confirm with `--unit 5A` before writing any prose.
3. **Reuse the v1 id wherever the v1 building had the same room.** Ids that
   resolve in the v1 universe classify as PRESERVE_OR_ALIAS. Invented ids
   with no v1 counterpart are invisible to the dependency audit until a
   consumer names them, then land as UNRESOLVED unless the adapter or a
   curated contract claims them.
4. **Validate in the engine, and update the counts in the same commit.**
   `orison_v2_blockout.gd` refuses duplicate ids, missing levels, invalid
   rects and missing compatibility ids — loudly, building nothing. It does
   **not** refuse overlapping rooms or dangling `connects` / `shaft` /
   stair `from`-`to` references (D1, D2); check those by hand until they
   are fixed. Then update the eight count assertions in
   `game/tests/orison_v2_blockout_test.gd` (C6) — the suite fails on the
   first one otherwise, and reads like the floor broke the building.
5. **Run the ledger and expect the count to rise.** New units create new
   minimum requirements. Read the ids, not the number:
   `python tools/audit_orison_v2_completeness.py --floor F05` and
   `--unit 5A`. Everything should be at least PROGRAMMED before you write
   a word of prose.
6. **Write the checkpoint, and check it before you commit it.** The name
   decides everything: `CHECKPOINT`, `GRAYBOX`, `ACCEPTANCE`, `RECEIPT`,
   `VERTICAL_CORE`, `SCHEMA_GENERATOR` are admitted; a `REPORT`, `CENSUS`,
   `AUDIT`, `HANDOFF`, `SCHEDULE` or `GUIDE` is inert no matter what it
   says. **Backtick the exact ids you actually proved** — a checkpoint that
   describes the floor beautifully and backticks nothing promotes nothing
   (proved above). Backtick only ids that exist in the layout you are
   committing: one that has since vanished is filed as stale evidence, and
   the rehearsal produced three that way in ten seconds. Then:
   `python tools/audit_orison_v2_completeness.py --evidence-impact
   design/<your doc>.md` — exit 1 with the exact list of promotions is what
   you want to see, and it tells you before you commit whether the document
   proves what you meant it to.
7. **Absorb the manifest drift deliberately, in the floor's own commit.**
   `python tools/audit_orison_spatial_dependencies.py` will fail with new
   unclassified records *and* a pile of classification changes on files you
   never touched — those are re-resolutions caused by the blockout being a
   second authority, and each row now names its cause. Read them, confirm
   every one is a `resolved_target` line, then
   `--update-manifest` and re-run to green. Never update the manifest to
   silence a record you have not read.
8. **Close the gates.** Three gates plus three suites, real exit codes,
   left as found:

```
python tools/audit_orison_v2_completeness.py
python tools/audit_orison_spatial_dependencies.py
python tools/audit_systemic_situation_authority.py
python tools/tests/test_orison_v2_completeness.py
python tools/tests/test_orison_spatial_dependencies.py
python tools/tests/test_systemic_situation_authority.py
```

The unfiltered completeness run stays at exit 2 until the whole rebuild is
done; that is correct, not a failure. Filtered runs (`--floor`, `--unit`,
`--space`, `--blockers-for`) exit 2 whenever anything in the filter still
blocks — verified in this rehearsal. Do not read an exit code through a
pipe; `head` will report its own.

### Traps, shortest form

- The blocker count goes **up** when you build correctly, and down when you
  checkpoint. (C1)
- A comma inside "privacy and distribution" costs you the entry minimum.
  It costs 2B one today. (C3)
- A checkpoint named `..._REPORT.md` proves nothing. A checkpoint with no
  backticks proves nothing. Both are silent.
- A backticked id that is not in the layout you commit becomes stale
  evidence, not proof.
- Overlapping rooms and dangling references build without complaint, and a
  broken stair reference exits 0 with the stair missing. Read stderr, not
  just the exit code. (D1, D2)
- Eight count assertions in the Godot suite break on any new floor. (C6)
- The dependency audit will report ~65 drift rows for one floor; ~54 of
  them are in files you never opened. (7a)

## Verdict

**READY WITH CAVEAT.** The machinery credits a correct floor for exactly
the right requirements, refuses to call it proven until a properly-named
checkpoint backticks the exact ids, and correctly reports SHELL_ONLY,
missing minimums by purpose text, ANCHOR_ONLY, stale evidence, and new
unclassified dependencies. It cannot be talked into a promotion by prose.
The named caveats are C1–C6 above; the two BROKEN items are D1 (overlap)
and D2 (referential integrity), both owned by the spatial-construction
owner and both cheap.

## Gate results for this landing

Run on the restored tree at the end of the work, real exit codes, never
through a pipe:

| Gate | Exit | Result |
|---|---:|---|
| `python tools/audit_orison_v2_completeness.py` | 2 | FIRST_SLICE_TECHNICAL 0 · GOLDEN_SHIFT_V2 1 · FULL_BUILDING_STRUCTURAL 80 · FULL_BUILDING_RUNTIME 45 · PRODUCTION_CUTOVER 95 · V1_RETIREMENT 97 — **identical to the baseline at `3aa3764`** |
| `python tools/audit_orison_spatial_dependencies.py` | 0 | clean; 0 new unclassified, 0 classification changes, 0 vanished, 0 stale |
| `python tools/audit_systemic_situation_authority.py` | 0 | clean |
| `python tools/tests/test_orison_v2_completeness.py` | 0 | 81 tests (was 77) |
| `python tools/tests/test_orison_spatial_dependencies.py` | 0 | 51 tests (was 48) |
| `python tools/tests/test_systemic_situation_authority.py` | 0 | 34 tests |
| `res://tests/OrisonV2BlockoutTest.tscn` (serial runner, `-LogPath`) | 0 | `ORISON V2 BLOCKOUT TEST: PASS` |

**Manifest delta: none.** `tools/orison_spatial_dependency_manifest.json` is
byte-identical to `3aa3764`; the `--update-manifest` rehearsal ran against a
scratch repository root built from copies of `game/{scripts,scenes,tests,data}`
and `art/data`.

**Left as found.** The synthetic layouts, the temporary Godot fixture
directory and the temporary harness scene were removed; the tracked
`.import` files that Godot's `--import` rewrote were restored (the change was
line-endings only, zero content lines). The ~237 untracked `*.uid` files are
the documented fresh-worktree `--import` side effect and were deliberately
left alone and not staged. The Godot lane was serialized through
`tools/run_godot_serial.ps1` throughout and is free.

**Runner note, confirming the handoff pack's warning from the other side.**
The fixed runner does report true exit codes — the rehearsal harness returned
4, then 0, honestly. But the runner only writes a log when given `-LogPath`;
without it the child inherits the console and a wrapper's PowerShell
redirection captures nothing, so a caller sees an exit code and an empty log.
Two of my own readings were instrument errors, not findings: an exit code read
through a pipe reports `head`'s status, and `& runner.ps1` inside
`pwsh -Command` needs an explicit `exit $LASTEXITCODE` to propagate. Always
pass `-LogPath` and read the printed PASS/FAIL lines beside the code.
