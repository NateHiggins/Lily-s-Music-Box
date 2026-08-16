# Orison Songbook — five-day bridge plan (2026-08-15 → 2026-08-20)

*Coordination note, not canon. The outside support model (ChatGPT) is paused
for five days from 2026-08-15. This document sequences the Songbook/audio lane
through the gap. The game lane is untouched by the pause: its authority remains
`design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md` →
`design/next_session_plan.md` (next: N6, Mina's release-print pursuit).*

## Where the project stands (verified 2026-08-15)

**Game lane** — moving fast and needs nothing from this plan: M1 closed; K7
and N2–N5 closed (dream maze graph, light binary, scene boundary, gradual
onset); the service-wire/prop interaction sweep landed; the title screen
shipped. N6 is next per `design/next_session_plan.md`.

**Songbook lane:**

- **Owner ruling 2026-08-15 — provisional title theme.** The Clockwork Waltz
  (an off-spec Dreamland take from the 2026-08-14 Gemini session) is the title
  music for now: the untouched 2:38.7 original opens, and `ESCAPEMENT FAILURE
  ×1.414` — a **pure-varispeed** return, nothing added after the speedup — is
  the second record. Masters, hashes and tests: `game/docs/title_screen.md`.
- **track_101 DREAMLAND:** `Moonlight_on_the_Dance_Floor` is the only on-spec
  candidate (objective pre-checks PASS: 2:37.7, a waltz at ~96, honest close,
  no synthetic sub). Owner ears (checklist items 1–8), the OWNER manifest
  fields and the scratch vocal are all still pending.
- **Sibling takes** from the same session: The Clockwork Waltz (promoted to
  the title, above) and Ballroom's False Collapse (off-spec duple meter,
  unassigned — disposition pending, Day 4). Manifests sit beside the audio in
  `art/audio/`.
- **G7 OPEN — the house rig.** Heavy bass + ghostly distortion on the return
  vs Music Bible §5.2's pure-varispeed rule. This is now a concrete A/B, not
  an abstract ruling: the shipped `clockwork_waltz_escapement_failure.ogg` is
  the §5.2-clean reference; `art/audio/Moonlight_HAUNTED_FLOOR_x1335.mp3` is
  the rigged prototype.
- **G8 OPEN — no scratch vocal exists.** Checklist items 9–10 (the 2007 test)
  are unjudged for every candidate; the base alone cannot chipmunk.
- **Not started:** 103/104/105/108 generations; Q6 consultations (they gate
  shipping masters only); §13 counsel reviews. FUTURE VOLUME tracks stay
  preserved and inactive. Audio stays uncommitted; manifests and docs commit.

## The critical path

Every Songbook step now funnels through three owner inputs — about thirty
minutes total. Nothing in this lane is blocked by the support model's absence;
it is blocked only on these:

1. **Rule G7 by ear.** Play the shipped ESCAPEMENT FAILURE (pure) against
   `Moonlight_HAUNTED_FLOOR_x1335.mp3` (rigged). Pick the community return's
   law: pure varispeed stands, or §5.2 gains one authored house-rig chain
   (still one immutable ratio, still no formant correction).
2. **Audition Moonlight** against the Levy 189/119 score — checklist items
   1–8 — and fill the OWNER fields in its `MANIFEST.md`.
3. **Record one disposable scratch vocal** over
   `art/audio/Moonlight_on_the_Dance_Floor.48k.wav`: any mic, full length,
   sung plainly at native speed. It is raw material, not a performance.

Everything downstream of these three is same-day agent work.

## Day plan

- **Day 1 — unblock.** Owner does 1–3 above (~30 min). Agent, same day: mix
  the complete take (base + vocal + room as recorded), cut the ×1.335
  true-varispeed return, gain-matched preview, and — per the G7 ruling — the
  rigged master or nothing. This is the project's first honest 2007-test
  material.
- **Day 2 — verdict, next generation.** Owner plays the return twice
  (items 9–10). If Dreamland passes, owner generates track_105 (AIN'T WE GOT
  FUN — no consultation gate) from House Five §4; if it fails, regenerate 101
  from §1 unchanged. Agent processes any new candidate within the day
  (pre-checks, previews, manifest).
- **Day 3 — fill the slate.** Owner generates the 103 and/or 104/108
  primaries (private audition is allowed; consultation gates shipping only).
  Agent processes each; the results table carries all five tracks.
- **Day 4 — treatment and dispositions.** If G7 adopted the rig:
  arrangement-aware pass on the best complete take (kick enters at the first
  chorus, drops for the interlude), plus ×1.414 alternates for the two tracks
  specced there. If G7 kept purity: an A/B pack of clean returns at both
  ratios. Owner also disposes of Ballroom's False Collapse (retire / FUTURE
  VOLUME texture reference / alternate title record).
- **Day 5 — consolidate and prepare re-entry.** Commit manifests and results
  rows (docs only). Write the delta brief for the returning support model —
  what changed 08-15 → 08-20 — to sit beneath the original handoff prompt.
  Owner reviews the week and names what follows (M2 golden shift on the game
  side; first Q6 outreach if any consult-gated track nears shippable).

If a day's owner input doesn't arrive, agents skip to whatever is unblocked
(candidate processing, N6 support, docs). Nothing here queues idle work.

## Standing rules through the gap

- No canon amendment without an explicit owner ruling; G7 is the only §5.2
  question on the table.
- Audio and large binaries are never committed; manifests and docs are.
- Stage by exact path, never `git add -A`; fetch before editing and before
  pushing. Multiple agents share this tree.
- Q6 consultations gate shipping masters, not private auditions; the §13
  HOLD table is binding.
- Gemini outputs remain audition material, never shipping masters.

## Re-entry (day 6)

The original handoff prompt (delivered in chat 2026-08-14, f2caedc era)
remains valid. Hand the returning model that prompt plus the Day-5 delta
brief; it resumes without re-deriving anything.
