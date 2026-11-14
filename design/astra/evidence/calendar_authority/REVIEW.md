# Accepted calendar contract and audit proof

The owner accepted Saturday, November 10, 1928. Current canon is
`design/ORISON_CAMPAIGN_CALENDAR_RULING_2026-09-05.md`; the Bible's exact
opening-date paragraph is amended, while the contrary August host-date
ruling and pre-acceptance research remain explicitly historical.

The shared-frame JSON and its real GDScript validator require the authored
calendar, fixed EST (-300 minutes), one local hour/minute sample, no host
calendar fields or later host clock reads, absolute elapsed minutes,
wrapped presentation time, Gregorian civil day-of-year and the retained
365-day schedule key. February 29 has schedule key 0; monthly first-Saturday
logic remains independent. The existing AdminPrereqContract harness now
contains 18 negative field mutations against that production validator.
This reviewer did not run Godot; runtime execution belongs to root's lane.

## Instrument changes

`audit_systemic_situation_authority.py` no longer exempts the whole old
`_initialize_epoch_from_host` function. The only campaign-owner exception
is a pure `_sample_local_minute_of_day` with exactly one
`Time.get_time_dict_from_system` call, no year/month/day/weekday access and
no durable write. Other civil host-clock reads, including player-facing
`Time.get_time_string_from_system()`, are actionable. Date/datetime reads flowing into durable state are
actionable, including through local aliases and named same-file helper
chains. Pure conversion of an authored Unix value into date fields is not
a host-clock read.

The approved non-world filename boundaries are the pure
`SongbookStore._new_id` and `PhoneCamera._new_photo_id` functions. Adding a
durable write to those helpers removes the exception; the test proves it.
The original broad `PhoneCamera.capture` mixed a date read and persistence;
root extracted the filename generator instead of suppressing the finding.
Songbook's `created` fact and PhoneOS date now consume the campaign clock.

`audit_period_dates.py` validates the exact accepted calendar JSON fields,
reuses the same host-calendar rule, and rejects PhoneOS host calendar
reads. CampaignClock is classified as authored-calendar authority.
HistoricalRadioNotice's new year consumer was separately inspected: it
compares injected campaign civil time to the authored effective date and
labels an encountered printed notice. It does not manufacture a heard
broadcast or resident knowledge. Its precise classification is
`observed_printed_historical_notice`.

These remain source heuristics, not a GDScript interpreter. Named same-file
flow is traced; arbitrary dynamic/cross-file aliases are not claimed as
complete data-flow proof. Once-only creation, reload, advancement and real
consumer behavior require the independent runtime tests.

## Captured controls

`integrated/receipt.json` records:

- Period CLI with persisted host calendar: exit **1**; authored source:
  **0**; changed campaign year: **1**.
- Systemic CLI with the same host-calendar defect: exit **1**; corrected
  authored source: **0**. Only synthetic mini-repository baselines are
  created by these controls.
- Eight focused host-calendar tests pass, including all four forbidden
  fields, repeated/persisting sampler, same-file helper flow, pure calendar
  conversion and filename-boundary negatives. The exact
  `organism_incidents.gd:_voice` time-string pattern fails while its
  CampaignClock replacement passes.
- All **42 systemic tests** and **four period tests** pass.
- Both integrated production audits exit **0**.
- The production systemic baseline SHA256 remains unchanged.

`pre_migration/` preserves the earlier integration read while root was
still replacing host-derived consumers. Those failures are retained and
are not described as a finished-candidate result. Reproduce the final
static controls with:

`python design/astra/evidence/calendar_authority/run_checks.py integrated`

No CampaignClock/calendar-data edits, Godot execution, staging or commits
were performed by this reviewer. Root and the runtime agent own production
clock/consumer changes and their runtime evidence.
