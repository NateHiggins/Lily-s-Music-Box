# DREAM PRODUCTION RENDERING R1 — READABLE APARTMENT, LAYERED BODY

Production capture, 2026-08-20. Governing target:
`art/reference/dream_surface/stage4_room_colonisation.png`. This is the first
substrate pass under the reconciled production-rendering plan in
`design/DREAM_SURFACE_REDESIGN_BRIEF.md`; it is not a claim that N10 or the
reference image is complete.

## What changed

The frame now treats the waking apartment and the organism as separate visual
jobs:

- `dream_klimt.gdshader` finally gates **every** frieze channel through the
  durable `eaten` phase boundary. Previously only leaf was gated; glaze, ink,
  jewels, ghost colour and impasto still recoloured nominally uneaten plaster.
  The advertised photographed Orison base was therefore mathematically
  unreachable. Wall, floor, ceiling, door and shaft materials now also begin
  at bounded 0.26–0.46 consumption instead of the global 0.55 default.
- `dream_corruption_layers.gdshaderinc` is a reusable shader vocabulary for
  cellular tissue, tendon folds, warped vessels and wet microfilm. The hazard
  body consumes those masks in `dream_lineage_gold.gdshader`; later breach and
  phase materials can reuse them without copying one monolithic fragment or
  adding overdraw.
- Deep plum/blood tissue is the mass. Rose is restricted to grazing thickness
  and folds. Wetness modulates a tight highlight. Antique gold occupies a
  narrow, warped vessel network and eyes. The three layers remain one submitted
  surface because this frame is submission-bound.
- The old proof's ellipsoid/graft tessellation rose from 5 × 8 to 7 × 12 and
  hazard tubes from 10 to 16 sides. This costs vertices, not draws, and removes
  the most obvious cardboard facets at encounter distance.
- A low cool environment lift, a five-metre carried black level and one bounded
  warm practical establish nearby Orison without waking gold or changing any
  hazard condition. The lamp-off organism uses only its ruled local wine-dark
  response; it lights no neighbouring architecture.

## Frames

- `01_furnished_breach_lamp_on.png` — production service lamp at encounter
  distance. Wainscot, rail, plaster and the historical room remain the control;
  tissue and gold vessels occupy the breach anatomy.
- `02_furnished_breach_motion.png` — same production camera 150 frames later;
  topology and collision are unchanged while the shader deformation moves.
- `03_furnished_breach_dark_live.png` — same view with the service lamp off.
  Gold sleeps; the wine body remains legible and every substantial limb remains
  registered contact on its source `DreamHazard`.

The camera moved from the previous survey proof's roughly 5.2 m / 78° view to
the safe encounter view at 2.85–3.6 m / 70°. The old camera stood at the edge
of the deliberately bounded black-level range and reduced the material to a
few pixels, so it could prove ownership but not judge a layered surface. This
means the following luma figures are presentation outcomes, **not a
single-variable A/B**:

| frame | mean luma | pixels above luma 16 |
|---|---:|---:|
| previous lamp-on proof | 0.0192 | 9.29% |
| R1 lamp-on proof | 0.0404 | 16.70% |
| previous lamp-off proof | 0.00214 | 0.255% |
| R1 lamp-off proof | 0.00408 | 1.303% |

## Rejected tuning

Three failed versions were not kept as acceptance frames:

1. Re-enabling only the carried black level did not repair a camera placed at
   its falloff boundary. The wall was still crushed and the material could not
   be judged.
2. Raising cold albedo and ambient without fixing the phase gate left the wall
   brighter but still abstract. The real defect was that uneaten plaster still
   received the gold pass's paint, ink and relief.
3. Driving the afterglow through `EMISSION` under the Compatibility/unshaded
   path remained nearly invisible after ACES. The final bounded dark-state
   value is carried in the organism's own unshaded albedo; it still cannot cast
   light or reveal the room.

## Proof

- `DreamSurfaceTargetTest.tscn`: **36/36 PASS**. The test now names the three
  material layers, their tissue-first tuning, the photographic environment
  lift, bounded carried black level and bounded warm practical, in addition to
  the existing ownership, contact, motion, Orison shell and furnishing checks.
- `DreamRoomBuilderTest.tscn`: **175/175 PASS**.
- `DreamHazardTest.tscn`: **42/42 PASS**.
- `DreamLineageTest.tscn`: **21/21 PASS**.
- `PERF_DREAM=1`, fresh 2560 × 1440 run: **PASS**, 0/4 stations over 16.6 ms.
  Rows were 1.94 ms / 78 calls, 1.83 / 78, 1.71 / 133 and 1.81 / 172. The
  vertex smoothing and shader layers added no submission relative to the prior
  172-call worst row.
- `WalkTest.tscn` FAST x8/480: **PASS**, with the inherited null
  `GameBoot.layout` script error at `walk_test.gd:885` still present.
- `WalkTest.tscn` FULL x8/480: **FAIL (1)** at the same unrelated waking
  roof-monitor walk already recorded by the previous surface pass (final
  z=2.9), while the 2A bedroom walk passed. It also prints the inherited
  null-layout and resident-route errors. This pass changes only dream-scene
  material, lighting and proof code and never enters that waking route, so the
  result is retained as external flaky proof debt rather than called green.

## Honest boundary

R1 solves substrate and readability; it does not solve final composition. The
production seed still photographs a long hall rather than the later three-room
validation pocket, and its one hazard grows from the authored floor fault
rather than from a newly invented showcase arch. R2 remains true relief and
architecture-bound transition masks. R3 remains the seeded eye family. R4
remains the torn breach and impossible interior depth. Phase states, bounded
warp and a single view-only portal follow those proofs. Enterable RECURSION is
still unlicensed.
