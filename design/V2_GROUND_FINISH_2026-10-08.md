# Courtyard and city-ground asphalt finish

Evidence class: **INERT**

REPORT - Bounded ground finish - 2026-10-08

Branch / starting HEAD / origin/main / merge-base: **main / 03118dd7 / same / same**.

The existing 1,876 asphalt groups now use a darker local tint, restrained normal
response and high roughness. Existing asphalt maps, metre UVs, soil, native
geometry, foundation positions and collision remain unchanged. No catalogue
key or texture is added. The shared asphalt material remains unchanged.

Read-only Blender review opens the saved ground and foundation sources and
renders two before/after views under neutral light. Installed comparisons retain
the original warm carried lamp. This is a surface finish pass; the four native
and GLB files are byte-identical to the starting commit. Their hashes are in
**art/renders/orison_v2/ground_finish_20261008/native/review.json**.

## Review and verification

Packet: **art/renders/orison_v2/ground_finish_20261008**. Two native and two
installed before/after pairs are reviewed at west city bedding and courtyard
city plinth. The old west-front-seam camera now faces an interior counter;
its diagnostic captures are excluded from ground evidence. Native review omits
the superstructure, which appears in the separate installed views.

The extended ground/foundation inspection retains all geometry, exact-export,
collision, original station and boiler-window checks. It also checks the exact
finish recipe, preserved maps, real mip chains, physical tile size and immutable
shared material. Shared texture readback runs once instead of per terrain tile.
All 12 existing view stations remain in the inspection even when captures are
filtered. No asset import is needed.

Run01 provides the reviewed images and successful geometry/finish checks;
uncaptured-view counters lacked settling and are not used as matched observations.
Run02 corrected settling but could not write its report without a screenshot-created
directory; it timed out and provides no verdict. The test now creates that
directory explicitly and exits on a write failure. Final run03 passes **28,732 checks**, zero failures: **2,112 ground
partitions**, **9,060 triangles**, **46 terrain contacts**, **2 retained
embedded stations**, and **all 48 original stations reproduced**. Production inputs are unchanged
between these checks. Raw records are preserved without rewriting their claims.

Reader NEW=0. Inspection records and wrapper receipts are INERT; no new schema-2
runtime contract or completeness-ledger acceptance is claimed.

## Closeout

Worktree clean at end: no; pre-existing owner insitu files, two EOL-only edits,
supplied review inputs and unrelated UIDs remain outside this batch. Stage named
owned paths only. Protected paths and selector are unchanged by implementation.

Changes outside expected boundary: focused capture/finish checks in the existing
ground/foundation validator and a read-only Blender review script. Open findings:
broader city-ground interfaces, drainage, shell/roof details, weather readiness
and full V2 acceptance. Decision needed from owner: none.

Last line: bounded ground finish pass; broader V2 remains open.
