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
| Bodega | **exterior_geometry.json**, **regions.json**, **orison_v2_exterior_cell.gd** own the current shop shell, storefront, display geometry and moving leaves. **build_bodega_receiving.py**, **bodega_receiving.blend/glb** and **orison_v2_bodega_receiving.gd** own the fitted fixed receiving floor/walls/ceiling/bench and collision. The old **shop_bodega.gltf** is dormant. | Existing bucket registry and **orison_v2_shop_simulation.gd** own stock, staffing, hours and condition. Storefront and sales aisle inspected. Flat shelf/stock masses are intentional current simplification. The fitted Blender receiving room and one semantic delivery leaf now pass a 30-waypoint sales-aisle round trip; storefront detail and physical utility distribution remain open. |
| Vantry Arcade | **orison_v2_passage_region.gd** mounts gateway plus twelve cells: passage and eleven shops. Passage geometry is the admitted V2 derivative; eleven shop assets remain retained cell exports. Imported collision, source marker doors and hours grilles retain their owners. | **passage_finish_pass.gd**, **passage_hours_director.gd**, shared **MaintenanceShopService** and **orison_v2_passage_residency.gd**. Portal and both nave directions inspected; actual hardware purchase and reload route retained as regression coverage. Individual shop/service and closed-hours walks remain open. |
| Street | Exterior cell owns the north pavement, curb and road. Extracted **passage_gateway.gltf** owns the opposite gateway/kiosk ground and retained transit approach. **orison_v2_street_boundaries.gd** owns route limits; **service_alley.glb** owns the rear/service paving up to the existing pavement. | Existing street traffic, light budget and shop presentation; no second city simulator. The street template's duplicate facade/window/cornice boxes are removed in composition. Kiosk rails and arcade piers require the actual public approach, as used by the bar route. Drainage slopes and all transit edges need further close review. |
| Harukiya bar | **orison_v2_bar_region.gd** mounts registered **shop_bar.gltf**, whose shell, floor, ceiling, sanitary partition, stair, backbar, retained furniture and static collision are unchanged. Source marker doors are the moving owners. | Exact **CELL_SHOP_BAR** roster: 29 markers, including 18 lights and three doors; existing Harukiya hours, nine interaction sockets and two ArcadeRow receivers. Acoustic fixture mouths register to world coordinates and restore on teardown. Public entry and restroom/sink return walked successfully. Seat fit, other apparatus reach and service continuity still require focused review. |
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
| Bodega / pavement | Threshold frame 1.2 m by 2.5 m; instance center world X **18.655 m**. Current shop floor and threshold stay in the exterior resolver's frame. Physical storefront leaf parameters remain in **exterior_geometry.json**. | Exterior cell owns both shop and north pavement, including existing colliders/counter. Source east neighbor shifts **+1.255 m** to the registered bodega. The original public leaf and datum remain unchanged; the internal receiving connection has its own owner below. |
| Bodega sales aisle / receiving room | Corrected rear-facing semantic frame local **(0.65,0,-10.56)**; original clear opening **1.05 m** by **2.25 m**, 0.16 m wall. One **0.95 m** by **2.10 m** east-hinged service leaf swings into the room through existing DoorProp input. Both floor datums zero. | Existing ExteriorCell owns the opening/leaf and shared shop/counter state; the fitted Blender room owns the contiguous 2.00 m extension, foundation, walls, ceiling and bench/collision. Jambs stay outside the opening. Existing delivery practical relocates onto a physical support with unchanged energy/range. Semantic placements walk through the existing sales aisle, close/reopen inside and return: 30 waypoints, zero failures. Room stays resident with bodega; no external rear approach is invented. |
| Arcade gateway / passage and eleven shops | Source marker openings, door dimensions, lintels and grilles remain authoritative in **building_layout.json** and cell exports. One imported frame; nave datum 0. | Imported cells own floor/collision; passage actors own doors and hours grilles. Shared hardware counter retains actual stock/inventory. Residency unload/reload occurs at the Orison core/vestibule, retaining physical actors. Separate shop-by-shop and closed-grille route work remains. |
| Street / bar lobby / bar basement | Source shaft X **4.30..5.90 m**, 1.60 m clear, street lobby top **0.02 m**. Fifteen **0.175 m** risers with **0.27 m** treads reach the **-2.80 m** room through the bottom landing. Street leaf 0.90 m; red leaf 0.90 m at source hinge **(4.15,-33.95,-2.8)**, outward hand. | Original imported slab, 0.30 m wall/threshold strip and collision remain. Use the west lane past the umbrella stand, then continue beyond the lobby crate before the descent stance. Red-door notch admits the capsule without crossing the 0.18 m lounge lip. No interstage teleport. Bar actor acoustic mouths register with the same city transform. |
| Bar aisle / customer WC | Original opening **0.70 m** by **2.05 m**, 0.15 m partition, hinge source **(-10.85,-36.17,-2.8)**, retained door width **0.70 m**, height **2.00 m** and hand. Floor datum **-2.80 m** on both sides. | A bar-scoped DoorProp subclass uses a **145-degree** open pose to clear the **0.66 m** capsule at the jamb; closed pose remains zero. The existing TapProp cycle receives primary-area input through a bar-scoped adapter. Imported walls/slab stay unchanged. A 54-waypoint real input round trip passes, with hot/mixed/off states and door closure; final candidate binding is recorded in **tmp/bar-access/verified/verification.json**. |
| City neighbors / service alley and bodega | West north neighbor shift **-3.20 m** derives from the accepted alley boundary plus 0.08 m separation; east shift derives from bodega registration. Northeast row shift **+5.58 m** clears the admitted construction route. Southern buildings retain source coordinates. | City shells own their solid backs/roofs/collision, with no copied street floor or shop interiors. Eight-millimetre arrises are visual detail; microscopic corner triangles are excluded from structural ray sampling. Roof/wet/utility penetrations beyond the accepted sources remain a review task. |

## Shared infrastructure register

Owner decision, October 1: **independent building services** govern the bar,
bodega and arcade buildings. Each building's incoming supplies and local plant
remain separate from Orison. This settles service ownership; the physical
routes, fittings and access still require source-authored construction and
verification. Existing controls/simulations stay their state authorities.

Existence of a riser, fixture or authored control does not prove a supported,
continuous physical network. Preserve the existing simulations while completing
the visual source/distribution/endpoint trace. Cross-location extensions need
their own source-grounded geometry and route checks.

| System | Existing source → distribution → endpoints | Physical work still to inspect/finish |
|---|---|---|
| Heating and return | Boiler/BoilerTend → fitted header/equalizer and **HEAT_STACK** → **heating.json**, HeatBalance and installed one-pipe radiators. October 2: three bounded inlet crossings receive steel sleeves and five bolted plates; the internal equalizer tee is opened while retaining the installed outer pipework. All eighteen original floor feeds contact their actual slabs; six floating wall ties are fitted with fixed slotted plates. | **art/blender/boiler_inlet.md** records the source-entry construction, geometry invariance and scoped checks. Endpoint fit remains in **art/blender/radiator_wall_ties.md**. Physical risers and pitched routes to the eighteen actual feeds, supports, expansion/joints and access remain open; the first-floor west feed needs a supported under-floor route beyond the excavated basement. Bar/bodega/arcade heat must follow their independent building sources rather than a fictitious shared live loop. |
| Water | Roof tank/ballcock and existing water/hot-water owners → **WEST_WET_STACK**, domestic fittings/completion data → apartment, laundry and sanitary fixture controls. | Inspect supply/return branch joins, valve clearance and floor penetrations; bar WC sink input and reach now pass; physical supply/drain joins still need tracing. No speculative municipal tie-in. |
| Drainage | Existing wet-stack reservation and fixture traps → shaft and basement routes. | Full drain/vent continuity, fall, cleanouts, sleeves and street outlet geometry are not verified by this batch. |
| Ventilation/exhaust/flue | Four completion-interior ventilation stacks/register rosters → hollow Blender sheets/seams, fitted wall/chase/outer-leaf linings and four roof curbs; exposed-branch trapezes seat on existing ducts/ceilings. Separate boiler breeching → **B1_BOILER_FLUE** and chimney. | **art/blender/ventilation_throats.md** scopes the 23 imported airway ports and terminal fan apertures. **art/blender/ventilation_slab_ports.md** records 27 slab ports and 15 sleeves. **art/blender/ventilation_fabric_ports.md** adds 67 room-wall, 15 chase and 26 outer-leaf opening volumes, four steel lining draws and full-bore/fixture checks. Support/access review and independent bar/shop exhaust construction remain open. |
| Power/conduit | Existing basement electrical/service equipment and **ELECTRICAL_SERVICE_RISER** → existing fixture/switch and lamp owners. The independent bodega property-side intake and supported lighting branch serve its three existing shop fittings and receiving practical. | **art/blender/bodega_power.md** records the wall sleeves, support/connector checks and scoped candidate binding. The external concealed service continuation, other apparatus feeds and bar/arcade routes remain open; mounted lighting and hours behavior alone do not establish electrical fabrication completion. |
| Lift equipment | Existing passenger/service shafts, landings, OrisonElevator, Blender roof drive and suspension. | Retain accepted mechanisms; inspect bearings, support/guard clearances, roof closures and landings. No new control authority. |
| Communications/deliveries | Existing switchboard, telephone network, **TELEPHONE_MESSAGE_RISER**, AcousticGraphData and service-set owners; accepted service alley, coal route and passage handcarts. | Verify penetrations, mounts, cable runs and physical delivery endpoints; bodega receiving access now passes through the storefront/sales aisle; external delivery and bar service/storage connections remain unauthored or uninspected. |

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
| Bodega | Registered shell and counter/state retained; fitted receiving room and 30-waypoint delivery return with one working leaf. | Storefront threshold/glazing/support detail; physical service distribution. | Raw architecture/infrastructure open; receiving metre UVs prepared; final polish open; stock simplifications recorded. |
| Arcade | Thirteen composed cells; all eleven shop thresholds, inside locks and ten night barriers walked in two normal-input routes. | Full sales-floor/apparatus reach; roof/support/wet/electrical joins. View-only rear rooms and shallow service panels remain intentional source boundaries. | Raw architecture/infrastructure open; existing imported mapping retained; final polish open. |
| Street | One Orison facade owner; continuous tested public route to bar. | Drainage and paving contacts; crossing/transit edges; remaining route limits. | Raw architecture/infrastructure open; mapping partly prepared; final polish open. |
| Bar | Retained cell playable; public route and 54-waypoint WC/sink return; pool inspection volume fitted to the actual source table. | Other moving poses, seats/apparatus, service/storage and utilities. | Public and sanitary connections implemented; raw architecture/infrastructure still open; imported mapping retained; final polish open. |
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

## Bodega receiving follow-up

**art/blender/bodega_receiving.md** records the missing-support before walk,
source dimensions, inferred 2.00 m extension, ordinary-input 30-waypoint route,
six structural contacts, six mapped partitions and directly inspected production
views. Public-view samples and their limits are retained there. The full clean
baseline is **tmp/bar-access/3bdd7e5-clean-board.json**. Final bound checks are
recorded in **tmp/bodega-receiving/verified/verification.json** for the verified,
pushed **7c2e35825df0b3827134739ac3c1c97448f4e3ec** implementation.
This batch appends only two individually reviewed spatial records, preserving
the previous 6,313 records; it does not promote the completeness ledger.

## Resident-key steering

The owner's later request adds resident originals and resident-authorized copies,
manual hinged-leaf lock control and a fresh V2 News Cigars unlock. The fitted key,
retained Keys Cut counter, ownership/save rules and scoped tests are described in
**art/blender/resident_keys.md**. Existing shop grilles/hours remain authoritative.
The key follow-up changes none of the six raw-architecture/infrastructure phase
states above. Continue the arcade threshold and service/interface queues after
the clean key-candidate verification; no ledger promotion follows from this work.
The verified/pushed key candidate is **693000cb7f83ecf9c7efea94e84fe85c726f4168**;
**tmp/resident-keys/verified/verification.json** records zero regressions, NEW **0**,
unchanged protected paths and eleven successful bound suites. Resident originals,
permission, copying, physical locks and reconstruction are scoped by the test's
schema-2 contract; the six architecture/infrastructure queues remain open.

## Arcade threshold follow-up

**art/blender/arcade_thresholds.md** records every shop connection, source parked
leaf poses, the diner customer aisle, normal key/door input, night barriers and
continuous retirement. Verified/pushed **4cbed737bc2b66ebfa6b518eeb2a1894d7b4bf7b**
reports **68 / 76 waypoints**, zero failures, physical grille/leaf-sweep separation
at all sampled poses and the existing **42-waypoint** purchase/residency route.
Geometry and simulations are retained. Borrowed-light rear rooms,
painted service panels and the funeral rail are authored view-only boundaries.
Final verification belongs to **tmp/arcade-thresholds/verified/verification.json**;
the source test/capture batch does not close the arcade infrastructure queue.

## Boiler inlet follow-up

Published **e93b9c25dc4e439a75222c0e89efe326b07f0848** fits the retained steam
feed's three structural crossings and opens its hidden equalizer junction.
**art/blender/boiler_inlet.md** records native geometry invariance, actual
plate/bolt seats, 324 airway samples and the construction scope. The complete
**47**-gate comparison and eleven binding windowed scene suites pass with zero
regressions, NEW **0**, unchanged protected paths and no ledger promotions.
Final verification is **tmp/boiler-inlet/verified/verification.json**; the
clean complete comparison board is **tmp/boiler-inlet/e93b9c2-clean-board.json**.
The six location phases and source-to-radiator distribution remain open.

## Landing underside prerequisite

Heating-support inspection exposed missing rendered landing undersides despite
retained slab collision. **art/blender/landing_soffits.md** records the source
repair: **64** additional ceiling partitions across **65** platforms, with actual
lower-ceiling ownership subtracted. Focused inspection passes **1,557** checks at
**585** surface/collision stations without duplicates. Normal-input routes and
the complete clean candidate comparison remain required before publication.
The added surfaces prepare physical support seating; they do not close any of
the six location phases or accept the proposed heating distribution.

Published **fc3b90db92364bb61a2a6a22fded6edffd94f941** completes the landing
prerequisite with nine binding scene suites and the full **47**-gate comparison:
zero regressions, NEW **0**, unchanged protected paths and requirement statuses.
**tmp/landing-soffits/verified/verification.json** and the genuine
**tmp/landing-soffits/fc3b90d-clean-board.json** retain the final observations.
One routing trial cleared retained millwork and had **466** proposed nine-point
underside seats with **49** unresolved stations. Subsequent pipe-to-pipe checks
rejected that trial's height packing and exposed a self-crossing north-wing
detour. Heating routes, structural sleeves, chase access, supports and the
ground-floor channel remain construction planning, not phase acceptance.

## Room-floor underside prerequisite

The same source inspection found exposed room-floor slabs without rendered
undersides. **art/blender/room_slab_soffits.md** records **54** additional mapped
partitions, with source apertures and all earlier ceiling/platform owners
subtracted. The focused inspection passes **2,881** checks over **585** landing
and **468** room-slab stations. Three retained roof-wall foreground contacts are
reported separately from the named slab-body query. No physics body changes.
The north-wing and ground-west perimeter frames were directly inspected; finish
response remains open. The full clean candidate comparison and normal routes
remain required before publication. This prerequisite accepts no heating route
or support station and closes none of the six location phases.

Published **cd5498b6f193d1bb6c9b2eea0bafa796e890812d** completes this room-slab
prerequisite with the full **47**-gate comparison and nine binding windowed scene
suites: zero regressions, NEW **0**, protected paths and requirement statuses
retained. All six final frames were directly inspected. The final comparison and
complete clean board are **tmp/room-slab-soffits/verified/verification.json** and
**tmp/room-slab-soffits/cd5498b-clean-board.json**. Continue the open physical
service routes, fitted ports, supports, chase access and mapping queues.

## Heating distribution construction

**art/blender/heating_distribution.md** indexes the provisional source and
editable one-pipe installation. Original masonry volumes exposed two buried
light-slot routes and an oblique service-wall route; the construction draft now
clears those leaves rather than cutting long slots through them. Native-only
lumen inspection and proposed support seats are scoped planning observations.
Sleeves, common plates, native hangers, guides, access covers, ground protection,
receiver union, ordinary routes and final verification remain open. No location,
utility or completeness requirement is promoted by this construction draft.

Owner review on October 2 asked whether the external shell was ready for cuts.
The draft heating apertures were removed from runtime, the published masonry
restored, and eight uncommitted fabrication/source/tool files preserved under
**tmp/heat-distribution/parked-work**. The current priority is wall-base,
foundation, setback and roof-rim readiness. **tmp/shell-readiness** retains actual
exported geometry, support discovery and direct frames. A missing sampled
contact is a construction finding requiring inspection, not a structural load
calculation or permission to close an authored light slot or circulation route.

The first correction is the source-bound roof rim in
**art/blender/roof_edge_support.md**: 28 native pieces, 240 triangles, 466 focused
checks, twelve physical edge contacts and twelve retained parapet bearings.
All twelve earlier recessed edge rays are reproduced with the new course
excluded. Three exported views were directly inspected. Normal routes and the
clean committed comparison remain required. Foundations and setback continuity
are still under review; no whole-shell or heating readiness is declared.

The rim candidate **3a3ca03effc97fb8e502aa0600a671e3c8a35cf2** passes ten binding
windowed scene suites, including the 51-waypoint roof and 79-waypoint vertical
circuits, but its complete comparison is blocked by three new incidental test
references. They are individually registered with the next roof batch. Preserve
**tmp/shell-readiness/verified/verification.json** as the failed comparison.

The actual overhead view also showed two open bulkheads despite retained
interior ceilings. **art/blender/roof_bulkhead_caps.md** records source-derived
200 mm closures on their full wall footprints: seven pieces, 78 triangles,
210 focused checks, eighteen matching upper contacts, twenty-four wall bearings
and retained interior ceiling owners. All five exported views were inspected.
The combined candidate must pass normal routes and the full original clean
**cd5498b** comparison before push. Foundation/setback ownership and exposed
ceiling tops remain inspection work; heating apertures remain parked.

Published **de69156b33bac0f6bfc3149837354242b346d2d2** completes both scoped
roof corrections with eleven binding windowed suites and the full 47-gate
comparison against **cd5498b**: zero regressions, NEW zero, protected 17/17,
V2 default/V1 rollback retained, and no completeness promotions. All eight final
cap/rim frames were directly inspected beneath **game/tmp/roof-closures/verified**.
**tmp/roof-closures/verified/verification.json** retains the comparison; its
genuine clean complete candidate board is **tmp/roof-closures/de69156-clean-board.json**.
Normal roof and vertical circuits pass 51 and 79 waypoints; resident keys pass
their schema-2 two-world route, 84 waypoints and 55 checks, with clean teardown.
Foundations, setbacks, source-only slab contacts and independent city service
routes remain open. The parked heating draft receives no readiness acceptance.

## Foundation contact prerequisite

**art/blender/orison_foundations.md** records nineteen source-derived stem
rectangles and fifty-one footing rectangles, outside retained basement room,
wall and riser projections. The complete union is closed; seventy-four bounded
mapped pieces use matching native triangle collision. No service cut is added.
The focused production inspection passes **1,119** checks: **61** closed ground
stations, **183** matching contacts and reproduced earlier gaps, **96** basement
masonry footing contacts and zero surface intrusion into ten occupied masks.
All four diagnostic frames were directly inspected. Fifty-one other deficient
ground stations, higher-storey bearing findings and upper setback closures remain
open. Modeled contact does not determine soil, reinforcement or load capacity.

The next clean candidate comparison uses the genuine complete **de69156** board,
with normal basement, boiler, alley, roof, vertical and key-reconstruction routes.
Foundation native construction and **game/tests/fixtures/orison_foundation_stations.json**
retain the original discovery's source identity. Only two new spatial references
are individually appended. Reader NEW remains zero. Raw architecture and all
seven location/utility phases remain open; heating apertures stay parked.

Published **202e55d18a402305675307b11c9b19184dca049b** passes the complete
47-gate comparison against **de69156** and twelve bound windowed suites:
zero regressions, NEW zero, protected 17/17 and no requirement promotions.
Normal basement, roof and vertical routes pass 88, 51 and 79 waypoints; keys
retain their schema-2 two-world contract with 84 waypoints and 55 checks.
All four final foundation frames were directly inspected. Comparison and clean
board are **tmp/foundations/verified/verification.json** and
**tmp/foundations/202e55d-clean-board.json**. Continue uncovered ceiling upper
closures, slab-edge seats and transfer continuity before heating cuts.

## Uncovered ceiling top prerequisite

**art/blender/ceiling_top_closures.md** records source-bound upper closures on
twenty-three retained ceiling owners. Fifty-one mapped native pieces add only
uncovered tops and genuine outer edges; upper walking floors, landings, source
ports, original undersides and the native service-alley pavement remain with
their earlier owners. The first isolated trial rejects alley overlap and a
degenerate edge. The repaired trial and production inspection preserve both
failures for review and use no tolerance or audit exception.

The production inspection passes **459** physical upper contacts, reproduced
earlier gaps and retained undersides, with zero foreground conflicts and zero
overlapping volumes across **14,484** comparisons with retained floor and landing
shapes. All five production frames were directly inspected. The complete clean
candidate comparison must use **202e55d**, with normal basement, vertical,
roof, alley, door/key reconstruction and retained fabric routes. Slab-edge
seats, transfers and wider shell continuity remain open; no heating port or
completeness requirement is promoted.

Published **244853be4af90ca95445eacf232859e918af7e08** passes all thirteen bound
windowed suites and the complete 47-gate comparison against clean **202e55d**:
zero regressions, NEW zero, protected 17/17, V2 default/V1 rollback retained and
no requirement promotions. All five final bound closure frames were directly
inspected. Normal basement, roof and vertical circuits retain 88, 51 and 79
waypoints; keys retain their schema-2 two-world contract, 84 waypoints and 55
checks. Comparison and clean board are
**tmp/ceiling-closures/verified/verification.json** and
**tmp/ceiling-closures/244853b-clean-board.json**. Continue actual current wall-base
and transfer discovery before making further shell cuts. Source aperture
classification is distinct from actual support contact; retained vent bores
must remain open. Heating apertures remain parked.

## Shifted ground core support prerequisite

**art/blender/ground_core_transfer.md** records a fitted 350 mm wide I transfer
frame, short watch-wall seat, two offset H columns and supplemental footing
pads beneath the retained basement landing. The native steel assembly is
connected; three mapped partitions have 1,884 triangles, actual chamfers and
matching triangle collision. No wall, laundry pocket or service port is cut.
The southern column preserves the west passage. Existing foundations and
editable masonry are subtracted from the new pads and edge band.

The final focused inspection passes 116 checks at
**tmp/shell-readiness/ground-transfer-production-inspection3.log.receipt.json**:
twelve matching seats and reproduced prior gaps, eight base and eight pad
contacts, eight exposed native/live anchor tops and zero positive overlap with
retained collision. All six construction views were directly inspected. Earlier
overlong-beam, buried-anchor and short-ray failures remain recorded. The
diagnosed short-ray parallel threshold is repaired with a longer segment and
the same first-hit owner and 30 micron contact requirement.

The final installed route passes 27 normal-input waypoints in
**tmp/shell-readiness/ground-transfer-production-route2.log.receipt.json**:
both west passage directions, actual input opening the retained laundry leaf,
entry/exit and return. All three route frames were inspected. The complete clean
candidate comparison must use **244853b**, the broader normal routes and the
retained native fabrics. Reader NEW and unclassified spatial references are zero;
only four individually reviewed references are appended. The separate actual
post-closure/source-masonry survey leaves 92 unresolved stations as a work list.
This frame targets four local stations; higher-storey transfers, front threshold
backing, weather closures and infrastructure remain open. No load capacity or
completeness requirement is promoted, and heating apertures remain parked.
