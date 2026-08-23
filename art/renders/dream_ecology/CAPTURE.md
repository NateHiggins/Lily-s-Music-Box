# PHASE 16 — THE CANONICAL DREAM ECOLOGY CAPTURE

`SWEEP_MODE=ecology` — 480 frames at 24 fps, twenty seconds, in an encroached
flat under the player's own lamp, with `DreamGlobalAttention` fired once at
the two-thirds mark so there is an independent ecology to interrupt and time
left to watch autonomy return.

    art/renders/dream_ecology/dream_ecology_capture.mp4

## The beat sheet

It logs what **actually happened**, not what was intended, because a capture
claiming sixteen behaviours and showing four is worse than one showing four
and saying so. All seven tracked beats fired in the take:

| beat | |
| --- | --- |
| a palp branched | yes |
| global attention seized the ecology | yes |
| a seam grazer occupied both sides of a wall | yes |
| a fold crab shortened a leg | yes |
| residue was on a surface | yes |
| a critter approached the hero | yes |
| a critter was shoved by a palp | yes |

Population at the end: **67 appendages** across three tiers and six
archetypes, running eight of the ten movement primitives, with 61 feeling a
neighbour, 23 cooperating and 16 branches unfolded; **8 critters** of two
species, 4 of them on both sides of walls.

## What this capture does NOT show, and why

**The three levels are not co-framed.** The camera is tight on the hero — 1.75 m
— and the margin and critters are elsewhere in the flat, so the video shows
the hero magnificently and the other two levels barely. §34 asks for all three
at once and this is not that yet.

The obstruction is physical: this wall has a partition about 2 m out, so the
camera cannot pull back far enough to hold the hero and a palp cluster in one
frame. Fixing it properly means staging the shot in a room chosen for it —
§34 names a radiator, a sofa, corners and seams — rather than in whichever
flat the case happens to use. That is a staging decision, not a systems one.

## What the framing cost, and what it taught

Seven attempts, each failing differently, and only the last two for
interesting reasons:

1. Orbiting the hero's root put the camera *inside the wall it emerges from*.
2. Standing off along the wall normal landed *in a glass door*.
3. Choosing "the clearest wall" chose a boundary wall whose clear side is the
   **landing**, four open metres of somewhere else entirely.
4. `_view_dir` samples the whole sphere and found a clear line **from outside
   the building at night**.
5. A partition sat between 1.8 m and 2.25 m from the hero.
6. Calling `hero.setup()` again to move it **instantiated a second creature** —
   it appends to the mesh list rather than replacing.
7. And the one worth remembering: the camera sat **0.67 m from the hero and
   photographed an empty room**, because the creature was mid *cross-sectional
   withdrawal* and its shader was discarding every fragment. Its own
   hyperdimensional law made it invisible to its own review capture. The
   capture now forces it present before rolling.

The diagnostic that ended it was printing the active camera and the hero's
geometry bounds instead of reasoning about them — the arithmetic had been
right for three attempts running.
