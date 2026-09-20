# Save recovery implementation and focused runtime evidence

This folder contains source first prepared while live `game/` was frozen. After
root's explicit GO following calendar commit `dd434b1`, the storage files were applied
and the focused checks below were run. Nothing was staged or committed by this agent.
Root integrated the production storage, title/boot consumers and test scenes in
commit `9548301873807117a870aeb6e517173e81a4713f`
(`Protect campaign saves and resume through the production title`). The earlier
runtime receipts retain their actual pre-commit HEAD and source hashes; the
integration commit does not relabel those historical executions.
`originals/` preserves the exact RealityState and CampaignClock inputs. The latter
is reference-only; this package does not edit the clock authority. `proposed/`
contains the storage helper, RealityState adapter and three focused test scenes.
`storage_reality_state.patch` targets only those eight files. The old `title/`
proposal is stale, remains unstaged, and is not a source for replay. Current title
evidence is indexed by `design/astra/evidence/title_save_recovery/receipt.json`;
its runner and preserved controls are in that evidence folder.

The package receipt records source hashes and points to the actual raw runtime
receipts. Python parsing and mutation-anchor checks remain packaging checks,
separate from Godot evidence. Actual separate-process interruption/restart was
executed as described below. Existing K3 human route observations and strict native
atomic replacement remain open; these focused checks do not claim those boundaries.

## Executed evidence

All paths below are beneath `design/astra/evidence/save_recovery/`. Each process
used a fresh APPDATA before autoload startup and the unchanged serial Godot runner;
each receipt contains source copies, before/after input hashes, raw exits and logs.

| Run | Result |
| --- | --- |
| original_invalid_red | Original existing APIs: 6 protection/preservation assertions fail, exit 1; known malformed-JSON loader diagnostic |
| candidate_invalid_02 | Same six assertions pass, exit 0; clean diagnostics |
| malformed_entry_red / green | Existing root-only validation fails 64 added assertions (115/179), exit 1; known entry validation passes 179/179, exit 0; clean diagnostics |
| invalid_utf8_red / green | Lossy decode fails 14 added assertions (181/195), exit 1, with retained decoder diagnostics; byte validation passes 195/195, exit 0, clean diagnostics |
| complete_no_readback_red | Removing actual byte verification causes 23/195 assertions to fail, exit 1; clean diagnostics |
| complete_future_fallback_red | Removing future/clock primary refusal precedence causes 3/195 assertions to fail, exit 1; clean diagnostics |
| complete_recovery_green | Restored candidate passes 195/195, exit 0; clean diagnostics |
| complete_compat_green | Existing future-save compatibility passes 14/14, exit 0; clean diagnostics |
| complete_calendar_green | Existing campaign calendar passes 52/52, exit 0; clean diagnostics |
| process_restart_03 | Four separate-process cases pass across ten processes; three identified writers terminated with native exit 81; all completed readers exit 0 with clean diagnostics |

The controls are reversible source mutations with restoration in `finally`;
`complete_controls_receipt.json` records restoration of the exact candidate. Every
listed run's before/after source digest was unchanged. The branch agent received
an explicit source/lane handoff only after the final storage green.

Intermediate failures are retained. `candidate_invalid_01` failed import because
the new global class was not yet in Godot's cache; the explicit preloaded script
type fixes that fresh-import dependency. `recovery_01` passed 99/114: fifteen
fixture comparisons mismatched runtime ints versus JSON floats, while byte
preservation assertions passed; fixture facts are now normalized to JSON's number
representation. That run also exposed a real empty-buffer HashingContext.update
error on first creation; the writer now hashes empty input without calling update,
with a known empty-SHA256 assertion. `compat_01` caught directory-as-save-target
copy incorrectly becoming an unreadable-save notice; the writer now distinguishes
a known directory target (write failure) from an unreadable existing file (protected
read failure). `recovery_02`, initial controls and initial restored green are kept
as earlier evidence rather than overwritten.

## Agreed title/boot API

- `load_game() -> void`: inspect/recover actual files, adopt a supported snapshot
  or publish protected/missing status. It does not create a new campaign clock.
- `can_continue() -> bool`: true only for loaded/recovered and no write latch.
- `load_status() -> Dictionary`: `status` is missing/loaded/recovered/protected;
  `reason` gives the refusal/recovery reason; `has_saved_campaign` means existing
  primary/recovery artifacts, including protected ones, not resumability.
- `start_new_campaign() -> bool`: prepare a private candidate, call the existing
  CampaignClock creation path once, archive original raw bytes by content hash,
  and adopt/publish only after successful primary readback. False prevents launch.
- `last_save_result() -> Dictionary`: `ok`, `code`, `stage`, `recovered`,
  `protection_required`; a failed New leaves the prior notice intact, so the title
  uses this separate result for its failure copy.
- Ordinary `save_game() -> bool` and `commit() -> void` retain their contract:
  a failed domain save does not roll back in-memory progress. Every invalid-load
  reason holds writes; dismissing its presentation cannot release that latch.

**Integration dependency now provided by root:** the agreed protected-state check
is present at the start of CampaignClock.bind_state. It returns false without
sampling or relabeling an existing refusal. Root reports a preserved original
51/52 exit-1 control and guard 52/52 exit-0 with future-version-99 notice preserved;
this agent did not run those earlier processes. The original clock copy remains unchanged
and the receipt separately records the now-current clock hash. The private New
preparation temporarily clears the latch and suppresses commits/notices while the
clock prepares its candidate. The proposed tests exercise this dependency again.

## Storage protocol and limits

One process owns the file. Compatible unknown fields survive; invalid known root
container/scalar shapes and the tested known collection entry envelopes are
rejected. The existing migration policy still accepts an absent `version` as 0
and accepts supported version-0 envelopes with defaults. A valid JSON Dictionary
is not inherently corrupt because it omits current fields. Domain scalar values,
IDs, vocabularies and deeper nested schemas are not comprehensively validated here;
domain-specific reconciliation stays with existing owners. CampaignClock validates
calendar structure without sampling. Future primary version and invalid primary
clock outrank backup fallback.

Raw bytes must be valid UTF-8 before String conversion or JSON parsing. The seven
invalid-sequence controls require refusal and exact byte preservation after an
ordinary commit. Validation covers incomplete sequences, invalid continuations,
invalid leads, overlong encodings, surrogate code points and values above U+10FFFF;
it avoids calling the lossy Godot decoder on those inputs. The collection checks
cover Dictionary records in the named item/order/job/situation/incident maps,
NPC observation arrays of Dictionaries, and night-register line Dictionaries.
They do not establish universal malformed-save protection.

The writer validates an immutable UTF-8 snapshot, writes and reads back `.tmp`,
copies and reads back the current primary into `.bak`, writes and reads back a
`.txn` of old/new SHA256 hashes, checks that the primary has not changed, then
promotes and reads back the exact new bytes. Only verified success returns true.
Promotion/verification failure copies the verified backup through `.tmp` and
restores it, leaving `.bak` intact. Failed restoration holds writes and preserves
the recovery artifacts. A first creation has no old committed generation: an
interrupted/failed creation with only artifacts is protected, not fresh/Continue.

A supported primary always wins over stale temp/journal debris. Missing/damaged
primary can recover a supported backup; a present journal must match its hash.
Unreadable primary, invalid/future backup or ambiguous artifacts are protected.
Damaged raw primary is archived as `.corrupt.<SHA256>` before recovery. Explicit
New archives primary and sidecars as `.replaced.<SHA256>` before reusing slots.
Paths are derived from the configured save path; journal JSON cannot redirect IO.
No mtime sorting, newest-temp selection, cross-process locking or automatic archive
pruning is added. Cleanup failures do not invalidate a verified primary.

Godot's installed Windows [file access source](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/drivers/windows/file_access_windows.cpp)
distinguishes missing files with ERR_FILE_NOT_FOUND and exposes checked buffer
writes, but flush/close do not establish a checked durable OS flush. Its
[directory rename](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/drivers/windows/dir_access_windows.cpp)
can remove the destination before moving the source. This proposal therefore
claims no strict atomic replacement or power-loss durability. Native replacement
and packaging remain separate debt, as the preceding read-only review records.

## Failure seam and executed proof

RealityState.storage_operation_override is a test-only Callable receiving
`(stage, operation, arguments)`. Null performs the real operation; a Dictionary
replaces that result. `temp_write` returning `{ok:false,error:ERR_FILE_CANT_WRITE}`
is the agreed pre-promotion New failure. `new_campaign_time_provider` returns only
hour/minute for deterministic sample-count tests; CampaignClock owns validation.

`reality_invalid_load_control` uses only pre-existing APIs, so it can run against
the preserved original RealityState and then the candidate. Its assertions require
malformed/non-object/wrong-shape files to latch and remain byte-identical after
an ordinary commit. It does not assert that the defect remains present.

`reality_save_recovery_test` uses the real storage and RealityState APIs against
private files. `controls/storage_no_readback.gd` removes actual byte verification;
the short-write assertions must fail. `controls/storage_future_fallback.gd`
removes primary-refusal precedence; the future/clock primary assertions must fail.
Restore the candidate source after each isolated control, and hash it before green.
Both negative controls were executed after GO, as the table above records.

| Case / stage | Required result |
| --- | --- |
| temp/backup/journal write or readback failure | False; old primary unchanged; fresh reader loads old facts |
| short buffer accepted by injected write result | Byte readback rejects it before declaring save success |
| promote fails before deletion | False; old primary unchanged |
| promote fails after Windows deletion gap | False; old primary copied back; backup remains intact |
| rollback temp/promotion/readback fails | False, protected; backup/journal survive; fresh reader obtains a complete old generation |
| cleanup fails | True only after verified primary; next reader selects new primary |
| future primary arrives before promote | Protected; arriving bytes preserved |
| damaged primary with supported backup | Archive damage, recover old facts, report recovery |
| future primary / unsupported primary clock with old backup | Protected before fallback; neither resampled nor overwritten |
| unreadable primary / orphan temp / ambiguous journal | Protected; never a fabricated fresh start |
| no primary or sidecars, including missing parent | Missing status; deliberate creation makes parent and commits a complete save |
| compatible unknown additive field | Preserved, with omitted known fields defaulted |
| explicit New temp failure | False; prior runtime facts/notice/latch/primary retained; no candidate announcement |
| successful New then load | One sample and one adoption; ordinary load samples zero times |

The full fixture compares work-job stage, consumed-item facts, dream phase and
campaign elapsed time, not just a sentinel string. Its fresh-reader checks are
**in-process** storage reconstruction. The additional `process_restart_03` proof
uses genuinely separate Godot processes with APPDATA isolated before autoload.
An external controller checks a unique stage marker, the exact engine path and
the engine/console ancestor chain back to its own PowerShell runner, then calls
Windows `TerminateProcess` on only that verified fixture handle. All three writer
terminations produced the requested native and runner exit 81. A new reader saw
the complete old generation before promotion and the complete new generation
after promotion but before verification. A third case deliberately deletes the
primary through the operation seam at promotion, then terminates the writer and
proves backup recovery. That is a **simulated native deletion gap**, not direct
instrumentation inside Windows rename or a power-loss test.

A separate four-process first-New sequence proves failure after temp creation,
orphan-artifact protection on restart, successful explicit retry with hash archive,
and another reader retaining the committed clock/facts. The receipt preserves all
ten process IDs, exits, commands, marker identities, file bytes/hashes and matching
before/after runtime input digests. Earlier `process_restart_01` and `_02` controller
attempts safely refused termination because their process identity checks did not
match the installed console launcher/path shape; their bounded timeout failures
are retained and are not counted as interruption proofs.

Reader sample callbacks are installed in scene `_ready`, after RealityState
autoload. Their zero count observes only subsequent calls to that callback, not
host sampling during earlier autoload. Exact full saved-clock equality across
processes is the durable restart observation; the clock source and separate static
authority checks substantiate the validation path's no-resampling contract.

Existing future-save compatibility and calendar regressions passed as recorded.
The title/boot agent subsequently completed its final tests; this paragraph reports
its saved receipts, not additional executions by the storage agent. The aggregate
`design/astra/evidence/title_save_recovery/receipt.json` binds the final production
source copies and nine named final cases. Under its `runtime/` folder:

- `handlers_final/receipt.json`: 123/123, exit 0, clean diagnostics.
- `existing_title_final/receipt.json` and `existing_audio_final/receipt.json`:
  both pass with exit 0 and clean diagnostics.
- `actual_continue_v1_final/receipt.json` and
  `actual_continue_v2_final/receipt.json`: actual CampaignShell launch, 5/5 each,
  exit 0; V1 retains the recorded found-piece wall-placement warning.
- `matrix_calendar_final/receipt.json`: all four root pairings pass, 30 checks,
  exit 0; recorded invalid-root and found-piece warnings remain visible.
- `existing_save_matrix_final/receipt.json`: 17/17, exit 0, clean diagnostics;
  `m08f_reconstruction_final/receipt.json`: 29 checks, exit 0, clean diagnostics.
- `title_capture_final/receipt.json` and its `visual_review.json`: ten frames,
  exit 0, ten images directly reviewed. Recorded Vulkan loader and RGB8 diagnostics
  remain in the raw logs; this is not a clean-diagnostics claim for that capture.

## Minimal replay files and dependencies

Starting from the integrated production commit above, the minimum named files
under `design/astra/work/save_recovery/` needed for the final reversible storage
controls and separate-process restarts are:

1. `run_storage_case.py`
2. `run_storage_controls.py`
3. `proposed/game/scripts/game/reality_save_storage.gd`
4. `controls/storage_no_readback.gd`
5. `controls/storage_future_fallback.gd`
6. `restart/run_restart_checks.py`

Keep this README with that set. The control runner requires byte equality between
the committed live storage and the packaged candidate, temporarily installs the
two preserved control sources, and restores the candidate in `finally`. The
restart runner reads the committed live restart scene directly; neither it nor
the control runner reads `restart/proposed/`, the full eight-file proposal, the
stale `title/` proposal, or `unix_audit/`.

External-to-this-folder dependencies are the committed `game/` project and test
scenes, `tools/run_godot_serial.ps1`, Git, Python's standard library, Windows CIM/
kernel32 process APIs, the bundled PowerShell executable at each runner's `PWSH`
constant, and `Godot_v4.7.1-stable_win64_console.exe` discoverable by PowerShell
`Get-Command`. The exact configured PowerShell path is machine-specific. Runtime
replay requires exclusive source/runtime ownership and fresh output names; the
runners refuse existing evidence paths. From the repository root, illustrative
fresh names are:

```powershell
python design/astra/work/save_recovery/run_storage_controls.py --batch replay_01
python design/astra/work/save_recovery/run_storage_case.py replay_01_restored recovery
python design/astra/work/save_recovery/restart/run_restart_checks.py replay_restart_01
```

The control controller expects its two child processes to exit 1 and returns 0
when both did so and its loop completed; semantic failures, clean diagnostics and
source restoration must still be checked in the child receipts/raw logs. The
restored green is a separate command. Commands above are reproduction instructions,
not new runs performed while sealing this checkpoint.

`package_storage.py` is optional historical package regeneration, not a runtime
dependency. If retained for that purpose, it additionally requires all eight files
under `proposed/`, the two original RealityState/CampaignClock source copies under
`originals/`, and `prepare_reality_state.py` (parsed, not executed). It reads live
source hashes and the named historical evidence receipts and rewrites the patch,
preparation receipt and two control copies. `prepare_reality_state.py` itself reads
only the original RealityState to build its proposed copy. Neither generator is
needed to rerun the committed test scenes or the two final controls.
