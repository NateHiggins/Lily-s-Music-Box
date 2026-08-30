# Orison v2 rebuild dry-run plan — 2026-08-30

Status: **PREPARED, NOT EXECUTED**. This is a rehearsal plan, not spatial
evidence, acceptance, or authorization to change the production selector. It is
deliberately named as a plan so the completeness ledger refuses it as proof.

## Purpose

Rehearse the first Orison v2 rebuild landing without authoring production
geometry. The rehearsal proves that inputs have readers, shared coordinate and
identity frames are ruled, generated outputs remain isolated from v1, failure is
observable, and the first new kind of space can be evaluated before it is
multiplied across the building.

The dry run follows `ORISON_GENETIC_MEMORY_2026-08-29.md` Part 7 and
`ORISON_V2_SEPT3_REBUILD_HANDOFF_2026-08-28.md`. It does not override either.

## Immutable controls

- `BuildingRootSelector.DEFAULT_ID` remains `"v1"`.
- No command writes `game/data/building_layout.json`,
  `art/data/building_layout.json`, current floor GLTF/BIN assets, or historical
  evidence directories.
- The shared dirty checkout is not used. Run in a clean worktree from a
  commit-pinned integration branch.
- One Godot process owns the lane. Lane refusal is exit 73, timeout is 124,
  environment failure is 78, and a suite's real failure is never rewritten as
  success.
- A report, plan, census, or handoff is not evidence. Candidate documents are
  checked with `--evidence-impact` before commit.
- The dry run stops before geometry if any prerequisite below is absent.

## Phase 0 — pin and inventory

Record:

1. integration commit and `origin/main` base;
2. clean-worktree status;
3. production-layout and v1 generated-asset hashes;
4. Godot, Blender and Python versions actually used;
5. active Godot/Blender process census;
6. current completeness counts and stale identifiers; and
7. exact output directory reserved for disposable v2 rehearsal artifacts.

No result from another commit or machine is silently reused.

## Phase 1 — prove the instruments can be red

Before trusting a green run:

- exercise the corrected serial runner against one known passing short suite;
- exercise its timeout path against a bounded long suite and require exit 124;
- exercise lane refusal without killing the occupying process and require exit
  73;
- run the builder's committed malformed-geometry fixture and require refusal;
- run each new gate's named bad fixture and require nonzero; and
- record command, scope, exit, decisive output line and artifact path.

Abort if a known-bad input exits zero or if a command has an empty/vacuous
selection.

## Phase 2 — pre-M11 dependency table

The rehearsal produces a yes/no table for these dependencies. A **no** stops the
run before geometry:

1. every new `game/data/` file has a production reader or a named exception;
2. persisted numeric fields have readers and are not write-only monotonic
   progress;
3. the element-indexed lineage/corruption vocabulary covers street, apron,
   arcade, shopfronts, B1 and service circulation;
4. the street/neighbourhood origin is ruled;
5. the shop identifier namespace is ruled;
6. the simulation-tier epoch is ruled;
7. the anomaly/space binding frame is ruled;
8. the completeness ledger has an exterior/region axis;
9. v2 exterior data has an authoritative output home separate from v1;
10. saved dream-module revision reconciliation exists; and
11. the floor-residency measurement exists before anyone chooses a
    `floor_01` cut granularity.

The verification-middleware ablation remains separately pre-registered work. Do
not turn its unproven detector into rebuild gate authority during this rehearsal.

## Phase 3 — zero-geometry rehearsal

In scratch copies only:

1. draft the correctly classified checkpoint amendment that backticks
   `F02_B_VESTIBULE` and `F01_WATCH` and resolves the stale
   `B1_PUBLIC_LANDING_E` claim;
2. run `--evidence-impact` and record the predicted status movement;
3. do not land the amendment merely to improve a number;
4. instantiate a synthetic first-shop schema record with durable simulation
   facts and `advance()` ownership, but no render geometry;
5. prove its data reader, save/reconstruction behavior and refusal boundary;
6. rehearse the declared F02/F04 service-hall opening records in disposable v2
   output; and
7. compare the resulting dependency/ledger delta without updating a baseline.

The expected blocker count may rise when new authored requirements become
visible. That is not failure. Unclassified dependencies, vanished preserved
targets, v1 hash changes, false evidence promotion and unread authored data are
failures.

## Phase 4 — synthetic first-cell proof

Only after Phases 0–3 pass, build one disposable synthetic instance for each new
kind, in this order:

1. first shop/bodega bucket;
2. first street segment and threshold cell; and
3. first exterior route connection.

Each instance must use public surface/placement resolvers, carry explicit
lineage, survive save/reconstruction, render once, and be inspected by a human.
Nothing is applied building-wide. No `floor_01` split occurs during this dry run.

## Required before/after gates

```text
python tools/audit_orison_v2_completeness.py
python tools/audit_orison_spatial_dependencies.py
python tools/audit_systemic_situation_authority.py
python tools/tests/test_orison_v2_completeness.py
python tools/tests/test_orison_spatial_dependencies.py
python tools/tests/test_systemic_situation_authority.py
```

Expected baseline: completeness exits 2 while the whole rebuild is incomplete;
the two drift/authority audits and all test suites exit 0. A lower completeness
count is not itself acceptance.

## Stop conditions

Stop without cleanup-by-baseline when any of the following occurs:

- v1 selector, layout or generated-asset hash changes;
- a new data file has no production reader;
- a shared frame is inferred rather than ruled;
- a gate cannot demonstrate its red fixture;
- the runner reports a result inconsistent with the child process;
- output escapes the disposable v2 directory;
- an evidence-inert document changes completeness state;
- synthetic placement intersects, floats or loses its owning surface;
- save/reconstruction changes semantic identity; or
- visual inspection cannot identify the intended threshold and route.

## Dry-run receipt

The final receipt must state **PASS**, **FAIL**, or **BLOCKED** for every phase;
list every command and real exit code; include before/after hashes and ledger
counts; name all unresolved prerequisites; and finish with one explicit decision:

- authorize the first bounded v2 build landing;
- repeat the dry run after named corrections; or
- revise the rebuild plan before authoring geometry.

No dry-run outcome authorizes M09, production cutover, v1 retirement or a
building-wide generation pass.
