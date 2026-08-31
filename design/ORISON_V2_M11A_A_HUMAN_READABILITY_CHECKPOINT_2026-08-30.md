# Orison v2 M11A-A first exterior-cell human-readability checkpoint — 2026-08-30

Evidence class: **TECHNICAL CHECKPOINT — HUMAN REVIEW PENDING — NO STATUS PROMOTION**

## Decision

The bounded M11A-A presentation correction is technically complete. The
production cell now communicates **ORISON → PAVEMENT → SHOP_BODEGA →
DELIVERIES → ORISON RETURN** with every explicit route-guide visual hidden.
The focused production objective is **PASS 40/40**, the replacement Forward+
packet is **PASS 4/4**, and the matched capture-lifecycle control is **PASS
3/3**.

This report does not self-declare human readability. The replacement packet is
**HUMAN REVIEW PENDING** until the owner answers the question at the end of
this checkpoint.

M11A's accepted architecture is unchanged. This checkpoint does not authorize
M09, M10, a selector cutover, production-layout replacement, v1 retirement,
broader exterior construction, or a merge to main. The committed selector
default remains **v1**, and the work remains only on
**codex/orison-v2-m11a-first-exterior-cell**.

## Authorization and frozen boundary

Work continued from
**c955b43be081a36765d4c4c9934c064816b4f4c6** on the authorized branch. The
technical disposition explicitly accepted and froze the bodega bucket,
timetable-driven advancement, inventory/work-order ownership, semantic save
state, exterior resolver, routes, threshold, generic construction, rotation,
collision topology, public teardown, selector, and protected assets.

This correction changes only source-owned presentation records, production
night lighting, camera-evidence placements, a public presentation toggle,
focused proof, and new evidence. No route node, threshold identity, collision
record, durable shop field, save authority, gameplay authority, or selector
mapping changed.

## Original human finding and correction

The superseded packet at
**art/renders/orison_v2/m11a_first_exterior_cell_01/** was technically
navigable but visually failed acceptance. Frame 2 identified the threshold;
the other views depended on a bright route stripe amid near-black geometry.
The pavement, Orison destination, storefront depth, and shop fixtures did not
provide enough independent orientation.

The bounded correction adds:

- a low-energy procedural night sky, differentiated horizon, restrained
  ambient contribution, opposing night bounce, and reduced fog density;
- pavement joints, curb coping, drainage/wear patches, wet material response,
  and separated lamp pools that describe travel direction;
- a bounded Orison facade mass, entrance surround, canopy, upper windows,
  courses, and warm threshold light that identify the building without
  constructing a wider street or building;
- a shopfront spill and side-wall rhythm that expose storefront depth;
- shelf tiers, stock silhouettes, readable aisle width, service counter and
  scale, cooler mass, delivery crates, handcart, worn floor, and a lit
  deliveries recess;
- ten new period-worn material records for wet paving, joints, aged paint,
  amber windows, lamp glass, crates, produce, paper, blue paint, and the
  icebox interior.

The change is not a blanket exposure lift. Practical pools, material
separation, facade apertures, and surface rhythm carry the route. Large dark
areas remain where the authorized cell ends.

## Existing simulation drives the visible shop

The renderer still enumerates the two existing generic geometry templates.
Every authored box and label now declares one explicit presentation role:
**environment**, **route_guide**, or **stock**. The builder validates and
consumes that role; it does not infer it from a node or record name.
The exact-key geometry source is versioned from schema 1 to schema 2 for this
new required field rather than silently changing the meaning of schema 1.

Stock silhouettes are a presentation of the existing durable
**SHOP_BODEGA** bucket. The public refresh reads the bucket snapshot and makes
the 18 stock visuals visible only when durable stock is nonzero. It records
the existing stock, condition, and staffing mode on the constructed cell. It
does not advance time, grant inventory, restock, create a new stock authority,
or alter WorkOrders. The final receipt reads stock 24, condition 100, and an
attended staffing mode from the existing bucket.

## Hidden-guide proof

**OrisonV2ExteriorCell.set_route_guides_visible** is a presentation-only
public surface. It affects the five authored **route_guide** visuals and does
not touch collision, route data, threshold data, or reconstruction.
The existing municipal-remnant guide remains the construction default; the
authorized hidden state operates on those same production visuals and is the
state required for this human packet.

The capture process rendered an in-memory enabled control and hidden control
before producing the human packet:

| Check | Enabled | Hidden | Result |
| --- | ---: | ---: | --- |
| Explicit guide visuals affected | 5 | 5 | Expected |
| Collision shapes | 34 | 34 | Unchanged |
| Collision objects | 6 | 6 | Unchanged |
| Threshold identity | **THRESHOLD_SHOP_BODEGA_FRONT** | same | Exact |
| Route identities | two | same two | Exact |
| Return reconstruction | **PAVEMENT_TURN** | same | Exact |
| Resolved-frame SHA-256 | **c6849523…0b35** | **63966992…a1df** | Visually different |

The sampled Forward+ images differ at 735 of 22,600 samples, or 3.2522%,
proving that the switch hides real visuals. All four packet frames assert the
hidden state. The hidden state leaves stock presentation active.

## Replacement human packet

Packet:
**art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/**

The directory contains exactly four PNG frames. Each is 1600×900 Forward+,
uses the real production module and current production PlayerController
camera, uses one legitimate semantic initial placement followed by
collision-bearing traversal, and contains no capture-only geometry,
capture-only lights, developer overlay, or explicit route guide.

| Frame | SHA-256 | CPU median ms | Physics median ms | GPU median ms | Draw calls |
| --- | --- | ---: | ---: | ---: | ---: |
| **01_orison_side_route_beginning.png** | **2b071621312c9d9117714acd3064b388fca73aee7d7c67580f584c14bb08999d** | 38.924 | 0.507 | 0.915 | 373 |
| **02_bodega_threshold_approach.png** | **8c36035d068ac44d71235b725a5e48fbd9a7be63d1b0ff7891e3fd3ad0cd3092** | 2.246 | 0.205 | 1.007 | 363 |
| **03_bodega_interior_continuing_route.png** | **fc40afbf157aa56a2b7170c04720fc9084cfffb50c6ded6a7015db9fa6de8777** | 2.463 | 0.184 | 0.947 | 341 |
| **04_return_direction_toward_orison.png** | **8ef7080e859fd90e903cd2d01bdab3e259ebb7fc95985ce05b9fa2a495f6ae04** | 2.749 | 0.494 | 1.015 | 340 |

GPU timing is directly reported and marked trustworthy by Forward+ for all
eight samples at each station. Frame 1 is the fresh-process first-station
sample and is reported separately from the 2.246–2.749 ms later-station CPU
medians. The storefront
opens through **PlayerController.use_primary_interaction** in 1.027 ms before
animation settle.

The final camera composition was independently preflighted. Frame 1 holds the
Orison entrance and lettering at the near origin, the continuous pavement,
and the bodega blade/awning at the far endpoint. Frame 2 presents the public
threshold. Frame 3 presents stocked aisles, cooler/storage mass, service
volume, and the deliveries opening. Frame 4 uses curb, joints, lamp rhythm,
and pavement response to return toward the recognizable multi-storey Orison
facade and warm entrance.

## Luminance disposition

Statistics use Rec. 709 coefficients over the exact packet PNG bytes. They are
descriptive evidence, not a substitute for human acceptance.

| Frame | Superseded mean | New mean | Superseded below 5% | New below 5% |
| --- | ---: | ---: | ---: | ---: |
| 01 | 0.04095 | 0.084057 | 71.70% | 36.58% |
| 02 | 0.07032 | 0.100220 | 57.79% | 30.48% |
| 03 | 0.07777 | 0.128286 | 22.29% | 23.06% |
| 04 | 0.04111 | 0.066217 | 77.56% | 59.78% |

The named navigable regions are more important than full-frame sky and
off-cell black:

| Region | Mean | Below 2% | Below 5% | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Pavement | 0.115764 | 1.929% | 10.462% | 0.462893 |
| Shop interior | 0.134081 | 0.896% | 24.643% | 0.771163 |
| Darkest navigable area | 0.145582 | 0.067% | 13.223% | 0.771163 |
| Orison facade | 0.092306 | 27.046% | 56.246% | 0.826693 |
| Brightest sign/light sample | 0.137915 | 21.084% | 25.773% | 0.597180 |

This preserves night contrast while preventing crushed-black navigation. The
high dark fraction in the return frame is primarily sky and unbuilt off-cell
space; the pavement boundary and destination remain legible.

## Objective and reconstruction proof

The final focused objective is **PASS 40/40**. It proves all original M11A
contracts plus the new presentation contract:

- guide visuals enable and hide through the public API;
- the hidden state preserves collision, threshold, routes, and semantic
  reconstruction exactly;
- stock presentation consumes the existing durable bodega bucket; real
  timetable advancement from stock 24 to stock 0 hides exactly the 18 stock
  visuals, and save/reconstruction restores that depleted visual state;
- the real PlayerController traverses the collision-bearing route and opens
  the real storefront leaf;
- the public counter honestly refuses the unrelated part without mutating
  WorkOrders or inventory;
- save, destruction, reload, reconstruction, and public placement preserve
  the bucket, semantic cursor, and awaiting-part job with no saved world
  coordinate;
- the disposable 35-degree second shop and route remain attached with 0.0 m
  error and exactly match first-instance node, mesh, and collision cost;
- public teardown is deterministic and clears scene owners and strong
  references.

The final semantic save SHA-256 is
**31e5f576f3e1a8a97084c576b7f373b44310352f7d13e4ded428474ea32d7379**.
The canonical saved and loaded semantic subset is exact at
**fd99640eb26ea034a81dbea270eb7da0b3be739391f48ed3a9f8a4e71487c5c4**.

## Capture-lifecycle trace

The final production capture reproduces its raw post-teardown delta: +53
objects, +6 resources, zero orphan nodes. Both cell and PlayerController weak
references release, and public teardown reports zero retained strong
references.

The new matched Forward+ lifecycle harness performs one camera-only control,
one module cycle, and a second module cycle in the same process through only
the public teardown API:

| Boundary | Objects | Resources | Nodes | Orphans |
| --- | ---: | ---: | ---: | ---: |
| Process after initial settle | 1,684 | 46 | 35 | 0 |
| Camera-only capture control | 1,777 | 46 | 35 | 0 |
| Module cycle 1 after teardown | 1,704 | 52 | 35 | 0 |
| Module cycle 2 after teardown | 1,704 | 52 | 35 | 0 |

The module cycles retain 73 fewer objects than the matched camera-only
control, so the raw +53 capture-process object delta is not a retained M11A-A
scene owner. Runtime census finds zero live module-owned objects in either
cycle. The second cycle adds zero objects, resources, nodes, or orphans.

The aggregate monitor's persistent increase is six resources. The ID census
isolates 23 resource IDs after each module cycle that were absent from the
control snapshot. Every one has a current retainer: nine through exact
**MatLib._cache** chains and 14 through exact **ResourceLoader** path-cache
ownership. The MatLib subset is three **StandardMaterial3D** resources and six
shared brass/oak **CompressedTexture2D** resources behind three cache entries.
Cycle 2 reuses the exact same MatLib resource IDs; it creates no new retained
ID. The attribution gate fails any amplified cycle with an unattributed ID.
There are zero unattributed resources and zero surviving module nodes or
non-resource objects. This is measured reusable process caching, not an
untraced leak.

The harness uses no node-name reach-in and no forced object deletion.

## Audit and regression results

| Command | Exit | Result |
| --- | ---: | --- |
| **audit_orison_v2_completeness.py** | 2 | Expected incomplete rebuild ledger; all 150 requirement/status and six blocker-scope counts exactly unchanged. |
| **audit_orison_spatial_dependencies.py** | 0 | 3,653 records; +1 test-only scene-path provenance record, zero production drift, failures, vanished targets, or unresolved save contracts. |
| **audit_systemic_situation_authority.py** | 0 | 59 findings, 35 production and 24 test; exactly unchanged, zero new actionable findings or policy violations. |
| **audit_data_consumption.py** | 1 | Expected reviewed historical debt: 1,303 findings exactly unchanged; zero M11A-A/exterior findings. |
| Completeness tests | 0 | 91/91. |
| Spatial tests | 0 | 51/51. |
| Systemic-authority tests | 0 | 34/34. |
| Data-consumption tests | 0 | 14/14. |
| M11A-A production objective | 0 | 40/40; includes stock depletion and reconstruction; stderr empty. |
| M11A-A final Forward+ capture | 0 | 4/4, exactly four 1600×900 PNGs; stderr empty. |
| M11A-A lifecycle control | 0 | 3/3; zero second-cycle growth and zero live module-owned objects. |
| Completeness evidence-impact for this checkpoint | 0 | Admitted as **CHECKPOINT** with an empty requirements-changed set. |

Completeness remains: **ABSENT 50, HUMAN_ACCEPTED 1, PROGRAMMED 44,
RUNTIME_PROVEN 34, SHELL_ONLY 3, SPATIALLY_PROVEN 18**. Blocker scopes remain
**0 / 1 / 86 / 45 / 101 / 103**. No completeness status or blocker moved.

The data audit remains **FIELD_UNREAD 1,289, FILE_UNREAD 11, MALFORMED 1,
DURABLE_NUMERIC_MONOTONIC_ONLY 2**. There is no new unread file, unread field,
or monotonic-only value.

The one spatial-count increment is the new lifecycle test's test-tier
reference to the production exterior-cell scene. It is classified
**TEST_CONTRACT / UPDATE_TEST_FIXTURE**, is non-gameplay, and does not move a
production spatial dependency.

## Protected boundary

The focused objective compares all 17 protected SHA-256 values before and
after. Both layout files, the selector, and every floor GLTF/BIN match exactly.
The selector hash remains
**d2b3db95d72e4a418c0e7184e6b3368da723a945192024a10ee937ea604c9802**;
both layout hashes remain
**68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d**.
The selector source still declares **DEFAULT_ID = v1**.

No production layout, floor asset, project setting, selector, historical
packet, simulation bucket, save fact, or gameplay authority changed.

## Remaining limitations

- Human acceptance of this replacement packet is pending; technical capture
  and luminance checks do not decide it.
- The Orison word is slightly cropped at the near-left edge of frame 1, while
  the distinctive entrance, facade, and enough lettering remain unambiguous.
- The authorized cell deliberately ends in dark off-cell space. No wider
  building or street was invented to fill it.
- The bodega still has no production-authorized maintenance part/order. Its
  public service interaction remains the honest no-open-order refusal proven
  by M11A.
- The rotated second shop remains disposable architecture proof and is absent
  from the human packet.
- This isolated v2 exterior module is not selector-wired and does not redirect
  production ownership.

## Evidence index

- **art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/01_orison_side_route_beginning.png**
- **art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/02_bodega_threshold_approach.png**
- **art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/03_bodega_interior_continuing_route.png**
- **art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/04_return_direction_toward_orison.png**
- **art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/production_cell_capture_receipt.json**
- **art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/objective_test_receipt.json**
- **art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/capture_lifecycle_receipt.json**
- **art/renders/orison_v2/m11aa_first_exterior_cell_readability_01/validation_receipt.json**

The superseded packet remains untouched. This checkpoint is inert evidence and
must not promote unrelated requirements.

## Human-review question

“Without the route stripe, can a first-time player identify Orison, follow the
pavement to the bodega, recognize and enter the threshold, understand the shop
interior and deliveries continuation, then turn around and find Orison again?”
