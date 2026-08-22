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

**Not started.** Recorded here so the ruling is not lost. Depends on the
modelled hero having contact events at all, which it does not yet.
