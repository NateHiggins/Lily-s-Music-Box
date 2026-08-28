# Room reconstruction progress ledger — usage and interpretation

`tools/room_reconstruction_progress.py` is the roll-up above the four
room tools: one deterministic answer to "how far along is each floor, which
rooms have profiles and checkpoints, which decisions survived regeneration,
and what is the next evidence task?"

**It is a progress ledger, not a completion authority.**  No state it emits
means a room is finished.  Completion requires visual, architectural,
interaction and route evidence (proof shots, WalkTest, live tests) that no
static aggregation can supply — which is why the strongest per-room headline
is *"layout drift green; manual/runtime evidence remains."*  There is
deliberately no COMPLETE state.

## Commands

```
python tools/room_reconstruction_progress.py --output <dir>
python tools/room_reconstruction_progress.py \
    --layout art/data/building_layout.json --checkpoints design \
    --output <dir> [--floor F01] [--room F01_COMMON_B] \
    [--json-only | --markdown-only] [--force] [--no-git]
```

Writes `room_reconstruction_progress.json` and `.md` into the explicit
output directory; refuses to overwrite without `--force` (exit 3).  Output is
deterministic; `--no-git` removes the provenance lookups so bytes depend only
on the layout and the checkpoint corpus.  Run it after every room checkpoint
and after every regeneration — it takes ~5 s over the whole building.

## What it consumes (and does not replace)

| Source | Contribution |
|---|---|
| `audit_orison_rooms.py` | spatial-census candidates, mapped to rooms via door adjacency and wall-endpoint proximity; outside-any-room records stay floor-level |
| `room_layout_workbench.py` | object inventory, per-room views (packet generatability, unknown footprints, ambiguous ownership, boundary crossers), room-profile discovery |
| `room_checkpoint_reconciler.py` | decision statuses, conflicts, duplicates, malformed rows, git provenance |
| `room_checkpoint_linter.py` | machine-checkability of every checkpoint row |

The ledger re-runs those tools; it never reimplements their semantics, and
reading the ledger never substitutes for reading a contradiction's detail in
the reconciler report or a row's lint diagnosis.

## How each state is derived

- **PROFILED / UNPROFILED** — a `## Room profile` section naming the room
  exists in a markdown file under `--checkpoints` (design/ in production).
- **AUDIT_PENDING** — spatial-census candidates touch the room and no
  structured checkpoint covers it yet.  Candidates are questions, not
  defects.
- **CHECKPOINT_PROSE_ONLY** — a checkpoint names the room but carries no
  verdict table or manifest; its verdicts are not machine-checkable.
- **CHECKPOINT_STRUCTURED** — parsed decisions (verdict-table or
  manifest-backed) exist for the room.
- **DRIFT_GREEN / DRIFT_RED** — no structured decision contradicted and no
  cross-checkpoint conflict / at least one of either.
- **MANUAL_EVIDENCE_REQUIRED** — UNVERIFIABLE decisions remain (runtime
  props, prose rows, `[manual]`/`[visual]` declarations).  Green drift plus
  this state is the normal, honest end-state of a checkpointed room until a
  human collects the evidence.
- **MALFORMED** — a covering checkpoint has rows the parser rejected.

Rooms may carry several states.  Validation evidence cited by a checkpoint
(`## Validation` bullets) is quoted with a recorded result only when the
document explicitly states PASS/FAIL/exit 0 — a citation is never assumed to
have passed.

## Floor roll-up and plan sequence

The floor table shows rooms / profiled / checkpointed / structured, decision
totals, census candidates, manual-evidence debt and layout regenerations
since the newest room checkpoint.  `Seq` is the reconstruction order
transcribed from `design/ORISON_ROOM_RECONSTRUCTION_PLAN_2026-08-27.md`
(1 F01 opening route, 2 F04 player route, 3 F02, 4 services B1/ROOF, 5 the
rest); if the plan changes, update `PLAN_SEQUENCE` in the tool.

## The next-action queue

Evidence-only and deterministic; it never recommends moving, adding or
removing production objects.  Ranking (each queued action names its source):

1. contradictions or conflicts → resolve contradicted decisions;
2. malformed records → fix the rows;
3. structured checkpoints with unknown regeneration status → rerun
   reconciliation;
4. prose-only checkpoints → add a verdict table or manifest;
5. unresolved machine-checkability (lint) and manual/runtime evidence debt;
6. profiled but uncheckpointed rooms → create a checkpoint;
7. unprofiled rooms on the plan's current floor → write profiles;
8. later-floor work.

## Corpus interpretation rules

- Checkpoints covering multiple rooms attribute each decision to its
  resolved room; the shared document is listed under every covered room.
- Abbreviated Room labels ("1A main") resolve only when every word matches
  layout evidence (unit, id component, or room kind) with exactly one
  surviving candidate; "Both flats"-style labels stay unresolved and are
  listed under *decisions with unresolved room mapping* with their exact
  source lines.
- Doors shared by adjacent rooms count for each room they serve (the
  reconciler's adjacency, cabinet leaves excluded).
- Objects outside every declared room remain floor-level census facts;
  runtime-created props and id-less architectural rows appear as
  manual/runtime evidence debt, never as room completion.
- Repeated compatible decisions across checkpoints are listed as duplicates,
  not conflicts; presence-vs-absence disagreements are conflicts and turn
  the room DRIFT_RED.
- Rooms whose built extent exceeds their declared rectangle (see the F01
  common-room checkpoint) cannot be detected statically; their extra legs
  surface only as outside-any-room records.

## Why manual/runtime evidence stays outside static proof

Layout JSON proves placement records, not builds: runtime GDScript props are
invisible to it, meshes can clip where AABBs are clear, and "reads as one
modest occupied room" is a camera judgment.  The ledger therefore carries
manual/runtime debt forward visibly instead of laundering it into green.

## Exit codes (stable, tested)

0 clean aggregation (OPEN/UNVERIFIABLE/partial coverage do not fail);
1 contradiction or conflict; 3 overwrite refusal; 4 malformed checkpoint
data; 5 both 1 and 4; 2 usage error; 70 internal failure.

## Tests

```
python tools/tests/test_room_reconstruction_progress.py
```

24 tests over synthetic fixtures: untouched floor, changed room count,
profiled-but-uncheckpointed, prose-only coverage, structured green,
contradicted (exit 1, rank-1 action first), malformed (exit 4), combined
(exit 5), runtime/manual-only evidence, multi-room checkpoints, unknown room
references, compatible duplicates, abbreviated-label resolution (and its
refusal for weak prose), byte-identical determinism, floor/room filters,
json/markdown-only modes, no-overwrite/`--force`, no-git operation, missing
checkpoint directory, and internal-failure exit 70.
