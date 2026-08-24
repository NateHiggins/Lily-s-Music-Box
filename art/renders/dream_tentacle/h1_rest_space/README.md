# H1 — DEFORMING FLESH REST SPACE

The hero's rigid riders already sampled their own recovered rest position, but
the skinned flesh sampled world position and visibly moved through its
procedural surface. This pass makes the deforming cage carry the exact
undeformed sculpt without creating another texture fetch, material, draw or
runtime owner.

## Channel contract

- UV2: normalized undeformed Blender X/Z, bounded to ±0.16 m.
- Primary strip V: coarse longitudinal Y.
- COLOR.g: ±0.012 normalized-Y residual. Encoding only the residual avoids the
  roughly 6.25 mm step an 8-bit colour channel would impose over the full
  1.6 m limb.
- Anatomy alpha: authored ocular region displaced from UV2. The already-bound
  RGBA texture remains the only anatomy sampler.
- COLOR.r/b/a remain thickness, gold-root and sucker masks.

Subdivision is applied before packing, smooth normals prevent face-corner
explosion, and the continuous primary strip is welded while retaining its
intentional U seam. The shipped GLB is 2,451,984 bytes and Godot imports
17,115 cage vertices.

`TentacleAssetProbe` measures a maximum decoded rest-position error of
**0.1374 mm** across all 17,115 vertices. `DreamHeroRestTest` then freezes the
surface contract while a real skinned distal bone travels **869.93 mm** in the
final focused run; the decode error remains 0.1374 mm. Production defaults to
rest-space. The
`HERO_FLESH_REST=0` path exists only to reproduce the old comparator.

## Rendered production proof

[`paired/contact_sheet.png`](paired/contact_sheet.png) is six frozen animated
poses. Each row is one pose; columns are `control_a`, identical old-behaviour
`control_b`, and `rest_space`. The camera, lamp, geometry, pose and procedural
shader time are unchanged within each triplet. The rest-space column removes
room-fixed bright bands while retaining organic body-local variation and the
separate modeled gold anatomy.

| pose | A/A RMSE | old/rest RMSE |
| --- | ---: | ---: |
| 00 | 0.000000 | 0.031708 |
| 01 | 0.000000 | 0.031313 |
| 02 | 0.000000 | 0.034412 |
| 03 | 0.000000 | 0.034218 |
| 04 | 0.000571 | 0.026737 |
| 05 | 0.001998 | 0.024376 |

Every treatment clears its live-render A/A floor; the worst ratio is over
12×, and the first four A/A pairs are byte-identical at the image metric.

## Performance and tests

One Forward+ run alternated three 60-frame trials per path in the same frozen
production scene with vsync disabled:

| path | median frame | draws | primitives |
| --- | ---: | ---: | ---: |
| old world-space control | 1.553 ms | 119 | 93,947 |
| rest-space | 1.552 ms | 119 | 93,947 |

- `TentacleAssetProbe.tscn`: PASS.
- `DreamHeroRestTest.tscn`: 5/5 PASS.
- `DreamTentacleTest.tscn`: 21/21 PASS.
- `DreamHeroSweep.tscn`: attempted, but the full production assembly exceeded
  the mandatory 60-second limit before reaching the new assertions. No pass is
  claimed from that run.

The remaining H1 debt is authored albedo, normal and detail-normal maps plus
UVs/bakes for the rigid riders. This proof closes only deforming-flesh surface
ownership.
