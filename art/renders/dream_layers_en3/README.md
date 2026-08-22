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

## The geometry half (same day)

The fold the direction means needs vertices, and the dream's boxes had four
per face. `DreamMazeBuilder._solid_box` now tessellates every box's faces at
`FOLD_CELL_M` 0.3 m (`DREAM_FOLD_GEOMETRY=0` restores the four-vertex box),
and the Klimt vertex stage **sinks wall vertices into the wall** around the
weld — the exposure field read at the vertex, a Gaussian about `weld_level`
of width `weld_width × fold_geometry_width`, up to `fold_depth_m` 0.09 —
**inward only, never on floors or ceilings**. The collider is the same box
it was, so the walkable world is exactly what RoomBuilder authored; only the
drawn surface recedes. `sheet_en3_geometry.jpg`: the surface fold beside
the surface + geometry fold — the dado rail breaks and steps where it
crosses the seam, the whole lesion sits in a dish, the weld rings it.

Clamps re-run on the result: DreamPerceptionTest 20/20, DreamHazardTest
42, DreamSurfaceTargetTest 105, DreamAtlasTest, DreamRoomBuilderTest — all
PASS. Cost at the stand: mid 2.3 ms, high 2.2 ms with R6 asleep (the
tessellation adds vertices to a draw-bound frame, not draws).

## What remains

A fold sinks; it does not yet crease the room across a diagonal or pull a
wall toward the player — that would be outward displacement, which the
promise forbids, or a second surface, which is EN-3's next taste row if the
owner wants the crease to leave the wall plane.
