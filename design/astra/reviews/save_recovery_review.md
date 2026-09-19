# RealityState save and recovery review

Read-only review at HEAD `cc95005d2c24b6be5cb04e728c5229c5d416954b`, including current uncommitted harness-directory repairs made by the owning agent. No product/tool edits, Godot run, staging or commit were performed for this review. Test descriptions below identify executable coverage, not newly earned runtime PASS receipts.

**The current owner preserves a recognized future-version save, but does not provide corruption or interrupted-write recovery.** There is also a separate launch-path defect: the normal title action explicitly creates a new campaign instead of resuming the save loaded at startup. Both matter to a real restart guarantee.

## Actual production path

| Step | Exact current source | Observed behavior |
| --- | --- | --- |
| Process boot | `game/project.godot:19–21,38–41` | Uses custom user directory `PleaseRemainOnTheLine`; main scene is the title. RealityState loads before SaveStatusNotice and RealityCases autoloads. |
| Load owner | `game/scripts/game/reality_game_state.gd:10–28,134–202` | Version 4, default path `user://reality_maintenance_save.json`. `_ready()` calls `load_game()`. No production code changes the injectable `save_path`. |
| Domain reconstruction | `game/scripts/game/reality_case_manager.gd:27–36`; `game/scripts/dream/campaign_shell.gd:26–50,86–95` | Cases seed missing case records. CampaignShell later chooses waking/dream composition from the loaded domain phase; it does not implement another disk loader. |
| Domain commit | `reality_game_state.gd:110–113`; e.g. `game/scripts/game/work_orders.gd:46–78,120–134` | A domain mutates shared facts, then `commit()` invokes `save_game()` if enabled and emits `state_changed` regardless of the write result. The void commit API does not acknowledge durable success to callers. |
| Physical file write | `reality_game_state.gd:116–131` | Opens the final target with `FileAccess.WRITE`, writes JSON directly and returns true. Only failure to open is checked. |
| Notices | `reality_game_state.gd:212–229`; `game/scripts/ui/save_status_notice.gd:10–16,57–68` | Save owner publishes structured copy; autoload displays the stored notice after boot and later updates. Dismissal only hides the panel. |
| Normal title action | `game/scripts/ui/title_screen.gd:195,498–503`; `game/scripts/game_boot.gd:158–164` | `BEGIN THE NIGHT` calls `_new_game()`, which passes `CINEMATIC, true`; GameBoot calls `start_new_campaign()` before opening CampaignShell. Only `DEBUG BUILDING` passes false. There is no ordinary Continue action in this menu. |

`start_new_campaign():232–239` releases the future-version latch, replaces in-memory data with fresh defaults and writes immediately. Therefore the ordinary title action overwrites a valid loaded campaign and can also replace a protected future save. The low-level replacement method is intentionally authorized only for an explicit new campaign; the current generic button does not distinguish that destructive choice from resuming a night. `game/tests/title_screen_test.gd` inspects presentation, focus, settings and music; it never launches or asserts preservation of an existing campaign.

Normal write callers are `commit()`, `start_new_campaign()`, and `_migrate():242–244`. No independent shutdown save/retry/backup-recovery owner was found in production. Domain commits remain the durability boundaries; a cleanly closed process alone cannot prove the most recent in-memory fact reached disk.

## Failure behavior, rather than intended behavior

| Input/failure | What current code actually does | Recovery limit |
| --- | --- | --- |
| No save file | Creates fresh defaults, emits loaded state, leaves writes enabled. | Expected fresh session. No save is written by this branch alone. |
| Malformed JSON, truncated JSON, empty file, or valid JSON with a non-dictionary root | `JSON.parse_string` returns a value outside the dictionary branch; fresh defaults remain and `_announce_loaded()` runs. | No corruption notice, backup lookup or write latch. A subsequent ordinary commit can replace the damaged bytes with fresh runtime facts. |
| Syntactically valid dictionary with invalid domain shapes | Merges supplied fields over defaults without validating types. Checks such as `not data.has("cases")` are absent for cases, and other additive checks test presence rather than value type. | `{"version":4,"cases":null}` is accepted at the file boundary, but `ensure_case():75–90` subsequently expects dictionary operations. Valid JSON is not a valid fact store. Exact resulting engine errors require runtime proof. |
| Existing file cannot be opened for read | Emits `save_read_failed`, keeps fresh state and returns. | Unlike the future branch, this does not block writes. The notice's “without changing that file” describes the load action, not protection from a later commit when storage becomes writable. |
| Recognized future version, e.g. integer 99 | Before merge, records the version, sets `save_write_blocked`, publishes a read-only notice and keeps fresh runtime state. Every subsequent `save_game` refuses. | Good existing byte-preservation boundary. `load_game()` re-detects it each time. Explicit new campaign deliberately releases it. Version is coerced with `int`; wrong-type/fractional version validation is not a separate policy. |
| Older version | Accepted dictionary merges over current defaults; if resulting `data.version < 4`, `_migrate` sets version 4 and directly saves. | Migration has no retained original, schema gate or transaction. `persistence_enabled` guards `commit` only; direct migration/new-campaign saves still run. Missing version defaults to 4 after the fresh-data merge, so it does not take this explicit migration branch. |
| Missing parent directory for an injected nested path | `FileAccess.open(..., WRITE)` fails, returns false and publishes `save_write_failed`. | Save owner creates no parent. The production default is at the application user-data root; the demonstrated `user://tests` failure is an isolated harness precondition, not proof that ordinary production startup lacks its root. |
| Directory used as target / write-open refusal | Returns false with a notice; shared in-memory mutation is retained and `state_changed` still emits after commit. | Existing test covers this refusal, not successful later retry or restart from the previous bytes. |
| Write opens, then short write, flush failure, close failure or process interruption | No check follows `store_string`; no explicit flush, close/error verification, readback, temporary sibling, replacement or previous-generation copy. | The method may report success even though a complete durable document was not established. The final target is exposed during replacement; interruption can leave truncated content which the next boot treats as fresh state. This is a source-derived risk, not an executed crash test. |
| Storage becomes writable after a failure | A later save attempts the same direct write. | A successful save does not clear an earlier `save_write_failed` notice. The notice can remain stale until load/new-campaign/reset clears it. |

The silent malformed-save branch is reachable without requiring another user mutation: entering a composed world binds `CampaignClock` (`day_night_director.gd:160–161` in v1; `orison_v2_runtime_root.gd:189–190` in v2), and a fresh empty clock initializes and commits at `campaign_clock.gd:12–35`. That later commit can overwrite the damaged file. The current normal title path replaces it even earlier through explicit new-campaign code.

## What the current tests really cover

| Test and exact path | Genuine executable proof | What it does not prove |
| --- | --- | --- |
| `game/tests/reality_save_compat_test.gd:10–55` | Uses the real owner and an isolated JSON file. Injects version 99; checks no merge, write latch, owner notice, rendered notice/dismissal, byte-for-byte preservation after commit, and explicit new-campaign replacement. | No damaged current/legacy schema, malformed root, read-open failure, interruption, backup recovery or second process. No fresh run was performed here. |
| Same test `:57–63` | Makes the save target the existing `user://tests` directory; asserts save refusal and the consequence notice. | Not a partial-write failure, full-disk failure, failed rename, retry-then-success, or preservation of a previous valid file through a failing write. |
| `game/tests/core_loop_test.gd:31–33,79–85` | Disables persistence; JSON-stringifies/parses the dictionary, resets facts, merges and rebuilds the coordinator across semantic boundaries. | Never calls the production file loader/writer. No I/O, autoload boot, schema rejection or recovery evidence. The save contract already states this distinction. |
| `game/tests/dream_boundary_test.gd:173–189` | Saves a real file, verifies saved phase, destroys/recreates CampaignShell, clears runtime facts, calls production `load_game`, then checks domain reconstruction across armed/entered/active/return-pending/awake boundaries. | Header says RealityState is destroyed, but code resets the existing singleton, not its node/process. No forced termination or new-process restart. Cleanup at `:294–304` compares existence of the production save, not its content hash. |
| `game/tests/open_shift_save_matrix_test.gd:38–111` | Produces four dispositions through actual situation/prop APIs; disk save/load preserves situation, porter and observation facts. Checks selector values for four direction labels. | Does not instantiate either complete BuildingRoot on the two sides. After load it reads saved dictionaries; the header's general “reconstructed” claim must stay at that narrow scope. Still does not create its own `user://tests` parent. No failure injection. |
| `game/tests/orison_v2_presence_ledger_test.gd:127–179` | Actual V2 world produces beliefs, then a real file reload preserves selected provenance fields. | `_reconstructs_under(root_id,...)` ignores `root_id` and builds no new root. Thus the two labels do not prove composed v1/v2 rollback. No failure recovery. |
| `game/tests/orison_v2_m08f_runtime_test.gd:103–134` | Actual V2 composition, disk save, root destruction, load and CampaignShell reconstruction compare the real work-order record. | Same process and same save singleton, successful-path only. `loaded := not data.is_empty()` by itself cannot discriminate load from fresh defaults; the expected job comparison is the meaningful assertion. |
| `game/tests/orison_v2_m11a_first_exterior_cell_test.gd:464–520` | Real disk save/hash, public module teardown, load, and new module/player composition; later subset/cursor assertions compare semantic facts. | Successful same-process reconstruction; no corrupted bytes, storage failure or crash. Do not promote module reconstruction to whole-game restart. |

The current working copy now creates and checks the test parent before persistence in M08F (`:14–21`) and M11A (`:98–105`). Those are the owning agent's bounded fixture fixes; historical missing-directory red receipts remain useful. They do not change RealityState's corruption/recovery policy. Compatibility, dream-boundary and presence tests already create `user://tests` themselves, though some do not check the directory-creation return code.

All these scene tests change `RealityState.save_path` in their own `_ready`, **after the RealityState autoload has already loaded the default path**. Safe execution therefore requires the existing external isolated-profile discipline before process start; a late path override alone does not prevent reading or migrating the real profile at autoload startup. No real profile was accessed by this read-only review.

## Smallest reversible implementation proposal

Keep RealityState as the single fact-store owner and preserve version-4 domain identities. Do not create a new save manager for every domain or serialize scene transforms. The [save transaction contract](../../SAVE_RELOAD_TRANSACTION_MODEL_2026-08-27.md) explicitly allows in-memory progress after a failed commit; the correction must improve persistence truth without silently changing that gameplay contract.

1. **First contain damaged-load overwrite.** Distinguish missing, readable-valid, unreadable, malformed, unsupported-future and invalid-shape results. Validate the version envelope and known container/scalar types before merging. Preserve unknown additive fields for compatible versions. On malformed/read failure, keep the original bytes untouched and hold writes with a notice until recovery or an explicitly named new-campaign action. Generalize the current latch reason so a corruption refusal cannot incorrectly display the future-version message. Include older-version migration in the same protected path.
2. **Replace only the file-writing boundary.** Serialize once to a same-directory temporary sibling, check write/flush status, close, reopen and validate the exact candidate, then replace the target using a same-filesystem operation whose replacement behavior is proven on the supported Windows build. Keep a previous validated generation recoverable. Never delete the only good target first to make rename succeed. Check every operation and leave the prior valid save intact on failure. A tiny injectable file-operation seam is justified for deterministic short-write/flush/replace failures; avoid a broad storage framework.
3. **Make restart select complete data deterministically.** An interrupted temporary file is not a committed generation. Validate before choosing primary/backup; future-version primary refusal takes precedence over silently loading an older backup. Preserve damaged bytes before any repair replacement and give the player a truthful recovery notice. Tests must establish both sides of the replacement boundary. Readback proves content, not arbitrary power-loss durability; filesystem durability must remain an explicitly bounded claim.
4. **Expose a real normal resume path.** For a valid existing campaign, the ordinary title action must enter cinematic mode with `new_campaign=false`. Present starting over as an explicit distinct action; do not release a damaged/future latch through an ambiguously named begin button. Return/record save success from the relevant owner path so UI and recovery logic can distinguish durable success from continuing only in memory. Clear obsolete write-failure notices after a verified successful save.

Step 1 is the smallest immediate data-preservation repair. Steps 2–4 are necessary before claiming interrupted-write recovery and ordinary restart preservation. Creating the harness directory is a separate already-owned test fix; it is not a substitute for any of these steps. Exact future-version behavior must remain compatible with the current tested refusal policy.

## Meaningful failure-injection cases

Run each in a fresh isolated profile established **before autoload**, with known byte hashes and retained evidence. Inject into the real file boundary, not just a fake return value above `save_game`.

| Case | Required red/green observation |
| --- | --- |
| Malformed, empty, array-root and wrong-type-container saves | Original bytes survive boot, composition-triggered commits and a second process; notice names the failure; no invalid domain merge. Current malformed path should fail this control. |
| Future integer version 99 | Reuse the good existing compatibility assertions; add restart and ordinary title launch. Neither may overwrite or silently downgrade it. Explicit new campaign is the separate allowed replacement control. |
| Valid previous-version fixture with known facts | Migration preserves job/item/case IDs and unknown compatible facts. Failed migration write retains the previous readable bytes and reports non-durability; retry succeeds without duplicating domain events. |
| Missing declared test parent; target is a directory; create/open denied inside disposable profile | Harness setup failure is distinct from save-owner failure. No prior valid save is lost; commit's in-memory behavior remains documented. Do not modify real account permissions. |
| Write accepted then truncated; flush/error; temporary readback corrupt; replacement refused | Save returns false and publishes notice; previous primary/backup remains byte-identical and reloadable. A seam which always returns success must make these tests red. |
| Forced process termination before replacement, then after replacement | A separate restarted process loads either the previous complete generation or the new complete generation according to the commit boundary, never mixed/default facts. Keep timing deterministic with a narrow test checkpoint, not random sleeps. |
| Primary damaged, validated backup present; both damaged; stray partial temporary file | Deterministic candidate policy is observed; original damaged bytes retained; neither a temporary file nor an unvalidated backup is silently blessed. Both-damaged case remains protected with an honest notice. |
| Failed save followed by successful retry | In-memory mutation survives, disk eventually contains it once, and stale failure copy clears only after verified success. A dependent work-order/item action must not duplicate after restart. |
| Actual normal title Continue versus explicit New Campaign | Two-process test with durable sentinels and a real dramatic boundary. Continue preserves facts through CampaignShell; the separately explicit replacement path resets exactly once. The current `BEGIN THE NIGHT` path should be a decisive red. |

Finally rerun successful composed boundaries under both real roots and the eleven player-route observations identified by the canonical save contract. A successful JSON read or a zero exit code alone does not establish location, physical answers, carried/spent state, or comprehensible continuation. This review does not reopen every historical TODO or convert semantic matrix labels into crash-recovery evidence.

## Source fingerprints

Current relevant owner sources are unchanged from HEAD; harness files may include the other agent's pending directory fixes. SHA256:

- `game/scripts/game/reality_game_state.gd`: `144a23b12a97dd49e716bcbd623a30c8d22b2659f4ad70bb924d902fea2788c2`
- `game/scripts/ui/title_screen.gd`: `b7d0e4cd4c73d483162f53894ef1835d34e7a493779d22007288e6f7e5eb9c00`
- `game/scripts/game_boot.gd`: `9d0fe3aa51a80eed6e19567b4c36a379fdb2aaec5b6a6a12f166aa4ca1fcd6a1`
- `game/tests/reality_save_compat_test.gd`: `4397353412fec1804168158fa59c6b56ff5950b0e49b7464177352149ce59a20`
- `game/tests/orison_v2_m08f_runtime_test.gd`: `ac7a13093c4931769668129aedf39a479e3490029dc8d9cd1c99761b88d7ed4d`
- `game/tests/orison_v2_m11a_first_exterior_cell_test.gd`: `ad3fc25fdd82a0c158b94aa05738986cb0165216e4765d7099b014e07b6d8e8c`
