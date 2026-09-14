# Orison v2 M11C1 owner-first export checkpoint — 2026-08-31

Evidence class: **TECHNICAL CHECKPOINT — DISPOSABLE REHEARSAL — NO PRODUCTION MUTATION**

## Disposition

M11C0 remains accepted as **PASS** for its rehearsal mechanism and **BLOCKED**
for production mutation. M11C1 closes the provenance and target-cell rehearsal
conditions that caused that refusal:

- every authoritative floor-01 source record now has a durable identity and an
  explicit owner supplied by authoring context;
- the disposable exporter batches by owner before material and emits all 17
  target cells with no **CELL_LEGACY_MIXED** remainder;
- canonical geometry, collision, transforms, materials, attributes, semantic
  identities, and compatibility aliases are machine-equivalent to the
  protected monolith;
- every real target cell and declared residency set imports independently;
- the isolated consumer adapter, semantic save/reconstruction path, five
  dangerous seams, and two complete load/unload cycles pass; and
- the selector, layouts, and all protected floor GLTF/BIN files remain
  byte-identical.

The supported next action is a separately authorized real owner-first
**floor_01** export cut. This checkpoint does not perform that cut, redirect a
production consumer, change the selector, authorize M09, retire v1, or merge
main.

Recommendation: **AUTHORIZE THE REAL OWNER-FIRST FLOOR_01 EXPORT CUT.**

## Baseline and protected boundary

The branch **codex/orison-v2-m11c1-owner-first-export** began clean at requested
base **edc18ffb7d5830e05acd98cdaa33a422ea4cb038**. Recorded **origin/main** and
the merge base were both
**c2dc01771bc25b07f5dcf7a6040102345b8c57d5**. The committed selector was and
remains **v1**.

Expected completeness movement was zero requirements and zero promotions. The
pre-write ledger had 150 requirements: **ABSENT 51, HUMAN_ACCEPTED 1,
PROGRAMMED 44, RUNTIME_PROVEN 34, SHELL_ONLY 2, SPATIALLY_PROVEN 18**. Its
blocker scopes were **0 / 1 / 86 / 45 / 101 / 103**. Final counts and blocker
scopes are identical.

The final protected receipt records **17/17** exact matches: both production
layouts, the selector, and every F01–F06/B1 GLTF/BIN. It is stored at
**design/ORISON_V2_M11C1_PROTECTED_FINAL_RECEIPT_2026-08-31.json**. No protected
asset was used as a writable output.

## Source identity and explicit ownership

The inert authoritative sidecar at
**art/data/m11c1/floor01_source_ownership.json** classifies **5,286/5,286**
records exactly once without bounds, centroid, connected-component, or other
spatial inference. It preserves **4,678** authored IDs and assigns reviewed,
durable IDs to the previously anonymous **42 walls, 565 site lights, and one
slab**.

The three Passage-overlapping lights are explicitly ruled as
**F01_SITE_LIGHT_0090**, **F01_SITE_LIGHT_0091**, and
**F01_SITE_LIGHT_0092**, all owned by **CELL_SITE_STREET_COMMON** because their
authored **SITE_PASS_CITY_WINDOW_CARD_CONTEXT** is site/street context. Their
overlap with the Passage envelope is recorded as non-authoritative.

| Owner cell | Source records |
| --- | ---: |
| CELL_ORISON_F01_INTERIOR | 465 |
| CELL_ORISON_FACADE_SHELL | 41 |
| CELL_SITE_STREET_COMMON | 2,192 |
| CELL_PASSAGE | 505 |
| CELL_SHOP_BAR | 375 |
| CELL_SHOP_BODEGA | 161 |
| CELL_SHOP_MODEL_LAUNDRY | 165 |
| CELL_SHOP_SHOE_REBUILDING | 108 |
| CELL_SHOP_KEYS_CUT | 187 |
| CELL_SHOP_HARDWARE_PAINT | 230 |
| CELL_SHOP_FUNERAL_PARLOUR | 121 |
| CELL_SHOP_PHOTO_SUPPLIES | 126 |
| CELL_SHOP_RADIO_SERVICE | 100 |
| CELL_SHOP_PAWNBROKER | 122 |
| CELL_SHOP_NEWS_CIGARS | 84 |
| CELL_SHOP_OTIS_SON | 189 |
| CELL_SHOP_LUNCHEONETTE | 115 |

The first runtime rehearsal exposed the old 0.55 m Passage probe on the exact
source family **storm_sf_*_stall***. Eleven authored shopfront stallboards were
corrected to **CELL_PASSAGE** from their explicit **zone=PASSAGE** and exact
source-ID family before the broader shop batch. No coordinate or collision-hit
position was used as ownership authority. The fresh rehearsal now hits
**CELL_PASSAGE** at 0.55 m and explicitly excludes
**CELL_SHOP_SHOE_REBUILDING**.

## Generated lineage and owner-first export

Disposable run **M11C1-12b0189ee7fe5afb6190447a** used the source-owned
sidecar and the authoritative layout mirror. It did not read the protected
GLTF/BIN as generation input and did not write any production path.

The export records:

- **5,286** authoritative sources plus three fixed supplemental generated
  sources;
- **9,820** generated contributions;
- complete source ID, owner, emission kind, material, collision class, source
  ranges, primitive ranges, triangle ranges, and legacy compatibility identity;
- **609** owner-first output primitives across 17 cells;
- **183,726 triangles** and **345,536 source-referenced vertices**;
- **189** unique semantic owners, including 72 **SITE_SHOP_*** identities;
- **531/531** protected legacy aliases accounted for, with 47 legitimate
  one-to-many owner splits; and
- zero unresolved lineage records and no **CELL_LEGACY_MIXED** cell.

The exporter preserves the **-col** and **-colonly** importer contracts and
uses one generic cell/batch path. The 17 target cells are Orison F01 interior,
Orison facade shell, site street common, Passage, bar, bodega, and eleven
Passage shops. The geometry-free persistent **F01** host is declared separately
as the production service/director composition host.

Two independent disposable runs produce the same candidate and 17-cell
GLTF/BIN bytes: **36/36** compared files match. Run-local IDs and output paths
remain isolated in receipt wrapper fields. After removing only those declared
wrapper fields, both complete-lineage payloads are byte-identical at canonical
SHA-256
**3af6cdaa912ddb10af8efc604bb789bd53bc516b9fe733b2928513f0bc33c5bd**;
the source-range lineage payloads are byte-identical at
**be9b2d22db0faf329633572ad5e7bddda77e65e4858c29af4bac801ea9824f59**.

## Canonical equivalence

All nine equivalence gates pass and the unexplained-difference set is empty.
The protected and owner-first forms have exact source, triangle, vertex,
attribute, material, world-triangle, world-bound, transform, collision-class,
semantic-identity, and compatibility-alias unions.

Owner-first rebatching legitimately changes descriptor topology:

| Property | Protected monolith | Owner-first candidate |
| --- | ---: | ---: |
| Nodes / meshes / primitives | 531 / 531 / 531 | 609 / 609 / 609 |
| Collision objects | 380 | 400 |
| Materials / textures / images | 104 / 304 / 304 | 104 / 304 / 304 |
| Triangles | 183,726 | 183,726 |
| Referenced vertices | 345,536 | 345,536 |

The 78 extra nodes/primitives and 20 extra collision objects are owner splits,
not new geometry. Index width may shrink on owner-local vertex bases; indices
are dereferenced before exact triangle comparison. Raw descriptor-byte
identity is therefore not required and no unexplained payload difference is
accepted.

The protected monolith is **12,703,334 bytes**. The 17 cell descriptors/BINs
total **13,475,594 bytes**, an overhead of **772,260 bytes** or **1.06079×**.
Descriptor overhead is **682,140 bytes** and BIN overhead is **90,120 bytes**.
The 304 textures remain a shared library rather than being copied per cell.

## Target residency and isolated consumer adaptation

A fresh materialization bound to source commit
**c34ad283df148496fbd98e68638470835c930c5c** imports all 17 real cells. Each
cell loads independently, each of the 17 declared residency sets loads, and
full recomposition loads without a legacy remainder. Both measured cycles
report **17/17 cells, 17/17 residency sets, five seams, 15 traversal contracts,
and 189 unique semantic owners**.

The harness adapts only the authorized isolated composition. Production
consumer files are not modified or redirected:

- **BuildingRoot loading** and **index/visibility** are
  **PASS_ISOLATED_ADAPTER** through explicit cell/residency IDs. The
  **BuildingRoot** class itself is deliberately not instantiated; this is the
  precise limit of the rehearsal.
- F01 host passes/directors execute their public production APIs against the
  geometry-free host and active cells.
- **OrisonDetailPass** executes against the unchanged full layout, mounts F01
  detail on the active host, keeps non-F01 hosts hidden and geometry-free, and
  resolves **18 radios / 18 units / zero failures**. Its honest status is
  **PASS_WITH_OFF_SLICE_DEPENDENCY** because **ROOF_DOOR_01** remains on the
  unchanged, unmounted roof slice.
- **VantryPointNetwork** builds 15 authored F01 points, activates an existing
  point, stops the chirp, releases audio policy, and tears down.
- **ExteriorDetailPass**, **ResidentNav**, and the M11A exterior composition
  execute without co-mounting M11A geometry with the target cells.
- save/reconstruction destroys all 17 cells, reconstructs through semantic
  route and threshold contracts, reloads the cells, and restores the exact
  canonical semantic state.

The saved route state contains **ROUTE_ORISON_TO_SHOP_BODEGA**,
**THRESHOLD_SHOP_BODEGA_FRONT**, and **PAVEMENT_TURN**. Its canonical SHA-256 is
**5a957cb1ea7a1679abd2e161ae79974f0c4a8eb0bc9e93de54234307bc9f1e90**
before save, after load, and after reconstruction. It contains no world
coordinates, asset/node paths, or selector authority. The protected v1
**F01_BODEGA_DOOR** and v2 **THRESHOLD_SHOP_BODEGA_FRONT** remain distinct.

## Semantic ownership and seam result

Every required semantic resolves once:

| Identity | Unique owner |
| --- | --- |
| F01_DOOR_06 | CELL_ORISON_FACADE_SHELL |
| F01_BODEGA_DOOR | CELL_SHOP_BODEGA |
| F01_BAR_DOOR | CELL_SHOP_BAR |
| PASSAGE_PORTAL_LT_W / PASSAGE_PORTAL_LT_E | CELL_SITE_STREET_COMMON |
| every SITE_SHOP_* family | one recorded owner; 72 identities total |

All traversal uses the production **PlayerController**, one legitimate initial
placement, collision-bearing movement, public door interaction, zero noclip,
zero intermediate transform writes, and zero teleports.

| Seam | Result |
| --- | --- |
| Orison shell ↔ street | PASS bidirectionally; facade, interior, and street residency; PlayerController grounded. |
| Street ↔ Passage portal | PASS bidirectionally through the real portal. |
| Passage ↔ shop aisles | Ten real bidirectional shop routes PASS; the authored NEWS/CIGARS locked frontage refuses as expected. |
| Bodega ↔ street | PASS bidirectionally through the protected v1 bodega leaf. |
| Facade shell ↔ interior | PASS bidirectionally; start +0.2250 m, interior -0.8755 m, return +0.2246 m relative to the authored seam plane; both facade and interior collision owners observed. |

The prior shoe-shop interception is resolved: the exact 0.55 m regression ray
hits **CELL_PASSAGE**, and the distinct shoe route traverses both directions.
The locked NEWS/CIGARS frontage is not misreported as an eleventh bidirectional
shop route.

## Performance and lifecycle

These measurements include root, profile, active residency set, and simulation
state. They are rehearsal load measurements, not a production streaming
schedule.

| Measure | Cycle 1 | Cycle 2 |
| --- | ---: | ---: |
| Full recomposition load + instantiate | 2,375.324 ms | 2,374.835 ms |
| Sum of 17 independent cell loads + instantiates | 11,916.147 ms | 11,810.746 ms |
| Sum of all 17 residency-set loads + instantiates | 14,292.012 ms | 14,204.320 ms |
| Full tree process / physics snapshot | 2,424.150 / 0.067 ms | 2,422.429 / 0.079 ms |

Full recomposition contains **1,415 nodes, 597 mesh instances/surfaces, 400
collision objects/shapes, 182,610 rendered triangles, and 343,304 rendered
vertices**. Headless GPU and VRAM are correctly unavailable and are not
inferred.

The Windows Forward+ packet measures **93–615 draw calls**, **0.015–0.019 ms
GPU samples**, and **1,865,585,808–2,204,525,360 bytes VRAM**. These short
capture samples are recorded as measured and are not generalized to steady
gameplay performance.

The two complete runtime cycles finish with **0 resource, 0 node, and 0 orphan
growth**, **-65 objects** relative to the warmed baseline, and zero retained
tracked owners. The second cycle changes **-1 object, 0 resources, 0 nodes, and
0 orphans** from the first. The full five-frame capture lifecycle ends at
exactly **0 objects, 0 resources, 0 nodes, and 0 orphans** relative to its
warmed control. Public teardown uses no forced deletion or node-name reach-in.

## Dangerous-seam packet

The immutable packet is
**art/renders/orison_v2/m11c1_owner_first_rehearsal_01/**. It contains exactly
five **1600×900 Forward+** proof frames, the exact runtime configuration,
complete export/lineage/equivalence receipts, materialization/import logs,
runtime/capture logs, and hash receipts:

1. [Orison shell ↔ street](../art/renders/orison_v2/m11c1_owner_first_rehearsal_01/frames/orison_shell_street.png);
2. [street ↔ Passage portal](../art/renders/orison_v2/m11c1_owner_first_rehearsal_01/frames/street_passage_portal.png);
3. [Passage ↔ west shop aisle](../art/renders/orison_v2/m11c1_owner_first_rehearsal_01/frames/passage_west_shop_aisle.png);
4. [bodega ↔ street](../art/renders/orison_v2/m11c1_owner_first_rehearsal_01/frames/bodega_street_threshold.png); and
5. [facade shell ↔ interior](../art/renders/orison_v2/m11c1_owner_first_rehearsal_01/frames/facade_shell_interior.png).

The production PlayerController camera is used. No capture-only geometry,
collision, light, label, arrow, or overlay is present. Camera occlusion and
objective luminance gates pass. The packet is intentionally dark technical
seam evidence; it is not a self-declared human art/readability acceptance.
Minor visual debt is the foreground trunk/pole in the Orison frame, the dark
bodega view, and the tight facade/interior view; none obscures its target.
The packet manifest binds the copied raw bytes, and
**committed_packet_receipt.json** binds all 27 evidence-commit paths to their
Git blob identities so line-ending conversion cannot masquerade as missing
evidence.

## Validation and audit disposition

Focused suites pass **25/25** source-identity checks, **10/10** owner-first
export checks, **17/17** runtime-rehearsal checks, and **7/7** scanner-adapter
checks. M11C0 regressions pass **13/13**, **5/5**, and **5/5**. Static audit
suites pass completeness **99/99**, spatial **51/51**, systemic authority
**34/34**, and data consumption **14/14**. Python compilation passes.

The fresh Godot materialization/import, two-cycle runtime, and five-frame
capture each exit **0 / PASS**. Runtime stderr contains three warnings and
capture stderr four warnings, all the explicitly qualified unchanged
**ROOF_DOOR_01** off-slice condition; both contain zero error lines. No
ObjectDB, resource, or orphan leak is reported.

Repository audits remain truthful:

- completeness exits **2** with the identical 150-row ledger and blocker
  scopes;
- spatial exits **0**, with no new unclassified record, classification change,
  vanished target, unresolved save contract, or stale preserved record;
- systemic authority exits **0** with the same 59 findings and no new
  actionable or baseline-policy violation; and
- data consumption exits **1** with historical debt exactly unchanged at
  **1,289 unread fields, 11 unread files, two monotonic-only durable values,
  and one malformed record**.

The final spatial scanner observes additional test/evidence-only identifiers,
but no production spatial drift. The data before/after comparison attributes
zero new unread files, unread fields, or monotonic-only values to M11C1. No
audit baseline is changed.

An informational Ruff invocation exits **1** on 11 style-only findings in the
new Python/test files: seven unused imports, three import-placement findings,
and one test lambda style finding. It reports no syntax or behavior failure;
the same files compile and their 59 focused tests pass. Source was not edited
after the frozen runtime/capture run merely to rewrite style.

## Remaining limitations and debts

- The checked-in layout asks for wall-finish IDs **f01_w00..f01_w09**, while
  the current bake authoring folders use **f01_wall_00..f01_wall_09**. The
  disposable export therefore binds 30 exact tracked production texture maps
  read-only as **LEGACY_COMPATIBILITY_TEXTURE_INPUT**. This is open authoring-ID
  debt, not unread geometry or unresolved lineage.
- **retail_bar_darts_door-1** is one authored inverted furniture box. The
  authoritative generator already rejects it; it is explicitly receipted as
  zero emission rather than silently repaired or called unresolved.
- **ROOF_DOOR_01** remains an expected off-slice dependency. The real floor-01
  cut must not fabricate it; later roof residency must supply it.
- **NEWS/CIGARS** is authored locked. Its collision refusal is the correct
  contract, not a missing route.
- The rehearsal intentionally does not redirect or instantiate production
  **BuildingRoot**. The authorized real cut must adapt that consumer in its own
  reviewed production change.
- M09, selector cutover, v1 retirement, production-layout replacement, and a
  merge to main remain unauthorized.

## Decision

M11C1 removes the source-provenance, legacy-remainder, target-residency,
semantic-ownership, shoe-collision, and lifecycle blockers found by M11C0.
No unresolved lineage record or target-cell seam blocker remains in this
rehearsal. The protected production files remain unchanged, so the next change
still requires explicit authorization and its own rollback-aware proof.

**AUTHORIZE THE REAL OWNER-FIRST FLOOR_01 EXPORT CUT.**
