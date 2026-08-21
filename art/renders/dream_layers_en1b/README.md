# EN-1b — the re-layered dream, in production

Decision 4 of the 2026-08-21 ruling, promoted. The five layers the EN-1
probe proved as frames (`art/renders/dream_layers_en1/`) now live **inside
`dream_klimt.gdshader`**, after the ornament, the incarnation surface and the
anatomy — so everything the Klimt surface already owed (the six shared-dream
incarnations, `unlit_reveal` for the eye hazards, the scar lock, the R6
portal camera) keeps its law and the layers sit on top of it. Not a switch
to the probe: the probe lacks the incarnation include, and the merge was
the only way to keep both.

## The layers in the Klimt surface

| bit | layer | where it comes from |
|---|---|---|
| 1 | **base** | where the field has not eaten the wall, the wall is the wall: the RAW plate at the **unwarped** world-box UV (not the incarnation's translation of it through the melt-dragged coordinate) with its own trowel relief, at `base_ground` 0.75 × (1 − eaten) × (1 − ½ woken). Never on `MOTIF_EYE` (a hazard still costs light). **Not gated on the scar lock**: a scar shows no gold ever, but it is still a wall, and the wall is what the lamp lights |
| 2 | **flesh** | the probe's lobed tissue from retained exposure × `exposure_gain` (so a scar grows none), wine/plum cells, folds, vessels, wet film, wrap-lit rim, breathing; relief by finite difference; the flesh covers the glow |
| 4 | **skin** | antique gold over the flesh only, sheets of the Klimt's own `leaf_sheet_m`, hammered micro-normal, tarnish at the torn edge; metallic, and it covers the emission — gold leaf is not a light source |
| 8 | **weld** | the molten bead along the contour `weld_level` 0.24 of the drive, heat-gradient colour, slow flow, a bulged profile from the field's gradient, emissive at `weld_glow` with an 8 % pulse |
| 16 | **portal** | at high gold phase the bead's core shows the case's reflected-world plate by the reflection vector — the stand-in for R6's bounded live camera (EN-2) |

`layer_mask` (default 31) is a uniform; `DREAM_LAYERS=0` in the environment
is the pre-EN-1b Klimt for A/B frames and perf, `DREAM_LAYERS=<mask>` a
subset (`dream_maze_builder._klimt_material`). `DREAM_PLAIN=1` stays the
graybox control.

## What the merge found

1. **Klimt wrote a world-space normal into `NORMAL`** (which is view
   space). `v_normal` is the model normal taken into world in `vertex()`,
   `bumped` is built from it, and `NORMAL = bumped` lit every wall with a
   normal that only agreed with the camera by accident — which is why the
   real lamp never seemed to reach the plaster and the shader's history
   made the waking emissive "because the world went black". Converted at
   both write sites (`VIEW_MATRIX * bumped`). The reflection vector keeps
   its legacy mixing so the melt's fake environment looks as it did.
2. **The base had to come from the raw plate, not the incarnation's
   surface**: with an incarnation bound, `surface` is the translated
   (dark) plate, and the grounded wall came out at a third of the probe's
   brightness. And from the **unwarped** UV: through `bt` (melt-dragged) the
   plaster streaked.
3. **The base must not honour the scar lock** — the probe never did, and in
   the EN-1 pocket the walls are scars; gated, nothing grounded.

## Frames (`sheet_en1b.jpg`; `klimt/` = `DREAM_LAYERS=0`, `layered/` = shipping)

The same stand, lamp and dwell as EN-1 (`DreamLayersShot`). Pre-merge Klimt
at every state is near-black with gold scribble; the merged surface is a lit
corridor — plaster, dado, the lamp pool — with the ornament holding on the
eaten side, and at the breach the lesion, the skin and the weld ring; the
probe reference beside it for the layer-by-layer comparison
(`05_probe_base` … `09_probe_stack_high`).

Cost at the EN-1 stand (GPU median ms): pre-merge Klimt latent 2.5 / mid
1.1–1.9 / high 1.0–2.1; merged latent 2.5 / mid 1.9 / high 2.1–2.4; the
probe stack 0.6–0.9. The merged surface carries the Klimt's ornament and
the layers both; trimming the ornament where the layers cover it is EN-2's
perf row.

Gates: `ShaderParseCheck` (now covering Klimt and the fauna shader),
DreamIncarnationTest, DreamIncarnationPlateTest, DreamIrradianceTest 16/16,
DreamExposureTest 35, DreamFaunaTest 28/28 — all PASS.
