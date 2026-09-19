# DREAM-SURFACE-S2I runtime packet

Godot 4.7.1 stable, Forward+, 1600×900, NVIDIA RTX 4080. Exactly five review PNGs are present.

## Material and render modes

| Role | Blend/depth mode | Optical response | Roughness / specular |
|---|---|---|---|
| Plasmodium tissue | Opaque, depth-writing, back-face culled | Thickness-hinted SSS transmittance and bounded backlight | 0.72 / 0.13 |
| Membrane/cortex | Opaque, depth-writing, back-face culled | SSS transmittance; inspection opening supplies direct anatomical view | 0.74 / 0.12 |
| Protein | Opaque, depth-writing, back-face culled | Dense absorption and bounded SSS | 0.78 / 0.10 |
| Cargo | Opaque, depth-writing, back-face culled | Softer absorption/SSS | 0.76 / 0.11 |
| Internal anatomy | Opaque, depth-writing, back-face culled | Depth/value differentiation without categorical emission | 0.80 / 0.08 |

Alpha layers: 0. Render-priority overrides: 0. Tangent-space textures: 0. Closed shells never overlap through transparency.

## LOD thresholds

| Asset | Triangles by LOD | Outward thresholds | Hysteresis | Simultaneously visible LOD roots |
|---|---:|---:|---:|---:|
| Plasmodium | 11,656 / 4,455 / 1,883 | 6 m / 15 m | 0.65 m | 1 |
| Transport | 54,230 / 20,722 / 8,754 / 2,125 | 4.5 m / 10 m / 19 m | 0.65 m | 1 |
| Cellular interior | 15,445 / 6,577 / 3,410 | 6 m / 15 m | 0.65 m | 1 |

The lower strips in frames 1–3 capture both sides of every threshold. `runtime_evidence.json` records the sampled distance, selected LOD and visible-root set. Every sample reports exactly one visible root.

## Focused performance

| Capture | Draw calls | CPU frame | Presentation CPU | GPU frame |
|---|---:|---:|---:|---:|
| Plasmodium contact | 10 | 0.607 ms | 0.003 ms | 0.328 ms |
| Transport contact | 15 | 0.593 ms | 0.012 ms | 0.312 ms |
| Intact cellular lighting | 23 | 0.588 ms | 0.011 ms | 0.308 ms |
| Examination cutaway | 23 | 0.779 ms | 0.012 ms | 0.492 ms |
| Furnished Orison | 1,737 | 6.503 ms | 0.017 ms | 4.128 ms |

Hero VRAM delta: 4,929,040 bytes.

## Geometry audit

`normal_winding_audit.json` covers all ten GLBs. Results: zero inverted transforms, inconsistent winding edges, duplicate triangles, non-manifold edges, or degenerate triangles. The transport cleanup removed only 20/20/20/19 proven zero-area or subpixel faces, leaving the accepted silhouettes and all intentional sectional boundaries unchanged. Tangents are intentionally absent because these materials do not use UV/tangent-space maps.

## Renderer teardown comparison

The identical full-room lifecycle probe was run without hero assets on clean main commit `e89fa608874fe2b75ecd0f0b52ab84829c884d82` and on the S2 branch. Both exited 0 and emitted exactly 1,264 Godot light-index diagnostics: 632 `instance_set_scenario` and 632 `instance_set_base`. This proves the diagnostic is neither introduced nor amplified by S2H/S2I. Raw logs and `teardown_baseline_comparison.json` are included.
