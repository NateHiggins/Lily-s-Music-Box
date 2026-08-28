# Room checkpoint reconciler — usage and interpretation

`tools/room_checkpoint_reconciler.py` answers one operational question: after
the next `gen_layout.py` change and regeneration, do the object-level
decisions recorded in the room checkpoint documents still hold?  It is
read-only with respect to production layout data, checkpoint prose and
verdicts; it never edits a checkpoint to make its own report green.

## Commands

```
python tools/room_checkpoint_reconciler.py --output <dir>
python tools/room_checkpoint_reconciler.py \
    --layout art/data/building_layout.json --checkpoints design \
    --output <dir> [--force] [--no-git] \
    [--pos-tolerance 0.05] [--yaw-tolerance 1.0]
```

Outputs `room_checkpoint_status.json` and `room_checkpoint_status.md` into
the explicit `--output` directory (required; never defaults into tracked
directories; refuses to overwrite without `--force`, exit 3).  Output is
deterministic; `--no-git` additionally removes the git-provenance lookups so
the bytes depend only on the layout and checkpoint files.

## Exit codes (stable, tested)

| Code | Meaning |
|---|---|
| 0 | every parsed decision is SATISFIED, OPEN or explicitly UNVERIFIABLE |
| 1 | at least one CONTRADICTED decision or cross-checkpoint conflict |
| 3 | refused to overwrite existing output (pass `--force`) |
| 4 | malformed decision rows found |
| 5 | both 1 and 4 |
| 2 | command-line usage error |
| 70 | unexpected internal failure |

OPEN does **not** fail the run: an ADD that has not landed yet is normal
mid-reconstruction state, not an error.  A CI-style gate should treat exit 0
as "decisions survive regeneration" and anything else as "read the report".

## What counts as a decision

Only deliberate checkpoint artifacts are read:

- Markdown documents matching `ORISON_*CHECKPOINT*.md` under `--checkpoints`
  (recursively).  Within them, only tables that have a `Verdict` column.
  Recognized verdicts: KEEP, MOVE, REPAIR, REPLACE, REMOVE, ADD, KEEP ABSENT.
- Machine-readable manifests matching `*.decisions.json` (see below).

Everything else — prose bullets, walkthrough notes, mentions of an object in
any other file — is never treated as a decision.  A checkpoint with no
verdict table (e.g. the F01 service-circulation checkpoint) is listed in the
report as prose-only with zero decisions, not guessed at.

Object references are taken **only** from backticked tokens in the element
cell:

- `` `exact_id` `` — literal id;
- `` `stem0..3` `` — documented numeric-range shorthand, expanded to
  `stem0`…`stem3` (each expansion becomes its own decision);
- `` `family_*` `` — glob, matched against layout ids with fnmatch;
- `` `old_id` -> `new_id` `` in a REPLACE row — old object plus its named
  replacement.  A REPLACE without this arrow (or a manifest `replacement`) is
  UNVERIFIABLE, because prose cannot say which object is the replacement.

A row whose element cell has no backticked id ("walls, floor, ceiling and
trim") becomes one UNVERIFIABLE decision — recorded, quoted, never guessed.
A token that names an assembly/marker *kind* rather than a record id (e.g.
`arcade_cab`) is detected against the layout's kind census and reported as
such instead of being classified.

Room association is conservative: a table's `Room` column is matched only
against room ids the same document names; a 3-column table inherits the
document's room only when the document names exactly one.  Anything else is
"room unresolved" — existence is still checked, room membership is not.

## Decision semantics

Statuses: **SATISFIED**, **OPEN**, **CONTRADICTED**, **UNVERIFIABLE**, plus a
separate **MALFORMED** row list.  SATISFIED means only that the layout JSON
does not contradict the decision's checkable facts — never that the room is
visually, historically or interactively correct.

- **KEEP** — satisfied when the exact id exists exactly once and, where the
  room is known, sits in that room (containing-rect, door adjacency, or
  within 0.10 m of the room rect).  Contradicted when absent, duplicated or
  assigned to a different room.  An object that exists but sits outside
  *every* declared room rect (facade/site dressing like `entry_marquee`) is
  UNVERIFIABLE: rectangles cannot decide its ownership.
- **REMOVE / KEEP ABSENT** — satisfied when nothing matches (globs included);
  contradicted when any match still exists anywhere in the layout.  After a
  satisfied REMOVE, ids sharing the stem are flagged as *possible* renamed
  equivalents — flagged only, never inferred to be the same object.
- **MOVE** — checkable only via explicit expected properties (manifest
  `expected.position` / `room` / `yaw_deg` with tolerances; defaults 0.05 m,
  1.0°).  A table's Room column is context, not a target, so a prose MOVE is
  UNVERIFIABLE.  Vanished object → contradicted.
- **REPAIR** — satisfied only for explicitly supplied checkable properties;
  otherwise UNVERIFIABLE pending Blender/Godot/visual evidence.
- **REPLACE** — old absent + replacement present (and matching declared
  properties) = satisfied; old present + replacement absent = OPEN (not
  started); both absent = OPEN, flagged half-complete; both present =
  CONTRADICTED.
- **ADD** — named id present with declared room/properties = satisfied;
  absent = OPEN; no stable id = UNVERIFIABLE.

Absent literal ids are triaged before being called contradicted: a token
whose prefix matches real ids (`lobby_runner` vs `lobby_runner_rug`) is
UNVERIFIABLE "imprecise id"; a token found in `game/scripts/**/*.gd` or
`game/data/*.json` (excluding the layout itself) is UNVERIFIABLE
"runtime GDScript prop" and listed under runtime-only dependencies.

**Conflicts** group verdicts into outcome classes — REMOVE / KEEP ABSENT /
REPLACE assert the id's absence; KEEP / ADD / MOVE / REPAIR assert presence.
Two checkpoints in the same class (e.g. door KEEPs repeated per room) are
compatible duplicates; presence vs absence on one id is a conflict, both rows
are flagged, and neither is treated as authoritative.

Git provenance (skippable with `--no-git`) records each checkpoint's last
commit and how many times the layout has been regenerated since — a
staleness hint, not a classification input.  An untracked checkpoint is
flagged "base commit unknown".

## The decisions manifest (forward format)

For decisions richer than prose tables can carry, add a sidecar
`<anything>.decisions.json` next to the checkpoints:

```json
{
  "version": 1,
  "base_commit": "abc1234",
  "decisions": [
    {"room": "F01_LOBBY", "object": "lobby_bench_w", "verdict": "MOVE",
     "expected": {"room": "F01_LOBBY", "position": [-4.1, -9.2],
                  "tolerance_m": 0.05, "yaw_deg": 0, "yaw_tolerance_deg": 2},
     "rationale": "against the south wall, clear of the runner"},
    {"room": "F01_LOBBY", "object": "LobbyPorterBoard", "verdict": "REPAIR",
     "scope": "runtime", "rationale": "faces the lobby after the yaw fix"}
  ]
}
```

`scope: "runtime"` marks decisions the layout can never verify (they classify
as UNVERIFIABLE and are listed as runtime dependencies).  `replacement` names
a REPLACE target.  Existing checkpoint prose is **not** rewritten to this
format; the report's per-document extraction section (tables found, rows
parsed, decisions, malformed) is the conservative migration aid — a document
that parses poorly shows up there, and future checkpoints can add a manifest
alongside their prose.

## Report contents

Summary counts; per-document extraction and provenance; status tables grouped
by room with exact `path:line` and quoted source for every decision; current
vs expected facts; classification reasons; flags (imprecise ids, runtime
dependencies, kind-tokens, undeclared rooms, outside-all-rooms); conflicts
and compatible duplicates; malformed rows; runtime-only dependency list; and
a **next reconstruction actions** section restricted to open or contradicted
decisions — no new design advice.

## Known parser limitations

- Prose-only checkpoints yield zero decisions (by design); their room
  verdicts live only in sentences the parser will not guess at.
- Element cells that describe objects without backticked ids ("desk and
  chair", "toilet") are UNVERIFIABLE even when a human could name the id.
- A backticked descriptive token that happens to equal an assembly kind is
  reported as a kind-token, not resolved to the objects of that kind.
- Multi-id REPLACE rows without the `->` arrow cannot bind old to new.
- Room-name cells resolve only against rooms the same document names.
- The runtime-evidence scan is substring-based: it proves an identifier
  appears in runtime sources, not that the prop is correctly built.

## Relationship to the workbench

The reconciler reuses `room_layout_workbench` record interpretation, door
adjacency and geometry helpers, so both tools agree on what an object is and
where it sits.  Suggested loop: checkpoint a room → regenerate → run the
reconciler (gate on exit 0) → for anything contradicted, open the room's
workbench plan to see the geometry before touching `gen_layout.py` again.

## Tests

```
python tools/tests/test_room_checkpoint_reconciler.py
```

38 tests over synthetic fixtures (`tools/tests/fixtures/checkpoints_*` plus
the mini layout): all six verdicts, KEEP ABSENT, range/glob/arrow parsing,
tolerance pass/fail, reappearing removals, vanished keeps, duplicate layout
ids, ownership drift, half-complete and both-present replacements,
presence-vs-absence conflicts vs compatible duplicates, malformed rows with
line numbers, no-id and no-target decisions producing UNVERIFIABLE (never a
guess), kind-token detection, runtime-evidence and prefix-match triage,
outside-all-rooms softening, byte-identical determinism, no-overwrite /
`--force`, empty-directory behavior, non-checkpoint markdown being ignored,
and the 0/1/3/4/5/70 exit contract.
