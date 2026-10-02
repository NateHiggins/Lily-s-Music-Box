# Roof bulkhead upper closures

Evidence class: **INERT**

The actual roof overview in **tmp/shell-readiness/before2/roof_overview.png**
showed both stair bulkheads open from above. Each retained ceiling rendered
only its interior underside and had no physical body. The authored roof source
already specifies a ceiling; this repairs its exterior presentation and body
without moving the stairs, doors, lift, plant or interior ceiling finish.

**scripts/build_roof_bulkhead_caps.py** derives the two caps from
**art/data/orison_v2/roof_source.json** and the existing blockout dimensions:
200 mm depth, underside **22.2 m**, top **22.4 m**. The footprint extends 70 mm
past each room centreline to seat on the complete retained 140 mm wall.
The generator refuses an unprojected roof or unhandled roof-ceiling port.
Future penetrations need their own source projection and fitted reveals.

**roof_bulkhead_caps.blend/glb** provide seven bounded native pieces and
78 triangles. The top, outer edges and narrow exterior underside rim are new;
the original interior ceiling surfaces remain. There are no caps at spatial
culling divisions, no duplicate horizontal footprints and no new material key.
Each piece has one source-depth box body under **RoofBulkheadCaps**. Full-precision
imported metre UVs, normals, tangents and concrete assignments are inspected
in the actual composed production world. Exterior weather finish, drainage and
material refinement remain separate work; these tests do not calculate loads.

**tmp/roof-closures/inspection1.log.receipt.json** records the focused run:
210 checks, eighteen upper contacts, twenty-four wall bearings, eighteen
reproduced original upper gaps and eighteen retained interior undersides,
zero failures. Five exported upper/oblique/interior frames were directly
inspected. Roof and vertical walks plus a clean committed comparison remain
required before publication. This wrapper receipt grants no runtime or ledger
completeness claim.

The preceding rim candidate **3a3ca03effc97fb8e502aa0600a671e3c8a35cf2** passes
ten binding scene suites but its complete comparison is blocked by three
new incidental test references in the spatial board. Those exact references,
the cap collision naming pattern and the two test room owners are individually
reviewed and appended to the manifest. Audit logic and prior classifications
remain unchanged. Final verification compares both roof corrections with the
genuine clean **cd5498b** board, preserving the failed comparison separately.

Heating apertures stay parked. The wider preliminary contact survey still
requires source-volume inspection of foundations, setbacks and embedded walls.
Discovery also identifies potentially exposed lower-ceiling tops; these are
unaccepted findings, since existing stairs, walking slabs and registered exterior
owners must be resolved first. Neither roof repair closes whole-shell readiness
or any of the six location and infrastructure phases.
