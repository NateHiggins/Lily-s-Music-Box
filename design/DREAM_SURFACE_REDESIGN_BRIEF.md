# THE DREAM SURFACE — SHADER AND GEOMETRY REDESIGN

Written 2026-08-18 against eight owner-supplied reference plates. This replaces
the surface half of the dream's look direction. The Klimt vocabulary survives;
the idea that it is a *painting on a wall* does not.

**The thesis the plates establish:** the apartment is real. It is also a skin.
Light does not illuminate the dream — **light thins reality, and what is
underneath grows through the hole.** The growth is persistent, it accumulates
where the player has looked, and it ends in an actual rupture with something
enormous, golden and eyed on the other side.

### Owner amplification — 2026-08-18

The accumulated warp does not stop at a changed wall. As exposure rises, the
ordinary surface blends into the gold structure, the breach resolves into
**slow animated three-dimensional tentacles intruding into the room**, and the
highest stage becomes the same impossible body that can close around the
player in the embrace. The escalation remains after the inspection lamp moves
because the exposure record remains; it may not be driven from the current
flashlight cone under another name.

High exposure also returns a restrained **gold reflected light** into the room.
This is independent of the current inspection beam and rises from the durable
exposure value. It does not make the gold texture emissive: the surface remains
metallic PBR, while a bounded, governed secondary light represents illumination
returning from the revealed otherworld. It persists only for as long as that
room's exposure memory persists, never flickers, and must be measured against
the active-light and submission contracts before it ships.

### Owner target and hazard override — 2026-08-20

The new governing composition plate is
`art/reference/dream_surface/stage4_room_colonisation.png`: recognisable Orison
rooms and furnishings remain in place while wine-purple organic anatomy has
colonised corners, mouldings, doors, floors and ceilings. Gold is not a second
coat painted over it. **The inspection lamp makes seams, veins and eyes return
antique gold; the body between them remains bodily.**

The same ruling changes the dark-state contract for **hazard anatomy only**.
Substantial tentacles remain slowly animated, legible and dangerous after the
lamp moves or switches off. Their unlit state may carry a faint local
wine-purple biological afterglow. It must not illuminate neighbouring
architecture, and it must remain far below the lamp-awakened gold response.
This explicitly supersedes the blanket “zero emission / ordinary unlit hall”
wording below wherever that wording would make a live limb disappear. Dormant
scars and ordinary lineage remain near-black; the exception does not turn the
whole maze into an emissive set.

Danger and picture share an owner. Every substantial growth centerline is
registered on its source `DreamHazard`; `DreamHazardField` still performs the
one contact evaluation and commits the one existing outcome. The renderer adds
no `CollisionObject3D`, damage volume or second combat system. Fine capillary
veins may be visual-only, but no limb that reads as a traversable obstacle may
be harmless. The Vantry signal trunk is excluded: its authored lesson is that
its arc is live only under the lamp, so giving it a dark-live body would lie.

Finally, a dream room is a memory of the Orison, not an empty procedural box.
Furnishing may be borrowed from production Orison prop constructors only by
extracting their finished meshes. Waking `FunctionalProp` owners, collisions,
lights, audio and interaction verbs may not cross that boundary.

**Implementation checkpoint — 2026-08-20, wall architecture.** The room is no
longer only an exact footprint with waking props inside it. Every remembered
nonblank generation now receives the Orison's shallow construction grammar:
140 mm skirting, canonical 1.32 m dado and framed corridor wainscot, 2.18 m
picture rail, stepped cornice below the exact 3.015 m ceiling, casings following
the live 0.91 × 2.13 m door schedule, and a pressed ceiling medallion. These are
two visual-only MultiMeshes at most and never alter wall, aperture or navigation
authority. Load-bearing hazard crawlers terminate in shallow closed-lobe grafts
and same-surface capillaries which overlap that millwork. This closes the
"empty procedural box" defect only. It does **not** claim workstream C's
tessera/grout/cracked-leaf relief or D's torn breach and impossible depth.
Production proof: `art/renders/dream_orison_walls_v1/README.md`.

### Production rendering reconciliation — 2026-08-20

The owner has supplied a broader rendering proposal whose useful diagnosis is
accepted: the current proof is too black to read the Orison, the live growth
has one coarse magenta material response, and adding more impossible geometry
before those two foundations are solved would only hide a weak picture behind
more effects. The target balance is now explicit: **roughly sixty percent
recognisable 1928 Orison apartment and forty percent impossible organism in an
establishing frame.** Darkness remains a game verb, but the screenshot may not
depend on a crushed monitor to feel dangerous. Plaster, wood, door casings,
radiators and furniture must remain readable enough to establish the violated
room; the service lamp then finds the gold and the danger.

The proposal is integrated under the following production rules rather than
adopted as a parallel dream implementation:

1. **One authority for space.** `DreamAtlas` and `DreamRoomBuilder` remain the
   only topology, aperture, navigation and forgetting owners. Locally ordinary
   rooms and globally impossible adjacency are already their contract. Any
   later portal, mirror room, recursion window or gravity-view is a rendering
   consumer of an atlas-authored fault. It may not maintain another room graph,
   choose a destination or become a second navigation system.
2. **One authority for danger.** Every substantial animated limb remains a
   registered path on its source `DreamHazard`; fine capillaries and material
   motion may be visual. Eyes are presentation and attention, not damage. No
   shader, portal camera or animation node receives an independent hit volume.
3. **Three material layers, one submitted surface.** The organism is evaluated
   as a reusable subsurface-tissue layer, a restrained wet microfilm and a
   living-gold phase. These are separate shader functions and tunable masks,
   not three overdraw passes: the dream is submission-bound. Deep plum is the
   mass; violet/magenta and rose explain thickness and wet tissue; antique gold
   occupies seams, vessels, stress lines and eyes rather than coating the body.
   Gold remains lamp-dominant. Only the already-ruled, local wine-dark
   biological afterglow may remain when the lamp is absent.
4. **Motion at three scales.** Macro motion is a slow room-scale contraction
   in authored anatomy, meso motion is tendon/fold travel on growth surfaces,
   and micro motion is a wet optical shimmer. No camera roll, flashing,
   chromatic assault or topology change occurs in view. Material motion must
   never imply that a static collision silhouette moved into the player.
5. **Architecture is where infection begins.** Corners, door and window
   casings, mouldings, cracks, radiator penetrations and floor/wall junctions
   are the anchor vocabulary. Furniture is remembered Orison furnishing first
   and may later receive bounded overlay infection; it is not replaced by
   generic sci-fi growth. A frame needs one dominant breach or arch, secondary
   connective growth and sparse tertiary eyes. Equal-detail noise everywhere
   is a failed composition even if every shader is technically correct.
6. **Eyes are a family, not scattered decals.** The later eye pass owns a
   deterministic seed, scale, blink phase, gaze target and local orientation.
   Closed or half-lidded resting states dominate; direct camera tracking is a
   sparse event. The first batched geometric eyes remain valid prototypes, not
   completion of this system.
7. **Phase change is state, not a bag of effects.** Flesh, gold/plasma, frost
   and liquid-metal states share one corruption mask and transition controller.
   They arrive only after the base flesh and living-gold material reads in a
   still. Every phase owes its own narrative trigger, luminance range and
   accessibility proof before it enters a case profile.
8. **Warp is local and compositional.** A later warp field may provide bounded
   UV/refraction displacement around an authored impossible intersection. It
   may use layered rotational fields or transformed SDFs, but cannot become
   full-screen noise. The ordinary Orison outside the field is the control that
   makes the impossible region intelligible.
9. **Portals escalate by proof.** First prove one bounded view-only aperture
   reusing the atlas's room renderer; then prove recursion depth 1; only then
   profile depth 2–4 with distance and screen-coverage gates. RECURSION remains
   **priced but unlicensed** as enterable space. The proposal's depth-four
   target is a quality ceiling, not permission to build four live worlds.
10. **Quality and diagnosis are part of the feature.** Low/medium/high tiers
    control portal depth, eye count, distortion samples and secondary motion,
    never room truth or hazard truth. Required developer views are base Orison,
    corruption mask, gold phase, tissue thickness, eye anchors, hazard paths,
    warp field, portal depth and overdraw/submission census.

The order is therefore: (R1) restore photographic readability and land the
layered tissue/wet/gold substrate; (R2) complete surface relief and
architecture-bound transition masks; (R3) complete the deterministic eye
family; (R4) build the torn breach and its cheap impossible depth; (R5) add
bounded phase states and warp; (R6) prove one view portal; (R7) decide whether
recursive/enterable faults earn their cost. A production validation pocket
must eventually frame three connected remembered rooms, one dominant
corrupted arch, real furnishings, 5–12 compositional eyes, a phase transition,
one bounded distortion field and one impossible view. It is a proof consumer
of production owners, never a second showcase-only dream.

**Implementation checkpoint — 2026-08-20, R1 substrate.** R1 is landed. The
Klimt filter now gates glaze, ink, jewels, ghost colour and impasto—not only
leaf—through the durable `eaten` boundary, so uneaten plaster can finally remain
the photographed Orison material the shader promised. Architectural materials
start at bounded 0.26–0.46 consumption. The live body reads cellular tissue,
tendon folds, warped gold vessels and wet microfilm from reusable functions in
`dream_corruption_layers.gdshaderinc`, still as one submitted surface. A low
cool lift, bounded carried black level and bounded warm practical restore the
near apartment without waking gold or changing hazard truth. Smoothed graft and
tube geometry spends vertices rather than draws. Production proof and rejected
tunings: `art/renders/dream_rendering_r1/README.md`. R2 was the next dependency
and is closed by the checkpoint below; R1 did not license portals, phase states
or RECURSION.

**Implementation checkpoint — 2026-08-20, R2 relief and anchors.** R2 is
landed. Every room-local Klimt material now receives the authoritative room
bounds, exact clear ceiling and one architectural surface class. The one
durable exposure field is biased—never replaced—toward real floor/wall joints,
corners, skirting, dado, picture rail, cornice, casings/lintels, shafts and the
pressed ceiling rose. A reusable shader include supplies 82 mm hand-set
tesserae with recessed narrow grout, large concentric bosses, raised rims and
branching leaf cracks. Stage 1 tessellates the existing spiral drawing rather
than wallpapering bare plaster; Stage 2 raises the bosses through it. A
single-step parallax shift and meter-space normal gradient provide 9–12 mm
tessera relief and 26–42 mm medallion relief on the existing submitted surface.
Collision, aperture, topology and danger ownership are unchanged. Three
production debug modes expose architecture pull, relief height and stage bands.
The rejected full-plane graph-paper pass and production proof are recorded at
`art/renders/dream_rendering_r2/README.md`. R3, the seeded eye family, is now
closed by the checkpoint below; R2 did not license the breach, warp, portals
or RECURSION.

**Implementation checkpoint — 2026-08-20, R3 eye family.** R3 is landed.
Each eligible danger now supplies five sparse compositional anchors to the
existing one-surface hazard body. Every eye publishes a stable id and source
hazard plus its actual anchor, 0.76–1.34 scale, local orientation, ±14 degree
roll, resting aperture, 0.045–0.073 Hz blink phase, authored gaze target and
behavior. Four of every five rest closed or half-lidded. Across the complete
live batch exactly one open eye may track the production camera; only its iris
and pupil move, within 0.28 of its own radius. Root, branch-tip and room-centre
gazes remain fixed. A wine-dark physical lid, antique sclera, iris and pupil
are nested at separate depths so the family reads as eyes rather than repeated
gold buttons. All geometry and per-eye controls remain vertex data in the
existing submitted surface—no eye node, material, collision, light, damage
volume or attention manager was added. `DREAM_EYE_DEBUG=1` isolates rest state
and the single tracker; `=2` isolates gaze classes. Production beauty and both
diagnostic sets are recorded at `art/renders/dream_rendering_r3/README.md`.
R3 did not license warp, phase states, portals or RECURSION.

**Implementation checkpoint — 2026-08-20, R4 torn breach.** R4 is landed.
One eligible dark-live danger in the live batch deterministically owns one
dominant 1.28 × 2.24 m wound on its actual Atlas room wall. Eighteen seeded
edge points, broken plaster, six exposed lath pieces, an interrupted living
rim and seven shallow rubble pieces provide real silhouette inside the
existing one-surface `DreamHazardGrowth` mesh. One double-wound flat face then
evaluates nine bounded nested angular frames, false-depth cables and a single
vanishing-point eye in the existing lineage shader: 87 mm of physical recess
claims 32 m of apparent depth without repeated geometry or another draw. The
authoritative wall is deliberately intact and still catches a physics ray.
No new door, graph edge, room, camera, `SubViewport`, `World3D`, collision,
damage or hazard owner exists. `DREAM_BREACH_DEBUG=1` isolates face,
plaster/rubble and lath ownership; `=2` displays recession bands, internal
cables and the eye. Production beauty, diagnostics, rejected readings and
proof are recorded at `art/renders/dream_rendering_r4/README.md`. R5, bounded
phase/warp state and a continuous exposure-owned reveal, is now the pickup.
R4 does not license a view portal or RECURSION.

---

## WHAT THE PLATES SHOW — FOUR STAGES OF ONE SURFACE

The references are not four different looks. They are **one surface at four
levels of exposure**, and the redesign's job is to make a wall walk this path.

**Stage 1 — INFECTION.** *(plate: torch on right wall + floor)*
Rough plaster and speckled terrazzo, mundane. Where the beam pools, a gold
mosaic of tight spirals has appeared — tessellated, grouted, slightly raised,
following the wall and floor planes exactly. The frontier is **organic and
wavy**, not a cone edge: it bulges and retreats like lichen or frost. Beyond
the beam, the same corridor is bare plaster. The far end is a bare bulb and
ordinary dark.

**Stage 2 — MEDALLION.** *(plate: gold wall + spiral floor, bulb at end)*
The infection has taken a whole wall and is crossing the floor. Tight spirals
have grown into large concentric medallions in raised gold leaf and mosaic.
**Dark inlay tiles appear among them — the first eyes**, stylised, flat,
triangular and lidded, in blue-black and bone. The relief is real: the discs
emboss out of the plane and catch the light on their edges. Plaster is still
visible above and beside, so the boundary is still legible as *advance*.

**Stage 3 — RUPTURE.** *(plate: vertical tear, "SERVICE ELEVATOR / BASEMENT")*
The wall has torn open in a ragged vertical wound. Masonry and lath break
outward at the edges. Inside is **not a room** — it is a dense knot of golden
cables, and behind them a receding angular lattice of nested frames, maze-like,
Greek-key, going back much further than the wall is thick. **A single eye sits
at the vanishing point of that lattice.** Cables spill out over the floor.

**Stage 4 — BREACH.** *(plate: full hole, rubble, tentacles across the hall)*
The hole is body-sized and rubble litters the floor. Golden tentacles —
segmented, ribbed, filigreed, torso-thick down to hair-fine — erupt into the
corridor, arc overhead, cross the floor in front of the viewer, and run past
the camera. **They are covered in eyes**: small ones clustered like scales
along their length, and one large lidded eye with a dark pupil at the mouth of
the breach. Behind everything, the nested golden frame-tunnel recedes forever,
visibly deeper than the building can contain.

---

## WHY THE CURRENT IMPLEMENTATION CANNOT GET THERE

`game/shaders/dream_klimt.gdshader` is a good surface filter and a bad organism.
Five specific gaps, in order of how much they block the target:

1. **Exposure is instantaneous, not accumulated.** `heat` is recomputed every
   frame from the lamp cone, so gold appears while lit and vanishes when the
   beam moves. Every plate shows the opposite: the conversion **stays**. This
   is the single biggest change and everything else depends on it.
2. **The frontier is a cone falloff.** `smoothstep(lamp_cos_outer, ...)` gives
   a smooth elliptical edge. The plates have a ragged, self-similar, organic
   growth front.
3. **The gold is a flat albedo mix.** `albedo = mix(real_wall, albedo, eaten)`
   is paint. The plates have genuine relief — tesserae with grout depth,
   embossed medallions, cracked-leaf edges catching light side-on.
4. **There are no eyes as elements.** MOTIF_EYE is a pattern function. The
   plates need discrete eye instances that appear at stage 2, gain lids and
   depth at stage 3, and track the player at stage 4.
5. **Nothing ever changes geometry.** Stages 3 and 4 are not shading. They are
   a hole in a wall, rubble, a volume behind the wall, and tentacle meshes in
   the room. No fragment shader reaches them.

---

## THE WORK, IN DEPENDENCY ORDER

### A. THE EXPOSURE FIELD — persistent, per-surface, accumulating
The foundation. Each room needs a low-resolution **exposure buffer** that
records how much lamp a given point on its surfaces has received, monotonically
increasing, persisted for as long as the room is in the pocket.

- The lamp writes into it; nothing erases it.
- Resolution can be very coarse (the growth front is noise-warped anyway).
- It must be keyed to the room, and the room is already named by path — the
  atlas's `room_id` and `aspect(id, salt)` give a free per-room seed so no two
  rooms grow identically.
- Rooms leaving the pocket may lose it. That is correct and thematically right:
  the building forgets what you did to it once it forgets the room.
- **Also feed it from time and decay**, not only from the lamp. The owner's ask
  is that the texture evolves "as time in the maze continues AND light is cast."
  `DreamAtlas.decay(id, depth)` already supplies the first term.

### B. THE GROWTH FRONT — organic, not optical
Threshold the exposure field through domain-warped fbm so the boundary bulges
and creeps. It should read as *spreading*, with fine filaments running ahead of
the main mass. Stage boundaries are thresholds on the same field, so a single
surface can show stage 1 at its edge and stage 3 at its centre — which is what
every plate actually shows.

### C. THE SURFACE STAGES — relief, not paint
Per-pixel work is free on this frame (TASKS.md §P: submission-bound, not
fill-bound), so spend it:
- Stage 1: fine spiral mosaic, real grout depth in the normal, slight height.
- Stage 2: large concentric medallions, embossed, with cracked gold-leaf edges;
  dark inlay eye-tiles seeded from the per-room hash.
- Parallax or true displacement for the tesserae. **Height maps already ship
  unused** — 227 library materials carry them and nothing samples them.

### D. THE BREACH — geometry, and the cheap way to fake its depth
Stage 3+ replaces a wall panel with a torn-edge hole plus a recessed volume.
- **Use interior mapping for the nested frame-tunnel.** It renders a convincing
  infinitely-receding interior on a single flat quad with no geometry and no
  extra draws — exactly right for "deeper than the building can contain," and
  it is the cheapest possible answer to the 7th-dimension read.
- Torn edges want real silhouette, so the hole needs actual geometry: a ring of
  broken lath and plaster shards, plus rubble on the floor.
- The eye at the vanishing point can live in the interior-mapped layer.

### E. TENTACLES — the only genuinely expensive item
Splined tubes with ribbed, filigreed, eye-studded surfaces, emerging from a
breach and crossing the room.
- Their extent and motion are a monotonic function of the same durable exposure
  field as the surface stages: no tentacle pops into existence when the beam
  crosses a threshold, and none retracts merely because the beam moves away.
- At the highest exposure they become the geometry of the embrace. Proximity
  may commit that ruled outcome, but growth cannot become an unexplained damage
  volume or a second combat system.
- **Watch the draw budget.** The frame is submission-bound; a forest of
  individually-drawn tentacles is exactly the wrong cost. Batch or instance
  them, and keep the count small and the silhouettes large.
- Slow, continuous motion. Never a jump cut, never a strobe.
- They must not block navigation, or must be solid and routable — decide
  deliberately, because `DreamPursuer` moves by assigning position and only the
  waypoint graph keeps it inside architecture.

### F. THE EYES
Flat inlay tiles at stage 2; lidded and parallaxed at stage 3; at stage 4,
discrete instances on tentacle surfaces whose pupils track the camera. Tracking
is a shader-space rotation of the pupil, not an animated mesh.

---

## CONSTRAINTS THAT ARE NOT NEGOTIABLE

1. **Gold is metallic, never an emissive texture.** Below the high-exposure
   reflected-light threshold it catches the lamp and is otherwise as dark as
   everything else. Above that threshold, one bounded secondary light may
   return warm gold into the room as ruled above; it is a governed world light,
   not self-lit albedo and not a duplicate flashlight cone. **2026-08-20
   exception:** live hazard tissue may carry the faint local biological
   afterglow ruled above. The gold response itself remains lamp-dominant.
2. **The dark stays navigable.** The real building is dimly readable at the
   feet without the lamp. The player can always move; they cannot always see
   what is coming through.
3. **Measured bones.** 2.08 m corridors, 0.91 m doors, 3.015 m clear ceiling.
   Whatever grows through them, the dimensions stay the waking Orison's.
4. **Hazards read as eyes, and only hazards do.** In a maze built to lose you,
   the pattern says what a thing is. Dormant scars must stay visibly dead —
   they never turn gold at any light level, which is already implemented.
5. **Safety, surviving every ruling:** no flashing at photosensitive
   frequencies; no forced camera roll, fisheye or chromatic assault. However
   far the geometry folds, the camera stays level.
6. **Perf discipline.** GPU per-pixel work is free here; DRAW SUBMISSIONS are
   not. Every new material instance, mesh and particle is the expensive axis.
   The dream station now establishes 1.71 ms / 45 calls before the persistent
   field and 1.90 ms / the same 45 calls after it. Tentacles and the reflected
   light must preserve that station as an A/A/B contract rather than borrowing
   its present headroom as permission.

---

## ACCEPTANCE

Not "does it run." Reproduce the plates:
- A wall that is stage 1 at its edge and stage 3 at its centre, in one frame.
- Gold that persists after the beam has moved away, and keeps growing.
- A frontier no viewer would describe as the edge of a torch beam.
- A breach whose interior is visibly deeper than the wall is thick.
- One tentacle crossing in front of the camera, lit only where the lamp finds
  it.

And the control that proves the thesis: an unlit corridor without a live limb
must still be photographable as ordinary derelict Orison. A corridor carrying
a live limb is no longer allowed to claim that nothing is wrong: its geometry
keeps moving and its low wine-dark afterglow keeps the danger barely legible.
