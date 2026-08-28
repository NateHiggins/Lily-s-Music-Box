# Orison v2 completeness ledger — usage guide

**Tool:** `tools/audit_orison_v2_completeness.py` (read-only, standard
library, no Godot/Blender/Git). **Tests:**
`tools/tests/test_orison_v2_completeness.py` (42, fixture-backed).
**Companion report:**
`design/ORISON_V2_FULL_REBUILD_COMPLETENESS_AUDIT_2026-08-28.md`.

The ledger exists to make one confusion impossible: **"the accepted route
works" is not "the complete building has been rebuilt."** It compares the
canonical program obligations against the current v2 schema and the
committed evidence, and reports per-requirement statuses with provenance —
never a single percentage.

## Running it

```bash
python tools/audit_orison_v2_completeness.py
```

Useful forms:

```bash
python tools/audit_orison_v2_completeness.py --json          # machine output
python tools/audit_orison_v2_completeness.py --markdown      # full ledger to stdout
python tools/audit_orison_v2_completeness.py --floor F02     # one floor
python tools/audit_orison_v2_completeness.py --unit 2A       # one unit (incl. its jobs/cases)
python tools/audit_orison_v2_completeness.py --space F02_A_MAIN
python tools/audit_orison_v2_completeness.py --blockers-for first-slice
python tools/audit_orison_v2_completeness.py --blockers-for golden-shift
python tools/audit_orison_v2_completeness.py --blockers-for full-building
python tools/audit_orison_v2_completeness.py --blockers-for production-cutover
python tools/audit_orison_v2_completeness.py --blockers-for retirement
python tools/audit_orison_v2_completeness.py --baseline prior_ledger_or_v2_layout.json
python tools/audit_orison_v2_completeness.py --out <dir>     # write JSON+MD reports
```

Input overrides: `--root`, `--v1-layout`, `--v2-layout`, `--design-dir`,
`--dependency-manifest`, `--acceptance`. `--blockers-only` survives as a
backward-compatible alias for `--blockers-for production-cutover` — the
WIDE meaning, never the first slice.

## Readiness scopes

Every requirement carries `blocking_scopes` / `complete_for_scopes` over
six ordered scopes: `FIRST_SLICE_TECHNICAL` (accepted route + M08E
ritual/2B/B1 owners + runtime composition + two-root proof; supports an
explicit v2 development/test selector only), `GOLDEN_SHIFT_V2` (eleven
authored beats under explicit v2 selection), `FULL_BUILDING_STRUCTURAL`,
`FULL_BUILDING_RUNTIME`, `PRODUCTION_CUTOVER` (both full-building scopes
plus whole-building navigation/performance/human acceptance and the
authorized reversible flip), `V1_RETIREMENT` (no fallbacks, rollback
window closed, owner authorization).

The ten M08D dependencies are **first-slice blockers** (equivalently:
golden-shift spatial blockers) — never "the cutover blockers".
Production-cutover blockers include every required absent or incomplete
whole-building obligation; a first-slice or golden-shift pass **cannot
flip `BuildingRootSelector.DEFAULT_ID`**. A clean first-slice query
prints exactly: `FIRST SLICE READY - PRODUCTION CUTOVER NOT IMPLIED.`

A v1 fallback of kind `absence` blocks every scope needing the item; a
`redundancy` fallback (v2 path proven, v1 path kept by contract, e.g.
the anonymous bed) blocks only `V1_RETIREMENT`.

**Exit codes:** `0` nothing in scope blocks the queried scope — for the
unfiltered run that means the whole rebuild is complete through
PRODUCTION_CUTOVER and V1_RETIREMENT, the operational definition of
"the Orison rebuild is complete" · `1` only V1_RETIREMENT-scope work
remains in scope · `2` a production-cutover-or-earlier blocker is in
scope (with `--blockers-for`, a blocker for that scope) · `3` malformed
input / refused output / usage · `70` internal failure. The unfiltered
run stays nonzero until the whole rebuild is complete; today it exits
`2`, and that is correct, not a tool failure.

**Output safety:** the tool writes nothing without `--out`. It refuses
`game/` and `art/` outright and refuses `design/` except the single
documented safe path `design/orison_v2_completeness_reports`. Existing
reports are never overwritten without `--force`; writes are atomic
(temp file + rename). Report filenames are stable
(`ORISON_V2_COMPLETENESS_LEDGER.json/.md`) and content is deterministic —
no timestamps, provenance is input SHA-256.

## Status ladder

`ABSENT → SHELL_ONLY / ANCHOR_ONLY → PROGRAMMED → SPATIALLY_PROVEN →
RUNTIME_PROVEN → HUMAN_ACCEPTED`, with orthogonal flags
`TEMPORARY_V1_FALLBACK` (kind `absence` or `redundancy`), `BLOCKED` and
`NOT_REQUIRED`; readiness is expressed per scope via `blocking_scopes` /
`complete_for_scopes`, never as one terminal boolean. Key rules:

- A rectangle with no entrance, no purpose, or `open_shell` is
  SHELL_ONLY. An anchor outside every programmed space is ANCHOR_ONLY.
- Checkpoint documents promote a space only if they backtick its exact
  id AND the id still exists in the current v2 layout; a checkpointed id
  that has since vanished is reported as stale evidence.
- Gray-box/vertical-core/schema checkpoints grant at most
  SPATIALLY_PROVEN; M08-family checkpoints grant RUNTIME_PROVEN.
- HUMAN_ACCEPTED comes only from a durable owner-verdict JSON
  (`ORISON_V2_*HUMAN_ACCEPTANCE*.json`, verdict PASS) and applies only to
  its recorded scope. M08A is route-readability only; it never accepts a
  room, and a scene-capture receipt is never acceptance.
- Unit functions (entry/living/cooking/sanitary/sleep/storage) match the
  v2 record's own `purpose`/`class` fields, never the id token.
- Heuristic conclusions (unit membership by id grammar for units no
  checkpoint has named) are flagged `heuristic` and never promote past
  PROGRAMMED-level trust.
- Unit-level status is worst-of across the unit's spaces: an unnamed
  support hall keeps the unit below checkpoint tier deliberately.

## Where the canon lives

The requirement tables at the top of the tool (`CANON_FLOORS`,
`UNIT_FUNCTIONS`, `F01_PROGRAM`, `B1_PROGRAM`, `ROOF_PROGRAM`,
`FLOOR_CIRCULATION`, `SERVICE_SYSTEMS`, `RITUAL_IDENTITIES`,
`UNIT_PREFIX_EXACT`, `V1_TO_V2_ALIASES`) are the reviewed machine encoding
of `design/ORISON_ARCHITECTURAL_PROGRAM_2026-08-28.md`, the rebuild
checkpoint, the migration contract and the M08D blocker statement. Editing
the program means updating these tables in the same commit — the tool
cites the source document on every conclusion so drift is visible.

Sealed units (`2D 3C 5D 6D`) require only a public threshold until a case
opens them. Pseudo-rooms (acoustic navigation zones, riser vocabulary) are
excluded from room coverage rather than reported missing.

## Recommended cadence

After every Orison milestone (and before proposing one):

```bash
python tools/audit_orison_v2_completeness.py && python tools/audit_orison_spatial_dependencies.py && python tools/tests/test_orison_v2_completeness.py
```

Read the blockers and the queue head; a milestone is finished when the
requirements it claimed move up the ladder and nothing else regressed
(`--baseline` against the previous report shows exactly that).

## Limitations

- The canon encoding is a curated table, not a prose parser; program
  changes require a table update (enforced socially by provenance
  citations, not automatically).
- Checkpoint evidence is matched at identifier granularity: a checkpoint
  that proves a census without backticking each id leaves those spaces at
  PROGRAMMED. That under-claims rather than over-claims.
- Route existence inside v2 is taken from door/opening connectivity and
  the committed traversal checkpoints; the tool does not re-run BFS or
  geometry itself.
- Acceptance JSONs are trusted at face value (verdict/scope); the tool
  cannot detect a rubber-stamped receipt.
