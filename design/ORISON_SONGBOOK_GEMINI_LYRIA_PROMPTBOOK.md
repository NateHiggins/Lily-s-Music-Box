# THE ORISON SONGBOOK — GEMINI / LYRIA AUDITION PROMPTBOOK

**AUDITION MATERIAL ONLY — NOT NEW CANON. NOT SHIPPING MASTERS.**

*Filed 2026-08-14 against `ORISON_SONGBOOK_MUSIC_BIBLE.md` at `28c564f`;
revised the same day to the OWNER CORRECTION — GEMINI FULL-LENGTH
OUTPUT: Gemini's current interface produces complete tracks (the owner
has generated 2:36 in it), so the obsolete 30-second hook tier is
deleted and every eligible track now carries a **PRIMARY FULL-LENGTH
BASE**, a **SPARSER KARAOKE VARIANT** (same arrangement concept, BPM,
key, meter and period ensemble — more room for the singer), and
**TARGETED CORRECTION PROMPTS**. Gemini generates **only the BASE** —
native-speed, fully instrumental, period-honest. It never generates the
returned nightcore version, a singer, or the player take: the game
assembles* `full native instrumental + scratch/player vocal + room →
capture coloration → complete take → fixed house ratio, true
varispeed`. *The 2007 test applies to the full performance — cohesive
section development, phrase space, ending behavior, incidental sound
and the complete accelerated return are all part of the audition, and
no short excerpt proves a track. Nothing generated enters `game/assets`
before the owner approves the sound and the commercial-use, rights,
consultation and provenance requirements are reviewed (Music Bible §13,
§14, §0). Modern lineage names appear only in editor's notes, never
inside a generation prompt.*

---

## 0. PASTE THIS FIRST — track_101 DREAMLAND, PRIMARY FULL-LENGTH BASE (2:41)

*Status: RUNNABLE (GREEN rights; audition mandated by Q1). Attach the
public-domain score pages listed in §3.1 if the interface accepts
images. Never upload or reference any historical commercial recording.*

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1909 American waltz song "Meet Me Tonight in
Dreamland" by Leo Friedman. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: a small 1926 American wedding dance orchestra
recorded live in one small hard-walled back room. Instruments: two
violins, cornet, trombone, clarinet, tuba, banjo, upright piano, and
a drum kit played only with brushes.

Non-negotiable musical facts: 3/4 waltz meter throughout. Tempo 96
beats per minute, steady. Key of F major. Total duration about 2
minutes 41 seconds. No fade-out; end cleanly on the tonic.

Structure:
[0:00 - 0:07] four-bar intro, piano and violins.
[0:07 - 0:37] 16-bar verse, band light.
[0:37 - 1:07] 16-bar chorus, full band.
[1:07 - 1:37] 16-bar verse, slightly quieter than the first.
[1:37 - 1:52] 8-bar instrumental interlude, cornet resting.
[1:52 - 2:22] 16-bar final chorus, the warmest pass.
[2:22 - 2:41] tag: a graceful 8-bar close, relaxed, ending on the
tonic chord.

The cornet quietly carries the vocal melody in the verses and
choruses as a guide for a live singer: audible but slightly softer
than the band, plain and unornamented. Leave clear space for an
untrained live singer everywhere: no instrument fills the vocal
register continuously; short restrained answering figures only at
the ends of the 4-bar vocal phrases; the band supports and never
crowds.

Dynamics: warm and unhurried; the first chorus fuller than the
verses; the final chorus the fullest; one gentle swell into the tag.

Room character: close, dry, small and hard-walled, like a modest
1920s location recording, with the cornet naturally a little
forward in the balance. Light natural performance noise is
acceptable, including one soft wooden chair creak somewhere in the
middle of the piece.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices of any kind, no vocal
samples. No modern synthesizers, no electronic drums, no sub-bass,
no sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music up.
Do not make nightcore, hyperpop, jungle, happy hardcore, or any
modern electronic style. Do not imitate or name any modern artist.
Do not quote or reproduce any historical recording.
```

---

## 1. HOW TO USE THIS BOOK

- **Full-length is the standard.** All musical outputs requested from
  Gemini are full-length unless the owner explicitly asks for an
  excerpt. Do not design around legacy clip limits; the current
  interface composes complete tracks. If the interface ever displays
  a hard length cap shorter than a dossier's duration, still run the
  primary prompt unchanged (preserve the complete requested
  duration), audition whatever returns for texture, instrumentation
  and vocal space only — structure and the 2007 test wait for an
  uncapped run — and note the cap in the manifest. That is the whole
  fallback; no prompt in this book is shortened preemptively.
- **Interfaces.** Gemini app music creation (per Google's help page:
  18+, full-track creation on the Pro tier; downloads as MP4 video or
  MP3 audio; every track carries an AI watermark). API: Lyria 3 —
  `lyria-3-pro-preview` (full-length, WAV via `response_format`) is
  the audition workhorse; prompts use the documented `[m:ss - m:ss]`
  section-tag convention.
- **Score attachment.** The API documentation supports up to 10
  images alongside the text prompt, and the app accepts image
  uploads. Attach the cited public-domain sheet-music pages (music
  pages, not just the cover) for every run that the interface allows.
  **Never upload, link, hum, or otherwise reference any historical
  commercial recording — not even "for reference." Scores only.**
- **One shot per run, plus corrections.** Multi-turn editing of audio
  is not supported; a flawed output is regenerated. Each track
  carries TARGETED CORRECTION PROMPTS — short paste-ready
  regeneration instructions for the common failure modes — to make
  the next one-shot count.
- **Two full arrangements per track.** The PRIMARY is the dossier's
  arrangement as written. The SPARSER KARAOKE VARIANT keeps the same
  arrangement concept, BPM, key, meter and period ensemble, but opens
  more midrange space, quiets the guide further, and drops most
  inter-phrase fills — audition both; keep whichever the scratch-
  vocal take proves.
- **Audio handling.** Prefer WAV via the API; app MP3 is acceptable
  for a first listen but note it in the manifest. Convert to 48 kHz
  before the return test (§3.4).
- **Every output is audition material.** SynthID/AI-disclosure is
  recorded in the manifest (§7). The evaluation sheet is pass/fail on
  the FULL performance; a failed item rejects the output — do not
  rationalize, and do not claim a short excerpt proves anything.
- **Prompt tiers.** NON-NEGOTIABLE (meter, BPM, key, duration,
  instrumental-only, vocal space, source-melody fidelity — regenerate
  until true), DESIRABLE (texture — accept close misses), EXPENDABLE
  (incident detail — drop without regret).
- **Statuses** mirror the Music Bible: RUNNABLE (Group A);
  `DO NOT RUN — CONSULTATION REQUIRED` (Group B; prompt-writing does
  not waive Q6); `RESERVE — NOT PROMOTED` (Group C); RIGHTS HOLD
  (Group D; no prompts provided).

## 2. GLOBAL RULES REPEATED IN EVERY PROMPT

Every runnable prompt in this book self-contains, in natural language:
instrumental only; no singing; no spoken words; no chanting; no
humming; no lexical crowd vocals; no vocal samples; no modern
synthesizers; no electronic drums; no sub-bass; no sidechain pumping;
no modern mastering loudness; no pitch correction; no quantization
beyond period feel; no vinyl crackle or fake gramophone loop (no
dossier requires one — the game adds capture coloration later, so no
phonautograph/soot effect either); do not speed up; do not make
nightcore/hyperpop/jungle/happy hardcore; do not imitate or name any
modern artist; do not quote any historical recording. The period
material must sound like itself at native speed — the club affinities
are allowed to appear only after the game accelerates the complete
player take.

**Correction-prompt convention.** Each track's TARGETED CORRECTION
PROMPTS are written to be pasted alone into a fresh generation
alongside the primary or sparser prompt they correct (paste the
original prompt, then the correction line beneath it). They cover, in
order: (1) added vocals, (2) changed source melody, (3) too modern,
(4) crowded vocal register, (5) wrong meter/BPM, (6) fake vinyl
noise, (7) missing room character, (8) weak after true-varispeed
return. Correction 8 is judged only after the §3.4 return test of the
complete take.

---

## 3. GROUP A — RUNNABLE FIRST AUDITIONS

### 3.1 track_101 — DREAMLAND (DON'T WAIT UP)

- **Source:** "Meet Me Tonight in Dreamland," music Leo Friedman,
  lyrics Beth Slater Whitson, pub. Chicago 1909 (Will Rossiter).
  US public domain (1909 publication; both authors d. ≤1930).
- **Score to attach:** Levy Sheet Music Collection scan
  (https://levysheetmusic.mse.jhu.edu/collection/189/119) — attach the
  notation pages (typically 3–4 pages after the cover); alternates:
  Library of Congress (https://www.loc.gov/item/2023792560/), Internet
  Archive (https://archive.org/details/sm_meetmetonightindreamland).
- **Never use or upload any historical commercial recording.**
- **Facts:** 3/4 · 96 BPM · F major · 2:41 · cornet guide · chorus
  slots 8-8-8-10 (rise-rise-fall-arc) · house ratio ×1.335.
- **Status:** RUNNABLE. First owner audition. Rights GREEN.

**PRIMARY FULL-LENGTH BASE:** §0 above — the book's first prompt.

**SPARSER KARAOKE VARIANT — full length:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1909 American waltz song "Meet Me Tonight in
Dreamland" by Leo Friedman. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: a small 1926 American wedding dance orchestra
recorded live in one small hard-walled back room — two violins,
cornet, trombone, clarinet, tuba, banjo, upright piano, brushed
drum kit — but arranged SPARSELY, as if half the band is resting
on any given phrase: mostly piano, tuba, banjo and brushes
carrying the accompaniment, with the horns and violins reserved
for section entrances and phrase-end answers.

Non-negotiable musical facts: 3/4 waltz meter throughout. Tempo
96 beats per minute, steady. Key of F major. Total duration about
2 minutes 41 seconds. No fade-out; end cleanly on the tonic.

Structure:
[0:00 - 0:07] four-bar intro, piano alone.
[0:07 - 0:37] 16-bar verse: piano, tuba, banjo, brushes only.
[0:37 - 1:07] 16-bar chorus: add soft violins; cornet guide very
quiet.
[1:07 - 1:37] 16-bar verse, sparse again.
[1:37 - 1:52] 8-bar interlude: violins and piano.
[1:52 - 2:22] 16-bar final chorus, the fullest this variant
gets — still airy.
[2:22 - 2:41] 8-bar tag, thinning back to piano, ending on the
tonic chord.

The cornet carries the vocal melody as a guide even more quietly
than usual — clearly audible only when the singer would breathe,
almost transparent under a voice. Keep the entire midrange open
for an untrained live singer: no instrument sustains in the vocal
register; no counter-melodies; almost no inter-phrase fills — at
most one short answer at the end of every second 4-bar phrase.

Dynamics: gentle throughout; the final chorus warmer, never big.

Room character: close, dry, small and hard-walled, like a modest
1920s location recording.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices of any kind, no vocal
samples. No modern synthesizers, no electronic drums, no
sub-bass, no sidechain pumping, no modern mastering loudness, no
pitch correction, no rigid grid quantization. No vinyl crackle
and no fake gramophone or old-recording effect. Do not speed the
music up. Do not make nightcore, hyperpop, jungle, happy
hardcore, or any modern electronic style. Do not imitate or name
any modern artist. Do not quote or reproduce any historical
recording.
```

**TARGETED CORRECTION PROMPTS (paste beneath the original prompt in
a fresh generation):**

1. *Vocals appeared:* "Regenerate exactly the same piece, but
   strictly instrumental: remove every trace of singing, humming,
   spoken words, and voice-like sounds. Change nothing else."
2. *Melody drifted:* "Regenerate following the attached sheet music
   exactly: the tune of 'Meet Me Tonight in Dreamland' must be
   recognizable phrase by phrase in the cornet guide and harmony. Do
   not substitute a similar melody."
3. *Too modern:* "Regenerate using only the listed 1920s acoustic
   instruments. Remove anything that sounds like a synthesizer,
   electronic drum, deep sub-bass, or loud modern mastering. It must
   sound like a live 1926 room."
4. *Vocal register crowded:* "Regenerate leaving the singer's range
   open: the cornet plays the melody quietly; no other instrument
   sustains or solos in the vocal register; answers only at the ends
   of the 4-bar phrases; fewer fills overall."
5. *Meter/tempo wrong:* "Regenerate in exact 3/4 waltz time at 96
   beats per minute, steady from first bar to last."
6. *Fake vinyl noise:* "Regenerate with a clean signal: no vinyl
   crackle, no gramophone hiss, no old-record effect. The room may
   sound natural; the recording must be clean."
7. *Room character missing:* "Regenerate as one live take in a
   small, dry, hard-walled back room, close-miked, with the cornet
   naturally a little forward."
8. *Weak after the ×1.335 return:* "Regenerate the same arrangement
   with firmer downbeats from the tuba and brushes, clearer contrast
   between verse and chorus, and a more decisive final chorus — same
   tune, meter, tempo, key, and instruments."

**Prompt tiers:** NON-NEGOTIABLE — 3/4, 96 BPM, F major, ~2:41,
source melody, instrumental-only, cornet guide subordinate, 4-bar
openings. DESIRABLE — balance, room, section dynamics. EXPENDABLE —
the chair creak.

**Evaluation sheet — judged on the FULL performance (reject on any
FAIL):**
- recognizable source melody: PASS/FAIL
- correct meter (3/4) and ≈96 BPM: PASS/FAIL
- fully instrumental: PASS/FAIL
- guide (cornet) subordinate: PASS/FAIL
- enough vocal space (open 4-bar phrases): PASS/FAIL
- period instrumentation only: PASS/FAIL
- no accidental modern production: PASS/FAIL
- no fake historical recording copied: PASS/FAIL
- native-speed performance works by itself, whole form: PASS/FAIL
- expected result at ×1.335 (whirl, not blur; ending survives):
  PASS/FAIL
- 2007 test on the complete accelerated take: PASS/FAIL

### 3.2 track_105 — AIN'T WE GOT FUN (RENT DUE MIX)

- **Source:** "Ain't We Got Fun," music Richard A. Whiting, lyrics
  Raymond B. Egan & Gus Kahn, pub. 1921. US public domain; life+70
  clear.
- **Score to attach:** NYPL public-domain scan
  (https://digitalcollections.nypl.org/items/510d47da-4d54-a3d9-e040-e00a18064a99);
  alternates: BGSU (https://digitalgallery.bgsu.edu/items/show/17179),
  UMaine (https://digitalcommons.library.umaine.edu/mmb-vp/33/).
- **Never use or upload any historical commercial recording.**
- **Facts:** 4/4 · 118 BPM · C major · 2:29 · clarinet guide
  (call/answer) · paired 7/7 slots · house ratio ×1.335.
- **Status:** RUNNABLE. First owner audition. Rights GREEN.

**PRIMARY FULL-LENGTH BASE:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1921 American popular song "Ain't We Got Fun"
by Richard A. Whiting. Follow the melody, harmony and form of the
attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: a tiny 1926 after-hours session in a laundry
loft — upright piano, banjo, one clarinet, and a slow, steady,
deep mechanical thump like a steam pressing machine keeping time
on beats one and three throughout, felt more than heard.

Non-negotiable musical facts: 4/4 meter. Tempo 118 beats per
minute, steady. Key of C major. Total duration about 2 minutes 29
seconds. No fade-out.

Structure:
[0:00 - 0:08] four-bar intro: piano vamp, the press thump
entering on bar three.
[0:08 - 0:41] 16-bar verse, light.
[0:41 - 1:13] 16-bar chorus, full trio.
[1:13 - 1:30] 8-bar patter interlude: banjo and piano only,
clipped and conversational.
[1:30 - 2:03] 16-bar chorus.
[2:03 - 2:24] 10-bar final half-chorus and button.
[2:24 - 2:29] the mechanical thump stops with a soft hiss of
steam; clean end on the tonic.

The clarinet quietly carries the vocal melody as a guide for live
singers, slightly under the piano, cheerful and plain, phrasing
the tune as call and answer — two bars of melody, two bars of
space — so two singers can trade lines. Leave the vocal register
open throughout: no instrument fills it continuously; short
answers only after each phrase.

Dynamics: bright, bouncing, honest; choruses fuller than verses;
the last half-chorus the happiest.

Room character: a wooden loft, close and dry, amateur and warm;
one brief natural laugh far from the microphone in the middle of
the second chorus is acceptable but not required.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1921 American popular song "Ain't We Got Fun"
by Richard A. Whiting. Follow the melody, harmony and form of the
attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: the same tiny 1926 laundry-loft session —
upright piano, banjo, one clarinet, and the slow deep mechanical
press thump on beats one and three — but arranged SPARSELY: piano
mostly alone as the accompaniment, banjo entering only in
choruses, clarinet guide very quiet.

Non-negotiable musical facts: 4/4 meter. Tempo 118 beats per
minute, steady. Key of C major. Total duration about 2 minutes 29
seconds. No fade-out.

Structure:
[0:00 - 0:08] four-bar intro: piano and press thump only.
[0:08 - 0:41] 16-bar verse: piano and thump, nothing else.
[0:41 - 1:13] 16-bar chorus: banjo joins lightly; clarinet guide
barely above the piano.
[1:13 - 1:30] 8-bar patter interlude: piano alone, clipped.
[1:30 - 2:03] 16-bar chorus, still airy.
[2:03 - 2:24] 10-bar final half-chorus and button, the fullest
this variant gets.
[2:24 - 2:29] the press thump stops with a soft steam hiss; clean
end on the tonic.

The clarinet carries the melody as a guide even more quietly than
usual — a thread, not a voice — and keeps strict call-and-answer
phrasing: two bars of melody, two bars of true silence in the
vocal register. No counter-melodies, almost no fills; at most one
short piano answer per eight bars. The whole midrange stays open
for two untrained singers trading lines.

Dynamics: modest throughout; the button is a smile, not a shout.

Room character: a wooden loft, close and dry, amateur and warm.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS:**

1. *Vocals appeared:* "Regenerate exactly the same piece, strictly
   instrumental: remove all singing, humming, spoken words and
   voice-like sounds. Change nothing else. (One distant wordless
   laugh is permitted; nothing more.)"
2. *Melody drifted:* "Regenerate following the attached sheet music
   exactly: the tune of 'Ain't We Got Fun' must be recognizable
   phrase by phrase. Do not substitute a similar melody."
3. *Too modern:* "Regenerate with only upright piano, banjo,
   clarinet and the mechanical press thump. Remove anything
   synthetic, any electronic drum sound, sub-bass, or loud modern
   mastering. A live 1926 loft, nothing newer."
4. *Vocal register crowded:* "Regenerate with strict call-and-answer
   space: two bars of quiet clarinet melody, two bars with the vocal
   register empty. No counter-melodies, minimal fills."
5. *Meter/tempo wrong:* "Regenerate in exact 4/4 at 118 beats per
   minute, steady throughout."
6. *Fake vinyl noise:* "Regenerate with a clean signal: no vinyl
   crackle, no gramophone hiss, no old-record effect."
7. *Room character missing:* "Regenerate as one live take in a
   close, dry wooden loft with the deep press thump keeping time on
   beats one and three, felt more than heard."
8. *Weak after the ×1.335 return:* "Regenerate with the press thump
   more even and present, crisper piano attacks, and stronger
   verse-to-chorus contrast — same tune, meter, tempo, key and
   instruments."

**Prompt tiers:** NON-NEGOTIABLE — 4/4, 118, C, ~2:29, source
melody, instrumental-only, clarinet guide with call/answer space.
DESIRABLE — press-thump timekeeper, loft warmth, patter feel.
EXPENDABLE — the distant laugh, the steam-hiss ending.

**Evaluation sheet:** the §3.1 eleven items on the FULL performance,
with ≈118 BPM in 4/4 and the ×1.335 expectation reading "pogo, not
smear; the thump becomes a kick."

### 3.3 track_111 — EAST SIDE WEST SIDE (ROUND AND ROUND)

- **Source:** "The Sidewalks of New York," Charles B. Lawlor & James
  W. Blake, pub. 1894 (Howley, Haviland & Co.). US public domain;
  authors d. 1925/1935 — clear everywhere.
- **Score to attach:** Levy scan
  (https://levysheetmusic.mse.jhu.edu/collection/143/165); alternates:
  NYPL (https://digitalcollections.nypl.org/items/8ebb8569-5e64-52e2-e040-e00a18065f28),
  Mississippi State Templeton collection
  (https://scholarsjunction.msstate.edu/cht-sheet-music/10198/).
- **Never use or upload any historical commercial recording.**
- **Facts:** 3/4 · 90 BPM · G major · 2:52 · concertina guide · relay
  verse slots, chorus ALL OF YOU · house ratio ×1.414.
- **Status:** RUNNABLE. First owner audition. Rights GREEN.

**PRIMARY FULL-LENGTH BASE:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1894 American waltz song "The Sidewalks of New
York" by Charles B. Lawlor. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: a scrappy 1926 street string band recorded
outdoors at night — concertina, two fiddles, banjo, and a wooden
packing case drummed with bare palms.

Non-negotiable musical facts: 3/4 waltz meter throughout. Tempo 90
beats per minute, steady. Key of G major. Total duration about 2
minutes 52 seconds. No fade-out; end together on the tonic.

Structure:
[0:00 - 0:08] four-bar intro: concertina alone, then the case
drum joins.
[0:08 - 0:40] 16-bar verse, light, fiddles sparse.
[0:40 - 1:12] 16-bar chorus, everyone in.
[1:12 - 1:44] 16-bar verse.
[1:44 - 2:00] 8-bar instrumental turn: fiddles lead, concertina
rests.
[2:00 - 2:32] 16-bar final chorus, the fullest.
[2:32 - 2:52] 10-bar close: one last half-phrase of the chorus
melody and a firm ending together.

The concertina quietly carries the vocal melody in verses and
choruses as a guide for live singers, plain and clear, a little
under the fiddles. Leave the vocal register open throughout: no
instrument fills it continuously; short fiddle answers only at
the ends of the 4-bar phrases, so a different singer can take
each line in relay.

Rhythm detail: the palm-drummed case keeps the waltz beat, and a
second, quieter palm pattern crosses it with gentle accents in
groups of two against the three — playful cross-rhythm, subtle,
never dominating, present mainly in the choruses.

Dynamics: open-air and eager; verses lighter, choruses full; the
final chorus the biggest without getting loud in a modern way.

Room character: outdoors on a bridge walkway at night — open air,
a little wind; one or two distant passing vehicles are acceptable
but not required.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1894 American waltz song "The Sidewalks of New
York" by Charles B. Lawlor. Follow the melody, harmony and form
of the attached public-domain sheet music exactly — do not invent
a merely similar tune.

Style and ensemble: the same scrappy 1926 street string band
outdoors at night — concertina, two fiddles, banjo, palm-drummed
wooden case — but arranged SPARSELY: banjo and case carry the
waltz almost alone; the fiddles sit out entire sections; the
concertina guide is faint.

Non-negotiable musical facts: 3/4 waltz meter throughout. Tempo
90 beats per minute, steady. Key of G major. Total duration about
2 minutes 52 seconds. No fade-out; end together on the tonic.

Structure:
[0:00 - 0:08] four-bar intro: case drum and banjo only.
[0:08 - 0:40] 16-bar verse: banjo, case, faint concertina guide.
[0:40 - 1:12] 16-bar chorus: one fiddle joins softly.
[1:12 - 1:44] 16-bar verse, back to the trio.
[1:44 - 2:00] 8-bar turn: both fiddles, briefly.
[2:00 - 2:32] 16-bar final chorus, the fullest this variant gets
— still airy.
[2:32 - 2:52] 10-bar close, thinning to banjo and case, firm
ending together.

The concertina carries the vocal melody even more quietly than
usual — a breath under the band — and the cross-rhythm palm
pattern appears only in the final chorus. Keep the whole midrange
open for up to five singers trading lines: no counter-melodies,
answers at most once per eight bars.

Dynamics: modest, buoyant, never big.

Room character: outdoors on a bridge walkway at night — open air,
a little wind.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS:**

1. *Vocals appeared:* "Regenerate exactly the same piece, strictly
   instrumental: remove all singing, humming, spoken words and
   voice-like sounds. Change nothing else."
2. *Melody drifted:* "Regenerate following the attached sheet music
   exactly: the tune of 'The Sidewalks of New York' — the East
   Side, West Side chorus — must be recognizable phrase by phrase.
   Do not substitute a similar melody."
3. *Too modern:* "Regenerate with only concertina, two fiddles,
   banjo and a palm-drummed wooden case. Remove anything synthetic,
   any electronic drum sound, sub-bass, or loud modern mastering."
4. *Vocal register crowded:* "Regenerate leaving the singer's range
   open: faint concertina guide, no counter-melodies, fiddle
   answers only at phrase ends, so five different singers can each
   take a line."
5. *Meter/tempo wrong:* "Regenerate in exact 3/4 waltz time at 90
   beats per minute, steady from first bar to last."
6. *Fake vinyl noise:* "Regenerate with a clean signal: no vinyl
   crackle, no gramophone hiss, no old-record effect. Outdoor air
   is welcome; artificial aging is not."
7. *Room character missing:* "Regenerate as one live outdoor take
   on a bridge walkway at night: open air around the band, close
   players, honest wind acceptable."
8. *Weak after the ×1.414 return:* "Regenerate with the case drum
   more present, the two-against-three palm accents clearer in the
   choruses, and a firmer together-ending — same tune, meter,
   tempo, key and instruments."

**Prompt tiers:** NON-NEGOTIABLE — 3/4, 90, G, ~2:52, source
melody, instrumental-only, concertina guide, relay-friendly
openings. DESIRABLE — cross-rhythm, outdoor air. EXPENDABLE —
wind, vehicle passes.

**Evaluation sheet:** the §3.1 eleven items on the FULL
performance, with ≈90 BPM in 3/4 and the ×1.414 expectation
reading "it spins — a whirl in three, cross-accents sparkling, not
a stomp; the close survives acceleration."

### 3.4 LOCAL COMPARISON RECIPE — the return test (all auditions)

*The audition's verdict is the complete take at speed. A synthetic
Gemini singer is not a valid substitute for the player-vocal test —
record a scratch vocal yourself, over the full form.*

1. Keep the native Gemini output untouched (prefer WAV from the
   API; convert app MP3 to WAV once and archive both).
2. Record a disposable scratch vocal over the ENTIRE base — any
   voice, any quality; commitment matters, polish does not.
3. Align the vocal to the instrumental (start-of-first-phrase
   alignment is enough for audition purposes).
4. Mix once into one complete take (vocal + base; light, no
   processing).
5. Convert the take to 48 kHz:
   `ffmpeg -i take.wav -ar 48000 take48.wav`
6. Create the return with TRUE resampling at the track's fixed
   ratio — tempo and pitch together (verified: a 4.000 s input
   returns 2.996 s at ×1.335 and 2.829 s at ×1.414):
   - ×1.335 → `ffmpeg -i take48.wav -af "asetrate=48000*1.335,aresample=48000" return_1335.wav`
   - ×1.414 → `ffmpeg -i take48.wav -af "asetrate=48000*1.414,aresample=48000" return_1414.wav`
   - ×1.26 → `ffmpeg -i take48.wav -af "asetrate=48000*1.26,aresample=48000" return_126.wav`
7. Do not pitch the voice separately; do not use formant
   correction; do not use `atempo` (tempo without pitch is the
   wrong machine).
8. Loudness-match native and returned versions with plain gain
   only: measure each with
   `ffmpeg -i file.wav -af ebur128 -f null -`
   (read integrated LUFS) and apply the difference as
   `ffmpeg -i file.wav -af "volume=XdB" matched.wav`.
   Never a limiter, compressor or normalizer — gain only.
9. Audition order: native base alone (whole form) → native take →
   returned take (whole form). Score the sheet; items ten and
   eleven are judged only on the complete returned take.

---

## 4. GROUP B — CONSULTATION-GATED DRAFTS

*Complete prompt sets, written so the consultation reviews concrete
text rather than intentions. The banner is absolute: prompt-writing
does not waive the Music Bible's Q6 requirements, and running one of
these before its review is a process violation, not a shortcut. Each
track's evaluation sheet gains a twelfth item: **consultant approval
on file: PASS/FAIL** — without it the audition does not begin.*

### 4.1 track_103 — ALOHA OE AT CLOSING TIME

> **DO NOT RUN — CONSULTATION REQUIRED.** Hawaiian-culture review
> (Music Bible §0-Q6, §11/track_103) covering the fictional touring-
> act framing, the Makai-family presentation, instrumentation and
> credits wording. Queen Liliʻuokalani's composition is a mele of her
> own and is never classified "hapa haole." No tropical or novelty
> flattening. Rights GREEN; the gate is cultural review, not law.

- **Source:** "Aloha ʻOe," words and music Queen Liliʻuokalani, 1878.
- **Score to attach:** UH Mānoa digital sheet
  (https://digital.library.manoa.hawaii.edu/items/show/31961);
  archival context: Hawaiʻi State Archives Queen's music collection
  (https://ags.hawaii.gov/archives/online-exhibitions/music-from-the-queens-collection/).
- **Never use or upload any historical commercial recording.**
- **Facts:** 4/4 · 84 BPM · G major · 2:33 · steel guitar guide ·
  chorus slots 10-10 (arc, fall) · house ratio ×1.335.

**PRIMARY FULL-LENGTH BASE (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of "Aloha ʻOe," composed in 1878 by Queen
Liliʻuokalani of Hawaiʻi. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune. Play it with dignity, as a beloved farewell
song, not as a novelty.

Style and ensemble: a small 1924 touring string trio recorded
warmly in one close room — steel guitar, rhythm guitar, and an
ipu (a Hawaiian gourd drum) played with quiet heel-and-slap
strokes.

Non-negotiable musical facts: 4/4 meter throughout. Tempo 84
beats per minute, steady. Key of G major. Total duration about 2
minutes 33 seconds. No fade-out.

Structure:
[0:00 - 0:09] four-bar intro: steel guitar states the last line
of the chorus melody once, gently.
[0:09 - 0:55] 16-bar verse, sparse; rhythm guitar and ipu only
under the vocal space, steel resting except phrase-end answers.
[0:55 - 1:41] 16-bar chorus, full trio, warm.
[1:41 - 2:04] 8-bar instrumental half-chorus: steel leads openly.
[2:04 - 2:27] 8-bar final half-chorus, quieter, tender.
[2:27 - 2:33] closing bars: one long, smooth sliding fall on the
steel guitar and a ringing tonic chord; then let the recording
run out naturally without a musical fade.

The steel guitar quietly carries the vocal melody as the singer's
guide, plain and warm, always slightly under where a voice would
sit, answering the ends of vocal phrases with smooth, unhurried
sliding falls. Leave the vocal register open throughout: no
instrument fills it continuously; answers only after each 4-bar
phrase.

Dynamics: warm, unhurried, sincere; the chorus fuller than the
verse; the final half-chorus the most intimate.

Room character: close, warm, dry; a small room late at night;
light natural performance noise acceptable.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. No ukulele strumming
bed, no ocean or beach sound effects, no exotica or novelty
gestures of any kind. Do not speed the music up. Do not make
nightcore, hyperpop, jungle, happy hardcore, or any modern
electronic style. Do not imitate or name any modern artist. Do
not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of "Aloha ʻOe," composed in 1878 by Queen
Liliʻuokalani of Hawaiʻi. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune. Play it with dignity, as a beloved farewell
song, not as a novelty.

Style and ensemble: the same small 1924 touring string trio —
steel guitar, rhythm guitar, ipu — arranged even more SPARSELY:
rhythm guitar and ipu carry almost everything; the steel guide is
faint and speaks mainly between phrases.

Non-negotiable musical facts: 4/4 meter throughout. Tempo 84
beats per minute, steady. Key of G major. Total duration about 2
minutes 33 seconds. No fade-out.

Structure:
[0:00 - 0:09] four-bar intro: rhythm guitar alone.
[0:09 - 0:55] 16-bar verse: rhythm guitar and ipu only; the steel
appears only twice, at phrase ends.
[0:55 - 1:41] 16-bar chorus: steel guide faint under the open
vocal space.
[1:41 - 2:04] 8-bar half-chorus: the steel's one open statement.
[2:04 - 2:27] 8-bar final half-chorus, barest of all.
[2:27 - 2:33] one long sliding fall and a ringing tonic; let the
recording run out naturally without a musical fade.

Keep the entire vocal register open at all times: no sustained
instrument in the singer's range, no counter-melodies, steel
answers at most once per 4-bar phrase, shorter than before.

Dynamics: intimate throughout; nothing swells past mezzo.

Room character: close, warm, dry; a small room late at night.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. No ukulele strumming
bed, no ocean or beach sound effects, no exotica or novelty
gestures of any kind. Do not speed the music up. Do not make
nightcore, hyperpop, jungle, happy hardcore, or any modern
electronic style. Do not imitate or name any modern artist. Do
not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS (gated with the track):**

1. *Vocals appeared:* "Regenerate exactly the same piece, strictly
   instrumental: remove all singing, humming, chanting, spoken
   words and voice-like sounds. Change nothing else."
2. *Melody drifted:* "Regenerate following the attached sheet music
   exactly: Queen Liliʻuokalani's melody must be recognizable
   phrase by phrase. Do not substitute a similar tune."
3. *Too modern:* "Regenerate with only steel guitar, rhythm guitar
   and ipu. Remove anything synthetic, any electronic drum,
   sub-bass, or loud modern mastering. A warm 1924 room, nothing
   newer."
4. *Vocal register crowded:* "Regenerate leaving the singer's range
   open: the steel speaks only between phrases, briefly; no
   counter-melodies; nothing sustains in the vocal register."
5. *Meter/tempo wrong:* "Regenerate in exact 4/4 at 84 beats per
   minute, steady and unhurried throughout."
6. *Fake vinyl noise:* "Regenerate with a clean signal: no vinyl
   crackle, no gramophone hiss, no old-record effect."
7. *Room character missing:* "Regenerate as one live take in a
   close, warm, dry room late at night — intimate, not spacious."
8. *Weak after the ×1.335 return:* "Regenerate with slightly firmer
   ipu strokes, clearer verse-to-chorus contrast, and the final
   sliding fall longer and smoother — same tune, meter, tempo, key
   and instruments."

**Prompt tiers:** NON-NEGOTIABLE — 4/4, 84, G, ~2:33, source
melody, instrumental-only, steel guide subordinate, dignity clause,
anti-exotica constraints. DESIRABLE — room warmth, intro quote,
run-out ending. EXPENDABLE — performance noise.
**Evaluation sheet:** the §3.1 eleven items on the FULL performance
(≈84 in 4/4; ×1.335 expectation: "the slides go weightless; the
farewell refuses to sit down; the run-out flap becomes a
wing-beat") + **consultant approval on file: PASS/FAIL**.

### 4.2 track_104 — CHARLESTON!!!!!

> **DO NOT RUN — CONSULTATION REQUIRED.** Black-vaudeville history
> review (Music Bible §0-Q6; §10 table) covering the dance-hall
> fiction, performance direction and credits wording for James P.
> Johnson's composition. Rights GREEN; the gate is cultural review.

- **Source:** "The Charleston," music James P. Johnson, lyrics Cecil
  Mack, from *Runnin' Wild*, pub. 1923 (Harms).
- **Score to attach:** USF Black American Sheet Music Collection
  scan (https://digitalcommons.usf.edu/aa_sheet_music/6/);
  alternates: NYPL
  (https://digitalcollections.nypl.org/items/ef520b40-c5ff-012f-2c90-58d385a7bc34),
  UMaine (https://digitalcommons.library.umaine.edu/mmb-vp/208/).
- **Never use or upload any historical commercial recording.**
- **Facts:** cut time (2/2) · 112 BPM (half-note pulse) · B♭ major ·
  2:36 · trumpet guide · call-track slots (the singer is the caller)
  · house ratio ×1.414.

**PRIMARY FULL-LENGTH BASE (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1923 song "The Charleston" by James P.
Johnson, from the Broadway show Runnin' Wild. Follow the melody,
harmony and form of the attached public-domain sheet music
exactly, including its famous syncopated rhythm — do not invent a
merely similar tune.

Style and ensemble: a hot 1926 dance-hall band recorded live at
an afternoon dance — trumpet, trombone, clarinet, alto saxophone,
banjo, tuba, and a drummer on a small trap kit. In the two main
dance choruses only, a second bass drum plays a simple steady
four-to-the-floor pulse underneath, deep, dry and even, like a
dance instructor keeping the floor together.

Non-negotiable musical facts: cut time, two beats to the bar.
Tempo 112 half-note beats per minute, driving and steady. Key of
B-flat major. Total duration about 2 minutes 36 seconds. End on a
hard, together button — no fade-out.

Structure:
[0:00 - 0:04] two-bar intro: full band stab and drum pickup.
[0:04 - 0:38] first chorus: full band, four-to-the-floor bass
drum in, dancers' stomps and claps audible.
[0:38 - 1:12] verse-and-patter section: lighter, banjo and reeds
forward, no four-to-the-floor, clear 2-bar gaps after each
phrase for a caller's voice.
[1:12 - 1:29] quiet eight bars: reeds only, the room settling —
the calm before the last dance.
[1:29 - 2:20] final double chorus: the biggest, four-to-the-floor
back in, short brass stabs answering the open vocal gaps.
[2:20 - 2:36] out-chorus tag and a hard button ending together
with one last stomp from the floor.

The trumpet quietly carries the melody as the guide, crisp but a
step behind the band in level. The live singer acts as a dance
caller: keep 2-bar gaps clear after every melodic phrase
throughout; band answers are short stabs only; never fill the
vocal register continuously.

Room character: a wooden dance hall in the afternoon — live
floor, real stomps and claps from dancers on the beat in the
choruses, occasional whistles. All crowd sound must be wordless:
stomps, claps and whistles only, no voices.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no lexical crowd vocals, no vocal samples.
No modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1923 song "The Charleston" by James P.
Johnson, from the Broadway show Runnin' Wild. Follow the melody,
harmony and form of the attached public-domain sheet music
exactly, including its famous syncopated rhythm — do not invent
a merely similar tune.

Style and ensemble: the same hot 1926 dance-hall band — trumpet,
trombone, clarinet, alto saxophone, banjo, tuba, small trap kit —
arranged SPARSELY: banjo, tuba and drums carry the dance; the
horns play section entrances and short stabs only; no
four-to-the-floor bass drum anywhere in this variant.

Non-negotiable musical facts: cut time, two beats to the bar.
Tempo 112 half-note beats per minute, driving and steady. Key of
B-flat major. Total duration about 2 minutes 36 seconds. End on
a hard, together button — no fade-out.

Structure:
[0:00 - 0:04] two-bar intro: banjo and drums.
[0:04 - 0:38] first chorus: rhythm section with trumpet guide
quiet; stomps and claps light.
[0:38 - 1:12] verse-and-patter: banjo and piano-less comping,
maximum space, 2-bar caller gaps after every phrase.
[1:12 - 1:29] quiet eight bars: clarinet alone over tuba.
[1:29 - 2:20] final double chorus: fuller but still airy; horns
stab, never sustain.
[2:20 - 2:36] tag and hard button with one last floor stomp.

The trumpet carries the melody even more quietly than usual —
present only where a caller would breathe. Keep every 2-bar
caller gap truly empty of melody; the vocal register stays open
from first bar to last.

Room character: a wooden dance hall in the afternoon; wordless
crowd only — stomps, claps, an occasional whistle.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no lexical crowd vocals, no vocal samples.
No modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS (gated with the track):**

1. *Vocals appeared:* "Regenerate exactly the same piece, strictly
   instrumental with wordless crowd only: remove all singing,
   humming, spoken words and voice-like sounds; stomps, claps and
   whistles may stay."
2. *Melody drifted:* "Regenerate following the attached sheet music
   exactly: the Charleston melody and its signature syncopation
   must be recognizable phrase by phrase. Do not substitute a
   similar tune."
3. *Too modern:* "Regenerate with only the listed 1920s acoustic
   band. Remove anything synthetic, any electronic drum sound,
   sub-bass, or loud modern mastering. The extra bass drum must
   sound like a real drum in the room, not a produced kick."
4. *Vocal register crowded:* "Regenerate keeping every 2-bar caller
   gap empty: no melody instrument enters the gaps; band answers
   are single short stabs."
5. *Meter/tempo wrong:* "Regenerate in exact cut time, two beats
   per bar, at 112 half-note beats per minute, steady."
6. *Fake vinyl noise:* "Regenerate with a clean signal: no vinyl
   crackle, no gramophone hiss, no old-record effect."
7. *Room character missing:* "Regenerate as one live take in a
   wooden dance hall with a real dancing crowd — wordless stomps
   and claps on the beat, floor bounce, afternoon energy."
8. *Weak after the ×1.414 return:* "Regenerate with the
   four-to-the-floor bass drum steadier and more present in the
   dance choruses, sharper brass stabs, and a harder final button —
   same tune, meter, tempo, key and instruments."

**Prompt tiers:** NON-NEGOTIABLE — cut time at 112, B♭, ~2:36,
source melody with syncopation, instrumental-only, wordless crowd,
caller gaps, kick confined to dance choruses (primary only).
DESIRABLE — hall liveness, the quiet eight. EXPENDABLE — whistles,
the final stomp.
**Evaluation sheet:** the §3.1 eleven items on the FULL performance
(≈112 in cut time; ×1.414 expectation: "a hardcore record that
arrived early — kick grits, the floor becomes sleet") +
**consultant approval on file: PASS/FAIL**.

### 4.3 track_106 — KATYUSHA GO!!

> **DO NOT RUN — CONSULTATION REQUIRED.** Japanese-material review
> (Music Bible §0-Q6) covering the settlement-club fiction, the
> song's history and credits wording. Rights GREEN; the gate is
> cultural review. Score scan: locate via the National Diet Library
> Digital Collections during the review (no direct PD scan URL was
> verified this pass — do not run from memory or from any
> recording).

- **Source:** "Katyusha no Uta," music Nakayama Shinpei, lyrics
  Shimamura Hōgetsu & Sōma Gyofū, 1914 (Geijutsuza, *Resurrection*).
- **Score to attach:** to be located at NDL Digital Collections
  during the Q6 review; melody documentation: OSU Rekion feature
  (https://library.osu.edu/site/japanese/2014/12/12/focus-on-rekion-shinpei-nakayama-%E4%B8%AD%E5%B1%B1%E6%99%8B%E5%B9%B3/).
- **Never use or upload any historical commercial recording.**
- **Facts:** 2/4 · 108 BPM · G major (major-pentatonic melody) ·
  2:18 · violin guide · verse slots 9-9 (rise-fall), chorus EVERYONE
  · house ratio ×1.414.

**PRIMARY FULL-LENGTH BASE (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1914 Japanese popular song "Katyusha no Uta"
by Nakayama Shinpei. Follow the melody, harmony and form of the
attached public-domain sheet music exactly — the melody uses a
major pentatonic scale — do not invent a merely similar tune.

Style and ensemble: a modest 1925 community-hall trio recorded
in a plain wooden room — upright piano, one violin, and a
tambourine played simply.

Non-negotiable musical facts: 2/4 meter throughout. Tempo 108
beats per minute, steady. Key of G major, melody in the major
pentatonic. Total duration about 2 minutes 18 seconds. No
fade-out.

Structure:
[0:00 - 0:07] four-bar intro: piano alone.
[0:07 - 0:42] first verse-and-chorus pass, light.
[0:42 - 1:17] second pass, tambourine in, a little fuller.
[1:17 - 1:33] 8-bar instrumental turn: violin leads openly.
[1:33 - 2:10] final pass, the fullest and friendliest.
[2:10 - 2:18] short close on the tonic; then brief wordless
applause and claps from a small group, cut naturally.

The violin quietly carries the vocal melody throughout as a
guide for a room of untrained singers, simple and clear, under
the piano. Leave the vocal register open: no instrument fills it
continuously; piano answers only at phrase ends; the verses stay
light so one voice can lead, and the final pass invites the
whole room without the band getting louder in a modern way.

Room character: a plain wooden community room; chairs and
movement audible between sections.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no lexical crowd vocals, no vocal samples.
No modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1914 Japanese popular song "Katyusha no Uta"
by Nakayama Shinpei. Follow the melody, harmony and form of the
attached public-domain sheet music exactly — the melody uses a
major pentatonic scale — do not invent a merely similar tune.

Style and ensemble: the same modest 1925 community-hall trio —
upright piano, one violin, tambourine — arranged SPARSELY: piano
alone for most of the piece, violin guide faint, tambourine only
in the final pass.

Non-negotiable musical facts: 2/4 meter throughout. Tempo 108
beats per minute, steady. Key of G major, melody in the major
pentatonic. Total duration about 2 minutes 18 seconds. No
fade-out.

Structure:
[0:00 - 0:07] four-bar intro: piano, very simple.
[0:07 - 0:42] first pass: piano only, violin guide a thread.
[0:42 - 1:17] second pass: unchanged instrumentation, slightly
warmer touch.
[1:17 - 1:33] 8-bar turn: violin's one open statement.
[1:33 - 2:10] final pass: tambourine enters, still airy.
[2:10 - 2:18] short close on the tonic; brief wordless applause
acceptable.

Keep the vocal register open at all times: no counter-melodies,
piano answers at most once per eight bars, the guide never rises
above the accompaniment.

Room character: a plain wooden community room.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no lexical crowd vocals, no vocal samples.
No modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS (gated with the track):**

1. *Vocals appeared:* "Regenerate exactly the same piece, strictly
   instrumental: remove all singing, humming, spoken words and
   voice-like sounds; only brief wordless applause at the very end
   may stay."
2. *Melody drifted:* "Regenerate following the attached sheet music
   exactly: the pentatonic melody of 'Katyusha no Uta' must be
   recognizable phrase by phrase. Do not substitute a similar
   tune."
3. *Too modern:* "Regenerate with only upright piano, violin and
   tambourine. Remove anything synthetic, any electronic drum,
   sub-bass, or loud modern mastering. A plain 1925 room."
4. *Vocal register crowded:* "Regenerate leaving the singer's range
   open: faint violin guide, no counter-melodies, piano answers
   only at phrase ends."
5. *Meter/tempo wrong:* "Regenerate in exact 2/4 at 108 beats per
   minute, steady."
6. *Fake vinyl noise:* "Regenerate with a clean signal: no vinyl
   crackle, no gramophone hiss, no old-record effect."
7. *Room character missing:* "Regenerate as one live take in a
   plain wooden community room — close, honest, chairs audible
   between sections."
8. *Weak after the ×1.414 return:* "Regenerate with a firmer piano
   left hand, clearer pass-to-pass build, and a brighter final
   pass — same tune, meter, tempo, key and instruments."

**Prompt tiers:** NON-NEGOTIABLE — 2/4 at 108, G pentatonic,
~2:18, source melody, instrumental-only, violin guide. DESIRABLE —
three-pass build, room plainness. EXPENDABLE — chairs, applause.
**Evaluation sheet:** the §3.1 eleven items on the FULL performance
(≈108 in 2/4; ×1.414 expectation: "a football chant from a gentler
planet; the applause becomes a firework") + **consultant approval
on file: PASS/FAIL**.

### 4.4 track_108 — NOBODY (AT SPEED)

> **DO NOT RUN — CONSULTATION REQUIRED.** Black-vaudeville history
> review (Music Bible §0-Q6) and the Q1 conduct rule in force: no
> blackface imagery, no dialect impersonation, no performance
> mimicry of Bert Williams in any produced layer, direction or
> marketing. The base is instrumental; the conduct rule still
> governs the whole track. Rights GREEN; the gate is cultural
> review.

- **Source:** "Nobody," music Bert Williams, lyrics Alex Rogers,
  pub. 1905 (Attucks Music Publishing Co.).
- **Score to attach:** Levy scan
  (https://levysheetmusic.mse.jhu.edu/collection/148/171) — attach
  the notation pages.
- **Never use or upload any historical commercial recording.**
- **Facts:** 4/4 · 66 BPM · C minor · 2:58 · trombone guide ·
  refrain slots 5-7-5 (flat-flat-fall), doubled rests · house ratio
  ×1.414.

**PRIMARY FULL-LENGTH BASE (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1905 song "Nobody," music by Bert Williams.
Follow the melody, harmony and form of the attached public-domain
sheet music exactly — do not invent a merely similar tune. Play
it perfectly straight and deadpan; never comic in the playing.

Style and ensemble: a very small, very dry 1926 office session —
one trombone, one harmonium (small reed organ), and a wooden
metronome ticking steadily through everything, never stopping.

Non-negotiable musical facts: 4/4 meter throughout. Tempo 66
beats per minute, patient and even. Key of C minor. Total
duration about 2 minutes 58 seconds. No fade-out.

The defining treatment: every notated rest in the vocal line is
held at DOUBLE its written length — where the sheet shows one bar
of rest, hold two full bars of near-silence in which only the
metronome ticks and the harmonium sustains very softly. Commit to
these silences completely.

Structure:
[0:00 - 0:15] intro: metronome alone for two bars, then
harmonium enters with the verse harmony.
[0:15 - 1:05] first verse and refrain with doubled rests.
[1:05 - 1:55] second verse and refrain with doubled rests, very
slightly warmer.
[1:55 - 2:12] 8-bar instrumental passage: trombone states the
refrain melody openly, still deadpan.
[2:12 - 2:52] final refrain with doubled rests.
[2:52 - 2:58] ending: on the final phrase the trombone and
harmonium cut dead together, leaving the metronome ticking alone
for two bars; then stop the metronome by hand. No fade.

The trombone quietly carries the vocal melody as the guide,
straight-faced, slightly under where a voice would sit. Leave the
vocal register completely open at all times: no instrument fills
it; the harmonium holds soft low chords; the doubled rests stay
truly empty except the metronome.

Room character: a small dry office at night; a clock, an
occasional wooden creak — quiet, deliberate, composed.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. No comedy sound
effects. Do not speed the music up. Do not make nightcore,
hyperpop, jungle, happy hardcore, or any modern electronic
style. Do not imitate or name any modern artist. Do not quote or
reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1905 song "Nobody," music by Bert Williams.
Follow the melody, harmony and form of the attached public-domain
sheet music exactly — do not invent a merely similar tune. Play
it perfectly straight and deadpan; never comic in the playing.

Style and ensemble: the same very small, very dry 1926 office
session — trombone, harmonium, wooden metronome — arranged even
more SPARSELY: the harmonium alone carries the harmony; the
trombone guide appears only in the instrumental passage and at
two phrase ends per refrain; the metronome never stops.

Non-negotiable musical facts: 4/4 meter throughout. Tempo 66
beats per minute, patient and even. Key of C minor. Total
duration about 2 minutes 58 seconds. Every notated vocal rest
held at DOUBLE its written length — two full bars of near-silence
with only the metronome and the softest harmonium. No fade-out.

Structure: as the primary — intro / two verse-refrain passes /
8-bar trombone passage / final refrain / the cut-dead ending
with the metronome alone, stopped by hand.

Keep the vocal register absolutely open: the singer's deadpan is
the whole performance, and this variant gives them nothing to
hide behind — which is the point.

Room character: a small dry office at night.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. No comedy sound
effects. Do not speed the music up. Do not make nightcore,
hyperpop, jungle, happy hardcore, or any modern electronic
style. Do not imitate or name any modern artist. Do not quote or
reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS (gated with the track):**

1. *Vocals appeared:* "Regenerate exactly the same piece, strictly
   instrumental: remove all singing, humming, spoken words and
   voice-like sounds. Change nothing else."
2. *Melody drifted:* "Regenerate following the attached sheet
   music exactly: the refrain melody of 'Nobody' must be
   recognizable phrase by phrase. Do not substitute a similar
   tune."
3. *Too modern:* "Regenerate with only trombone, harmonium and a
   wooden metronome. Remove anything synthetic or produced. A dry
   1926 office, nothing newer."
4. *Vocal register crowded:* "Regenerate with the vocal register
   completely empty: soft low harmonium chords only, trombone
   under the voice's range, nothing during the doubled rests but
   the metronome."
5. *Meter/tempo wrong:* "Regenerate in exact 4/4 at 66 beats per
   minute, patient and even, with every vocal rest held at double
   its written length."
6. *Fake vinyl noise:* "Regenerate with a clean signal: no vinyl
   crackle, no gramophone hiss, no old-record effect."
7. *Room character missing:* "Regenerate as one live take in a
   small dry office at night — close, quiet, composed, the
   metronome plainly audible."
8. *Weak after the ×1.414 return:* "Regenerate with the silences
   even more absolute and the cut-dead ending tighter — same tune,
   meter, tempo, key and instruments. The silences are the
   performance."

**Prompt tiers:** NON-NEGOTIABLE — 4/4 at 66, C minor, ~2:58,
source melody, doubled rests truly empty, instrumental-only,
trombone guide, deadpan direction, cut-dead ending. DESIRABLE —
office dryness, metronome-alone bars. EXPENDABLE — clock, creak.
**Evaluation sheet:** the §3.1 eleven items on the FULL performance
(≈66 in 4/4; ×1.414 expectation: "the doubled rests land at their
true written length — the return restores the song's timing; the
metronome becomes a woodblock sprint") + **consultant approval on
file: PASS/FAIL**.

### 4.5 track_112 — THE ALPHABET SONG (BURNING BRIGHT)

> **DO NOT RUN — CONSULTATION REQUIRED.** Yiddish-material review
> (Music Bible §0-Q6) covering text, pronunciation, the seltzer-
> family fiction and credits wording. Rights GREEN; the gate is
> cultural review.

- **Source:** "Oyfn Pripetshik" ("Der Alef-Beyz"), words and music
  Mark M. Warshawsky, 1890s, pub. 1901.
- **Score to attach:** Workers Circle Mlotek collection page with
  notation (https://yiddishsongs.org/oyfn-pripetshik/).
- **Never use or upload any historical commercial recording.**
- **Facts:** 2/4 · 72 BPM · D minor · 3:05 · mandolin guide · verse
  slots 10-10-8 (all falling), duet custom · house ratio ×1.26.

**PRIMARY FULL-LENGTH BASE (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the Yiddish song "Oyfn Pripetshik" by Mark
Warshawsky, published 1901. Follow the melody, harmony and form
of the attached public-domain sheet music exactly — do not
invent a merely similar tune. Play it tenderly and a little
playfully, like family music for a child — warm, not mournful.

Style and ensemble: a small 1926 back-room session at a seltzer
depot — harmonium (small reed organ), mandolin, a soft brushed
rhythm played with wire brushes on a wooden shipping crate in an
unhurried half-time feel throughout, and the gentle sympathetic
ringing of glass bottles on one shelf that softly answers loud
notes.

Non-negotiable musical facts: 2/4 meter throughout. Tempo 72
beats per minute, unhurried. Key of D minor. Total duration
about 3 minutes 5 seconds. No fade-out.

Structure:
[0:00 - 0:10] intro: harmonium alone, then the brushed crate
enters.
[0:10 - 1:00] first verse and refrain, light.
[1:00 - 1:50] second verse and refrain, mandolin tremolo a
little warmer; exactly one small displaced accent in the brushed
rhythm somewhere in this section, like a gentle hiccup, then
back to even time.
[1:50 - 2:10] 8-bar instrumental turn: mandolin leads, bottles
ringing quietly.
[2:10 - 2:58] final verse and refrain, the warmest.
[2:58 - 3:05] soft close on the tonic minor; let the last
bottle-ring die away naturally.

The mandolin quietly carries the vocal melody throughout as a
guide for two singers a generation apart, simple tremolo, under
the harmonium. Leave the vocal register open at all times: no
instrument fills it continuously; answers only at phrase ends;
keep the whole performance modest enough that a grandparent and
a child could sing over it comfortably.

Room character: a small storeroom — close, warm, slightly
cluttered; distant cart wheels outside acceptable; the
harmonium's soft air leak acceptable.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. No exaggerated klezmer
ornamentation, no strings section, no choir, no melodrama. Do
not speed the music up. Do not make nightcore, hyperpop,
jungle, happy hardcore, or any modern electronic style. Do not
imitate or name any modern artist. Do not quote or reproduce
any historical recording.
```

**SPARSER KARAOKE VARIANT — full length (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the Yiddish song "Oyfn Pripetshik" by Mark
Warshawsky, published 1901. Follow the melody, harmony and form
of the attached public-domain sheet music exactly — do not
invent a merely similar tune. Play it tenderly and a little
playfully, like family music for a child — warm, not mournful.

Style and ensemble: the same small 1926 seltzer-depot session —
harmonium, mandolin, brushed crate, sympathetic bottle ring —
arranged even more SPARSELY: harmonium and crate only for the
verses; the mandolin guide is a whisper and takes full voice
only in the instrumental turn; bottle ring rare.

Non-negotiable musical facts: 2/4 meter throughout. Tempo 72
beats per minute, unhurried. Key of D minor. Total duration
about 3 minutes 5 seconds. No fade-out.

Structure: as the primary — intro / two verse-refrain passes /
8-bar mandolin turn / final pass / soft close with the last
bottle-ring dying away.

Keep the vocal register open at all times: no counter-melodies,
answers at most once per phrase pair; the performance stays
modest enough for a grandparent and a child to sing over
comfortably, with even more room than the primary.

Room character: a small storeroom — close, warm, slightly
cluttered.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. No exaggerated klezmer
ornamentation, no strings section, no choir, no melodrama. Do
not speed the music up. Do not make nightcore, hyperpop,
jungle, happy hardcore, or any modern electronic style. Do not
imitate or name any modern artist. Do not quote or reproduce
any historical recording.
```

**TARGETED CORRECTION PROMPTS (gated with the track):**

1. *Vocals appeared:* "Regenerate exactly the same piece, strictly
   instrumental: remove all singing, humming, spoken words and
   voice-like sounds. Change nothing else."
2. *Melody drifted:* "Regenerate following the attached sheet
   music exactly: Warshawsky's melody must be recognizable phrase
   by phrase. Do not substitute a similar tune."
3. *Too modern:* "Regenerate with only harmonium, mandolin,
   brushed wooden crate and natural glass resonance. Remove
   anything synthetic or produced. A warm 1926 storeroom."
4. *Vocal register crowded:* "Regenerate leaving the singers'
   range open: whisper-level mandolin guide, no counter-melodies,
   answers only at phrase ends — room for a grandparent and a
   child."
5. *Meter/tempo wrong:* "Regenerate in exact 2/4 at 72 beats per
   minute, unhurried, with the brushed half-time feel throughout."
6. *Fake vinyl noise:* "Regenerate with a clean signal: no vinyl
   crackle, no gramophone hiss, no old-record effect."
7. *Room character missing:* "Regenerate as one live take in a
   small, warm, slightly cluttered storeroom, with the soft
   sympathetic ring of glass bottles answering louder notes."
8. *Weak after the ×1.26 return:* "Regenerate with the brushed
   crate slightly more present and the section warmth building
   more clearly to the final pass — same tune, meter, tempo, key
   and instruments. Keep it gentle; the return is the catalogue's
   gentlest."

**Prompt tiers:** NON-NEGOTIABLE — 2/4 at 72, D minor, ~3:05,
source melody, instrumental-only, mandolin guide, warm-not-
mournful, half-time brush feel. DESIRABLE — bottle resonance, the
single displaced accent, harmonium leak. EXPENDABLE — cart wheels.
**Evaluation sheet:** the §3.1 eleven items on the FULL performance
(≈72 in 2/4; ×1.26 expectation: "the gentlest return — a young
voice's tempo, a glockenspiel nobody owns, never silly") +
**consultant approval on file: PASS/FAIL**.

---

## 5. GROUP C — GREEN RESERVE AUDITIONS

*Every entry: `RESERVE — NOT PROMOTED`. Parameters marked PROVISIONAL
are audition proposals, not canon; promotion requires the Q6
consultation for its material and a passed full-length audition. Each
reserve carries the same trio: PRIMARY FULL-LENGTH BASE, SPARSER
KARAOKE VARIANT, TARGETED CORRECTION PROMPTS. Reserve corrections use
the same eight-slot convention as §2; where a correction below says
"standard," paste the corresponding correction from §3.1 with this
track's title, meter, tempo, key, guide and room substituted — the
track-specific corrections that differ are written out.*

### 5.1 DAISY BELL (GO FASTER) — `RESERVE — NOT PROMOTED`

- **Source:** "Daisy Bell (A Bicycle Built for Two)," Harry Dacre,
  1892. GREEN (d. 1922). **Score:** Levy
  (https://levysheetmusic.mse.jhu.edu/collection/140/090); IMSLP
  (https://imslp.org/wiki/Daisy_Bell_(Dacre,_Harry)); UW-Madison
  (https://search.library.wisc.edu/digital/AN22C7MP6ACVCM8H). Never
  use or upload any historical commercial recording.
- **PROVISIONAL facts:** 3/4 · 92 BPM · G major · ~2:20 · concertina
  guide · ratio ×1.414. Note (Q2): would be Volume One's THIRD
  waltz; substitutes only into a vacated waltz slot.

**PRIMARY FULL-LENGTH BASE:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1892 waltz song "Daisy Bell (A Bicycle Built
for Two)" by Harry Dacre. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: an amateur 1926 cycling-club parlor band —
concertina, violin, banjo, upright piano, and a small choir of
real bicycle bells played rhythmically as percussion.

Non-negotiable musical facts: 3/4 waltz meter throughout. Tempo
92 beats per minute, steady. Key of G major. Total duration about
2 minutes 20 seconds. No fade-out.

Structure:
[0:00 - 0:10] four-bar intro: piano and one polite bicycle bell.
[0:10 - 0:52] 16-bar verse, light.
[0:52 - 1:13] 16-bar chorus, full band, bells on the offbeats.
[1:13 - 1:34] 16-bar verse.
[1:34 - 1:45] 8-bar bell-choir turn: the bells carry the rhythm
while the violin sketches the tune.
[1:45 - 2:10] 16-bar final chorus, the fullest and silliest.
[2:10 - 2:20] 4-bar close ending together on the tonic with one
last bell ring.

The concertina quietly carries the vocal melody as the singer's
guide, under the violin. Leave the vocal register open
throughout: no instrument fills it continuously; bicycle-bell and
violin answers only at phrase ends.

Dynamics: verses lighter, choruses fuller, cheerful and homemade
from start to finish.

Room character: a parlor with wooden floors; close, warm,
amateur.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1892 waltz song "Daisy Bell (A Bicycle Built
for Two)" by Harry Dacre. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: the same amateur 1926 cycling-club parlor
band — concertina, violin, banjo, upright piano, bicycle bells —
arranged SPARSELY: piano and banjo carry the waltz; the violin
plays only in the turn and final chorus; the bicycle bells ring
only in the turn and at the last close; the concertina guide is
faint.

Non-negotiable musical facts: 3/4 waltz meter throughout. Tempo
92 beats per minute, steady. Key of G major. Total duration about
2 minutes 20 seconds. No fade-out.

Structure:
[0:00 - 0:10] four-bar intro: piano alone.
[0:10 - 0:52] 16-bar verse: piano and banjo only.
[0:52 - 1:13] 16-bar chorus: unchanged trio, faint concertina
guide.
[1:13 - 1:34] 16-bar verse.
[1:34 - 1:45] 8-bar turn: bells and violin, briefly.
[1:45 - 2:10] 16-bar final chorus: violin joins, still airy.
[2:10 - 2:20] 4-bar close on the tonic with one last bell ring.

Keep the vocal register open at all times: no counter-melodies;
answers at most once per eight bars; the guide never rises above
the accompaniment.

Dynamics: modest, cheerful, homemade.

Room character: a parlor with wooden floors; close, warm,
amateur.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS:** standard slots 1–7 per §5 note
(title "Daisy Bell," 3/4 at 92, G major, concertina guide, parlor
room). 8. *Weak after ×1.414:* "Regenerate with firmer piano
downbeats and the bell accents cleaner on the offbeats — same tune,
meter, tempo, key and instruments; the return should ring, not
smear."

### 5.2 LA PALOMA (COME BACK TO ME) — `RESERVE — NOT PROMOTED`

> **CONSULTATION REQUIRED before any run:** Spanish-language
> material review (Q6).

- **Source:** "La Paloma," Sebastián Iradier, ~1863. GREEN
  (d. 1865). **Score:** locate a public-domain scan via Levy / LoC /
  IMSLP at promotion; none verified this pass — do not run from
  memory. Never use or upload any historical commercial recording.
- **PROVISIONAL facts:** 2/4 habanera · 76 BPM · D major · ~2:40 ·
  guitar-treble guide · ratio ×1.335.

**PRIMARY FULL-LENGTH BASE (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the habanera "La Paloma" by Sebastián Iradier,
composed in the 1860s. Follow the melody, harmony and form of the
attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: a small 1926 boarding-house kitchen session —
one nylon-strung guitar carrying both the habanera bass rhythm
and the melody on the treble strings, and a second player tapping
the habanera pattern softly on a wooden crate.

Non-negotiable musical facts: 2/4 meter with the habanera rhythm
(dotted-eighth, sixteenth, two eighths) held steadily throughout.
Tempo 76 beats per minute. Key of D major. Total duration about 2
minutes 40 seconds. No fade-out.

Structure:
[0:00 - 0:13] four-bar intro: the habanera rhythm alone, then the
treble melody enters.
[0:13 - 0:55] verse, intimate.
[0:55 - 1:20] chorus, slightly fuller.
[1:20 - 1:50] second verse.
[1:50 - 2:03] 8-bar guitar turn: the melody stated openly on the
treble strings.
[2:03 - 2:30] final chorus, the warmest.
[2:30 - 2:40] gentle close on the tonic; let the last chord ring.

The guitar's treble melody is the singer's guide, warm and
unhurried, never busy. Leave the vocal register open throughout:
melody stated simply, answers only at phrase ends; the habanera
sway never stops.

Room character: a small kitchen at night, close and intimate; a
little household quiet around the edges.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the habanera "La Paloma" by Sebastián Iradier,
composed in the 1860s. Follow the melody, harmony and form of the
attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: the same small 1926 boarding-house kitchen
session — nylon-strung guitar and a wooden crate tapped softly —
arranged SPARSELY: the treble melody is stated only in the intro,
the turn, and the first two bars of each verse and chorus;
elsewhere the guitar plays the habanera rhythm and bass alone,
and the singer owns the tune.

Non-negotiable musical facts: 2/4 meter with the habanera rhythm
(dotted-eighth, sixteenth, two eighths) held steadily throughout.
Tempo 76 beats per minute. Key of D major. Total duration about 2
minutes 40 seconds. No fade-out.

Structure:
[0:00 - 0:13] four-bar intro: rhythm alone, then a single treble
statement of the first phrase.
[0:13 - 0:55] verse: rhythm and bass; melody only in the first
two bars.
[0:55 - 1:20] chorus: the same discipline.
[1:20 - 1:50] second verse.
[1:50 - 2:03] 8-bar turn: the melody's one open statement.
[2:03 - 2:30] final chorus, warm but bare.
[2:30 - 2:40] gentle close on the tonic; let the last chord ring.

Keep the vocal register open at all times: no counter-melodies,
no fills between phrases; the habanera sway never stops.

Room character: a small kitchen at night, close and intimate.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS (gated):** standard slots 1–7 ("La
Paloma," 2/4 habanera at 76, D major, guitar-treble guide, kitchen
room; slot 5 adds "keep the dotted habanera rhythm exact").
8. *Weak after ×1.335:* "Regenerate with the crate taps slightly
more present and the habanera bass more even — same tune, meter,
tempo, key and instruments; at speed the sway should become a
glide."

### 5.3 MOLIHUA (JASMINE ALL NIGHT) — `RESERVE — NOT PROMOTED`

> **CONSULTATION REQUIRED before any run:** Chinese-language
> material review (Q6), including romanization and phrase-guide
> language.

- **Source:** "Molihua" (Jasmine Flower), traditional Chinese
  melody, in print since the 18th century (Barrow, 1804). GREEN
  (traditional; arrangement ours). **Score:** locate a public-
  domain transcription during the Q6 review; none verified this
  pass — do not run from memory. Never use or upload any
  historical commercial recording.
- **PROVISIONAL facts:** 4/4 · 66 BPM · G major (pentatonic) ·
  ~2:30 · erhu guide · ratio ×1.26.

**PRIMARY FULL-LENGTH BASE (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the traditional Chinese melody "Molihua" (Jasmine
Flower). Follow the melody and form of the attached public-domain
transcription exactly — the tune is pentatonic — do not invent a
merely similar tune.

Style and ensemble: a quiet 1926 upstairs tea-room duo — erhu
(two-string bowed fiddle) and yangqin (hammered dulcimer),
recorded close and gently.

Non-negotiable musical facts: 4/4 meter throughout. Tempo 66
beats per minute, flowing. Key of G major, melody pentatonic.
Total duration about 2 minutes 30 seconds. No fade-out.

Structure:
[0:00 - 0:12] short intro: yangqin alone, sketching the first
phrase.
[0:12 - 0:55] first full statement of the melody: erhu leads,
gentle.
[0:55 - 1:38] second statement: yangqin leads the melody, erhu
resting to soft harmonies.
[1:38 - 2:20] third statement: erhu leads again, the warmest
pass, yangqin arpeggios fuller.
[2:20 - 2:30] soft close on the tonic; let the last yangqin
notes ring away naturally.

The erhu (and in the second statement the yangqin) quietly
carries the melody as the singer's guide, plain and singing in
tone. Leave the vocal register open throughout: the guide states
the tune simply and yields space at phrase ends; nothing is
busy.

Room character: a small upstairs room over a shop; close, warm,
unhurried.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the traditional Chinese melody "Molihua" (Jasmine
Flower). Follow the melody and form of the attached public-domain
transcription exactly — the tune is pentatonic — do not invent a
merely similar tune.

Style and ensemble: the same quiet 1926 upstairs tea-room duo —
erhu and yangqin — arranged SPARSELY: the erhu whispers the
melody only in the first statement; the second and third
statements are yangqin accompaniment alone, with the tune stated
once at each section's entrance — the singer carries it.

Non-negotiable musical facts: 4/4 meter throughout. Tempo 66
beats per minute, flowing. Key of G major, melody pentatonic.
Total duration about 2 minutes 30 seconds. No fade-out.

Structure:
[0:00 - 0:12] short intro: yangqin alone.
[0:12 - 0:55] first statement: erhu whispers the melody.
[0:55 - 1:38] second statement: yangqin accompaniment; the tune
appears only in the entrance bars.
[1:38 - 2:20] third statement: the same discipline, slightly
warmer.
[2:20 - 2:30] soft close on the tonic; let the last yangqin
notes ring away naturally.

Keep the vocal register open at all times: nothing is busy;
answers only at phrase ends; the guide never rises above the
accompaniment.

Room character: a small upstairs room over a shop; close, warm,
unhurried.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS (gated):** standard slots 1–7
("Molihua," 4/4 at 66, G pentatonic, erhu guide, tea-room). 8.
*Weak after ×1.26:* "Regenerate with the yangqin attacks slightly
clearer and the third statement warmer — same tune, meter, tempo,
key and instruments; the gentlest return must still bloom."

### 5.4 SANTA LUCIA (ROW US HOME) — `RESERVE — NOT PROMOTED`

*(Consultation recommended for Neapolitan material under Q6's
standing rule; not on the owner's named gate list.)*

- **Source:** "Santa Lucia," Teodoro Cottrau, 1849. GREEN
  (d. 1879). **Score:** locate a public-domain scan via Levy /
  LoC / IMSLP at promotion; none verified this pass — do not run
  from memory. Never use or upload any historical commercial
  recording.
- **PROVISIONAL facts:** 3/8 barcarolle · dotted-quarter ≈ 50 ·
  E♭ major · ~2:30 · mandolin guide · ratio ×1.335.

**PRIMARY FULL-LENGTH BASE:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the Neapolitan barcarolle "Santa Lucia" by Teodoro
Cottrau, published 1849. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: a 1926 dawn pier-shed trio — mandolin,
concertina, and one guitar keeping the rocking barcarolle sway.

Non-negotiable musical facts: 3/8 meter with a gentle rocking
sway throughout, about 50 dotted-quarter beats per minute. Key of
E-flat major. Total duration about 2 minutes 30 seconds. No
fade-out.

Structure:
[0:00 - 0:10] intro: guitar sway alone, then concertina chords.
[0:10 - 0:45] verse, intimate.
[0:45 - 1:10] chorus, fuller, mandolin tremolo warm.
[1:10 - 1:40] second verse.
[1:40 - 1:52] 8-bar mandolin turn: the melody stated openly.
[1:52 - 2:20] final chorus, the warmest.
[2:20 - 2:30] gentle close on the tonic; the sway settles like a
boat touching the dock.

The mandolin quietly carries the melody in tremolo as the
singer's guide, under the concertina's held chords. Leave the
vocal register open throughout: answers only at phrase ends; the
sway never stops until the final bars.

Room character: a wooden pier shed at dawn — close, a little
boxy, calm; distant water and gulls acceptable but not required.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length:**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the Neapolitan barcarolle "Santa Lucia" by Teodoro
Cottrau, published 1849. Follow the melody, harmony and form of
the attached public-domain sheet music exactly — do not invent a
merely similar tune.

Style and ensemble: the same 1926 dawn pier-shed trio — mandolin,
concertina, guitar — arranged SPARSELY: the verses ride on the
guitar's rocking sway and soft concertina chords alone; the
mandolin tremolo appears only at section entrances and in the
turn — the singer owns the tune.

Non-negotiable musical facts: 3/8 meter with a gentle rocking
sway throughout, about 50 dotted-quarter beats per minute. Key of
E-flat major. Total duration about 2 minutes 30 seconds. No
fade-out.

Structure:
[0:00 - 0:10] intro: guitar sway alone.
[0:10 - 0:45] verse: sway and soft chords; mandolin only at the
entrance.
[0:45 - 1:10] chorus: the same discipline, slightly warmer.
[1:10 - 1:40] second verse.
[1:40 - 1:52] 8-bar turn: the mandolin's one open statement.
[1:52 - 2:20] final chorus, warm but bare.
[2:20 - 2:30] gentle close on the tonic; the sway settles like a
boat touching the dock.

Keep the vocal register open at all times: answers only at phrase
ends; the sway never stops until the final bars.

Room character: a wooden pier shed at dawn — close, a little
boxy, calm.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS:** standard slots 1–7 ("Santa
Lucia," 3/8 sway at dotted-quarter 50, E♭, mandolin guide, pier
shed; slot 5 adds "keep the rocking 3/8 sway — never straighten it
to march time"). 8. *Weak after ×1.335:* "Regenerate with the
guitar sway more even and the final chorus warmer — same tune,
meter, tempo, key and instruments; at speed the rocking should
become a hands-locked side-to-side."

### 5.5 LA GOLONDRINA (THE SWALLOW) — `RESERVE — NOT PROMOTED`

> **CONSULTATION REQUIRED before any run:** Spanish-language
> material review (Q6).

- **Source:** "La Golondrina," Narciso Serradell Sevilla, 1862.
  GREEN (d. 1910). **Score:** locate a public-domain scan via
  Levy / LoC / IMSLP at promotion; none verified this pass — do
  not run from memory. Never use or upload any historical
  commercial recording.
- **PROVISIONAL facts:** 3/4 · 72 BPM · G major · ~2:45 ·
  harp-style guitar guide · ratio ×1.335.

**PRIMARY FULL-LENGTH BASE (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1862 Mexican song "La Golondrina" by Narciso
Serradell. Follow the melody, harmony and form of the attached
public-domain sheet music exactly — do not invent a merely
similar tune. Play it tenderly; it is a farewell song about a
swallow flying home.

Style and ensemble: a small 1926 family session above a tailor's
shop — one harp-tuned guitar playing flowing arpeggios that carry
the melody on the top strings, and a second guitar holding soft
bass and chords.

Non-negotiable musical facts: 3/4 meter, flowing, throughout.
Tempo 72 beats per minute. Key of G major. Total duration about 2
minutes 45 seconds. No fade-out.

Structure:
[0:00 - 0:12] intro: the arpeggio pattern alone, settling.
[0:12 - 0:55] verse, intimate.
[0:55 - 1:22] chorus, slightly fuller.
[1:22 - 1:55] second verse.
[1:55 - 2:08] 8-bar guitar turn: the melody stated openly on the
top strings.
[2:08 - 2:38] final chorus, the tenderest.
[2:38 - 2:45] gentle close on the tonic; let the last arpeggio
ring away.

The first guitar's top-string melody is the singer's guide, clear
but gentle. Leave the vocal register open throughout: the
arpeggios flow underneath and yield the melody register whenever
a voice would enter; answers only at phrase ends.

Room character: a small workroom, close and warm; a little
street air acceptable.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**SPARSER KARAOKE VARIANT — full length (gated):**

```
Compose a fully instrumental karaoke backing track: a complete
performance of the 1862 Mexican song "La Golondrina" by Narciso
Serradell. Follow the melody, harmony and form of the attached
public-domain sheet music exactly — do not invent a merely
similar tune. Play it tenderly; it is a farewell song about a
swallow flying home.

Style and ensemble: the same small 1926 family session above a
tailor's shop — two guitars — arranged SPARSELY: the top-string
melody is stated only in the intro and the turn; elsewhere the
arpeggios avoid the melody register entirely and the second
guitar holds soft bass and chords — the singer owns the tune.

Non-negotiable musical facts: 3/4 meter, flowing, throughout.
Tempo 72 beats per minute. Key of G major. Total duration about 2
minutes 45 seconds. No fade-out.

Structure:
[0:00 - 0:12] intro: arpeggios with one statement of the first
phrase.
[0:12 - 0:55] verse: arpeggios below the melody register.
[0:55 - 1:22] chorus: the same discipline, slightly fuller.
[1:22 - 1:55] second verse.
[1:55 - 2:08] 8-bar turn: the melody's one open statement on the
top strings.
[2:08 - 2:38] final chorus, the tenderest, still bare.
[2:38 - 2:45] gentle close on the tonic; let the last arpeggio
ring away.

Keep the vocal register open at all times: no counter-melodies,
answers only at phrase ends.

Room character: a small workroom, close and warm; a little
street air acceptable.

Strictly instrumental only: no singing, no spoken words, no
chanting, no humming, no crowd voices, no vocal samples. No
modern synthesizers, no electronic drums, no sub-bass, no
sidechain pumping, no modern mastering loudness, no pitch
correction, no rigid grid quantization. No vinyl crackle and no
fake gramophone or old-recording effect. Do not speed the music
up. Do not make nightcore, hyperpop, jungle, happy hardcore, or
any modern electronic style. Do not imitate or name any modern
artist. Do not quote or reproduce any historical recording.
```

**TARGETED CORRECTION PROMPTS (gated):** standard slots 1–7 ("La
Golondrina," 3/4 at 72, G major, top-string guide, workroom). 8.
*Weak after ×1.335:* "Regenerate with the bass guitar steadier
and the final chorus more openly tender — same tune, meter,
tempo, key and instruments; the farewell should fly at speed, not
flutter."

---

## 6. GROUP D — RIGHTS HOLDS: NO GENERATION PROMPTS PROVIDED

*Per Music Bible §13 (Q2), the following are creatively retained and
**excluded from all audio generation and production procurement**
until counsel clears them. This promptbook deliberately contains no
runnable prompt for any of them; writing one before clearance is a
process violation.*

| Track | Work | Hold reason | Earliest expected relief |
|---|---|---|---|
| track_102 | Gondola no Uta (Nakayama/Yoshii, 1915) | Fourth AMBER; Directive 2011/77/EU last-surviving-author rule — even the instrumental's EU status is COUNSEL REVIEW, not asserted | 2031-01-01, or counsel opinion |
| track_107 | Some of These Days (Brooks, 1910) | Brooks d. 1975; life+70 territories to 2045-12-31 | 2046-01-01, or counsel opinion |
| track_109 | Yes! We Have No Bananas (Silver/Cohn, 1923) | Cohn d. 1961; life+70 territories to 2031-12-31 | 2032-01-01, or counsel opinion |
| track_110 | After You've Gone (Layton/Creamer, 1918) | Layton d. 1978; life+70 territories to 2048-12-31 | 2049-01-01, or counsel opinion |
| — | The Prisoner's Song (credited Massey, 1924) | HOLD on provenance integrity (Q2): tangled authorship conflicts with the project's own attribution rule | An honestly resolvable authorship story |

**No audio generation or procurement may begin for any row of this
table before clearance.** The all-GREEN audition slate (§5) stands
behind every hold.

---

## 7. PROVENANCE MANIFEST — save one beside every generated audition

```
ORISON SONGBOOK AUDITION MANIFEST
----------------------------------
track id:                  (e.g. track_101)
promptbook revision:       (git commit of this file used)
prompt used:               (PRIMARY / SPARSER / +corrections, with
                           verbatim text or exact § reference)
score attached:            (source name + URL + pages attached)
historical recordings:     NONE USED — confirm: ____
gemini/lyria product:      (app tier or API model id shown by the UI)
model displayed:           (e.g. lyria-3-pro-preview)
generation date:           (YYYY-MM-DD)
output filename:           (as archived, with format/sample rate)
length cap encountered:    (none, or the cap the interface displayed)
synthid / ai disclosure:   (watermark noted? disclosure text?)
legal status:              (GREEN / HOLD ref Music Bible §13)
consultation status:       (n/a | required-pending | approved by ___)
owner audition result:     (full-performance PASS/FAIL sheet attached)
rejection reason:          (which sheet item failed, or —)
selected candidate:        (filename, or —)
production decision:       (re-record live / retain audition / defer)
----------------------------------
Gemini outputs are AUDITION MATERIAL, not approved shipping masters.
Nothing enters game/assets before the owner approves the sound AND
the applicable commercial-use terms, rights, consultation and
provenance requirements are reviewed.
```

## 8. KNOWN LIMITATIONS — what these prompts cannot prove

- **Exact melody fidelity is not guaranteed.** Score images are
  accepted as context, but nothing promises note-accurate reading of
  notation; the model may return a similar-but-wrong tune. That is
  why "recognizable source melody" is the first evaluation item and
  an automatic rejection — the prompt asks for fidelity; only a human
  comparing against the score can verify it.
- **Negative constraints are requests, not switches.** Vocals are on
  by default in the product; "instrumental only" is honored as an
  instruction, not a mode. Expect occasional hummed or voiced
  artifacts; use correction 1 and reject.
- **Structure timestamps are approximate.** Section tags steer form;
  bar-exact boundaries and totals drift (±10% is normal). Meter is
  usually honored; cut time versus fast 4/4 may need correction 5.
- **Period fidelity is stylistic, not organological.** Near-neighbor
  substitutions happen (alto sax for clarinet, kit for brushes);
  correction 3 targets them; the evaluation sheet decides.
- **No multi-turn audio editing.** Every fix is a fresh regeneration
  from the original prompt plus a targeted correction; log each
  attempt in the manifest.
- **Output format:** WAV via the API's `response_format`; the app
  delivers MP3/MP4. Convert to 48 kHz before the return test; note
  lossy sources in the manifest.
- **Interface length caps, if ever displayed,** do not shorten any
  prompt in this book: run the primary unchanged, audition the
  partial result for texture only, note the cap in the manifest
  (§1's fallback). Do not assume a legacy 30-second limit — none
  applies.
- **SynthID is always present** in generated audio and is a required
  manifest field, not a defect.
- **A synthetic singer proves nothing.** A generated voice is not a
  valid stand-in for the player-vocal return test (§3.4 step 2);
  auditions of the return use a real scratch vocal over the full
  form, always.
