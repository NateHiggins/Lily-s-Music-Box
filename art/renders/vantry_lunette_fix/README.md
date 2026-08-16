# The south lunette was occluded by its own blackout — V1 defect, fixed

Found 2026-08-16 by the adversarial verification pass on the V4 lighting
plan. It went looking for something to light at the terminus and reported
that the deliverable was *physically impossible*: nothing of the lunette
was visible from the hall.

## The defect

The south gable occupies y −64.60..−64.36 and the aisle is north of it,
so the viewer looks south at the gable's −64.36 face. V1 authored the
lunette's soot backing at `gy1 + 0.08`:

| element | y span |
|---|---|
| gable slab | −64.60 .. −64.36 |
| lunette glass | −64.54 .. −64.42 (inside the gable) |
| `nave_lunette_back` | **−64.28 .. −64.22** — *north of the gable face* |

The backing therefore hung **in the room, between the viewer and its own
glass**, spanning z 5.10..8.10 and covering both panes completely. The
lunette had been invisible since the day it was built. Every night frame
"confirmed" it looked fine, because a black plate in an unlit corner and
an unlit window are the same picture.

The clerestory got this right in the same pass — its backing is authored
outboard at `backx0 = wx0 − 0.10`. Only the lunette inverted the sign.

## The fix

`nave_lunette_back` moves outboard to y −64.74..−64.68, behind the gable
where a backing belongs. `03_hall_south.png` now shows the glazed opening
reading at the vanishing point instead of a void. It is still unlit —
lighting it is V4's job, and the abnormality it will carry (a room behind
it that cannot exist) is what made the review notice the occlusion.

## The lesson

A dark render is not evidence. Two of this session's defects — this one
and the kiosk interpenetration — were invisible at night and found by
arithmetic on coordinates. Judge geometry by measuring it; judge light by
looking.
