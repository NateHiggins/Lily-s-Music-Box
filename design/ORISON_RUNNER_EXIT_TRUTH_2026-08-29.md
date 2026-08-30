# The serial runner says what actually happened — 2026-08-29

**Task:** DEV-RUNNER-1. **Lane:** tools only. **Base:** **4aa97fa**, the
tip of origin/main. **Changed:** `tools/run_godot_serial.ps1` and this
document. No production script, layout, scene, checkpoint, evidence
packet, baseline or manifest was touched.

## The defect

`-TimeoutSeconds` was `[ValidateRange(1, 60)]`, and **every** runner-level
refusal returned 73 — lane conflict, timeout kill, missing Godot binary,
unusable exit code, all one number. Two committed suites cost more than
60 seconds, so both were killed and both reported 73. The honest reading
of a red 73 is "another agent holds the lane, wait and retry", and for
those two suites that retry could never succeed: nothing was contended,
the ceiling was simply too low to express what they cost. This is the
same class of defect the runner already carried once, when its exit code
was structurally `$null` and every failing suite reported success — one
signal standing for two different facts.

## What 73 had to keep meaning

Grepping the repo for 73 before choosing found four sites, all in tools:

| Site | Use |
| --- | --- |
| `tools/run_godot_serial.ps1:93` | the single catch-all this task splits |
| `tools/run_godot_capture.ps1:62` | **its own** preflight `exit 73` when the process census finds Godot running — unambiguously *lane busy* |
| `tools/run_godot_capture.ps1:93` | comment: "Exit 73 means the lane is occupied or the ceiling fired" |
| `tools/run_godot_capture.ps1:132` | `$status = if ($engineExit -eq 73) { "BUSY_OR_TIMEOUT" }` |

The capture tool's own `exit 73` is a lane refusal, so **73 keeps meaning
lane busy** and the timeout gets the new code. The reverse split would
have left two tools using 73 for different things.

## The codes now

| Code | Meaning | Right response |
| ---: | --- | --- |
| `0` / `n` | the suite ran and reported its own verdict | read the verdict |
| `73` | **LANE BUSY** — refused before launching anything; mutex held, or the process census found a Godot alive | wait and retry |
| `124` | **TIMEOUT KILL** — launched, still alive at the ceiling, terminated by the runner. GNU `timeout` convention | raise the ceiling, or diagnose a hang. Retrying unchanged repeats it |
| `78` | **CANNOT RUN** — Godot not on PATH, unresolvable project path, or an exit code Windows would not surrender. sysexits `EX_CONFIG` | fix the environment; retrying will not help |

`78` exists because leaving those failures at 73 would have preserved the
same defect in miniature: a caret told to "wait and retry" on 73 would
retry forever against a machine with no Godot installed.

The ceiling still kills. This makes the report truthful, not the patience
infinite.

## Measured cost of every committed v2 and Open Shift suite

One run each, through `tools/run_godot_serial.ps1` itself with
`-LogPath`, on this machine, warm import, lane otherwise idle. Every one
passed.

| Suite | Seconds | Exit | Verdict |
| --- | ---: | ---: | --- |
| OrisonV2M08ESpatialTest | **80.5** | 0 | PASS |
| orison_v2_two_root_matrix_test | **76.3** | 0 | PASS, all four directions, checks=24 |
| OrisonV2IntegratedTest | 44.3 | 0 | PASS |
| OrisonV2BlockoutTest | 4.7 | 0 | PASS |
| orison_v2_m08f_runtime_test | 2.2 | 0 | PASS checks=29 |
| orison_v2_presence_ledger_test | 1.8 | 0 | PASS checks=17 |
| OpenShiftAbandonTest | 1.1 | 0 | PASS |
| OpenShiftSaveMatrixTest | 1.1 | 0 | PASS 17/17 |
| OpenShiftAuthorityTest | 0.9 | 0 | PASS |
| OpenShiftIgnoreTest | 0.9 | 0 | PASS |
| OpenShiftMeddleTest | 0.9 | 0 | PASS |
| OpenShiftWorkTest | 0.9 | 0 | PASS |
| OrisonV2BlockoutGuardTest | 0.6 | 0 | PASS (0 failures) |
| OpenShiftSituationTest | 0.5 | 0 | PASS |

The two suites that motivated this task are exactly the two that
exceeded 60: **80.5s** and **76.3s**, matching the reported ~81s and
~75s. Twelve of the fourteen finish inside five seconds.

**Ceiling chosen: `[ValidateRange(1, 180)]`, default still 60.** 180 is
2.24x the slowest measured suite — enough headroom for a cold cache or a
loaded machine, while still capping a genuine hang at three minutes. The
default is unchanged, so a caller that needs longer must ask deliberately.
Raising this bound again should come with new measurements.

## Proof of both paths

**Timeout.** A real suite against a deliberately tiny ceiling:

```
run_godot_serial.ps1 -Scene res://tests/OrisonV2M08ESpatialTest.tscn -TimeoutSeconds 5
  -> exit 124
  TIMEOUT: 'res://tests/OrisonV2M08ESpatialTest.tscn' was still running at the
  5-second ceiling and was terminated by the runner. The ceiling ended this run,
  not the suite - it reported no verdict. Re-run with a higher -TimeoutSeconds if
  the suite is legitimately this expensive, or diagnose a hang. Partial log: ...
```

**Lane busy.** A genuine second Godot started outside the runner (so it
holds no mutex) and left alive:

```
run_godot_serial.ps1 -Scene res://tests/OpenShiftSituationTest.tscn -TimeoutSeconds 30
  -> exit 73
  LANE BUSY: Godot is already active (Godot_v4.7.1-stable_win64:28140,
  Godot_v4.7.1-stable_win64_console:2824); no process was started. Wait and retry,
  or close that window if it is an idle editor.
```

The refusal still names every holding process, and now prints each
window title when there is one — an idle Project Manager window held this
lane for six hours once, and the title is what identifies it.

**Bound is real:** `-TimeoutSeconds 300` is refused by parameter
validation ("greater than the maximum allowed range of 180"), `180` is
accepted and runs.

**Both motivating suites, re-run through the runner under the committed
configuration** (`-TimeoutSeconds 120`): M08E spatial 80.6s exit 0,
two-root matrix 76.3s exit 0.

## Callers

| Caller | Depends on | Effect |
| --- | --- | --- |
| `run_godot_capture.ps1` | `-eq 73` -> `BUSY_OR_TIMEOUT` | **degraded, not broken** — see below |
| `export_friends_build.ps1` | `-ne 0` | none; its message now carries a more specific code |
| `warm_release_checkout.ps1` | `-ne 0` | none |
| `run_release_performance_matrix.ps1` | passes its own `-TimeoutSeconds` through | none |
| `test_release_pipeline_contract.ps1` | asserts the runner **parses** | passes, 46/46 |

**Reported, deliberately not rewritten** (per the task's instruction not
to silently rewrite a caller that hardcodes 73):

1. `run_godot_capture.ps1:132` maps 73 to the receipt status
   `BUSY_OR_TIMEOUT`. A timeout now returns 124, so it falls to `FAIL`
   instead. That is less specific but not wrong — a capture that was
   killed genuinely did not produce its frames — and its own line-62
   lane `exit 73` remains correct. Its line-93 comment ("Exit 73 means
   the lane is occupied or the ceiling fired") is now stale. A follow-up
   could add a `124 -> TIMEOUT` arm and split that receipt status, but
   that changes evidence-receipt vocabulary and belongs with whoever owns
   the capture receipt schema.
2. `run_godot_capture.ps1` and `run_release_performance_matrix.ps1` each
   carry **their own** `[ValidateRange(1, 60)]`, so widening the serial
   runner does not widen them. That is correct for capture and perf
   workflows, which are short by design, and it is stated here so nobody
   assumes the new ceiling reaches everywhere.

**Pre-existing defect found, not caused by this change and not fixed:**
`tools/test_release_pipeline_contract.ps1` **does not parse under Windows
PowerShell 5.1**. Line 74 contains a UTF-8 em-dash
(`"CONTENT NOTE — READ BEFORE PLAY"`) in a file with no BOM, which 5.1
decodes as Windows-1252 and then fails on `Unexpected token 'READ'`. The
file is pristine on this branch (`git status` clean for it), and it runs
**PASS 46/46, exit 0** under `pwsh` 7. Anyone running that contract test
must use `pwsh`, or the file needs a BOM.

## Validation

| Command | Result | Exit |
| --- | --- | ---: |
| Timeout proof (ceiling 5s) | 124 + naming message | 124 |
| Lane-busy proof (real second Godot) | 73 + process list | 73 |
| `-TimeoutSeconds 300` | refused by validation | 1 |
| `-TimeoutSeconds 180` | accepted, ran | 0 |
| OrisonV2M08ESpatialTest @120 | PASS, 80.6s | 0 |
| orison_v2_two_root_matrix_test @120 | PASS 24 checks, 76.3s | 0 |
| OpenShiftAuthorityTest @60 | PASS | 0 |
| orison_v2_m08f_runtime_test @60 | PASS checks=29 | 0 |
| RealitySaveCompatTest @60 | PASS 14/14 | 0 |
| DreamBoundaryTest @60 | PASS 39 checks | 0 |
| `test_release_pipeline_contract.ps1` (pwsh) | PASS 46/46 | 0 |
| `audit_orison_v2_completeness.py` | structural 80, golden-shift 1 | 2 (expected) |
| `audit_orison_spatial_dependencies.py` | clean, 0 new unclassified | 0 |
| `audit_systemic_situation_authority.py` | 0 new actionable | 0 |
| `test_orison_v2_completeness.py` | 90 OK | 0 |
| `test_orison_spatial_dependencies.py` | 51 OK | 0 |
| `test_systemic_situation_authority.py` | 34 OK | 0 |

Gates left exactly as found: FIRST_SLICE 0, GOLDEN_SHIFT_V2 1,
FULL_BUILDING_STRUCTURAL 80, FULL_BUILDING_RUNTIME 45,
PRODUCTION_CUTOVER 95, V1_RETIREMENT 97.

## Limitations

- The timings are one run each on one machine with a warm import. They
  size a ceiling; they are not a performance baseline, and a cold import
  or a contended machine will be slower — which is what the 2.24x
  headroom is for.
- 124 is the *runner's* judgement that the process outlived the ceiling.
  It cannot distinguish a hang from a suite that is merely expensive;
  only the partial log at `-LogPath` can, which is why the timeout
  message names it.
- A suite that exits with code 73, 78 or 124 of its own accord would be
  indistinguishable from a runner refusal. No committed suite does —
  they exit 0 or their failure count — but a future suite must not adopt
  those numbers.
