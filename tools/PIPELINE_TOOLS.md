# Pipeline tools

Seven instruments that turn the dispatch-and-verify loop from typed claims
into files. Each one reads, runs through the existing lane, or writes
into a directory you name. None merges or pushes. The candidate verifier's
default mode creates and removes temporary worktrees; use its in-place mode
for work restricted to the canonical checkout.

| tool | answers | typical time |
|---|---|---:|
| `gate_board.py` | Did any static gate or tools test get worse? | 25 s |
| `run_receipt.py` (called by the runners) | What exactly did this Godot run do, against which tree? | automatic |
| `verify_candidate.py` | Is this commit a merge candidate, checked the way management checks? | 2-4 min, more with Godot suites |
| `lint_design_doc.py` | Does this design document say what the ledger will treat it as? | 1 s |
| `lane.ps1` | Who holds the Godot lane, and can I wait for it instead of failing? | - |
| `lanes.py` | Where does every worktree and branch stand against main? | 6 s |
| `check_rulings.py` | Is every RUL-nnn citation real, sourced and current? | 1 s |

## Gate board

```
python tools/gate_board.py --out C:/ov/boards/main          # a board for main
python tools/gate_board.py --out <dir> --baseline C:/ov/boards/main/board.json
python tools/gate_board.py --compare-only old/board.json new/board.json
python tools/gate_board.py --only ledger --only reader --no-tests
```

Gates: ledger, spatial, systemic, period, reader, carriers, rulings and every
`tools/tests/test_*.py`. Each row keeps the gate's real exit code, a
severity (PASS, INCOMPLETE, FAIL, ERROR) and the named defects behind its
counts. With `--baseline` the exit is 1 on any regression: severity rose, a
defect count rose, a named defect appeared, a ledger requirement fell or
vanished, or a test file ran fewer tests. main's known reds (ledger
INCOMPLETE, the two clock "Hold E" prompts) are not regressions while they
stay the same.

The reader gate compares by name whether or not a tree has the frozen
baseline `tools/data_consumption_baseline.json`. It holds 1,308 known findings
(2026-09-19: 1,302 at 6b5dc29, plus seven trivia-deck fields made visible when
the file became strict JSON, minus its MALFORMED entry). It is debt, not
permission.

## Run receipts

Both Godot runners write `<LogPath>.receipt.json` after any launched run:
completed, exit code, timed out, elapsed, commit, tree, dirty paths, the
scene's root test script and its SHA-256, the runtime-inputs digest (the
ledger's own algorithm), log hashes, PASS and FAIL lines, and a stale-cache
flag. Refusals (73) write none, because nothing ran.

```
python tools/run_receipt.py verify <log>.receipt.json   # BINDS / STALE / MALFORMED
python tools/run_receipt.py digest                      # the runtime-inputs digest
```

`evidence_kind` is `suite_run`. A test that writes its own schema-2
`runtime_contract` receipt may copy the `execution` and `source` blocks
verbatim; the wrapper never grants runtime proof.

## Candidate verifier

```
python tools/verify_candidate.py <sha|branch> [--base origin/main]
    [--suite res://tests/X.tscn ...] [--long-suite res://tests/Y.tscn ...]
    [--windowed-suite res://tests/Z.tscn ...]
    [--report reports/<task>.json] [--no-godot] [--keep]
    [--in-place --baseline-board <clean-merge-base-board.json>]
    [--accept-regression "blockers.FIRST_SLICE_TECHNICAL"]
```

Suites whose contract involves the pointer, mouse capture, the pause menu
or screenshots must be passed as `--windowed-suite`: headless Godot cannot
capture a mouse, so `Input.mouse_mode` stays VISIBLE however the suite sets
it and those checks fail for the harness's reason, not the code's.

Checks, in order: fresh checkout clean under the machine's autocrlf; this
tree's gate board in candidate and merge-base, compared; changed gate files
flagged for review; changed design documents linted; 17 protected paths and
selector V2; optional Godot imports and suites through this tree's runners
with receipt verification; optional report sidecar compared claim by claim.
Output goes to `C:/ov/reports/<sha12>/verification.{md,json}`. The last line
is `MERGE-CANDIDATE <sha>` or `BLOCKED <reasons>`. `--accept-regression`
records an owner-ruled recount, such as a gate hardening, instead of
blocking on it.

For development restricted to the canonical checkout, capture a full board
before editing, then commit and run with `--in-place --baseline-board <path>`.
The candidate must be the clean current HEAD; the baseline must name the
merge-base commit and tree, have no dirty paths, use the current board version,
and include every static gate and tools test present at that commit. This mode
never creates, switches or removes a checkout, and reports that fresh-checkout
autocrlf behavior was not verified. Give `--out` an ignored directory under the
canonical checkout, for example `tmp/v2-cutover/verification`.

The owner authorized the V1-to-V2 default on 2026-09-21. The verifier permits
only that exact selector literal change while retaining the historical
17-path receipt. It reports 16 unchanged paths plus one authorized change at
cutover, and rejects any other selector or protected-path edit. The V1 scene
remains available through `ORISON_BUILDING_ROOT=v1`; neither selector choice
is persisted into saves.

### Report sidecar (`orison.dispatch-report.v1`)

A developer may commit this beside the prose report, for example at
`reports/<task-id>.json`. Every key is optional; each one present is checked.

```json
{
  "schema": "orison.dispatch-report.v1",
  "task": "ORISON-V2-M12A",
  "head": "<40-char candidate sha>",
  "merge_base": "<40-char sha>",
  "selector": "v2",
  "protected": "17/17",
  "ledger_before": {"FIRST_SLICE_TECHNICAL": 7, "GOLDEN_SHIFT_V2": 8,
                    "FULL_BUILDING_STRUCTURAL": 84, "FULL_BUILDING_RUNTIME": 52,
                    "PRODUCTION_CUTOVER": 107, "V1_RETIREMENT": 109},
  "ledger_after": {"...": "same six scopes"},
  "requirements_changed": [],
  "gates": {"ledger": 2, "spatial": 0, "reader": 0, "test:test_orison_v2_completeness": 0},
  "suites": {"res://tests/OrisonV2BlockoutTest.tscn": 0},
  "last_line": "MERGE-CANDIDATE <sha>"
}
```

A sidecar cannot name the commit that contains it. When the sidecar is
changed in the candidate commit itself, the verifier also accepts that
commit's parent as `head` and in `last_line`.

## Design-doc lint

```
python tools/lint_design_doc.py design/FOO.md
python tools/lint_design_doc.py --staged
python tools/lint_design_doc.py --changed-since origin/main
python tools/lint_design_doc.py --print-hook     # opt-in pre-commit body
```

ERROR when the `Evidence class:` header and the filename disagree about
whether the ledger admits the document. WARN on a missing or unclassified
header, and on id-like backticks in an inert document. For evidence
documents it prints the ledger's `--evidence-impact`.

## Lane broker

```
pwsh -File tools/lane.ps1 status
pwsh -File tools/lane.ps1 run -Scene res://tests/X.tscn -LogPath C:/ov/logs/x.log -WaitMinutes 20
pwsh -File tools/lane.ps1 batch -BatchFile runs.json -WaitMinutes 30
```

`status` names the holder, each Godot process with its command line, and
each waiter. `run` and `batch` wait for the mutex and an empty process
census, then call the ordinary runners in the owning thread, so the lane is
held across a batch and every run keeps its receipt. 73 if the lane stays
busy past the deadline.

## Lane ledger

```
python tools/lanes.py [--ledger] [--fetch] [--out C:/ov/lanes]
```

Every worktree and origin branch with ahead/behind main, merged, dirty count,
last commit and a disposition: merged-clean (removable), merged-dirty,
unmerged-active, unmerged-stale, missing. `--ledger` adds each worktree's own
blocker counts. It suggests; it never removes.

## Rulings

`design/RULINGS.json` is an append-only index of standing rulings with their
sources. Cite `RUL-nnn` in briefs, critiques and reviews instead of restating
the rule.

```
python tools/check_rulings.py
python tools/check_rulings.py --show RUL-006
```
