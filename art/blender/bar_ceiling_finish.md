# Local Harukiya smoke-film ceiling finish

Evidence class: **INERT**

Classification: **ADAPTATION**. The four original **retail_bar_ceil** stocks
retain every source record, triangle, normal, datum and physical owner. Their
old soot plate rendered as large raised mineral cracks across the ceiling.
The local **smoked_plaster** catalogue finish gives these faces fine plaster
relief and broad optical smoke staining. The existing shared **soot** key
continues to serve coal, speakers, the scoreboard and other original uses.

**art/tools/build_smoked_plaster.py** creates deterministic periodic albedo,
roughness, height and tangent-normal maps without photographic pixels,
lettering, joints or baked illumination. Pigment staining varies independently
of the substrate relief. The 1.8-metre tile has 0.22-mm nominal height range;
normal strength remains the catalogue standard 0.35. Mean albedo stays near
RGB 28, matching the old plate's dark tone. Fine-scale source images are
2048 square; shipping albedo, roughness and normal imports generate mipmaps.
The height map records source relief and adds no new runtime parallax tier.

**scripts/build_bar_ceiling_finish.py** extracts the 48 actual source
triangles and stores four individually closed editable native stocks.
One material partition carries metre charts, normals and tangents without
embedded image duplication. **orison_v2_bar_ceiling_finish.gd** validates
all source boxes and exact oriented triangle membership before splitting
only those indices from the old surface. It preserves the remaining serialized
vertex, normal and UV buffers, appends the native chart surface to the same
mesh, and updates the original owner's exact visible collision. It adds no
second ceiling, body or gameplay owner. The retail SurfacePass retains the
existing state and optical consumers. The shared MatLib cache remains intact.

The catalogue addition preserves all 62 prior runtime specifications, old
shipping maps and fifteen visual locks. **refresh_catalogue_bindings.py**
proves thirteen existing native families and exports unchanged, then refreshes
only catalogue input hashes and dependent fixture hashes. Source layout and
bar glTF/bin remain byte-identical. No lighting, shader recipe, environment,
fixture setting, door, schedule, Mina mesh or simulation is redesigned.

**scripts/inspect_bar_ceiling_finish.py** reads the saved native, checks all
four positive closed stocks and 192 source-equal face samples, and renders
four views with actual catalogue maps and read-only source context. Close
micrograin and pipe-clearance frames use a diagnostic raking studio light;
this is not a production lighting change or a substitute for game captures.
Dynamic fixture actors and the fitted runtime pipe/light supports are absent
from that native context. Production tests separately inspect them.

**OrisonV2BarCeilingFinishTest** checks all four immutable records, every
original oriented triangle, retained serialized buffers, metre UV derivatives,
exact original-owner collision and the active retail material. Four paired
views require a clear ordinary standing capsule and original floor support.
The visual comparison restores the old mesh and surface temporarily while
keeping identical physical geometry. Ordinary production lamps and the carried
lamp remain unchanged; native studio-light frames are diagnostic only.

Scoped inspection and receipts live in **tmp/bar-ceiling-finish**. Captures
and **suite_run** receipts grant no runtime-ledger promotion. This repairs one
visible ceiling defect; roof falls/outlets, original utility endpoints,
independent shop services, gallery overlaps, remaining apparatus and whole-game
geometry/material acceptance remain open.
