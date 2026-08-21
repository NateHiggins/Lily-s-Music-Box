# ORISON COMMENSALS — WAKING-WORLD VERMIN, BIRDS AND INVASIVE FLORA

**RULED FOR BOUNDED C1 PRODUCTION — 2026-08-20.** This is the waking-world
sibling of dream fauna. The owner approved the seven-part adversarial package
recorded in §10, including the C1-without-generator correction. Later breadth
remains gated exactly as stated.
Research citations and repository observations in the source advisory were
made against `d15a48f` and must be refreshed before implementation.

## 0. Current state

No vermin, bird, pest or weed system currently exists in `game/` or `design/`.
The only nearby flavor is “moth holes” in `RETAIL_TEXTURE_PROMPTS.md`. Today a
scratch in the wall reads unambiguously as haunting; ordinary animal life would
give the player the mundane explanation the Both True engine needs.

## 1. Thesis — the building's other tenants

At canonical 03:00 the residents sleep and the building's other shift comes
out. A 1928 Queens apartment block has mice in walls, roaches at kitchen
skirting, pigeons on cornices and ailanthus in the areaway. This is Accord 9
(ordinary decay outranks spectacle) and Accord 14's evidence of use, age,
maintenance and consequence given a living layer. Life is positional: food,
damp and neglect determine placement, so it reads as evidence rather than
decoration.

The horror benefit is structural. TASKS §X1 begins with an anomaly small enough
to dismiss, but the building currently supplies nothing to dismiss it as.
Mice-in-the-walls become the mundane scapegoat, using the same acoustic graph
that carries the Tenant without ever becoming a haunting owner.

## 2. Five laws

### L1 — Canon and evidence first

Nothing here carries signal. Everything is ordinary, period and second-hand.
Every species needs a Harukiya-accord filing: CANONICAL, INFERRED, ADAPTATION or
NECESSITY. Proposed cast: Norway rats, house mice, German roaches, basement
waterbugs, rock pigeons, house sparrows, lamp and clothes moths, silverfish,
flies, ailanthus, plantain, dandelion, mugwort and moss on damp north courses.
The druggist and HARDWARE PAINT may stock period countermeasures only in C3.

### L2 — Sell by ear first

The waking frame has little headroom. T7 closed the street at 15.718 ms with
0.88 ms spare; the atrium remains roughly 41 ms over budget; roof cost is
tick-dominated. Cost order is mandatory: audio, static batches, instanced
motion, then rare scheduled hero events. Contracts:

- STREET: at most +3 draws and +0.3 ms, re-proven through `WeatherPerf`.
- Interiors: per-floor gated; the atrium eye collects no off-floor work.
- Roof: hard-gated instances and director work.
- One measured low-Hz director; no particles, per-creature nodes, lights or
  shadow casters.

### L3 — No pathfinding

The system must not inherit `resident_nav`'s prop-reading debt. Motion is
static; a local vertex-shader orbit/jitter; a generated, clearance-validated
anchor-pair spline; or between-shift relocation. Nothing routes at runtime.

### L4 — Simulate pressure, not animals

Each generated anchor carries a small pressure integer advanced by the existing
shift/schedule clock. Food, damp, neglect, weather and later §E grime feed it.
C1 is stateless: pressure is pure `f(anchor, shift_count, seed)` and nothing is
saved. Zone/floor entry realizes deterministic instances and an event schedule.
Persistence arrives only with C3 by riding §E's anchor state.

### L5 — The Tenant's separation

`CommensalDirector` and `PoltergeistLibrary` are separate owners. Vermin audio
never patterns on the motif: no short-short-pause-long cadence and no fifth
position. Assert that boundary programmatically. The proposed haunting-requested
hush/flush hook is rejected; commensal behavior never confirms or denies a
haunting.

## 3. Architecture

`CommensalDirector` is one waking `BuildingRoot`-family presentation owner. It
owns the per-shift pressure pass, per-zone MultiMesh sets, event scheduler and
stimulus rules. Like Passage carts, physics/collision/render submissions freeze
when another zone owns the frame; indoor work respects per-floor visibility.

Anchors are generator- or owner-derived facts. C1 reuses existing authoritative
markers and named owner geometry. Later genuinely new anchors use
`gen_layout.py` marker kind, species affinity and validated run-lines just as it
emits `passage_shop_hours`; JSON is never hand-edited and runtime code contains
no coordinate literals.

**SCHEDULING HAZARD:** `gen_layout.py` is contended. The PS12a held-hunks lesson
applies: perform the marker pass only when no other lane holds edits there,
inspect the shared index before work and commits, and stage every generated or
generator file by exact name. Never overwrite, restore or absorb another lane's
hunks.

Rendering uses one MultiMesh per class per zone: moths, pigeons, interior
skitters, static flora and webs. Droppings and guano join the existing
`story_decal`/`AtmosphericDecalPass` vocabulary and occur only under roosts or
runs. Vertex motion derives from `TIME` plus per-instance data. Audio uses the
existing acoustic graph, remains sparse and never synchronizes.

There is no collision or interaction in C1. §E countermeasure verbs arrive only
in C3.

## 4. Species and location matrix

- **Street:** moth orbits at lit lamps; sleeping pigeon rows on marquee,
  cornices and sign brackets; a rare validated rat gutter-run; horse-dropping
  wear and restrained fly shimmer by dray/hansom lanes; weeds at hoarding bases
  and kerb cracks; guano only beneath roosts. A future viaduct is a natural
  primary roost but is not assumed.
- **Orison exterior/light court:** cornice pigeons, moss on the damp north base
  course, one areaway ailanthus seedling and moths at the entry lantern.
- **Orison interior:** one habituated light-switch roach scatter into a real
  authored gap; mice-in-riser audio through the acoustic graph; silverfish near
  bathroom drains; corner-anchored cobwebs in stairs and basement.
- **B1:** waterbugs at drains/drip lines and rat runs between coal and storage.
  There is no Room 0 exclusion; ordinary animals do not confirm it.
- **Passage at 03:00:** mice behind grilles and rare terrazzo crossings, moths
  at HARDWARE PAINT's lit window, and ferns/moss at the 26 barrel-vault drains.
- **Harukiya:** two flies over the established sticky patch and one rare shelf
  roach. A sleeping mouser on the third stair is an optional ADAPTATION and
  requires a ruling before it or a name exists.
- **Roof:** hard-gated roosting pigeon colony, positional guano, gutter weeds
  and moths at the stair-head lamp.
- **Shops:** clothes-moth evidence in stored textiles, period mousetrap/flypaper
  dressing, and at most one restrained funeral-parlour fly—or none.
- **Malcolm (3A):** his tended window box is the one deliberately cultivated
  contrast to invasive growth; file as INFERRED if ruled.

## 5. Simulation and events

Pressure advances on the existing shift clock. Zone realization schedules only
a few events per shift: rat run, light-armed scatter, proximity-armed pigeon
flush. Attention events never fire during `call_locked`, active conversation or
dream onset; ambient loops are exempt. Rain suppresses street insects and
pushes rat pressure inward without creating wet strobe. The same shift index
and seed must produce the same census and schedule.

## 6. Interactions and later integration

In C1 proximity may flush pigeons, light repels roaches and lamps retain moths.
Nothing obstructs, collides, prompts or yields an item. Phase-one cases and
residents do not couple to the system.

C3 may use already-ruled §E machinery: personality-filtered resident complaints,
period countermeasure errands, and three-state “functional but failing” evidence
such as a drip tray attracting waterbugs. Ambient orders remain place/fault
bound and never advance cases. These are not licensed until §10 rules scope.

## 7. Taste and canon guardrails

- Never make every location infested; density follows authored causes.
- No bedbugs, maggots, gore or spectacle swarms.
- Droppings/guano are capped positional wear, only under roosts and runs.
- No creature carries signal, glows or behaves anachronistically.
- Audio never patterns on the motif, masks a tell or outranks room tone.
- Nothing stalks or targets the player; rats run away.
- The funeral parlour receives restraint or nothing.

## 8. Proof contract

`CommensalTest` must prove deterministic census/schedule; zone and floor gating;
zero collision, lights, shadow casters and per-instance `_process`; protected
event windows; motif-cadence exclusion; per-zone caps; marker traceability with
no coordinate literals; and habituation.

Performance requires `WeatherPerf` with the street layer enabled (≤ +0.3 ms,
≤ +3 draws), `Perf.tscn` atrium/lobby/roof before/after with A/A controls, and a
director tick ≤ 0.1 ms. Production shots cover marquee roost, lamp moths,
kitchen scatter, Passage drain ferns and areaway ailanthus.

`art/renders/insitu/shots.md` is currently dirty in another lane. Do not edit,
sweep or absorb it; use a workstream-owned proof folder and merge shot logging
only when that owner releases the file.

## 9. Rollout

- **C1 — minimum proof:** moths at the two Orison-door lamps,
  mice-in-the-riser audio on one F02 run, one roach scatter in 4B's kitchen and
  one static weed cluster at a hoarding base. Measure, render and judge before
  adding breadth.
- **C2 — waking breadth:** pigeons and one flush, rat gutter-runs, guano/web
  decals, and Passage/B1 casts without a Room 0 exclusion.
- **C3 — §E integration:** pressure persistence on entropy anchors, resident
  complaints, countermeasure chores and Murphy-timed events.
- **C4 — separately ruled breadth:** audio expansion and the optional cat. The
  precursor hook is excluded from this owner.

This is a waking §E-family lane, orthogonal to dream fauna. Its only known
contended ground is `gen_layout.py`; schedule that pass clear of all other
holds.

## 10. Owner ruling — closed 2026-08-20

1. **Cast/taste approved, tiered.** C1 uses mice, German roaches, lamp moths
   and one restrained weed family. C2 may add Norway rats, pigeons, waterbugs,
   silverfish, clothes-moth evidence, moss and ailanthus. No infestation
   spectacle; no funeral-parlour cast; guano remains sparse and positional.
2. **Harukiya mouser deferred.** A cat is a character and remains C4-gated.
3. **Room 0 exclusion rejected.** Ordinary animals do not confirm Room 0.
4. **Haunting precursor rejected.** Vermin hush/flush is not a signal channel.
5. **Complaints/countermeasures approved for C3 only.** They remain ambient
   place/fault orders and never advance cases.
6. **Ownership approved with boundary.** `CommensalDirector` owns deterministic
   pressure, census, scheduling and visual batches; existing acoustic owners
   retain playback, propagation, priority and ducking.
7. **Daylight is species-specific, C1 night-only.** Plants/wear persist,
   pigeons may roost, rats/roaches become rarer, and moths require darkness plus
   a lit lamp. No global daylight switch.

**Execution correction:** C1 derives its anchors from existing authoritative
street-lamp markers, 4B kitchen fixtures, riser identities and named hoarding
geometry. It does not touch `gen_layout.py`. Reserve an uncontended generator
pass for C2's genuinely new validated rat-run and specialized roost anchors.
