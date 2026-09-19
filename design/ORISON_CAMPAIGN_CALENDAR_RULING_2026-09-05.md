# Orison campaign calendar ruling — 2026-09-05 UTC

The owner accepts **Saturday, November 10, 1928** as the campaign's opening
date in Queens, New York. This amends the Bible's previously year-only
starting date and supersedes the host-date/weekday clauses of
`ORISON_V2_SHARED_FRAMES_RULING_2026-08-30.md`. The dated original remains
historical evidence; it no longer authorizes host calendar persistence.

## One creation-time clock sample

`game/data/campaign_calendar.json` is the authored calendar authority:
`schema_version` 1, year 1928, month 11, day 10, civil timezone
`America/New_York`, and authored UTC offset -300 minutes. The campaign uses
fixed Eastern Standard Time; astronomical conversion uses that offset and
does not consult automatic host daylight-saving rules.
Campaign creation may sample the player's real local hour and minute once.
That sampled minute of day is placed on the authored date; it is not a
conversion of the host's current date or timezone into historical Queens.
The permitted production seam is
`CampaignClock._sample_local_minute_of_day`, using
`Time.get_time_dict_from_system`. Host year, month, day and weekday cannot
choose or become durable campaign calendar facts, even inside that sampler.

After creation, accumulated simulation elapsed minutes govern time.
Calendar dates, schedules, presence, situational elapsed durations and
observations read that shared authority. Loading, changing roots, pausing,
opening a clock or changing the computer's clock must not capture a new
campaign epoch. Wrapped minute of day is a presentation/schedule value;
it is not elapsed time and must not be used to measure multi-day duration.

Civil dates use Gregorian leap years. `day_info().civil_doy` is the civil
day of year (315 on the accepted opening date). Existing schedule
`day_info().doy` remains the 365-day month/day key (314 on November 10),
preserving authored anniversary keys rather than shifting them after
February in leap years. February 29 has schedule key 0, meaning no recurring
authored 365-day anniversary key; civil day 60, weekday and monthly routines
remain valid. March 1 keeps schedule key 60 even when civil day is 61.
`first_sat` means the first Saturday of the current
month: Saturday and day of month at most seven. November 10 is not one.

## Real history reaches residents through the world

The owner permits real-world timeline events to enter the tale through
dated, source-supported world changes and actual observations: a changed
station assignment, an encountered newspaper, a heard broadcast or a
conversation whose speaker has a plausible source. A calendar trigger does
not itself give every resident knowledge. The existing observation,
audibility, presence and memory owners must carry that information.

The following morning's documented radio reassignment is a grounded
opportunity: revised US broadcast assignments took effect November 11,
1928 at 03:00 Eastern Standard Time. The [Federal Radio Commission
transmittal and table](https://www.thebdr.net/wp-content/uploads/PDF/Profiles/Broadcast-History/the-great-frequency-move-of-1928.pdf)
are reproduced in a radio-history transcription. [WNYC's archive](https://wnyc.org/story/1931-files/)
independently dates its new 570-kilocycle time-sharing with WMCA to that
day. The archive's surviving recordings discussed there are from 1931;
they are not authentic audio of the 1928 event.

Starting November 10 preserves the once-sampled time of day and places the
event ahead of every possible opening minute. It does not force a 03:00
opening, replay the event on demand or establish fictional broadcast
dialogue. Historical facts, suggested domestic scenes and actually
implemented content remain distinct. The research record is
`astra/reviews/campaign_date_research.md`; its source limitations remain
binding on claims of historical authenticity.
