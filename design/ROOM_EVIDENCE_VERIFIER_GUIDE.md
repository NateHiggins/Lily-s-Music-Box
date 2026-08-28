# Room evidence verifier — usage and interpretation

`tools/room_evidence_verifier.py` verifies that the proof a checkpoint cites
actually resolves: the cited artifacts exist, and what they *record* matches
what the checkpoint *claims*.  It runs nothing — no Godot, no Blender, no
tests, no captures — and it never edits historical receipts, logs, render
evidence or checkpoints.  Statuses report what an artifact records, never
what reality "is": a PNG that exists proves a PNG exists; a receipt that
records PASS proves a receipt records PASS.  No result here makes a room
COMPLETE.

Receipt semantics follow `game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`; this tool
implements that contract rather than inventing a competing one.

## Commands

```
python tools/room_evidence_verifier.py --checkpoints design --output <dir>
python tools/room_evidence_verifier.py --checkpoint design/ORISON_X_CHECKPOINT.md --output <dir>
... [--floor F01] [--room F01_COMMON_B] [--json-only | --markdown-only]
    [--force] [--no-git] [--scaffold] [--repository-root .] [--layout <json>]
```

Writes `room_evidence_status.json` and `.md` into the explicit output
directory; refuses overwrite without `--force` (exit 3).  Output is
deterministic; `--no-git` removes provenance lookups entirely.

## What counts as a citation

Only evidence/validation sections of `ORISON_*CHECKPOINT*.md` documents
(headings containing *validation*, *evidence* or *proof*) and
`*.evidence.json` manifests.  Within a section, each bullet or paragraph is
one claim; recognized citations are backticked repository paths, quoted
render directories, receipt/log/metrics/image basenames, CamelCase scene or
test names, commit SHAs, and result tokens (PASS / FAIL / exit 0) plus
explicit frame-count ("four … frames", "seven-view") and resolution
(1280×720) claims.  A result line with no citation at all is preserved as an
*assertion* (SYMBOLIC_ONLY).  Paths are never guessed from vague titles; a
basename matching several artifacts is AMBIGUOUS with the candidates listed.

## Supported artifact semantics

| Artifact | Verdict source |
|---|---|
| `scene_capture_receipt.json` (v1) | `status`, expected/actual frames, capture list; referenced outputs must exist |
| `capture_receipt.json` (v1, wrapper) | `status`, engine exit, frames, files, resolution |
| `shot_metrics.json` (v1) | `status`, recorded `failures`, frame references; thresholds recorded *by the artifact* are reported separately from thresholds merely asserted by prose |
| `walk_fast.log` | `WALKTEST RESULT: PASS\|FAIL` |
| ShotHarness `godot.log` | `[TAG] RESULT: PASS\|FAIL captures=N expected=M` |
| `lighting_audit.log` | `LIGHTING AUDIT: … PASS\|FAIL` |
| unittest `*.log` | final `OK` / `FAILED` |
| `*.png` | existence + IHDR dimensions via stdlib parsing — never composition, clearance or visual quality |
| directories | existence + PNG/receipt/log inventory; a non-empty directory without a receipt is present evidence, not a recorded pass |

Unknown receipt schemas and unrecognized log dialects are UNSUPPORTED —
never reinterpreted.  A log with both pass and fail verdict lines is
AMBIGUOUS.  **Absence of a failure line is never a pass**: a verdict-less
log is VERIFIED_PRESENT with that note, and a checkpoint claiming PASS over
such an artifact keeps an "unverified claim" note rather than a mismatch.

## Symbolic-name linkage

`WalkTest`, `LightingAudit` and `*Shot` names are symbolic.  A durable
artifact is *attached* when it is cited on the same line, or when exactly
one artifact of the matching kind (`walk_fast.log`, `lighting_audit.log`,
receipt-or-`godot.log` respectively) exists inside a directory the same
checkpoint cites — the linkage is recorded in a note.  Several candidates
leave the citation SYMBOLIC_ONLY rather than choosing.  Names with no
matching artifact kind (`DoorCheckTest`, live tests) stay SYMBOLIC_ONLY:
their runs left no durable receipt.

## Metadata cross-checks

METADATA_MISMATCH is raised when an artifact exists but records facts that
contradict the claim: expected vs actual frame counts inside a receipt or
harness log, checkpoint frame-count or resolution claims vs the receipt,
receipt- or metrics-referenced outputs that are gone, directory PNG counts
vs a claimed count, a manifest `expected_scene` not matching the receipt, or
a claimed commit that does not resolve.  With git enabled, each artifact's
last-modifying commit is reported and compared with claimed commits,
distinguishing "artifact predates the claimed commit" from an actual
mismatch — the current HEAD is never assumed to be the build that produced
historical evidence.

## Exit codes (stable, tested)

0 no MISSING / RECORDED_FAIL / METADATA_MISMATCH / MALFORMED; 1 any of the
first three; 3 overwrite refusal; 4 malformed evidence record; 5 both;
2 usage error; 70 internal failure.  SYMBOLIC_ONLY, UNSUPPORTED, UNREADABLE
and declared-manual claims stay visible without failing the run.

## Evidence manifests (optional forward format)

`<name>.evidence.json` beside the checkpoints:

```json
{"version": 1, "claims": [
  {"claim_id": "C01", "rooms": ["F01_LOBBY"],
   "artifact": "art/renders/.../scene_capture_receipt.json",
   "artifact_kind": "path", "expected_schema": "scene_capture_receipt.json",
   "expected_scene": "F01ArrivalRoomShot", "expected_commit": "abc1234",
   "expected_output_count": 5, "claimed_recorded_result": "PASS",
   "manual_visual_proof_required": false}]}
```

`manual_visual_proof_required: true` declares a claim outside artifact
verification.  A claim with neither artifact nor manual declaration is
MALFORMED.  `--scaffold` generates `<checkpoint>.evidence.json.proposed`
files into the output directory only, clearly marked unapproved.

## Ledger integration

```
python tools/room_evidence_verifier.py --output <dir>
python tools/room_reconstruction_progress.py --output <dir2> \
    --evidence-report <dir>/room_evidence_status.json
```

With the report, rooms the verifier maps explicitly gain an `evidence`
block and states: EVIDENCE_PRESENT, RECORDED_VALIDATION_PASS,
RECORDED_VALIDATION_FAIL, EVIDENCE_MISSING, SYMBOLIC_VALIDATION_ONLY,
EVIDENCE_MISMATCH.  Without `--evidence-report` the ledger's output is
byte-identical to before.  The ledger still has no COMPLETE state, and the
integration converts "cited" into "recorded" — never into visual proof.

## What remains outside verification

Human full-size frame inspection, composition, clearance, historical
accuracy, interaction feel, and every live test that leaves no durable
receipt (`DoorCheckTest`, `MaintenanceChuteLiveTest`, …).  The report's
"remains manual or visual" section lists exactly these, per checkpoint and
line.

## Tests

```
python tools/tests/test_room_evidence_verifier.py
```

34 tests over synthetic evidence trees: exact/missing paths, ambiguous
basenames, receipts recording pass and fail, unknown schemas, missing
receipt outputs, frame-count and resolution mismatches, commit mismatch via
real git, PASS/FAIL/mixed/verdict-less logs in all four dialects, PNG
dimension parsing and unreadable images, directory-only evidence, rooms
sharing artifacts, manifest claims (verified, missing, manual, malformed),
deterministic byte-identical output, room/checkpoint filters, scaffold
marking, no-overwrite/`--force`, no-git operation, ledger integration and
its absence, and the 0/1/3/4/5/70 exit contract.
