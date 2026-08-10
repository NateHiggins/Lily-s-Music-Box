# THE DREAM — PROPOSAL

*Filed 2026-08-10. Proposal, not a ruling: nothing below is canon until the owner
says so. Obeys `ORISON_BIBLE.md` §I (both true) and §VIII (the Rule of Signal
does not reach here — see "What the dream is exempt from").*

---

## THE ONE-LINE CASE

**The player is narcoleptic. When they go down, they wake somewhere that is
almost the Orison, in the dark, with something already coming — and the only
way out is to die and wake up in bed.**

Then the phone rings, and there is a new case.

---

## THE LOOP

```
   the waking building
         │
         │  sleep takes them — gradually, or without warning
         ▼
   THE DREAM        10 seconds early in the campaign · 90 seconds late
         │          run, turn, and decide about the light
         │
         │  a hazard, or the thing behind you
         ▼
   awake in bed     always in bed, however far they got, wherever they fell
         │
         ▼
   the phone rings — a new issue, called in
```

Death is the only exit. There is nowhere to get to. **The feeling of progress is
purgatory** — and the building is not lying about that, because there is no
destination and never was.

---

## WHY NARCOLEPSY IS THE ENGINE, NOT THE FRAMING

§I sets one law: **both true.** Every explanation must be true and neither may
win. Until now that has been held by authorial discipline. The condition makes it
structural:

> The dream is a hypnagogic hallucination — a real, documented symptom.
> The dream is the building showing what it keeps.

Neither reading can be dislodged, because the condition explains it completely
and explains nothing. **This is the cleanest expression of §I in the project.**

It also explains the premise. Narcolepsy makes ordinary employment hard. This
person took a job where you work alone, at night, in the building you live in, in
exchange for rent. Nobody sensible designs that job. Someone would accept it.

**Play the condition straight.** Real narcolepsy carries excessive daytime
sleepiness, sudden sleep attacks, cataplexy, sleep paralysis and hypnagogic
hallucination. The real symptom set is richer than anything we would invent, and
treating a disability accurately is both more respectful and more frightening
than treating it as a device. It is named in the game and part of a lived life,
not a reveal.

### Onset

- **Gradual** is a warning and therefore a choice: desaturation, the field
  narrowing, a low-pass creeping over the mix, the torch dimming, the building's
  hum rising underneath. In a game about sound, *the mix going wrong* is the most
  legible possible tell.
- **Sudden** has no warning at all.
- **Resistance is weak and brief.** The player can push back for a moment —
  stand up, move, cold water — and it buys seconds, not safety. It must never
  read as a cure.
- **Cataplexy** is the cruel one and belongs in the design: strong emotion drops
  you. The player's job is being present for people on their worst night, so the
  moments that land hardest are the moments most likely to take them.

**They must fear it happening.** That is the design target for the waking game,
and it is achieved by surprise, not by frequency.

### A call in progress protects them

*(Ruled 2026-08-10.)* Once a call has started, sleep holds off. The job is the
one safe place, which is worth more than the cruelty of taking someone
mid-sentence — and it obeys the rule that an attack may cost time, position and
dignity but never work.

**It delays; it does not cancel.** Pressure accumulates through the call and
fires when the handset goes down. So the shape of it is: the conversation lands,
the player feels it land, they hang up — and then they go down, because feeling
it is what drops them. The dread moves into the aftermath, which is a better
place for it, and there is no exploit in staying on the line.

**Accessibility valve: ship an option forcing every onset to be gradual.** It
keeps the mechanic and removes the ambush, and it costs one boolean.

---

## THE LIGHT IS THE ENTIRE GAME

There is no UI. There is a light source. Everything the player decides comes down
to one binary, held continuously:

| | You can see | It can find you |
|---|---|---|
| **Light on** | hazards, corners, the way through | **yes — the light attracts it** |
| **Light off** | nothing; you navigate by sound | no |

That is the whole verb set: run, turn, and decide about the light. It is enough,
because the decision is live every second and both answers are bad.

**This is why the hazards must teach through sound** — see below. With the light
off, hearing is the only sense left, and the acoustic graph is already built.

---

## THE THING THAT FOLLOWS

**It is the poltergeist — and it is the poltergeist of the case the player is
currently working.**

`poltergeist_library.gd` already defines one per resident, each derived from that
resident's case: its manifestation, its resolution flags, its portal rule.
"Nothing is invented." So the thing in the dream is not a monster. It is **this
week's resident's wound, given a shape and a direction.**

That buys an enormous amount for nothing:

- The dream changes character per case with **no new content** — the library
  already describes how each one behaves.
- It explains the loop's ending. You are pursued by the next case before you are
  assigned it, and then the phone rings.
- It keeps §I intact. The thing chasing you is a hallucination of a person's
  documented problem, and it is the building carrying that person's wound
  through its own wiring. Both true.

Rules, settled:

- **One.** Never two.
- **Unkillable.** No hazard will kill it; that door stays shut.
- **The same one, night after night.** It has been waiting.
- **No hiding.** This is short — run or die.

---

## THE MAZE

**A fractalised apartment building: everything is correct close up, and nothing
about the larger layout makes sense.**

Local coherence, global incoherence. A door, a skirting board, a light switch and
a floorboard are all exactly right at arm's length. The corridor they are in
returns to itself. The stair goes up and arrives below. A hallway of nothing but
bathrooms.

**This is why it is generated rather than authored.** A fractal layout cannot be
hand-built sensibly, and — unusually — it cannot look "wrong", because wrongness
is the specification. The usual objection to procedural space, that it reads as
generated, does not apply when generated is the intended reading.

- **Room archetypes come from the Orison itself.** The real flats, corridors,
  landings and service spaces, used as vocabulary. Reuse the assets *wrongly*:
  the same wallpaper at twice the scale, thirty identical doors in a row, a
  landing that appears four times. Cheaper than new art and considerably more
  disturbing, because the player half-recognises all of it.
- **One entrance.** Wherever the player fell asleep, the dream starts in the
  same place, so that recognition compounds.
- **The seed is fixed per save.** Generated once, at campaign start,
  deterministically. Your building is nobody else's and it is the same building
  every night — which is what makes hazards learnable at all.
- **It should run the same audit `gen_layout.py` does** — overlap, footprint,
  door width, door swing — and exit nonzero on a real defect.

### A light that escapes you

There is something ahead, and it is receding. It gives every run a direction
without giving it a destination, and it is honest: the player is not being
cheated of an exit, because the absence of an exit is the subject.

---

## HAZARDS

**Eight, fixed for the save.** Learnable because they never move.

The rule that makes a hazard fair: **in the half second before it kills you, you
must understand why.** If the player cannot reconstruct the cause, it is not a
hazard, it is a dice roll, and they will stop learning and start hoping.

Which collides with darkness — so:

### Everything teaches through sound

The torch cone is a few metres of information and the hazard is usually outside
it. With the light off there is no cone at all. So every hazard announces itself
on a channel darkness does not take away, and the acoustic graph already models
propagation through heating, electrical, water, structural and flue.

- The open shaft has a **draught**, and a big empty volume sounds nothing like a
  corridor.
- The floor that gives **creaks differently one step before** it goes.
- The live thing **hums**, and the hum arrives through the wall before the room does.
- The thing that sweeps a corridor is **audible from the far end**, on a rhythm.

The player can also **make noise deliberately** to bait the poltergeist onto a
different network. The system for this exists and is currently idle.

### Four kinds

| Kind | What is learned | Example |
|---|---|---|
| **Positional** | *where* | the open lift shaft, a missing floor, a live rail |
| **Triggered** | *what not to touch* | a tread that gives, a door that locks behind |
| **Rhythmic** | *when* | something that crosses a corridor on a cycle |
| **Conditional** | *how* | only dangerous if entered at a run; only if the light is on |

The **conditional** ones are the most valuable. A corridor that only kills you if
you came into it at speed teaches the player they must sometimes stop *while
being pursued* — the hardest thing to do, and the best thing to learn. It is also
what stops the pursuit and the hazards from being two systems stacked on each
other rather than one system arguing with itself.

Introduce them gradually. At ten seconds a run the player meets one.

---

## PROGRESS IS AUTHORED, NOT EARNED

**Nothing persists.** No unlocks, no items, no shortcuts, no meta-progression, no
save state beyond the seed. The player gets better; the character does not.

So the leash is lengthened by the **campaign**, not by maze performance:

| | Run length | What it is |
|---|---|---|
| Early | ~10 seconds | wake, panic, three corners, dead. Disorientation, not mastery |
| Late | ~90 seconds | long enough to have learned the first rooms and to be losing the next |

The player is allowed further as the story proceeds, and they never earn it. That
is the correct feeling for purgatory and it should not be softened.

### The world never acknowledges improvement, and that is the point

*(Ruled 2026-08-10: the feeling of not making progress is the design.)*

Nothing congratulates the player. No counter, no distance, no best-ever, no
resident remarking that they look rested. The character is not getting anywhere,
because there is nowhere, and the game must never imply otherwise.

One distinction to hold on to while building it, because it is easy to lose:
**the player's own mastery still has to be perceptible to the player.** They
learn the first rooms, they recognise a corridor, they last ninety seconds where
they used to last ten. That improvement is real and felt — and the world's
refusal to acknowledge it is what makes this purgatory rather than noise. If
neither the character nor the player can perceive anything changing, the loop
stops being oppressive and becomes tedious.

Nothing needs to be added to achieve it; the run-length curve and room
recognition deliver it on their own. The instruction is only: **do not author
against it.**

---

## WHAT THE DREAM IS EXEMPT FROM

**The Rule of Signal does not reach here.** §VIII binds the waking building:
signal devices are forty years early, everything else is 1927 and second-hand.
The dream is not the building and is not bound. That exemption is what buys the
surreal, and it should be stated in the Bible if this is ruled canon, so nobody
later reads the dream as a violation.

The dream may reference the Orison; **the Orison never references the dream.**
One-way. Cheap now, and it keeps the option open.

---

## WHAT THIS IS NOT

- **Not an extraction loop.** Nothing is carried out.
- **Not combat.** Nothing can be killed, including the pursuer.
- **Not stealth.** There is no hiding. Run or die.
- **Not a mode.** The player never chooses to enter it.
- **Not a puzzle.** There is no solution, because there is no exit.

---

## PRODUCTION

- **Separate scene, same project.** Reuses the prop system, the light rig, the
  torch, the acoustic graph and the poltergeist library. No new subsystems.
- **Shapeless costs nothing.** No character model, no rig, no animation, no
  faces. Silhouette, darkness, mass and sound.
- **Asset reuse is the art direction, not a saving.** New art would be worse.
- Ten-second runs mean the whole early game is affordable to iterate on.

---

## OPEN QUESTIONS

1. **Which poltergeist chases the player before the first case is assigned**, and
   after the last one closes?
2. **Does the player's own poltergeist ever appear?** 4B has no case; §IV says
   the player's arc bends toward a release.
3. **Does the dream ever change after a case closes** — does the thing that was
   chasing you stop?
