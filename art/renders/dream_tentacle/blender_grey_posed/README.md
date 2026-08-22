# TB-13 — DOES IT HOLD TOGETHER WHEN IT MOVES?

The grey test proves the sculpt. It cannot prove the *creature*: a model
rendered only in rest pose looks identical whether it is one bound body or
ninety-five separate parts that happen to be sitting in the same place.

So the rig now gets bent hard — every `DEF_` bone takes a few degrees,
alternating axes so the result is an S rather than an arc — and the same
angles are re-shot. Anything not truly bound stays behind in mid-air.

    GREY_POSE=bend blender -b art/blender/dream_tentacle.blend \
        -P art/blender/scripts/render_dream_tentacle_grey.py

## What it found

**Nothing was bound.** `skin()` added an `ARMATURE` modifier to each of the
ninety-four systems and stopped there — but a modifier with no vertex groups
deforms nothing. The eye, the lids, every gold plate, every sucker, every
crystal was unattached. The glTF exporter had been printing `has no skin,
skipping` once per object on every single build, for as long as the script
has existed, and it scrolled past as noise.

The first fix — bind each piece rigidly to its nearest bone, which is what
the docstring had always *claimed* — was better and still wrong. The
companion check measured it:

    12/95 riders drift past 4.0 mm
    DRIFT 15.5 mm  GOLD_SPUR_07      12.5 -> 28.0 mm from flesh
    DRIFT  9.2 mm  GOLD_CRESCENT_06   5.0 -> 14.2 mm from flesh
    DRIFT  6.3 mm  CRYSTAL_03         3.1 ->  9.4 mm from flesh

A gold spur 28 mm off the body is hanging in space. The cause: at a joint the
flesh takes a *blend* of two bones while a single-bone rider takes one of them
pure, so the two diverge exactly where the creature bends most.

**The fix is to inherit.** Every rider vertex copies the bone weights of the
nearest cage vertex, so each piece deforms precisely as the flesh beneath it
does. It still reads rigid — its whole footprint sits on nearly identical
weights — but it is welded by construction rather than by hoping one bone is
close enough.

    0/95 riders drift past 4.0 mm — PASS

## The gate

`art/blender/scripts/check_dream_tentacle_bind.py` poses the rig and measures,
for every rider, the **median distance from its own vertices to the flesh**,
before and after. Exit code is the number that drift.

It measured centroids first, and reported two false failures: a dendrite tree
and a membrane skirt span a large region, so their centroids sit tens of
millimetres off a curved surface and *move* when the limb bends even though
every vertex is welded correctly. That measured the shape, not the binding.

## The membrane, fixed the same way (§13)

The posed frames showed it for what it was: a single-sided sheet with a
three-fold star border — folded card, not tissue. §13 asks for *"a thick
irregular flower/socket… folds stretching toward the root, irregular
attachment border, tension wrinkles"*, and the thing that makes the creature
appear to extrude through reality rather than through a hole.

- **Thickness.** It had none. A zero-thickness sheet is the loudest possible
  tell that something is not made of meat. Solidify at 10% of the root radius.
- **The border** is broken at three scales instead of one, and only ragged at
  the rim — at the root it is flesh.
- **The folds were invisible.** Gathers at 4 mm and wrinkles at 2 mm on a
  270 mm sheet read as a smooth white disc, which is exactly how the
  room-facing shot came out. Raised roughly six-fold, and pushed into the
  *radius* as well as the lift — a fold that only moves along the axis
  disappears the moment you look at the sheet face-on.
- Pulled in from 4.6× the root radius to 3.4×; at the old size it dominated
  every frame it appeared in.

**And the root was an open pipe.** It was left open "for the membrane to
close", and the membrane does not close it: photographed from beneath the
socket you look straight up a hollow tube into the inside of the creature.
It now carries a shallow dome pushed up into the limb.

Two shots were added, because faults hide in the angles you do not take:
`11_membrane` (the membrane read as a flat fan in every profile shot because
every profile shot sees it edge-on) and a corrected `09_root`, which at 0.55 m
had been filling the frame with featureless white.

## Standing faults in these frames

- The distal third reads as a **stack of discrete beads** rather than
  continuous flesh with swellings in it.
- Gold plates read as thin flat shards when seen edge-on.
- §13 also asks the membrane for **gold anchors and crystal nodules**. It has
  neither yet.
- §23's clearance poses (figure-eight, 180° tip curl, axial twist) are not
  tested; only the S-bend is.
