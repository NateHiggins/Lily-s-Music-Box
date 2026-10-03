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
| Street | Fitted **front_pavement.blend/glb** owns the north public slab and matching collision in the Orison front-door frame; exterior cell retains curb, road and registered bodega floor. Extracted **passage_gateway.gltf** owns the opposite gateway/kiosk ground and retained transit approach. **orison_v2_street_boundaries.gd** owns route limits and shed floor; **service_alley.glb** owns rear/service paving. | Existing street traffic, light budget and shop presentation retain their owners. The original rectangular public slab is removed only from V2 composition; fitted paving excludes current rooms, masonry, bodega, shed and curb volumes. Kiosk rails and arcade piers require the actual public approach. Broader subgrade, drainage slopes, paving joints and transit edges remain open. |
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
| Bodega / pavement | Threshold frame 1.2 m by 2.5 m; instance center world X **18.655 m**. Current shop floor and threshold stay in the exterior resolver's frame. Physical storefront leaf parameters remain in **exterior_geometry.json**. | Exterior cell owns the shop floor/collider/counter; fitted front paving owns only the public slab outside retained shop volumes. Source east neighbor shifts **+1.255 m** to the registered bodega. The original public leaf and zero datum remain unchanged; the internal receiving connection has its own owner below. Broader below-floor support and drainage remain open. |
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

Published **366653ce52e6bf6eb8ee97a52faeb8fd1566c91f** passes all fifteen bound
windowed suites and the complete 47-gate comparison against clean **244853b**:
zero regressions, NEW zero, protected 17/17, V2 default/V1 rollback and no
requirement promotions. All nine final frame/route views were directly
inspected. Normal basement, roof and vertical circuits retain 88, 51 and 79
waypoints; keys retain their schema-2 two-world contract, 84 waypoints and 55
checks. Comparison and genuine clean complete board are
**tmp/ground-core-transfer/verified/verification.json** and
**tmp/ground-core-transfer/366653c-clean-board.json**. Continue current contact
discovery before adding upper transfers: longer native rays must distinguish
small-triangle probe misses from actual missing construction. Heating cuts
remain parked while shell and support continuity are open.

## First-upper A rear-wing support prerequisite

The fresh longer-ray survey and separate editable-source reconciliation at
**tmp/shell-readiness/post-frame-contact1.log.receipt.json** and
**post-frame-source-continuity.json** account for 943 of 1,030 stations, leaving
87 upper-storey stations. The front threshold contacts the existing foundation;
no additional backing is required there. These counts describe a work list,
without load-path, capacity or shell-readiness acceptance.

**art/blender/rear_wing_a_support.md** records seven source-derived I beams,
nine fitted H posts, independent external pedestals/pads and retained storage
roof/wall seats beneath twenty first-upper A rear-wing stations. The bath seat
preserves the wet stack and common-room corner. Complete connected native steel
is beveled before surface clipping into 18 bounded partitions, with 8,414 mapped
triangles, original outward winding and matching collision. Retained source
masonry, floors, services, controls and lighting remain authoritative.

The installed inspection passes 506 checks at
**tmp/shell-readiness/rear-wing-a-production-inspection3.log.receipt.json**:
60 contacts and reproduced original gaps, 36 bases, 20 pad contacts, eight
retained basement-wall seats, 36 exposed native/live anchors and zero positive
retained-body overlaps. All six installed views were directly inspected.
Earlier collision, tangent/export and visually reversed open-section trials
remain rejected. Final imported UV-derivative and unit-basis checks pass with
their original tolerances.

The installed normal-input apartment circuit passes 45 waypoints at
**tmp/shell-readiness/rear-wing-a-production-apartment-route1.log.receipt.json**;
all fourteen route frames were inspected. The earlier basement trial passes 88
but precedes the final winding-preserving export. The complete clean candidate
comparison must repeat that route and use **366653c**, including the retained
broader routes and fabric checks. The 47-gate precommit comparison has zero
regressions, reader NEW zero and no changed requirements. The six fixed main
viewport observations add two to eight visible draws; these are diagnostics,
without timing or whole-world performance acceptance.
One individually reviewed collision naming reference is appended; audit
logic and existing manifest classifications remain unchanged. A fresh actual
survey is required before counting these twenty targets as resolved in the wider
work list. The other rear wing, upper-storey transfers, weather closures and
shared utility construction remain open. Heating apertures remain parked.

Published **0454d43fa75dac182d58d3a9409d1cf1a50dd8b5** passes all seventeen bound
windowed suites and the complete 47-gate comparison against clean **366653c**:
zero regressions, reader NEW zero, protected 17/17, V2 default/V1 rollback and
no requirement promotions. The bound frame repeats 506 checks and its apartment
route repeats 45 waypoints; all twenty final captures were reviewed. The final
export repeats the 88-waypoint basement circuit, with all thirteen frames
reviewed, plus 51 roof and 79 vertical waypoints. Keys retain their schema-2
two-world contract, 84 waypoints and 55 checks with clean teardown. Comparison
and genuine clean complete board are
**tmp/rear-wing-a-support/verified/verification.json** and
**tmp/rear-wing-a-support/0454d43-clean-board.json**. Continue fresh actual contact
discovery before counting the twenty target stations in the wider work list or
fabricating the next wing. Heating cuts remain parked.

The fresh **tmp/shell-readiness/post-rear-wing-a-contact1.log.receipt.json**
and separate **post-rear-wing-a-source-continuity.json** account for 963 of
1,030 stations, leaving 67: **F02** 36, **F03** eleven, **F04** eight and **F05**
twelve. The installed frame now supplies actual contact at all twenty original
A targets. All three discovery views were reviewed. The front threshold retains
its existing foundation. Continue the other rear wing and upper transfers;
these measured counts do not establish shell readiness or weather closure.

## First-upper C rear-wing support prerequisite

**art/blender/rear_wing_c_support.md** records seven source-derived I beams,
sixteen H posts, nine retained basement roof seats and seven independent external
pedestals/pads beneath twenty-nine first-upper C stations. The studio and kitchen
southern beams terminate at the actual package/core wall faces. Complete closed
native unions are chamfered before surface clipping into 24 bounded partitions,
with 15,022 triangles, original outward winding and matching collision. Retained
source masonry, floors, services, doors and the gentler lamp remain authoritative.

The installed inspection passes 749 checks at
**tmp/shell-readiness/rear-wing-c-production-inspection1.log.receipt.json**:
87 matching seats and reproduced original gaps, 64 bases, 28 external pad contacts,
64 exposed anchors and zero retained-body conflicts across 243 component queries.
All eight final production views were inspected. Native studio details show the
chamfers and fasteners; those temporary diagnostic lights/materials do not confer
live finish acceptance. Base steel remains dark under the existing in-game finish.
Strict imported metre UV, unit-basis and derivative checks pass unchanged.

The final installed normal-controller 2C circuit passes 32 waypoints at
**tmp/shell-readiness/rear-wing-c-production-apartment-route1.log.receipt.json**,
with all seven rooms, actual input opening/closing five retained leaves and the
restored closed-entry barrier. All eleven route frames were inspected. The first
trial's six wardrobe-blocked waypoints remain rejected; furniture is preserved.
Eight fixed main-viewport observations add one to thirteen visible draws and
992 to 11,739 primitives, without timing or whole-world performance acceptance.

Only six individually reviewed references are appended to the spatial manifest.
The full clean candidate comparison must use **0454d43**, repeat the retained
broader routes and native fabrics, and preserve protected paths/V1 rollback.
A fresh actual wider survey remains required before counting these 29 targets
in the remaining work list. Higher transfers, weather closures, courtyard/grade
inspection and shared utility construction remain open. Heating cuts stay parked;
no capacity, shell-readiness or completeness requirement is promoted.

Published **3ad3a2cd2929726634ec6f8517680c9cc5804f57** passes the complete
47-gate comparison against clean **0454d43** and all nineteen bound windowed
suites: zero regressions, reader NEW zero, protected 17/17, V2 default/V1
rollback and no requirement promotions. The bound C frame repeats 749 checks
and the 2C apartment repeats 32 waypoints; all nineteen final captures were
reviewed. The normal basement circuit repeats 88 waypoints with thirteen
reviewed captures; roof and vertical routes repeat 51 and 79 waypoints. Keys
retain their schema-2 two-world contract, 84 waypoints and 55 checks with clean
teardown. Comparison and genuine clean complete board are
**tmp/rear-wing-c-support/verified/verification.json** and
**tmp/rear-wing-c-support/3ad3a2c-clean-board.json**. Continue the fresh actual
survey and retained structural interfaces before accepting shell readiness.

The fresh **tmp/shell-readiness/post-rear-wing-c-contact1.log.receipt.json**
and separate **post-rear-wing-c-source-continuity.json** account for 992 of
1,030 stations, leaving 38: **F02** seven, **F03** eleven, **F04** eight and
**F05** twelve. All twenty-nine C targets now have actual native contact. Three
discovery captures were reviewed; the west-slot view is obstructed and confers
no slot/weather inspection acceptance. The first-upper hall overhangs, higher
transfers, wider weather/ground continuity and shared utilities remain open.

## First-upper hall support prerequisite

**art/blender/first_upper_hall_seats.md** records two source-derived 350 mm wide,
300 mm deep bracket-supported I beams and a narrow watch-wall toe ledger at
seven original first-upper hall stations. Fifteen original sample points receive
new seats; six retain their old source-masonry footprint. Four wall brackets and
the ledger meet five retained source faces without cutting or moving old fabric.
The first live preflight rejects an eleven-component redundant ledge segment
against the inner package-room partition; it is removed entirely. The final
preflight checks 92 component volumes with zero old-body conflicts.

The portable Blender generator reproduces the reviewed isolated plan from
canonical layout and editable masonry. Three closed chamfered native assemblies
are clipped into six bounded draws with 5,214 triangles and matching collision.
Thirty-two exposed anchor heads sit beside actual triangular gussets. Strict
imported metre UV, tangent handedness and derivative checks remain unchanged.
The installed geometry inspection at
**tmp/shell-readiness/first-upper-hall-production-inspection1.log.receipt.json**
passes 180 checks, including all fifteen new contacts, reproduced old gaps,
five actual retained wall-face joints and zero conflicts. All five production
frames are reviewed; the dark live steel finish still prevents fine-fastener
appearance acceptance. Main-viewport visible/hidden observations add one or two
draws and 1,075 to 2,771 primitives; no timing acceptance is inferred.

The isolated ordinary-controller route passes 50 waypoints through 2A/2B and
both public-hall returns, with retained input-operated doors and restored closed
entry barriers. All fourteen trial frames are reviewed. The installed route
repeats all 50 waypoints at
**tmp/shell-readiness/first-upper-hall-production-route1.log.receipt.json**;
all fourteen production route frames are reviewed. Clean candidate validation
against genuine clean **3ad3a2c** remains required before publication. Only two
individually reviewed spatial references are appended.
The wider contact count remains 38 until a fresh actual survey is run. Upper
transfers, weather closure, courtyard/grade continuity and infrastructure remain
open. Heating cuts remain parked; no capacity, readiness or completeness
requirement is promoted.

The complete precommit comparison at
**tmp/first-upper-hall-seats/precommit/board.json** has 47 gates, zero regressions,
reader NEW zero, spatial drift zero and no changed requirements. Clean candidate
verification remains required. A fresh actual installed wider survey at
**tmp/shell-readiness/post-first-upper-hall-contact1.log.receipt.json** and
**post-first-upper-hall-source-continuity.json** accounts for 999 of 1,030
stations, leaving 31: **F03** eleven, **F04** eight and **F05** twelve. All seven
hall targets are accounted for by the new native contacts and retained source
footprints. Ground-watch and north-setback views are reviewed. The rolled narrow
west-slot diagnostic has a collinear-up warning and does not confer weather
closure acceptance; a level view remains required.

Published **120b28f413b212ede0ce3f777370aba6e0f409da** passes the complete
47-gate comparison against genuine clean **3ad3a2c** and all twenty-one bound
windowed suites: no regressions, reader NEW zero, protected 17/17, V2 default/V1
rollback and no requirement promotions. Its native fitting repeats 180 checks
and the hall circuit repeats 50 waypoints; all nineteen final hall captures are
reviewed. The retained C frame/apartment and thirteen basement captures are also
reviewed. Basement, roof and vertical circuits repeat 88, 51 and 79 waypoints;
keys retain their schema-2 two-world contract, 84 waypoints and 55 checks with
clean teardown. Comparison and genuine clean complete board are
**tmp/first-upper-hall-seats/verified/verification.json** and
**tmp/first-upper-hall-seats/120b28f-clean-board.json**. Continue the thirty-one
upper stations, external grade and weather/slot inspection. Heating cuts stay
parked; this publication does not establish whole-shell readiness.

## External grade discovery before further service cuts

**tmp/shell-readiness/external-grade-discovery1.log.receipt.json** inspects
four points 450 mm beside each of twelve actual external rear-wing posts.
Frame steel/concrete and foundation bodies are excluded so footing faces cannot
masquerade as courtyard terrain. Forty-seven probes have no first hit down to
four metres below grade; the remaining probe hits an existing basement wall top
at minus 200 mm. None establishes a grade-level terrain owner. The detailed
results are **tmp/shell-readiness/external-grade-probe-results.json**.

West and north rendered views confirm exposed below-grade construction amid
empty terrain. The east camera is obstructed and confers no visual acceptance.
The revised upward slot camera has no collinear-up warning and shows the retained
narrow gap; this limited view does not establish drainage or weather closure.
All four captures are inspected directly. Source-ground ownership, bounded
courtyard/subgrade construction and an unobstructed east inspection remain open.
Retained basement roofs, native foundations and accepted alley paving must keep
their own surfaces and collision. Heating cuts remain parked.

## Repeated upper-core transfers and C inner-wall toe

**art/blender/upper_wall_seats.md** records two source-derived west-core I spans
beneath the original **F03** and **F05** wall bases, plus a fitted C west-toe ledger
on the actual retained **F04_C_MAIN** inner partition. Five backplates meet retained
wall faces; 92 component volumes preserve existing collision. Three closed native
assemblies have four bounded draws, 5,116 triangles, actual triangular gussets and
32 exposed heads. No retained wall, opening or service is moved or cut.

The first isolated native trial fails one strict UV derivative check at a narrow
clipped face. The corrected export preserves the exact authored chart U direction
through undefined-tangent repair; its temporary construction attribute is omitted
from the runtime export. All original mapping tolerances remain unchanged.
Corrected isolated and installed inspections pass 178 checks, with 21 original
sample contacts and reproduction of all old gaps when only the seats are excluded.
All five installed frames and both native studio details are inspected. Fine live
steel finish acceptance remains open. Main-viewport observations add one or two
draws and 1,400 to 2,830 primitives; no timing acceptance is inferred.

Isolated and installed whole-building stair circuits each pass 79 ordinary-input
waypoints. Their final wall/radio-obstructed captures are inspected with that
limitation. Evidence is **tmp/shell-readiness/upper-wall-seats-production-inspection1.log.receipt.json**
and **upper-wall-seats-production-route1.log.receipt.json**. Only one individually
reviewed generated collision-name reference is appended. The full precommit board
at **tmp/upper-wall-seats/precommit/board.json** has 47 gates, zero regressions,
reader NEW zero, spatial drift zero and no requirement changes. Clean committed
candidate verification against genuine clean **120b28f** remains required.

Fresh actual installed contact discovery and separate source reconciliation at
**tmp/shell-readiness/post-upper-wall-seats-contact1.log.receipt.json** and
**post-upper-wall-seats-source-continuity.json** account for 1,006 of 1,030 original
stations, leaving 24: eight each on **F03**, **F04** and **F05**. All seven target
stations now have actual contacts. Three discovery views are reviewed; the west
slot is upright without the earlier collinear warning, but weather closure is
still unaccepted. The remaining transfers, external grade and weather closure
must precede heating cutouts. Whole-shell readiness and completeness stay open.

Published **a44bf6f95caf9d122a1c1ea504ae06b78c47df06** passes the complete clean
47-gate comparison against genuine clean **120b28f** and all twenty-three bound
windowed suites: zero regressions, reader NEW zero, protected 17/17, V2 default
and V1 rollback, no changed requirements. All six final new batch captures,
nineteen retained hall captures and thirteen basement captures are reviewed with
their stated appearance limits. Native fitting repeats 178 checks; stair, hall,
basement and roof circuits repeat 79, 50, 88 and 51 waypoints. Keys retain their
schema-2 two-world contract, 84 waypoints and 55 checks. Exact comparison and
genuine clean complete board are **tmp/upper-wall-seats/verified/verification.json**
and **tmp/upper-wall-seats/a44bf6f-clean-board.json**. The remaining twenty-four
upper stations, external grade and weather closure stay open before heating cuts.

## Remaining upper transfers before grade and weather closure

**art/blender/remaining_upper_transfers.md** records source-fitted **F03** service
and vestibule spans, **F04** vestibule toe/northern T frame and **F05** offset
vestibule/northern kitchen T frame. The actual lower A/B room identities and
retained source faces govern their position. Seven closed native assemblies
export in thirteen bounded draws with 13,154 triangles, 233 component volumes,
sixteen wall interfaces and 72 exposed heads. The original light-slot width,
wet-stack volume and retained structural fabric stay unchanged.

The first preflight rejects 32 overlaps against two retained B partitions.
The revised vestibule profile fits their measured 210 mm channel. A later
native face/UV precision failure is corrected with small local part coordinates
and an equivalent stable exported V chart; strict checks are not relaxed.
Corrected isolated and installed fitting inspections each pass 667 checks,
including all 72 frozen original sample contacts, reproduced old gaps, sixteen
actual wall joints, 72 exposed heads and zero old-body overlaps. All seven
installed frames and three isolated native details are reviewed; the narrow
vestibule camera is a geometry diagnostic, and fine live finish remains open.
Matched visible/hidden observations add one to six draws and 1,514 to 7,783
primitives; no timing or capacity acceptance is inferred.

The isolated affected lower A/4B circuits pass 28 and 32 ordinary-input waypoints,
and the whole-building stair circuit passes 79. Retained door and household
controls remain live. All nine A and 22 B trial captures are reviewed; the last
stair capture is wall/radio obstructed. Installed routes, a fresh whole-building
source-contact discovery and complete clean candidate comparison remain in
progress. The previous wider count of 24 is retained until fresh reconciliation.

The unobstructed east grade view and live frame export at
**tmp/shell-readiness/external-grade-frame-discovery1.log.receipt.json** confirm
the earlier missing-ground finding: 47 of 48 original probes remain empty and
one meets a basement wall at minus 200 mm. All four captures are reviewed. The
Orison's actual registered pose rotates pi around UP at world Z minus 11.65;
CityShells retain source orientation at minus 9.795. These frames must be
reconciled explicitly when projecting old source ground. Ground/subgrade,
drainage, weather closure and wider shared systems remain open before heating
cutouts. This batch establishes no whole-shell readiness or ledger promotion.

Installed affected-room and full stair routes repeat 28, 32 and 79 waypoints.
All nine A and 22 B captures, one qualified stair capture and three actual native
studio details are directly reviewed. Fresh installed discovery at
**tmp/shell-readiness/post-remaining-transfers-contact1.log.receipt.json** and
separate **post-remaining-transfers-source-continuity.json** reconciliation now
account for all 1,030 original stations, leaving zero unresolved. All 24 targets
have actual native contact. Three fresh discovery captures are reviewed; the
upright slot view confers no drainage or weather acceptance. The wider station
count therefore moves from 24 to zero, without claiming structural capacity or
whole-shell readiness.

The full precommit board at **tmp/remaining-upper-transfers/precommit/board.json**
has 47 gates, zero regressions, reader NEW zero, spatial drift zero and no changed
requirements. Clean committed candidate verification against genuine clean
**a44bf6f** remains required. External ground/subgrade, drainage, weather closure
and shared service routes remain the next prerequisites; heating cuts stay parked.

## Remaining-transfer publication

Published **97faa90eacfad8f2ea51d0145f2b699ba7f9d854** completes the clean
47-gate comparison against genuine clean **a44bf6f**: zero regressions,
no requirement changes, protected paths 17/17 and retained V2/V1 selector
behavior. Twenty-six source-bound windowed wrapper suites and both imports complete,
including 667 native remaining-transfer checks, the affected A/4B routes
(28/32 waypoints), retained basement clearance and the 79-waypoint stair circuit.
All seven new candidate native views, nine A, 22 4B and thirteen retained
basement captures are reviewed with the existing fine-appearance limits.
Verification is **tmp/remaining-upper-transfers/verified/verification.json**;
**tmp/remaining-upper-transfers/97faa90-clean-board.json** is the next clean
baseline. The wider shell/infrastructure task remains open; heating cutouts
stay parked while exterior ground, drainage and weather closure are resolved.

## Fitted front public-floor ownership

**art/blender/front_pavement.md** records the registered public slab replacement:
37 bounded native draws, 1,656 triangles, 160 mm thickness and the retained
zero top datum. The composed original **pavement_slab** is removed; current
room, masonry, bodega, shed and curb volumes retain their separate owners.
The five original 700 mm room-floor overlaps are reproduced geometrically,
then resolved in the installed mesh/collision with all fifteen frozen room
stations preserved. Two existing shower trays remain qualified foregrounds.
The saved closed native union has zero nonmanifold edges and positive volume.

Installed fitting inspection passes 911 checks with 592 actual new-surface
contacts and strict metre-UV derivatives. All five player-height frames and
the actual production-native overview are reviewed. Matched stationary visible/
hidden viewport observations add four to 31 draws and 116 to 892 primitives;
they establish geometry cost only. Broader street/courtyard subgrade, drainage,
boiler airwell, city-plinth joins, weather closure and finished paving joints
remain open. The flat courtyard trial is uninstalled and requires fresh owner
discovery against this fitted paving. Heating cutouts stay parked.

The complete precommit board has 47 gates with zero regressions, reader NEW
zero, spatial drift zero and no requirements changed against genuine clean
**97faa90**. Ten production wrapper suites plus the separate 25-waypoint alley
route preserve street, shed, bodega, subway, bar, arcade and resident-key
behavior. Only five individually reviewed room identities are registered.
Clean committed candidate comparison remains required before publication.

## Reconstruction-matrix owner boundary

The committed **2ac3b8e** attempt at **tmp/front-pavement/verified/verification.json**
has zero static regressions and eleven completed, source-bound windowed suites,
but the additional V1/V2 reconstruction matrix reached 180 seconds. It is blocked
and is not a publication receipt. The approved long windowed repeat at
**tmp/front-pavement/matrix-recheck/matrix.log.receipt.json** completes in 239 seconds:
all four reconstruction directions preserve calendar, inventory, case and optical
state; one acoustic-restoration assertion fails.

The separate actual owner probe at **tmp/front-pavement/matrix-acoustic-probe1.log.receipt.json**
and **matrix-acoustic-probe.json** confirms that scoped adapter restoration matches
the complete expected graph. Its only remaining pre-world differences are the
21 independently resident bar mouths. The test previously required the adapter
to unmount the bar while the bar was still live. The corrected matrix compares
all owned adapter originals with the pre-world records, checks disjoint bar
ownership, requires the whole graph to match those restored records plus every
unaffected active owner, and retains the exact full-graph world-teardown check.
Runtime acoustic code and bar poses are unchanged. No suite failure is waived.

The paving asset, affected-route evidence and existing material state remain
unchanged. A clean follow-up candidate must pass the corrected complete matrix,
the installed paving and resident-key contract before the authorized push.
The prior eleven passing receipts remain separately attributable to **2ac3b8e**;
they do not become follow-up-head runtime-contract proof. Heating cuts stay parked.

## Fitted pavement publication

Published **118d770362f1c20c9873c4d1165d86a904a637a8** includes the fitted
paving **2ac3b8e** and the strict reconstruction-matrix owner correction.
The unmodified candidate verifier at
**tmp/front-pavement/matrix-followup-verified/verification.json** records a
complete clean 47-gate comparison against **97faa90**, zero regressions,
no requirement changes, protected paths 17/17 and retained default V2/explicit
V1 rollback. Both imports complete; the first recreates legacy untracked
UIDs from cache with warnings, and the second has empty stderr.

The approved long matrix completes all 44 checks in 138 seconds with all four
save/reload directions passing. Its only stderr warnings are the deliberate
invalid-selector exercise and the existing V1 found-art placement warning.
Fresh current-head windowed paving and resident-key runs pass 911 checks and
84 waypoints/55 checks respectively, both with empty stderr. All five paving
frames and 21 key-route frames are reviewed; ordinary radio foreground remains
qualified. Eleven passing parent wrapper receipts retain their **2ac3b8e**
attribution and still bind to unchanged current runtime/test sources. Their
receipts are preserved without relabelling the resident-key runtime contract.

The next genuine clean board is **tmp/front-pavement/118d770-clean-board.json**;
**followup-verification-summary.json** records exact source attribution.
Fresh production discovery at
**tmp/shell-readiness/post-front-pavement-grade-discovery1.log.receipt.json**
exports 782 enabled grade colliders and preserves all 48 ground stations:
47 remain empty and one meets an existing wall. Seven new frames are reviewed.
Overhead rays find roof-deck floors above the two front recesses at 19 m;
the north courtyard and east airwell have no overhead collider. Those rays
describe collision ownership, not comprehensive weather closure. The existing
alley still covers the boiler air opening at minus 300 mm.

The new uninstalled flat ground source accounts for the exact 296 fitted slab
cells, clears 946 retained/reserved volumes and has zero nonmanifold edges.
Its native/grid volume is approximately 4,186.17 cubic metres, with difference
below 0.001 cubic metre; the actual saved native render is reviewed. Drainage,
city-plinth joins, narrow wall-edge closure, boiler airwell and broader raw
infrastructure remain open. Heating cuts stay parked; this is no whole-shell
acceptance or ledger promotion. The authorized wider task continues.

## Bounded groundworks continuation

**art/blender/groundworks.md** records the fitted ground, graded original alley,
grated boiler well, open catches and hollow construction-stage collector.
The V2 Ground module mounts once in the existing blockout frame; ServiceAlley
replaces only its old Paving/Iron owners and retains masonry, lamps and doors.
The public slab/retained floors/basement roofs keep their original ownership.
The source-bound geometry-authoring map distinguishes exact solid masks from
occupied volumes and qualified clearance envelopes; it refuses stale bindings.

The installed inspection passes 1,535 checks at all 48 original ground stations,
including 46 actual terrain contacts and two retained embedded-masonry stations.
The installed alley passes 195 strict mapping checks and 32 normal-controller
waypoints, with clear well/catch outlets, collector bore and unchanged boiler
window reveal. Reopened saved Blender sources show 277 closed alley pieces,
32 bounded alley partitions, 198 ground partitions and no ground intrusion into
976 retained/reserved volumes. Fresh 48,817-station native runoff discovery
reaches all four receivers without missing/stranded samples. These are scoped
construction observations, not downstream drainage or whole-shell acceptance.

The property collector ends at local Z **-16.605 m**, X **17.75 m**, with a bolted
construction blank awaiting the street main. It is an **ADAPTATION** physical
recipe with no second simulation. Source water/drain services in the bar, bodega
and arcade remain independent under the owner's prior choice. Residual courtyard
falls/outlets, neighbor plinths/terrain, joint seals, boiler-window operating
glazing and roof/weather/light-slot closure remain open. Heating cuts stay parked.

The catalogue admits **asphalt** through its existing runtime-policy generator,
using the original three maps and authored 2.5 m scale without a new visual lock.
Five paired prototype view costs and nine installed ground observations are
recorded in the construction note; they grant no frame-rate verdict. Four
individually reviewed new test references are appended while all 6,383 existing
spatial records remain unchanged. No ledger requirement changes are claimed.
The clean complete baseline remains **tmp/front-pavement/118d770-clean-board.json**;
the final named-path candidate result belongs to
**tmp/shell-readiness/groundworks-verified/verification.json** after verification.
The six location phases and shared infrastructure register remain unfinished.
