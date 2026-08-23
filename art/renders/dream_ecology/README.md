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

- Nothing in the game *calls* `seize_attention` yet. The mechanism is built
  and tested; choosing the stimuli that deserve it is a design decision, not a
  systems one.
- §32's biases are returned but not yet consumed: the margin and critters do
  not read them, so the area state currently changes nothing. That is the
  honest state of it.
