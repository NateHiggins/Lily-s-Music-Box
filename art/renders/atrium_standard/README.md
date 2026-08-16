# The light court's standard — halved, composed, and the budget raised

Owner direction 2026-08-16: *"remove half of those lights on the atrium
lighting fixture and redesign it to be more period appropriate and go
with 64."* The fixture is the brass tree that rises the full height of
the stairwell from the basement floor to the skylight.

## What changed in the piece

The tree threw **two branches per storey at a random angle, a random
reach and a random rise** — sixteen lights, scattered up the well. The
randomness is what read as un-period. 1928 decorative metalwork is
*composed*: Edgar Brandt's foliate ironwork of exactly these years is
rigorously set out however organic its motifs are, and a piece
commissioned for a light court would have been drawn by a draughtsman.
The eye reads that difference immediately without being able to name it.

Now: **one bracket per storey**, at a constant height in the slice, a
constant 0.86 m reach and a constant rise, alternating to opposite sides
floor by floor with a quarter-turn so the column does not read as a flat
ladder when you look straight up it. Ascending the well you read a
deliberate rhythm instead of a scatter.

Untouched, because they are the piece's character: the wandering trunk,
the beaten brass pads, the twigs, the root flare, and the reading nook
built among the roots.

**Eight lanterns instead of sixteen** — which is what pays for the
budget raise below.

## What changed in the budget

`building_root` shipped 16 active / 16 shadow under a comment reading
*"Sixteen is the renderer's actual per-object ceiling."* That ceiling
became 128 some time ago, so the budget was derived from an expired
argument (TASKS L14). It is now **64 active / 16 shadow**. Shadows stay
at sixteen deliberately: the positional atlas is a fixed 8192 that
subdivides per caster, so raising *that* number shrinks every shadow in
the frame (TASKS L13).

`perf_probe.gd`'s `PINNED_LIGHT_BUDGET` moved 16 → 64 with it. A pin that
stops tracking production stops measuring the game and starts measuring a
configuration nobody plays — while still producing confident numbers.
**Tables recorded before 2026-08-16 ran at 16/16 and are not directly
comparable to anything after it.** Sweep `LIGHT_BUDGET=16` to reproduce
a historical figure.

## Measured, canonical pinned night, 1280×720

| station | 16/16, 16 lanterns | 64/16, 8 lanterns |
|---|---:|---:|
| lobby | 27.01 | **25.57** |
| atrium eye (7 storeys) | 37.17 | **39.28** |
| corridor F04 | 26.88 | 26.70 |
| street elevation | 27.50 | 27.64 |
| harukiya | 13.28 | **10.60** |
| passage northbound | 14.26 | **13.61** |
| stations over 16.6 ms | 6 / 11 | **5 / 11** |

**The trade paid everywhere except the place it was meant to pay.**
Every other station improved or held — the bar by 20% — and one station
crossed under the gate. The atrium still costs about 2 ms more than it
did: halving the lanterns bought back roughly a third of what raising
the budget cost there (measured 40.25 at 64/16 with sixteen lanterns,
39.28 with eight), so the redesign helped without covering it.

That is worth stating plainly rather than spinning. The judgement to
keep it: the atrium is already the worst station in the game at 2.4× the
gate, it is a known P1 item that will need structural work regardless,
and +2 ms there is not what decides its fate — while the improvement
everywhere else is real and shipping.

**Why the court in particular charges:** its lanterns are
`navigation: true`, and LightRig's `NAV_WEIGHT` makes a nav fixture rank
as if at 0.387× its true distance. Combined with the court being exempt
from the storey gate, all eight are permanently eligible from anywhere in
the building. If the atrium needs its own relief later, that exemption —
not the lantern count — is the lever.

## Frames

`before/` and `after/`, same three cameras: the well from the lobby
looking up, the court from F03, and the base with its reading nook.
Canonical night, so the court reads dark by design; the composed bracket
is legible in `02_court_from_f03`.
