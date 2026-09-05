# Save recovery implementation review — 2026-09-05

This closes the bounded storage implementation and verification assigned to
`authority_debt`. It supplements, rather than rewrites, the earlier read-only
`save_recovery_review.md` and `save_recovery_next_batch.md`. Root owns the release
decision and commits; the title/boot agent owns its consumers and final matrix.
No staging or committing was performed by this agent.

## Implemented boundary

`game/scripts/game/reality_save_storage.gd` owns checked file operations on the
configured primary and fixed `.tmp`, `.bak`, `.txn` siblings. The transaction
validates and reads back candidate bytes, verifies the previous generation and
hash journal, checks the primary again, promotes, then verifies the exact primary.
Failed verification restores by copying the previous generation through temp;
the sole backup is not consumed. Failed restoration keeps recovery artifacts and
requires protection. Explicit New archives existing raw artifacts by SHA256 before
replacement. Journal contents cannot supply paths.

`game/scripts/game/reality_game_state.gd` supplies the compatible envelope/clock
validator and the agreed load-status, Continue, explicit-New and save-result APIs.
Ordinary invalid loads hold writes independently of notice dismissal. A failed
ordinary save preserves current in-memory progress. New prepares privately through
the existing CampaignClock path and adopts only after verified persistence. Root's
protected-state clock guard remains an integration dependency, exercised by the
focused calendar checks. This package does not modify CampaignClock.

Supported primary data wins stale transaction debris. Future primary versions and
unsupported primary clock state refuse before backup fallback. A compatible backup
can recover damaged/missing primary when the journal, if present, matches its old
hash. Unreadable primary and orphan/ambiguous artifacts remain protected. A temp
file alone is never treated as a committed campaign.

## Exact-byte and envelope protection

The decoder validates UTF-8 bytes before conversion to a Godot String. This avoids
replacement decoding turning invalid raw bytes into apparently valid JSON, and
avoids decoder error spam for the tested invalid input. Seven invalid sequences
cover invalid leads, continuations, incomplete input, overlong encodings,
surrogates and values above U+10FFFF. Each must remain byte-identical after an
ordinary commit attempt. Journal decoding uses the same UTF-8 precondition.

Known root envelopes are checked before adoption. The tested record maps require
Dictionary entries: cases, work orders, maintenance jobs/items, open-shift
situations, shop buckets, exterior semantics, organism incidents and waking
residues. NPC observation values must be arrays of Dictionaries; night-register
lines must be an array of Dictionaries. Known register, observation and porter
root containers are also checked.

**Preserved migration policy:** `_validate_document` uses
`candidate.get("version", 0)`. An absent version is treated as version 0, and
supported version-0 envelopes are accepted with defaults. Missing current fields
alone do not make a valid JSON Dictionary corrupt. Compatible unknown additive
fields, including future `*_at_basis` metadata, survive. This review does not
claim every valid JSON Dictionary is malformed or that every conceivable malformed
save is detected.

**Remaining schema limits:** this boundary does not comprehensively validate domain
scalar ranges, IDs, vocabulary, chronology or every deeper nested field. Existing
owners still handle job stages/evidence/repair results, item quantities, route
identities and dream/situation reconciliation. Nested case flags/apartment changes,
building-personality maps and other domain payloads are not universally protected
by a central load latch. These are explicit remaining validation coverage limits,
not tested corruption guarantees.

## Actual evidence

All paths below are beneath `design/astra/evidence/save_recovery/`. Receipts retain
raw exits and stdout/stderr, isolated APPDATA, commands, source copies and matching
before/after input hashes. Controls restore exact candidate sources in `finally`.

| Evidence | Observed result |
| --- | --- |
| `original_invalid_red` → `candidate_invalid_02` | Existing APIs: 6 protection/preservation failures, exit 1 → all six pass, exit 0 |
| `malformed_entry_red` → `malformed_entry_green` | Same expanded fixture: 115/179, exit 1 → 179/179, exit 0 |
| `invalid_utf8_red` → `invalid_utf8_green` | Same fixture: 181/195, exit 1 with decoder diagnostics → 195/195, exit 0, clean diagnostics |
| `complete_no_readback_red` | Disabling actual byte readback causes 23 failures, 172/195, exit 1 |
| `complete_future_fallback_red` | Removing future/clock primary precedence causes 3 failures, 192/195, exit 1 |
| `complete_recovery_green` | Exact candidate restored: 195/195, exit 0, clean diagnostics |
| `complete_compat_green` | Existing compatibility suite: 14/14, exit 0, clean diagnostics |
| `complete_calendar_green` | Existing calendar suite: 52/52, exit 0, clean diagnostics |
| `process_restart_03` | All four cases pass across ten real processes; complete generations and raw artifacts checked |

Earlier import, fixture-number-comparison, empty-buffer hashing, directory-target
classification and controller-identity failures remain in their original folders.
The package README explains each correction; those failures are not hidden or
counted as successful proof.

The process-restart proof binds to HEAD
`716a64de3549155aba41e56f036cba7f3c46f7a7` plus 1,152 captured text runtime inputs,
digest `e4d89a965381ff53943dcf2dddc08bbd19beac5a7b195d092392c4b1268cc2b1`,
unchanged throughout the batch. The uncommitted source copies are part of that
binding; HEAD alone is not the executed-source identity.

| Boundary | Verified writer engine PID / native exit | New reader engine PID / exit | Observed generation |
| --- | --- | --- | --- |
| Before promotion | 9960 / 81 | 24564 / 0 | Complete old generation, loaded |
| After promotion, before primary verification | 27340 / 81 | 29076 / 0 | Complete new generation, loaded |
| Deliberately simulated deletion gap | 29424 / 81 | 28816 / 0 | Complete old generation, recovered |

The controller matches nonce/stage marker, installed engine executable and the
engine/console ancestry back to its own runner before calling Windows
`TerminateProcess` on the one verified handle. It never kills by process-name
glob. The deletion-gap case deletes the primary at the operation seam before the
kill; it does not instrument the interior of Windows rename. The reader compares
work-job stage, consumed-item facts, dream phase and the entire saved campaign
clock, so a mixture of generations cannot pass the expected projection.

The failed-first-New case uses four more processes: 24592 fails after temp creation;
12040 loads the orphan as protected and confirms ordinary writes preserve it;
28772 explicitly retries, archives the orphan and creates a verified campaign;
19840 reloads the same committed clock/facts. Each exits 0 with clean diagnostics.

The reader's sample callback is installed in scene `_ready`, after autoload. Its
zero count observes only subsequent use of that callback and cannot directly count
host sampling during preceding autoload. Reports label this limit. Exact full
saved-clock equality is the durable observation; the clock source/static audit
separately supports its no-resampling validation path.

## Remaining execution and durability limits

These runs demonstrate the named crash-recovery boundaries and known invalid-input
controls. They do not establish power-loss atomicity, checked durable OS flushing,
simultaneous multiple-writer safety, automatic archive pruning, all domain schemas,
or human K3 route acceptance. Installed Godot Windows rename can remove an existing
destination before moving its source; native replacement remains separate debt.

The title/boot agent has the final source and runtime lane for affected handler and
composed matrix regressions, then the Vulkan agent receives the lane. No production
changes or runtime processes were started by this agent after that handoff.

Owned source package: `design/astra/work/save_recovery/preparation_receipt.json`
and `storage_reality_state.patch`, covering RealityState, storage, and three script/
scene test pairs. The separate Unix timestamp audit proposal remains outside live
tools under `design/astra/work/save_recovery/unix_audit/`; it is not represented as
an integrated production repair.
