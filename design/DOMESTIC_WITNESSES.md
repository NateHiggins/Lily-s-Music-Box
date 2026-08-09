# Domestic Witnesses

Every inhabited apartment has one clock. It is the same gameplay object but
not the same possession: each clock borrows a recognizable domestic design
language and restates its resident's unresolved problem through timekeeping.

Each of the building's 17 occupied physical apartments also gets one other
domestic anomaly archetype. These are distributed rather than repeated so an
apartment develops its own visual grammar and the player cannot reduce the
system to "watch the clocks." Unit 4C's door chain is shared by Cam and Noel
and performs a different movement for each case.

The clocks are deliberately *not* generically haunted antiques. They look selected,
inherited, repaired, or bought by the people who live with them. References
include schoolhouse and railway clocks, Bauhaus geometry, Streamline Moderne,
1920s sunrays, restrained industrial design, studio timers and Art Deco mantel
pieces. Juno's Vantry modular clock, Cal's split-flap receiver and Sacha's
Nixie display are the exceptions licensed by the Rule of Signal: they
synchronise or display information and stop at the 1967 ceiling. Malcolm's
mechanical sunray and 4D's folding travelling alarm carry no signal and remain
period-correct, second-hand 1927 objects. These are influences rather than
replicas of branded products.

## Horror contract

- Tier 1 is deniable: a tick doubles, a hand loses one minute, or a marker
  appears where the player cannot swear it was absent.
- Tier 2 repeats the resident's personal tell and establishes a pattern.
- Tier 3 stages the wound: checkout approaches, a recording runs behind,
  a level clock tilts with the room, or two incompatible times coexist.
- Tier 4 may move while watched. Earlier tiers prefer changes outside the
  camera and use sound alone if directly observed.
- Every event restores. The clock leaves no forensic proof, only memory.

## Character mapping

| Resident | Design | Possession |
|---|---|---|
| Evelyn | schoolhouse | corrects time backward |
| Teresa | institutional hospital | returns to the fatal call time |
| Mina | Bauhaus annotation clock | labels the present `YOU: NOW` |
| Lena | stitched textile clock | second hand comes visibly loose |
| Juno | Vantry modular signal clock | skips and repeats a sampled tick |
| Malcolm | 1920s mechanical sunray | preserves the last minute |
| Omar | industrial service clock | develops a new visible fault |
| Rhea | studio timer | plays its own ticking back wrong |
| Peter | railway office clock | remains permanently pending |
| Cam | courier/bicycle clock | becomes a spirit level for the room |
| Noel | protected mantel clock | turns its untouched face away |
| Guests | 1927 folding travelling alarm | advances to checkout, never beyond it |
| Nadia | architectural clock | tilts toward an impossible exit |
| Cal | broadcast-synchronised split-flap | receives a previous moment |
| Iris | painter's palette clock | subtly performs for an audience |
| Sacha | Vantry Nixie evidence timer | displays a seven-second delay |
| Jonah | writer's clock | loses the end of its time |
| Mae | Art Deco heirloom | displays two valid histories |

## Additional apartment distribution

| Unit | Object | Deniable behavior |
|---|---|---|
| 1A | mirror | reflection shifts slightly late |
| 1D | Vantry listening point | mechanical telltale holds its breath with Teresa |
| 2A | intercom | receives an unlisted internal call |
| 2B | coat hook | gains one hook after the player looks away |
| 2C | smart speaker | repeats a voice it was never taught |
| 3A | houseplant | all leaves turn to listen |
| 3B | power outlet | displays an impossible live condition |
| 3D | telephone | handset lifts onto an open line |
| 4A | thermostat | refuses a temperature change as `DENIED` |
| 4C | door chain | leans with Cam or seals itself for Noel |
| 4D | luggage scale | weighs departure as infinity |
| 5A | spirit level | insists a crooked wall is level |
| 5B | table radio | tunes to the previous room |
| 5C | picture frame | subject changes pose between glances |
| 6A | security camera | follows seven seconds after movement |
| 6B | typewriter | finishes a sentence Jonah did not write |
| 6C | key bowl | contains one extra, familiar key |

## Implementation

`DomesticWitnessSystem` reads `domestic_witness_clocks.json` and
`domestic_anomaly_props.json`, finds each resident's living-room bounds, and
places both layers through `WallArtLaw`. Wall clocks reserve a real hook before
resident art is hung; Noel's mantel clock and the Guests' travelling alarm
reserve a real furniture surface. The two 4C clocks therefore share one wall
budget without occupying one another or a later photograph.
It subscribes to `SanityDirector.intruded`; the emitted case ID selects exactly
one clock and the escalation tier controls intensity. Each clock is a
`FunctionalProp`, so existing gaze raycasts and conductor timing can perceive
and affect it without another attention system.

The mesh is procedural and inexpensive. Static housing uses primitives while
the face, hour, minute and second hands remain separate transform rigs. A small
wall collision shape makes the object inspectable. No skeletal animation,
physics body, cloth simulation, unique texture set, or dynamic light is used.

Debug forcing follows the existing case controls: forcing any sanity rung in
the building debugger also triggers that resident's clock. Code can isolate it
with:

```gdscript
building_root.domestic_witnesses.force("mina_caption_crisis", 3)
```
