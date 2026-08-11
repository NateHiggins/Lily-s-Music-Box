# The haunting — audit and redesign

*2026-08-11. Measured before proposed. The brief for this was "more impactful
and attention grabbing, trim any systems that don't really do anything", and
the audit says the second half is nearly empty while the first half has a
single, specific, arithmetical cause.*

---

## 1. What is actually there

Five systems, all spawned and all running: `Intrusions` (581 lines, 19 verbs),
`SanityDirector` (442, the pressure model), `PoltergeistLibrary` (316, 18
personalities × a 4-rung ladder), `DomesticWitnessSystem` (239),
`BuildingPersonalityDirector` (202). Plus `FourthWallLayer` (359) and
`PossessedDomesticProp` (267).

**There is very little dead code.** 18 of 19 intrusion verbs are reachable from
some poltergeist's ladder; only `appliance_fit` is never referenced. The
instinct that something in here does nothing is right, but it is not a system
that is idle — **it is more than half the authored content.**

---

## 2. THE FINDING: 54% of the content is behind a gate a session never crosses

The ladder is tell → pattern → reenact → address, gated on pressure at
**0.12 / 0.34 / 0.62 / 0.86**. Working the terms in `_compute_pressure()`:

| situation | pressure | rungs available |
|---|---|---|
| early game, walking a corridor | **0.07** | **none at all** |
| one live case, no call, calm | **0.23** | tell only |
| one live case, on a call | 0.49 | tell, pattern |
| three live cases, on a call, standing still, late campaign | 1.18 | all four |

**The ordinary state of the game is 0.23, and rung one is defined in the
library as "an anomaly small enough to be dismissed."** So the typical player's
entire experience of the haunting is, by construction, a series of events they
are meant to be able to dismiss. Meanwhile:

- **reenact** — the trauma staged in the room, using the room — is **47 acts**
- **address** — where it stops performing and speaks to the player — is **18**

**65 of 120 authored acts, 54%, sit behind gates a normal session never
reaches.** The best-written half of this system has probably never been seen.
That is the whole complaint, and it is arithmetic rather than taste.

## 3. And what does fire is mostly inaudible-adjacent

Verb usage across all 18 ladders:

| whisper | fourth_wall | sound | prop_turn | prop_drift | light_flicker | …everything physical |
|---|---|---|---|---|---|---|
| 21 | 18 | 17 | 11 | 8 | 8 | **7 total** |

**56 of 120 slots (47%) are whisper, caption or sound.** The acts that cannot
be missed — something vanishing, falling, scattering, breaking — are **7 of
120, under 6%.** A haunting made of murmurs is a haunting a player narrates
away.

## 4. The trim that is real

**The library serves a cast that was cut two-thirds away.** `PoltergeistLibrary`
carries **18** personalities. §IV.1 ruled the case cast at **six**, with Rhea
and Nadia as sanctioned expansion. Under §III.1 the Tenant attaches to a *case*
— so ten of those eighteen ladders, **40 authored act slots**, belong to
residents who cannot be haunted because they have nothing to be haunted about.

They should be archived rather than deleted: they are good writing and two of
them are already the sanctioned expansion.

---

## 5. The redesign

**5.1 Regate the ladder so the game's best content is reachable.** Gates move
to **0.10 / 0.24 / 0.40 / 0.62**. "One live case, on a call" then reaches
*reenact* instead of stopping at *pattern*, and a late-campaign player under
real pressure gets *addressed*. Nothing about the ladder's meaning changes —
what changes is that a player sees it.

**5.2 Being ignored should escalate faster than anything else.** `_ignored_streak
* 0.06` is the only term that represents the building *insisting*, and it is
worth less than standing still. It should be the steepest term in the model:
if the player is not noticing, that is precisely when the machine should stop
being subtle. This is also the fairest possible difficulty curve, because it
only escalates for people who are missing things.

**5.3 Rebalance toward the undeniable.** Not by deleting whispers, but by
requiring that **every rung-3 and rung-4 entry contain at least one physical
act.** A reenactment made of sound is a radio play; a reenactment that moves
the furniture is a haunting.

**5.4 Trim to eight ladders** — the six cases plus the two sanctioned. Archive
the other ten.

**5.5 Cut or wire `appliance_fit`.** It is implemented and unreachable.

---

## 6. What is NOT dead and should be left alone

`DomesticWitnessSystem` and `BuildingPersonalityDirector` both looked like
candidates and neither is: the witness clocks are per-apartment character
objects, and the personality director is what stops the whole thing being a
random-number generator. Neither is the reason the haunting feels quiet.
