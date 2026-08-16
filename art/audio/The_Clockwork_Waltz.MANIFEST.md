# ORISON SONGBOOK AUDITION MANIFEST — The_Clockwork_Waltz

*Per the House Five book (`design/ORISON_SONGBOOK_GEMINI_LYRIA_
HOUSE_FIVE.md`). Fields marked `OWNER:` need the owner's entry from
the Gemini UI or their audition; everything else verified locally,
2026-08-14 (second processing pass — this file was found unlogged
beside the Moonlight candidate).*

```
track id:                  OWNER: unconfirmed — same Gemini session
                           as the track_101 Moonlight run (11:46);
                           duration sits at the Dreamland spec but
                           the measured meter does not (see below)
promptbook revision:       f374287 current at generation time
prompt used:               OWNER: which prompt ran? verbatim / edits
score attached:            OWNER: confirm (list pages, or "none")
historical recordings:     NONE USED — OWNER confirm: ____
gemini/lyria product:      OWNER: app tier / model shown by UI
model displayed:           OWNER:
generation date:           2026-08-14 (file mtime 11:59)
output filename:           The_Clockwork_Waltz.mp4
                           (H.264 + AAC 197 kbps 44.1 kHz stereo,
                           2:38.7; audio extracted to 48k WAV)
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
| Duration vs Dreamland spec (~2:41) | **2:38.7 — within 1.5% of spec.** Full-length form delivered |
| Meter/tempo (spec: 3/4 at 96) | **OFF SPEC.** Onset grid at ~0.428 s with 2× and 4× groupings dominant — a duple/quadruple pulse (~70/140 BPM feel), not a waltz. No 3/4-at-96 periodicity: the ~0.64 s beat candidate's ×3 grouping is its weakest. The identical analysis recovers Moonlight's 95.3 BPM ×3 bar lattice, so the method detects waltzes where they exist. If this ran House Five §1, checklist item 2 fails |
| Mid-piece dropout | ~2 s of near-silence at 150.5–152.5 s (down to −57 dBFS) followed by a full-level return — an authored grand pause or a generation dropout; ears decide |
| Ending (no fade-out) | Music ends ~158.0 s with 0.7 s tail; the final phrase decays −13 → −47 dBFS over ~4 s — plausible played ring-out; confirm by ear it is not a mixed fade |
| Sub-bass (none allowed) | **CAUTION:** sub-50 Hz only 6.1 dB under full-band RMS (Moonlight measures 13.7 dB under with identical settings) — listen for synthetic sub vs honest tuba/room rumble |
| Loudness | −12.3 LUFS integrated, LRA 12.9 LU — unsquashed, wide dynamics |

## Derived files (this folder; NOT for game/assets)

- `The_Clockwork_Waltz.48k.wav` — extracted audio, recipe conversion.
- `..._base_return_x1335_PREVIEW.wav` — base alone through true
  varispeed ×1.335 (118.9 s = 158.73/1.335 exactly).
- `..._PREVIEW_matched.wav` — gain-matched −0.7 dB to the native
  master (gain only).
- `The_Clockwork_Waltz.NIGHTCORE_PREVIEW_x1335.mp3` — 256 kbps
  listening copy of the matched return preview.

**Preview caveat:** this is the BACKING alone at ×1.335. Checklist
items 9–10 are judged only on base + scratch vocal as one complete
take. Given the off-spec meter, owner ear time is better spent on
the Moonlight candidate first.

## Disposition — 2026-08-15 (owner ruling)

**Promoted out of the track_101 audition: provisional title theme.**
The untouched original opens the title; `ESCAPEMENT FAILURE ×1.414`
(pure varispeed, nothing added after the speedup) is the optional
second record; completed streams alternate. Shipped masters, SHA-256
hashes and playback tests are recorded in `game/docs/title_screen.md`.
The Dreamland meter failure above is therefore moot — the duple
clockwork pulse is presumably what won it the slot. The OWNER fields
above (prompt used, score pages, model shown, SynthID text) are
still worth filling for the record.
