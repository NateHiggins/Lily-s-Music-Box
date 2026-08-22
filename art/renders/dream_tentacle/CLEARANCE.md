# TB-15 / §23 — ANIMATION CLEARANCE, MEASURED

> *"Before finishing detail, test S curve, hard distal curl, figure-eight
> contact, 90° bend, 180° tip curl, axial twist… Watch for gold plates
> colliding, crystals entering flesh, eye deformation, cilia penetrating the
> cornea, sucker overlap, membrane collapse. Fix before final polish."*

Eyeballing seven poses across ninety-five parts is not a review, it is a hope.
`art/blender/scripts/check_dream_tentacle_clearance.py` drives the rig through
the poses and measures the failures that matter: parts **sinking** into the
flesh, and parts from different systems **colliding**. Exit code is the number
of failures.

    blender -b art/blender/dream_tentacle.blend \
        -P art/blender/scripts/check_dream_tentacle_clearance.py

Current state: **PASS**, 0 failures across all seven poses, and the bind gate
still 0/95.

## The check found a shipping bug before it found anything about poses

It passed on the very first run, which is exactly when to doubt the
instrument. `CLEAR_SELFTEST=1` shoves a crystal onto the limb's axis — deep
inside the flesh, unambiguously — and re-runs. It still said PASS.

The reason was that **the entire flesh cage was wound inside out**. Signed
volume negative; the outermost +X vertex carrying `normal.x = −0.99`. Every
"is this point inside the flesh" question was answered backwards, so seated
pieces read as buried and buried pieces read as clear.

Blender never showed this because EEVEE shades both sides. **Godot culls back
faces**, so the hero creature's body would have rendered inside-out in the
engine. A grey test cannot catch it; a test that asks the mesh a question
about its own inside can. The winding is fixed, and the signed volume is now
asserted on every run.

## The 112 mm that would not move

With the normals fixed, one failure remained: `MEMBRANE_ROOT` sinking
**112 mm** into the flesh in the three poses that bend sideways. Four fixes
went by:

1. Anchor the membrane rigidly to the root bone — 112.0 mm.
2. Grade it by radius, inner edge following the flesh — 111.9 mm.
3. Limit the root bones' rotation on the rig — 111.9 mm.
4. (and the original soft binding) — 112.0 mm.

A number that does not move by more than 0.3 mm when you change the thing it
claims to measure is not measuring it. What it actually saw: **a 1.66 m limb
curled into an S comes back down and touches its own collar.** That is
contact, and for the one part that wraps the limb, "vertices inside the flesh"
says nothing at all about collapse.

Membrane collapse is now measured as what it actually is — **the aperture's
inner edge tearing away from the flesh**, which is what would open a hole
around the limb and stop the creature reading as coming *through* the surface.

Two of those four changes were kept, on their own merits and **not** because
they fixed anything:

- **The graded membrane binding** implements §13's "bulge, thin, stretch,
  cling" directly: the inner edge travels with the limb, the rim stays with
  the wall, the sheet between takes the blend.
- **The root rotation limit** is what §13 and §14 describe — the collar grips
  the first few centimetres of limb, so it cannot swing freely. It is a real
  constraint on the rig rather than a rule in a document, so an animator who
  over-rotates the root gets clamped.

## Known, unresolved

The aperture measures **46.4 mm from the flesh at rest**, which is further
than a collar around a limb should sit. It is probably a sampling artifact —
the check samples ~48 vertices per part, so the "inner edge" of an 896-vertex
solidified and subdivided sheet is approximate — but it has not been run down,
and until it is, the aperture metric is measuring growth from a baseline it
may not have located correctly.
