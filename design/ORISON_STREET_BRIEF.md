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

### As built — traffic contact, 2026-08-14

The shove is now physical and deliberately small. `StreetTraffic` carries the
player in the vehicle's actual world-X direction at 3.4 m/s; the old placeholder
vector pointed across the lanes and is retired. `PlayerController.stagger()`
blends that carry with reduced—but never removed—steering for 0.72 seconds,
adds a restrained 4.9° camera roll, and settles automatically. Mouse/touch look
is never seized and there is no get-up input.

The street, not the player, owns four seconds of repeat immunity. A second hit
inside it cannot stack into a launch. Entering a protected call or noclip clears
the residual carry rather than suspending it for later. No health, damage,
failure UI, bespoke impact sound or persistent state was introduced.
`StreetStaggerTest` drives the production traffic contact and proves direction,
displacement, recovery, non-stacking and both protection seams.

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

### As built — WE TUNA PIANOS trade truck, 2026-08-14

One piece of ordinary commercial traffic is allowed to be funnier on its own
merits: a battered 1928 one-ton piano-repair box truck in oxidised teal, cream
and vermilion. Its coachwork is 5.8 × 2.05 × 2.30 m and carries the approved
painted advertisement—a shark playing a baby grand by swinging a uniformed,
mustachioed tuna across the keys—under the exact legend **WE TUNA PIANOS**.
Nobody comments because it is an advertisement, not an anomaly.

The production traffic version keeps the concept's identifying silhouette and
sideboards without pretending a close-view concept model is free. Body, cab,
wheels and lamps stay in the existing traffic MultiMeshes. Both sign faces for
every repair truck share one additional shadowless, non-emissive MultiMesh that
has zero visible instances when the kind is absent. The truck has 2.0 of 99.0
selection weight (~2.02%), follows ordinary lane speed and direction, never
serves the tram stop, and owns no light, collision, parked state or scene.

The approved sign is at
`art/concept/advertisements/we_tuna_pianos_truck_logo_v1.png`; the vehicle
design sheet is at
`art/concept/vehicles/we_tuna_pianos_repair_truck_v1.png`. The runtime panel is
the same complete sign, not a redrawn approximation. `PianoRepairTruckTest`
proves the envelope, rarity, imported source, one-batch/two-face ownership,
opposite-lane motion and unchanged crossing/arrival contracts. Fixed morning
and day rain frames are under `art/renders/piano_repair_truck/`. This addition
did not itself close T2d; the shared traffic pass immediately below does.

### As built — night traffic readability, 2026-08-14

The under-lit carriageway stays under-lit. Each moving road user instead owns
one restrained piece of information on the surface immediately ahead of it: a
5.2 × 1.55 m warm reflection from two period lamps, widening, overlapping and
breaking across the wet paving until it reads as one imperfect pool. It marks
the nose, direction and closing speed without pretending to illuminate nearby
architecture or turning the vehicle body self-luminous.

All visible reflections share one `TrafficWetHeadlightPools` MultiMesh. It is
unshaded additive geometry 35 mm above the road, casts no shadow, contains no
`Light3D`, and submits zero instances when the street is empty. The lamp faces
remain the original emissive quads. This is the entire T2d spend; street lamps,
the 16/16 lighting budget, traffic cadence, tram stop and shove rules are
unchanged.

`TrafficNightReadabilityTest` proves the one-batch ownership, bounded size and
alpha, opposite-lane placement, zero-light/shadow rule, empty-street behavior
and unchanged crossing contracts. Canonical-night control/control/final frames
are in `art/renders/traffic_night_readability_t2d/`; the repeated control makes
the live-rain difference explicit. At the focused 1440p street station the
pool-hidden and production runs measured 29.99 and 30.29 ms respectively, while
their independent runtime populations differed by 10 objects and 15 calls.
That delta is inside run noise; the deterministic cost is one shared draw.

---

## 4. The ends of the street

The owner's proposal: a tear in the universe at either end, swirling, lightning,
debris, never explained.

**Superseded by the built ruling in §8 and T8.** The impossible boundary remains,
but its shipped expression is quiet storm, hoarding and middle-distance loss—not
a loud vortex that ejects debris. The discussion below is retained as the design
path that identified that volume risk, not as current implementation authority.

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

### As built — T6 closed 2026-08-14

The first controllable frame now begins on the south walk at (−3.60, −24.72),
looking across the complete 30 ft carriageway at the Orison entrance. The car is
already tucked against the kerb beside the player at (−4.50, −22.55). It holds
for 1.15 seconds—long enough for the relationship to read without taking the
camera—then accelerates to 6.4 m/s while merging into the eastbound lane. It
crosses the authored east storm boundary at x +20.60 exactly once and ceases to
exist at x +27.00. No character, caption or objective acknowledges it.

This is not the deleted static rideshare restored under another name. It has no
body or collision shape, occupies one ordinary `StreetTraffic` slot, and uses
the same shared shadowless MultiMesh submissions as the rest of the road. A
lower close-view motor profile and muted teal greenhouse distinguish it without
a bespoke draw owner, light, scene or permanent object. Random startup
traffic yields for five seconds so the first action remains legible, then the
ordinary two-way stream resumes.

`FirstShiftDirector` remains the one-shot campaign owner through the existing
`intro_complete` fact; `StreetTraffic` owns only the moving vehicle lifecycle.
The production player is now bound after it actually exists, correcting the
old null startup reference used by traffic audio and shoves. `ArrivalCarTest`
proves the spawn, hold, acceleration, lane merge, exact storm crossing, removal,
non-replay, shared-batch budget and absence of the former static hull. The three
fixed morning-rain proof frames are in `art/renders/arrival_car_t6/`.

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

At the T5 checkpoint T2d remained honest: the instanced traffic silhouettes
were still under-read at night. T5 proved a real served stop and readable
shelter architecture; the later traffic-readability pass above owns that fix.

### As built — T5b road clearance closed 2026-08-14

The four utility cuts and their sixteen striped barricades are retired. They
were route-control scenery from the superseded map in which the retail row sat
across the street; after all eleven shops moved into the Vantry Arcade and the
final street ends gained their own visible architecture, the excavation no
longer explained or protected anything. It merely fenced active traffic lanes,
duplicated the stage boundary, and made the road read as a permanent worksite.

The subtraction is narrow: four trench slabs, four spoil heaps, two loose
planks and the south-kerb paper scatter leave with the barricades. The zebra
remains as visual crossing guidance. Drains, manholes, puddles, traffic, the
served shelter, frontage-side crates/bottles/bins and both x −20.10 / +20.60
timber-and-storm ends remain. The carriageway is continuous inside those
controls; this does not reopen the approved three-zone plan or §4's later
question about how loud the end weather becomes.

The production rebuild removes one merged F01 primitive containing 10,816
position vertices, 17,952 indices and 381,296 bytes. `RoadClearanceTest`
proves zero obsolete records, all sixteen former barricade stations clear to
the production capsule, all eleven zebra records present, and the six authored
boundary spans intact. Fixed A/B frames and a same-build live-rain control are
under `art/renders/road_clearance_t5b/`.

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

### As built — T7a stable-region visibility gate, 2026-08-14

The current canonical-night street-elevation station is **29.30 ms**, not the
33.28 ms pre-construction baseline above. It still misses 16.6 and remains a
submission/lighting problem; T7a does not claim to close that gap.

One unrelated CPU remainder was safe to bank. `BuildingRoot` used to scan about
614 registered props and 120 doors every physics tick even while the player or
camera remained inside one visibility region. It now packs the exact answer—
Passage, atrium eye, exterior, all-floor override, and shell/actor visibility
for every authored storey—into a region signature. The signature is recomputed
continuously; the actor scan runs only when that answer changes. Direct
`_apply_visibility()` calls remain authoritative for tools and focused tests.

The production-scene microprofile, with no frames advancing between samples,
measures **0.003 ms per signature versus 0.207 ms per full scan: 0.204 ms
avoided per stable physics tick**. A fresh same-build control using
`PERF_VISIBILITY_CACHE_OFF=1` measured 28.79 ms cached and 29.58 ms with the old
scan, but the frames differed by 647 render objects; that noisy 0.79 ms delta is
not claimed as causal. `PassageVisibilityTest` proves same-region suppression,
portal invalidation and the all-floor override. The full map route and WalkTest
FAST/FULL at x8/480 remain green. No render changed, so no beauty A/B was made.

P5's adjacent “empty occlusion pass” lead was also tested and falsified. The
production tree owns exactly zero `OccluderInstance3D` nodes, but fresh street
runs measured 28.79/29.08 ms with project occlusion enabled and 28.79 ms with it
disabled on the same build. The enabled controls' render populations differed,
so the spread is noise; Godot already short-circuits the empty system. The
project setting remains enabled for any future properly proved occluders.

That pass also corrected an instrument claim: on the current Compatibility
backend, `Viewport.get_render_info` reports all calls under VISIBLE and zero
under SHADOW. `SubmissionCensus` still provides a useful frustum/owner and
light-overlap census, but now marks its render-pass split unavailable and does
not pretend the frustum surfaces reconcile to a backend-total call count.

### As built — T7b STREET/core shadow ownership, 2026-08-14

The historical aerial elevation is not the playable street. A new north-
pavement lens parks the production player at `(-16.0, 0.27, 13.5)` under the
camera at `(-16.0, 1.68, 13.5)`, looking east along the traffic stream. Its
first run exposed two probe errors before any policy was judged:

- `WeatherPerf` and the new census left `BuildingRoot.view_override` on the
  detached camera. Streaming therefore answered from 1.68 m eye height, inside
  F02's 1.75 m overlap, instead of the controller's feet as production does;
- the census equated `visible` with submission, counting root-owned geometry
  already composed out by render layers, and recursed into arcade SubViewports,
  reviving the already-falsified isolated-World3D light attribution.

Corrected, the production lens measured 35.680 ms, 19,897 objects and 25,235
calls. Its 2,651 frustum beauty surfaces could not explain the backend total;
the remainder was repeated light work. Eleven budgeted fixture sources stood
inside the Orison shell while the player stood in STREET. They still need to
shine through windows and the open door, but their shadow maps re-rendered the
sealed interior into the outdoor frame.

T7b composes that ownership inside `LightRig`: at low STREET height, as proved
by `BuildingRoot.weather_exposure_at`, a source inside the Orison's exact
absolute-x <= 15.2 / absolute-z <= 11.2 streaming bounds keeps its energy and
visibility but does not receive a shadow slot. Exterior entry/facade sources,
the player's phone,
the directional moon, Passage sources and every fixture seen from ORISON are
unchanged. No hide/show list or stale saved state exists; the ordinary ranked
budget restores core shadows on the first update after entry.

The retained same-build control `PERF_STREET_CORE_SHADOWS_ON=1` measured:

| playable north pavement, 1440p, canonical night | objects | calls | ms |
|---|---:|---:|---:|
| old state A/B | 19,900 / 20,072 | 25,248 / 25,370 | 35.929 / 36.486 |
| production A/B | 10,401 / 9,741 | 12,530 / 11,883 | 26.486 / 27.042 |
| mean change | -49.6% | **-51.8%** | **-9.444 ms (-26.1%)** |

The visual proof is a paused same-process A/A/B, not unrelated beauty frames:
`art/renders/street_core_shadow_t7b/paired/`. Live GPU rain still moves in the
pause, so the repeated control records its floor. The treatment's mean absolute
pixel delta is 0.1208/255 against 0.0646/255 control noise; the true difference
is small and localized around the distant lit entrance recess, with no lost
light pool or flattened facade depth at the playable lens. `LightingAudit`
proves core fixtures exist and lose shadows outside, a local exterior caster
survives, and ranked core shadows return inside.

The result is large and shippable, but not a target flip: 26.764 ms still misses
16.6 by 10.16 ms. T7 remains open on the remaining submission work.

### As built — T7c enclosed-F01 STREET gate, 2026-08-15

The T7b census still showed about 2,650 beauty surfaces and 12,000 backend
calls after the core-light shadow maps were removed. A reversible spatial cut
identified the next ownership failure: low STREET submitted more than a
thousand F01 draws whose complete world AABBs sat behind the Orison shell.
They included imported interior buffers and late-built dressing that no legal
outdoor camera can see, yet every surviving exterior, phone and moon shadow
pass continued to render them.

The production gate indexes only geometry wholly inside absolute-x 15.2,
absolute-z 11.2 and low F01 height -0.50..2.80 m. Boundary contact preserves a
draw. Compound functional props and doors are classified as owners rather than
as loose child meshes, so a neon word or multi-leaf door cannot be sheared.
The authored `F01_DOOR_06` street entry, all `WindowGlow` cards, the runtime
entry/marquee assemblies and moving `NPC_` residents are protected explicitly.
Imported or static interior geometry is removed from render layers only while
the occupied point is low STREET; entering Orison or using the aerial station
restores its exact authored layer.

Many of these nodes are also foreign to PASSAGE. A pair of independent
save/restore tables would be wrong at a direct portal transition: the second
gate could restore a node the first still owns as hidden. `_zone_toggle` now
stores one authored layer and a set of named blockers; it restores only when
the set is empty. `StreetCoreVisibilityTest` proves all 16 ownership and
transition rules, including STREET -> PASSAGE -> STREET -> ORISON on a measured
overlap node. `PassageVisibilityTest` retains its full existing contract.

The same-build retained control is
`PERF_STREET_CORE_GEOMETRY_ON=1`. At 1440p, canonical night, 16/16:

| playable north pavement | objects | calls | ms |
|---|---:|---:|---:|
| previous state A/B | 9,735 / 9,740 | 11,864 / 11,881 | 26.735 / 26.252 |
| production A/B | 8,198 / 8,202 | 9,433 / 9,433 | 22.870 / 22.794 |
| mean change | **-15.8%** | **-20.5%** | **-3.662 ms (-13.8%)** |

Exact production A/A/B frames at north pavement, south elevation and east
road mouth are in `art/renders/street_core_geometry_t7c/production_pair/`.
GPU rain continues during pause, so each station carries its own control-noise
floor. No named facade element disappears: WindowGlow, the closed entry door,
complete cyan/pink neon, marquee, light pools and exterior depth all survive.
The remaining differences are low-level illumination/shadow changes at the
window and entry apertures caused by removing their impossible behind-wall
casters, plus live-rain variance.

This banks another real submission win but does not close T7: the authoritative
mean is 22.832 ms, still **6.23 ms above 16.6**.

---

## 8. Owner rulings, reconciled from the built street 2026-08-14

The four questions in the original proposal are no longer open. Later direct
owner instructions and their accepted production proofs answer them:

1. **No loud tear.** The impossible ends are the densest parts of the same
   driving storm: visible hoarding, wet timber and weather swallowing the middle
   distance. No stinger, vortex or lightning portal announces a boundary.
2. **Traffic and weather emerge; debris and people do not.** T5b removes the old
   excavation debris rather than replenishing it. Ordinary vehicles—including
   the one-time arrival car—appear from and disappear into the storm.
3. **The tram has no rails.** That is the brief's authored wrong 5%, retained
   without comment. Do not add permanent rail geometry to the crossing lane.
4. **Traffic continues at night.** T2d exists specifically to make that stream
   readable on the wet road at canonical night. Night does not empty the street.

These are a record of the approved map already in production, not permission to
reopen the three-zone layout or the street-end architecture.
