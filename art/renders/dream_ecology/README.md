# PHASE 13 — THE ECOLOGY DIRECTOR, AND THE ONE MIND

`DreamEcologyDirector` has two jobs, and §33 insists they stay separate.

## The area state biases probabilities (§31, §32)

Nine states — `DORMANT` … `INCARNATING` — each returning multipliers on
movement, contact, sociability and orientation. They do **not** drive
animations and they do **not** synchronise anybody. During `FORAGING` there is
more contact; during `WATCHING`, less locomotion and more sensory orientation.
Everyone still decides for themselves.

## Global attention overrides local intent, and almost never happens (§13, §40)

> *"Twenty procedural palps are doing different things. Several critters are
> moving independently. Hero Tentacle is examining an object. A sudden
> meaningful stimulus occurs. At the same instant: procedural tips orient,
> critters stop or turn, hero eye fixes… Hold. Then autonomy returns
> asynchronously."*

§40 makes the *transition* the acceptance test, so the two halves are built as
opposites and both are measured:

| | measured |
| --- | --- |
| before | 72 palps doing **5 different things**, 8 critters, hero on its own errand |
| the snap | **72/72 palps, 8/8 critters, and the hero**, all on the same point, within one frame |
| the release | **109 individuals letting go across 5.30 s** |

The snap has no easing and no per-individual delay, because the legibility of
the whole beat is that it is simultaneous. The release is staggered by each
individual's own curiosity and startle threshold, because a coordinated
release would read as a machine switching off rather than as attention
lapsing.

Nothing fires this on a timer. §40 says it must stay rare enough to remain
meaningful, so it is called deliberately or not at all.

## Two bugs the contract found

**A palp born mid-event carried on working a skirting board** while
seventy-one others stared at the same point — which breaks the entire reveal.
Anything born during an event now joins it.

**Branches had no `attend_override` field at all.** They are built in
`try_branch` rather than `_birth`, so every field the rest of the system
expects has to be repeated there, and this one was not.

## Not done

## What triggers it (owner direction, 2026-08-23)

> *"wire seize attention to trigger whenever the player modifies the
> environment, open a door, fixes something etc"*

`PlayerController` emits `world_modified(where, what)` from its single
interaction chokepoint, so it covers **every** prop that answers `interact` —
a door opened, a switch thrown, a fault put right — without each of them
having to know anybody is listening.

§40 pulls the other way: the reveal must stay rare enough to remain
meaningful. Both are satisfied by a floor on how often it can happen rather
than by ignoring some interactions. Every modification is noticed, but the
ecology cannot snap to attention while it is already attending, and will not
do so twice inside a 22-second cooldown. **A door opened ten times in ten
seconds is one event, not ten** — which is also how attention works in an
animal.

The whole chain is tested, not just the function: the player's signal, the
director's gate, all three levels reacting, the ecology looking at the point
that was touched, the second modification declining to re-seize mid-event,
and the cooldown holding afterwards.

One bug worth recording: the encroachment tried to make this connection when
it was built, which is **before the player exists**, so it connected nothing
and said nothing. The director finds the player itself now and retries until
it appears. A `find_child` by name failed the same silent way before walking
up the tree fixed it.
- §32's biases are now consumed. The margin scales how long an act lasts and
  how readily an appendage turns to watching; the critters scale their pace.
  Measured by driving the area to opposite extremes and watching how far the
  population actually travels: **0.481 m while dormant against 1.197 m while
  foraging**. The individual's own speed still decides its pace — the state
  only scales it.
