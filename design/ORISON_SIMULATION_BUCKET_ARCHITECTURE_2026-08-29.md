# Simulation buckets — architecture ruling, 2026-08-29

Owner direction: bucket each shop interior, designing for eventual full
simulation. The goal is not a game but a complex system the player can
interact with in as many ways and with as many consequences as we can
implement without melting the GPU.

Work order, not proof — named so the completeness ledger refuses it.

## The ruling: two ladders, not one

The brief's performance cells answer *what is drawn*. They are the
wrong unit for *what is happening*. Bucket both, separately, because
their costs run in opposite directions:

- **Rendering** is expensive and the measured bottleneck is draw-call
  submission, not fill or lighting. Few interiors may be resident.
- **Simulation** is cheap. A shop advancing stock, staffing, hours,
  temperature and tenancy costs a few floats per simulated minute.
  Fifty buckets at low fidelity cost less than one rendered aisle.

Therefore: **simulate everything, render almost nothing.** A shop is
not "a facade" or "an interior" — it is a bucket with a simulation
tier and, independently, a rendering tier.

## The simulation fidelity ladder

Every bucket sits at one of four tiers, and may move between them at
any time without losing or inventing state.

**S0 DORMANT** — nothing advances. The bucket holds durable facts and
the simulation minute at which they were last true.
**S1 STATISTICAL** — aggregate advance on wake or on tick: stock
depletes by rate, dust accumulates, a shift is worked, a delivery
arrives. No individual agents.
**S2 SCHEDULED** — named agents keep their timetable and discrete
events fire (the clerk opens, a resident's 13:30 errand happens, the
cooler's compressor fails). Still no bodies, physics or animation.
**S3 EMBODIED** — actual bodies, collision, animation, interaction
surfaces. Only where the player is, or is about to be.

**The transition rule is absolute: promotion and demotion must be
lossless and deterministic.** A bucket returning from S0 to S3 must
arrive at exactly the state it would have held had it run at S3
throughout. That means every tier writes the same durable facts and
every advance is a pure function of `(facts, elapsed simulation
minutes)`.

We have already built and proven this primitive. **PorterActor**
forms an intention, becomes eligible, travels off-screen, can be
blocked, and applies its consequence — entirely from durable
timestamps, with `advance_to(now)` as pure catch-up. It survives save,
load, scene unload and room rebuild without pausing, repeating or
accelerating. That is an S1/S2 bucket in everything but name, and it
is the template.

## Facades are simulated shops rendered cheaply

This is the consequence that makes the whole design scale, and it
should be understood as a promise rather than a compromise.

The locksmith you cannot enter still has stock, a proprietor with a
timetable, an hours schedule, a tenancy history and a maintenance
state. That simulation is already visible without an interior:

- lights that match whether anyone is actually working
- a shutter that is down because the proprietor is at the hospital,
  not because it is Tuesday
- a window display that changed because stock changed
- a CLOSED sign that means something specific
- a proprietor you meet somewhere else, because he is not here

"Eventually full simulation" therefore is not a rewrite. It is
promoting one bucket's **rendering** tier while its simulation tier
never changes. The interior we add later is a window onto a system
that was already running.

## Where the consequences come from: flows between buckets

Emergence lives in the edges, not the nodes. The fiction has already
authored several, unknowingly:

- Thirteen-plus resident errands per day already target the bodega.
  Stock depletion is therefore not invented — it is the sum of an
  existing timetable.
- One resident uses "the bodega only for the two items it reliably
  stocks," and "substitution is chaos." **If the player buys the last
  of one of those two items, that resident's day breaks** — and the
  break is legible, because her character already tells us it would
  be.
- Another "records the cooler hum" at 03:30. If the compressor fails
  in the simulation, her recording changes, and a maintenance job
  exists that nobody has reported yet.
- One resident *never* uses the bodega. That is a fact with a reason,
  and reasons are consequence surfaces.

The building's existing systems are the other half of the graph: heat,
power, water, the acoustic network, work orders, the observation
ledger. A shop is a customer of the building, not a diorama beside it.

## Two disciplines that keep this from exploding

**1. Every simulated quantity needs a sensory tell.** Simulation that
nobody can perceive is CPU spent on nothing. Before adding a
simulated variable, name how the player could ever notice it — a shelf
gap, a handwritten card, an apology, a smell, a sound, a neighbour's
complaint, a price change. No tell, no variable.

**2. The ethos law already governs this, and it is the reason this can
scale.** Consequences must be concrete facts with one owner; no
coordinator may fabricate what an NPC knows; no timer may impersonate
an actor; custody belongs to the inventory authority. Those rules are
not bureaucracy — they are exactly what lets a bucket run at S0 for a
week and still be trusted at S3. The systemic-authority audit already
fails a build that violates them, so the machinery that keeps a large
simulation honest is in place before the simulation is.

## Bucket contract (what every shop must declare)

```
id, boundary, simulation_tier, rendering_tier
durable_facts        - stock, staffing, hours, condition, tenancy, cash
last_simulated_minute
advance(facts, elapsed_minutes) -> facts      # pure, deterministic
inputs               - deliveries, resident demand, power, heat, weather
outputs              - what leaves: purchases, knowledge, jobs, residue
interaction_surface  - what the player may do, and each consequence
sensory_tells        - how each simulated quantity becomes perceptible
render_representation- facade / window-parallax / partial / full interior
```

## Consequences for the bodega build

The first interior must be authored as a bucket:

1. Its durable facts and `advance()` are written **before** its
   geometry, so the shop exists as a system that is briefly rendered
   rather than a room that later grows behaviour.
2. Its stock is driven by the existing resident timetable, not by an
   invented restock loop.
3. The notions counter's parts flow through the inventory authority —
   the same one that owns the radiator packing — so a purchase is one
   fact with one owner.
4. Every other shop on the street and in the passage gets a bucket at
   S1 on the same day, rendered as facade. They cost almost nothing
   and they make the street behave like a neighbourhood immediately.
5. The impossible back-room link is itself a bucket input: what passes
   through it, and what notices.
