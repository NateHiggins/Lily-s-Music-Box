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
   not self-lit albedo and not a duplicate flashlight cone.
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

And the control that proves the thesis: **the same corridor, unlit, must be
photographable as an ordinary derelict apartment hallway with nothing wrong
with it.**
