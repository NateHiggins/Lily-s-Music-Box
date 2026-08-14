# ORISON SONGBOOK AUDITION MANIFEST — Ribbons_on_the_Banister

*Per `design/ORISON_SONGBOOK_GEMINI_LYRIA_PROMPTBOOK.md` §7. Fields
marked `OWNER:` need the owner's entry from the Gemini UI or their
audition; everything else was verified locally on 2026-08-14.*

```
track id:                  track_101 (DREAMLAND — assumed from "first
                           track"; correct me if this ran a different
                           prompt)
promptbook revision:       990047e
prompt used:               OWNER: confirm — promptbook §0 (the
                           then-current 30-second hook, superseded
                           by the full-length revision) or other;
                           note any edits. Future runs use the
                           PRIMARY FULL-LENGTH BASE prompts
score attached:            OWNER: confirm — Levy Collection 189/119
                           notation pages? (list pages actually
                           attached, or "none")
historical recordings:     NONE USED — OWNER confirm: ____
gemini/lyria product:      OWNER: app tier or API model shown by UI
model displayed:           OWNER: (e.g. lyria-3-pro-preview)
generation date:           2026-08-14 (file mtime 10:36)
output filename:           Ribbons_on_the_Banister.mp3
                           (MP3 192 kbps, 44.1 kHz stereo, 58.93 s —
                           app download; if this candidate is kept,
                           prefer a WAV regeneration via the API)
synthid / ai disclosure:   presumed embedded per Google docs —
                           OWNER: note the UI's disclosure text
legal status:              GREEN (Music Bible §13; track_101)
consultation status:       n/a for this track (Q6 does not gate it)
owner audition result:     OWNER: attach the §3.1 eleven-item sheet
rejection reason:          OWNER: —
selected candidate:        OWNER: —
production decision:       OWNER: —
```

## Local objective pre-checks (not a substitute for ears)

| Check | Result |
|---|---|
| Duration vs hook spec (~30 s) | **58.9 s — about double the ask.** Not disqualifying for a hook audition (more material to judge); the FULL base is where duration is held to spec |
| Meter/tempo (spec: 3/4 at 96 BPM) | **Consistent with spec.** Onset autocorrelation shows the bar period at 1.87 s (= 96.3 BPM in 3/4), a strong half-bar pulse, and eighth-note subdivision — a waltz envelope, bar-rate on target |
| Ending (spec: no fade-out) | Full level (−15 dB RMS) until 58.3 s, then stop — consistent with a clean close, not a long fade. Confirm by ear |
| Sub-bass (constraint: none) | Energy below 50 Hz is ~12.5 dB under full-band RMS — no synthetic sub signature |
| Loudness | Integrated −11.7 LUFS, LRA 5.5 LU — dynamics present, but on the warm/hot side for a 1920s room fiction; weigh under "no accidental modern production" by ear |

## Derived audition files (in this folder; NOT for game/assets)

- `Ribbons_on_the_Banister.48k.wav` — recipe step 5 conversion.
- `Ribbons_on_the_Banister.base_return_x1335_PREVIEW.wav` — the base
  alone through true varispeed ×1.335 (44.14 s = 58.93/1.335 exactly).
  **Preview only:** the real return test (§3.4) is judged on base +
  scratch vocal as one take; do not score the last two sheet items on
  this file.
- `..._PREVIEW_matched.wav` — the same, gain-matched −0.6 dB to the
  native master's −11.7 LUFS for fair A/B (gain only, no dynamics).

## What cannot be verified without ears (the owner's audition)

Recognizable source melody against the Levy score; fully instrumental
(no buried hums/voiced artifacts); cornet guide present and
subordinate; open 4-bar vocal phrases; period instrumentation without
substitutions; no fake old-recording effect. Then the scratch-vocal
take and its ×1.335 return for the final two sheet items, including
the 2007 test.
