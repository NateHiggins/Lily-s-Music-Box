# EN-3 — the fold, surface-side (bounded)

"The building being consumed, melted and folded from a fifth direction."
Built 2026-08-22 on EN-1b/EN-2 as bit 32 of the Klimt surface's
`layer_mask` (default 63; `DREAM_LAYERS=31` is the no-fold control).

## What it does

Within a band either side of the weld contour, the wall's own photograph
(the grounded base of EN-1b) is **drawn into the seam** along the exposure
field's gradient in the wall's tangent frame — up to `fold_pull_m` 0.22 of
slide, most at the seam — and the surface is **creased** there: the normal
tilts into the seam by the same vector. Reality slides into the weld rather
than being painted beside it. The band is `fold_reach_m` × 0.36 of drive
about `weld_level`.

**Bounded by construction.** No vertex moves: the collider, the navigation
and the Atlas's promise (what RoomBuilder authored is what stands) are
untouched, and Gate C's clamps were re-run on the result —
DreamPerceptionTest 20/20 (every hazard still honestly identifiable),
DreamHazardTest 42, DreamSurfaceTargetTest 105 — all PASS.

## Frames

`sheet_en3_fold.jpg` — the EN-1 stand at full exposure, layers 31 beside
layers 63: the crease along the outside of the weld ring, the plaster and
the dado rail pulled toward it. It reads as a fold of the surface, not of
the room.

## What this is not, and what the next step is

The fold the direction imagines — the room itself creased from a fifth
direction — needs vertices to move, and the dream's walls are graybox boxes
with four of them (`dream_maze_builder`, "no usable UVs"). A geometry fold
is a **RoomBuilder tessellation** job: subdivide the authored faces near a
breach so a vertex displacement along the same gradient can bend the wall
toward the weld, still inside the Atlas's promise (displacement capped
below the collider's skin, never on the floor), with Gate C re-run. That is
the EN-3 that remains open; this surface fold is its first, bounded half.

Also in this commit, EN-2's taste row: R6's view camera sways with the
seam's flow (a few centimetres and a degree or two at the bead's 0.08 Hz)
so the view in the weld moves like something held in molten metal. The R6
contracts assert the camera's existence, cull mask and attributes, not its
pose; all PASS.
