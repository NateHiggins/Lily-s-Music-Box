# Room checkpoint linter — usage and interpretation

`tools/room_checkpoint_linter.py` closes the loop the reconciler exposed:
most unverifiable decisions are created at checkpoint-*authoring* time.  The
linter analyzes a checkpoint draft before it is committed and reports, per
verdict row, whether the reconciler will be able to check it — and if not,
exactly which fact the author must supply.  It is strictly read-only: it
never edits the checkpoint, layout, generator or any production data, never
rewrites prose, and never selects among ambiguous candidates.

Parsing and object inventory are reused from the reconciler and workbench
(same verdict tables, same backtick/range/glob/arrow syntax, same object
index and room ownership), so the three tools cannot disagree about what an
id means.

## Commands

```
python tools/room_checkpoint_linter.py --checkpoint design/ORISON_X_CHECKPOINT_2026-08-27.md
python tools/room_checkpoint_linter.py --checkpoint design            # every checkpoint
python tools/room_checkpoint_linter.py --checkpoint my.decisions.json # manifests lint too
python tools/room_checkpoint_linter.py --checkpoint <draft.md> \
    --scaffold-output <explicit-dir> [--force]
```

Without `--scaffold-output` the lint report prints to stdout.  With it, the
tool writes `<name>.lint.json`, `<name>.lint.md` and
`<name>.decisions.json.proposed` per checkpoint into the explicit directory
only — never beside the production checkpoints — and refuses to overwrite
existing files without `--force` (exit 3).

## Diagnostics

| Diagnostic | Meaning |
|---|---|
| `EXACT` | token resolves to exactly one layout record, or one explicit stable set (full `a..b` range, glob family, proposed-new ADD id, or an absence target that already matches nothing) |
| `AMBIGUOUS` | several candidate records; the author must choose — the linter lists them all and picks none |
| `PREFIX_ONLY` | no exact record, but ids extending the token exist (`lobby_runner` → `lobby_runner_rug`); the likely id is named but **not assumed** |
| `KIND_NOT_ID` | token names an assembly/marker kind (`arcade_cab`), not a record id; the records of that kind are listed — a deliberate kind-wide rule must be written as the explicit id list (or a glob that matches exactly that family) |
| `RUNTIME_ONLY` | identifier found in `game/scripts/**/*.gd` / `game/data/*.json` but never in layout JSON; a text match does not prove instantiation or placement |
| `ARCHITECTURAL` | room-envelope vocabulary (walls/floor/ceiling/trim/windows...) with no per-object id |
| `MANUAL_TARGET` | the row declares manual/visual verification via a `[manual]` or `[visual]` tag — a legitimate final state |
| `UNKNOWN` | no known repository entity matches |
| `MISSING_TARGET` | the verdict needs a target fact that is absent |
| `MISSING_TOLERANCE` | advisory only: positional target without an explicit tolerance (reconciler defaults 0.05 m / 1.0° apply) |
| `CONFLICTING_TOKEN` | token matches more than one entity class, or an ADD proposes an id that already exists |
| `NO_VERDICT_TABLE` | document-level: prose-only checkpoint; its backticked tokens are inventoried informationally |
| `READY` | the row is machine-checkable as written, or explicitly manual |

## Verdict completeness rules

- **KEEP** needs an exact id, an explicit stable set, or `[manual]`.
- **REMOVE / KEEP ABSENT** likewise — but a literal token that matches
  nothing is already a checkable absence target (already retired, or never
  existed; the reconciler verifies absence either way).  `PREFIX_ONLY`
  remains a warning here: a misspelt id would "verify absent" forever.
- **MOVE** needs an explicit target (manifest `expected.position` / `room` /
  `yaw_deg`); a table's Room column is context, not a target.  The object's
  current coordinates are shown *for reference, never as the target*.
  Tolerances should be explicit (advisory otherwise).
- **REPAIR** needs a layout-checkable property or an explicit
  `[visual]`/`[manual]` marker — "repair appearance" must not pretend to be
  layout-verifiable.
- **REPLACE** needs both sides: `` `old` -> `new` `` in the element cell or a
  manifest `replacement`.  The linter notes when the old object is still
  present and when the proposed replacement already exists.
- **ADD** needs a stable proposed id (a token matching nothing is the good
  case), the target room, and an expected type — a kind token in the same
  cell (`` `new_lamp` (`plant`) `` style) satisfies the type requirement.
  A proposed id that already exists is `CONFLICTING_TOKEN`.
- **Runtime objects** need a manifest entry with `scope: "runtime"` plus a
  manual/scene/live-proof field; the linter scaffolds the entry with the
  evidence paths filled in and `"proof": "REQUIRED"`.

`[manual]` / `[visual]` in the Reason (or Element) cell is the documented way
to declare that a spatial verdict is deliberately human-verified; such rows
lint READY and the reconciler will report them as explicitly unverifiable
rather than as authoring gaps.

## Prose analysis

Rows without backticked tokens get conservative phrase resolution:
room-envelope vocabulary is labeled `ARCHITECTURAL`; words matching assembly/
marker kinds are narrowed to the row's room — exactly one record in the room
yields an exact backtick suggestion ("phrase 'toilet' resolves to exactly one
toilet in F01_RESTROOM: use `F01WC_wc`"), several yield the full candidate
list, never a pick.  Everything else is `UNKNOWN`.  A suggestion never makes
the row READY by itself: the author must actually add the backticked id.

## The proposed manifest

`<name>.decisions.json.proposed` is an evidence-backed scaffold: source line
and quote preserved per entry, exact ids filled only where unambiguous,
`object_candidates` listed otherwise, `"REQUIRED"` markers for every fact the
author still owes (targets, tolerances, rationale, runtime proof).  The
`.proposed` suffix means the reconciler will not read it; an author reviews
it, replaces every `REQUIRED`, deletes what they do not endorse, and renames
it to `*.decisions.json`.

## Exit codes (stable, tested)

| Code | Meaning |
|---|---|
| 0 | every decision machine-checkable or explicitly manual |
| 1 | unresolved/ambiguous decisions (or prose-only checkpoints) remain |
| 3 | refused to overwrite scaffold output (pass `--force`) |
| 4 | malformed checkpoint structure (broken rows, unrecognized verdicts) |
| 5 | both 1 and 4 |
| 2 | usage error (bad arguments, missing checkpoint file) |
| 70 | unexpected internal failure |

## Suggested authoring loop

1. Draft the checkpoint with its verdict table.
2. `room_checkpoint_linter.py --checkpoint <draft>` — fix rows until only
   deliberate `[manual]`/runtime states remain (exit 0).
3. Optionally scaffold and complete a decisions manifest for MOVE/REPAIR/
   runtime decisions the table cannot carry.
4. Commit the checkpoint; regenerate; gate with the reconciler (exit 0).

## Limitations

- Phrase resolution sees assembly/marker kinds and envelope vocabulary only;
  it cannot name ids for prose describing batches, materials or site zones.
- The runtime scan is substring evidence, not proof of instantiation.
- Kind containment matches (e.g. "pendant" → `pendant_shade`) are only
  reported when the row's room actually holds one.
- The linter checks against the current layout: a draft written against a
  stale layout can lint clean and still reconcile dirty — run both.
- Manifest linting checks target completeness, not value plausibility.

## Tests

```
python tools/tests/test_room_checkpoint_linter.py
```

29 tests over synthetic fixtures (`tools/tests/fixtures/lint_drafts/`,
`runtime_src/`, plus the shared mini layout): every diagnostic above, one and
many prefix matches, kind-vs-id, runtime evidence, unknown prose, MOVE
without target, REPAIR without property, REPLACE missing a side, ADD with a
duplicate id, manual-verification records, prose suggestions (single and
ambiguous), prose-only inventory, manifest linting, deterministic scaffolds,
the reconciler ignoring `.proposed` files, no-overwrite/`--force`, missing
files, malformed tables, out-of-repository operation, and the exit contract.
