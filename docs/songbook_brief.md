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

---

# ADDENDUM A — three modes (owner, 2026-08-07)

*Filed after the brief body, which stays verbatim. Three ideas from the
owner, assessed against the brief and against the bible. One of them
contradicts a stated rule above and the contradiction is resolved here
rather than silently.*

## A.1 THE BLIND READ

Split writing from performing. Player A writes lyrics to an
instrumental. Player B receives the track but **does not see the lyrics
until they hit RECORD** — they sing it cold, reacting to words scrolling
at them in real time. The recording keeps the stumbles, the laugh, the
save. That artifact is the shareable thing.

**Why it belongs here and not in some other game.** The brief already
lists EXQUISITE CORPSE as a creative mode, but that version blinds the
*writer*. This blinds the *performer*, and that is a different machine.
It is the only mechanic in the Orison that manufactures the present
moment. Per `ORISON_ARCHETYPE_SCHEDULES.md` §I, no resident carries the
Jester — purgatory contains nobody who can live in the moment for its
own sake, and the karaoke basement is explicitly where they go to borrow
it. A blind read cannot be planned, rehearsed, perfected or deferred.
It can only be *done*, once, live. Read the cast against that:

- **Rhea** deletes take 18 and re-records. A blind read has no take 18.
- **Jonah** cannot finish. A blind read finishes itself or fails aloud.
- **Peter**'s rule is *uncertainty does not prevent action*. This is
  that sentence as a control scheme.
- **Iris** performs for an imagined house and flees the applause. Here
  the house is real and the performance is unrehearsable.

The brief's scoring section already refuses pitch and tracks
**COMMITMENT — did the singer finish**. In every other mode that is a
footnote. In a blind read it is the whole score.

**Ships earlier than it looks.** The mechanic is local; only the
*sourcing* of unseen lyrics needs other people. A blind read of any
version the player has not read — an NPC's, a stranger's, one of their
own from months ago — is Phase 2 work the moment versioning exists.
Hold the lyrics behind the record button and the feature is done; the
network only widens the pool. It also solves NPC performance cheaply:
an NPC stumbling through a human's words needs no acting model, because
stumbling is the authored behaviour.

## A.2 SYLLABLE-RESTRICTED PUZZLES — *opt-in, not the default path*

Treat a phrase slot as an audio puzzle: a clear simple melody guide
(music box, retro synth), a UI that maps the required rhythm as
positions (`_ _ _  -  _ _`), and lyrics that must land on the exact
syllable count and stress before the line is accepted. Solve the text,
then perform it.

**The contradiction, stated plainly.** LYRIC WRITING above says the UI
"may hint a line is probably too long/short but **never prevents
experimentation**." Idea as given requires exact fit *to progress*. Both
cannot be the default. Resolution: the constraint becomes a **creative
mode** — `STRICT METER` — alongside PROMPTED, THREE WORDS and GENRE
WRONG, which is precisely the slot the brief already built for
constraints that "defeat the blank page." Default writing stays
unblocked and unjudged. A player who wants the puzzle chooses the
puzzle.

Split further, because the two halves have different rules:

- **The syllable map is a DISPLAY and ships for every mode.** Showing
  the shape of the melody as beats is information, not enforcement, and
  it is the single best answer to a blank slot. `PhraseSlot` already
  carries `suggested_syllables` and `melodic_shape`; this is drawing
  what the data already says.
- **The gate is a MODE and ships only when chosen.** Only STRICT METER
  refuses a line.

Songs written in STRICT METER should be marked as such in the Songbook,
because a later coverer inherits the meter whether they know it or not —
and a mutation that breaks it is a legitimate branch, not an error.

## A.3 PRODUCER AND PERFORMER

Two ways to play the same room. **Producers** arrange the isolated stems
in a sandbox — physically, by placing elements into a diorama of the
bar's own stage — and publish the result as a beat. **Performers**
browse community beats, write, record, and release the finished song.
Both names go on it.

**What this actually solves.** Two real problems, neither of them
cosmetic:

1. **The library problem.** The brief asks for 30–50 authored
   instrumentals and then expects thousands of variants. Producer mode
   multiplies the library without commissioning more music: the same
   stems, rearranged, are new backing. It scales the one input that
   does not scale by itself.
2. **The microphone problem.** The brief already protects the shy —
   anonymous publishing, PRIVATE state, never punish an unusual voice —
   but every one of those still ends at a microphone. Producer mode is
   the first way to be a full participant in the culture and never
   record a sound. For a game whose thesis is folk music, that is not a
   side mode; it is half the folk.

**Diegetically it is already built.** This game puts its interfaces in
the world — the mail bank, the call desk, the Songbook binder. A mixing
desk that is a diorama of the stage you can see across the room is the
same instinct, and the stage, mic stand, PA and karaoke TV all exist as
geometry today.

**Data implication, flagged now so it is cheap later.** A published beat
is a new entity between `SongResource` and `CommunitySongVersion` —
call it `SongArrangement`: arrangement_id · base_song_id · author ·
stem gains/mutes/positions · effects. Genealogy grows a second axis, so
lineage becomes `base → arrangement → version`, and a version must name
which arrangement it was sung over or playback reconstructs the wrong
backing. The brief's STORAGE PRINCIPLE survives intact and gets
stronger: still no audio uploaded for the backing, because an
arrangement is a handful of numbers over stems every client already has.

## A.4 WHERE THEY LAND IN THE MVP ORDER

The brief's rule holds — **do not build networking first**. Each of the
three has a local core and a networked pool; only the pool waits.

| Idea | Local core | Needs the network for |
|---|---|---|
| Blind Read | Phase 2, once versions exist to hide | a stranger's words |
| Syllable map (display) | **Phase 1** — it is the lyric editor | nothing |
| STRICT METER (gate) | Phase 2, with modes | nothing |
| Producer sandbox | Phase 3, when stems arrive | publishing beats (5) |

Phase 1 as written does not change. The syllable map is the only one
that touches it, and it is a better editor, not a new feature.

**One combination worth building toward.** A Producer publishes a beat.
A writer sets words to it. A third player blind-reads those words over
that arrangement, cold, and finishes the take laughing. Three people who
never met, one song, and every one of them on the credit. That is the
brief's own thesis — *a folk-music simulator disguised as a shitty
karaoke machine* — at full extension, and it is the argument for taking
all three ideas rather than any one.
