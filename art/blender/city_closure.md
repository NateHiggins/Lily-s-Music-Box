# Source-owned city parapet joints

Evidence class: **INERT**

Classification: **ADAPTATION**. This batch removes demonstrated overlapping
corner faces in the original neighboring city masses. It does not establish
whole-city weather performance, structural capacity or broad finish acceptance.

## Construction and mapping

The unchanged **city_shells.blend** retains 335 closed original source solids.
The read-only survey finds 301 same-facing coplanar overlaps; a one-millimetre
outward containment check separates 198 locally exposed overlaps from 103 buried
ones. Before/after renders of three building corners demonstrate dark rectangular
overlap artifacts. **scripts/build_city_closure.py** unions each building's four
original parapet stocks, keeping its actual authored material family.

**city_closure.blend** links the original source, retains 335 exact local stocks
and stores 25 closed connected parapet rings. Every native stock/ring has positive
volume, manifold contiguous edges and no zero-area face. The current export has
84 original building/material partitions and 14,088 triangles, with identical
visible/physical triangles. Existing mast, aerial, tank and beacon GLBs remain
byte-identical. Original layout, positions, roof/slab owners and controllers stay
under their existing authority.

Exact Boolean intersections may create coincident or collinear vertices. Cleanup
welds at most two micrometres: measured maximum movement is 1.974 micrometres and
maximum cleanup boundary error is 1.370 micrometres. Volume change is bounded by
the measured surface area times the weld reach. Exactly collinear triangles merge
into their adjacent native polygon; no positive-area surface is discarded.
Reopened union envelopes are checked against the original native 20-micrometre
registration tolerance. This is finite-precision fabrication, not exact symbolic
equality of every union vertex.

Shared metre charts preserve catalogue tile phase and export standard tangent
handedness. Two microscopic triangles require the existing local-chart fallback;
every remaining triangle passes the same strict derivative check. The exporter
omits zero exactly represented float32 triangles only if present; this rebuild
omits none. Maps remain the exact existing **brick**, **concrete**, **bronze_sheet**,
**soot**, **galvanized_roof** and **brass_mesh** catalogue families. Local material
duplicates enable these charts without modifying shared projection or lighting.
Stone remains provisionally mapped to concrete; the original bronze roof/parapet
designation remains source-owned. Neither is a broad material acceptance claim.

## Inspection and reproducibility

Rebuild with the saved original native and **scripts/build_city_closure.py**.
The construction JSON and portable fixture bind normalized generator/source bytes,
actual current blockout/region registration, original native, maps and retained
hardware. Native inspection reopens the saved result, compares every retained
stock's coordinates, topology and transform with the linked source, verifies all
360 closed volumes and renders six representative corner/roof pairs.

**OrisonV2CityClosureTest.tscn** checks all 84 imported charts, exact catalogue
textures, matching colliders and 1,205 complete retained mast/aerial/tank bearing
stations against the original 100-micrometre target tolerance. Capture selection
tests actual sightlines to each building's own corner, avoiding adjacent-wall
occlusion. Twenty-five close corners and four skyline views supplement native
inspection. These elevated inspection cameras are not walking-route evidence.

Evidence and retained initial failures live under **tmp/city-joints**. The first
focused run passes 2,049 checks, but its northwest-row camera is obstructed.
The revised focused run passes 2,074 checks and supplies a clear northwest-row
corner. The exact committed candidate requires its own completed receipts. Final proof belongs to **verified/verification.json**, its run receipts
and hash-bound reviewed-frame index. Captures and wrapper receipts promote no
completeness-ledger requirement or frame-rate claim.

## Management report

REPORT - CITY PARAPET JOINTS - 2026-10-03

Branch / HEAD / origin/main / merge-base: canonical **main**, named-path candidate
over **379b46727bc663b8722b1d095cc2ead5931600f8**. Exact publication SHAs and clean
worktree state belong to the bound verification/publication report.
Protected 17/17, V2 default and explicit V1 rollback are enforced by the verifier.
Ledger baseline **[7, 8, 127, 42, 151, 153]** is not promoted by this INERT record.
All 47 gates compare with **tmp/city-beacons/379b467-clean-board.json**; zero NEW
unread fields and no new spatial failure remain required. Native/chart/contact
counts are stated above; suite verdicts come only from completed bound receipts.

Changes outside the asset/runtime/test boundary: hash attributes, exact derived
embedded-image ignores, source-work inventory and documentation. Catalogue maps,
fifteen visual locks, historical protected systems and owner captures remain.

Open findings: coordinated main-roof falls/outlets and downstream drainage,
other city/weather joints, courtyard/street closure, independent shop services,
whole-shell readiness and broader room/material acceptance. Heating cutouts stay
parked. Decision needed from owner: none for this source-owned correction.
The candidate verifier determines the publication verdict.
