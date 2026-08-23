# DREAM SALIVA — THE RESIDUE THE CREATURE LEAVES

> Owner direction, 2026-08-22, verbatim:
>
> *"I want the dreamworld tentacle to leave an iridescent holographic
> reflective saliva goo on everything it touches that crystalizes like
> superchilled frost in a otherworldly metalic neon rainbow with dimensional
> breaking properties that persist and decay like its being eroded by an eon
> of time in a couple seconds"*

## What this is

Not a decal. A **material state** that spreads onto whatever the creature
touches, and then lives out an entire geological history in two or three
seconds.

Read the ruling as five separate demands, because each one fails differently:

1. **Iridescent, holographic, reflective.** Structural colour, not a tint —
   the hue must change with view angle and with the lamp's angle. A fixed
   rainbow gradient painted on a surface is the failure mode.
2. **Crystallises like superchilled frost.** It does not appear; it
   *propagates*, the way frost runs across glass — branching, directional,
   faster along seams and edges than across open faces.
3. **Otherworldly metallic neon rainbow.** Metallic, not glassy. Neon, not
   pastel. This is the palette that separates it from ordinary wet.
4. **Dimensional-breaking properties.** It is the antagonist's substance, so
   it should carry the same law the rest of the Dream does — the surface it
   sits on should stop being reliably three-dimensional where the goo is
   thick. Tie to `DreamFieldState`.
5. **Persists and decays as if eroded by an eon in a couple of seconds.**
   The decay is the point and the hardest part. It must not fade uniformly.
   It should *erode*: pit, crack, thin at the edges, lose its structural
   colour before it loses its geometry, and leave a ghost.

## The shape of the implementation

- **Where it goes.** Contact events already exist (`DreamContactSensor` for
  the procedural limb; the modelled hero needs its own). A contact writes a
  patch: position, normal, radius, birth time, seed.
- **How it draws.** The building's surfaces already run a shared surface
  shader. The residue is most cheaply a screen-independent layer in that
  shader, driven by a small array of patches, rather than spawned geometry —
  the frame is draw-call bound (see `DT4_PERFORMANCE_REAUDIT.md`), so new
  draws are the expensive thing and per-pixel work is nearly free.
- **The frost front.** One radius that runs outward fast and then stops, with
  a noise-warped boundary and a bright leading edge. Growth must be visibly
  *directional along the surface*, not a circle scaling up.
- **The clock.** Every patch carries its own age. The stages want to be
  authored, not lerped: wet → structural colour blooming → crystallised →
  fracturing → pitted → ghost. Different channels should die at different
  times, which is what makes it read as erosion rather than as a fade.

## Acceptance

Camera truth, as ever. In the canonical review frames, under the player's own
lamp, at gameplay distance:

- The hue must visibly change as the lamp moves. If it looks the same from
  two angles it is a painted rainbow and has failed.
- The crystallisation must read as *spreading*, catchable in the act.
- The decay must read as **erosion**, not as opacity going down.
- It must be legible as something that was left *by* the creature — the same
  substance as its body, not a generic VFX.

## Status

**Built, first pass.** `DreamResidue` + `dream_residue.gdshader`, fed by the
hero's `touched` signal now that H3 gave it contact. Photographed across a
patch's whole life in `art/renders/dream_saliva/`.

Four of the five demands are served: it propagates as a warped front with a
bright leading edge; the hue comes from view angle so it moves as you move;
it is neon and metallic rather than pastel; and the decay is erosion — the
structural colour dies first, then the substance pits and cracks, leaving a
holed stain rather than a fade.

**All five are now served.** The fifth was built last, and it is the one the
rest of the Dream's law had to reach into.

**Dimensional-breaking.** The goo is not a film on the wall: it is a
CROSS-SECTION of something with a fourth extent, and the wall shows only the
slice at the Dream's current `w`. Parts of it therefore have no cross-section
here at all — holes with hard, unweathered edges, which is a different thing
entirely from the soft pitting the erosion opens, and which MIGRATE as the
slice advances rather than only widening. It is the field's own equation,
`r_visible = sqrt(r² − w²)`, applied to a smear of spit, and it is gated on
the frost: fresh spit is a fluid, and it is the crystal that has the extra
axis. Alongside it, the crystal interior is sampled at a view-dependent offset
so it swims against the surface as you move past — a window behaves like that
and a stain does not. That is the half you notice while walking; the holes are
the half you notice while standing still.

A patch records the slice it was LAID at. `dream_w` only ever increases — at
0.115 per second it moves about 0.41 across a patch's whole life — so an
absolute reading would strand every patch slices away from its own substance.

### The capture

`SHOT_MODE=saliva` on the staged room, because the two acceptance tests here
cannot be settled by a normal take. The decay has to read as erosion rather
than as opacity going down, which needs the same patch at known ages; and the
colour has to be structural, which needs the same patch at the SAME age from
more than one place. A patch laid wherever the creature happens to reach gives
neither, so one is laid by hand on a flat panel.

```bash
SHOT_DIR=/tmp/saliva SHOT_MODE=saliva SHOT_WARM=6 godot --path game res://tests/DreamStageShot.tscn
```

Three things that capture caught, none of which was visible any other way:

- **The facets were a checkerboard.** Flooring a plain grid gave square cells
  in a square lattice — the one pattern frost never makes. The lookup is
  warped before it is cut.
- **Two thirds through its life the goo was a few specks.** The pitting, the
  cracking, the edge retreat and the new cross-section cut all compounded, and
  the result was a fade with extra steps. The erosion is slower and the ghost
  keeps most of its opacity; what goes is the COLOUR.
- **The colour died at two thirds**, leaving half the life as a colourless
  smear. It now goes late, just before the substance follows it.
