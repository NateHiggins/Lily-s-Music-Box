# V2 fabrication and material coverage

Evidence class: **INERT**

This is an implementation work index, not acceptance evidence. Regenerate
**v2_fabrication_inventory.json** with **tools/inventory_v2_fabrication.py**.
The index names all 200 semantic spaces, 111 doors, 87 openings, 72 windows,
74 envelopes, 85 fixtures, 67 platforms, 12 lift landings, 14 stairs and seven
risers, plus fourteen installed-data files and building-script asset references.
Discovery does not classify a hidden reservation as an unfinished visible prop.
The production root, its exterior/passage composition and rendered inspection
remain necessary to establish what the player actually sees.

The all-space overview now has 400 captures across all 200 spaces. See
**v2_space_sweep.md** and **v2_space_review.json** for the reviewed overviews,
obstructed landing views and remaining detail/route work. This is a coverage
advance, not acceptance of every installation. The composed exterior and
passage still require a complete independent sweep.

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
| Floors, ceilings, partitions, corners, openings | V2 blockout and architectural materials | Open stair-core walls now span the full storey, closing the missing 200 mm ceiling band; twelve contacts and alley views checked. Simple planar solids can be intentional. Review every room class for seams, thickness and collisions; the Blender outer masonry leaf now covers exposed slab bands and extends reveals while preserving narrow light slots; see **exterior_masonry.md**. Full facade composition remains pending. |
| Window surrounds and room millwork | window_joinery / millwork_profile Blender generators | Existing completed work retained; per-space visual sweep still pending. Sashes intentionally remain static. |
| Ordinary doors | existing leaf owner, Blender knobs and articulated butt hinges | Retain completed hardware; sweep swing clearance and thresholds across both handed orientations. |
| Public/service stairs and landings | court stair-ironwork generator and existing collision ramps | Seven public flights fit a one-metre court eye; service assembly retained. Source-owned landing trims, fourteen guards and local transfer seats are in light_court.md. Wider landing/shell fit remains open. |
| Lift cab, landings and controls | lift_* Blender generators, OrisonElevator | Retain completed assemblies and mechanisms. Emergency-stop presentation remains decorative. |
| Lift roof drive, suspension and guards | build_lift_drive.py and V2 lift drive/suspension owners | Existing Blender machinery found and retained; inspect bearings, mounts and guard clearance before deciding whether refinement is needed. |
| Roof parapet, coping and chimney | roof_coping / chimney_crown Blender generators | Retain prior completed masonry/weather caps. Parapet planar substrate is intentional; inspect joins and roof route. |
| Roof tank and overflow collector | house_tank Blender generator | Retain completed timber/binding assemblies and maintenance; lid remains static. |
| Roof ventilators and bathroom registers | roof_ventilator / vent_register Blender generators | Retain completed rotor/shutter pivots and passive registers; stack integration sweep pending. |
| Shared ductwork and service chases | V2 ventilation and semantic risers | Inspect junctions, supports and maintenance clearance; do not infer completion from hidden shaft boxes. |
| Boiler firing and ash doors | BoilerProp | Outward swing and matching plate collision fixed in 643c161; 14 animated poses, actual contacts and service route checked. Full boiler fabrication remains open. |
| Boiler breeching | build_breeching.py / V2 boiler flue owner | Three fitted elbows and open straight shells implemented; focused rendered/contact checks passed. Candidate verification and production route belong to the batch receipts. |
| Boiler body and firebox | build_boiler_body.py / BoilerProp | Hollow casing, fitted surrounds, recessed firebrick, internal grate, ash tray and live shaped coal fabricated. Twelve cavity contacts and closed plate seals checked; production renders inspected. |
| Boiler water column, header and service hardware | BoilerProp / build_boiler_pipework.py | Instrument feeds, unions and guards fabricated; handles clear the glass and the needle hub faces its dial. Header now reaches the heat shaft, the return sits outside the casing and the discharge has fitted supports. Seven pipe contacts and three damper settings checked; full header and production-lamp views inspected. |
| Coal delivery, electrical room, workshop, storage | V2 basement / coal delivery / existing apparatus | Stepped coal boxes replaced with an angular Blender heap; delivery route and nine contacts pass. Preserve delivery state and service/storage access; inspect supports and storage construction in detail. |
| Public reading room | build_reading_furniture.py / existing room and door owners | Empty shell furnished with a six-place table, chairs and two bookcases. Nine actual contacts and 25 walking waypoints pass; shared reading activities remain unimplemented. |
| Public rooms, laundry, watch/mail/package spaces | Production prop owners and completion interiors | Existing mechanisms remain. Lobby benches and parcel shelves fabricated; four surface contacts, solid-intersection check and 29 waypoints pass. Other controls/service installations still need focused review. |
| Apartment fixed wet fittings | bath_lavatory / bath_water_closet / bathroom_details | Reuse existing Blender fittings; check all installed variants and close-range controls. |
| Apartment furniture and built-ins | domestic_furniture_source and installed surfaces | Existing source-derived surfaces are not automatically placeholders. All fourteen bed coverings/pillows now use three Blender variants and matching collision; 56 contacts and visible inspection captures pass. Other furniture kinds, hardware, pivots and UVs still require detail review. |
| Household radiators and accessories | heating/accessory source and mechanism owners | Preserve one-pipe steam and service semantics; inspect support, union and vent geometry. |
| Room lights and switches | lighting data / light_switch Blender generator | Retain completed switches; fixture bodies and mounting clearance need complete sweep. |
| Street, entry, passage, shop installations | exterior cell / passage composition | Rear service alley fabricated and joined to the existing sidewalk, with an operating rear door. Include imported architecture and shop props in the sweep; semantic interior index alone does not prove exterior coverage. |
| Bounded courtyard subgrade and alley groundworks | build_orison_ground / build_alley_groundworks / retained-grade authoring map | Fitted source volume, graded original paving, grated boiler well, open catches and hollow construction-stage collector; scoped native and walking checks in groundworks.md. Street-main connection, residual courtyard drainage, full weather/terrain closure remain open. Operating glazing is covered by boiler_window.md. |
| Neighboring city bedding and terrain | build_city_shells / build_city_foundations / build_orison_ground | Northwest row registration overlap removed; seven native undersides fitted around retained sidewalk support. Scoped source, mapping and terrain checks in city_foundations.md; farther boundary, weather and drainage work remains. |
| Neighboring rooftop masts and guy anchors | build_city_masts / immutable authored aerial records / retained city_shells | 25 masts and 75 guys fitted against actual saved roof/bulkhead faces; full plate footprints and clear spans in city_masts.md. Beacon housings, tanks, weather closure and broad material acceptance remain open. |
| Original roof flat-top aerials and dishes | build_city_aerials / 140 immutable components / retained city_shells | 23 flat frames and 16 curved collectors; 636 closed stocks, 39 connected assemblies, 85 supported plates and 108 clear spans. Exact fabricated triangles and local catalogue maps; city_aerials.md. Tanks, beacon housings, weather joints and broad textures remain open. |
| Service-bulkhead weather cover and rainleader | build_roof_service_weathering / source-owned retained roof cap | Sloped metal cover, open gutter/leader and fitted supports; downstream main-roof field and final weather materials remain open; see roof_service_weathering.md. |
| Public light court and skylight weather fit | public stair/court/bridge generators, roof cap generator and public-weather source plan | One-metre eye, fitted guards/supports and six pitched panes installed within the retained core; bounded curb/cricket/gutter/leader fit in light_court.md. Whole-shell readiness, drainage connection and broad materials remain open. |
| Roof-wall base flashing fit | build_roof_base_flashings / retained roof source and blockout | Folded upstands, fitted feet, mitered bulkhead/parapet corners and clear retained door apertures; original walls/deck own buried contact planes. See roof_base_flashings.md. Main-roof field, falls/outlets, sealing and downstream drainage remain open. |
| Operating boiler-well window | build_boiler_window / retained semantic opening / existing household save owner | Fitted six-pane inward sash, hinges, cam and stays; original reveal/well retained. Scoped fit, walking and save proof in boiler_window.md; whole weather and combustion-air capacity remain open. |
| Main-roof field finish | build_roof_membrane / retained seven roof deck owners / catalogue roof_bitumen | Closed four-millimetre native finish within the original slab envelope; metre UVs, three authored PBR maps and bounded partitions. Scoped fit in roof_membrane.md; coordinated falls, outlets and downstream connections remain open. |
| Bodega fixed frontage and lower door field | build_bodega_frontage / original exterior panes and hinged leaf | Three demonstrated upper bands closed by fitted frame and glass; raised lower panel stays inside the original moving box. Scoped native, collision and 57-pose checks in bodega_frontage.md; shop shell, weather capacity and broader materials remain open. |
| Carried radiophone, teletype and lamp | existing service-set owners | Preserve accepted assembly, physical HUD, pointer and debug behavior; no redesign authorized by the inventory. |
| Dream zoo, hero, organelles, sixteen critters | accepted zoo and Blender critter sources | Intentional preservation boundary. Keep accepted assets, behaviors and declared placeholders; regression checks remain required. |

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
