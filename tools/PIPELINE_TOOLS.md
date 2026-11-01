# Pipeline tools

These instruments turn the dispatch-and-verify loop from typed claims
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
| `preflight_spatial_test_bindings.py` | Are every spatial receipt's inherited test dependencies declared before Godot starts? | <1 s |
| `publish_v2_spatial_packet.py` | Publish already executed played-room proof with checked sources/logs and a preserved previous packet? | source-size dependent |

## Played-room packet publication

After a completed windowed spatial run, use **publish_v2_spatial_packet.py** with
**--packet**, **--receipt**, **--destination** and **--archive**. The destination
must be a named packet under **art/renders/orison_v2**; the fresh archive belongs
under **art/reviews**. The tool validates source-bound room witnesses, additional
typed connection/region claims, matching wrapper provenance and original raw-log
hashes before publication. It copies the original contract and wrapper bytes,
compresses unchanged log bytes and installs the contract last. It cannot create
or repin a runtime receipt. Failed runs and changed sources are refused.

An archive is tied to one incoming contract. Retrying the same publication is
safe; a subsequent new run needs a fresh archive. Optional **--images** accepts
plain PNG/JPEG/WebP filenames from that capture directory. These remain capture
records, not human appearance or gameplay acceptance. First-slice authority
contracts use their separate authority validator; this publisher covers played
room, connection and regional access only.

## Gate board

Owner preference, 2026-10-26: automated checks must not interfere with the
owner's mouse. Use headless checks where valid. A windowed scene that requests
capture, confinement or cursor warping must wait until it can run without
interfering, or the owner explicitly makes room for that input check. Do not
substitute headless or noncapturing diagnostics for required windowed
grab/motion/release evidence. A private desktop on the same Windows window
station is insufficient: the capture probe changed the active cursor clip
rectangle. Merely hiding, minimizing or unfocusing a window is not a capture
isolation guarantee. Noncapturing optical benches remain usable; inspect their
actual startup/teardown paths, since even closing a reading panel may capture
the cursor. Keep every Godot launch inside the existing shared-lane wrappers.

Before long spatial-contract runs, use
`python tools/preflight_spatial_test_bindings.py --all`, or pass individual
receipt-writing scripts under **game/tests**. This read-only check follows
transitive test references and rejects missing files or omitted **SOURCES**
bindings before Godot starts. It does not generate or qualify runtime evidence.

RUL-012 adds three surface gates: **v2_surface_imports** checks complete
mipmap/HQ GPU-compression bindings, **v2_mesh_uv_imports** keeps the seven
measured UV-precision overrides, and **v2_surface_qualification** requires a
current composed inventory, test-written runtime contract and reviewed image
hashes. New rendering inputs invalidate the qualification; a red baseline
cannot waive it. See **design/V2_SURFACE_REQUIREMENTS_2026-10-11.md**.

Run **OrisonV2SurfaceInventory.tscn** windowed through the serial runner with
**SHOT_DIR** set to the review directory. It checks the whole loaded world and
takes the close-up/room images in one process. Evaluate an inventory alone
with **python tools/audit_v2_surfaces.py --inventory <file> --out <report>**.
The independent saved-packet gate is **python tools/v2_surface_evidence.py**.
For a combined physical renewal and city-geometry diagnostic in one composed
world, set **ORISON_SURFACE_PHYSICAL_ONLY=1** and **ORISON_SURFACE_CITY_REVIEW=1**;
leave city-only/fire-only off. The schema-2 contract records the additional city
diagnostic's checks/failures separately. Physical coverage remains exhaustive;
this does not run or accept the skipped interaction/save programmes. Use the
existing city-only mode for iteration when no physical renewal is needed.
Before either city mode, run **python tools/city_elevation_probe_fixture.py --check**
to reject stale native wall targets without composing the world. These targets
check source correspondence; they do not establish architectural or artistic approval.


Both lane runners accept **ExtraArgs**, and the long runner accepts an empty
scene for imports. In PowerShell invoke the script directly with **&** when
passing an argument array; a nested **pwsh -File** does not preserve the array
as one parameter. For example:

```powershell
& tools/lane.ps1 run -Runner long -ExtraArgs @('--import') -LogPath tmp/import.log
& tools/lane.ps1 run -ExtraArgs @('--headless','--editor','--quit') -LogPath tmp/import-refresh.log
```

```
python tools/gate_board.py --out C:/ov/boards/main          # a board for main
python tools/gate_board.py --out <dir> --baseline C:/ov/boards/main/board.json
python tools/gate_board.py --compare-only old/board.json new/board.json
python tools/gate_board.py --only ledger --only reader --no-tests
```

Repeat **--only** for each requested id; **--only test** selects the tools-test
family. An unknown selection, including a comma-separated list, exits3 before
running gates or writing a board. Inspect actual rows, not just the process exit.

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
    [--windowed-long-suite res://tests/W.tscn ...]
    [--report reports/<task>.json] [--no-godot] [--keep]
    [--in-place --baseline-board <clean-merge-base-board.json>]
    [--accept-regression "blockers.FIRST_SLICE_TECHNICAL"]
```

Suites whose contract involves the pointer, mouse capture, the pause menu
or screenshots must be passed as `--windowed-suite`: headless Godot cannot
capture a mouse, so `Input.mouse_mode` stays VISIBLE however the suite sets
it and those checks fail for the harness's reason, not the code's.
For a suite that also legitimately exceeds 180 seconds, such as the
connected world's two complete room-switch passes, use
`--windowed-long-suite`. It retains the same lane and receipt contract and
uses the long runner's 1,500-second ceiling.

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

## Publishing a completed surface review

**python tools/publish_v2_surface_packet.py --packet <capture-dir> --archive <review-dir>**
publishes a packet that already passes **v2_surface_evidence.py**, including its
test-written contract, wrapper, raw compressed logs and reviewed image hashes.
It preserves the preceding packet, validates its inventory/log/image bindings,
and stages atomic file replacements with the contract installed last. Both the
source and published packet must qualify. Windows sharing failures receive a
bounded retry; failed staging leaves the prior target file intact.

A publication failure alone does not justify another Godot run. Reuse the
completed capture while its bound rendering inputs remain unchanged. This tool
does not author, promote or repin runtime evidence.

## Physical service input binding

**python tools/v2_physical_inputs.py [--json]** records authored mesh triangle
positions, winding, morph positions, node frames, material slot names and mesh
import parameters. Identical expanded triangles survive vertex repacking for
new UVs or normals. Texture pixels are qualified separately by the surface
packet. Animated, compressed and unsupported geometry is conservatively hashed
in full, including local buffers. The output is input provenance, not proof of
play or appearance acceptance.

First-slice receipts containing **physical_service_round** must bind this
digest as well as their root test and production code/data. The test measures
all three before and after execution; the ledger independently rechecks them.
A geometry edit invalidates the old physical pass, including same-size edits
with restored timestamps. Reuse a gameplay run after an optical-only change
only while its physical and production input bindings remain current.

## Local image generation

`art/tools/imagegen.py` runs SDXL base 1.0 on this machine's RTX 4080. Every agent
may use it; nothing is uploaded and there is no per-image cost.

- **Run it with any Python.** It re-launches itself in the environment at
  `C:/devkit/imagegen` (venv and model cache, outside the repository).
- **One image or a batch.** `--prompt "..." --out <dir> --seeds 4`, or `--batch
  jobs.json --out <dir>`. Finished images are skipped, so a stopped batch resumes.
- **Provenance.** Each PNG gets a JSON sidecar with its prompt, seed and model.
- **It is a lane task.** Each slice of 24 images takes the Godot lane through
  `tools/lane.ps1` (a batch entry with `"gpu"`), so it queues with Godot runs and
  never shares video memory with one. `lane.ps1 status` shows it as `lane/gpu`.
  The queue is first come, first served, so a batch goes to the back after every slice. Logs land in `<out>/logs`.
- **Results are drafts.** Look at each one. SDXL invents lettering; RUL-008 still
  forbids it. Reference photographs stay out (RUL-007).
- **Rebuilding the environment.** `uv venv --python 3.12 C:/devkit/imagegen/venv`,
  install `torch` from the PyTorch cu124 index, then `diffusers transformers
  accelerate safetensors sentencepiece pillow huggingface_hub`. Download the model
  with `HF_HOME=C:/devkit/imagegen/hf`, fp16 files only.

## The lane queue

`tools/lane.ps1` is first come, first served. A waiting broker writes a record under
`%LOCALAPPDATA%/Orison/waiters`, and only the oldest live record asks for the mutex.
A record whose process is gone, or started after the record was stamped, does not
count. A runner started directly exits 73 while anyone is queued. The mutex and the
Godot census still decide ownership; the queue only decides whose turn it is. A
broker running an older copy of the script ignores the queue until its checkout
has this change. `tools/tests/test_lane_queue.py` races real brokers on a private
mutex.
