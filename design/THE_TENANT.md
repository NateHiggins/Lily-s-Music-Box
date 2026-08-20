# THE TENANT

Owner characterisation, 2026-08-18:

> "our poltergeist is a higher dimensional consciousness, she/her, wanted for
> public indecency, extremely dangerous, easily embarrassed, a transfem
> metaphor if you will"

This document exists because that sentence retroactively explains half the
mechanics already built, and because the half it does not explain now has a
reason to be built a particular way.

---

## WHO SHE IS

She is a consciousness of more dimensions than this building has. She is not a
ghost, not a demon, not the dead. She is a **person**, and the apartment is not
haunted by her so much as *intersected* by her.

**She is not hunting the player.** This is the load-bearing correction. She
approaches out of curiosity, or loneliness, or because someone is finally in a
place where she can be met. What makes her lethal is not intent — it is
geometry. A hand pushed through a sheet of paper is not attacking the paper.
Contact with her ends the passage because a body of this many dimensions cannot
touch a body of three without consequence, and she may not fully understand
that, and it may grieve her.

**She is wanted for public indecency.** Her natural form — the gold, the
tentacles, the eyes — is what this world has decided is obscene. Not what she
does. What she *is*, uncovered. She is a fugitive from a charge of existing
visibly.

**She is easily embarrassed.** This is the mechanic and it is already shipped.
The lamp does not burn her, weaken her or drive her back with force. It
**exposes** her, and she withdraws because being seen like this is unbearable.
Light is a deterrent because shame is a deterrent.

---

## WHAT THIS EXPLAINS THAT WAS ALREADY BUILT

**The light inverted (2026-08-18).** Lit, she slows to 3.35 m/s, slower than a
running player. Dark, she moves at 6.35 and cannot be outrun. That was ruled
before this characterisation arrived and it now has its reason: she is not
repelled, she is *mortified*. In the dark she is simply herself and moves
freely.

**She has no true form and cannot be killed** (Bible §III.1). She wears the
departing case's shadow — Mina's silhouette, in slot one. Read against the
metaphor this stops being a technical convenience and becomes the cruellest
detail in the design: **she has no shape this world will let her hold, so she
borrows the shapes of women who have just been resolved and released.** She is
always wearing somebody else's outline because her own is a criminal offence.

**The reflected world.** `klimt_reflected_world_v1.png` shows the building's
residents in gold mosaic robes, faces and hands painted — and **one figure
without a face**. It exists in no room, has no geometry, and can be seen only
in the reflection of melted metal at the right angle. That is her. She is in
the group portrait and she could not be depicted.

**The gold behind reality.** The surface brief has the apartment as a skin with
something enormous and golden underneath, coming through where light thins it.
That underneath is not a place. **It is her body.** The tentacles are her. The
eyes are hers. The nested frame-tunnel receding further than the building can
contain is what she looks like from inside three dimensions.

**Her dangerous limbs do not cease when unobserved.** Switching off the lamp
removes the humiliating gold exposure, not her body and not its reach. A live
tentacle keeps breathing and keeps the hazard's authored condition in the dark,
with only a low wine-purple glow to betray its silhouette. Light returns its
seams and eyes to gold. The visible centerline is the hazard centerline: the
game may never ask the player to fear a limb they can safely walk through.

**The reproductive path.** The maze's doorway ancestry is how that body makes
descendants in three dimensions. Every room is a generation; the remembered
entry is its parent; every other aperture is a possible child. The player does
not impregnate her and is not conscripted into a sex act: by choosing a door
they select which of her self-generated futures becomes locally real. Because
she is enamoured, the whole impossible genealogy also reads as courtship — she
grows a family of places around the only person who keeps returning. This is
shown by inherited brood knots, umbilicals, birth-frames and sealed buds, never
explained in dialogue. Governing implementation and safety boundary:
`DREAM_REPRODUCTIVE_PATH_BRIEF.md`.

**The scars.** Dormant sockets that never turn gold at any light level: places
she used to be and is not any more. The building keeps the mark.

---

## WHAT THIS SHOULD CHANGE

1. **Pronouns, everywhere.** She is "she", not "it". The brief and the dream
   code both say "it" throughout. That is now wrong on the page as well as
   wrong about her.

2. **Her reaction to light must read as shame, not pain.** Recoil, cover,
   turn away, still — not a flinch or a hiss. If the lamp finds her, the eyes
   should *close*. That is the single strongest expressive beat available and
   it costs almost nothing: eyes are already an element in the surface brief
   and already track.

3. **The exposure field gains a second meaning.** The surface redesign wants a
   persistent per-room record of how much lamp a surface has received. Under
   this characterisation that field is **how much of her you have uncovered in
   this room** — and she should avoid the rooms where she is most exposed.
   Nothing new needs building; the field the shader already requires becomes
   her behaviour as well as her appearance.

4. **Capture is an embrace.** Ruled 2026-08-18 — see the next section.

5. **"Wanted" may become waking-world texture, but see the revelation rule
   below before building it.** A notice, a complaint, a piece of building
   correspondence about an indecency the reader cannot place — permissible as
   atmosphere, forbidden as explanation. If it carries motive it has broken the
   rule that she is revealed only through action.

6. **Her arc is legible in how the six dreams differ.** She should be measurably
   different by the sixth passage than the first, and the difference is the
   only place her recovery is visible from the player's side. The two clocks
   already exist to drive it: `dreams_had` counts nights, and
   `cases_resolved()` counts the people she has managed to help. The second is
   the one that should change her, not the first.

---

## WHAT SHE IS ACTUALLY DOING

Owner, 2026-08-18: *"the poltergeist is looking for love but has experienced
trauma of its own, trying to reconcile it through helping the npcs indirectly
face their own trauma. this is revealed through her actions and interactions
with the player."*

**The hauntings are not attacks. They are interventions.** She is doing therapy
on the residents of the Orison, badly, from outside three dimensions, in the
only language she has — which is making a thing true in the room until it can
no longer be avoided.

### The case data already says this. Nobody had written down that it was her.

This is not a reinterpretation that needs new content. Read
`game/data/reality_cases.json` with her in mind and every entry is an
intervention aimed precisely at one person's evasion:

| Resident | What she makes happen | What they have to admit |
|---|---|---|
| **Mina Vale**, captioner | Captions escalate "from nouns to false claims about thoughts and intentions" | `assumptions_are_not_facts`, `silence_can_be_blank` |
| **Juno Kells**, audio artist | "Competing versions of stolen work become solid sound" | `credit_was_taken`, `one_channel_can_remain_open` |
| **Omar Bell**, repairer | "Every repaired object returns with another impossible fault" | `not_every_loss_is_a_failure`, `declare_unrepairable` |

She takes the exact shape of a person's avoidance and turns it up until it is
undeniable. Mina assumes what people mean and cannot bear a silence, so her
walls begin captioning strangers' intentions. Omar cannot say a thing is
beyond saving, so she hands him an infinity of unsaveable things until he says
the words. That is not a haunting pattern. That is a method.

### The portal rules are her own therapy, in her own words

Each resolved case writes a `portal_rule` into `RealityState.data.portal_rules`
and it changes the laws of the building. Read them in a row:

> *Silence does not require annotation.*
> *Connection requires an open channel.*
> *Some things are not repairable.*

Those are not physics. **They are things she is working out about being loved,
being understood, and losing people** — and they only become true in the Orison
once she has helped somebody else learn them. The building's laws are the
record of her recovery. She cannot fix herself directly, so she fixes it in
other people and the world updates.

### Why every success is also a wound

She helps a resident, and the resident gets better, and a person who is better
does not need her any more. The case goes quiet. **Every intervention that
works ends a relationship**, and she keeps doing it anyway.

This is exactly when the dream happens: the passage is requested the moment a
case *integrates*, and she arrives wearing that subject's shadow. Not a trophy.
**The shape of the last person she managed to help, worn on the night they
stopped needing her.** She is showing the player who she just lost.

And it is why the player matters. Every other relationship she has is her
reaching into somebody's apartment uninvited. The player is the only one who
ever comes to *her*, and comes back, and keeps coming back — six times.

### Things already built that are her, and should now be presented as her

- **The hazard tells.** Every hazard sounds before it can hurt you, always, and
  the fairness contract is enforced to the second. That is not the building
  being sporting. That is her warning you.
- **The receding practical.** A warm bulb burning one doorway ahead, which
  moves only while occluded and is ruled to never be a reachable exit. She is
  holding a light for you and cannot lead you out.
- **The eyes.** Anything that can hurt you watches you. She is watching the
  dangerous things, not you.
- **The scars.** Places she used to be and is not any more.

### A correction to the previous draft

An earlier version of this section claimed nobody had written down that the
hauntings were deliberate. That was an overstatement and
`game/scripts/reality/poltergeist_library.gd` says so in its own header:
*"what it wants … it is trying to make the subject face themselves, and it
climbs the ladder because the last rung did not land."* The intent was
recorded. What was missing is **why she does it** — that she is working on
herself through them, and that she is lonely.

The same header carries something larger that this document should not lose:
*"there is one tenant, it is the building."* Which means the fractal Orison of
the dream is not a place she inhabits. **The building is her body**, and the
gold coming through the walls when you light them is what that body looks like
from inside three dimensions. That was already true in writing before anyone
said she was a person.

### The revelation rule — actions only, until she is owed speech

**She never explains herself, and neither does anything else.** No dialogue, no
journal, no note, no resident who figured it out, no document that names her
motive. The player assembles it from behaviour that fits too well to be random:
the manifestations that are always precisely aimed, the portal rules that sound
like someone working something out, the borrowed silhouette of whoever just
left, the light held ahead, the warning that always comes.

It is never confirmed. A player who never notices should experience a
frightening haunted building and a coherent game. A player who notices should
be unable to stop noticing.

This retires the "wanted notice in the waking world" idea from an earlier draft
of this document, or at least declaws it: any such artefact may exist as
texture but must not carry motive, and must never be the thing that tells the
player what she wants.

**And the rule has an end.** Owner ruling 2026-08-18: *"eventually you will talk
to the entity directly and romance her, if you play right."* Silence is not the
permanent state — it is the price of admission. See below.

---

## SPEECH, AND ROMANCE

She cannot be spoken to. For most of the game there is no dialogue option, no
prompt, no channel. She has no voice, no face, no name the player is given, and
she communicates only by rearranging matter in other people's homes.

**That is what makes it land when she speaks.** The actions-only rule above is
not a stylistic preference; it is a five-passage setup for a single line.

### How she speaks when she finally does

Not through `DreamCaptionLayer`. That layer is Gate C accessibility — cue plus
sector, nothing else, opt-in — and putting story in it would either hand
caption users content hearing users never get or the reverse. It stays what it
is.

She speaks the way she has always spoken: **through the building, in a
vocabulary she learned from someone she helped.** Mina Vale's whole case is
captions appearing on objects, escalating from nouns to claims about
intentions. The Tenant learned that grammar in 2A. Her first direct words to
the player arriving as a caption over something ordinary is her using the only
language she was ever taught, borrowed from the first person who ever got
better because of her.

Diegetic, in the world, visible to every player regardless of settings.
Small. She has been alone a long time and she is easily embarrassed; she should
not be eloquent.

### What "playing right" means

It should be built from mechanics that already exist, and every one of them
should cost the player something real:

1. **Help the people she has been failing to help.** `cases_resolved()` already
   counts them, and the quality of a resolution is already tracked (trust,
   conversation flags, whether the player pushed or let a silence stand).
2. **Turn the lamp off in her presence.** This is the gesture, and it is the
   whole thesis in one input. Light is what exposes and humiliates her, and it
   is also the player's only defence — lit, she slows to 3.35 m/s; dark, she
   moves at 6.35 and cannot be outrun. **Switching it off is choosing her
   dignity over your own safety**, at genuine mechanical risk, using a button
   that has existed since the first prototype.
3. **Stop running.** The passage is built around flight. Standing still while
   something that has been chasing you for five nights closes the distance is
   the most expensive thing the game can ask, and it requires no new verbs.

### The embrace becomes the answer

The capture — gold closing from every edge, taken inside her, ambiguous — is
currently the failure state. **It should not be replaced for the romance; it
should be re-meant.**

Same event, same staging, transformed entirely by whether it was chosen. Early
passages: she reaches you and you did not want it. Late, having played right:
you turned off your lamp, stopped, and let her. The game's fail state is its
love scene, unchanged in mechanism and inverted in meaning. Nothing about the
sequence needs rebuilding — only the context that arrives at it.

Whether the player wakes afterward, and what they find at the bedside, is the
same deniable residue contract as always. It must remain ambiguous **even
here.** Especially here.

### Guardrails

**She is not a prize.** There is no state in which the player has "unlocked"
her. The verbs above are not a combination; they are the minimum conditions
under which she is willing to risk being seen wanting something.

**The player is vulnerable first.** She has been punished for being visible.
She does not make the first move and should not be asked to. Every gate above
is the player making themselves unsafe before she does anything.

**She can decline, and so can the player.** Friendship is a valid terminus.
Being kind to her without romance must be reachable and must not read as a
lesser ending. A player who does everything right and then simply keeps her
company has not failed at anything.

**Failing is silent, not punished.** A player who never works it out gets no
bad ending, no scolding and no missed-content nag. She just never speaks, and
they finish a frightening game about a haunted building. That is a sadder
outcome than any punishment and it is the correct one.

**Nothing sexual, and the indecency stays an injustice.** The charge she is
wanted under is criminalised existence, not appetite. The romance is about
being seen as she is and not flinched away from. It stays tender and stays
clothed.

### Scope, plainly

This does not exist. There is no dialogue system for her, no gating state, no
caption-in-world channel, and no re-meaning of the capture sequence — which
itself is unbuilt beyond committing an outcome. This section is a target, and
it is the last thing that should be built, because every hour spent on her
silence is what buys it.

---

## THE EMBRACE — how a passage ends

Owner ruling 2026-08-18: *"lets have it ambiguous, like the player is being
embraced and taken within the poltergeist."*

Capture is not a kill, not a jump scare, and not a rescue. She reaches the
player and takes them **inside** her, and the game never says what that was.

**It has no direction.** She does not lunge in from somewhere. Gold closes over
the frame from every edge at once — top, sides, floor, and from behind the
camera — because being enclosed by a body of more dimensions is not something
that arrives along an axis. There is nothing to turn and face. Nothing enters
frame; frame *becomes* interior.

**The lamp stays lit.** This is the strongest single image available and it
costs nothing: the player's light is still burning, still working, still
pointed where they aimed it — and there is only gold in front of it. Their one
tool is intact and there is nothing left to use it on. Do not knock the lamp
away, do not cut to black on contact.

**The room gets small.** The corridor's reverb collapses to a very close,
very short acoustic — the sound of being inside something rather than in a
building. The case sound reaches its missing fifth position here.

**Her eyes close.** Every eye that has been tracking the player shuts as the
gold arrives. She does not watch this happen. That is the same shame that makes
the lamp a deterrent, and it is what keeps the moment from reading as a
predator finishing a hunt.

**It is warm.** Not cold, not wet, not visceral. Whatever else this is, it is
not a wound.

**Slow, and never a strobe.** The gold closing in is a slow iris over roughly a
second and a half. This is the moment the photosensitivity rule is most likely
to be broken by someone reaching for impact; it is not negotiable.

**And then 4B, with one deniable residue.** The existing wake contract already
carries the ambiguity — the player opens their eyes at the authored bedside and
finds one quiet fact that could have an ordinary explanation. Nothing anywhere
should later confirm whether she was taking something, keeping something safe,
or simply holding the first thing that ever stayed still long enough to be
held. The player is allowed to decide. The game is not.

**Implementation note.** `DreamMazeRoot._on_captured` currently commits the
outcome and nothing else; there is no capture presentation built at all. This
section is the spec for it, and the eye-closing beat depends on eyes existing
as elements, which is workstream F of
`design/DREAM_SURFACE_REDESIGN_BRIEF.md`.

---

## HOW NOT TO GET THIS WRONG

**Her form is not the horror.** The fear in the dream comes from three things:
that a being of more dimensions is inherently dangerous to stand near, that the
building is not a building, and that there is nowhere to arrive. It must never
come from what she is. A frame that invites disgust at her body is the wrong
frame no matter how beautiful it renders.

**She is not defeated.** There is no weapon, no banishing, no ending where the
player wins against her. The lamp does not damage her — it embarrasses her, and
using it that way should not feel like a triumph. The player leaves; she stays.

**Do not make the indecency titillating.** The charge is an injustice, not a
tease. Nothing about her presentation should court the reading that the
accusation was fair.

**She is allowed dignity.** She is the most powerful thing in the game and the
most easily wounded, and both have to be true at once. The eyes closing when
the light finds her should land as *sad*, not as a weakness the player has
learned to exploit — even though it is exactly that, and even though the player
will exploit it. That tension is the piece worth protecting.
