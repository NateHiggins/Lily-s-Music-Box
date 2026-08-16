# ORISON SONGBOOK AUDITION MANIFEST — Ballroom’s_False_Collapse

*Per the House Five book (`design/ORISON_SONGBOOK_GEMINI_LYRIA_
HOUSE_FIVE.md`). Fields marked `OWNER:` need the owner's entry from
the Gemini UI or their audition; everything else verified locally,
2026-08-14 (second processing pass — this file was found unlogged
beside the Moonlight candidate).*

```
track id:                  OWNER: unconfirmed — same Gemini session
                           as the track_101 Moonlight run (11:46);
                           duration sits near the Dreamland spec but
                           the measured meter does not (see below)
promptbook revision:       f374287 current at generation time
prompt used:               OWNER: which prompt ran? verbatim / edits
score attached:            OWNER: confirm (list pages, or "none")
historical recordings:     NONE USED — OWNER confirm: ____
gemini/lyria product:      OWNER: app tier / model shown by UI
model displayed:           OWNER:
generation date:           2026-08-14 (file mtime 12:08)
output filename:           Ballroom’s_False_Collapse.mp4
                           (H.264 + AAC 197 kbps 44.1 kHz stereo,
                           2:37.3; audio extracted to 48k WAV)
length cap encountered:    apparently none (full-length delivered)
synthid / ai disclosure:   presumed embedded — OWNER: note the UI
                           disclosure text
legal status:              inherits the confirmed track's §13 status
                           (track_101 = GREEN)
consultation status:       n/a if track_101
owner audition result:     OWNER: attach the House Five rejection
                           checklist (10 items, full performance)
rejection reason:          OWNER: —
selected candidate:        OWNER: —
production decision:       OWNER: —
```

## Local objective pre-checks (not a substitute for ears)

| Check | Result |
|---|---|
| Duration vs Dreamland spec (~2:41) | **2:37.3 — within 2.3% of spec.** Full-length form delivered |
| Meter/tempo (spec: 3/4 at 96) | **OFF SPEC.** Onset grid of ~0.46 s units (eighths of a ~65 BPM quarter, or a ~130 BPM duple feel) with the strongest grouping at the half-note (1.845 s) — no 96-BPM waltz signature anywhere in the autocorrelation. The identical analysis recovers Moonlight's 95.3 BPM ×3 bar lattice, so the method detects waltzes where they exist. If this ran House Five §1, checklist item 2 fails |
| Ending (no fade-out) | Music ends ~156.5 s with 0.8 s tail; the last ~5 s decay steadily −20 → −53 dBFS — **could read as a mixed fade**; check by ear against the no-fade rule |
| Sub-bass (none allowed) | **CAUTION:** sub-50 Hz only 6.5 dB under full-band RMS (Moonlight measures 13.7 dB under with identical settings) — listen for synthetic sub vs honest tuba/room rumble |
| Loudness | −13.0 LUFS integrated, LRA 9.3 LU — warm, honest dynamic range |

## Derived files (this folder; NOT for game/assets)

- `Ballroom’s_False_Collapse.48k.wav` — extracted audio, recipe
  conversion.
- `..._base_return_x1335_PREVIEW.wav` — base alone through true
  varispeed ×1.335 (117.8 s = 157.30/1.335 exactly).
- `..._PREVIEW_matched.wav` — gain-matched −0.7 dB to the native
  master (gain only).
- `Ballroom’s_False_Collapse.NIGHTCORE_PREVIEW_x1335.mp3` — 256 kbps
  listening copy of the matched return preview.
- `..._base_return_x1414_PREVIEW{,_matched}.wav` /
  `..._NIGHTCORE_PREVIEW_x1414.mp3` — added 2026-08-15 for the Day-4
  **alternate title record** option: the title's second-record
  convention is pure varispeed ×1.414 (ESCAPEMENT FAILURE), so the
  disposition audition needs this ratio, not ×1.335. True varispeed
  (111.2 s = 157.30/1.414), gain-matched −0.8 dB to the native
  master (gain only).

**Preview caveat:** this is the BACKING alone at ×1.335. Checklist
items 9–10 are judged only on base + scratch vocal as one complete
take. Given the off-spec meter, owner ear time is better spent on
the Moonlight candidate first.

## Disposition — pending (2026-08-15)

Unassigned: off-spec for Dreamland, and its sibling take (The
Clockwork Waltz) won the provisional title slot. Owner options:
retire, hold as a FUTURE VOLUME texture reference, or audition as an
alternate title record. See `design/ORISON_SONGBOOK_BRIDGE_PLAN.md`,
Day 4.
