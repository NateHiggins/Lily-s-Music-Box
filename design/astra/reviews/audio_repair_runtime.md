# Audio repair runtime validation and matrix harness correction

The actual two-root CampaignShell matrix passes on the final frozen audio implementation: process exit 0, 24/24 checks, and all four direction totals equal 1. A new isolated APPDATA profile was used. Its test save directory was absent before launch and created by the repaired matrix harness. All test saves were removed afterward. The verbose run took 93.005 seconds of process time; this is not a graphics-performance measurement.

The only diagnostics in this final run were one deliberate invalid-selector fallback warning and five existing v1 found-art placement warnings for `cam_noel_witches`. There were no save-failure warnings, ObjectDB leak warnings, retained-resource errors, or other error lines. The art-placement warnings remain project content debt; they are not approved engine-baseline exceptions.

The final matrix consumes NightRegister SHA-256 `54710acbd5875ee5abcdc7814ef30b12503ea15cc063dacd88175f384f8478cf` and AudioPolicy SHA-256 `ddde458de7c22aea3a640cf096b5dbfca447ce66d0011be63fcdfafbc620525f`. These include owner release, released-slot replacement, and the off-tree presentation guard. The precise implementation belongs to the parent agent and its selective controls; this reviewer made no audio production edit. Game source snapshots were unchanged throughout the final matrix. The only concurrent broad-diff change was `tools/tests/test_orison_v2_completeness.py`, which this runtime did not execute.

## Preserved red and repair

The first independently fresh-profile matrix failed with exit 4 and 20/24 checks: every reconstruction direction failed, and twenty save-failure warnings were recorded. The harness wrote `user://tests/m08d_<direction>.json` without creating its parent. Its historical base pass used a shared isolated profile after another harness had already created `tests`; that result did not prove directory ownership on a fresh profile.

Only `game/tests/orison_v2_two_root_matrix_test.gd` was edited by this reviewer in the final repair. At the start of `_ready()`, before campaign mutation, it creates the test-save directory and checks the return code. A failure reports the directory/error and exits 2. The repaired source SHA-256 is `d6d17f3a54806bf15c5b876a87aee2fda49ffd331e0077deb31b7202e1a7a5d0`. `git diff --check` passed. There was no runner edit, staging, or commit.

An initial attempt to launch the green with `pwsh -File ... -ExtraArgs --verbose` failed in PowerShell argument binding, before Godot launched. That exit-1 receipt is retained. The successful invocation used an explicit `@('--verbose')` array through PowerShell `-Command`, a separate fresh profile, and the unchanged serial runner. This was one executed post-repair matrix run.

## Other focused results

These runs preceded the final off-tree guard addition; their exact earlier source hashes are retained separately. They used the same released-slot AudioPolicy implementation.

| Suite | Actual exit | Functional result | Shutdown diagnostics |
| --- | ---: | --- | --- |
| M08F production runtime fixture | 0 | 29/29 | None; the prior 4-object/2-resource symptom was absent |
| M11A exterior module | 0 | 40/40 | None |
| AudioPolicy | 0 | 45/45 | None |
| NightRegister focused apparatus | 0 | 148/148 | 22 leaked objects and 6 resources still in use |

The NightRegister focused suite result is not clean lifecycle evidence. Its immediate shutdown and exact retained owners require separate diagnosis; the authority agent owns the focused harness correction and subsequent proof. The M11A result remains isolated exterior-module validation, not proof that the exterior is mounted in BuildingRoot. Empty shutdown diagnostics do not independently constitute an in-test zero-retained-object assertion.

The initial baseline diagnosis is historical. Its unresolved four-object M08F symptom is superseded at the tested source scope by these later runs and the parent's owner controls. It should not be read as proving that idle ServiceSet or WatchRegister children caused that retention; the parent's subsequent production-consumer investigation identified the NightRegister paper cue in AudioPolicy.

Machine review and hash-linked raw evidence: `design/astra/evidence/audio_repair_runtime/final_review.json`. Successful final matrix receipt: `design/astra/evidence/audio_repair_runtime/matrix_directory_green/verbose_launch/receipt.json`. The initial suite receipt, separate diagnostic categorization, failed matrix red, and failed prelaunch attempt remain beside them.
