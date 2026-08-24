# THE DREAM ECOLOGY — THREE RESOLUTIONS OF ONE BIOLOGY

> Owner direction, 2026-08-22. **Locked architecture.** Supersedes any reading
> of the earlier ruling that treated the procedural limb work as discarded:
> it was shelved *as a hero*, and this places it where it belongs — the
> margin.

## The model

The Dream manifests at three connected levels. They are **not three unrelated
systems; they are three resolutions of the same biological reality.**

1. **Hero Primary Tentacle** — the authored Blender hero asset. Highly
   detailed, independently intelligent, capable of cinematic interaction, the
   clearest local manifestation of the antagonist. *The Dream deliberately
   putting a coherent limb into our dimension.*
2. **Procedural Dream Margin Tentacles** — many smaller independently
   behaving appendages around the encroachment edge, interacting with
   architecture, each other, and the hero limb. *Its distributed
   sensory/feeding edge.*
3. **Procedurally Varied Dream Critters** — distinct species from authored
   anatomical archetypes plus controlled morphological variation. *Semi-
   autonomous organisms, organs, symbionts, offspring, fragments, or
   ecological expressions produced by the same adjacent biology.*

> *"The result should feel like a functioning impossible ecosystem rather
> than one monster surrounded by VFX."*

---

## 1. KEEP THE HERO BLENDER TENTACLE

The current hero asset **remains canon**. Continue refinement of: dense
carnal flesh; embedded eye at ~42%; triple lid anatomy; sensory cilia; living
gold biomineral skeleton; crystal organs; distal suckers; membrane emergence;
high-fidelity contact; vascular pressure; mechanical gold articulation;
hyperdimensional phase behavior.

It is intentionally more authored and anatomically specific than the
procedural population. **It should be the creature we can put the camera
directly against.**

The Hero owns: highest mesh fidelity; strongest eye/attention performance;
complex contact; sophisticated surface deformation; hero shaders; bespoke
animation states; precise cinematic behavior; major environmental
transformation; special hyperdimensional events.

**Do not proceduralize away the qualities that make it exceptional.**

## 2. HERO TENTACLE BEHAVIOR

Individually intelligent. Core states:

    MEMBRANE_BULGE  EMERGING  ORIENTING  SEEKING  APPROACHING
    HOVER_INSPECTION  TOUCHING  CARESSING  TASTING  WATCH_PLAYER
    INTERACT_MARGIN  INTERACT_CRITTER  FLINCH  RESUME  WITHDRAW

It interacts naturally with procedural systems: small palps groom its gold
structures; procedural tentacles investigate its contact point; the hero
gently displaces smaller appendages; margin tentacles make room when it
emerges; critters react to its attention; some approach, some avoid; one may
ride or cling to it; the hero may inspect a critter; pulses propagate between
hero and margin.

**It is not a completely isolated cinematic object. It is part of the
ecology.**

## 3. HERO VS PROCEDURAL SCALE LANGUAGE

| level | size | reads as |
| --- | --- | --- |
| Hero Tentacle | ~1.6 m class | powerful, elegant, intentional, exceptionally complex, individually intelligent |
| Primary procedural palps | 10–60 cm | sensory appendages, mouthparts, fingers, exploratory organs |
| Secondary branches | 3–20 cm | specialised tactile sub-organs |
| Tertiary cilia | mm to several cm | distributed sensing |
| Critters | variable | insect-sized, palm-sized scavengers, cat-sized, larger rare organisms |

Scale should produce **ecological hierarchy**.

## 4. DREAM MARGIN IS A LIVING ANATOMICAL BORDER

The violet Dream field does not end in a shader fade. Its boundary is
populated with independently behaving appendages.

From a distance: crawling edge. Closer: individual feelers. Closer: several
anatomical types. Closer: social interaction. Closer: recursive branching.
Eventually: **the realization that this may all be one distributed nervous
system.**

Build with: `DreamMarginController`, `DreamPalp`, `DreamPalpMorphology`,
`DreamPalpBehavior`, `DreamPalpContact`, `DreamPalpBranch`,
`DreamPalpNeighborSystem`, `DreamGlobalAttention`. All consume
`DreamFieldState`.

## 5. PROCEDURAL PALP ARCHETYPES

Do not generate meaningless tubes. Author strong source archetypes. Initial
library:

- **Soft palp** — muscular fleshy exploratory organ.
- **Flat ribbon** — broad tactile surface.
- **Sucker probe** — specialised surface sampler.
- **Gold-jointed finger** — rigid/flexible biomineral articulation.
- **Crystal feeler** — fine probe with sensory mineral organ.
- **Ciliated whisker** — long distance/vibration detector.
- **Hook palp** — bracing and grasping structure.
- **Branching organ** — designed specifically for recursive unfolding.
- **Mouthpart palp** — shorter, more forceful, works cooperatively in clusters.
- **Membrane tongue** — very flat, slides into seams and beneath objects.

Each must have its own movement biases and functional anatomy.

## 6. CONTROLLED PROCEDURAL MORPHOLOGY

Every spawned palp receives a seed. Vary: total length; segment proportions;
base thickness; taper; distal specialisation; cross-section progression;
twist; curvature; stiffness; sucker distribution; cilia count; gold
percentage; gold structure type; crystal probability; vein configuration;
flesh mottling; wetness; branching potential.

Variation stays anatomically constrained by archetype. **No procedural
oatmeal.** A Gold Jointed Finger must always remain recognizably different
from a Flat Ribbon.

## 7. PROCEDURAL CROSS-SECTIONS

Generated spline rings, not circular tubes. Support circular, elliptical,
flattened, ribbed, lobed, triangular-ish, asymmetric crescent, pinched,
swollen — interpolated along length:

    muscular root -> flattened shaft -> lobed sensory region -> fine distal tip
    thin root -> articulated gold swelling -> round flesh segment -> broad sucker pad

**This alone will dramatically increase apparent biological variety.**

## 8. PROCEDURAL PALP PERSONALITY

Stable traits per palp: `curiosity`, `boldness`, `startle_threshold`,
`contact_persistence`, `social_affinity`, `territoriality`, `object_interest`,
`branch_likelihood`, `tremor_frequency`, `preferred_reach`,
`phase_instability`, `hero_affinity`, `critter_affinity`.

**Do not reshuffle these continuously.** Stable personality makes individual
appendages memorable.

## 9. PALP MOVEMENT MUST COME FROM INTENT

No global sine-wave waving. Movement primitives:

- **Probe** — extend, stop, microcorrect, stop, extend.
- **Sample** — distal-only 5–9 Hz tremor.
- **Hover** — tiny positional corrections near target.
- **Touch** — velocity decreases before contact; tip compresses.
- **Trace** — follow edge, seam, contour or grain.
- **Brace** — plant and stiffen.
- **Taste** — short repeated local sampling.
- **Watch** — orient distal sensor toward stimulus.
- **Withdraw** — retraction propagates along the body.
- **Freeze** — immediate stillness.

Use actual behavioral targeting to drive the desired pose. The procedural rig
solves toward it.

## 10. PROCEDURAL PALPS INTERACT WITH EACH OTHER

Broadcast: tip position, body occupancy, target, interest level, contact
state, startle state, branch state, hero proximity, critter proximity.

Social behaviors: avoidance, investigation, grooming, bracing, competition,
mimicry, pulse communication, touching, intertwining, cooperative object
inspection. Clusters can form temporary arthropod-mouthpart-like
arrangements. **They should look purposeful, not chaotic.**

## 11. THE HERO PARTICIPATES IN THIS SOCIAL SYSTEM

The Hero is a high-priority neighbor entity. Margin palps may touch it,
withdraw from it, groom it, follow it, inspect what it inspects, orient
toward its eye, collect around its root, brace against it, crawl across it,
receive pulses from it.

Hero behavior may include gently nudging small palps aside, allowing them to
cling, observing them, touching one with its distal sensory club, reacting if
one startles.

**This makes the hero limb feel like a dominant organ of the same living
system rather than a special effect dropped into it.**

## 12. RECURSIVE / FRACTAL PALPS

Adaptive anatomical recursion. Canonical sequence:

1. target interest increases
2. local vascular congestion
3. gold structures reposition
4. crease forms
5. folded anatomy separates
6. two or more secondary appendages unfold
7. secondary branches independently investigate
8. fine cilia deploy
9. task completes
10. fine anatomy retracts
11. secondary branches fold together
12. parent returns to simpler topology

**Never spawn a branch by scaling a cylinder from zero.** Make it appear that
complicated anatomy was folded inside simple anatomy.

## 13. COORDINATED GLOBAL INTELLIGENCE

Most of the ecology behaves independently. Rarely, `DreamGlobalAttention`
overrides local intent.

Canonical event: twenty palps doing different things, several critters moving
independently, the hero examining an object. A sudden meaningful stimulus.
At the same instant — procedural tips orient, critters stop or turn, the hero
eye fixes, gold structures tense, nearby field anatomy shifts. **Hold.** Then
autonomy returns asynchronously.

> *"This should be one of the most important reveals in the game: the
> ecosystem may be one mind."*

## 14. PROCEDURAL CRITTER SYSTEM

`DreamCritterGenerator`. **Do not procedurally synthesize arbitrary animals
from nothing.** Authored anatomical species templates plus controlled
variation.

Architecture: `DreamCritterSpecies`, `DreamCritterMorphology`,
`DreamCritterGenerator`, `DreamCritterRig`, `DreamCritterBehavior`,
`DreamCritterSensorySystem`, `DreamCritterContact`, `DreamCritterPhaseBehavior`.

Each species defines hard biological constraints; the generator creates
believable individuals inside them.

## 15. DISTINCT CRITTER SPECIES ARCHETYPES

Development shorthand, species canon to be refined later:

- **Seam Grazer** — flat wall crawler, feels along wallpaper seams and
  baseboards, broad tactile underside, small gold skeletal lattice.
- **Crystal Listener** — mostly sensory, long cilia, crystal resonance
  organs, freezes to detect vibration.
- **Fold Crab** — low multi-limbed crawler, several mouthpart-like front
  appendages, gold joint cups.
- **Ribbon Moth** — thin folded organism, moves partly through normal space
  and partly via dimensional reconfiguration.
- **Orbital Observer** — large eye/sensory complex on small locomotor
  appendages.
- **Gold Tick** — tiny mineral-heavy creature that anchors to Dream surfaces.
- **Membrane Skater** — broad flesh sheets rather than conventional legs.
- **Palp Colony** — looks like one small creature until disturbed, then
  unfolds into many short appendages.

## 16. HARD MORPHOLOGICAL RULES PER SPECIES

Example, Seam Grazer. **Must have:** flattened body; low silhouette; tactile
underside; seam-following sensory organ. **May vary:** body length; width;
number of small feelers; gold lattice pattern; crystal count; coloration;
locomotion rhythm. **Cannot become:** a spherical floating creature; a long
tentacle; a six-foot spider.

**Species identity comes before variety.**

## 17. PROCEDURAL CRITTER VARIATION

Within species vary: scale; proportions; limb count within bounded range;
limb segment lengths; symmetry; asymmetrical defects; gold mineralisation;
crystal organ size; cilia distribution; vascular pattern; skin texture;
wetness; color bias; temperament; locomotion rhythm; sensory priorities;
phase instability.

Allow rare morphs: most Seam Grazers have 4 sensory palps; 5% may have 6; 1%
may have an unusually large crystal organ. **Very rare variation becomes
memorable.**

## 18. MODULES + DEFORMATION

Favor authored hero body modules; procedural spline limbs; Geometry
Nodes-derived structures exported appropriately; instanced
sucker/cilia/gold components; morph targets; modular sockets.

Do not attempt arbitrary runtime mesh sculpture when it gives worse art
direction. The model is: **authored biological grammar + procedural assembly
+ procedural deformation.**

## 19. CRITTER BEHAVIOR VARIATION

Species behavior defines locomotion style, sensory priorities, social
behavior, fear response, Dream-margin relationship, hero relationship, object
interests. Individual values adjust confidence, curiosity, persistence,
sociability, aggression, startle, exploration radius.

**Two critters of the same species should feel related but not duplicated.**

## 20. PROCEDURAL MOVEMENT VARIATION

Not merely scaled animation speed. Vary stride phase; which limb initiates
motion; pauses; body compression; head/sensor tracking; preferred turning
side; gait asymmetry; secondary dynamics. One individual moves confidently;
another of the same species hesitates, freezes often, samples constantly,
follows walls. **Their anatomy remains the same species.**

## 21. CRITTERS INTERACT WITH PROCEDURAL PALPS

Critters use the Dream margin as **habitat**: crawl across margin tentacles;
groom them; feed on transformed residue; hide beneath them; get pushed aside
by larger palps; follow a palp to a discovered object; use a stationary palp
as a bridge; ride an emerging appendage; be inspected by a branch; trigger
coordinated local attention.

**This turns the wall into a functioning biome.**

## 22. CRITTERS INTERACT WITH THE HERO

Rarely and meaningfully. A tiny critter clings to a hero gold plate; the hero
eye notices it; the distal club nudges it; the critter unfolds sensory
structures; the hero allows it onto another section; nearby palps orient
toward the interaction.

Or: the hero emerges, several critters flee into the margin, one remains, and
the hero examines the brave individual.

**These interactions can create character without dialogue.**

## 23. CRITTER SOCIAL SYSTEM

Per species: solitary, colonial, pair-bonded, flocking, opportunistic
aggregation. Behaviors: following, sharing discoveries, grooming, competing,
feeding together, warning signals, mimicry, territorial displays. **Do not
make every species social in the same way.**

## 24. PROCEDURAL CRITTER HYPERDIMENSIONALITY

One dominant impossible rule per species, not randomly assigned generic phase
effects.

- Seam Grazer — occupies both sides of a thin wall simultaneously.
- Crystal Listener — its sensory crystal rotates without changing apparent
  external orientation.
- Fold Crab — shortens one leg without moving either endpoint.
- Ribbon Moth — wing area increases when viewed edge-on.
- Orbital Observer — some eyes remain visible through occlusion.
- Palp Colony — body unfolds into more volume than could fit inside it.

**These are species biology.**

## 25. SHARED DREAM MATERIAL BIOLOGY

**Flesh** — plum/violet, dense, opaque, vascular, shallow SSS, heterogeneous
wetness, multi-scale normals. **Gold** — living biomineral structure,
mechanically active, embedded into tissue. **Crystal** — functional organ,
sparse, faceted, internally structured.

Individual species rebalance these radically: one 90% flesh, another 60%
gold, another nearly all membrane with tiny mineral structures. **Family
resemblance without palette swapping.**

## 26. CRITTER MATERIAL VARIATION

Species-specific ranges, seeded per individual: aubergine/magenta balance;
crimson vessel prominence; skin roughness; pore scale; papilla density; gold
alloy tint; oxidation coloration; crystal hue; wetness pattern; structural
iridescence. **Avoid arbitrary hue randomization.** Everything stays within
Dream color language.

## 27. ENVIRONMENTAL INTERACTION

Hero, palps and critters all understand `DreamTargetProfile`. Targets expose
contact points, edges, seams, surface normals, material, softness, heat,
vibration, interest, transformability.

Different organisms interpret the same object differently. A radiator:

| organism | response |
| --- | --- |
| Hero Tentacle | delicately caresses the edge |
| Soft palp | traces the fin gap |
| Gold finger | taps the metal |
| Crystal Listener | presses its resonance organ to it |
| Seam Grazer | ignores it unless a paint crack forms an interesting boundary |

**Ecology emerges from different sensory priorities.**

## 28. TRANSFORMATIVE CONTACT

Contact may temporarily produce flesh, vascular structures, gold
mineralisation, crystal nodules, dimensional phase effects. Intensity depends
on species, contact time, Dream state, object compatibility. **The Hero gets
the richest transformation;** procedural organisms cause subtler effects.

## 29. POPULATION LOD

| tier | count | detail |
| --- | --- | --- |
| Hero Tentacle | 1 | fully detailed |
| Hero palps | 3–6 | full collision, complex behavior |
| Secondary palps | 10–20 | simplified |
| Tertiary palps | 20–60 | cheap |
| Implied micro-margin | hundreds | shader/curves |
| Hero critters | 3–8 nearby | full rigs and behavior |
| Background critters | dozens | simplified movement and materials |

Dynamic promotion/demotion. **Preserve individual seeds across LOD
transitions.**

## 30. DYNAMIC PROMOTION

On approach, preserve species, seed, personality and current state; generate
or load a higher-detail representation. Demote when distant. **No obvious
identity replacement.**

> *"A tiny background shape can become a surprisingly intricate creature when
> investigated."*

## 31. ECOLOGY DIRECTOR

`DreamEcologyDirector` does not micromanage movement. It controls local
density, active species, margin activity, hero availability, global
attention, feeding/investigation events, retreat, curiosity, environmental
transformation intensity. **This prevents independent procedural systems from
producing incoherent noise.**

## 32. ECOLOGY STATES

`DORMANT` `CURIOUS` `FORAGING` `SOCIAL` `WATCHING` `STARTLED` `WITHDRAWING`
`HIGH_ATTENTION` `INCARNATING`

They modify **probabilities, not animations directly**. During `FORAGING`:
more object contact, more critter activity, more cooperative palps. During
`WATCHING`: less locomotion, more sensory orientation, more player tracking.
During `STARTLED`: critters retreat per species, palps freeze/retract, the
hero responds independently.

## 33. PRESERVE INDIVIDUAL AGENCY

Global states **bias** behavior; they do not turn everyone into synchronized
puppets. Only rare `DreamGlobalAttention` events produce hard
synchronization. Normal ecology: many agents. Global reveal: one intelligence.

## 34. FIRST COMBINED TEST SCENE

An encroached apartment room with wall margin, radiator, sofa/furniture,
corners/seams, player flashlight.

Population: 1 Blender Hero Tentacle; 4 hero palps; 12 secondary palps; 30+
tertiary structures; 3 critter species at 2–4 individuals each.

Target behaviors, in order: margin performs independent sampling; critters
navigate among appendages; one critter uses a palp as structure; a palp
discovers the radiator; another investigates; a mouthpart cluster forms; the
hero begins emerging; local palps make space; critters respond by species;
the hero investigates an object; one critter approaches the hero; a recursive
branch event; the flashlight causes a freeze response; a global sound causes
an ecosystem-wide attention event; one species-specific hyperdimensional
event; false retreat / observation reposition.

**Capture 20–40 seconds. This becomes the new canonical Dream ecology review
asset.**

## 35. DEVELOPMENT ORDER

1. Keep the Hero Tentacle branch active; document its remaining quality tasks.
2. Restore/build `DreamMarginController`.
3. First 6 procedural palp archetypes.
4. Procedural morphology variation.
5. Independent behavior/personality.
6. Neighbor interaction.
7. Integrate the Hero as a social/ecological participant.
8. Recursive branching.
9. First 3 procedural critter species.
10. Individual critter morphology variation.
11. Critter personality/behavior variation.
12. Hero/palp/critter cross-interaction.
13. `DreamEcologyDirector`.
14. Species-specific hyperdimensional rules.
15. Population LOD/promotion.
16. Combined gameplay test.

## 36. ACCEPTANCE — HERO

The Hero must remain **visually superior** to generated palps. If procedural
appendages make it feel redundant, reduce their complexity. The hero owns a
recognizable eye, extraordinary orbital anatomy, rich gold mechanics, the
strongest contact animation, the strongest flesh rendering, major narrative
attention. **It should feel like the ecology's hand/face.**

## 37. ACCEPTANCE — PROCEDURAL MARGIN

At least six nearby appendages must be clearly different **without relying
purely on color** — differing in silhouette, movement, function and distal
anatomy. **The edge should never look like repeated noodles.**

## 38. ACCEPTANCE — CRITTER VARIETY

Spawn ten individuals of one species: all clearly the same species, yet
several individually recognizable through proportion, anatomy variation,
materials, behavior. Then spawn three species: nobody should confuse them.

## 39. ACCEPTANCE — ECOLOGY

Watch 30 seconds without player intervention. It should produce purposive
movement, pauses, interactions, occasional discoveries, variation. It should
**not** produce perpetual writhing, constant collisions, synchronized idle
animation, particle-like chaos. **It should feel like animals inhabiting a
place.**

## 40. ACCEPTANCE — ONE MIND

Trigger `DreamGlobalAttention`. The transition from independent ecology to
coordinated reaction must be **immediately legible**. One of our central
horror beats. Use rarely enough that it remains meaningful.

## 41. NON-NEGOTIABLES

**Do not:** discard the Blender Hero Tentacle; proceduralize the hero into
mediocrity; make procedural palps copies of the hero; make critters
palette-swapped versions of each other; use random spline noise as behavior;
synchronize constant motion; make everything hostile; attach decorative gold;
scatter meaningless crystals; use every hyperdimensional effect on every
organism; overpopulate until individual behavior becomes unreadable.

**Do:** preserve hierarchy; preserve purpose; preserve anatomical function;
allow silence and stillness; create procedural variation inside authored
constraints; let organisms interact; let species behave differently; reserve
spectacular complexity for important moments.

---

## FINAL DESIGN MODEL

**THE HERO** — one exquisitely incarnated limb, with enough stable anatomy
for the player to recognize an individual presence.

**THE MARGIN** — thousands of potential fingers, antennae and mouthparts,
providing distributed sensory complexity.

**THE CRITTERS** — a functioning ecosystem generated from the same impossible
biological laws, providing evidence that this is a world, not an encounter
gimmick.

And occasionally all three stop behaving independently and respond to the
same stimulus at once. That is when the player understands:

> *"These may not be a monster, its tentacles, and some strange animals. They
> may all be different scales of anatomy belonging to one higher-dimensionally
> adjacent infinite self."*

**Build the architecture around preserving that ambiguity.**

---

## §35 PHASE STATUS (updated 2026-08-23)

| phase | state |
| --- | --- |
| 1 Hero branch active, tasks documented | done — `design/HERO_TENTACLE_REMAINING.md` |
| 2 `DreamMarginController` | done |
| 3 Six palp archetypes | done — §37 sheet in `art/renders/dream_margin/` |
| 4 Morphology variation | done |
| 5 Personality and intent | done — 8 of 10 primitives running at once |
| 6 Neighbour interaction | done, all 9 of §10's broadcasts |
| 7 Hero as ecological participant | done |
| 8 Recursive branching | done — folded, never scaled from zero |
| 9 First three critter species | done |
| 10 Critter morphology variation | done |
| 11 Critter personality/behaviour | done — 7 of 7 movement properties vary |
| 12 Hero/palp/critter cross-interaction | done |
| 13 `DreamEcologyDirector` | done, biases consumed |
| 14 Species hyperdimensional rules | done — enacted, not merely declared |
| 15 Population LOD | done — nearest-first, identity preserved |
| 16 Combined gameplay test | done — `art/renders/dream_ecology/` |

Contracts: field 16/16, margin 31/31, critters 29/29, ecology 23/23.

### The two things that need a decision rather than more code

1. **The combined capture does not co-frame the three levels.** The camera is
   tight on the hero because this wall has a partition about 2 m out. §34
   names a radiator, a sofa, corners and seams — it wants a room chosen for
   the shot. That is staging, not systems.
2. **Nothing calls `seize_attention`.** The one-mind reveal is built, wired
   through all three levels and measured, but which stimuli deserve the whole
   ecology's notice is a design decision. §40 says it must stay rare enough to
   remain meaningful, and picking those moments is authorship.

### Known gaps inside completed phases

- ~~§10's other five broadcasts~~ DONE. Contact state, startle state, branch
  state, hero proximity and critter proximity are all broadcast now, and each
  is consumed by a behaviour rather than merely published: warning signals
  (startle spreads outward as a wave), competition (contact settles who keeps
  a contested find), bracing (an appendage steadies against one that is
  actually anchored), and investigation of a critter that comes within reach.
  Superseded, kept for the record:
- ~~§10's other five broadcasts (contact, startle, branch state, and the two
  proximity signals) need systems that do not exist.
- §12's branch sequence now has steps 1-6 IN ORDER AND WITH TIME BETWEEN
  THEM. Steps 5 and 6 were built first and arrived out of nowhere: an organ
  was simple, and on the next frame it was branched. Congestion, the gold
  moving aside and the crease are the tell, they take about a second and a
  half, and their whole purpose is that the wall shows you where it is about
  to open before it opens. The roll no longer branches on the frame it
  succeeds — it starts the swelling instead.

  Two things the camera settled that the tests could not. The crease was a
  hairline over five per cent of an organ's length, which on a three-centimetre
  appendage across a room is less than a pixel; it runs over about a seventh
  now. And the gold term meant to CLEAR metal from the line was multiplied by
  the individual's own gold fraction and lost to the term adding it, so the
  premonition photographed as a gold ring — an ornament, which is the one
  thing it must not be.

  Steps 7-12 (independent investigation, cilia deploying, the retraction and
  refolding) are still owed.
- §21's habitat list is COMPLETE — all ten. *"This turns the wall into a
  functioning biome."*

  An animal grooms an appendage that is holding still; a nervous one hides
  under the nearest appendage when the alarm runs through the margin; one
  settling to feed on residue turns the appendages around it; a branch
  inspects an animal that comes within its reach; and a bold one climbs on at
  the base, is carried along, rides anatomy that is still unfolding, and steps
  off the far end onto whatever that end is resting against.

  The last three needed one mechanism between them: an animal has to be able
  to stand on an APPENDAGE rather than on architecture. The surface-walk
  re-seats by casting a ray at whatever is under its destination, and
  appendages have no presence in physics — eighty colliders for organs that
  exist to be looked at is not a trade worth making on a frame that is already
  submission-bound. So a rider is carried ANALYTICALLY: it holds an
  appendage's id and how far along it it has got, and its position is read off
  that organ's own line each frame. Riding an emerging one and crossing a
  bridge then come almost free — the first is a rider whose host has not
  finished unfolding, the second a rider that reaches a tip which is resting
  on something.
- §22 — DONE except for the last clause. The hero's club now reaches the
  animal it is minding and pushes it for real, the animal answers by putting
  its sensory structures out, and nearby palps turn to watch. What is not
  built is "the hero allows it onto another section": a critter riding the
  creature's body needs the critter to be seated on a moving surface, which
  the surface-walk does not do.
- The hero itself still owes albedo/normal bakes and eight of §2's states.

## Where this lands against existing work

- `DreamSurfaceTendrils` (DF-13) is the **seed of level 2**, not a dead end.
  It already spawns many small limbs on real surfaces from the field's
  cross-section, in one draw. It becomes the tertiary tier under
  `DreamMarginController` — it has no archetypes, morphology, personality,
  neighbor awareness or intent-driven movement yet.
- `DreamHeroTentacle` is **level 1** and now exists in-game, animated, though
  §2's state machine is unbuilt and it has no bakes.
- `DreamFieldState` is already the shared substrate §4 and §17 require.
- Nothing of level 3 exists.
