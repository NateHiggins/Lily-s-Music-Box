# H1 — THE HERO'S BAKED ANATOMY

The hero had **no baked maps at all**. Everything visible was procedural from
the shared material stack — which is exactly what a generated margin palp
also has, so under ecology §36 the hero could not be visually superior to
one. The owner's words were *"the texture is not great"*.

    blender -b art/blender/dream_tentacle.blend \
        -P art/blender/scripts/bake_dream_tentacle.py

One RGB map, `T_dream_hero_anatomy.png`, carrying the three things a shader
**cannot** know because they are facts about geometry rather than about a
noise field:

| channel | what | measured range |
| --- | --- | --- |
| R | ambient occlusion | 0.000 – 1.000 |
| G | curvature, from pointiness | 0.573 – 0.941 |
| B | thickness, occlusion sampled *inside* the mesh | 0.345 – 1.000 |

In the shader: thickness replaces the coarse per-vertex guess and drives real
subsurface scattering; curvature makes crests polish and creases hold fluid;
AO multiplies the procedural cavity term rather than replacing it.

`01_bake_off.png` vs `02_bake_on.png` are the same frame at
`anatomy_strength` 0 and 1. With the bake, the flesh separates into a dark
perfused upper surface and a molten lower one, the wetness beads, and the eye
reads as a distinct globe. Without it, everything flattens toward a uniform
gold-brown.

## Two wrong turns, kept here because they were instructive

The first bake came out in hard rectangular blocks. **Raising samples
eightfold changed nothing** — which, again, is what says a result is
structural rather than noisy.

Hiding the ninety-four riders cleaned it up completely and produced AO of
0.88–1.00, **mean 0.996**: a channel that is present and carries nothing,
because a mostly convex limb does not occlude itself. Widening the sampling
distance fivefold moved that mean by 0.002.

Which settles it, and reverses the diagnosis. **This body's occlusion IS its
riders.** The blocks are rectangular in UV space because a gold plate spans a
few ring segments and a few rings, and a plate seated into flesh genuinely
does black out what is under it. The map only looked broken because I was
expecting soft AO from a shape that has none.

`BAKE_ISOLATE=1` keeps the riders-hidden behaviour for comparison.

## Still owed

- Albedo, normal and detail-normal maps. The stack still invents all colour
  and micro-relief procedurally; this map only gives it geometry facts.
- The riders have no UVs, so none of them are baked. The flesh cage is the
  only mesh carrying a strip.
