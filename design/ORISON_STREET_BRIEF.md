# The street

*Proposed 2026-08-11. **Not canon until the owner rules.** The demolition in
here is done; the construction is not.*

The street outside the Orison is currently a corridor with scenery either side.
The proposal is to make it a **place with a current running through it** — one
you cross rather than walk along — and to do that without adding a single
interruption to the flow of travel.

---

## 1. What has already been removed

| Gone | Why |
|---|---|
| 16 parked cars, both kerbs | They hide oncoming traffic from a player judging a gap, cost submissions on the worst station in the game, and a street of switched-off vehicles reads as a diorama whatever drives through it |
| The bus shelter | **Not cancelled — unplaced.** See §6 |
| The arrival rideshare + its 4.7 m collision box | Same reasons, plus it should arrive *moving*. See §5 |
| The kerb-line stage boundary | **This was the invisible wall.** See below |

**The invisible wall, specifically.** Two collision segments ran the length of
the carriageway at y −17.35 with one 7.45 m gap at the crossing, so the player
could not step into the road except in one place. An earlier pass deleted the
near-black rail that used to telegraph them — correctly, calling it "a wall
wearing an apology" — and left the collision behind, which is the apology's wall
with nothing wearing it. A shape probe over the block
(`tests/StreetBlockProbe.tscn`) found it as the largest single blocker on the
street at 113 hits of 2346.

It could not survive this design anyway: **you cannot judge a gap in traffic
through a fence with one door in it.** The reason not to walk into the road is
now the road.

The lateral edges at x −20.10 and x +20.60 remain, backed by visible hoarding.
They are honest, and they are temporary — §4 replaces them.

---

## 2. The crossing is a texture, not a challenge

The single most important constraint, and the one that decides every other
question here: **crossing must never interrupt travel.** The moment it costs a
death, a reload, a fade or a menu, the street becomes a thing players route
around, and everything below is wasted.

So:

- **No death. No damage. No failure.** Being hit is a horn, a shove, four seconds
  of lost dignity and a scuff. The player gets up.
- **No UI.** No timer, no prompt, no score, no "press X to cross".
- **No dedicated crossing point.** Cross anywhere. The kerb is not a gate.
- **Gaps are always available.** Traffic is dense enough to require a look and
  never so dense that waiting exceeds ~8 seconds. A player who never learns to
  read it still gets across; they just get shoved more.

This is the fidget doctrine from `PROP_ACTIVITIES.md` applied to a street:
*would you do it twice, for no reward?* Crossing a live road is one of the few
motions that passes that test on its own.

---

## 3. The traffic

**95% credible, 5% wrong, and the wrong is never acknowledged.**

Absurd traffic is charming for ten seconds and then it is a joke that keeps
talking, and the haunting has to compete with it. The street's job is to be
*credible enough that the building's wrongness lands*. Ordinary decay outranks
spectacle (Accord 9) applies to vehicles too.

**The ordinary stream** — drays and horse carts, a delivery lorry, a coal truck,
a tram on rails, a hearse, a milk float, bicycles, a hand-pushed barrow. Period
1928, second-hand, and mostly slow. Slow traffic is more readable and more
crossable than fast, and it is also cheaper.

**The wrong 5%**, seasoned in and never remarked on by anyone:

- the same vehicle passing a third time, with the same load
- a tram on a street with no rails in it
- a dray whose horse is not there, still moving at the horse's pace
- a vehicle that arrives before the sound of it does
- something far too large for the road, which nonetheless fits

Residents never comment. A resident waiting at the kerb with their back to it is
worth more than any effect.

**Sound is the tell.** A player should be able to cross by ear alone with the
camera facing the door they are about to open. That is what makes it a texture
rather than a minigame — it can be done without looking.

---

## 4. The ends of the street

The owner's proposal: a tear in the universe at either end, swirling, lightning,
debris, never explained.

**The intent is right and the volume is the risk.** A visible impossible thing
that nobody reacts to is a strong statement of the world's rules, and it answers
the question an endless street would otherwise keep asking. But it would also be
the loudest object in the game, sitting on the first street the player walks
down, in a game whose best trick is refusing to point at anything. The Orison is
forty years early and never mentions it; that quiet is the asset a screaming
portal spends.

**Recommended: commit to the tear, and stage the indifference.**

- It is **weather**, not an event. No stinger, no camera move, no dialogue.
- The residents' non-reaction is authored, not implied: someone waits at the
  kerb near it, bored, back turned, checking a watch.
- **It is the boundary.** The street stops having edges and starts having ends —
  the lateral stage collision retires into it, and walking toward it is walking
  toward weather that gets worse until you turn around.
- Debris that comes out of it lands on the road and stays. The street should
  accumulate.

If it proves too loud in the frame, the fallback is subtraction, not
redesign: haze that the eye slides off, weather wrong only down there, sound
arriving before its source.

---

## 5. The first minute

The arrival car comes back, **moving**. The player gets out at the kerb, it
pulls away east and into the tear, and nothing comments. That is a better
introduction to the street's rules than finding the same car parked outside the
door forever, and it removes the game's most conspicuous piece of standing
scenery.

---

## 6. The bus shelter

Saved, not scrapped: 4.4 × 1.4 m, 2.45 m roof, glazed back with a centre
mullion, timber bench. It last stood on the south walk at (−12.6, −25.55).

It should return **at a stop the new traffic actually serves** — which means it
is placed after the tram or bus route exists, not before. A shelter for a
service that does not run is set dressing; a shelter with a resident waiting
under it, for something that does arrive, is the cheapest character moment on
the block.

### As built — T5 closed 2026-08-14

The shelter is back at its saved south-walk origin and ruled envelope: x
−12.60..−8.20, y −26.95..−25.55, roof z 2.45 m. Its glazed back, centre
mullion and timber bench survive. Both pedestrian routes survive too: **1.66 m
clear at the kerb and 1.37 m clear behind the glass**, each proven with the
production player capsule.

The first proof render caught a defect in the deleted asset rather than hiding
it: the two records named `post` were 0.10 × 1.30 m solid fins, so both ends
read as the same unexplained black slabs Check 2 removed. They are now literal
0.10 × 0.10 m rear corner posts. The shelter owns four bounded
`transit_shelter` material buffers instead of joining F01's block-wide
furniture batches; painted cast iron and dull zinc replace near-mirror generic
metal. This is truthful ownership and a local light-selection AABB, not an
unshaded beauty override. A small **CARS STOP HERE** enamel board makes the
stop legible at night and adds no realtime light.

The service is executable. Only an eastbound `tram` stops, once, with its
centre at x −10.40, emits `transit_arrived("south_shelter", "tram")`, dwells
4.5 seconds, and resumes east while preserving the unused frame delta.
Westbound trams and all non-tram traffic pass through. Under the physical roof,
close rain and spatter suppress while middle-distance rain remains visible;
leaving the footprint restores the exposed weather.

At canonical-night street elevation, the paired shelter-visible/control run
was **29.98 / 29.98 ms**. A repeat reversed inside live-scene noise at
30.02 / 30.46 ms. The exact visual delta is five owners and 14 submissions
(four local material buffers plus the in-world sign); there is no measurable
frame-time regression. `TransitShelterTest` passes 20/20. Containment, final
route, weather/sky, lighting, Passage visibility/ownership and WalkTest FULL
at x8 / 480 Hz all pass. Fixed day/night proof frames are under
`art/renders/transit_shelter_t5/approved/`.

T2d remains honest: the instanced traffic silhouettes are still under-read at
night. T5 proves a real served stop and readable shelter architecture; it does
not quietly claim to have completed the separate traffic-fidelity work.

---

## 7. Budget, before anything is built

Street elevation is the second-worst station in the game: **33.28 ms against a
16.6 ms target**, and the frame is CPU-bound on submission, not GPU work
(`TASKS.md` P2). Decomposed at that station:

| toggle | frame | objects |
|---|---|---|
| baseline | 33.28 ms | 14,081 |
| all illumination hidden | **−33%** | 7,872 |
| all props hidden | −28% | 9,106 |
| all geometry `cast_shadow` off | −24% | 5,594 |
| props culled past 12 m | −16% | 11,499 |
| every prop batched | ~0% | 12,620 |

Two things follow. **Lighting is the dominant term outdoors** — twice what it is
in the atrium — so the traffic's headlamps and the tear's lightning are the
expensive part, not the vehicles. And **batching is worthless here**, so the
traffic must be instanced from the start for reasons of submission count, not
draw calls.

Removing the parked cars has already bought some of this back. The budget for
the moving stream should be set from a measurement, not spent and then measured.

---

## 8. Open questions for the owner

1. **Does the tear stay loud?** §4 recommends yes, with staged indifference.
2. **Does anything come out of it besides traffic?** Debris is proposed. Weather
   is proposed. A person is not — that is a much bigger ruling.
3. **Is the tram on rails?** Rails in the road are a strong period read and a
   permanent piece of geometry down the middle of the frogger lane.
4. **Does traffic stop at night?** A street that empties gives the building's
   nights their silence back; a street that never stops is more oppressive.
   Either is defensible and they are very different games at 3 a.m.
