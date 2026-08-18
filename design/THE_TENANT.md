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

### The revelation rule — actions only

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
