# THE BUILDING GETS DIRTY — dynamic degradation and the mop

**PROPOSAL — OWNER REVIEW REQUIRED — NOT YET BINDING CANON.**
*Owner direction 2026-08-16, recorded verbatim as the design's north star:*

> "What if we dynamically created grime and damage, with decals, that you
> could clean with a mop, same with states of simple repair — grime on the
> ground, litter, lights burn out randomly, damage to walls and floor,
> toilets need to be unclogged, sinks leak, all appliances needing simple
> repair. Any simple two-state visual way we can degrade the building that
> a maintenance worker would need to address. I want it to seem like a
> Sisyphean task but you get immediate visual feedback from your efforts."

> "Like we remove the current decal spread so we have a pristine, like-new
> version, then we simulate the action of our residents and apply damage
> dynamically to give us things to do."

**That second paragraph is the actual architecture, and it is a much
stronger idea than a cleanable-dirt feature.** It says the building's
condition should not be authored at all: it should be the *output* of the
lives being lived in it. Every mark has a cause, and the cause is
somebody. See §3.

---

## 1. Why this game in particular

Most games bolt a chore system onto a protagonist who has no reason to
care. This one already cast the player as **the night-shift maintenance
tenant of a building that is quietly failing**, gave them a work-order
device they carry in the hand, a hardware shop that sells parts, and a
loop that runs *problem → errand → repair → conversation*. The entropy
system is not a new pillar. It is the ambient substrate the existing
pillar was always standing on — and without it the building only breaks
in the eleven places a designer authored.

The thesis in one sentence: **the Orison should be dirty in a way that
answers to your hands.**

## 2. The Sisyphean contract

The feeling the owner named has a precise shape, and getting it wrong in
either direction kills it:

- **Too fast** and it is demoralising. A player who mops a corridor and
  watches it re-soil before they reach the stairs stops mopping forever.
- **Too slow** and it is a checklist. Once the building can be finished,
  it is furniture.

The resolution is not a rate. It is a **scope split**:

> **Local victory is always available. Global victory is never.**

Any single room, fixture or fitting can be brought to *perfect* by a
player who chooses to, and it will stay perfect long enough to be
admired, revisited, and felt. The **building** cannot — because it is
eight floors, a street, a basement, an arcade and a bar, and entropy runs
everywhere at once while the player works in one place. Sisyphus does not
suffer because the boulder is heavy. He suffers because there is only one
of him and the hill is always there.

Three rules protect the feeling:

1. **The mop stroke pays instantly.** No timers, no "cleaning…" bar, no
   deferred state. Contact changes the world in the same frame. This is
   the single most important requirement in the document.
2. **Nothing the player fixed degrades again while they can still see
   it.** Re-soiling happens across a scene boundary, a shift, or a sleep
   — never in view. A stain that returns while watched is a bug in the
   fiction, not tension.
3. **Every degradation is legible before it is reachable.** The player
   should notice the burnt bulb from the far end of the corridor.

## 3. Strip the authored wear; let the residents make it

This is the load-bearing decision, and it inverts how the building is
currently dressed.

**Today, wear is authored.** `build_orison.py`'s `build_wear_decals()`
bakes traffic marks into the glTF at design time, and
`AtmosphericDecalPass` places domestic and institutional residue at
runtime from rules and unit hashes. Both are good work and both say the
same thing: *a designer decided this floor looks used.*

**Proposed: the building ships as clean as it ever gets, and every mark
after that is produced by the simulation.** The Orison already runs
eighteen residents with authored routines, schedules, navigation and
per-unit life profiles — 240 sockets across 18 profiled units. That
system already knows who goes where, when, and how often. It is one step
from also knowing what that costs the floor.

The payoff is not tidiness. It is that **the building's condition becomes
readable evidence**:

- The stair everyone actually uses wears; the one nobody does stays
  clean, and the player can *see* which is which.
- The corridor outside a resident who is struggling looks different from
  one outside a resident who is not — without anybody authoring a
  "struggling corridor" decal.
- The laundry is filthy because the laundry is *used*, and if the player
  keeps it clean the building tells the truth about that too.
- A case that changes a resident's behaviour changes their wear. Nobody
  has to write that down; it falls out.

### "Pristine" does not mean "new"

An important correction to the word, so nobody strips the wrong thing.
The Orison was built in **1912**, partly demolished in 1927 and reopened
in **1928**. The building is sixteen years old at game start and was
never new during the game. So the baseline is not a showroom — it is
**inherited patina**: the marble tread dished by a decade of feet, the
brass rail polished to gold at hand height, the wallpaper faded away from
the window. That is *architecture*, it pre-dates the player, and it stays
baked.

What gets stripped is **accrued grime**: the layer a maintenance worker
would recognise as *this week's*. The test for which pile a mark belongs
in is simple:

> Could a person with a mop, a bulb and an afternoon undo it?
> If yes, the simulation should be making it. If no, it is architecture.

### Burn-in: generate the past with the same machine

Day one must not look sterile. Rather than authoring a starting mess,
**run the simulation forward before the player arrives** — some weeks of
resident traffic with no maintenance worker in the building — and use its
output as the opening state. One machine produces both the history and
the present, so the building on day one is already lived-in and every
mark on it still has a cause. It also gives a free difficulty dial: how
long the building has gone unattended before you took the job.

### Keep it coarse, or it will cost the frame

The simulation must be an **accumulation model, not a footstep model**.
Residents tick counters on authored anchors as they pass — corridor
segments, thresholds, fixtures, appliances — and a mark appears when a
counter crosses a threshold. Nothing spawns per footfall, nothing
raycasts per step, and the whole thing can advance per shift rather than
per frame. The existing schedule already runs at that granularity; the
wear model should ride it rather than add a second clock.

## 4. What degrades

All two-state or few-state, all restorable, all visible. Grouped by the
verb that answers them, because the verb set is the real budget:

| Verb | Degradation | Restored state | Consumable? |
|---|---|---|---|
| **MOP** | floor grime, spills, tracked-in wet, soot films | clean floor | bucket refill |
| **SWEEP / BIN** | litter, cigarette ends, broken glass, leaves | clear floor | none |
| **REPLACE** | burnt-out bulbs (flicker → dead) | lit fixture | bulb stock |
| **PATCH** | wall scuffs, gouges, chipped plaster, peeled paper | repaired wall | filler / paint |
| **PLUNGE** | clogged WC | draining WC | none (tool) |
| **TIGHTEN / WASHER** | dripping tap, weeping trap, radiator bleed | dry, quiet | washers |
| **UNJAM / RESEAT** | appliance faults — a stuck sash, a dead ring, a jammed hopper | working | occasional part |
| **WIPE** | mirror haze, greasy switch plates, fogged glass | clean | cloth |

Every one is a two-state visual at minimum; the richer ones earn three
(clean → soiled → filthy) so effort has gradient. Nothing here needs a
new interaction grammar: the project already has an inspect/interact ray,
a carried device, a consumable inventory and a shop that sells parts.

## 5. The technical spine — and the one thing that will kill it

**Do not build this out of one node per stain.** The frame is
submission-bound, not fill-bound (measured: identical frame time at 720p,
1080p and 1440p). A building-wide dynamic decal system authored as one
`MeshInstance3D` per patch is hundreds of new draw calls in the exact
currency this game is poorest in, and it will be beautiful in a test
scene and unshippable in the building.

**The correct shape, with precedent already in the repo:**

- **One `MultiMeshInstance3D` per (surface class × floor)** — grime,
  litter, wall damage — with per-instance transforms switched on and off.
  PS6's after-hours grilles already do exactly this: **1360 instances in
  a bounded number of draws**, toggled by state, zone-owned and
  perf-proven. That is the template. Cleaning a patch sets an instance's
  scale to zero (or moves it to a parked transform); it does not free a
  node.
- **The look is already solved.** `story_decal.gd` is the proven surface
  recipe: an atlas region cached to an `ImageTexture`, a `QuadMesh`,
  `TRANSPARENCY_ALPHA_SCISSOR` at 0.08 (cheap, no sort order cost),
  roughness 0.84, `cull_mode` disabled, shadows off. Reuse the atlas
  discipline (`atmospheric_decals/`) rather than inventing a second one.
- **Godot's `Decal` node is NOT the mechanism** — this project renders on
  `gl_compatibility`, `AtmosphericDecalPass` conspicuously uses quads
  despite its name, and nothing in the codebase instances a `Decal`.
  **Verify before relying on either answer**: this repo has already been
  bitten by a documented engine limitation that had quietly become false
  (the `light_projector` correction of 2026-08-08), and the standing rule
  from that episode is that an engine limitation is a claim with a date
  on it. Re-test, then write down what you found.
- **Persistence must be compact.** `RealityState` saves to real JSON, and
  a per-stain transform list will bloat it. Store degradation as **state
  per authored anchor** — an id and a small integer — and let the builder
  reconstruct the visuals deterministically from a seed, exactly as the
  dream maze reconstructs from `seed_hex`. Never serialise a chase frame;
  never serialise a stain's world matrix.
- **Lights are already half-built.** `PROP_ACTIVITIES.md` notes burnt-out
  fixtures reduce the live light count, and the switch system, LightRig
  ranking and per-fixture flicker profiles all exist. A dead bulb is a
  state on an existing owner, not a new object — and it is
  performance-*positive*, which makes it the cheapest possible first
  slice.

## 6. What this must not do to the core loop

The authored maintenance job (`MaintenanceJobLibrary`, WorkOrders, one
job per case) is the **spine**. Ambient chores are the **weather**. The
distinction has to be enforced in code, not just intended:

- Ambient chores **never** advance a case, never issue a work order,
  never satisfy a job stage, and never appear on the ORDER device as
  case work.
- Authored jobs are always singular, named, and consequential; chores are
  always plural, anonymous, and optional.
- If a chore ever becomes required to progress, it has stopped being
  weather and must be promoted to an authored job with a data record.

The player should be able to ignore the entire system for a whole
campaign and lose nothing but the building's dignity — which is itself
the point, and should be *noticed* by residents rather than scored.

## 7. The Orison thread, held back

The horror is not the mechanic. Restraint, and only after the honest
system is loved:

- A stain that returns in the same shape after being cleaned three times.
- One bulb on a landing that burns out only when nobody is on the stair.
- A room that is already clean when the player arrives to clean it.
- The mop bucket's water darker than the floor accounted for.

None of these ship in the first slice. All of them are free once the
substrate exists, which is the argument for building the substrate
honestly first.

## 8. Minimum provable slice

Following the arcade's V1 discipline — one vertical slice, fully proven,
before any breadth:

**One corridor. One grime type. One mop. One bulb.**

1. F01 corridor authors N grime anchors, seeded and deterministic.
2. One `MultiMeshInstance3D` carries them; the count is measured and the
   corridor's perf station is re-run against its recorded number.
3. The mop is a carryable with a contact verb; a stroke clears the
   nearest instance **in the same frame**.
4. One corridor fixture can burn out and be replaced from stock bought at
   HARDWARE PAINT — closing the loop through the existing errand system.
5. All of it survives save/load through the real file.
6. Re-soiling happens only across a sleep boundary, never in view.

If that slice is not satisfying, no amount of breadth will save it.

## 9. Open rulings for the owner

1. **Does dirt have opinions?** Should degradation cluster where the
   fiction says it should (the bar after a night, the laundry, the stair
   everyone uses) or spread evenly? Clustering is better drama and more
   work.
2. **Do residents react?** A visibly maintained floor changing what
   people say is the cheapest possible reward and the strongest — but it
   touches the case/dialogue systems, which are spine.
3. **Is there a score?** **RULED 2026-08-16: NO.** No percentage, no
   meter, no completion figure, anywhere — HUD, ORDER device or menu. The
   building's condition is legible only by *looking at it*. A number
   would convert a building you are caring for into a task you are
   failing; it would advertise a global victory that §2 exists to deny;
   and it would replace the evidence-reading this whole system is built
   to create with a glance at the corner of the screen. Residents
   noticing remains open (ruling 2); arithmetic does not.
4. **How far does "appliance repair" go?** There is a real risk of
   sprawl. Recommend a fixed verb set (§3) that all appliances map into,
   rather than bespoke minigames per device.
5. **Night shift only, or always?** Degradation advancing per *shift*
   rather than per *hour* fits the loop already ruled.
