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

## Running down the aperture's 46 mm

The first aperture reading said the collar sat **46.4 mm off the flesh at
rest**, which is not where a collar around a limb sits. I guessed sampling
artifact. It was not — and it took three more corrections, each to the
measurement rather than the model, before the number meant anything:

1. **Sparse sampling.** ~48 vertices of an 896-vertex solidified, subdivided
   sheet. Densely sampled it read 49.1 mm, so that was not it.
2. **"Innermost sixth by count" is not an edge.** On a disc that reaches a
   long way out across the sheet. Taking a narrow band just above the minimum
   radius instead: 27.9 mm.
3. **A buried vertex is not a gap.** `closest_point_on_mesh` returns a
   distance whichever side of the surface you are on, so a vertex embedded in
   the limb counted exactly like one floating away from it — which is why
   deliberately burying the inner ring made the reported gap *grow*, from
   27.9 to 33.8 mm. Only vertices genuinely outside the flesh count now.

With the metric finally measuring what it names, the model change it had been
asking for all along was real: the membrane's inner ring used to butt against
the flesh, leaving up to 28 mm of daylight around the limb — the exact
opposite of §13's *"extrude through reality instead of through a hole"*. It
starts inside the limb now.

    aperture MEMBRANE_ROOT rests 12.6 mm from the flesh (median 0.0, 688 pts)

Median zero: attached all the way round, with one worst point where a fold
pushes the ring outward.
