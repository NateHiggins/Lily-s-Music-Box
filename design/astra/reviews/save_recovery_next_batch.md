# Next save-recovery batch: concrete consumer plan

Historical preparation record. The storage and ordinary Continue implementation subsequently landed in `9548301873807117a870aeb6e517173e81a4713f`; see [the implementation review](save_recovery_implementation_review.md) and [the final title review](title_save_recovery.md) for current results and limits. The observations below describe the inspected pre-change source.

Read-only proposal after the calendar changes. RealityState, title and
GameBoot were inspected; no save/title edits, Godot run, installation,
compilation, staging or commit was performed. This refines
`save_recovery_review.md`; it does not replace that evidence or claim K3.

## Implement now: protected loads, recoverable writes, ordinary Continue

Keep the version-4 fact document and its existing path. RealityState remains
the only disk owner. Domain mutations still commit through it, and a failed
ordinary commit still leaves in-memory progress in place as the save model
requires. The next batch should claim **crash-recoverable writes**, not
strict atomic file replacement or power-loss durability.

The current calendar patch adds `campaign_clock_read_only` protection and
captures the new clock at `start_new_campaign`. Preserve both. It does not
fix malformed JSON, unreadable files, invalid non-clock shapes or the title's
normal launch: `title_screen.gd:195,498–503` still maps BEGIN THE NIGHT to
`GameBoot.begin_game(CINEMATIC, true)`, whose `:158–164` calls new-campaign
creation before scene change. There is still no ordinary Continue path.

## Why a normal Godot rename is insufficient on this Windows build

The installed engine commit's [DirAccessWindows::rename](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/drivers/windows/dir_access_windows.cpp)
removes an existing destination before `MoveFileW` for distinct paths
(lines 313–319). Therefore `rename_absolute(temp, primary)` has a deletion
gap. Its failure must be recoverable from another intact generation.

The same engine's [FileAccessWindows](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/drivers/windows/file_access_windows.cpp)
has an internal safe-save path using `ReplaceFileW`, but the inspected
[GDScript FileAccess bindings](https://raw.githubusercontent.com/godotengine/godot/a13da4feb/core/io/file_access.cpp)
do not expose a per-write switch or a checked replace primitive. Also,
Windows `flush()` calls `fflush` without returning its result; a successful
readback is content verification, not a disk-power-loss guarantee.

## RealityState transaction and recovery boundary

Add a small file-operation seam for deterministic failures, not a second
save manager. `save_game()` delegates one immutable serialized snapshot to
the writer. Use same-directory siblings: primary, `.tmp`, `.bak`, and
`.txn`. Journal metadata belongs to storage, not the world's fact schema.

1. Parse/version/type-check the candidate before writing. Preserve unknown
   additive fields in compatible saves; reject invalid known container
   shapes and a non-integral/invalid version before adopting the dictionary.
   Delegate calendar checks to the existing clock authority. Suppress
   reentrant disk commits while load/default/clock migration is in progress;
   the validated migrated candidate goes through the same writer afterward.
2. Write `.tmp`, check write status, flush/close, reopen and verify exact
   bytes/hash plus the save envelope. No primary change yet. A short or
   otherwise invalid candidate is a failed save, even if open succeeded.
3. Copy the previous primary to `.bak` and verify its bytes before risking
   replacement. Ordinary commits only back up a validated primary. Explicit
   New Campaign may preserve raw protected/future bytes as the previous
   generation, without trying to interpret them. A failed backup leaves the
   intact primary in place and aborts the transaction.
4. Write and verify `.txn` containing expected old/new hashes and candidate
   paths before touching the primary. Only then promote the verified `.tmp`.
   If promotion fails after the Windows deletion gap, recover from the
   verified backup using a new temporary copy; keep the backup itself intact.
   If restoration also fails, leave the journal/backup and hold writes with
   a truthful notice. Never delete the last verified generation to make a
   rename succeed.
5. Reopen and verify the promoted primary against the candidate. Only this
   success returns true and clears an obsolete write-failure notice. Keep
   the previous generation; journal/temp cleanup occurs after the verified
   primary exists. Failed cleanup must not misclassify the completed save.

Startup selection must be deterministic and independent of file mtimes:

| Observed files | Load decision |
| --- | --- |
| Supported valid primary | Load it, including when stale journal/temp debris exists. Never prefer an uncommitted temp. |
| Future-version primary | Refuse before merge and before backup fallback. Preserve its exact bytes; do not silently roll back to an older campaign. |
| Invalid campaign clock in primary | Preserve the existing clock read-only latch; do not sample a new epoch or treat it as a fresh campaign. |
| Primary missing/damaged, verified compatible backup | Recover the previous generation; retain damaged primary bytes under a deterministic hash-qualified recovery name before replacing them. Show that recovery occurred. |
| Unreadable primary, both generations invalid, unsupported backup only, or ambiguous artifacts without a valid committed generation | Hold writes, preserve artifacts and expose the reason. Missing/unreadable must be distinct read outcomes; a boolean existence check is not enough. |
| No primary or recovery artifacts | Fresh-start status, not a fabricated successful load. |

Use a reasoned write latch for every invalid-load branch. `save_game()` must
not turn a malformed-save refusal into the future-version notice. Dismissing
SaveStatusNotice never releases a latch. A successful explicit new campaign
is the intentional replacement boundary; a failed attempt preserves both
the previous bytes and the previous protection reason.

## Title and launch handlers

Expose runtime-only `load_status` / `can_continue()` from RealityState so
the title does not become a second file parser. A valid or successfully
recovered campaign gets **CONTINUE** as the primary focused action. Its
handler launches `CINEMATIC, false`; it neither creates a campaign nor
samples a clock. A missing campaign gets **BEGIN THE NIGHT**.

Starting over is a separate **NEW CAMPAIGN** action with explicit replacement
copy when a save or protected artifacts exist. Only its committed choice
calls the replacement operation. Build a fresh candidate and sample its
hour/minute once without prematurely invoking an ordinary commit; adopt it,
clear old protection and launch only after the storage transaction succeeds.
Make that success observable to `GameBoot.begin_game` (return bool/error),
which currently changes scenes regardless of new-campaign persistence.
Keep the existing debug launch/read-only diagnostics separate from normal
Continue. A future save is not a resumable current campaign.

## Decisive proof order

First preserve red controls for malformed/truncated/non-object JSON,
wrong-shaped known fields, invalid/future calendar, future save version,
and the existing BEGIN overwrite. Assert old bytes and protection survive
ordinary commits, notice dismissal and restart. Then inject failures at
temp write/readback, backup creation, journal creation, primary removal,
promotion and restoration. Each stage must return failure honestly and
leave a deterministic recoverable generation or protected artifacts.

Run a second real process for interruption points immediately before and
after promotion, using profiles isolated before autoload startup. It must
recover either the complete previous state or complete newly committed
state, never a merged/truncated hybrid. Compare actual job, spent-item,
dream-boundary and campaign-clock facts, not only an extra sentinel string.
Finally exercise the actual title button handlers: Continue preserves those
facts; cancelled New does nothing; failed New preserves the old save; an
explicit successful New replaces once and samples once. Existing future-save
and composed positive reconstruction tests remain required. This is not a
substitute for the eleven human route-boundary observations.

## Strict atomic replacement remains a separate native prerequisite

No `.gdextension`, Godot C++ binding headers or native project manifest was
found in the workspace inventory. CMake, Ninja and .NET are installed;
Visual Studio Community 2022 is present, but `vswhere` finds no installed
`Microsoft.VisualStudio.Component.VC.Tools.x86.x64`. No cl/clang/gcc/zig
compiler was found on PATH or at the checked standard LLVM/MSYS locations.
This is an inventory result, not proof that no compiler exists anywhere.
The repository's unrelated stale `legacy_arcade` submodule mapping also
means `git submodule status` cannot establish a complete dependency census.

A future tiny native boundary could expose checked Windows `ReplaceFileW`
for an existing target and a checked same-volume move for first creation,
with error details, backup retention and appropriate flush semantics.
That requires a build/package path and isolated real-OS failure controls;
do not quietly claim that a GDScript delete-and-rename sequence is equivalent.
No installation or native implementation was attempted in this review.
