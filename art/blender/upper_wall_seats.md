# Upper wall seats — retained source faces

Evidence class: **INERT**

REPORT - UPPER WALL SEATS - 2026-10-02

Canonical **main** in **C:/PleaseRemainOnTheLine**. Clean preceding implementation
and comparison baseline: **120b28f413b212ede0ce3f777370aba6e0f409da**, with its
complete clean board at **tmp/first-upper-hall-seats/120b28f-clean-board.json**.
This report documents modeled construction and scoped checks. Remaining upper
supports, exterior grade and weather closure prevent whole-shell readiness;
heating cutouts remain parked. No capacity or completeness claim is made.

## Source and construction

**build_upper_wall_seats.py** reads canonical layout and the retained editable
**PreServiceMasonry** bounds directly from **exterior_masonry.blend**. It builds
two repeated 350 mm wide, 300 mm deep west-core I spans beneath the original
**F03_PUBLIC_CORE** and **F05_PUBLIC_CORE** wall bases. Each span joins the actual
lower west-hall north face and C-studio south face through two fitted 20 mm wall
plates, 300 mm seats and real triangular gussets. The flange thickness is 30 mm;
the web is 16 mm. The lower public-core west walls are absent in the source, so
an invented continuous wall does not substitute for the missing spans.

The third assembly carries the unsupported west toe of **F05_C_MAIN** over the
retained **F04_C_MAIN** inner wall. Its 210 mm seat fits the missing outer-leaf
interval between Z 6.35 and 8.25. The retained inner partition, rather than a
nonexistent exterior leaf, owns the backplate face. Four actual triangular ribs
support the ledger. Thirty-two exposed heads and washers sit beside the gussets.
No retained wall, slab, opening, service or collision owner is moved or cut.

The live preflight checks all 92 component volumes and five retained faces with
zero overlaps at **tmp/shell-readiness/upper-wall-seats-preflight1.log.receipt.json**.
Three closed, chamfered native assemblies are clipped into four bounded draws
with 5,116 triangles and no artificial internal caps. Native area, source planes
and outward winding survive partitioning. Matching triangle bodies preserve the
open sections and exact fabricated surfaces.

One isolated mapping failure is retained at
**tmp/shell-readiness/upper-wall-seats-native-inspection1.log.receipt.json**.
At a narrow clipped triangle, reconstructing an undefined MikkTSpace tangent
from rounded normals selected a different chart axis. The generator now carries
the exact authored chart U direction on the native corners, uses it only when
the standard tangent is undefined, and removes the construction attribute from
the runtime export. Unit basis, metre density and actual imported UV-derivative
checks keep their original strict tolerances. No test tolerance is relaxed.

## Inspection and routes

After two imports, the corrected isolated native trial passes all 178 checks at
**tmp/shell-readiness/upper-wall-seats-native-inspection2.log.receipt.json**.
All 21 original sample points gain actual native/live first-hit contact; excluding
only the new seats reproduces all original gaps. Five backplates meet unchanged
wall faces, all 32 native/live heads are exposed, and existing collision remains
clear. All five trial captures are reviewed directly. The isolated full stair
circuit passes 79 ordinary-controller waypoints at
**tmp/shell-readiness/upper-wall-seats-route-trial2.log.receipt.json**. Its final
frame is inspected but mostly obstructed by the nearby wall and carried radio;
it grants no detailed visual acceptance of the route.

The portable generator reproduces the reviewed plan from actual source bounds.
The installed inspection repeats all 178 checks at
**tmp/shell-readiness/upper-wall-seats-production-inspection1.log.receipt.json**;
all five production frames are reviewed. Fine live steel details remain too dark
for final material/render acceptance. Temporary neutral native studio renders
verify hardware form without saving materials or lights into the asset.

Five matched-pose main-viewport visible/hidden observations differ by one or two
draws and 1,400 to 2,830 primitives. These diagnostic counts do not establish
timing, whole-world performance or final finish. Exactly one individually
reviewed generated collision-name reference is appended; previous classifications
remain unchanged. The installed stair circuit repeats all 79 waypoints at
**tmp/shell-readiness/upper-wall-seats-production-route1.log.receipt.json**.
Its final frame has the same limited wall/radio view and is reviewed with that
qualification. Both native studio details are reviewed directly at
**tmp/shell-readiness/upper-wall-seats-production-studio-core_bracket.png** and
**upper-wall-seats-production-studio-c_toe.png**.

The fresh actual installed survey at
**tmp/shell-readiness/post-upper-wall-seats-contact1.log.receipt.json**, reconciled
separately in **post-upper-wall-seats-source-continuity.json**, accounts for 1,006
of 1,030 original stations. Twenty-four remain: eight each on **F03**, **F04**
and **F05**. All seven targeted stations have new actual contacts. Three discovery
frames are reviewed; the upward west-slot view is upright, without the earlier
collinear-up warning, but confers no weather or drainage acceptance.

The complete precommit comparison at **tmp/upper-wall-seats/precommit/board.json**
has 47 gates, zero regressions, reader NEW zero, spatial drift zero and no changed
requirements. Complete clean committed candidate verification against the genuine
clean **120b28f** baseline remains required before publication. This report does
not turn wrapper receipts or images into runtime-contract proof.
