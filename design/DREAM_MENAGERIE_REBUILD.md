# THE MENAGERIE REBUILD — EVERY DREAM CRITTER TO THE TENTACLE'S BAR

> Owner direction, 2026-08-22. Canon for every creature from here on.

## The governing sentence

> *"Do not make monsters decorated with Dream aesthetics. Rebuild them as
> animals that evolved inside the Dream."*

## The aesthetic, as ruled

> Carnal anatomy + living biomineral machinery + crystalline sensory
> structures + hyperdimensional topology + exquisitely purposeful motion.

> *"Every creature should become convincing enough that its impossible
> qualities are more disturbing because everything around them feels
> physically real."*

---

## 1. AUDIT EVERY EXISTING CRITTER BEFORE REBUILDING

Inspect, for each creature: current mesh, silhouette, scale, topology, UVs,
rig, material setup, current animation, behavioral state logic,
collision/contact, LOD, existing Dream-field integration, screenshot/gameplay
readability.

Capture: neutral pose, front, side, top, three-quarter, gameplay distance,
close-up, extreme bend/action pose.

Then explicitly classify problems. Typical failure categories: "tube with
shader"; generic spider/crab/insect; generic tentacle; sphere with
appendages; procedural-noise creature; over-symmetrical anatomy; details only
visible in editor; pasted-on eye; painted-on gold; random crystals; joints
that do not look functional; motion without weight; hyperdimensional effect
that reads as glitch VFX; excessive uniform gloss; clear-gel flesh; no
tactile/contact specialization; too many effects competing simultaneously.

**Do not rebuild blindly. State what deserves to survive first.**

## 2. GIVE EACH CRITTER A SINGLE BIOLOGICAL THESIS

Before modelling, one sentence per creature:
*This organism exists to ________, and therefore its body evolved ________.*

Examples given: tastes architectural seams, therefore its entire ventral
anatomy is a flexible sensory comb. Observes from dimensional folds,
therefore most of its visible body is an ocular support mechanism. Migrates
through walls, therefore broad membrane anchors and mineral ribs that
repeatedly collapse into planar cross-sections. Collects vibrations,
therefore articulated gold tuning structures and crystal cilia.

Every part must support the thesis. No decorative appendages without
biological or behavioral purpose.

## 3. ESTABLISH A DISTINCT SILHOUETTE BEFORE DETAIL

Materials off. Every critter must be recognisable as a black silhouette. Do
not reuse one body grammar. Explore: flattened crawler; radial organism;
ribbon body; suspended jelly-like mass with dense opaque flesh; many-jointed
walking sensor; branching sessile organism; coiled spring-like body;
asymmetric biped/quadruped; crawling membrane; floating ocular assemblage;
nested shell/body; an organism whose apparent body is several disconnected 3D
slices.

Large masses first. No pores, no veins, no gold filigree. **If the silhouette
is boring, rebuild it before adding detail.**

## 4. MODEL EACH CREATURE AS LAYERS OF ANATOMICAL SYSTEMS

Avoid single combined sculpts. Modular collections:

    CRITTER_NAME
    BODY        deformation_cage, high_sculpt, subdermal_deformers
    SENSORY     eyes, cilia, antennae, tactile_organs
    GOLD        structural, joints, dendrites, growth_roots
    CRYSTAL
    CONTACT     suckers, pads, hooks, feelers
    MEMBRANE
    RIG
    BAKE
    DEBUG

Not every critter needs every category. Use only what its anatomy demands.

## 5. FLESH MUST BE MODELLED AS MASS

Dream flesh is dense, warm, pressurised, opaque, yielding, vascular,
structurally layered. It is **not** clear gel, translucent rubber, silicone,
or uniformly glossy slime.

Model primary volumes so it still looks fleshy in flat clay shading. Sculpt
major muscle bundles, load-bearing folds, compression, stretching, subdermal
masses, asymmetrical tissue accumulation, sockets around hard structures.
Then secondary wrinkles, vascular relief, pits, pores, papillae, scars and
tension lines. Microscopic detail belongs primarily in baked maps.

## 6. MAKE GOLD A LIVING SKELETAL PHASE

Nothing should look like gold trim applied after modelling. Gold is one phase
of Dream anatomy: skeleton, tendon, armour, sensory framework, joint, orbit,
support rib, resonator, spinal component, mineralised scar, tendon anchor,
locomotion component.

Model real gold where it affects silhouette, mechanical motion, contact or
joint function. At every large flesh/gold boundary: deform flesh around the
gold, embed roots beneath tissue, create compression, redirect veins, add
socket geometry, produce local wetness/AO. **Nothing appears glued on.
Everything appears grown.**

## 7. DO NOT REPEAT THE TENTACLE'S GOLD LANGUAGE IDENTICALLY

The Tentacle uses articulated skeletal plates and dendrites. Others
mineralise differently. Walking critter: internal/external joint cups and
distal claws. Wall crawler: broad gecko-like structural lattices.
Flying/floating: lightweight radial trusses. Burrowing: wedge-like cranial
structures. Sensory: resonant filaments. Defensive: overlapping petals and
scales. Same biology, different evolutionary implementation.

## 8. CRYSTALS MUST BE ORGANS

Never scatter generic gemstones. Functions: vibration detection, orientation,
dimensional phase sensing, light sensing, communication, pressure reservoir,
computational/storage organ, joint bearing, pulse routing, field projection.

Model hero crystals with actual facets, connected anatomically:
flesh, then mineral roots, then gold matrix, then crystal organ. Give
selected crystals internal occlusion, fracture planes, embedded inclusions,
pulse cores, narrow directional glints. Avoid generic transparent-gem
rendering.

## 9. DESIGN UNIQUE SENSORY ANATOMY FOR EVERY CRITTER

Not a human-like eye on everything. Possible: deeply recessed eye; compound
mineral eye; multiple eyelids; distributed tiny eyes; pressure pits; cilia;
whiskers; vibrating membranes; gold antennae; crystal lenses; ring-shaped
pupil; light-sensitive skin; surface topology that actively orients toward
stimuli.

Where eyes exist, integrate them physically: sockets, brows, muscles, lids,
lubrication, skeletal support, nerves and veins, surrounding tissue
deformation. No floating eyeballs unless floating anatomy is deliberately the
concept.

## 10. MAKE CONTACT ANATOMY SPECIFIC TO BEHAVIOR

Contact systems: suckers, pads, hooks, microcilia, claws, fleshy palms,
grasping folds, branching tendrils, pressure-sensitive bulbs.

**The last 10-30% of any exploratory appendage should be more mechanically
and sensorially complex than the shaft supporting it.** Contact should
visibly compress, spread, deform, grip, release and react to material. Do not
let feet or tips simply intersect surfaces.

## 11. RIG FROM FUNCTION, NOT CONVENIENCE

No automatic humanoid or generic chain rigs. Possible: spline IK, B-Bones,
radial arm rigs, spider-style limb IK, membrane lattices, multi-chain tails,
shape keys, subdermal deformers, Geometry Nodes deformation, procedural
secondary motion.

Rig hierarchy corresponds to actual anatomy. For every important region
specify primary movement, secondary follow-through, twist, compression,
stretch limit, contact behavior. Corrective shape keys for extreme poses.

## 12. BUILD SECONDARY MOTION INTO THE BODY

Muscular lag, skin compression, tendon tension, gold micro-articulation,
cilia springs, crystal inertia, sucker compression, membrane follow-through,
vascular pulses. Layers respond at different temporal frequencies:

    bone moves first, muscle mass follows, flesh settles,
    gold structure reseats, cilia oscillate, wet highlight stabilises

This creates physical mass.

## 13. UNIQUE MOTION LANGUAGE FOR EACH SPECIES

A behavioral signature visible from movement alone: continuously sampling;
pausing between mathematical poses; moving only when unobserved; fluid
locomotion interrupted by rigid mineral locks; rapid insectlike orientation
followed by slow fleshy translation; movements propagating from sensory
organs backward; locomotion through successive dimensional slices rather than
ordinary translation.

Avoid generic random twitch, idle noise, sinusoidal bobbing, procedural
jiggle everywhere. **Purposeful motion is sexier and more frightening than
noise.**

## 14. SHARE THE DREAM BIOLOGY, NOT THE BODY PLAN

Recurring: dense plum/violet flesh; crimson perfusion; living gold
biomineralisation; occasional crystal organs; structural iridescence;
dimensional instability; environment transformation.

Varying: hue balance, gold percentage, vascular architecture, flesh texture,
crystal type, anatomy, symmetry, movement, sensory system. Organisms in one
biosphere, not palette swaps.

## 15. GIVE EACH SPECIES ONE HYPERDIMENSIONAL LAW

One dominant impossible rule, optionally one minor supporting rule.

- Phase crawler: legs sometimes connect to different apparent body sections.
- Fold moth: wings have greater visible area when edge-on.
- Observer: eyes stay oriented toward the player even through occlusion.
- Ribbon animal: inside and outside exchange without visible twisting.
- Burrower: body shortens without moving either endpoint.
- Colony: one visible creature casts several anatomically different shadows.
- Mirror predator: reflection reveals a larger parent anatomy.
- Surface grazer: body passes across two sides of an architectural corner
  without bending around it.

These must stay coherent with behavior. **Do not use digital glitching.**

## 16. BUILD HIGH-DIMENSIONAL EFFECTS INTO MODEL TOPOLOGY WHEN POSSIBLE

Design geometry supporting disconnected slices, hidden alternate meshes,
reversible topology, overlapping sections, cross-section morph targets,
expanding/collapsing interior spaces, phase meshes, duplicated anatomical
configurations. Let Godot selectively reveal them. **An impossible model
beats an ordinary model under a fancy shader.**

## 17. ENSURE THE BODY SUPPORTS DREAM FIELD INCARNATION

All major critters tie back to the same `DreamFieldState`. Expose masks and
attributes for `phase_sensitive`, `incarnation`, `vascular_pressure`,
`gold_growth`, `crystal_activity`, `attention`, `contact`, `dream_w`.

Bodies should partially emerge, phase, leave residue, merge with
environmental growth, and disappear by cross-sectional collapse. The creature
and the encroachment are manifestations of the same adjacent organism.

## 18. RETOPOLOGY PRIORITY

Retopologise manually around major bends, joints, eyelids, mouths, sucker
fields, contact pads, gold sockets, membrane roots. Keep loops aligned with
deformation. Do not waste geometry on flat regions where normal maps suffice.

Preserve as geometry: silhouette, joints, folds, sockets, contact structures,
hero crystals, hero gold. Bake: pores, fine wrinkles, tiny veins, microscopic
mineralisation, fine crystal fractures.

## 19. UV AND MAP ARCHITECTURE

Anatomical UVs. Do not unwrap arbitrary procedural islands where directional
flow matters. Generate or bake: albedo, primary normal, detail normal,
roughness, AO, curvature, height, thickness, SSS mask, vascular mask, wetness
mask, gold root mask, crystal mask, contact mask, phase mask. Preserve vertex
attributes when they are more useful than textures.

## 20. MATERIAL READABILITY TEST

Every critter must pass flashlight testing. A moving player lamp should
distinguish flesh mass, microtexture, shallow subsurface depth, vascular
structures, moisture, rigid gold, crystal facets.

If everything becomes uniformly shiny, fix it. If everything becomes black
except emission, fix it. If purple becomes translucent gel, fix it.

## 21. MODEL AT MULTIPLE VIEWING DISTANCES

Far: silhouette and locomotion. Gameplay: body plan, sensory organs, major
gold. Close: sockets, veins, contact anatomy, crystals. Macro: pores,
micro-mineralisation, wetness, tiny mechanics. Do not create detail that only
works in Blender's viewport and disappears during gameplay.

## 22. RUN EXTREME POSE TESTS BEFORE FINAL SCULPTING

Contact sheet per rig: neutral, maximum bend, maximum twist, compression,
extension, contact pose, startle pose, locomotion extreme, phase state.

Check for mesh pinching, gold collisions, crystal clipping, eye intersection,
appendage penetration, lost volume. **Fix now. Do not hide deformation
failures with animation framing.**

## 23. HIGH POLY SOURCE, GAME-READY HERO OUTPUT

Keep the Blender source luxurious; it may contain millions of polygons. The
exported mesh reserves geometry for physically important structures. Build
sculpt source, retopologised hero, LODs, bakes. Do not prematurely simplify
the source because the final game asset needs optimisation.

## 24. BUILD A CRITTER REVIEW CONTACT SHEET

Per rebuilt species: hero three-quarter, front, side, top, ventral if
relevant, silhouette, wireframe, eye/sensory close-up, gold/crystal close-up,
contact anatomy, deformation poses, scale against a human, hyperdimensional
state, neutral clay render, final material render. **This becomes species
canon.**

## 25. IN-GAME REVIEW ASSET

Every critter gets an 8-15 second gameplay capture using the actual player
camera and lamp: approach, locomotion, sensory reaction, contact if
applicable, material response, one hyperdimensional event, exit or phase
behavior. **Do not evaluate only in Blender. Camera truth wins.**

## 26. SPECIES ACCEPTANCE TESTS

- **Silhouette** — can I identify it in black?
- **Anatomy** — can I explain what major structures physically do?
- **Motion** — could I identify this species from animation alone?
- **Materials** — do flesh, metal and crystal read as distinct substances?
- **Integration** — does gold visibly grow through the anatomy?
- **Contact** — does it physically interact with the environment?
- **Sensory logic** — can I tell how it detects the world?
- **Hyperdimensionality** — one impossible event unique to its species?
- **Restraint** — does it avoid firing every Dream effect at once?
- **Family resemblance** — same ecology as the Dream Tentacle without being a
  miniature copy?

If any answer is no, continue refinement.

## 27. PRIORITY FOR EXISTING ASSETS

- **P0** Preserve useful existing work. Do not destroy functional systems
  without reason.
- **P1** Rebuild silhouette and body plan. Correct generic or hose-like forms.
- **P2** Rebuild functional anatomy: sensory, locomotion, contact.
- **P3** Integrate living gold and crystal anatomy. No decoration.
- **P4** Retopologise and rig for real movement. Animation dictates topology.
- **P5** Flesh and material upgrade to current carnal standards.
- **P6** Unique movement language. Make behavior legible.
- **P7** One signature hyperdimensional behavior. Restraint.
- **P8** Capture the Blender canon sheet.
- **P9** Capture the gameplay review.
- **P10** Optimise only after visual and behavioral approval.

## 28. DO NOT HOMOGENISE THE MENAGERIE

Critters may be gorgeous, grotesque, cute, regal, irritating, timid,
predatory, parasitic, curious, playful, ceremonial or incomprehensible. Do
not force every organism toward horror aggression. The commonality comes from
physical laws and biology, not personality. A tiny harmless Dream creature
makes the larger antagonist more convincing because it implies an entire
functioning ecosystem.

## 29. FINAL QUALITY BAR

A creature is not complete because its shader looks expensive, it has lots of
polygons, it glows, it has purple flesh, it has gold, or it looks alien.

It is complete when its anatomy, topology, motion, materials and dimensional
behavior feel like aspects of one coherent organism. A viewer should
intuitively believe: this flesh has weight; that joint carries load; those
sensory structures receive information; that gold grew there; those crystals
serve a purpose; the creature knows where it is; and the impossible thing it
just did is a natural consequence of living according to more spatial
dimensions than we do.

---

## Status

**Not started.** §1's audit is the entry point and nothing may be rebuilt
before it.

The Dream Tentacle is the bar, and it is **not finished either** — see
`art/renders/dream_tentacle/CLEARANCE.md`, `.../ASSET_HANDOFF.md` and the
open items below. Two of them are the owner's own observations on first
seeing the modelled hero in game, 2026-08-22:

- **"the new tentacle is not animated at all"** — was true, now addressed at
  a first pass. All 28 deform bones are driven with a §13 motion language:
  the organism is *continuously sampling*. It commits to a direction, eases
  into a reach, holds it, and chooses somewhere new, with a peristaltic wave
  travelling out along the limb throughout, and the root held nearly still
  because the membrane grips it. Measured: the tip travels **0.203 m in 2 s**,
  asserted by the sweep so it cannot silently go back to rest pose. Blender's
  root rotation limit is a constraint, which glTF does not export, so it is
  reimplemented in the driver. Still missing per §12: layered secondary
  motion at different temporal frequencies (muscle lag, gold reseating, cilia
  springs) and any contact behaviour.
- **"the texture is not great"** — also true. The hero has a straight-strip
  UV and six vertex masks as of today, and **no baked maps at all**: no
  albedo, normal, roughness, AO, curvature or thickness. Everything visible
  is procedural from the shared stack. That is §19 and §23, unstarted.
