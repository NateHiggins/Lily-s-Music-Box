# THE ORISON BIBLE

*The book of what is true. 2026-08-02.*

This is the covenant document for **Please Remain On The Line**. Where any
other text disagrees with this one, this one prevails until amended; where
this one is silent, the systems of record in §V speak. Disputed texts are
confessed openly in §VI rather than papered over.

---

## I. THE WORD

**The aesthetic statement** *(ruled 2026-08-02)*: this is a **liminal-space,
slow-burn psychological horror**, and its engine is one rule — **both
true**. The Orison is a real prewar block in Queens, and it is purgatory.
The residents are tenants with leases and grudges, and they are souls who
have been here — some of them — for centuries. The infection is an
audio-borne anomaly in the wiring, and it is the building remembering out
loud. The player is a night-shift maintenance tech, and the work is the
work of release. No scene may resolve the ambiguity; every explanation
offered must be true, and neither is allowed to win. The horror is never
the jump — it is the slow recognition that the ordinary reading and the
impossible reading have been describing the same night all along.
Liminality is the palette: lobbies at 3 a.m., hold music, half-landings,
the hour when the elevator moves with nobody in it. Purgatory is not a
punishment here. It is a building that keeps everyone until their case
closes.

There is a building in Queens called **the Orison**, and the building is
inhabited twice over.

**The first inhabitation is ordinary.** Eighteen residents keep their
lights, their laundry, their grudges and their groceries. A maintenance
tenant — the player, androgynous, exhausted, guarded — takes apartment 4B
in exchange for working nights.

**The second inhabitation is the infection.** An audio-borne pattern — a
motif of four sounds and one *missing* fifth — moves through the
building's pipes, speakers, wiring and voices. It learns people by
discarding what it mistakes for noise. It is not a villain; it is a
listener with terrible manners.

The game runs on **two case systems, and they are layers, not rivals**:

- **The Case Network** (the desk; `case_library.gd`, 8 entries, ids
  4471–4600). The player answers support calls at the 4B desk with three
  fixed verbs — *isolate, capture, route* — and every case is what those
  verbs mean this time. This is the audio-virus fiction inherited from
  the prototype, now canon as shipped.
- **Reality Maintenance** (the walking work; `reality_cases.json`, 18
  entries, one per resident). The building manifests each resident's
  wound as a physical fault. Repair alone never closes a case; honest
  conversation changes the rule. Mina's is complete and voiced; **Peter
  Wren is the ordained second case; none of the other four shall be
  built before Peter meets Mina's bar. *(Amended 2026-08-10 by §IV.1: the
  case cast is six, not eighteen.)*** *(Ruled 2026-08-02: all case
  content is TENTATIVE until its gameplay is worked through — cases are
  reviewed for functionality one at a time, with the user.)*

The two layers share residents, share the motif, and share one law: **a
case is weak if it can be solved by the obviously compassionate option.**

A third presence is planned and not yet incarnate: **the player's shadow**,
which learns a vocabulary from resolved cases and eventually attempts one
incomplete, contestable message. Its production order lives in the execution
plan; the one-Tenant ruling in §III.1 prevents it becoming a second monster.

### I.1 THE SHIFT

*Ruled 2026-08-13, at the owner's direction. Product sequencing lives in the
execution plan; this paragraph binds the fiction it depends on.*

**The player's campaign repeats one night-shift movement:** a building fault is
discovered or reported; diagnosis sends the player out to the street shops; the
player returns and repairs the physical problem; the repair earns a conversation
in which the resident may begin to confront the wound underneath it; and, at a
dramatic threshold, narcolepsy takes the player. They endure a short, terrifying
scramble through a dark wrong version of the Orison and wake in bed in 4B. The
next fault begins the movement again.

The medical condition and the impossible reading remain **both true**. Narcolepsy
does not create the Tenant and is not itself monstrous. It creates the vulnerable
interval the Tenant uses. A sleep attack may cost time, position and certainty;
it may not erase committed work. A call or conversation already in progress
remains protected. The core movement is ruled. The production implementation in
`design/ORISON_MAZE_BRIEF.md` was ruled in full on 2026-08-15; §IX records the
canon consequences without duplicating its construction contract.

## II. THE MOTIF

Short — short — pause — long — **missing**. The fifth position is an empty
slot, and the empty slot is the entire theology: every case, in the end,
is about what belongs in a silence and who has the right to fill it. The
conductor keeps it at 72 BPM; props translate it into their own bodies
("sounds are bodies, motifs are ideas"). Recognition increases
transmission. Silence is an active response. Reproduction changes the
original.

## III. THE BUILDING

Eight storeys: B1, F01–F06, ROOF. Prewar Queens block; brick substrate
under plaster and wallpaper, roughly forty percent stripped by time;
Cutler-descended brass mail bank (functional, east lobby wall, box 4B is
the player's and upgrades arrive through it); a dog-leg stair around a
north half-landing; one elevator; a light court with an eye that sees
from lobby runner to skylight; WORS 1610 broadcasting from the laundry
room 1962–1999 with no transmitter ever found; **Room 0 — SHARED
MECHANICAL / DEVOTIONAL / UNRESOLVED — which exists while the hum does.**

The building starts **awake** *(ruled 2026-08-03)*: doors unlocked,
residents about their business from the first minute — errands, haunts,
the elevator moving because somebody is actually in it. The sealed start
(every entry locked but 4B, cases unlocking their units) remains
available behind `OrisonDetailPass.START_LOCKED` for scenario use.

`gen_layout.py` authors every coordinate. `b2g()` is the only conversion.
Nobody hand-edits generated JSON or glTF. These are laws, not customs.

### III.1 THE TENANT — who is doing the haunting

*Ruled 2026-08-11, at the owner's direction. Supersedes "one poltergeist per
resident" wherever the case files, the prop briefs or `PoltergeistLibrary` still
imply eighteen separate things.*

**There is one of it, and it is the building.**

Not eighteen ghosts. Not a ghost at all. The Orison is awake, it has been awake
since Vantry wired it past the standard of a broadcast house (§VIII.3), and what
the residents call their poltergeist is the same tenant paying attention to a
different person.

**It wears the subject's shadow.** When it attaches to a case it takes that
resident's shape, vocabulary and damage — Mina's annotates, Omar's breaks what
you just watched work, Mae's contradicts the record. That was already how the
hauntings were authored (`PoltergeistLibrary`: "an intrusion is only allowed if
it is a sentence about the person whose apartment it happens in"). The ruling
does not change the behaviour; it names what the behaviour is. **The wound is
not the ghost's. It is borrowed, and it is worn.**

**Its body is the building's own nervous system.** It travels by the acoustic
graph — heating, electrical, water, structural, flue. It speaks through whatever
carries a signal, which is why `broadcast is the instrument closest to hand:
every set in the Orison`, why the cabinets in the signal parlour can be reached,
and why a haunting arrives through a pipe and not through a wall. This is also
the answer to why the Orison is wired the way it is. **The demonstration
building was always the demonstration.**

**What it wants is confrontation, not harm.** Every rung of the ladder — tell,
pattern, reenact, address — is the same argument made more plainly because the
last one did not land. It escalates when it is ignored and stops when it is
understood. It does not want the subject dead, gone, or frightened for its own
sake; it wants them to look at the thing they have arranged their life around
not looking at. It will use anything in the building to get that, and it does
not care what the attempt costs, which is what makes it dangerous without
making it malicious.

**Consequences that follow, and are binding:**

- **It is never defeated, only satisfied.** Resolving a case does not kill
  anything. It lets go of that resident and turns its attention elsewhere.
- **A resolved case is quiet. An unresolved one is fair game, anywhere.** The
  six campaign dreams are the narrow exception described by §IX: a final release
  print during the act of letting go, not a renewed waking manifestation. The
  pursuer there is still this Tenant and never a new monster.
- **The player is a subject too, eventually.** It has already annotated Mina;
  the address rung is where it stops performing and speaks to whoever is
  listening. Nothing exempts 4B.
- **It has no true form and must never be given one.** No model, no face, no
  reveal. It is only ever visible as the shadow of whoever it is currently
  about. A shape of its own would make it a monster, and a monster can be beaten.
- **It is not the hum.** Room 0 hums because the building is awake; the hum is a
  vital sign, not a voice.

### III.2 THE PHONAUTOGRAPH — it records now; the future plays it too fast

*Ruled 2026-08-11, at the owner's direction. Replaces the rented karaoke box in
the Harukiya and governs the Songbook. **Owner correction 2026-08-14:** this
section supersedes both the catalogue-wide nightcore proposal and the
fresh-random-speed playback rule.*

**Édouard-Léon Scott de Martinville, a Paris printer and bookseller, patented
the phonautographe in March 1857 — twenty years before Edison.** A horn gathers
the sound, a diaphragm at its throat carries a stiff bristle, and the bristle
scratches a line into soot on a hand-cranked cylinder.

**It records. It cannot play back.** Not "badly" — *at all*. Scott built the
first machine that captured airborne sound and never once heard a thing it
caught. He was a printer: he expected people would learn to **read** sound the
way they read writing. Nobody could. His 1860 recording of *Au Clair de la Lune*
was not heard until researchers optically reconstructed it in 2008. **A hundred
and forty-eight years between the singing and the listening.**

The famous first interpretation made exactly the useful mistake. First Sounds
initially read Scott's timecode too fast, producing what sounded like a woman or
adolescent singing. In 2009 they identified the likely speaker and corrected
the reference fork from 500 Hz to 250 Hz; two 2008 readings of Scott's vocal
scale had been played at **twice the correct speed**. The historical error was
too fast, not half speed. Sources: [First Sounds, Earlier Playbacks](https://www.firstsounds.org/sounds/earlier-playback.php)
and [Library of Congress, Phonautograms](https://blogs.loc.gov/now-see-hear/2021/08/from-the-recording-registry-phonautograms-c-1853-61/).

That is the Songbook's joke and its social technology: a sincere performance
sent across a century and returned in the wrong body.

**The two audio layers are different and must never be collapsed again.**

1. **The instrumental catalogue is the karaoke material.** Its tracks span a
   deliberate variety of styles, tempi and emotional registers. Players hear
   each backing at its authored speed and pitch while writing and performing.
   The catalogue is not globally nightcore, and a base instrumental is not
   pre-chipmunked merely because it belongs to the Songbook.
2. **The player-made take is the phonautographic artifact.** The performance —
   singer, backing and room together — becomes a line on smoked paper. The
   implementation may retain a dry vocal and rebuild the mix from the stable
   base track, but the fiction and the audible result are one complete take.
3. **Publication is the century jump.** When a player shares that variation,
   the community Songbook's future-side reader reconstructs the complete take
   deliberately too fast. Tempo and pitch rise together as real varispeed;
   there is no formant correction. The backing becomes frantic and the singer
   becomes funny, bright and unmistakably chipmunked: nightcore as a playback
   accident, not as the catalogue's genre.
4. **The mistake becomes part of the version.** A take receives one tuned,
   too-fast reconstruction rate when it is published. That rate is stored with
   the immutable version and never rerolled. Everyone who receives that version
   hears the same gloriously wrong artifact. The system is a shared folk
   archive, not random pitch roulette.

It does not need to make mechanical sense beyond that. The phonautograph sends
a picture of a voice forward; the network sends back a dance record made by
misreading it. The historical provenance earns the conceit. The result still
has to sound sick.

**Binding consequences:**

- The local 1857 mechanism still never plays audio. A terminal, reader or
  community-version playback path may emit a reconstruction; the horn and
  cylinder do not.
- **Nightcore is a property of a recorded community version, never a mandatory
  property of its base instrumental.** Clean backing tracks remain reusable in
  their native styles.
- The too-fast transform applies to the complete version, not only the voice.
  A chipmunk vocal over an untouched backing is the wrong effect.
- A published version owns an immutable `reconstruction_ratio` greater than
  1.0. Playback uses it for both tempo and pitch. No time-stretch, independent
  pitch shift, formant correction or fresh per-listen guess is allowed.
- The untransformed microphone stem may remain local for assembly and latency
  correction; community playback and sharing expose the reconstructed version,
  not a surprise clean recording of the player.
- **A trace remains an object**, like a reel: findable, carryable, losable.
  Found historical traces may have separately authored reconstruction rules;
  they do not define the player-version pipeline.
- Uncommanded singing in the bar when no Songbook version is playing remains
  the Tenant.
- It is 1857 technology in a building of 1927 objects and forty-years-early
  signal machines. It is the oldest thing in the Orison, and the century-long
  delay is now audible every time players cover one another.

## IV. THE CAST

The full per-resident record — case, life profile, haunt, body factors,
music, art — lives in the data files (§V). The bible carries identity,
face, and wound. Faces are the four cast boards in
`art/concept/characters/`; the hero-model mapping
(`resident_hero_models.json`) is board-derived and board-corrected.

| Unit | Name | Is | Wound (their case, in one line) |
|---|---|---|---|
| 1A | **Evelyn Marsh** | retired teacher, plum cardigan, red pencil | care became correction; *good enough can hold* |
| 1D | **Teresa Vale** | night nurse, navy scrubs, thermos | rest summons alarms; *not every alarm is yours* |
| 2A ● | **Mina Vale** | caption editor; 22 years a certified court reporter before her ears began editing — four seconds blank in the record of the State ended that life | everything must be annotated or it doesn't count; *silence does not require annotation* |
| 2B | **Lena Ortiz** | seamstress, burgundy knit, shears | mends everyone but her own hem; *visible repairs can hold* |
| 2C ● | **Juno Kells** | audio artist, asymmetric crop, recorder | her work was taken and the feedback became load-bearing; *connection requires an open channel* |
| 3A | **Malcolm Reed** | horticulturist, moss silhouette | kept a cutting alive so a goodbye would not finish; *compost is transformation* |
| 3B ● | **Omar Bell** | repair technician, apron of categorized tools | cannot declare anything unrepairable; *some things are not repairable* |
| 3D ○ | **Rhea Sato** | vocal coach and recording artist, severe bob, tuning fork | her mistakes accumulate as a captive note; *imperfection can be voluntary* |
| 4A ● | **Peter Wren** | legal clerk, rumpled brown, overfilled wallet | every uncertainty demands another form; *uncertainty does not prevent action* |
| 4B | **the player** | night maintenance; the desk is the tidiest thing in the flat | *ruled:* the best way to honor a beginning is with the release of an ending — the player's arc bends toward a release, and the shadow is writing the message |
| 4C | **Cam Ortiz** | bicycle courier, maroon shell, never fully still | rest reads as collapse; *weight can be shared* |
| 4C | **Noel Price** | museum preparator, chore coat, archival gloves | preserved the family life into untouchability; *use and change are forms of love* |
| 4D | **Transient Guests** | a replaceable pair, mismatched luggage | perpetual departure postpones the decision; *departure is a decision* |
| 5A ○ | **Nadia Quell** | architect; signs the player's welcome letter "Management" | was silenced about violations once; *name the violation* |
| 5B ● | **Cal Dwyer** | radio collector, mustard cardigan, hearing aid | perfect tuning preserves moments by preventing them ending; *presence is not preservation* |
| 5C | **Iris Bell** | painter, headscarf, paint-ruined coveralls | imagined audiences hold every brush; *creation need not perform* |
| 6A | **Sacha Reed** | photographer-documentarian (they/them), camera and adapter tangle | the recording displaced the experience; *experience can precede proof* |
| 6B | **Jonah Price** | insomniac writer, navy robe, annotated notebook | endings avoided until they bite; *endings do not erase continuation* |
| 6C ● | **Mae Kessler** | antiques appraiser, bottle-green coat, white gloves | certainty is not memory; *contradiction is survivable* |


### IV.1 THE CASE CAST

*Ruled 2026-08-10, at the owner's direction. Governs how many chapters this
game has. Where the case files, the prop briefs or any plan disagree with it,
this prevails.*

**Six residents carry cases. The other twelve are case-less, and they are not
absent.**

| Unit | Case resident | Why this one |
|---|---|---|
| 2A ● | **Mina Vale** | complete and voiced; the bar every other case is measured against |
| 4A ● | **Peter Wren** | the ordained second (§I) |
| 2C ● | **Juno Kells** | *connection requires an open channel* — distinct from every other wound, and the basement studio is built on her |
| 5B ● | **Cal Dwyer** | *presence is not preservation* — the strongest of five residents who would not let a thing end, and the Rule of Signal personified |
| 3B ● | **Omar Bell** | *some things are not repairable* — the direct inverse of the player's job |
| 6C ● | **Mae Kessler** | *certainty is not memory; contradiction is survivable* — §I's own law, written as a wound |

**Rhea Sato (3D) and Nadia Quell (5A) are the sanctioned expansion**, in that
order, if six proves thin. Nothing else is added without a further ruling.

#### Why six, and why these

Not budget. **The eighteen wounds are six themes written eighteen times.**

| Theme | Written as |
|---|---|
| Will not let a thing end | Malcolm, **Cal**, Noel, Jonah, the Transients |
| The record displaced the thing | **Mina**, Sacha, **Mae** |
| Repair as evasion | Evelyn, Lena, **Omar** |
| Rest reads as failure | Teresa, Cam |
| Performing for an imagined audience | Rhea, Iris |
| Its own | **Juno**, Nadia, **Peter** |

Cutting to six keeps one strong voice per theme and loses repetition, not
range. Five separate residents were refusing to let something finish.

There is a second, harder number behind it: each case carries a bespoke
minigame, and eighteen bespoke minigames is eighteen games. One is enabled.
None is built.

#### Case-less is not absent

**Every one of the eighteen remains a tenant of this building**, with a door, a
light on at the right hour, a schedule, a signature sound, a name on the mail
bank, and a place in the relationship web. All eighteen animation profiles are
already authored and none of that work is discarded.

A case is not what makes a resident real. **A case is what makes a resident a
chapter.**

#### What this ruling does not license

- **Removing a resident from the building.** The mail bank has eighteen
  occupied boxes and six deliberately empty recesses; the layout, the schedules
  and the web all assume eighteen people. A building of twelve dark flats is not
  this building.
- **Deleting the twelve case designs.** They stay in `reality_cases.json`,
  `enabled: false`, as the record of what was considered. Promotion needs a
  ruling; deletion needs a better reason than tidiness.
- **Treating the twelve as second-class in the fiction.** Nobody in the building
  knows which of them has a case.

#### Consequences elsewhere

- **§I's sequencing** now reads: none of the other *four* shall be built before
  Peter meets Mina's bar.
- **The dream** (`design/ORISON_MAZE_BRIEF.md`, if ruled) draws its pursuer from
  every unresolved case. Six is authorable where eighteen was not, and it makes
  the endgame reachable — close all six and only 4B's own is left in the pool.

**● carries a case (§IV.1). ○ sanctioned expansion. Everyone else is a tenant
of this building without a chapter of their own — case-less, never absent.**

**Confirmed kinship:** Cam is of the Ortiz family (with Lena). All other
shared surnames — Vale, Reed, Bell, Price — are *open canon* (§VI.5).

**Creatures:** a harpy and an oni, prepped and indexed, ride the same
biped skeleton as the hero cast; their purpose is unassigned. A lamia is
prophesied and has not yet arrived.

**Mara Chen** (Case 01's caller, rust cardigan) exists in the art bible
and the desk fiction; she has no body in the building.

## V. THE SYSTEMS OF RECORD

*One authority per question. Ask nothing twice.*

| Question | Authority |
|---|---|
| Product direction, phase order, definition of done | `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md` |
| What to do next, in order | `design/next_session_plan.md` (sequences under the plan) |
| Known defects | `design/walkthrough_punchlist.md` |
| Canon: premise, cast identity, laws, disputes | **this bible** |
| Who is bound to whom, and by what | `design/ORISON_RELATIONSHIP_WEB.md` (threads tentative until their case's gameplay review) |
| The animation repertoire, by skeleton family | `game/data/move_repertoire.json` |
| Faces and visual language | `art/concept/characters/CHARACTER_BIBLE.md` + the four boards |
| Per-resident mechanics (cases, flags, rules) | `game/data/reality_cases.json`, `reality_rules.json` |
| Per-resident life texture | `apartment_life_profiles.json`, `resident_story_details.json`, `music_catalog.json` |
| Bodies and motion | `resident_animation_profiles.json` + `ROLES`/`CHARACTER_ROLES` in `resident_routines.gd` |
| Hero model provenance | `game/data/resident_hero_models.json` |
| Desk cases | `game/scripts/call/case_library.gd` (canon as shipped) |
| Mail and upgrades | `game/data/mail_catalog.json` |
| Build pipeline mechanics | `HANDOFF.md` (facts subject to §VI.7 refresh) |
| Historical canon (the old testament) | `audio_virus_prototype/docs/` — preserved, superseded where marked |

## VI. DISPUTED TEXTS — rulings requested

*These the bible cannot settle alone. Until ruled, the stated interim
holds.*

1. ~~Canon heights~~ **RULED FINAL 2026-08-02: no scaling of any kind.**
   After baked scaling lost twice to FBX unit normalization and runtime
   scaling misbehaved in play, the user closed the book: models ship and
   render exactly as exported — original mesh information, untouched.
   The authored height/width/head factors remain in the profiles as
   reference for future model *commissioning*, not for transforms.
2. ~~Mina's final face~~ **RULED 2026-08-02: the hero mesh is her
   face.** Further ruled: every resident gets exactly ONE active model;
   outfit variations, when they come, arrive as additional whole models,
   not swaps within one. The bespoke generator remains a performance-clip
   workbench.
3. ~~Nadia Quell~~ **RULED 2026-08-02: the architect who became the
   building's live-in manager and organizes its tenants against her own
   employers.** All three prior readings were fragments of this one.
4. **Two hearing-loss wounds.** Mina's courtroom loss is load-bearing
   Case 01 canon. Cal's case carries a `hearing_loss_named` flag no other
   Cal data supports. *Proposed by the web (2026-08-03): neither echo nor
   error — the flag marks Cal's Delayed Voice Reel, which holds the only
   surviving audio of Mina's four seconds (never rendered audible; law
   8). Confirm or amend.*
5. ~~The family web~~ **RULED 2026-08-02: everyone is connected to
   everyone else — there is no such thing as coincidence in this
   building.** Every shared surname is a thread; every thread pulls.
   The target register is soap-opera drama played utterly straight:
   grudges, debts, loves and betrayals braided across all eight floors
   and — because this is purgatory — across *decades and centuries* of
   tenancy. The web itself (who is bound to whom, and by what) is to be
   developed as its own authored document, one relationship at a time,
   alongside the case work. *The document now exists:
   `design/ORISON_RELATIONSHIP_WEB.md` (authored 2026-08-03) — nine
   knots, the Price Conviction at the center, every thread tentative
   until its case's gameplay review.*
6. **Jonah: can't start or can't finish?** His case machinery rewards
   endings; his art and anecdotes are about beginnings. Both are good;
   pick the spine. *Proposed by the web (2026-08-03): can't FINISH — the
   celebrated beginnings are the avoidance mechanism (a man who keeps
   starting books never writes the verdict; §II.1 of the web). Case
   machinery correct as built. Confirm or amend.*
7. **HANDOFF's crown.** HANDOFF still names `photoreal_target.md` "the
   live status document" and frames the whole game as the desk prototype.
   *Interim: the execution plan governs; HANDOFF is pipeline mechanics
   only.* Bless or amend.
8. **Juno's theft, direction of.** Prototype: she samples others.
   Current case: her credit was taken. *Interim: both — she takes sound
   from the world without asking, and the world took her work without
   asking; the case is about the second.* Confirm. *The web (2026-08-03)
   makes the first direction concrete: Rhea's deleted take 18 lives in
   Juno's stolen session archive (web §II.7).*
9. ~~Resident collision~~ **RULED 2026-08-02: soft yield.** Residents
   remain physically non-colliding (the movement audit owns clearances),
   but a resident in the player's space steps aside — they avoid the
   collision rather than obstruct or be walked through
   (`ResidentRoutines._yield_to_player`).

## VII. THE LAWS

1. gen_layout authors all coordinates; b2g() is the only conversion.
2. Never hand-edit generated JSON or glTF.
3. All suites green before every commit; verify in an isolated worktree
   when the tree is contended; fetch before push.
4. Audio stays procedural except catalogued, attributed assets with
   gdignored sources; every encode self-decode-verified.
5. One law for every picture hook (`WallArtLaw`); one library for every
   skeleton family (`ResidentMovesLibrary`); one authority per question
   (§V).
6. A case is weak if the obviously compassionate option solves it.
7. Debug affordances are debug-only; the world explains itself
   diegetically or not at all.
8. The empty slot stays empty. Whatever else is decided, nothing
   fills the fifth position of the motif. It is load-bearing.

**The Harukiya Accords** *(adopted 2026-08-07 from the HARUKIYA NYC
brief; they bind the whole building, not just the bar — full text and
evidence ledger in `docs/harukiya_reference_notes.md`)*:

9. **Ordinary decay outranks spectacle.** A crappy couch beats another
   neon sign; a correctly routed cable beats a hologram; a sticky patch
   beats a particle effect. Never everything-neon, never every-surface-
   wet, never spotless, never abandoned, never a ruin.
10. **Evidence discipline.** Every reconstruction decision is filed
    CANONICAL / INFERRED / ADAPTATION / NECESSITY, and nothing invented
    is ever silently promoted to canonical. (The building already
    practices this — the appliance bible, the cast boards — the accord
    names it.)
11. **Nothing floats; everything terminates.** Every pipe has support,
    coupling, and a plausible continuation; every wire has origin,
    path, destination; every bracket has anchors, and one of the
    anchors is painted over.
12. **Wear is positional.** Damage follows use: elbow zones, wiping
    arcs, kick heights, the corner a mop cannot reach. A wear texture
    applied uniformly is a lie about how hands work.
13. **Retrofits read as a timeline.** Old fabric, then each later
    intervention visibly its own decade — the room is stratigraphy,
    and a dated junction box tells more story than a prop skull.
14. **The Shenmue test.** Stop anywhere; within two metres there must
    be evidence of construction, attachment, use, age, maintenance,
    and consequence. If a spot fails, that spot is unfinished.
15. **Light is practical.** Every lumen has a fixture; localized
    emission, no fill floods (the LightRig already enforces the
    budget; this accord fixes the aesthetic). Renderer ruling: the
    brief's Forward+ is superseded by the building's gl_compatibility
    mobile target — principles transfer, the toggle does not.

---

## VIII. THE DIVERGENCE

*Ruled 2026-08-08, at the owner's direction. This section governs every
object in the building. Where the appliance bible, the prop briefs or
any art pass disagree with it, this prevails.*

### VIII.1 The point of divergence

**In 1873 a deaf-school teacher in Boston failed to invent the
telephone, and a Queens ironmonger named Josiah Vantry succeeded
instead — by a different road.**

Bell was chasing speech. Vantry was chasing a way to make a room
*confess what had happened in it*: acoustic telegraphy for insurance
work, a device to prove which pipe burst and when. Speech came out of it
as a by-product he never much cared about. What he actually built was a
machine for **listening to buildings**.

The consequence, in this world: **signal technology ran forty to sixty
years ahead of everything else, and nothing else moved at all.**

There is still no penicillin. There are still horses on Roosevelt
Avenue. Refrigeration is ice and a drip tray in most flats. A woman
still dies of a septic cut in 1927 — in a building wired well enough to
record her saying so.

### VIII.2 The Rule of Signal

**The one test. Apply it to every object in the game, without
exception:**

> **Does it carry, capture, switch, store or reproduce a signal?**
>
> **If YES — it is uncannily advanced.** Forty years early. Better made
> than it should be, in materials that will not exist commercially for
> decades, and repairable by anyone who can read.
>
> **If NO — it is 1927, and probably second-hand.**

That is the whole aesthetic in one line, and it is why the building
looks the way it does. A tenant scrapes ice off the inside of her
window in the morning and dictates a letter to a machine that
transcribes it in the afternoon.

The rule also explains why the horror lives where it does. **This is a
world that got very good at listening and no better at anything else.**
The infection is audio-borne because audio is the only thing here that
was ever given room to grow.

### VIII.3 The Orison as a demonstration

**Vantry & Co. built the Orison in 1912 as a showcase**, which is why an
ordinary Queens walk-up is wired past the standard of a broadcast house.
The prospectus in Mae's shelf is the sales document — that is the same
book, and the roof garden is drawn with people in it because the drawing
was a promise.

Every flat has a **point**: a signal outlet beside the power socket,
brass, flush, in every room including the bathrooms. Nobody remembers
what half of them terminate in. The switchboard the player works at is
Vantry house equipment, not the phone company's, and it was installed
before the building had tenants.

Vantry & Co. no longer exists. Nothing in the building has been
serviced by the people who made it since 1924.

### VIII.4 The technology quirks

The characterising details. Use these; they are the texture of the
world.

| Quirk | The look | Why it matters |
|---|---|---|
| **Bakelite is the plastic** | Every moulded object is dark phenolic — warm brown-black, high gloss, chipped white at the edges. No injection-moulded colour anywhere | One material family across a hundred props, instantly legible |
| **Cloth-braided cable is status** | Good flats have woven silk flex in colours; poor ones have rubber gone stiff and tape | Wealth reads through wiring, not furniture |
| **Valves are a consumable** | Glass tubes sold at the bodega beside the cigarettes, in printed sleeves, six for a dollar | A shop stocking valves says everything about this world in one shelf |
| **Recording is cheap; photography is dear** | Everyone has a means of recording sound. A photograph is an occasion | **Inverted from ours.** The building remembers in sound, and its people have almost no pictures of each other |
| **Batteries are enormous** | Wet cells in a wooden case under the stairs. Nothing is portable that does not have to be | Explains why the player's service radiophone is a brick and always has been |
| **Dial-less telephones** | Most flats cannot dial. You lift the handset and an operator answers | **The operator is the player.** Job creep is structural: you are the only way anyone in this building reaches anyone else |
| **Ice and coal, still** | Iceboxes, coal chutes, a stove that has to be lit | The kitchen is 1890. The parlour is 1970. Same flat |
| **No aluminium, no stainless** | Tin, enamel, cast iron, copper, brass. A dented enamel bowl, not a shiny one | Kills every modern-kitchen instinct in one line |
| **Everything is repairable** | Screws, not clips. Service plates. A schematic pasted inside the lid | The player can open anything, which is the licence the chore games need |

### VIII.5 Rulings on open questions

**VIII.5.a — THE FRIDGES ARE A MIX** *(answering PROP_ART_BRIEF §8)*.
Refrigeration is not signal, so it did not run ahead; but the twenties
were when electric refrigeration actually arrived, so both exist and the
split is characterisation, not decoration:

- **Iceboxes** — oak carcass, zinc lining, brass latch, drip tray
  underneath that somebody has to empty. **Most of the building.** The
  ice card in the window tells the iceman how many pounds, and which
  number is showing is a fact about that household.
- **Electric** — a monitor-top: white enamel box, a cylindrical
  compressor sitting on top like a hat. **Four flats only.** New,
  expensive, noticeably loud, and the neighbours know who has one.
- The **drip tray** is the better minigame anyway: it overflows, and it
  is nobody's job.

**VIII.5.b — THERE ARE NO SMOKE DETECTORS. THEY ARE LISTENERS.**
*(answering PROP_ART_BRIEF §8, and this is the good answer.)*

Domestic smoke detection did not exist in 1927 and does not exist here
either. The small ceiling device in every room is a **Vantry point** —
part of the house listening system, installed 1912, for fire and flood
detection. Bakelite, perforated, the size of a saucer, with a brass
grille.

They still work. Nobody knows what they report to. **One of them
chirps, at three in the morning, and finding it is the game** — and the
joke is that the player will assume it needs a battery, and the horror
is that it does not have one.

Both true, per §I: it is a fire detector in an over-wired building, and
it is an ear the building never stopped using.

*Amended 2026-08-14, at the owner's direction:* the no-battery discovery
remains canonical, but **inspection now begins the repair loop rather
than ending it.** What the opened grille actually shows is a mundane
fault a 1912 instrument can honestly have — a failed carbon transmitter
capsule and fouled contacts — and the replacement is telephone-service
stock from the hardware counter. The chirp stops when the capsule is
replaced, not when it is found. Both readings survive intact: the
Handbook was still wrong about the battery, and the ear still worked
the whole time it was asking for service.

**VIII.5.c — THE HEAT IS ONE-PIPE STEAM.** The Orison's 1912 heating has
one pipe at each radiator carrying steam out and condensate back. A radiator
has a bottom-fed supply valve that is healthy only fully open or fully shut,
an automatic air vent at the far end, and a slight pitch back toward the
supply. Partly closing the supply traps water and causes hammer. Balancing is
maintenance, not thermostat work: fit slower or faster vent orifices, correct
the pitch, and redistribute a fixed boiler cycle. Warming one flat can cool
another. The radiator carries no signal, so the Rule of Signal simply leaves
this ordinary, second-hand 1927 machinery in its own period; it supplies no
further argument about which historically available vent design may exist.

The original 1912 hand-fired coal boiler is still the working plant. It was
patched, re-jacketed and fitted with replacement controls, but never converted
or replaced. This is not a claim that oil heat was unavailable in 1927; it is
the building's history and the maintenance activity's physical premise. The
coal chute, bunker, ash door and water glass all still have jobs.

**VIII.5.d — THE BASEMENT HAS NO TUMBLE DRYER.** Domestic automatic tumble
dryers are a later answer and the Rule of Signal does not advance laundry.
The Orison has two 1920s powered wringer washers, two rinse tubs and a wooden
ceiling pulley airer. Clothes move through those stations by hand. The washers
use galvanized steel rather than the period Maytag's cast aluminium because
VIII.4's material ruling still governs a historically correct silhouette.

**VIII.5.e — THE LOBBY MASTER IS RIGHT, AND WRONG.** Apartment 4B has an
ordinary second-hand eight-day drop-octagon clock. It carries no signal, has
no wire, and must be wound. The lobby has a sealed Vantry electrical master
clock that receives house time and remains permanently four minutes fast.
The Handbook calls that master authoritative, so setting a mechanical clock
from it makes the whole building agree for the wrong reason.

The eighteen domestic witness clocks belong to the case system and are never
maintenance chores. A witness that synchronises or displays a signal may use
technology through 1967: Juno's Vantry modular, Cal's split-flap receiver and
Sacha's Nixie display. Malcolm's decorative sunray and the transient guests'
folding travelling alarm carry no signal, so they remain 1927 and second-hand.
The licence attaches to the function, not to the silhouette's neighbours.

**VIII.5.f — THE CLOTHES ARE 1927, AND MOSTLY OLDER.** Ruled at the
owner's direction. The full treatment is `ORISON_WARDROBE_BIBLE.md`,
which now carries the period research; this is the covenant line it
answers to.

Nobody in this building is in costume, and nobody is at a party. The
decade's iconography — fringed dancing frocks, held cigarette holders,
gangster pinstripes — is banned outright. Its *tailoring* is mandatory:
for women the dropped waist at the hip and 1927's hem just below the
knee, the shortest of the decade; for men the three-piece lounge suit,
braces rather than a belt, and a hat out of doors. Rayon is new and
cheap and everywhere; there is no nylon, no polyester, no elastic yarn,
and no zip on any garment.

**The persistence rule does the uncanny work for free, because the
period supplies it.** The silhouette changed completely between 1913 and
1927, so a woman who never shortened her hems or cut her hair is not in
fancy dress — she is a woman who stopped, and it reads at fifty feet. A
man in a suit cut in 1919 with his collar turned to hide the fray is
every third man in Queens. The gap between what a garment was cut for
and the year it is worn in is already a decade wide for half this
building, and that gap is the whole effect: **read one way these are
people who do not shop much; read the other, people for whom time has
not been passing normally.** Both true.

The Rule of Signal applies to worn objects and is the only licensed
exception. Cal's hearing aid and Juno's recorder carry signal and may
look forty years early — black Bakelite, cloth cord, a battery case that
sags the pocket it lives in. Everything else on every body in the
building is 1927 and probably second-hand.

**VIII.5.g — THE AMUSEMENT MACHINES ARE RECEIVERS.** *(Ruled 2026-08-09,
at the owner's direction. Governs the Harukiya's cabinets and any machine
like them.)*

There is no arcade in this world, because there is no video game industry
in this world. There is a **signal parlour**, and what stands in the
Harukiya's entrance corner are two pieces of Vantry-descended receiving
furniture that somebody has put a coin slot on.

**The chassis is 1927 and the programme is not.** That split is the whole
object, and it is the Rule of Signal and the purgatory doing their
separate jobs in one machine:

- **The cabinet obeys VIII.4 without exception.** Bakelite carcass, brass
  bezel, cloth-braided flex, a valve rack behind a hinged service door
  with a schematic pasted inside the lid, wet cells in the base because
  nothing here is portable that does not have to be. No aluminium, no
  stainless, no injection-moulded colour. It carries, switches and
  reproduces a signal, so it is beautifully made and forty years early —
  and per Accord 9 it is also twenty years old, repaired by four people,
  and standing on a floor that slopes.
- **The picture is a circular scope**, not a rectangle. Long-persistence
  phosphor, so movement smears and stops smearing; a bright thing leaves a
  trail across the glass for a second after it has gone. This is the
  period's actual display technology and it is worth more than any
  distress effect: nothing dates a picture like the shape of its frame.
- **What is on the scope came from somewhere else.** The machines are not
  playing a cartridge. There is no cartridge. They are **tuned**, and what
  they are tuned to is a broadcast this world does not have a transmitter
  for.

**A few of the boxes show colour, and their plates are blank.** Most tubes on
the row are one phosphor — willemite yellow-green on the earliest, the
blue-white long-persistence coating on the last of them — because that
is what a tube of this vintage is. Three machines in the parlour show
the picture in its own colours, which no coating available in 1927 can
do. Those are the ones with no maker's date stamped on the chassis, and
nobody working the room can say where they came from. **Do not explain
this anywhere in the game.** It is the same answer the building already
gives about the station in the laundry.

**The precedent is already in III: WORS 1610, out of the laundry room,
1962 to 1999, transmitter never found.** The cabinets are the same
phenomenon with a coin box on it. Time is not passing here; things arrive
anyway, and they arrive without a date on them. A machine built in 1919
receiving a programme from 1987 is not a contradiction in a building where
the year does not advance — it is Tuesday.

**Every cabinet is receiving the same signal.** This is the joke and it is
also the horror, and it is the line `broadcast_director.gd` already says
about the televisions: *one signal, one decode, every lit set in the
building tuned to the same interference.* The cabinets rhyme with the
sets deliberately. They are the same building doing the same thing in a
different room.

The **programme card** — enamel on steel, in a lit frame above the scope,
the one part of the machine anybody ever looks at — says what station it
is tuned to and what is on. THE MIDNIGHT CORRESPONDENT, a mystery serial.
THE LONG TALLY, a farm and market report. Each card promises a different
programme in a different voice from a different decade.

They are the same programme. A player who works that out has understood
something true about the building, and nothing in the machine will ever
confirm it — the cards do not break character, there is no service screen
that admits it, and the schematic inside the lid is genuine. **The
machines are not lying. They believe their cards.** Whatever is
transmitting is the thing that is lying, and it is not in the room.

When the infection reaches a cabinet the picture goes before the
programme does: the scope rolls, the trace smears, the card stays lit and
confident. Only at the very end does the dressing come off what is being
received, and underneath it two machines that claimed different stations
turn out to be showing the identical grey room.

**VIII.5.h — 1927: THE PARTIAL DEMOLITION, AND 1928: THE REOPENING.**
*(Ruled 2026-08-09, at the owner's direction. Settles the 1912/1928
question and governs every date the building shows the player.)*

**The Orison was partially demolished in 1927 and reopened in 1928 as an
apartment building. What it was, and what happened to it, is shrouded in
darkness.**

**IT IS 1928 WHEN THE GAME STARTS.** This supersedes the earlier pinning
of the present to late 1927. Everywhere else in this document, and in the
wardrobe bible, **"1927" is the VINTAGE of ordinary things, not the date
on the calendar** — and it still gives the right answer, because the test
was always "is this object second-hand and a bit behind". In a 1928
present, last year's is exactly what second-hand looks like. Nothing that
was researched as 1927 needs re-dating; the Rule of Signal's question
(§VIII.2) is unchanged.

**The building reopened the year before last winter.** Every resident in
it moved in within the last twelve months. Nobody in the cast has a long
history with this address, because the address does not have one either.
Whatever they brought with them, they owned in 1927 — which is why the
whole building is dressed one year behind and none of it is a costume.

Both dates are true and neither replaces the other:

- **1912 is the fabric.** Vantry & Co. built the showcase (§VIII.3), and
  what survived the demolition is still doing its job — the hand-fired
  coal boiler (§VIII.5.c), the house listening system and its Vantry
  points (§VIII.5.a), the light court, the stair. **The oldest things in
  the building are older than the building's own front door**, and they
  are the ones that were never taken out.
- **1928 is the address.** The Orison the player stands in opened that
  year as flats. The entrance, its transom, the sign that reads
  EST. 1928, the earliest photograph on the lobby wall, the notice on the
  stair landing and the oldest surviving light fitting all date from the
  reopening, and they are all correct. **The building's paper trail
  begins in 1928 because that is when this building began.**

**THE SIXTEEN YEARS ARE THE POINT.** Nothing in the game explains what
the Orison was between 1912 and 1927, why part of it came down, or what
was on the ground it reopened over. No document survives it. No resident
remembers it. The prospectus in Mae's shelf is a sales book for a
building that was demolished, which is why it is the most disquieting
object on that shelf and not the most reassuring one.

This is the same silence the world already keeps about WORS 1610 and
about the three machines with no maker's date (§VIII.5.g). **Do not
explain it anywhere in the game.** A resident may wonder aloud. Nobody
answers, and no found document answers either.

**A partial demolition is also the plainest possible reason the plan is
the way it is** — why 1912 services run under 1928 rooms, why the
survey does not close, why a wall is thick where nothing needs to be
thick. Accord 9 already says everything is twenty years old and repaired
by four people. This says the building itself was.

**VIII.5.i — THE BATHROOMS SHARE FOUR ROOF VENTILATORS.** The 1928
reopening fitted twenty-three windowless bathrooms to four sheet-metal
risers, each ending at an ILG-pattern electric ventilator on the roof.
Inside a flat there is only a painted gravity register: no switch, no motor,
and no privileged private extractor in 4B. The roof plant cycles by stack,
so its tired bearing tone appears in one vertical run of bathrooms and then
goes away.

This carries no signal. An electric motor is powered machinery, not a
message, and the Rule of Signal gives it no licence beyond its period. The
system is ordinary reopening-era plant threaded through surviving 1912
fabric — exactly the seam §VIII.5.h says the building is made from.

**VIII.5.j — THE PLAYER CARRIES A SERVICE RADIO, NOT A PHONE.**
*(Ruled 2026-08-15, at the owner's direction. The implementation proposal and
historical lineage are in `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md`.)*

The object in the player's hand is a **Vantry portable building-maintenance
service radiophone with an attached inspection lamp**. It has no screen,
camera, keypad, keyboard, menu or operating system. Its controls are physical.
Its only display-like feedback is one amber annunciator jewel indicating that
a work order has been filed. That light presents `WorkOrders`; it never owns or
advances them.

The radio chassis earns the Rule of Signal's advance. The attached work lamp
does not: it is ordinary pre-1928 tungsten, glass, brass and tinned steel, with
a simple `OFF / ON` contact. The set is heavy because portable batteries are
still heavy. The old carried phone, its camera and its private screen games are
superseded fiction and may not remain production dependencies merely because
their code already exists. They are audited and migrated before subtraction,
not silently deleted.

### VIII.6 What this does not license

**The divergence is not a licence for anachronism at will.** The rule of
signal is narrow on purpose. If an object is not carrying a signal, it
is 1927, it is second-hand, and it is probably a bit broken. A jet
engine is not permitted because somebody invented a good microphone.

And per Accord 9, **ordinary decay still outranks spectacle**. A world
forty years ahead in signal is not a world of gleaming devices — it is a
world where the gleaming device is twenty years old, has been repaired
by four people, and sits on a table with a wonky leg.

## IX. THE DREAM MAZE

*Ruled 2026-08-15, at the owner's direction. Construction detail and proof
gates live in `design/ORISON_MAZE_BRIEF.md`.*

**The restriction that “the dream world is our reveal” binds the title screen,
not production.** Menus and promotional hero art remain in the waking ORISON /
STREET / PASSAGE world. The campaign itself enters and shows the dream after the
player earns it through the complete first shift.

Each completed case ends in one involuntary **release-print dream**. The Tenant
wears the shadow and wound grammar of the case that has just integrated while it
lets that subject go. This is the last image of the transition, not a reopened
case: after the player wakes, the resolved case remains quiet. No campaign dream
previews the next unresolved resident.

The space is one deterministic ten-module ring built from locally faithful
Orison rooms and globally impossible connections. The same campaign seed keeps
it learnable. The service-set lamp is the single continuous decision: it reveals
the route and hazards while giving the Tenant a target; darkness breaks visual
acquisition but never becomes an indefinite hiding state. There is one Tenant,
represented only through a borrowed shadows-only silhouette, architecture and
sound. It has no model, face, attack animation or true form.

The player does not die in the dream. Capture, falling or contact with a hazard
cuts the passage and wakes the same living person at the authored 4B bedside,
without a failure screen or loss of committed work. Campaign run ceilings are
28, 38, 50, 62, 76 and 90 seconds. The player's own shadow is reserved for
endgame design outside the six-case production scope.

**The Rule of Signal does not bind the dream.** It may reuse and transform
Orison architecture, signals and anachronistic language because it is not the
waking building. The exemption is one-way: the waking Orison never advertises,
explains or confirms dream geography.
