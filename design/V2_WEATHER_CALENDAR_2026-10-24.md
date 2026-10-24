# A year with the weather: campaign calendar

Evidence class: **INERT**. Authored content, integration notes and diagnostics;
not a completeness-ledger claim, full-world runtime qualification or human acceptance.

The calendar covers **10 November 1928 through 9 November 1929**, the full
365-day playable newspaper year. It is **invented alternate-history weather**,
not a reconstruction of actual observations in Queens. The accepted opening
date and fixed Eastern Standard Time remain owned by CampaignClock.
The earlier suggestion of all 366 days of civil 1928 would omit most of the
playable campaign; it was replaced by this explicitly dated campaign year.

## Research and canon

The [National Weather Service chronology](https://www.weather.gov/timeline/)
documents public radiotelephone forecasts in 1921 and teletype becoming the
Weather Bureau's principal communications method in 1928. Its automatic
New York telephone service dates to 1939. These support a weather desk,
short dispatches and forecasts carried by signal; they do not support
quietly importing modern radar, satellites or a modern named-storm list.
The Bible's Rule of Signal permits advanced transmission, not omniscient
prediction or modern household machinery.

[NWS Central Park records](https://www.weather.gov/okx/centralparkhistorical)
provide the regional climatological context. They are not presented as
measurements of the fictional dates. The existing papers are the local
fictional chronology: their weather ears, heat episodes, overnight snow,
ice-cutting work, January thaw and autumn coal orders remain intact.
The [NYC coastal-storm profile](https://nychazardmitigation.com/documentation/hazard-profiles/coastal-storms/)
supports northeast winds and coastal precipitation as regional weather forms,
not a claim that a particular invented storm occurred historically.
[Contemporary New York commentary, January 1927](https://www.newyorker.com/magazine/1927/01/29/the-talk-of-the-town-civic)
describes coal smoke near the riverfront; the game's sepia haze is an art-directed
interpretation. No reference image is baked or committed.

## Narrative spine

- November: first coal, cold window glass, then the borough's unusually quiet snowy night.
- December: an ice harvest measured in inches; a thaw interrupts wages before Christmas snow.
- January: rain, river fog and the thaw that threatens next summer's ice supply.
- February: sharp light, wool drying slowly, then brief mild spells and rare coloured high cloud.
- March: pipes thaw, cornices drip, and the company finds weather a convenient explanation.
- April: umbrellas, soaked coat hems, drying paper; a clearing forecast fails and is corrected.
- May: the first open windows carry neighbours' voices; the first heat increases ice deliveries.
- June: sleeping outside, rising heat, then a dated late thunderstorm and relief.
- July: another sequence of hot days; the July 11 storm is authored at 21:45–23:10.
- August: six days of heat break under a bruised sky, fictional local hail and sudden rain.
- September: the first cool evenings and a rare stacked cloud worth stopping for.
- October: warmer afternoons against cold stairs; windows shut one by one.
- November: coal returns. The coat hook is familiar; the player has a year's experience of it.

Twenty dated chapters provide story hooks rather than new quests or case state.
Rare formations are scheduled, not randomized on load. Their visual quality
remains subject to the sky review's existing limitations; scheduling does not
make the weak asperitas/lenticular/nacreous renderings accepted.

## Existing owners

**CampaignWeather** is a cached pure projection, not a second clock or simulation.
The existing WeatherManager samples dated anchors at most once per real second,
only re-evaluating changed campaign minutes. Rendering still consumes
LiveWeatherService.presentation. The existing sky, lighting, particles and glass
receive the same conditions. Hail, coastal rotation, severe threat and rare
formation selection pass through the installed extension seam.

Date changes, rollover and reconstructed clock owners select the same facts.
Cloud movement and effect settling remain visual animation. No host date, network
request or independent saved weather epoch is introduced. Beyond the authored
year, seasonal fallback is explicit; the year's papers and events never repeat.
Explicit existing live/simulation overrides remain supported. Calendar-only
resident comments are suppressed during those overrides.

The newspaper catalogue attaches a detached report to a returned page; it never
rewrites shared front-page dictionaries. Reports use Fahrenheit, miles per hour
and inches of mercury, with E.S.T. issue and validity times. Each day has a morning
forecast and an evening outlook. Predictions retain their original wording after
a correction. An as-of timeline contains observed reports and already-issued
predictions only, and grants no knowledge by being queried.

Seventeen supported residents have distinct local remarks and sustained-weather
comments. Weather is an optional conversation branch, not an unsolicited speech.
Existing knowledge flags remember hearing a remark; no trust or case outcomes are
awarded. Comments draw on a window, garment, plant, instrument or errand and do not
reveal tomorrow's forecast. Sustained-weather clauses require at least three
campaign days and a matching three-day calendar trend. Mina's separately owned
case dialogue is preserved; it does not acquire this shared branch.

## Verification and issue log

Seven cross-owner Python tests pass, including full-year
continuity, immutable newspaper ears, forecast validity and byte-stable generation.
The data-consumption audit reports zero new unread fields. Original diagnostics,
failed runs and lane receipts remain under the external integration report root.

| Location | Reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|---|
| Weather owner | Advance campaign date offline | Medium | Original seasonal fallback repeats a monthly ideal | Dated daily anchors through existing clock and normalizer | 395-check focused Godot diagnostic passes |
| Newspaper desk | Compare forecast with later weather | Medium | No structured issue/validity history | Retain issued predictions and later corrections beside observations | 395-check focused Godot diagnostic passes |
| Resident conversations | Discuss a sustained weather spell | Low | Existing dated news opinions have no local weather branch | Optional voiced-character text, existing heard-flag authority | 395-check focused Godot diagnostic passes |
| News rack | Request evening edition before its dispatch | Medium | Existing rack offers both editions all day | Morning 06:00/evening 17:00 publication gate, rechecked on taking a paper | Publication-time checks pass in the focused diagnostic |

No full-world performance improvement is claimed. The preceding weather A/B
baseline failed at the existing front-door input stop before its route completed;
its frames are diagnostic only. Whole-world V2 route, surface and save renewal
remain outstanding independently of this content pass.

The first calendar batch was withdrawn while still waiting for the lane; no
Godot process started. Offline review of the official engine parser established
that its date/time conversion needs seconds, so report timestamps now append
`:00` for conversion. The pre-1970 continuity guard uses an explicit previous-date
flag, not a nonnegative Unix-time assumption. The subsequently launched v3 fixture had two inferred-type parse errors; its
failed source and wrapper receipt are retained. V4 executed 395 checks and failed
two fixture checks: its 3 p.m.-only regime sample missed fog/late storms, and its
shader path named the wrong directory. Its result and original capture are
retained. V5 corrects those fixture defects and passes 395 checks. No old result
or receipt was rewritten.


## Final focused diagnostic, v5

The test-written **calendar_test.json** reports 395 checks and no failures.
It exercises all 365 dated days, as-of issue times, a retained wrong prediction
and correction, Gregorian year rollover, reconstructed clock state, the production
WeatherManager/normalizer seam, hail/rare-formation event selection, immutable
newspaper owners, physical rack publication gates, local remarks and a guard
that prevents weather flags from changing case state or trust. The existing
LiveWeatherService and Newspaper suites also pass. All four v5 stderr files
are empty. These are scoped diagnostics, not a schema-2 runtime qualification.

**CampaignWeatherWorldReview** builds the occupied V2 world and changes only
its CampaignClock date/time. August 6, 1929 at 3 p.m. resolves to hail code 96;
September 19 at 6 p.m. to fair code 2; December 24, 1928 at 9 p.m. to snow code 73.
All retain **campaign-calendar** as source. The three images and newspaper page
were inspected individually. The review uses a static cinematic station above
the street and accelerates effect settling. It proves neither walking access to
that height nor movement/input performance. The v5 world wrapper records 152 seconds.

The hail view is a flat, low gray deck; the September view has readable warm
cloud edges and brick silhouettes, but no convincing stacked lens is established.
The snow view is subdued, with a visible horizon band; it does not establish
particle readability or whiteout quality. The existing rare-formation art limits
remain open. The calendar schedules the feature; it does not qualify its artistry.

Reports now print period-style dates and A.M./P.M., compass wind direction,
Fahrenheit, miles per hour and inches of mercury. The visible page retains the
old report beside the new forecast, with a readable original front page below.
At night, shared remarks read the existing director's sun direction rather than
praising daylight. Fog tonight and fog then clearing have distinct daily windows;
the July 11 temperature falls 22 degrees F. over the reported hour rather than instantly.

The archive is **art/reviews/v2_weather_calendar_20261024/archive.json**.
It preserves the failed v3/v4 sources and receipts, v5 test-written results and
four stills, original blocked performance attempts, and hashes of every archived
file. The raw calendar SHA-256 is
**e5cd3a6205f90fe72409363ce3cf175bff5a6fbeeb312a43df0fcaaa44f2c63d**;
new weather sources and artifacts are protected from checkout line-ending changes.
The calendar has 2,195 anchors, 730 issued bulletins and 20 narrative chapters.

The period-date audit explicitly classifies this pure campaign-clock consumer;
the four existing host-clock negative-control tests still pass. Four new
**test-only** spatial records were reviewed and appended, preserving all 10,709
existing manifest records and its original bytes outside the append. The eight
pre-existing reported fixtures remain reported; no failing or unresolved dependency
was reclassified. 1,573 import sidecars were restored only after exact LF-normalized
comparison proved their changes were line endings alone.

The optional year preview passed a Node DOM-stand-in check for 365 dates, 13 partial
civil months, selection and persisted selection restoration. Browser security
blocked its local-file preview; no browser layout acceptance is claimed and no
alternative browser route was attempted. This authoring aid never enters Godot.

Broader V2 qualification and performance work remain outstanding. Mina's
separate conversation owner remains untouched, dates after 9 November 1929 use
explicit seasonal fallback, and the incomplete street-route A/B yields no
weather performance comparison. PR 23 remains an integration candidate until
the separate route/save/surface renewal gates are satisfied.


## Developer report

REPORT - V2-WEATHER-CALENDAR - 2026-10-24

Branch / HEAD / origin/main / merge-base:
**codex/v2-main-integration-20261024 / 0eaa96ba / 5485fbb4 / 5485fbb4**
at verification launch; the named staged weather payload accompanies this report.
Worktree clean at end: **no**; generated untracked UID sidecars are preserved.
Only the named weather, diagnostic, report and reviewed-manifest paths are staged.
Protected 17/17: **yes**, with no weather change touching a protected owner.
Selector: **v2**, retaining the explicit V1 rollback.
Ledger before -> after (ABSENT / ANCHOR_ONLY / SHELL_ONLY / PROGRAMMED /
SPATIALLY_PROVEN / RUNTIME_PROVEN / HUMAN_ACCEPTED):
**4 / 0 / 0 / 122 / 86 / 27 / 1 -> 4 / 0 / 0 / 122 / 86 / 27 / 1**;
requirements_changed: **[]**.
The completeness audit remains INCOMPLETE; this inert report promotes nothing.

Gates: full board **104 PASS / 7 FAIL / 1 INCOMPLETE**. Period, reader, spatial,
systemic, rulings, native import policy and the seven new tools tests pass.
Reader has **zero new unread fields**. Against the complete clean 5485 main board,
the only remaining regression is the already-open surface contract that does
not bind the current surface test (defects 2 -> 3). No clean-candidate or merge-ready
verdict is claimed. The full board, comparison and clean main board are archived.

Godot: v5 Calendar 395 PASS checks; LiveWeatherService PASS; Newspaper reports
**0 failures**; occupied-world review has **no failures** and three source/date
matches. Every run has its archived named LogPath and wrapper receipt; the
calendar/world diagnostics write their own results. All four stderr files are
empty. Original v3/v4 failures remain in the same packet. These are diagnostics,
not schema-2 runtime-contract receipts.

Numbers: 365 days, 2,195 weather anchors, 730 issued bulletins, 20 chapters,
17 shared resident profiles; three inspected world images plus one newspaper.
Changes outside the content boundary: period audit adds one explicit authored-clock
consumer; spatial manifest appends four reviewed test-only references and preserves
all existing records. Both changes are visible review instruments, not a rebase of
failed gameplay or material evidence.

Open findings: full-world route/save/surface renewal, failed door-input performance
baseline, rare sky-shape/readability limits, Mina's separate conversation owner,
and seasonal fallback beyond the authored year. No new acceptance or speed claim.
Decision needed from owner: **none**.

BLOCKED merge qualification: renew the independent route, save and surface gates.
