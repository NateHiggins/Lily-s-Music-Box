# Historical radio notice: independent review

Reviewed `historical_radio_reallocation.json`, `HistoricalRadioNotice`, the
new control on `LobbyBulletinBoard`, and its focused runtime-test source.
No board/helper/data edits or Godot execution by this reviewer.

## Resolved finding

The new board control initially returned `[E]  Read wireless tuning notice`.
The real prompt-carrier audit rejected exactly that new legacy carrier.
Root changed it to the semantic `Read wireless tuning notice`; the subsequent
audit exits 0 (`evidence/calendar_authority/notice_prompt_review/prompt_after.stdout.json`).
The previously reviewed general board prompt is unchanged. No prompt or
spatial baseline was enlarged to absorb the new interaction.

## Source and interpretation bounds

The effective date/time, WEAF 660, WJZ 760, WOR 710, and WNYC/WMCA 570 with
divided time were rechecked directly in the [FRC transmittal/table
transcription](https://www.thebdr.net/wp-content/uploads/PDF/Profiles/Broadcast-History/the-great-frequency-move-of-1928.pdf),
PDF pages 3–6. It is correctly identified as a transcription of a government
document hosted by a radio-history publisher, not a government-hosted scan.
The original licenses' stated expiration is February 1, 1929; this artifact
is a dated notice about the November change, not a perpetual claim about
current station licensing or programme availability.

The before-assignment provenance retains the research's access limits:
WEAF 610 from the FRC's June 30 list; WJZ 660 and WOR 710 from contemporary
AP reporting. A newly located contemporary [Official Radio Log for
1928–1929](https://www.worldradiohistory.com/Archive-Radio-Logbooks/Official-Radio-Log-1928-1929.pdf)
also has old/new frequency columns for the November 11 change (printed
pages 22–24). Its indexed text corroborates WEAF's 610-to-660 movement;
direct screenshot retrieval returned HTTP 403, so this review does not
claim visual verification of that scan or add it to product provenance.

The hand-copy and its lobby posting are explicitly authored fiction.
Neither source data nor returned card asserts a particular broadcast,
programme hour, voice recording, blackout or resident reaction. The shared
frequency is qualified by the absence of programme hours. The physical
sheet retains both before/after columns; inspection changes the dated
interpretation rather than rewriting the sheet at 03:00.

`copy_at` uses injected civil year/month/day and minute, not the legacy
schedule day-of-year. Missing civil time returns an unresolved reading
with the printed effective date intact. Root also added a finite-minute
guard after this review began. The helper has no clock advance, work/case
mutation, knowledge write or audio playback. The board reuses its existing
paper tap and creates no allegedly historical broadcast.

The focused test source covers the exact 02:59.999/03:00 boundary, a wrong
legacy schedule key, reconstruction, unresolved time, the physical control's
ray priority, the existing service-wire presenter, static printed columns
and unchanged clock/NPC observation facts. These are useful component
claims; they do not certify a human can read the sheet in the composed lobby
or that a resident has observed it. Those remain separate runtime/visual
claims for the production lane. No remaining source-level blocker was found
within this notice's stated scope after the semantic prompt correction.
