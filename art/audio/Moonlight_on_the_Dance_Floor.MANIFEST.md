# ORISON SONGBOOK AUDITION MANIFEST — Moonlight_on_the_Dance_Floor

*Per the House Five book (`design/ORISON_SONGBOOK_GEMINI_LYRIA_
HOUSE_FIVE.md`). Fields marked `OWNER:` need the owner's entry from
the Gemini UI or their audition; everything else verified locally,
2026-08-14.*

```
track id:                  track_101 (DREAMLAND — assumed; correct
                           me if this ran a different prompt)
promptbook revision:       f374287 (House Five §1 primary)
prompt used:               OWNER: confirm House Five §1 verbatim /
                           note any edits
score attached:            OWNER: confirm — Levy 189/119 notation
                           pages? (list pages, or "none")
historical recordings:     NONE USED — OWNER confirm: ____
gemini/lyria product:      OWNER: app tier / model shown by UI
model displayed:           OWNER:
generation date:           2026-08-14 (file mtime 11:46)
output filename:           Moonlight_on_the_Dance_Floor.mp4
                           (H.264 + AAC 195 kbps 44.1 kHz stereo,
                           2:37.7; audio extracted to 48k WAV)
length cap encountered:    apparently none (full form delivered)
synthid / ai disclosure:   presumed embedded — OWNER: note the UI
                           disclosure text
legal status:              GREEN (Music Bible §13; track_101)
consultation status:       n/a for this track
owner audition result:     OWNER: attach the House Five rejection
                           checklist (10 items, full performance)
rejection reason:          OWNER: —
selected candidate:        OWNER: —
production decision:       OWNER: —
```

## Local objective pre-checks (not a substitute for ears)

| Check | Result |
|---|---|
| Duration vs spec (~2:41) | **2:37.7 — within 2% of spec.** Full form delivered |
| Meter/tempo (3/4 at 96) | **On spec.** Bar period 1.87–1.88 s = 95.7–96.3 BPM in 3/4; strong half-bar pulse; eighth-note subdivision — a waltz envelope at the asked tempo |
| Ending (no fade-out) | Music ends ~155.8 s with 1.8 s natural silence tail; the last ~6 s settle to −26.8 dB RMS — reads as a graceful ritard/tag decay. Confirm by ear that it is a played close, not a mixed fade |
| Sub-bass (none allowed) | Sub-50 Hz ~13.7 dB under full-band RMS — no synthetic sub |
| Loudness | −11.4 LUFS integrated, LRA 7.2 LU — warm but with honest dynamic range (better spread than the first candidate) |

## Derived files (this folder; NOT for game/assets)

- `Moonlight_on_the_Dance_Floor.48k.wav` — extracted audio, recipe
  conversion.
- `..._base_return_x1335_PREVIEW.wav` — base alone through true
  varispeed ×1.335 (118.1 s = 157.66/1.335 exactly).
- `..._PREVIEW_matched.wav` — gain-matched −0.5 dB to the native
  master (gain only).
- `Moonlight_on_the_Dance_Floor.NIGHTCORE_PREVIEW_x1335.mp3` —
  256 kbps listening copy of the matched return preview.
- `Moonlight_return_x1414.wav` — the same base through ×1.414 (the
  heavier alternate ratio), cut for comparison.
- `Moonlight_HAUNTED_FLOOR_x1335.{wav,mp3}` /
  `Moonlight_HAUNTED_FLOOR_x1414.{wav,mp3}` — owner-requested
  direction test (2026-08-14): heavy bass beat + ghostly distortion
  over the returns. Synthesized 55 Hz kick on every returned beat
  (kick1335/kick1414.wav), sidechain pump, drive into soft clip,
  slow pitch-wobble, dark 210/440 ms echoes; sub-60 Hz −28 →
  −14.5 dB RMS, −9.8 LUFS. **Not canon:** Music Bible §5.2 refuses
  post-speedup additions, so shipping this sound needs the owner's
  house-rig ruling (TASKS.md G7).

**Preview caveat:** this is the BACKING alone at ×1.335. The real
return — and the checklist's items 9–10 — are judged on base +
scratch vocal as one complete take. The chipmunk voice this system
is built around isn't in this file yet, because it's yours.
