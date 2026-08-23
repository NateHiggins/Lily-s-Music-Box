# H6 — CROSS-SECTIONAL WITHDRAWAL

The hero's one impossible thing (ecology §1: *"special hyperdimensional
events"* are hero-owned; menagerie §15: **one** dominant rule, used rarely
enough to stay meaningful).

**It does not retract, shrink toward its root, or fade.** Its cross-section
closes — everywhere along its length at the same instant — while its length
does not change. The limb stays exactly as long, and exactly where it is, and
stops having a thickness.

That is the field's own law applied to the hero's body:

    r_visible = sqrt(r² − w²)

Nothing is travelling. Our slice is moving past it. A creature that leaves
the way a three-dimensional animal leaves is a three-dimensional animal.

It fires on every third ordinary withdrawal, so most departures are unremarkable
and this one is not.

## Measured

`SWEEP_SLICE=1` forces the event and shoots twelve frames from a fixed camera.
The frames are then differenced against the fully-absent frame — the room is
identical in every shot, so the difference **is** the limb — and its silhouette
measured:

| slice_close | silhouette px | bbox |
| ---: | ---: | --- |
| 0.11 | 47,420 | 1255 × 719 |
| 0.44 | 30,265 | 925 × 445 |
| 0.65 | 29,050 | 914 × 422 |
| 0.87 | 35,353 | 825 × 422 |
| 0.99 | 699 | — |

The `sqrt` curve is why it barely thins for most of the event and then goes
almost at once. At 0.87 the body has become a **lacework**: holes open through
it where the flesh was thin, thick anatomy survives longest, and the remnant
still spans its whole extent.

## The fault this found

The first version collapsed straight along the surface normal, and measured,
the silhouette's long axis lost **59%** of its length — which would make this
an ordinary retraction wearing a costume. The cause is that an end cap's
normal points *along* the limb, so collapsing along it pulls the ends in.

On this mesh UV.y runs along the body, so `BINORMAL` is the axial direction;
removing that component leaves the true radial one and the caps barely move.
The long axis now holds to −34%, and most of that residue is a measurement
artifact rather than motion: a thinning distal end drops below the difference
threshold against a similarly-lit wall before the thick root does.

## Not done

- The margin does not react to it. §11 wants palps to respond to the hero, and
  a hero that stops having a cross-section beside them ought to be the single
  most alarming thing they ever witness.
- No residue is left at the vanishing point.
