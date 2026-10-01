# V2 composed city production map — October 1

Evidence class: **INERT**

REPORT - V2 CITY COMPOSITION - 2026-10-01

This is a source, visual-discovery and work register. Wrapper suite receipts
and the captures below do not promote completeness requirements. Raw architecture,
infrastructure, mapping preparation and final material polish are separate states.
The complete phase remains open; the first composition batch closes three
demonstrated omissions without replacing accepted fabrication.

## Source and runtime ownership

Canonical checkout is **C:/PleaseRemainOnTheLine**, **main**. The clean starting
HEAD, origin/main and merge-base were **4c4d641318289983a68d04769de411f7e984535c**.
The complete clean baseline board is **tmp/city-architecture/baseline/board.json**.
Candidate verification and the exact committed outcome are recorded in
**tmp/city-architecture/final-verified/verification.json** and the follow-up report.
The earlier **verified/verification.json** records the blocked provisional candidate.

**tools/inventory_v2_fabrication.py** now indexes the composition as well as the
200-space interior. Its generated **art/blender/v2_fabrication_inventory.json**
distinguishes whole active cells, source-derived geometry and dormant registered
cells. A source reference alone is not a successful walk or a quality verdict.

| Bucket | Shell, aperture, floor and collision owners | System owners and current discovery |
|---|---|---|
| Orison | **orison_v2_blockout.json**, **orison_v2_blockout.gd**; installed exterior masonry, window joinery, door casings and roof generators. **world_connection.json** retires the stand-alone street template's duplicate Orison facade and raised entry step only in the composed root. | **orison_v2_runtime_root.gd** composes existing simulation/maintenance, schedules, persistence and service equipment. Prior masonry, stairs, boiler, alley and roof fabrication remain. Exterior composition inspected; room/detail coverage remains in the existing fabrication queue. |
| Bodega | **exterior_geometry.json**, **regions.json**, **orison_v2_exterior_cell.gd** own the current shop shell, floor, storefront, display geometry and colliders. The old **shop_bodega.gltf** is dormant. | Existing bucket registry and **orison_v2_shop_simulation.gd** own stock, staffing, hours and condition. Storefront and sales aisle inspected. Flat shelf/stock masses are intentional current simplification; delivery leaf, service circulation and physical distribution need a focused audit. |
| Vantry Arcade | **orison_v2_passage_region.gd** mounts gateway plus twelve cells: passage and eleven shops. Passage geometry is the admitted V2 derivative; eleven shop assets remain retained cell exports. Imported collision, source marker doors and hours grilles retain their owners. | **passage_finish_pass.gd**, **passage_hours_director.gd**, shared **MaintenanceShopService** and **orison_v2_passage_residency.gd**. Portal and both nave directions inspected; actual hardware purchase and reload route retained as regression coverage. Individual shop/service and closed-hours walks remain open. |
| Street | Exterior cell owns the north pavement, curb and road. Extracted **passage_gateway.gltf** owns the opposite gateway/kiosk ground and retained transit approach. **orison_v2_street_boundaries.gd** owns route limits; **service_alley.glb** owns the rear/service paving up to the existing pavement. | Existing street traffic, light budget and shop presentation; no second city simulator. The street template's duplicate facade/window/cornice boxes are removed in composition. Kiosk rails and arcade piers require the actual public approach, as used by the bar route. Drainage slopes and all transit edges need further close review. |
| Harukiya bar | **orison_v2_bar_region.gd** mounts registered **shop_bar.gltf**, whose shell, floor, ceiling, sanitary partition, stair, backbar, retained furniture and static collision are unchanged. Source marker doors are the moving owners. | Exact **CELL_SHOP_BAR** roster: 29 markers, including 18 lights and three doors; existing Harukiya hours, nine interaction sockets and two ArcadeRow receivers. Acoustic fixture mouths register to world coordinates and restore on teardown. Public entry, descent, red door, room and return walked successfully. Restroom, seat fit, apparatus reach and service continuity still require focused review. |
| Cityscape | **build_city_shells.py** derives 335 authored box solids from immutable generated city records. Editable **city_shells.blend**, exported **city_shells.glb**, and **orison_v2_city_shells.gd** own 84 building/material mesh and collision partitions. Source ground/shop interiors are omitted. | Geometry-only neighbors, backs, cornices, roofs and distant closures. No new live controls, modern services or simulation. Two north neighbors register to the current bodega/alley; southern bar/arcade geometry retains its authored frame. Oblique, street-wall, roof and overhead views inspected. Rear courtyards and more boundary sightlines remain uninspected. |

The northeast row also registers **+5.58 m** beyond the current street region,
including the construction-shed approach: projecting cornices begin at world X
**25.58 m**, the ground mass at **25.78 m**. Restoring its old X **20.20 m** ground
face blocked the admitted east route; that failed run is preserved. The corrected
**street-fixed.log.receipt.json** completed 24 waypoints with zero failures;
candidate-bound repetition remains required. The shell filter excludes street news
boxes, whose shared name prefix is not a neighboring-building identity.

The dormant old Orison interior/facade and bodega cells remain available for V1.
The street-common cell supplies only the gateway derivative; it is not wholly
mounted in V2. The bar remains outside the arcade CELLS roster and stays resident
independently of the arcade geometry lifecycle.

## Shared transition register

The Orison adapter rotates its local frame 180 degrees about Y and registers
the front threshold at world **(0,0,0)**: local origin is world Z **-11.65 m**.
Imported city geometry uses **GameBoot.b2g** and the **street_frame.json**
translation Z **-9.795 m**. The bodega uses registered instance/surface transforms
from **regions.json**. Do not substitute one frame's coordinates for another.

| Interface / both owners | Datum, opening and door | Surface, collision, services and loading boundary |
|---|---|---|
| Orison vestibule / street exterior | **F01_DOOR_06**, 1.10 m by 2.13 m, authored left hinge/outward hand. Floor datum 0; V2 wall envelope and fitted casing own the opening. Street template threshold surface is a 1.4 m by 2.5 m mounting frame, not a replacement opening. | Interior slab and exterior pavement meet at the registered threshold. One physical V2 leaf. Duplicate exterior facade, synthetic windows and raised step removed. Arcade prefetch starts at the vestibule; bar/city geometry stays resident. No new service crossing is invented. |
| Orison service hall / service alley | **F01_REAR_SERVICE_DOOR**, 0.91 m by 2.13 m, left hinge/outward hand, local center **(8.9,9.25)**. Existing hall and alley share datum 0. | DomesticDoors owns the moving leaf; accepted Blender alley owns exterior walls/paving/collision. The west neighbor's nearest face is world X **-18.40 m**, beyond the alley wall/pier at **-18.32 m**. Door/alley regression suite must still pass with neighbors installed. |
| Bodega / pavement | Threshold frame 1.2 m by 2.5 m; instance center world X **18.655 m**. Current shop floor and threshold stay in the exterior resolver's frame. Physical storefront leaf parameters remain in **exterior_geometry.json**. | Exterior cell owns both shop and north pavement, including existing colliders/counter. Source east neighbor shifts **+1.255 m** to the registered bodega. Delivery aperture and swept volume are not yet accepted. |
| Arcade gateway / passage and eleven shops | Source marker openings, door dimensions, lintels and grilles remain authoritative in **building_layout.json** and cell exports. One imported frame; nave datum 0. | Imported cells own floor/collision; passage actors own doors and hours grilles. Shared hardware counter retains actual stock/inventory. Residency unload/reload occurs at the Orison core/vestibule, retaining physical actors. Separate shop-by-shop and closed-grille route work remains. |
| Street / bar lobby / bar basement | Source shaft X **4.30..5.90 m**, 1.60 m clear, street lobby top **0.02 m**. Fifteen **0.175 m** risers with **0.27 m** treads reach the **-2.80 m** room through the bottom landing. Street leaf 0.90 m; red leaf 0.90 m at source hinge **(4.15,-33.95,-2.8)**, outward hand. | Original imported slab, 0.30 m wall/threshold strip and collision remain. Use the west lane past the umbrella stand, then continue beyond the lobby crate before the descent stance. Red-door notch admits the capsule without crossing the 0.18 m lounge lip. No interstage teleport. Bar actor acoustic mouths register with the same city transform. |
| City neighbors / service alley and bodega | West north neighbor shift **-3.20 m** derives from the accepted alley boundary plus 0.08 m separation; east shift derives from bodega registration. Northeast row shift **+5.58 m** clears the admitted construction route. Southern buildings retain source coordinates. | City shells own their solid backs/roofs/collision, with no copied street floor or shop interiors. Eight-millimetre arrises are visual detail; microscopic corner triangles are excluded from structural ray sampling. Roof/wet/utility penetrations beyond the accepted sources remain a review task. |

## Shared infrastructure register

Existence of a riser, fixture or authored control does not prove a supported,
continuous physical network. Preserve the existing simulations while completing
the visual source/distribution/endpoint trace. Cross-location extensions need
their own source-grounded geometry and route checks.

| System | Existing source → distribution → endpoints | Physical work still to inspect/finish |
|---|---|---|
| Heating and return | Boiler/BoilerTend → fitted header/equalizer and **HEAT_STACK** → **heating.json**, HeatBalance and installed one-pipe radiators. | Preserve accepted boiler piping. Trace vertical and branch support, sleeves, expansion/joints and access at every floor; bar/bodega/arcade heat must follow an authored source rather than a fictitious new live loop. |
| Water | Roof tank/ballcock and existing water/hot-water owners → **WEST_WET_STACK**, domestic fittings/completion data → apartment, laundry and sanitary fixture controls. | Inspect supply/return branch joins, valve clearance and floor penetrations; inspect original bar WC sink physically and functionally. No speculative municipal tie-in. |
| Drainage | Existing wet-stack reservation and fixture traps → shaft and basement routes. | Full drain/vent continuity, fall, cleanouts, sleeves and street outlet geometry are not verified by this batch. |
| Ventilation/exhaust/flue | Four completion-interior ventilation stacks/register rosters → **orison_v2_ventilation.gd** ducts and roof fans; separate boiler breeching → **B1_BOILER_FLUE** and chimney. | Fan/duct supports, register branch junctions, penetrations and access remain a focused queue. Bar sanitary/exhaust and shop distribution require source tracing. |
| Power/conduit | Existing basement electrical/service equipment and **ELECTRICAL_SERVICE_RISER** → existing fixture/switch and lamp owners. | Trace conduit supports, drops and termination boxes across shops/bar; mounted lighting and hours behavior alone do not establish electrical fabrication completion. |
| Lift equipment | Existing passenger/service shafts, landings, OrisonElevator, Blender roof drive and suspension. | Retain accepted mechanisms; inspect bearings, support/guard clearances, roof closures and landings. No new control authority. |
| Communications/deliveries | Existing switchboard, telephone network, **TELEPHONE_MESSAGE_RISER**, AcousticGraphData and service-set owners; accepted service alley, coal route and passage handcarts. | Verify penetrations, mounts, cable runs and physical delivery endpoints; bodega delivery route and bar service/storage access remain unimplemented/uninspected connections. |

## Inspection, measurements and next queues

Before: **tmp/city-architecture/before/city**. After:
**tmp/city-architecture/after/city-final**. Thirteen production camera views
include player-height frontage, shop, arcade, bar approach, alley and street
walls, plus roof and overhead discovery. The paired **census.json** files record
visible mesh bounds, ownership paths, transforms, residency and render counters.
The scratch **game/tmp/CityAudit.tscn** creates no extra lighting and uses the
real player as residency/light observer. It is capture machinery, not traversal.

Direct inspection confirmed the duplicate Orison facade, absent bar and absent
neighbor masses before; their composed after views were inspected. The bodega
shows flat-color stock/shelves, the roof stance is partly occluded by equipment,
and the bar's first approach camera lies near kiosk rails. These limitations
are retained in discovery, not counted as clear installation acceptance.
Successful bar route frames are in **tmp/city-architecture/bar-route-5**.

Geometry-node discovery changed **11,007 → 11,401**. Startup samples were
**19.04 → 19.97 s**. Representative all-pass draw counters: front
**37,848 → 38,719**, bar approach **5,426 → 7,908**, alley
**17,841 → 18,570**, overhead **26,180 → 30,979**. Process samples vary strongly
with view and residency: front **139 → 127 ms**, bar **101 → 149 ms**, alley
**178 → 177 ms**, overhead **311 → 342 ms**. These single-frame, multipass
observations are not stable FPS measurements or a performance acceptance claim.
The additional city asset is approximately **1.72 MB**, partitioned for culling.

| Bucket | Verified/visible current result | Small next queue | Phase states |
|---|---|---|---|
| Orison | Duplicate facade removed; installed masonry retained. | Basement/roof/landing and targeted room interfaces; existing service joins. | Raw architecture open; infrastructure open; mapping partly prepared; final polish open. |
| Bodega | Registered shell, existing counter/state retained; rendered aisle. | Delivery leaf and approach; threshold/glazing/support detail; service distribution. | All four phase states open; planar/stock simplifications recorded. |
| Arcade | Thirteen composed cells and retained eleven-shop roster. | Every shop threshold/service route; closed-hours circulation; roof/support/wet joins. | Raw architecture/infrastructure open; existing imported mapping retained; final polish open. |
| Street | One Orison facade owner; continuous tested public route to bar. | Drainage and paving contacts; crossing/transit edges; remaining route limits. | Raw architecture/infrastructure open; mapping partly prepared; final polish open. |
| Bar | Retained cell playable; real 38-waypoint round trip and red-door input. | WC route/control, other moving poses, seats/apparatus, service/storage and utilities. | Public connection implemented; raw architecture/infrastructure still open; imported mapping retained; final polish open. |
| Cityscape | Missing source masses restored with physical backing. | Courtyards/backs; boundary sightlines; neighbor supports/penetrations. | Structural composition advanced; infrastructure open; metre UVs prepared; final polish open. |

## Gates, failures and preservation

Initial focused **bar-route-5.log.receipt.json** completed with **38 waypoints / 0 failures**.
The provisional **city-composition-3.log.receipt.json** completed with **1,295 checks /
468 structural contacts / 0 failures** on the original 87-partition export, two world
constructions, all three original hours states, active UVs/normals/tangents and acoustic
restoration. The 84-partition correction must pass its own final candidate checks.
Earlier runs that stopped on an approach pier, umbrella stand, a crate/tread stance,
or microscopic bevel probes are not acceptance evidence. One earlier import
argument error ran the wrong scene and reached its ceiling; it is not an import
receipt. Subsequent double imports completed successfully.

The first sandboxed passage run could not write Godot's user log, then crashed
before route proof. Its escalated retry completed successfully; this is evidence
for an execution-environment failure, not a diagnosed engine/game defect. The
crash screenshot alone cannot establish a code cause. Keep both receipts.

Spatial manifest changes append only 21 individually reviewed new references;
existing classifications and audit logic remain. Reader audit reports **NEW: 0**.
The complete board/candidate comparison and bound regression suites are required
before push. Completeness counts remain **[7,8,127,42,151,153]**, with no promotions.

The sixteen non-selector protected paths and selector/V1 rollback remain unchanged.
The gentler waking flashlight, boiler swing/pipework, service alley, resident/shop
state and accepted Dream/hero/organelles/critter boundaries are preserved. The
owner's later removal of five untracked capture images supersedes the old prompt;
their absence and committed **art/renders/insitu/shots.md** bytes are preserved.

Changes outside the geometry boundary: source inventory, two focused test scenes,
reviewed spatial references and this INERT register, all necessary to describe and
check composition. No owner decision is currently needed. Continue the open queues;
do not declare the architecture/infrastructure phase finished from this batch.
