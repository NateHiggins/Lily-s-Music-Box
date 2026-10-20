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

The first composed attempt, **surface8**, stopped at native preflight in ten
seconds because five city families still bound the 92-entry material manifest.
**tools/renew_additive_material_bindings.py** verifies all 92 previous records
and other manifest fields are identical, validates every other native dependency
and recorded output digest, archives original construction records, and renews
only construction source hashes and their metadata dependency chain. It never
edits a runtime contract. Three tests reject altered old materials, sources and
meshes and verify preservation/archiving. The seven-entry extension therefore
requires no unchanged-city Blender rebuild or replay of historical evidence.
The next composed run still has to establish fresh runtime qualification.

**surface9** completed 40,051 checks with seven failures, all in the older normal
calibration guard, which expected 0.35 for the seven new metric recipes. Its
inventory found zero UV/PBR/mip defects across 26,844 draws, 17,517 meshes,
6,393 materials and 520 textures. The failed contract and original logs remain
in the packet. The guard now checks metric recipe units, convention and declared
strength instead of that legacy default. The small family bench calls the same
ABI preflight, and the composed suite rejects an invalid ABI before world build.
No previous passing contract is edited or reused as a new pass.

The canonical-checkout ABI and hand bench subsequently passed in 34.35 seconds
with empty stderr. **surface10** was deliberately stopped at 342 seconds after
the static board found one unreferenced duplicate albedo sidecar with default
no-mip settings; it produced no completed runtime qualification. The settings
are repaired. The import preflight now includes nonignored, unstaged images in
its authored physical folders, and a real temporary-Git regression checks both
unstaged and staged coverage while preserving ignored local files. Post-import
static checks pass in both checkouts. This prevents that staging gap from
reaching another long world build. The complete board's tools tests passed;
its surface qualification remains pending the fresh composed result.

## Completed surface qualification

**surface11** ran in the canonical checkout and passed **40,065 checks, zero
failures**, with zero unresolved technical surface findings: 26,844 draws,
17,517 meshes, 6,393 materials and 520 textures. Its schema-2 test-written
contract reports production composition, surface requirements and runtime-owned
teardown PASS. Disk save reconstruction is explicitly NOT_EXECUTED in this
suite. The wrapper completed in 949.69 seconds with zero script errors; seven
historical Texture RID exit warnings remain separate lifecycle work.

The published packet is **art/renders/orison_v2/surface_requirements_20261011**.
Both checkouts qualify it with zero defects. It binds 6,272 current inputs to
SHA-256 **18615aea240e9b280d700cb7c22fdaa6686c99f3294046599d7382458c914d74**.
The 23-image technical review contains 21 fresh composed frames and two reused,
unchanged native handheld/character specimen views, explicitly identified in
its image records. The predecessors are preserved independently under
**art/reviews/v2_surface_final_20261020**; the earlier unqualified renewal archive
is also retained. No old contract was repinned. Native source and corrected
in-game render checks are complete for this batch. Human appearance acceptance,
flat book bindings and broader V2 completion remain open.
