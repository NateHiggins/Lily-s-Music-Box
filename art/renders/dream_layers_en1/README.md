# EN-1 — the re-layered dream, as frames

First frames for decision 4 of the 2026-08-21 ruling
(`design/DREAM_ENCROACHMENT_BRIEF.md`): *"a solid, physically grounded base
with ethereal layers on top, not a wavy golden shower curtain … a purplish
flesh golden skin and impossible molten golden … welds that work like
portals."* Shot 2026-08-21 on Godot 4.7.1 Compatibility at the project window
(1280 × 720). Nothing in production changed.

## How

`res://tests/DreamLayersShot.tscn` stages the exact pocket the R2–R8 proofs
use — a furnished room from `D01_F04_LONG_HALL` with its governed breach —
stands the player's camera where `DreamSurfaceTargetShot` stands it, settles
the real service lamp, and photographs from that one camera:

- the **shipping Klimt surface** latent, at a mid retained state and at a
  high one;
- the **EN-1 probe surface** (`game/tests/dream_layers_probe.gdshader`), a
  stand-in material that takes each Klimt surface's own base maps, tile size
  and reflected-world plate and receives the root's exposure field, lamp
  pose and incarnation bundle through the same collector — so only the
  layer model differs — one layer at a time at the high state, and the full
  stack latent and mid.

The high state is one held lamp at the wound (7.9 s then 16.1 s more, the
real `DreamExposureField` doing the write), so retained exposure falls off
radially — 1.000 at the wound, 0.055 a metre aside — and one frame carries
the whole progression from plaster to weld. `layers_sheet.png` is the
contact sheet; `frames/` the originals; `dream_layers_shot.log` the run.

## The layers, as built in the probe

| bit | layer | what the probe does |
|---|---|---|
| 1 | **base** | the surface's own albedo/normal/roughness under the builder's world-box UV, **unwarped**, PBR, lit by the real lamp |
| 2 | **flesh** | lobed patches grown from retained exposure (a world-space lobe field nudges the contour so it has an edge, not a radius); aubergine → wine → plum by `dream_corruption_cells`, tendon folds as crests, faint vessels, wet film on roughness, a wrap-lit rim at grazing angles, breath at 0.07 Hz in the fold phase; relief from the cell/fold fields by finite difference |
| 4 | **skin** | antique gold as a metallic skin **over the flesh only**, appearing from a lobe-shaped tear field as drive rises: metallic 1, roughness ≈ 0.3 with per-sheet and hammered variation at 18 /m, tarnish toward the torn edge; no emission — it reflects what is there |
| 8 | **weld** | a bead along the contour `drive = 0.24` (the seam where the encroachment is fused to the apartment): heat-gradient colour dull red → orange → yellow-white core, slow flow along the seam from a drifting 3-D field, a bulged profile from the exposure gradient, emissive at 1.1 with an 8 % pulse at 0.1 Hz — molten metal glows, nothing flashes |
| 16 | **portal** | where the bead's core is strong and the gold phase is past `portal_open`, the core shows another place: the case's reflected-world plate sampled by the reflection vector, a stand-in for R6's bounded live camera |

## What the frames say

- **`05_probe_base` is a real corridor wall** — plaster, picture rail, dado,
  the lamp pool — photographable as the Orison. The shipping surface never
  shows this: `00_klimt_latent` is near black with gold scribble, because
  the Klimt substrate is held at 0.55 × and cold at 0.18 ×, and `04_klimt_high`
  is dark mesh and spiral motif wall-to-wall with the lamp's vignette.
- **`06_probe_flesh`**: a lesion with an edge, wine and plum, wet under the
  torch, growing across the rails rather than replacing the wall. This is
  the "local, has an edge, stops" rule of the brief made visible.
- **`07_probe_skin`**: gold where the flesh is deepest, dark because it is
  a mirror in a dark room and the lamp is the only thing to reflect — the
  Klimt's own law ("gold leaf is not a light source"), now obeyed by a
  surface with thickness and tears instead of a pattern.
- **`08_probe_weld`**: one molten seam ringing the lesion, a bead with heat
  in it. It reads as a weld, and it is *the* place a portal can open.
- **`09_probe_stack_high`** is the owner's sentence in one frame; compare
  `04_klimt_high` from the same camera.
- **`10_…_with_limbs`**: the R4–R8 limbs (flat magenta, gold wire edges)
  do not belong to this stack yet. They are the next thing to re-skin with
  the same flesh/skin functions — the probe's layers 2–4 are written to be
  shared by a body as much as by a wall.

## Cost

GPU median of 36 frames per state at this stand, vsync off, same camera:

| frame | state | GPU ms | draw calls |
|---|---|---:|---:|
| 02 Klimt | mid | 0.93 | 79 |
| 04 Klimt | high | 0.88 | 315 |
| 05 probe base | high | 0.36 | 314 |
| 06 + flesh | high | 0.58 | 314 |
| 07 + skin | high | 0.65 | 314 |
| 08 + weld | high | 0.69 | 314 |
| 09 + portal (full stack) | high | 0.70 | 314 |
| 10 full stack + limbs | high | 1.10 | 317 |

The full probe stack costs **less than the shipping Klimt surface** at the
same state (0.70 vs 0.88 ms) and adds no draw; flesh is the priciest layer
(+0.22 ms, three 3-D fbm fields and a finite-difference relief), skin, weld
and portal together +0.12. The draw-call rise from 79 to 314 between mid and
high is the root's own high-state owners (view portal, intrusion, reflected
light) waking, identical for Klimt and probe. `00_klimt_latent`'s 4.9 ms is
the run's first capture and includes shader compilation; it is not a cost.

## What this does not decide

- The **fold** layer (geometry-side warping, mirrored architecture) is not
  in the probe; it is EN-3 and needs the Atlas's fairness clamps re-run.
- The portal core here is a plate, not R6's live feed; EN-2 places the
  bounded camera by the weld vocabulary.
- Limbs, eyes and the lineage body keep their current shader until the
  owner accepts this stack; they then take layers 2–4 from the same include.
- Adoption means promoting the probe's layers into `dream_klimt.gdshader`
  in place of the motif/leaf/ripple/dish path, keeping the motif as
  wayfinding *only where it earns it* (doors, danger eyes), and leaving
  exposure, hazard and topology ownership exactly where they are.
