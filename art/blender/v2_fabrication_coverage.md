# V2 fabrication and material coverage

Evidence class: **INERT**

This is an implementation work index, not acceptance evidence. Regenerate
**v2_fabrication_inventory.json** with **tools/inventory_v2_fabrication.py**.
The index names all 200 semantic spaces, 111 doors, 87 openings, 72 windows,
74 envelopes, 85 fixtures, 67 platforms, 12 lift landings, 14 stairs and seven
risers, plus sixteen installed-data files and building-script asset references.
Discovery does not classify a hidden reservation as an unfinished visible prop.
The production root, its exterior/passage composition and rendered inspection
remain necessary to establish what the player actually sees.

The all-space overview now has 400 captures across all 200 spaces. See
**v2_space_sweep.md** and **v2_space_review.json** for the reviewed overviews,
obstructed landing views and remaining detail/route work. This is a coverage
advance, not acceptance of every installation. A separate 100-station city survey now has 100 images and seven inspected
contact sheets; discovery limits and specific route/detail work remain. Several arcade
apparatus and stock groups still use primitive boxes. Keys Cut, Shoe Rebuilding
and News/Cigars now have source-owned native fittings; their rear stores, services and the
remaining retail trades remain open in the fabrication queue.

The focused production run also writes **production_geometry_inventory.json**
beside its screenshots, recording actual mesh types, visibility, instances and
active material/texture or shader bindings. The 2026-09-29 discovery observed
11,378 geometry nodes, of which 9,812 were visible in the scene tree: 5,732
ArrayMesh, 2,659 box, 904 cylinder, 272 torus, 170 sphere and 75 quad nodes.
These include ordinary simple surfaces and composed/debug content; they are
not a count of unfinished assets. The render counters include additional
viewports and passes and are not an FPS or whole-building performance verdict.

## Work order and acceptance

Finish geometry before broad texture rollout. For each installation, require
player-height and close-up inspection, continuous assembly, usable controls,
collision/visual agreement, moving-pivot checks where applicable, and no route
or gate regression. Reuse accepted fabrication unless inspection exposes a
defect. The JSON index deliberately retains every space even when no defect
has yet been demonstrated; none is silently marked complete.

| Family / installation | Existing authority | Current disposition and next check |
|---|---|---|
| Original shop seating | build_shop_seating / sixty immutable source boxes / existing shipping maps | Thirty fitted chairs, benches and pedestal stools; 416 closed stocks, 42 draws, 55,200 triangles and 420 floor samples. Paired native/production review in shop_seating.md. Other counters, apparatus, cloth and broad finishes remain open. |
| Shoe Rebuilding machinery and stock | build_cobbler_fittings / 49 immutable source records / existing shipping and catalogue maps | Eleven assemblies, 408 closed stocks, 46 partitions and 117,708 triangles; twenty-two hollow shoes, supported finisher/sewing frames, fitted rear approach and locally finished dust cover. Native and production detail in cobbler_fittings.md. Rear-store access, live machinery and utility continuity remain open. |
| News/Cigars stock and transaction furniture | build_news_fittings / 38 immutable source records / existing shipping and catalogue maps | Thirteen assemblies, 215 closed stocks, 37 partitions and 41,656 triangles; folded papers, hollow jars/bowls, glazed stock, open service frame, actual paper punches and a seated proprietor stool. Explicit local container optics and fitted ledger/punchboard/pipe-display extents; original references remain. Rear-store operation, continuous access and utility continuity remain open. |
| Hardware/Paint ordered drawer wall | build_hardware_drawers / 80 immutable source records / five original shipping map sets | Thirty-five framed oak drawers and brass bail pulls, fitted cabinet rails and a floor-seated plinth, supported workbench and seven actual paint tins; 601 stocks, 87 partitions, 122,676 triangles and 50 contacts. Explicit aisle-facing adaptation in hardware_drawers.md. Other stock, scale/shaker equipment, glass/tool racks, ladder and independent services remain open. |
| Hardware/Paint passive apparatus | build_hardware_apparatus / four immutable source records / existing catalogue and shipping maps | Joined beam balance with actual open pans, unloaded shaker frame and floor/crown-supported paddle; 53 stocks, five partitions, 13,280 triangles and ten contacts. Explicit support and local aged-brass adaptations in hardware_apparatus.md. Live operation, remaining stock/racks/ladder and independent services remain open. |
| Hardware/Paint retail stock | build_hardware_stock / 53 immutable source records / original shipping and registered catalogue maps | Two supported six-level cases, 36 filled trays, 48 open brass couplings, framed service counter and window stand; 678 stocks, 81 partitions, 170,472 triangles and 56 contacts. Explicit +X rack clearance and local quieter wood finish in hardware_stock.md. Glass/tool racks, ladder, continuous routes and independent services remain open. |
| Hardware/Paint glass/tools/ladder | build_hardware_tools / 34 immutable source records / original shipping and registered catalogue maps | Framed five-sheet glass stand, supported cutter, eight silhouettes with seven tools and one pale vacancy, and floor/case-bearing ladder; 100 closed stocks, 11 partitions, 10,976 triangles and 12 contacts. Explicit adaptations in hardware_tools.md. All 171 fitting sources are covered; operations, plot behavior, routes and services remain open. |
| Photography camera display | build_photo_cameras / 8 immutable source records / original shipping and registered catalogue maps | Three passive bellows/box/press silhouettes and floor-bearing framed window stand; 50 closed stocks, 8 partitions, 10,016 triangles and 7 contacts. Explicit raised deck and moved back in photo_cameras.md. Other shop fittings, photography operation, routes, glazing/locks and services remain open. |
| Photography counter/ledger | build_photo_counter / 4 immutable source records / original shipping and registered catalogue maps | Framed counter, four thin panes, seated ledger; 31 closed stocks, 5 partitions, 5,124 triangles and 5 contacts. Explicit local glass adaptation in photo_counter.md. Stock, photography operation, routes, storefront glazing/locks and service capacity remain open. |
| Harukiya pool table | build_bar_pool / seven original source boxes / retained chalk and cue owners | Fitted leg/apron frame, recessed violet bed, six open pocket bags and five spherical balls; scoped native, collision, finish and ordinary chalk-input checks in bar_pool.md. Broader bar services and final surfaces remain open. |
| Harukiya original light mounts and canopy | build_bar_fixture_mounts / eighteen original markers / actual retained fabric | Sixteen fitted fixture connections and four canopy stays; 161 closed stocks, 46 partitions, 13,900 triangles, native/production contact and ordinary-height review in bar_fixture_mounts.md. Gallery overlap is addressed by the separate source-fitted gallery; independent services and broad finishes remain open. |
| Harukiya original gallery | prepare_bar_gallery / WallArtLaw / build_bar_gallery / twenty-two retained sources | Twenty-two fitted works on their original walls, corrected north image winding, 242 closed construction stocks, four partitions and 9,944 triangles. Actual wall/backing contact and original observation reach are inspected in bar_gallery.md. Atlas/content mismatch, independent services and broad finishes remain open. |
| Harukiya stage curtains and pelmet | prepare_bar_stage / measured retained signal hardware / build_bar_stage / seventeen original sources | Thin folded cloth, sewn header/hem, covered timber fascia and wall-supported rail; 118 closed stocks, three partitions and 36,340 triangles. Clear retained geometry, wall/collar contacts and source signal preservation are checked in bar_stage.md. Piano, microphone, PA, inherited sign/ceiling fit and final cloth finishes remain open. |
| Floors, ceilings, partitions, corners, openings | V2 blockout and architectural materials | Open stair-core walls now span the full storey, closing the missing 200 mm ceiling band; twelve contacts and alley views checked. Simple planar solids can be intentional. Review every room class for seams, thickness and collisions; the Blender outer masonry leaf now covers exposed slab bands and extends reveals while preserving narrow light slots; see **exterior_masonry.md**. The fitted front entrance, awning, sign and upper composition are described in front_facade.md; retained ceilings and rear-door corner are fitted in exterior_masonry.md. Current rendered review is recorded in building_surface_finish.md. |
| Window surrounds and room millwork | window_joinery / millwork_profile Blender generators | Existing completed work retained; all 200 semantic-space overviews reviewed. Tight or obstructed detail views retain their limits. Sashes intentionally remain static. |
| Ordinary doors | existing leaf owner, Blender knobs and articulated butt hinges | Retain completed hardware; 108 actual fitted leaves clear 9,843 one-degree poses. Ordinary stops are 90 degrees, basement shop 85, roof 100. The narrow bar WC has a native wide-throw hinge; building_surface_finish.md records the fit and walking checks. |
| Public/service stairs and landings | court stair-ironwork generator and existing collision ramps | Seven public flights fit a one-metre court eye; service assembly retained. Source-owned landing trims, fourteen guards and local transfer seats are in light_court.md. The retained platform soffits and court transfers are fitted in landing_soffits.md and light_court.md; exposed iron now uses local iron_blackened. Structural capacity remains separate. |
| Lift cab, landings and controls | lift_* Blender generators, OrisonElevator | Retain completed assemblies and mechanisms. Emergency-stop presentation remains decorative. |
| Lift roof drive, suspension and guards | build_lift_drive.py and V2 lift drive/suspension owners | Existing Blender machinery found and retained; inspect bearings, mounts and guard clearance before deciding whether refinement is needed. |
| Roof parapet, coping and chimney | roof_coping / chimney_crown Blender generators | Retain prior completed masonry/weather caps. Parapet planar substrate is intentional; inspect joins and roof route. |
| Roof tank and overflow collector | house_tank Blender generator | Retain completed timber/binding assemblies and maintenance; lid remains static. |
| Roof ventilators and bathroom registers | roof_ventilator / vent_register Blender generators | Retain completed rotor/shutter pivots and passive registers; stack integration sweep pending. |
| Shared ductwork and service chases | V2 ventilation and semantic risers | Inspect junctions, supports and maintenance clearance; do not infer completion from hidden shaft boxes. |
| Boiler firing and ash doors | BoilerProp | Outward swing and matching plate collision fixed in 643c161; 14 animated poses, actual contacts and service route checked. Native body, firebox, pipework and instruments are described by the following entries; whole combustion/heating service remains separate. |
| Boiler breeching | build_breeching.py / V2 boiler flue owner | Three fitted elbows and open straight shells implemented; focused rendered/contact checks passed. Candidate verification and production route belong to the batch receipts. |
| Boiler body and firebox | build_boiler_body.py / BoilerProp | Hollow casing, fitted surrounds, recessed firebrick, internal grate, ash tray and live shaped coal fabricated. Twelve cavity contacts and closed plate seals checked; production renders inspected. |
| Boiler water column, header and service hardware | BoilerProp / build_boiler_pipework.py | Instrument feeds, unions and guards fabricated; handles clear the glass and the needle hub faces its dial. Header now reaches the heat shaft, the return sits outside the casing and the discharge has fitted supports. Seven pipe contacts and three damper settings checked; full header and production-lamp views inspected. |
| Coal delivery, electrical room, workshop, storage | V2 basement / coal delivery / existing apparatus | Stepped coal boxes replaced with an angular Blender heap; delivery route and nine contacts pass. Preserve delivery state and service/storage access; inspect supports and storage construction in detail. |
| Public reading room | build_reading_furniture.py / existing room and door owners | Empty shell furnished with a six-place table, chairs and two bookcases. Nine actual contacts and 25 walking waypoints pass; shared reading activities remain unimplemented. |
| Public rooms, laundry, watch/mail/package spaces | Production prop owners and completion interiors | Existing mechanisms remain. Lobby benches and parcel shelves fabricated; four surface contacts, solid-intersection check and 29 waypoints pass. Other controls/service installations still need focused review. |
| Model Laundry parcels, shirts and ironing furniture | build_laundry_fittings.py / retained shop owners | Forty wrapped parcels, nine shirts and hangers, supported rail and ironing table/pads fitted from 53 source stocks. Native joins and 57 supporting contacts inspected; the native tubs, mangle, irons, airers and rear-workshop apparatus are now fitted in laundry_apparatus.md. Physical utility continuity and capacity remain open. |
| Apartment fixed wet fittings | bath_lavatory / bath_water_closet / bathroom_details | Reuse existing Blender fittings; check all installed variants and close-range controls. |
| Apartment furniture and built-ins | domestic_furniture_source and installed surfaces | Existing source-derived surfaces are not automatically placeholders. All 22 installed beds, including eight completion templates, use three Blender variants and matching collision; 88 contacts and clear installed views inspected. Other furniture kinds, hardware, pivots and UVs still require detail review. |
| Household radiators and accessories | heating/accessory source and mechanism owners | Preserve one-pipe steam and service semantics; inspect support, union and vent geometry. |
| Room lights and switches | lighting data / light_switch Blender generator | Retain completed switches; fixture bodies and mounting clearance need complete sweep. |
| Street, entry, passage, shop installations | exterior cell / passage composition | Rear service alley fabricated and joined to the existing sidewalk, with an operating rear door. Include imported architecture and shop props in the sweep; semantic interior index alone does not prove exterior coverage. |
| Bounded courtyard subgrade and alley groundworks | build_orison_ground / build_alley_groundworks / retained-grade authoring map | Fitted source volume, graded original paving, grated boiler well, open catches and hollow construction-stage collector; scoped native and walking checks in groundworks.md. Street-main connection, residual courtyard drainage, full weather/terrain closure remain open. Operating glazing is covered by boiler_window.md. |
| Neighboring city bedding and terrain | build_city_shells / shared city_registration / build_city_foundations / build_orison_ground | Northwest and southwest assembly overlaps removed; 23 ground-level native undersides fitted around retained owners. Finite grade extends across the source city envelope; scoped source, mapping and terrain checks in city_foundations.md and city_grade.md. Weather, drainage and broader surface review remain open. |
| Neighboring rooftop masts and guy anchors | build_city_masts / immutable authored aerial records / retained city_shells | 25 masts and 75 guys fitted against actual saved roof/bulkhead faces; full plate footprints and clear spans in city_masts.md. Beacon housings, tanks, weather closure and broad material acceptance remain open. |
| Original roof flat-top aerials and dishes | build_city_aerials / 140 immutable components / retained city_shells | 23 flat frames and 16 curved collectors; 636 closed stocks, 39 connected assemblies, 85 supported plates and 108 clear spans. Exact fabricated triangles and local catalogue maps; city_aerials.md. Tanks, beacon housings, weather joints and broad textures remain open. |
| Original neighbouring roof tanks | build_city_tanks / 98 immutable records / fitted on-roof positions | Fourteen closed stave tanks, fitted plates/legs/braces and full weather covers; source positions recorded separately from local fits clearing original aerials. Catalogue tank_staves finish; city_tanks.md. Production/native acceptance, beacon housings, weather joints and broad family textures remain open. |
| Neighboring city parapet corners | build_city_closure / retained 335 source stocks | Four original overlapping parapets become one closed ring per building; 25 rings, 84 original material groups and strict metre charts. See city_closure.md. Whole weather/drainage and broad finishes remain open. |
| Original mast-head beacon housings | build_city_beacons / seventeen immutable records / retained fabricated mast heads | Closed passive red housings, fitted pedestals and 1,105 complete footprint samples; city_beacons.md. Final verification and broad weather/service acceptance remain open. |
| Local roof-hardware surface calibration | catalogue / three periodic generators / existing source geometry | Local bronze_sheet, galvanized_roof and beacon_lacquer; old maps and fifteen locks retained. Native geometry equality and production acceptance required; city_hardware_finishes.md. |
| Fixed roof hardware surface charts | fabrication_uvs / common native surface axes / catalogue tile phase | city_hardware_uvs.md records corrected texture repetition on masts and aerials. Every exported triangle position, normal, node pose and fitted contact remains identical. Ceramic cracking, bronze patina and broad family material acceptance remain open. |
| Service-bulkhead weather cover and rainleader | build_roof_service_weathering / source-owned retained roof cap | Sloped metal cover, open gutter/leader and fitted supports; the fitted downstream field, outlets, leaders and grade receivers are recorded in roof_drainage.md; see roof_service_weathering.md. Capacity/weather acceptance remains separate. |
| Public light court and skylight weather fit | public stair/court/bridge generators, roof cap generator and public-weather source plan | One-metre eye, fitted guards/supports and six pitched panes installed within the retained core; bounded curb/cricket/gutter/leader fit in light_court.md. The source-owned front-court roof/contacts are fitted in front_court_roof.md and drainage assembly in roof_drainage.md. Whole structural/weather capacity remains open. |
| Roof-wall base flashing fit | build_roof_base_flashings / retained roof source and blockout | Folded upstands, fitted feet, mitered bulkhead/parapet corners and clear retained door apertures; original walls/deck own buried contact planes. See roof_base_flashings.md. The fitted main-roof field, falls/outlets and downstream connections are in roof_drainage.md. Sealing/weather capacity remains open. |
| Operating boiler-well window | build_boiler_window / retained semantic opening / existing household save owner | Fitted six-pane inward sash, hinges, cam and stays; original reveal/well retained. Scoped fit, walking and save proof in boiler_window.md; whole weather and combustion-air capacity remain open. |
| Main-roof field finish | build_roof_membrane / retained seven roof deck owners / catalogue roof_bitumen | Closed four-millimetre native finish within the original slab envelope; metre UVs, three authored PBR maps and bounded partitions. Scoped fit in roof_membrane.md; coordinated falls, outlets, leaders and retained-grade receivers are fitted in roof_drainage.md. Capacity and weather acceptance remain open. |
| Keys Cut source-owned retail fittings | build_locksmith_fittings / 133 retained source boxes / existing local catalogue maps | Nine assemblies, 98 pierced key blanks, 536 closed stocks, 30 partitions and 93,880 triangles. Native joins and clear production details are inspected; the geometry test checks 34 supports and exact key faces. Copying, saved permissions and passage reload retain their separate checks. Original rear-store stock and the remaining shop trades stay open. |
| Bodega source-owned retail fittings | build_bodega_fittings / 58 original source mesh owners / catalogue maps | 966 closed stocks, 92 partitions and 146,668 triangles; supported racks, individual stock, lined icebox, recessed counter, delivery cart and seated practicals. All 18 aggregate stock owners remain; real depletion, actual conduit contacts and fitted Label3D lettering are checked in bodega_fittings.md. Independent-service capacity and broader gameplay remain open. |
| Bodega fixed frontage and lower door field | build_bodega_frontage / original exterior panes and hinged leaf | Three demonstrated upper bands closed by fitted frame and glass; raised lower panel stays inside the original moving box. Scoped native, collision and 57-pose checks in bodega_frontage.md; shop shell, weather capacity and broader materials remain open. |
| Carried radiophone, teletype and lamp | existing service-set owners | Preserve accepted assembly, physical HUD, pointer and debug behavior; no redesign authorized by the inventory. |
| Dream zoo, hero, organelles, sixteen critters | accepted zoo and Blender critter sources | Intentional preservation boundary. Keep accepted assets, behaviors and declared placeholders; regression checks remain required. |

The four original Harukiya ceiling pipes now have fitted split collars, bolted joints and ceiling bearings; see **bar_pipe_supports.md**. Their endpoints and utility function remain source-owned and open to service review.

## Materials and mapping

Production V2 architecture uses **orison_v2_architectural_materials.gd**:
catalogue keys feed MatLib, then the existing SurfacePass recipes. MatLib uses
the generated material-set table, authored metres per tile, local triplanar
mapping, existing albedo/roughness/normal maps and 0.35 normal strength.
SurfacePass owns calibrated height, detail and masks. Lamp/Dream optical
binding is a separate existing consumer and must not be replaced by a generic
material shader. Older art roadmap descriptions of flat materials and baked
lighting are not a description of this production composition.

The breeching keeps **cast_iron** and **metal**, with editable metre UVs and
length baked into straight mesh positions so triplanar scale stays physical.
No new material key, bitmap, map derivation, global lighting or shader change
has been made. Broad material acceptance is still **pending** for masonry,
stone/concrete, plaster, painted trim, wallpaper, tiles/ceramics, wood, metals,
glass, cloth/leather, paper, coal/soot, water, exterior paving/roofing, vegetation
and supported Dream surface families. Validate representative installations
under the production lamp before applying changes throughout the building.

The four original Harukiya ceiling stocks use a local **smoked_plaster** finish with fine physical substrate relief and optical smoke staining. Their 48 original faces, normals and physical owner remain; **bar_ceiling_finish.md** records the bounded repair. Shared soot, all fifteen visual locks and broader material acceptance remain separate.

## Evidence and continuation

Door receipts and inspected captures: **tmp/boiler-doors**; verified candidate
**643c161b0f4e3aadb44fdcba576478476eb4d801** was pushed to main with zero gate
regressions. Breeching evidence: **tmp/breeching**, including before views,
double import, focused test, route views and final candidate verification.
Only completed wrapper receipts count as suite runs; no runtime-contract or
ledger promotion is claimed. The first pre-change route hit the runner ceiling;
the second failed lamp-settle timing. Neither is presented as a passing run.

Use **game/docs/v2_launch.md** for the exact title and zoo procedure. V2 stays
the default and explicit V1 rollback remains. Preserve the owner's six files
under **art/renders/insitu**, accepted H23 debt, historical evidence and all
protected systems. The full geometry and material task is not yet complete.
