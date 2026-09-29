# Production V2 room overview sweep

Evidence class: **INERT**

**OrisonV2SpaceSweep.tscn** captured all 200 semantic spaces in the production
composition, with 400 views. Each room samples a 5 by 5 grid using the real
player capsule dimensions, layer-one collision and a supporting floor ray.
Two separated clear samples supply the ordinary 1.41 metre eye view. The first
retains the carried device; the second hides its CanvasLayers for inspection.
The existing lamp remains enabled; no lighting or material setting changes.
Optional **V2_SWEEP_LEVEL** selects one level. **SHOT_DIR** is required.

This is discovery coverage, not a walkability or fabrication acceptance test.
It teleports between samples and does not exercise locks, routes or every
fixture interaction. A clear sample is not proof that the room is reachable.
Enclosed/reserved rooms remain closed in gameplay. Exterior/passage areas
beyond the 200 semantic spaces still need their own complete sweep.

The completed run is **tmp/v2-space-sweep/sweep.log.receipt.json**: 449 seconds,
200 records, zero harness failures. All 13 overview contact sheets were viewed;
selected larger views informed the boiler and reading-room work. The room-by-
room index **v2_space_review.json** keeps detail and route review pending,
including the partially obstructed landing views. Captures remain local under
**tmp/v2-space-sweep/shots**. An initial script parse error and a deliberately
interrupted overlay-obscured capture are not counted as completed coverage.

Concrete follow-ups from rendered inspection:

- **B1_PUBLIC_CORE** shows an apparent exposed underside/void beneath the
  lowest stair. Check actual slab ownership and collision before changing it.
- **F01_REAR_APRON** shows exposed exterior edges/undersides. Inspect the
  composed outside boundary and route rather than extending a room box blindly.
- **F01_COMMON_B** was empty; the reading-furniture batch addresses its table,
  chairs and bookcases. **F01_LOBBY** and **F01_PACKAGE** remain sparse and need
  their own furnishing/access review.
- **B1_COAL_ROOM** has a stepped rectangular fuel mass. Preserve the coal
  delivery state while replacing that visible heap with appropriate geometry.
- Existing apartment furniture, wet fixtures, radiators, kitchen appliances,
  millwork, stairs and roof machinery are present. Keep them and target concrete
  detail defects: slab-like bed coverings, shelf supports, fixture joints and
  material boundaries. Their presence does not finish the fabrication pass.
- Close lamp illumination exposes strong wood/stone microdetail and bright
  ceramic/metal responses. Review them in the later coordinated mapping pass;
  no global lighting change is justified by this overview alone.

Use the coverage index for the remaining family work. Neither these captures
nor this report promote the completeness ledger or the existing accepted debt.
