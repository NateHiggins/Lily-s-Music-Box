# November 10 campaign integration

The owner selected November 10, 1928. New campaigns use that Saturday in
Queens, with a single sample of the player's local hour and minute. The
campaign date, weekday, seasons, displayed civil time and elapsed duration
then derive from the saved CampaignClock. The current authored zone is fixed
EST (UTC−05:00); seasonal offset changes are not implemented.

## Production consumers and scoped evidence

CampaignTime advances one shared clock only while a live building root exists.
Both roots, schedules, celestial lighting, visible clock props, PhoneOS, journal
text and Open Shift duration consumers read it. Gregorian dates and the existing
365-key schedule convention are explicit; February 29 has no anniversary key.
Old ambiguous wrapped duration facts retain their original data and are marked
unresolved rather than acquiring invented days of neglect.

The lobby has a physical hand-copy of the November 11, 03:00 EST radio frequency
reallocation, with verified station frequencies and campaign-time-specific
inspection copy. It asserts neither programme hours nor an invented broadcast.
This is one V1 player-readable source, not resident knowledge or V2 integration.

Evidence paths are relative to `design/astra/`:

| Gate | Actual result and scope |
| --- | --- |
| Old host-calendar baseline | `evidence/campaign_calendar/baseline_red/run.log`: exit 1 |
| Calendar | `evidence/historical_radio_notice/protected_bind_green/run_receipt.json`: 52/52, exit 0, 0.881 s; one deliberate future-save warning |
| Protected clock red | `evidence/historical_radio_notice/protected_bind_red/run_receipt.json`: 51/52, exit 1 before the refusal guard |
| Midnight precision red | `evidence/historical_radio_notice/calendar_clamp_omitted/run_receipt.json`: 49/50, exit 1; exact restored source retained |
| World-time coherence | `evidence/world_time_coherence/receipt.json`: 27/27 focused; old duration and absent-resident sight controls fail correctly |
| Composed reconstruction | Same receipt: 26/26 across four root directions, exit 0, 92.763 s; proves providers and fact reconstruction, not yet exact epoch preservation at every direction |
| Admin contract | `evidence/historical_radio_notice/admin_01/run_receipt.json`: 29/29, exit 0 |
| Notice | `evidence/historical_radio_notice/runtime_visual_validation.json`: 17/17, exact teardown-omission red; final live-neighbour audio ownership check clean |
| Actual lobby | `evidence/historical_radio_notice/capture_03/run_receipt.json`: three readable frames using the actual player's interaction ray; teleported camera, Dummy audio, no walked-input or listening claim |
| Static authority | `evidence/calendar_authority/integrated/receipt.json`: both selected audits exit 0; 42 systemic and 4 period fixtures; unchanged baselines |

The calendar has 52 checks after the notice agent's 50-check aggregate. The two
protected-bind receipts are an explicit supplement, not a rewrite of that earlier
evidence. All times above are whole fixture process times, not frame-time budgets.

## Open defects and limits

- V1 Forward+ capture exits 0 but still emits 261 soft-shadow-count and 1,252
  light-unpair engine BUG diagnostics at teardown, plus loader/RGB warnings.
  It is not a clean runtime or human visual acceptance. Exact engine/source
  attribution remains under investigation.
- Resident sight now respects absence. The existing audible-event path still
  admits observations while a resident is away; this separate gap remains open.
- MaintenanceInventory acquired/consumed timestamps, WorkOrders issued/closed
  timestamps, organism report timestamps and NightRegister line timestamps still
  store host Unix time. They need campaign-time values with explicit provenance;
  the present audit intentionally has not been credited with closing this gap.
- A legacy porter intent with an ambiguous nonempty deadline may hold indefinitely.
  A recoverable authored resolution is still required.
- General corrupt-save recovery, ordinary title Continue, checked crash recovery,
  all dramatic-boundary reconstruction, native atomic replacement, V2 placement,
  actual resident learning, authentic radio delivery and human review remain open.

The next production milestone is protected save recovery and a genuine Continue
action, followed by exact calendar preservation through both root reconstructions.
The default selector remains V1. No quarantined branch adoption, public release,
renderer change or V1 retirement is authorized or implied by this integration.
