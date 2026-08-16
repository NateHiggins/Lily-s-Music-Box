# Songbook delta brief — 2026-08-15 → 08-20 (RUNNING LOG)

*The Day-5 deliverable of `design/ORISON_SONGBOOK_BRIDGE_PLAN.md`, kept as a
running log so re-entry day is a read, not an archaeology dig. Hand the
returning support model the original handoff prompt (chat, 2026-08-14,
f2caedc era) plus this file. Append entries; do not rewrite history.*

## 2026-08-15

- **Owner ruling — provisional title theme.** The Clockwork Waltz opens the
  title untouched (2:38.7); `ESCAPEMENT FAILURE ×1.414`, pure varispeed with
  nothing added after the speedup, is the optional second record. Masters,
  hashes, trims and tests: `game/docs/title_screen.md`. Its Dreamland meter
  failure is moot; it is out of the track_101 audition.
- **Owner clarification — dream secrecy binds the title screen only.** It does
  not prohibit designing or building the production dream. (Game lane
  consequence: N2–N6 landed; see git history.)
- **Bridge plan written** (`design/ORISON_SONGBOOK_BRIDGE_PLAN.md`): the lane
  is blocked only on three owner inputs — rule G7 by ear (shipped pure
  ESCAPEMENT FAILURE vs rigged `Moonlight_HAUNTED_FLOOR_x1335.mp3`), audition
  Moonlight against the Levy score (checklist 1–8, MANIFEST OWNER fields),
  record one full-length scratch vocal over
  `art/audio/Moonlight_on_the_Dance_Floor.48k.wav`.
- **Day-1 agent step tooled and proven.** `art/audio/songbook_scratch_return.py`
  turns base + scratch vocal into the complete take, true-varispeed return,
  gain-matched preview and 256 kbps listening copy in one command. Base-only
  self-test reproduces the 08-14 Moonlight preview exactly (118.100 s, −0.5 dB
  match). Its `--rig` flag approximates the HAUNTED_FLOOR chain (−10.6 LUFS vs
  the prototype's −9.8) and is explicitly non-canon pending G7.
- **Days-2/3 candidate processing tooled and validated.**
  `art/audio/songbook_candidate_precheck.py`: Gemini .mp4 → 48k extraction,
  objective pre-checks (duration, onset-autocorrelation meter/tempo, ending,
  sub-50 Hz, LUFS/LRA, dropout scan), ×1.335 matched preview and a MANIFEST
  scaffold. Validated against all three recorded candidates: Moonlight ON SPEC
  (identical LUFS/LRA/sub-bass; documented half-bar pulse), Ballroom OFF SPEC
  duple + sub-bass caution, Clockwork OFF SPEC + its dropout found at
  150.8–152.5 s (logged 150.5–152.5). Existing manifests are never overwritten.
- **Ballroom's False Collapse gained ×1.414 audition material** for the Day-4
  alternate-title-record option (the title's second-record convention is
  ×1.414, so judging it at ×1.335 only would misjudge the option):
  `..._base_return_x1414_PREVIEW{,_matched}.wav`,
  `..._NIGHTCORE_PREVIEW_x1414.mp3`, gain-matched −0.8 dB. Manifest updated.
  Disposition itself remains the owner's Day-4 call.

- **G1a/G1b landed in the game runtime** (`9c22581`): `SongResource` carries a
  data-tuned `return_ratio` (> 1.0, default ×1.335); every kept version stores
  it as an immutable `reconstruction_ratio`; READ IT BACK now auditions the
  composite recipients get (backing + vocal varisped together, one bus, no
  guess/wow/skip). The fresh-guess `PhonautogramReader` serves found traces
  only. `SongbookTest` 22/22. G1's remaining scope is cross-player version
  delivery (G2 reframe + G6a gates).

## Still pending (update as they land)

- G7 ruling · Moonlight ears/OWNER fields · scratch vocal (the three gates).
- Day-2+: first honest 2007-test return; 105 or 101-regen; 103/104/108 slate.
- Ballroom disposition (retire / FUTURE VOLUME reference / alternate title).
- Q6 consultations (gate shipping masters only) and §13 counsel reviews.
