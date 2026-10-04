# Source-fitted shop seating

Evidence class: **INERT**

Classification: **ADAPTATION**. The original F01 source owns sixteen funeral
parlour chairs, two rear chapel benches, four Otis & Son stools and eight
luncheonette stools. Sixty original body/back/top records are retained exactly
in the editable native. Counts, footprints, seat heights, back directions and
floor owners remain source-derived.

## Fabrication and materials

**scripts/build_shop_seating.py** makes 416 individually closed positive stocks,
assembled as thirty furnishings: worked timber seats, turned legs, stretchers,
posts and spindles; pedestal stools have bell bases, columns, foot rings/spokes,
seat pans and welted cushions. Spindles enter their seats and crest rails. The
native inspection checks one connected surface-contact graph per assembly at
20 micrometres; this is contact evidence, not a load-capacity calculation.
Eighty-four feet supply 420 complete floor-bearing samples.

**shop_seating.blend** keeps the source boxes, closed construction and forty-two
bounded visible partitions. The portable mesh has 55,200 triangles and matching
collision. Metre UVs, explicit split normals and standard tangent handedness
carry the existing shipping **wood_dark_b**, **chrome_b** and **vinyl_oxblood_b**
maps from the original shop cell. Native materials reference the same relative
images, tile scales and normal strength. The runtime clones original materials
locally before the existing SurfacePass. No catalogue key, map, visual lock,
global shader or lamp calibration is changed.

The runtime removes exactly twelve outward boundary triangles per source stock.
Original imported positions are quantized, so matching allows one measured
encoded position step plus the existing 20 micrometre registration tolerance.
Outward normals distinguish coincident body/back boundaries. Only index buffers
change: remaining position, normal, tangent, UV, colour and material resources
stay literally identical. Old LOD indices are discarded because they still
contain replaced stocks. The entirely replaced Otis chrome batch becomes hidden
with disabled old collision; it never falls back to an unindexed full draw.
Original glTF/bin files remain unchanged.

Both initial Passage mount and streamed reconstruction install the seating
before SurfacePass. Imported mesh references live with each cell and retire
with it. Shop actors, stock/hours, doors, locks, resident keys and saved states
retain their existing owners.

## Inspection and reproduction

Rebuild with **scripts/build_shop_seating.py**, then import twice through the
serialized Godot runner. **scripts/inspect_shop_seating.py** reopens the native,
checks source/map hashes, closed connected stocks, assembly contacts and all
floor samples, and renders front/rear views of the first and last furnishing in
each family. Its default output is **tmp/shop-seating-native**.

**OrisonV2ShopSeatingTest.tscn** checks exact source removal, retained attributes,
catalogue maps, every imported UV derivative, bounded draws, matching collision
and actual floor contacts. Its final development run passes 956 checks. Sixteen
native and thirty-four paired fitted/original production frames are directly
reviewed under **tmp/city-review**. Paired views use identical stationary poses;
they are not walking-route proof. Counters obscure two overview stations, with
clear alternate floor-derived views retained.

Earlier failed runs remain: parse inference, quantized source-boundary matching,
an empty source batch and normal/tangent repacking. The final implementation
corrects those causes rather than weakening equality checks. Run verdicts belong
to completed receipts; the exact committed candidate needs separate verification.

## Management report

REPORT - ORIGINAL SHOP SEATING - 2026-10-04

Canonical **main**, named-path candidate over clean
**d3d9677ed838c6562786ed6ec3bae9d79ada1c0c**. Exact HEAD, origin/main,
merge-base and clean publication state belong to the bound report under
**tmp/city-review/verified**. Its 47-gate comparison uses
**tmp/city-joints/d3d9677-clean-board.json**. Protected 17/17, default V2,
explicit V1 rollback and unchanged ledger **[7, 8, 127, 42, 151, 153]** remain
required. Captures, native checks and wrapper receipts promote no ledger status.

Changes outside the asset/runtime/test boundary: hash attributes, fabrication
inventory and documentation; seventy-one reviewed spatial records are appended
without changing any existing record or classification rule. They name the
sixty source stocks, two runtime bindings and nine test-only references. The
two unresolved test prefix filters remain classified unresolved.

Open findings: remaining shop apparatus and cloth, bar pool table, missed
apartment bed adaptations, whole-shell/weather fit, coordinated roof falls and
outlets, downstream drainage, independent building services and broad room/
material acceptance. Heating cutouts remain parked. Owner decision: none for
this source-owned fabrication. The verifier determines the publication verdict.
