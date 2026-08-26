# K1 playable-atrium shadow budget proof

These frames use the corrected `perf_probe.gd` station named `atrium F03
landing (playable)`. The player body, eye, carried lamp and streaming origin
are all at the photographed position. This is not the older detached atrium
composition camera.

## Captures

- `control_a_64_16/`: first production-budget control.
- `control_b_64_16/`: repeated production-budget control, establishing the
  temporal render floor.
- `candidate_64_5/`: same station with all 64 light slots retained and only
  the five highest-ranked eligible fixtures casting shadows.

Every run captured exactly one station and reported the intended budget. The
day/night clock was frozen. White weather motes still move between fresh
processes, so a nonzero image difference is expected even between the two
controls.

## Measurement

The matching performance runs measured 23.70 ms at 64/16 and 15.28 ms at
64/5; a fresh 64/5 repeat also measured 15.28 ms. The candidate therefore
clears the strict 16.6 ms gate at this playable hotspot.

At 1600x900, whole-frame RMSE is:

- control A versus control B: `384.586 (0.0058684)`
- control A versus candidate: `647.166 (0.00987512)`

On the fixed 1000x360 architecture crop at +300,+500, RMSE is:

- control A versus control B: `719.44 (0.0109779)`
- control A versus candidate: `1153.87 (0.0176069)`

The candidate is 1.60x the same-camera crop floor. Side-by-side inspection
shows no legibility loss in the railings, landings, ceiling relief or practical
light pools; the clearest changes are temporal weather specks. This supports
five casters as a viable atrium budget, but it does **not** establish five as a
safe global default. Other representative interiors and the exterior still
need paired review before any production policy is changed.

## Ruling

Accepted as quantitative and visual evidence for a spatially bounded atrium
policy. Not accepted as authorization to lower the building-wide shadow
budget. No production lighting setting is changed by this sheet.
