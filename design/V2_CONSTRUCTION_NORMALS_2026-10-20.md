# Construction normals and native cabinet finish

Evidence class: **INERT**. Reviewed implementation checkpoint; no ledger promotion.

The owner's texture direction is now part of **V2_SURFACE_REQUIREMENTS_2026-10-11.md**:
every revised finish chooses material-specific relief and physical scale. Existing
bespoke recipes remain supported. This is not acceptance of every legacy texture.

**art/tools/material_relief.py** authors periodic height in metres and OpenGL
normal derivatives at the declared UV scale. Orange peel, casting skin, working
marks, weave, grain, plaster, glaze and four glass constructions have separate
profiles. Sub-resolution detail is reported for roughness treatment. Signed
micrometre heights use floating-point filtering, avoiding image-filter rounding.
Holes, folded edges, joints, silhouettes and substantial bevels remain geometry.

Seven registered finishes supply cabinet enamel, lining, worked steel, drawn,
reeded, cut and frosted glass. The native Blender cabinet adds a continuous
pressed frame, sheet returns, interleaved hinge knuckles/pins, formed pull,
slotted fasteners, glazing seal, fine embedded wire, an open tray and folded
spring clip. Its 28 stocks contain 38,724 triangles with authored metre charts.
The existing rack keeps its fitted bearings and gains calibrated normal response.
All eight existing cabinet owners receive the successor; four glass treatments
are distributed through their explicit station records. Repair facts, source
pivots, ownership, mechanical stops and save authorities remain intact.

Glass uses authored normals with engine refraction and roughness. It refracts
opaque scenery; nested transparent layers and true caustics are not provided by
this screen-space technique. The visual direction favors expressive surface
character. This batch does not claim physically complete optical simulation.

## Verification and retained failures

The packet is **art/reviews/v2_construction_normals_20261020**.

- **cabinet-import-20261020** received malformed argument packaging and entered
  the project instead of importing. Only this task's confirmed child was stopped;
  the failed wrapper remains. **cabinet-import2-20261020** completed in 559 seconds;
  the small corrected-map import **cabinet-import3-20261020** completed in 11 seconds.
- **cabinet-skin1-20261020** failed because the new fixture omitted its standing
  floor and production voxel-light setup. Its frames are rejected diagnostics.
- **cabinet-skin2-20261020** passed loaded surface checks and leaf manipulation,
  but its large decomposed wheel/screen gesture could not lift a washer from the
  new tray. Four-millimetre physical input waypoints fix the driver; the actual
  collision geometry, movement authority and contact tolerances are unchanged.
- **cabinet-skin3-20261020** completed in 28.94 seconds with 78 passing hand checks,
  zero failures, zero script errors and empty stderr. Loaded UV metric/tangent
  checks, full PBR mip chains and anisotropic filtering pass. It exercises actual
  grab/motion/release, fixed/moving hinges, washer removal/fitting, union motion
  and household snapshot restoration. The production voxel field is live and
  the old screen plate is disabled. These are scoped diagnostics, not a schema-2
  runtime contract or whole-world acceptance.
- The 36-test static run had two Windows file-lock errors during import, with
  no assertion failures. Those two cases and all five final physical-relief tests
  subsequently passed together: seven tests in 86.589 seconds. Other tests are
  reused from the first run. Reader baseline has zero new unread fields; calibrated
  recipe projections report zero discrepancies across 132 tile records.

The native source render, rack renders and corrected game frames were inspected.
The enamel shows shallow relief; drawn/reeded/cut glass distorts the stock and
frosted glass softens it. The fixture has a dark empty background and is not a
room aesthetic acceptance image. The broad surface packet is stale until its
next composed run completes; neither earlier full-world result is repinned.
Whole V2 completion, composed qualification and human appearance remain open.
