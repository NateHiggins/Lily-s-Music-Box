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
  Wren is the ordained second case; none of the other sixteen shall be
  built before Peter meets Mina's bar.** *(Ruled 2026-08-02: all case
  content is TENTATIVE until its gameplay is worked through — cases are
  reviewed for functionality one at a time, with the user.)*

The two layers share residents, share the motif, and share one law: **a
case is weak if it can be solved by the obviously compassionate option.**

A third presence is planned and not yet incarnate: **the player's
shadow**, which learns a vocabulary from resolved cases and eventually
attempts one incomplete, contestable message. Its scripture is the
execution plan, Phase 4.

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

The night begins sealed: every apartment entry is locked except 4B and
the street door. A case activating unlocks its unit. Residents keep their
own hours behind their own locks.

`gen_layout.py` authors every coordinate. `b2g()` is the only conversion.
Nobody hand-edits generated JSON or glTF. These are laws, not customs.

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
| 2A | **Mina Vale** | caption editor; 22 years a certified court reporter before her ears began editing — four seconds blank in the record of the State ended that life | everything must be annotated or it doesn't count; *silence does not require annotation* |
| 2B | **Lena Ortiz** | seamstress, burgundy knit, shears | mends everyone but her own hem; *visible repairs can hold* |
| 2C | **Juno Kells** | audio artist, asymmetric crop, recorder | her work was taken and the feedback became load-bearing; *connection requires an open channel* |
| 3A | **Malcolm Reed** | horticulturist, moss silhouette | kept a cutting alive so a goodbye would not finish; *compost is transformation* |
| 3B | **Omar Bell** | repair technician, apron of categorized tools | cannot declare anything unrepairable; *some things are not repairable* |
| 3D | **Rhea Sato** | vocal coach and recording artist, severe bob, tuning fork | her mistakes accumulate as a captive note; *imperfection can be voluntary* |
| 4A | **Peter Wren** | legal clerk, rumpled brown, overfilled wallet | every uncertainty demands another form; *uncertainty does not prevent action* |
| 4B | **the player** | night maintenance; the desk is the tidiest thing in the flat | *ruled:* the best way to honor a beginning is with the release of an ending — the player's arc bends toward a release, and the shadow is writing the message |
| 4C | **Cam Ortiz** | bicycle courier, maroon shell, never fully still | rest reads as collapse; *weight can be shared* |
| 4C | **Noel Price** | museum preparator, chore coat, archival gloves | preserved the family life into untouchability; *use and change are forms of love* |
| 4D | **Transient Guests** | a replaceable pair, mismatched luggage | perpetual departure postpones the decision; *departure is a decision* |
| 5A | **Nadia Quell** | architect; signs the player's welcome letter "Management" | was silenced about violations once; *name the violation* |
| 5B | **Cal Dwyer** | radio collector, mustard cardigan, hearing aid | perfect tuning preserves moments by preventing them ending; *presence is not preservation* |
| 5C | **Iris Bell** | painter, headscarf, paint-ruined coveralls | imagined audiences hold every brush; *creation need not perform* |
| 6A | **Sacha Reed** | photographer-documentarian (they/them), camera and adapter tangle | the recording displaced the experience; *experience can precede proof* |
| 6B | **Jonah Price** | insomniac writer, navy robe, annotated notebook | endings avoided until they bite; *endings do not erase continuation* |
| 6C | **Mae Kessler** | antiques appraiser, bottle-green coat, white gloves | certainty is not memory; *contradiction is survivable* |

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
   Cal data supports. Echo or error?
5. ~~The family web~~ **RULED 2026-08-02: everyone is connected to
   everyone else — there is no such thing as coincidence in this
   building.** Every shared surname is a thread; every thread pulls.
   The target register is soap-opera drama played utterly straight:
   grudges, debts, loves and betrayals braided across all eight floors
   and — because this is purgatory — across *decades and centuries* of
   tenancy. The web itself (who is bound to whom, and by what) is to be
   developed as its own authored document, one relationship at a time,
   alongside the case work.
6. **Jonah: can't start or can't finish?** His case machinery rewards
   endings; his art and anecdotes are about beginnings. Both are good;
   pick the spine.
7. **HANDOFF's crown.** HANDOFF still names `photoreal_target.md` "the
   live status document" and frames the whole game as the desk prototype.
   *Interim: the execution plan governs; HANDOFF is pipeline mechanics
   only.* Bless or amend.
8. **Juno's theft, direction of.** Prototype: she samples others.
   Current case: her credit was taken. *Interim: both — she takes sound
   from the world without asking, and the world took her work without
   asking; the case is about the second.* Confirm.
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
