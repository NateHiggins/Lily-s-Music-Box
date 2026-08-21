# M-COVER — coverage options, framed and priced

Owner request 2026-08-17: *"rethinking our general coverage solutions as the
tiling is not doing for me anymore in many cases."* The task said bring
frames, not adjectives. These are the frames, shot 2026-08-21 on Godot 4.7.1
Compatibility at the project window (1280 × 720), and the numbers.

## How the frames were made

`res://tests/CoverageShot.tscn` boots the production building exactly as
FreeCam does — production fixtures as the rig budgets them, the player's own
torch on the camera, no judging fill — and at each stand swaps **only the
floor surfaces of that storey** (`F0x_floors_*`) for a probe material
(`game/tests/coverage_probe.gdshader`) fed with the surface's own albedo /
normal / roughness set, colour, roughness and metallic. So `current` is what
ships, `plain` is the probe with one tap (the control), and every other frame
differs from `plain` by exactly its trick. GPU cost is the viewport's measured
render time, median of 48 frames after a warm-up of every shader variant, vsync
off; it is printed in every label and stored in `frames/coverage.json`.

Stands: the F04 corridor's long sightline, the same corridor looking down at
the floor, the lobby, the 4B living room, and (for oak) a bare stretch of 4B's
boards. Sheets: `<stand>_sheet.png` (all nine options) and `<stand>_close.png`
(centre crop at 2×); the full frames behind the findings are in `frames/`
(terrazzo current/mirror/hex/split, corridor long current/split, oak
current/hex/rows) and the rest regenerate with the harness in a few minutes.

## What repeats, and why the obvious fixes fail on it

**Walls do not tile.** Every wall carries its own compiled finish
(`T_wallfinish_f0x_wNN`, ~100 px/m) — soft, not repetitive. The repetition is
the **floors**: terrazzo in corridors and lobby, oak in the flats.

**The terrazzo tile is structured.** The imported mesh's UV runs at 4.0 m per
unit (`materials.json` says 1.5 for the set, the mesh says 4.0 — trust the
mesh); that 4 m tile holds a 3 × 3 lattice of 1.33 m cells divided by brass
strips, one strip along an edge, and one crack. Down the corridor the same
crack and the same chip cluster arrive every cell. Because the lattice is
*baked into* the tile:

- **mirror jitter** (one tap, seam-free on symmetric content) doubles the
  edge strip where a mirrored tile meets an unmirrored one —
  `corridor_floor_close.png`, third panel;
- **hex stochastic** (three taps at hashed offsets, variance-preserving blend)
  varies the aggregate beautifully and chops the lattice into a ghosted,
  broken grid — fourth panel;
- **self-detail** at 3.718× adds grain but the crack still repeats — fifth.

## What works

**Cell-snapped hex** (`split`): hex stochastic whose three offsets are snapped
to thirds of the tile. All three taps then agree on where the brass strips
are, so the lattice stays crisp and continuous, while the aggregate inside
each cell is shuffled among the nine authored cells. The crack appears once.
Faint ghosting remains where three cells blend; a production version authors
the aggregate as a cell-free field and even that goes. `corridor_floor_close.png`
eighth panel, `frames/corridor__split.png` for the long view.

**Per-board-row offsets** (`rows`): for oak, one tap, each board row shifted
along the grain by a hashed amount. Every board edge survives exactly; the
tile-period joint line that ran across the whole floor is gone
(`oak_floor_sheet.png`, right). Hex on the same boards cuts them into
mis-registered segments with blend seams (middle) — wrong tool for structured
boards.

So the rule the frames teach is: **separate what is structure from what is
field.** Lattice and board edges are structure and must stay on their grid;
aggregate and grain are field and may be shuffled. One shader does both with
two uniforms (`lattice_cells`, `rows_per_tile` / `grain_along_u`).

## Cost

GPU median per stand, ms, and delta from `current`:

| stand | current | plain | mirror | hex | detail | hex+detail | mirror+detail | split | rows |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| corridor (long) | 11.54 | −0.21 | −0.15 | −0.21 | −0.29 | +0.06 | −0.09 | +0.13 | −0.11 |
| corridor (floor) | 5.04 | +0.16 | +0.23 | +0.37 | +0.20 | +0.30 | +0.24 | +0.34 | +0.20 |
| flat 4B | 6.58 | +0.15 | +0.16 | +0.19 | +0.22 | +0.16 | +0.16 | +0.16 | +0.11 |
| lobby | 10.55 | +0.90 | +1.21 | +1.40 | +1.45 | +1.60 | +1.52 | +1.47 | +1.40 |
| oak (bare boards) | 3.43 | — | — | +0.37 | — | — | — | — | +0.22 |

Three stands put every option within **+0.4 ms** of shipping; draw calls are
unchanged everywhere (the trick is per-pixel, not per-object), and no option
adds a texture. At the lobby every probe variant *including the one-tap
control* reads +0.9–1.6 ms: that is an order/thermal drift the control shares,
not a trick's price; the spread above the control there is ≤ 0.7 ms. This is
consistent with the project's standing finding that the frame is
submission-bound, not fill-bound.

**Per-room UV seeds** were priced rather than framed. Done in the builder they
need floor meshes split per room (≈ +16 submissions per storey per floor
category, and the building is draw-call bound); done in the shader they are a
hash of the room cell, which is what cell-snapped hex already is for the
cells it owns. **Supertiles** (M1's VRAM question) were not needed to get
here. **Decal variation** (`atmospheric_decal_pass.gd`) remains the right
tool for wear and marks, orthogonal to coverage.

## Recommendation

Adopt two material classes for floors, both from the probe shader's proven
paths: cell-snapped hex for terrazzo (and any tile-lattice set: ceramic,
porcelain), per-board-row offsets for oak and other boards. Keep the shipping
StandardMaterial3D for sets that neither tile visibly nor carry structure.
Production adoption is a `MatLib`/glTF material swap per set plus two
uniforms per set — not a pipeline change. It waits on the owner choosing
from the sheets; nothing in production changed in this pass.

Rebuild the sheets with:

```bash
python art/tools/build_coverage_contact_sheets.py art/renders/material_coverage_m/frames art/renders/material_coverage_m
```
