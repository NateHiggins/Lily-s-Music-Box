# Clock consumer review for the first post-sanitation correction

**Historical source diagnosis.** The owner has since accepted November 10,
1928. The no-accepted-month/day finding below records the earlier state;
the [current calendar ruling](../../ORISON_CAMPAIGN_CALENDAR_RULING_2026-09-05.md)
now governs. Runtime findings below are evidence from the stated commit,
not a claim about the corrected implementation.

Read-only source review at **c2dc01771bc25b07f5dcf7a6040102345b8c57d5**. No product code, state, date configuration or tests changed; no Godot process launched.

## Calendar authority: what is actually ruled

The latest owner mandate permits the real local **time of day** at campaign creation and requires an independent authored/simulation starting date. The Bible §VIII.5.h fixes the starting **year at 1928**, but does not specify month, day or weekday. A full targeted search across design, authored data and runtime found **no accepted campaign month/day**.

There is an explicit older contrary instruction, not merely an accidental code assumption: `design/ORISON_V2_SHARED_FRAMES_RULING_2026-08-30.md:11–14,24–26` says to capture host date/time and deliberately declines a fictional starting date. The corresponding `game/data/orison_v2_shared_frames.json:26` prescribes host-sampled weekday. Both are superseded by the latest mandate and must be corrected with the consumer; do not leave an apparently binding old rule beside a new implementation.

Existing `CampaignClock.configure_start(day, doy, minute_of_day)` is a deterministic **test API**, not an accepted creative calendar choice. `admin_prereq_contract_test.gd:25` uses Friday, DOY100, 23:59 solely to test crossing into Saturday/DOY101. The ubiquitous 03:00 is a frozen rendering/test time and Open Shift's fallback origin; it supplies no campaign month/day.

The authored schedule is explicitly a **365-day non-leap date-key index**: `resident_schedules.json` meta.schema.special_days, `ScheduleDirector.doy_of():144–150`, and `design/ORISON_ARCHETYPE_SCHEDULES.md:1302–1303`. This is different from a Gregorian year: 1928 is a leap year. Do not silently reinterpret all date keys as leap-year DOY. Some dates are explicitly proposed, others source-grounded; none is the campaign's starting date.

Practical recommendation: add a named, validated authored calendar configuration and record its provenance independently from the sampled time. If a default is needed for a reversible development build before a creative calendar is selected, declare it visibly in the decision log as **provisional**, never as recovered owner canon. January 1 is a possible deterministic technical default, not a recommendation derived from fiction. There is no evidence here that licenses claiming a specific month/day has already been accepted. Injection and host-date independence can be proven without choosing public-facing season/anniversary behavior.

## Exact consumers and defects

| Consumer | Current behavior | Consequence |
| --- | --- | --- |
| `game/scripts/game/campaign_clock.gd:12–35` | `bind_state()` validates only weekday, initializes invalid weekday by reading host date/time, commits host weekday/DOY/epoch date. | Violates latest date separation. A corrupt clock with a valid weekday but negative/out-of-range other fields passes initialization. A missing epoch during reconstruction can silently sample a new host date. |
| `CampaignClock.configure_start():38–49` | Calls `bind_state()` before writing the explicit test epoch, then overwrites fields and commits again. | An explicit supplied epoch can cause an unnecessary host initialization/commit first. A red test should prove supplying configuration never needs host state. |
| `CampaignClock.day_info_at():98–109` | Adds `start_minute_of_day` to elapsed minutes; wraps DOY at 365; `first_sat` means Saturday with DOY ≤7. | The argument is **elapsed**, not time of day. First-Saturday monthly routines can trigger only in the first week of the year. Host leap-aware initial `_doy_of()` feeds a non-leap 365-day cycle, so post-February anniversaries can shift. |
| `game/scripts/building/day_night_director.gd:160–161,221–227` | Binds the campaign owner; advances its elapsed state from `_process` only when DAYNIGHT enabled and not forced. | In v1, a presentation director currently drives simulation time. Quality/visual test overrides also stop time. Preserve explicit test freezes, but define one campaign advance owner before moving time. |
| `game/scripts/characters/schedule_director.gd:74–75,102–116,127–160` | Binds the same RealityState clock; reads time/calendar, with explicit debug override paths. | Correct shared-state read seam exists. Its non-leap date-key mapping and daily chance seed must remain deliberate. Header's real-local-time wording is stale once date separation lands. |
| `game/scripts/building/orison_v2_runtime_root.gd:155–164,187–208` | Creates and injects a real observation ledger with `resident_is_home` based on loaded timetable. | **V2 already has presence injection.** Initial sanitation draft generalized v1 incorrectly; corrected in authority/debt docs and JSON. Preserve this integration. |
| `OrisonV2RuntimeRoot.resident_is_home():218–230` | Calls `campaign_clock.day_info_at(open_shift_ecosystem.now_minutes())`, then resolves timetable using ecosystem minute. | Passes wrapped time of day as elapsed: epoch minute is added twice when choosing the date/day, while timetable minute still comes from the different clock. At a late-night campaign start, a 03:00 situation reading can select tomorrow's weekday. |
| V2 campaign clock advancement | Root binds CampaignClock but has no `_process` advancing it; no DayNightDirector is composed here. | Campaign elapsed stays separate from the advancing Open Shift situation clock. Changing only the host-date initializer would leave V2 simulation/calendar wrong. |
| `game/scripts/game/open_shift_radiator_ecosystem.gd:68–76,82–99` | No provider in either root; uses 180 + durable situation elapsed, wrapped at 1440; accrues only after offer. | Situation time starts at 03:00 regardless of campaign time. A callable seam exists, but passing campaign time-of-day through it does not solve elapsed-duration loss across whole days. |
| `game/scripts/game/open_shift_situation.gd:114–138` | `elapsed_since()` uses modulo-1440 difference; injected `_minute_now()` is also wrapped. | A 24-hour absence aliases to zero; actor/situation durations need absolute campaign minutes, while display/schedule time needs wrapped minute of day. Converting this is a small owner/API contract change with save-field semantics, not just a label rename. |
| `game/scripts/reality/npc_observation_ledger.gd:132+`, `porter_actor.gd` | Timestamp/actor clients use the situation clock protocol. | Preserve observation provenance and actor catch-up while unifying units. Audit every caller before changing absolute/wrapped semantics. |
| `game/scripts/game/reality_game_state.gd:48,169–170` | Defaults/backfills an empty clock dictionary; loaded dictionaries otherwise merge. | New clock schema must validate initialization and reconstruction explicitly; legacy-save waiver permits a declared reset/migration, not silent host resampling or resetting valid new saves. |
| `tools/audit_systemic_situation_authority.py:598–604` | Entire `_initialize_epoch_from_host` function exempted from host-clock scan. | Audit green cannot detect the latest rule violation. Narrow to the allowed creation-time time-of-day read and retain a red fixture for host calendar persistence. |
| `tools/audit_period_dates.py:20–30` | Classifies clock's year access as `campaign_epoch_seed_only`, says host year is acceptable and hidden by PhoneOS. | Update current policy/provenance with the new clock. Hidden host-derived date is still disallowed by latest ruling. Do not merely delete a classification to suppress unexpected-consumer output. |
| `game/scripts/building/orison_v2_frame_contract.gd:33` | Checks frame unit/host-clock boolean; current frame JSON combines host_clock_allowed=false with authorized seed strings. | Frame schema should explicitly distinguish one-time local time-of-day sampling, authored calendar identity, absolute elapsed minutes and wrapped presentation time. |

## Meaningful red runtime proof

Existing `admin_prereq_contract_test.gd` tests only one explicit midnight crossing and same-dictionary reconstruction. It never proves host-date independence, real initialization, monthly/year behavior, disk reload or root time coherence.

Existing `orison_v2_presence_ledger_test.gd` usefully proves real V2 presence composition and home/corridor sight. It pins the situation origin and does not inject the campaign date/time. Its `_reconstructs_under(root_id,...)` does **not use root_id or instantiate either root**; it compares reloaded state only. Therefore its labels claiming reconstruction under two roots must not be cited as cross-root composed proof. It also deliberately pins the separate hearing-presence gap, so changing that behavior requires a new scoped proof.

The smallest coherent runtime suite should drive the production clock owner with an injectable creation-time provider and explicit authored calendar fixture, while writing an isolated `user://tests/` save path:

1. Two new campaigns, same authored date and 23:59 local time, wildly different host date fixtures: same campaign calendar and minute; provider called once. Old initializer must fail the date assertion, not fail solely because a new API is absent.
2. Explicit valid authored configuration initializes without reading host date and without an intermediate commit containing host state.
3. Advance two minutes: 00:01 on the next authored calendar day; reject backwards absolute time. Advance beyond 1440 minutes and prove elapsed duration is not lost while displayed minute wraps.
4. Save, destroy owner, mutate/disable provider, load isolated file and recreate owner: same elapsed/calendar/time with no host read. A second reconstruction must be identical.
5. Malformed epoch with valid weekday but invalid minute/DOY or nonfinite elapsed is refused/reconciled by explicit policy, without overwriting a recoverable file or silently sampling host calendar.
6. If Gregorian date support is included, test Dec31→Jan1, leap-day behavior and post-February schedule-key normalization. If retaining the authored 365-day schedule calendar in this slice, name that domain explicitly; do not claim Gregorian support. Test first Saturday of a later month so the current `doy<=7` defect demonstrably fails.
7. Composed explicit V2 test sets a late-night campaign start, advances across midnight with a known weekday-specific resident block, then observes. Require campaign calendar, situation timestamps and resident presence to agree. Test after a full-day absence and reconstructed root. This fails the current wrapped/elapsed call misuse.

Suggested mutation controls are narrow: restore the host-date seed, replace absolute elapsed with modulo1440, or use the wrong argument in V2 `resident_is_home`. Each should independently make the corresponding contract assertion and runner exit red. Remove each mutation before final green; preserve logs and exact artifact hashes. Coordinate all Godot calls through the runtime owner and shared lane.

## Recommended patch boundary

For an initial **clock contract correction**, change CampaignClock plus its authored config/contract and relevant audit policy; prove creation and file reconstruction first. Record that V2 clock composition remains a separate named consumer gap if it is not corrected in the same commit. For a **world-time coherence** claim, also bind both root compositions to one advance owner and one absolute campaign-time protocol, adapt situation/porter/ledger clients, and test actual root rebuilds. Do not call the narrower initializer patch the finished time ruling while production Open Shift still starts at independent 03:00 or loses elapsed days.
