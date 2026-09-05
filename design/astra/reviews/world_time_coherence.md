# World-time consumer review — 2026-09-05

The recorded consumer checks are green on the dirty composition based on `d729e4d8042c18a26920a8ce555ca6954651e257`. One `CampaignTime` autoload advances campaign time; both real waking roots use its durable campaign clock for unwrapped event time and schedule-aware presence. The change retains multi-day durations and rejects invalid calendars before publishing or composing a world. This is an engineering result with the migration and evidence limits below, not human acceptance or release readiness.

The machine aggregate is `design/astra/evidence/world_time_coherence/receipt.json`. Every case retains its exact command, fresh APPDATA path, source before/after hashes and binary diff, process status, wall time, raw stdout/stderr, and artifact hashes. All 18 cases have stable source within the case. Owned runtime source hashes match between the focused green and final two-root matrix; the final tested broad diff is `169b4ef30b5d30419ca0e7ef4410d6dac220b0799c263bbd68e6cc2ee054b31a`. Other agents' composed calendar, historical notice, and capture files are included in those source snapshots; this agent does not claim ownership of those edits.

## Ownership and behavior

`game/scripts/game/campaign_clock_driver.gd`, registered as `CampaignTime` in `game/project.godot`, is the only automatic advancement owner. It advances once per frame when at least one live eligible `building_root` exists, including when roots overlap. A paused tree, `CAMPAIGN_TIME_FREEZE=1`, or its deterministic test freeze hook stops advancement. Title/menu-only and Dream-only trees have no eligible waking root and therefore do not advance. Disabled, queued, off-tree, or failed roots do not authorize advancement.

`DayNightDirector` now reads campaign UTC for ephemeris presentation and retains the authored fallback when the clock returns no valid UTC dictionary. It does not advance the clock or consult the host calendar. `ScheduleDirector.minute_now()` reads the campaign clock, with its explicit `SCHEDULE_MINUTE` test override retained. Sky overrides do not change that query. The old default that `DAYNIGHT=0` disables resident dispatch when `SCHEDULE` is unspecified remains for compatibility with existing harnesses; this does not freeze `CampaignTime`. Full removal of presentation/dispatch coupling is not claimed.

Both `BuildingRoot` and `OrisonV2RuntimeRoot` bind the campaign clock before composition and provide `absolute_minutes()` to the ecosystem and observation ledger. Their resident presence callbacks query the actual schedule using `day_info()` and `minute_of_day()`. In particular, V2 no longer uses a stale situation-local minute to decide whether a resident is home. Invalid calendar state produces `startup_failed` before ecosystem or knowledge creation, and `CampaignShell` refuses to publish that failed root or complete a Dream return against it.

`OpenShiftRadiatorEcosystem`, `OpenShiftSituation`, and `NpcObservationLedger` retain unwrapped event timestamps. Elapsed time uses direct nonnegative subtraction rather than modulo 1440. New records identify their clock basis. `PorterActor` receives that same basis and holds ambiguous old deadlines. Lightweight isolated fixtures retain their existing fallback monotonic simulation provider; production roots inject the campaign provider explicitly.

## Evidence and controls

All runs used the unchanged serial Godot runner, headless Godot 4.7.1, and fresh task-local APPDATA directories. The runner did not create `user://tests`; harnesses create their required parent with a checked result. Hardware context was RTX 4080 / i7-13700KF. Elapsed values below are process wall time, not gameplay performance measurements.

| Case | Exit and result | Scope / diagnostics |
|---|---|---|
| Preserved old duration source | 3; 1/4 checks | Source compiles, then the three intended duration/timestamp checks fail. Exact child status retained. |
| Preserved old V2 presence source | 1; 5/6 checks | Source compiles, then Saturday 20:00 presence fails against its stale 03:00 provider. |
| WorldTimeCoherenceTest | 0; 27/27; 3.947 s | Durations, ownership, overlap, pause/freeze, schedule queries, migration, real invalid-root refusal, and real V2 binding. Two deliberately expected calendar-refusal error messages; no retention diagnostics. |
| OpenShift situation / authority / ignore / abandon | 0 each | Focused contracts pass; no diagnostic headers. |
| OpenShiftSaveMatrix final | 0; 17/17; 1.531 s | Isolated semantic assembly and JSON save/load, not real-root reconstruction. No diagnostic headers. |
| V2 presence ledger | 0; 17 checks; 2.275 s | Absolute timestamp and campaign presence fixture. Its cross-root helper reads the same save document; it does not instantiate both roots. |
| M08F runtime | 0; 29 checks; 2.624 s | Composed V2 runtime/lifecycle, no diagnostic headers. |
| M11A first exterior cell | 0; 40 checks; 21.500 s | First-cell scope only, no diagnostic headers. |
| Actual two-root matrix | 0; 26 checks; 92.763 s | Real V1/V2 initial roots plus all four CampaignShell reconstruction directions. One expected invalid-selector warning and five existing `cam_noel_witches` placement warnings; no save errors, engine errors, or retention diagnostics. |

The original first two negative controls used a PowerShell invocation that normalized nonzero child status to 1. Their raw outputs remain preserved, but the later `legacy_duration_exact_exit` and `legacy_presence_exact_exit` receipts supersede their process-status interpretation. The helper now explicitly propagates `$LASTEXITCODE`. The first focused green exited 0, so its successful status is unaffected by that normalization behavior.

The first save-matrix run on a new profile failed 16 writes because its save parent did not exist. Checked directory creation removed those warnings. A subsequent diagnostic isolated the remaining 16 equality failures to the new schema field changing from GDScript integer `2` to JSON float `2.0`; the persisted values otherwise matched in that printed sample. The final harness compares expected and restored persistence facts after the same JSON normalization. This adjusts the comparison to the actual serialization boundary while preserving all keys and values. All red and diagnostic receipts remain beside the final green.

One presence invocation used nonexistent `OrisonV2PresenceLedgerTest.tscn` and exited 1 with resource errors. It is classified as an invocation error, retained without pretending it is a product regression, and superseded by the successful lowercase `orison_v2_presence_ledger_test.tscn` run.

## Explicit limits and next proof

Legacy wrapped timestamps retain original values and an unresolved historical-day annotation. The migration does not invent an epoch for old evidence or fabricate neglect, abandonment, or porter eligibility. A newly attested attention event can establish its own valid deadline while the older facts stay unresolved. An existing legacy porter intent with an ambiguous deadline may remain held indefinitely because the actor refuses another intent. Recovery by an explicitly observed new fact is open debt; this migration is not claimed fully playable.

Invalid-calendar tests prove startup refusal and absence of active ecosystem or knowledge writes. `CampaignShell` currently has no player-facing recovery UI for that refusal. Recovery behavior belongs to the subsequent save/title work.

The current 26-check actual matrix adds an absolute-provider and single-owner assertion for each initial root, and preserves the existing four-direction semantic save/reconstruction proof. It does **not** assert exact calendar epoch/start/elapsed preservation in each direction. A root-owned focused calendar test separately exercises clock persistence; these scopes must not be combined into an unperformed four-direction assertion.

At the root's request, `design/astra/reviews/pending_two_root_calendar.patch` is prepared outside game and `git apply --check` passes. It is **not applied and not run**. Its matching JSON metadata records the exact base source hash and patch hash. It freezes `CampaignTime`, seeds 1928-11-10 at 23:59 plus 181.5 elapsed minutes, and plans one additional assertion per real-root direction covering the exact JSON clock record and real bound destination calendar (Sunday 1928-11-11 03:00:30). The intended future total is 30 checks. The current 26-check receipt remains immutable.

The focused presence suite retains its known absent-resident `in_home_hearing` capability gap. This world-time repair does not resolve that separate observation defect. No screenshot, actual player camera, human traversal, visual acceptance, broad M11 route acceptance, or performance release claim is made here.

## Changed files owned by this task

Production: `game/project.godot`; `game/scripts/game/campaign_clock_driver.gd`; `game/scripts/building/day_night_director.gd`; `game/scripts/building/building_root.gd`; `game/scripts/building/orison_v2_runtime_root.gd`; `game/scripts/characters/schedule_director.gd`; `game/scripts/game/open_shift_radiator_ecosystem.gd`; `game/scripts/game/open_shift_situation.gd`; `game/scripts/characters/porter_actor.gd`; `game/scripts/reality/npc_observation_ledger.gd`; `game/scripts/dream/campaign_shell.gd`.

Harnesses: `game/tests/WorldTimeCoherenceTest.tscn`; `game/tests/world_time_coherence_test.gd`; `game/tests/orison_v2_presence_ledger_test.gd`; `game/tests/orison_v2_two_root_matrix_test.gd`; `game/tests/open_shift_save_matrix_test.gd`; `game/tests/schedule_live_probe.gd` (comment correction).

No staging or commit was performed. Godot lane and source freeze were explicitly released to `dream_forensics` after the final matrix process completed. The pending matrix extension was prepared without modifying game while that agent's runs were active.
