# THE SONGBOOK — COMMUNITY KARAOKE BRIEF

Filed 2026-08-07, verbatim from the owner. Task #53 carries the
implementation order; this file is the reference text. It supersedes the
Harukiya brief's Phase 7 (karaoke gameplay): the timed-lyrics system
described there becomes Phase 1 of this. NPC musical preference ties
into the archetype/schedule work (task #50, ORISON_ARCHETYPE_SCHEDULES)
— the residents ARE the bar's cultural memory.

Central rule, kept where it can be seen: this is a folk-music simulator
disguised as a shitty karaoke machine. The target moment is walking in
on someone performing a song you wrote — and the NPCs already knowing
the chorus.

---

## CORE IDEA

Implement a unique interactive karaoke system. The goal is not
SingStar/Guitar Hero with pitch scoring. The karaoke bar functions as a
**community song mutation machine**: players write lyrics, perform them,
record vocals, cover other players, alter existing songs, create duets,
and gradually establish songs that become part of the simulated culture
of the bar.

Create approximately 30–50 original instrumental karaoke tracks. Each
base track contains: instrumental backing track · optional isolated
stems · BPM · musical key · section timing · simple melody guide ·
lyric phrase slots · genre/mood metadata.

**There are initially no canonical lyrics.** The instrumental
deliberately leaves space for vocals.

Example: TRACK 018 — LAST TRAIN HOME · 92 BPM · F minor · Power Ballad.
Nobody has written words for this yet. A player writes lyrics and
performs them; their version is saved as a community-authored version.
Other players can later: **COVER** (sing the existing lyrics) ·
**REWRITE** (altered lyrics) · **MUTATE** (keep some sections, change
others) · **DUET** (add another vocal part) · **ANSWER** (a response
song from another perspective) · **START OVER** (only the original
instrumental) · **ADD HARMONY** (another vocal layer on an existing
recording).

Every version maintains its ancestry. Never overwrite older versions.
Preserve a visible song genealogy:

```
LAST TRAIN HOME
     +-- Lily version
     |      +-- Erica cover
     |      +-- alternate verse
     |      +-- comedy mutation
     +-- completely different lyrics
            +-- duet version
```

## THE SONGBOOK

Represent the system diegetically through the battered physical karaoke
binder and terminal in the bar. Each instrumental is a musical template;
the Songbook may contain thousands of player-created variants built from
a much smaller library of backing compositions. Browse categories: New
Songs · Local Classics · Recently Written · Most Covered · Most Mutated
· Duets · Forgotten Songs · Weirdest Branches · Songs Nobody Has
Finished · My Songs. Avoid a sterile social-media UI — it is a karaoke
machine in a shitty basement bar.

## NO TRADITIONAL SINGING SCORE

Do NOT score primarily on pitch. Bad singing is part of karaoke. The
game's fundamental response is: **YOU DID KARAOKE.** Track
social/cultural outcomes instead: **CROWD ENERGY** (NPC response) ·
**COMMITMENT** (did the singer finish) · **SINGALONG** (did anyone join
the chorus) · **LEGACY** (how often later players perform this version)
· **MUTATION** (how many songs descended from it). Never punish unusual
voices; a terrible singer can create the most culturally significant
song in the game.

## LYRIC WRITING

No DAW. An extremely simple lyric editor over predefined melodic phrase
slots:

```
VERSE 1
0:14 -------- 0:19   [____________________________]
0:20 -------- 0:25   [____________________________]
0:26 ----- 0:29      [_____________________]
```

Slot metadata: start_time · end_time · suggested_syllable_count ·
melodic_shape · section · optional_prompt. Entered lyrics automatically
become timed karaoke lyrics. Optional UI may hint a line is probably too
long/short but never prevents experimentation. No music theory required.

## CREATIVE MODES

NORMAL (write anything) · PROMPTED ("Write about realizing you missed
the last train.") · THREE WORDS (must incorporate e.g. telephone,
cigarettes, Tuesday) · ANSWER SONG · GENRE WRONG (death-metal lyrics
over cheerful city pop) · ONE LINE EACH (each community member one
line) · EXQUISITE CORPSE (write a section blind, reveal after) ·
CONFESSIONAL (anonymous) · TRANSLATION (new-language interpretation).
These defeat the blank page.

## GHOST DUETS

Asynchronous collaboration: Player A records lead; later Player B picks
SING WITH A STRANGER — A's vocal plays while B records harmony; later
another player adds backing. A performance may hold LEAD VOCAL · HARMONY
· BACKING VOCAL · GROUP SHOUT from players who never met. Store each
vocal separately; never permanently bake vocals together except as a
temporary playback cache.

## CALL AND RESPONSE

Some tracks include alternating phrase slots ("I told the bartender
_____" / "YOU ABSOLUTELY DID NOT!" / … / Everyone: "TONIGHT WE'RE GOING
HOME!"). Players create one half and leave response slots for future
performers.

## MUSIC DESIGN

Backing music = **karaoke skeletons**, not finished instrumentals:
arrangements deliberately leave room for a vocalist; a quiet
melody-guide instrument in previews, near-silent during performance.
Example direction: late-1980s Japanese-influenced urban power ballad,
84 BPM, F minor; drum machine, fretless bass, chorused electric piano,
restrained digital bell synth, clean chorus guitar, sparse saxophone
responses; strong four-bar vocal phrases with generous space; no vocals,
no spoken word, no choir. Styles: city pop · synth pop · new wave ·
punk · power ballad · post-punk · lounge · cheesy rock anthem · novelty
· slow torch song · dance · strange experimental. No copyrighted
melodies.

## DATA ARCHITECTURE

`SongResource`: id · title · genre · bpm · key · instrumental_audio ·
melody_guide_audio · preview_audio · duration · sections[] ·
phrase_slots[] · community_versions[].
`SongSection`: name · start_time · end_time.
`PhraseSlot`: id · section · start_time · end_time ·
suggested_syllables · melodic_shape · optional_prompt.
`CommunitySongVersion`: version_id · base_song_id · parent_version_id ·
author_id · display_author · lyrics[] · created_timestamp ·
vocal_stems[] · effects_profile · covers · mutations · singalong_count
· performance_count. Must support arbitrary branching.

## VOCAL RECORDING

Godot microphone capture (AudioEffectRecord workflow). Sequence: select
song → load backing + lyric data → mic/latency check → countdown → play
instrumental + record mic → performance ends → playback → DISCARD /
SAVE PRIVATELY / PUBLISH → create community version. Publishing is an
explicit choice.

## LATENCY CALIBRATION

Diegetic: **MIC CHECK — clap when the screen flashes.** Measure offset,
store a local compensation value, apply when aligning recorded vocals.
Never manually compensate per recording.

## STORAGE PRINCIPLE

Do NOT upload the instrumental with each recording — every client has
the backing track. Store: base song ID · version metadata · lyrics +
timing · parent version · dry vocal recording · vocal effects settings.
Playback = local original backing + downloaded community vocal stem.
Another player can mute the community vocal and perform those lyrics
themselves.

## THE BAR AS AN AUDIO EFFECT

Community recordings come from wildly different microphones. Store
vocals relatively dry; at runtime route playback through the fictional
karaoke rig: high-pass · karaoke mic EQ · mild compression · subtle
saturation · modest slapback · cheap digital reverb · PA speaker
coloration. The voice should sound like it is coming through this bar's
mediocre PA. The physical bar becomes part of the instrument.

## NPC CULTURAL MEMORY

NPCs gradually learn community-created songs. Each NPC has musical
preferences (ties to the resident archetypes: the sentimental
enthusiast, the punk who only sings late, the bartender who has heard
everything and hates several overplayed songs, hums familiar choruses
while working). Track community popularity; at thresholds NPCs
recognize → request → sing → join choruses → hum; the bartender reacts;
environmental references appear (a fragment written in the restroom;
the Songbook labels it a LOCAL CLASSIC). This transforms user-generated
content into culture inside the simulation — a central design goal.

## SONG CULTURAL STATES

UNKNOWN → DISCOVERED → COVERED → REGULAR → LOCAL FAVORITE → LOCAL
CLASSIC. Not raw play counts: weight unique singers · covers ·
mutations · complete performances · NPC affinity · singalongs. Prevent
one person farming their own song into a classic.

## NPC PERFORMANCE

Community songs appear naturally in simulation, not only in menus. The
player may enter while an NPC is on stage singing a song written by
another human days or months earlier — and may eventually walk in on a
song THEY wrote. No achievement popup; the recognition is the reward.

## MODERATION / PRIVACY

Publishing states: PRIVATE · FRIENDS/INVITE ONLY · COMMUNITY. Author
identity separable from performance data. Support anonymous publishing,
report, hide, block creator, delete own published version. Backend
interfaces abstract so moderation/storage can be implemented later
without rewriting gameplay.

## MVP IMPLEMENTATION ORDER

Do not build networking first.
- **PHASE 1 — ONE SONG LOCALLY**: SongResource · phrase data · timed
  karaoke display · lyric editor · backing playback · mic recording ·
  latency offset · playback of vocal + backing.
- **PHASE 2 — VERSIONING**: save version · parent/child · cover ·
  rewrite · genealogy.
- **PHASE 3 — MULTITRACK**: second vocal · harmony · ghost duet.
- **PHASE 4 — NPC**: preferences · NPC performance · recognition ·
  singalong.
- **PHASE 5 — ONLINE STORAGE**: only after the full local experience
  works — upload/download metadata, stem transfer, discovery,
  moderation, popularity.
- **PHASE 6 — CULTURAL MEMORY**: long-term propagation to
  environmental references.

## FIRST PROTOTYPE

ONE song: **LAST TRAIN HOME**. Instrumental placeholder · melody-guide
placeholder · verse/chorus/verse/chorus/bridge/final chorus · 6–12
phrase slots. The player must be able to: walk to the terminal → choose
it → write lyrics → queue → walk onto the stage → use the microphone →
see synchronized lyrics → hear backing spatially through the bar PA →
record → listen back → save → see it in the Songbook → derive a second
version → view the parent/child relationship → have an NPC later
perform the saved version. Do not expand beyond this until the vertical
slice works.
