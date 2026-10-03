# V2 fabrication and material coverage

Evidence class: **INERT**

This is an implementation work index, not acceptance evidence. Regenerate
**v2_fabrication_inventory.json** with **tools/inventory_v2_fabrication.py**.
The index names all 200 semantic spaces, 111 doors, 87 openings, 72 windows,
74 envelopes, 85 fixtures, 65 platforms, 12 lift landings, 14 stairs and seven
risers, plus thirteen installed-data files and building-script asset references.
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
| Public/service stairs and landings | stair_ironwork Blender generator and existing collision ramps | Lowest stair foundation gap filled and checked at twelve contacts and eleven walking waypoints. Retain completed ironwork; remaining landing fit sweep pending. |
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
| Bounded courtyard subgrade and alley groundworks | build_orison_ground / build_alley_groundworks / retained-grade authoring map | Fitted source volume, graded original paving, grated boiler well, open catches and hollow construction-stage collector; scoped native and walking checks in groundworks.md. Street-main connection, residual courtyard drainage, operating glazing and full weather/terrain closure remain open. |
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
