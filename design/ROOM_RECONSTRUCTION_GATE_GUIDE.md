# Room reconstruction gate — usage and interpretation

`tools/room_reconstruction_gate.py` answers one question with one command:
**"Is this room checkpoint safe to land, and if not, exactly which gate
blocks it?"**  It chains the existing toolchain in order — checkpoint lint,
regeneration reconciliation, evidence verification, and the progress ledger
enriched with the evidence report — by invoking each component's own CLI
in-process, so their parsers, statuses and conservative semantics are
preserved exactly.  The wrapper composes their answers; it never
manufactures a greener one, never runs Godot/Blender/captures/imports/
production tests, and LANDABLE never means visually complete.

## Commands

```
# strict gate for one new checkpoint
python tools/room_reconstruction_gate.py \
    --checkpoint design/ORISON_X_CHECKPOINT_2026-08-27.md --output <dir>

# strict gate for everything checkpoint-shaped changed since a commit
python tools/room_reconstruction_gate.py --changed-since <git-ref> --output <dir>

# explicit whole-corpus audit (historical-debt policy)
python tools/room_reconstruction_gate.py --checkpoints design --output <dir>
```

Options: `--layout`, `--repository-root`, `--floor`, `--room`,
`--json-only`, `--markdown-only`, `--force`, `--no-git`.  Selection is
explicit: `--checkpoint` and `--changed-since` are mutually exclusive, and
with neither, `--checkpoints <dir>` must be passed deliberately —
historical checkpoints are never gated silently.  `--checkpoints` also
names the corpus root (default `<root>/design`) for the other modes.

## Outputs

`room_reconstruction_gate.json` + `room_reconstruction_gate.md` (a one-page
summary) plus the full component reports under `components/lint/`,
`components/reconciliation/`, `components/evidence/`,
`components/progress/`.  Everything is produced in a private staging
directory and published atomically only after every component finished, its
files parse, and the summary composed; overwrite is refused without
`--force` (exit 3), and a component failure publishes a BLOCKED_INTERNAL
packet with the component's stdout/stderr — never a partial LANDABLE.

## Results and exit codes (stable, tested)

| Result | Exit | Meaning |
|---|---:|---|
| LANDABLE | 0 | every gate clean, no symbolic debt |
| LANDABLE_WITH_SYMBOLIC_EVIDENCE | 2 | gates clean; SYMBOLIC_ONLY evidence debt remains visible |
| BLOCKED_LINT / BLOCKED_DRIFT / BLOCKED_EVIDENCE / BLOCKED_REVIEW | 1 | blocked (see blocker list) |
| BLOCKED_MALFORMED | 4 | malformed checkpoint/evidence data (5 when combined with an ordinary blocker) |
| BLOCKED_INTERNAL | 70 | component failure |
| (usage) | 3 | overwrite refusal, bad selection, invalid git ref, `--changed-since` with `--no-git`; argparse flag errors are remapped to 3 so exit 2 stays unambiguous |

## Blocker policy

**Strict** (single checkpoint / `--changed-since`):

- *Lint*: no malformed rows; every row READY (READY already covers explicit
  `[manual]`/`[visual]` and declared-runtime rows).
- *Reconciliation*: no CONTRADICTED decisions; no conflicts touching the
  selection; no malformed rows; OPEN blocks; UNVERIFIABLE is allowed only
  when explicitly declared (its lint row is READY, or the reconciler flags
  a declared runtime scope).  Authoring-shaped unverifiables (no stable id,
  kind token, imprecise id, no checkable target) block under the **lint**
  category so the fix is named correctly; genuine layout uncertainty blocks
  as **drift**.
- *Evidence*: no MISSING cited artifact, RECORDED_FAIL, METADATA_MISMATCH
  or malformed evidence record.  VERIFIED_PRESENT is never a recorded pass.
  SYMBOLIC_ONLY does not block but stays visible, split into
  claimed-durable-proof-without-artifact, manual assertions, and symbolic
  test names.
- *Progress*: the ledger must generate, consume the evidence report, show
  no DRIFT_RED for selected rooms, retain manual/runtime states, and (an
  enforced invariant) contain no COMPLETE state.

**Whole-corpus** (`--checkpoints`): known historical lint debt, prose-only
checkpoints, OPEN decisions and undeclared manual rows are *reported as
debt, not regressions*; the corpus still fails on contradictions,
conflicts, malformed records, missing exact evidence, recorded failures
and metadata mismatches.  A corpus LANDABLE therefore means "no hard
failures", never "all work done" — the debt list is the work.

## Changed-since selection

With git, `--changed-since <ref>` selects added/modified
`ORISON_*CHECKPOINT*.md`, `*.decisions.json` and `*.evidence.json` under the
corpus root (committed, staged, unstaged and untracked), ignores unrelated
files, reports the exact selection, fails clearly (exit 3) on an
unresolvable ref, and surfaces **deleted** checkpoint documents as
BLOCKED_REVIEW — a deliberate review condition, never silently ignored.
`--no-git` rejects `--changed-since` rather than guessing.

## Reading the report

The one-pager shows: selection (checkpoints + resolved rooms), mode,
result + exit, repository commit and exact command (git enabled), lint
READY/attention counts, reconciliation S/O/C/U counts, the six evidence
counts, progress states per selected room, blockers in priority order
(drift, malformed, evidence, review, lint) each with its source line and a
concrete next action — add an exact ID, supply a MOVE target, mark a
decision `[manual]`/`[visual]`, resolve a contradiction, attach a missing
receipt, correct mismatched metadata, split a multi-room decision, rerun
after regeneration — and the non-blocking symbolic/manual debt.  It never
recommends moving, adding or removing production objects.

## Limitations

- The gate is exactly as strong as its components; it adds selection,
  policy and atomic packaging, not new analysis.
- Reconciliation and evidence always run over the whole corpus (conflicts
  and regeneration truth are corpus-wide); only gating is scoped.
- An empty `--changed-since` selection gates nothing and reports LANDABLE
  vacuously — the selection list in the report makes this visible.
- Landability is layout-and-artifact truth only: visual, interaction and
  historical correctness remain human judgments the ledger keeps carrying
  as manual/runtime debt.

## Tests

```
python tools/tests/test_room_reconstruction_gate.py
```

26 tests over synthetic repository roots: fully landable, landable with
symbolic evidence, pure lint blocker, OPEN blocker, contradiction +
conflict, missing artifact, recorded failure, metadata mismatch, malformed
verdicts and evidence manifests, multiple simultaneous blockers (exit 5),
strict vs corpus policy on the same document, changed-since selection,
deleted-checkpoint review, invalid ref and `--no-git` incompatibility,
explicit-selection enforcement, component crash and missing component
output (BLOCKED_INTERNAL, exit 70), atomic publication, no-overwrite/
`--force`, byte-identical determinism, room filtering, json/markdown-only
modes, component-report preservation, and the no-COMPLETE invariant.
