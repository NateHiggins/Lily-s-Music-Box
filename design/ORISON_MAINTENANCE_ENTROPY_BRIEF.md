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

## 6. Residents file the work orders — and personality decides who

**Owner ruling 2026-08-16, and it supersedes this section's first
draft.** The original said ambient chores must never issue a work order.
That was too clean. What actually happens in a building is that *people
complain*, and the ruling is that **residents react to the building's
condition by filing work orders, filtered through personality**.

This is a better design than either extreme, because it makes the
degradation system speak in the game's existing voice — the ORDER device
the player already carries — without collapsing chores into cases.

### Two classes of work order, one lifecycle

`WorkOrders` already owns a full lifecycle (issued → acknowledged →
diagnosed → awaiting part → repairable → repaired → closed). Ambient
orders live in exactly that lifecycle and are real work. What separates
them from the spine is **binding, not mechanism**:

| | authored case job | resident-filed ambient order |
|---|---|---|
| origin | `MaintenanceJobLibrary` data record | a resident reacting to observed condition |
| bound to | a case, a resident, a dream window | a place and a fault |
| on completion | may advance the case, earn a conversation | closes; the building improves; nothing else |
| if ignored | the campaign waits | the building degrades and residents escalate |
| count | one at a time, named | many, plural, ordinary |

The hard line stays where it matters: **an ambient order never advances a
case, never satisfies an authored job stage, and never gates progress.**
If one ever becomes required, it gets promoted to an authored job with a
data record. But it may absolutely appear on the ORDER device, be
acknowledged, be closed, and be *how the player learns what the building
needs*.

### Personality is the filter, and it is free characterisation

Eighteen residents already carry identities, routines and life profiles.
Who files, how fast, about what, and in what words is the cheapest
characterisation this project will ever get — it costs a few fields per
resident and it makes the inbox itself a portrait:

- **The fastidious one** files about a scuff on the landing within a day,
  in complete sentences, and files again when it is not done.
- **The stoic one** does not file at all until the radiator is stone cold
  in February, and then apologises for the trouble.
- **The furious one** files immediately, in capitals, about the wrong
  fault.
- **The frightened one** files about the noise but not about the door.
- **The invisible one** never files, and the player only finds out how
  bad it got by going up there — which is a whole story told by an
  *absence* of work orders.

Two consequences worth designing to. First, the **inbox becomes a
diagnostic instrument for the residents, not just the building**: a
sudden first-ever order from someone who never complains is alarming.
Second, the same fault reported by different people is a different
sentence, so the player learns the house by reading its mail.

The player can still ignore the entire system for a campaign and lose
nothing but the building's dignity — and now also the residents' patience,
which is the correct currency for it.

## 7. Purgatory, and Murphy's Law as a director

**Owner ruling 2026-08-16:** *"This is purgatory. Apply Murphy's law and
make it part of the horror."*

This promotes the entropy system from a chore layer to **a horror
system**, and it resolves §2's Sisyphean question at the level of
metaphysics rather than tuning. The building never comes right because
*that is the condition of the place*, not because a designer picked a
decay rate. Sisyphus is not badly balanced. He is in the correct
location.

### The simulation loads the gun; the director fires it

The other half of the ruling — *"when this happens is a gameplay
decision"* — is the safeguard, and it gives the architecture its shape:

> **Wear accumulates by simulation. Failure is timed by a director.**

The resident-traffic model (§3) decides *what is eligible* to fail and
how close it is. It never decides *when*. A separate owner — the same
kind of thing as the existing sleep-pressure and dream directors —
chooses the moment to cash an eligible fault in, and chooses it for
dramatic effect.

That single split buys everything:

- Pure simulation is frustrating and arbitrary; pure scripting is
  predictable. This is neither.
- Failures land where they mean something, and the player can *feel* the
  timing, which is the horror.
- It is tunable without touching the wear model.

### Murphy's Law, written as a design rule

Anything that can go wrong will — **at the moment it costs most**:

- The stairwell bulb dies as you start down, not while you are standing
  under it with a spare in your hand.
- The boiler fails on the coldest authored night, and the residents who
  file about it are the ones you have not met.
- The lift goes out while you are carrying the crate up (PS5 already
  makes carrying the hard leg of an errand).
- The WC clogs during the resident's worst hour, so the fault and the
  crisis arrive as one knock.
- The part you need is the one HARDWARE PAINT is out of, and the shop
  closes at 02:00 — which the hours system already enforces.

**The discipline that keeps this from becoming punishment:** Murphy's Law
must be *dramatically* timed, never *punitively* timed. The test for any
instance is whether it makes a better story or merely a longer walk. It
must never invalidate committed work, never undo a repair the player has
already made, and never fire during a protected interaction — the
`call_locked` flag and the dream boundary already define those windows
and it must respect them exactly as sleep onset does.

### Three appliance states, not two

**Owner ruling:** appliances are **working → functional but failing →
dead**. The middle state is the whole point: it is the warning, the thing
a maintenance worker is supposed to catch, and the thing Murphy's Law
gets to punish you for ignoring. A radiator that knocks before it dies is
a fair building. One that simply dies is a cruel one — and the fairness
bar the maze brief already sets ("the player understands in the
half-second before impact") applies here in slow motion.

It also means neglect is legible as *sound and behaviour* before it is
legible as failure, which is free horror: the building complains for
weeks before it stops.

### The uncanny layer, still held back

Restraint, and only after the honest system is loved:

- A stain that returns in the same shape after being cleaned three times.
- One bulb on a landing that burns out only when nobody is on the stair.
- A room that is already clean when the player arrives to clean it.
- The mop bucket's water darker than the floor accounted for.
- A work order filed by a resident for a fault that has not happened yet.

None of these ship in the first slice. All of them are nearly free once
the substrate exists, which is the argument for building the substrate
honestly first — and note that the last one only became possible because
residents file orders (§6). The systems compound.

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

1. **Does dirt have opinions?** **RULED 2026-08-16: BOTH LAYERS.**
   A general grime accrues everywhere — the honest baseline of a working
   building — *and* it clusters where the fiction says it should: the bar
   after a night, the laundry, the stair everyone actually uses. Two
   layers, not a choice between them. The ambient layer means no surface
   is ever exempt and the mop always has somewhere to go; the clustered
   layer is where the drama and the evidence-reading live (§3). In
   MultiMesh terms these are separate instance sets with separate
   thresholds, so the ambient one can be coarse and cheap while the hot
   spots carry the detail.
2. **Do residents react?** **RULED 2026-08-16: YES, BY FILING WORK
   ORDERS, FILTERED THROUGH PERSONALITY.** See §6, which was rewritten
   around this — it is the ruling that gives the whole system a voice in
   the game's existing interface instead of a new one.
3. **Is there a score?** **RULED 2026-08-16: NO.** No percentage, no
   meter, no completion figure, anywhere — HUD, ORDER device or menu. The
   building's condition is legible only by *looking at it*. A number
   would convert a building you are caring for into a task you are
   failing; it would advertise a global victory that §2 exists to deny;
   and it would replace the evidence-reading this whole system is built
   to create with a glance at the corner of the screen. Residents
   noticing remains open (ruling 2); arithmetic does not.
4. **How far does "appliance repair" go?** **RULED 2026-08-16: THREE
   STATES — working, functional but failing, dead** (§7). Every appliance
   maps into the fixed verb set of §4; no bespoke minigame per device.
   The middle state is the design's warning shot and the thing Murphy's
   Law is allowed to punish you for ignoring.
5. **Night shift only, or always?** Degradation advancing per *shift*
   rather than per *hour* fits the loop already ruled.
