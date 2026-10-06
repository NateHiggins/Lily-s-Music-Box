# WHERE THINGS ARE WRITTEN DOWN

Seventy-odd documents live in this repository and another twenty-five in the
world compiler next door. This file is the map. **If you do not know where to
look, look here first.**

## Precedence â€” who wins when two documents disagree

1. **`design/ORISON_BIBLE.md`** â€” the covenant. It says so itself: where any
   other text disagrees, the Bible prevails until amended.
2. **The newest dated ruling** inside the Bible (`Â§VIII` carries them).
3. **This map**, for anything about where documents live.
4. Everything else.

A disagreement you cannot resolve is not a bug to paper over â€” the Bible has a
**Â§VI Disputed Texts** section for exactly that. Add to it rather than picking a
side quietly.

## The six kinds of document

Knowing which kind you are reading tells you how much to trust it.

| Kind | What it means | Where |
|---|---|---|
| **Covenant** | Rules. Binding until amended by the owner. | `design/ORISON_BIBLE.md` and the other `*_BIBLE.md` |
| **Reference** | How a subsystem actually works. Kept current. | `game/docs/`, `art/docs/`, `docs/` |
| **Brief / proposal** | **Not canon until ruled.** Says so at the top. | `design/*_BRIEF.md`, `docs/songbook_brief.md` |
| **Prompt sheet** | Inputs to asset generation. Historical once used. | `design/*_PROMPTS.md`, `*_PROMPT_SHEET.md` |
| **Brief in data shape** | Design written as JSON but read by nobody. Lives in `design/` so it is not mistaken for game data | `design/resident_decor_profiles.json` |
| **Queue** | Open work, one line each. Deleted when done. | `TASKS.md` |
| **Audit** | Evidence with a method and confidence levels. Findings graduate to the queue; the audit stays as the record | `design/AUDIT_*.md` |
| **Build guide** | How to build and verify. Mechanics only. | `HANDOFF.md`, `art/README.md`, `game/README.md` |

## Where to look forâ€¦

| If you want to knowâ€¦ | Read |
|---|---|
| Current room/city geometry and texture review, fitted door motion and honest ledger refresh | `design/V2_BUILDING_SURFACE_FINISH_2026-10-05.md` and `art/blender/building_surface_finish.md` |
| Fitted Keys Cut board, passive machinery, supported display and unchanged copying authority | `art/blender/locksmith_fittings.md` and `design/V2_LOCKSMITH_FITTINGS_2026-10-05.md` |
| Fitted cobbler machines, open paired shoes, fine dust finish and sampled rear approach | `art/blender/cobbler_fittings.md` and `design/V2_COBBLER_FITTINGS_2026-10-05.md` |
| Source-owned News/Cigars papers, glazed stock, pipe bowls, counter and seated proprietor stool | `art/blender/news_fittings.md` and `design/V2_NEWS_CIGARS_FITTINGS_2026-10-05.md` |
| Original Hardware/Paint ordered drawer wall, aisle-facing panels and supported paint bench | `art/blender/hardware_drawers.md` and `design/V2_HARDWARE_DRAWERS_2026-10-05.md` |
| Original Hardware/Paint passive balance, unloaded shaker and supported mixing paddle | `art/blender/hardware_apparatus.md` and `design/V2_HARDWARE_APPARATUS_2026-10-05.md` |
| Original Hardware/Paint bins, open coupling stock, window stand and service counter | `art/blender/hardware_stock.md` |
| Original Hardware/Paint glass stand, seven tools with one empty silhouette, and leaning ladder | `art/blender/hardware_tools.md` and `design/V2_HARDWARE_TOOLS_2026-10-05.md` |
| Three original expensive photographic cameras and their supported window stand | `art/blender/photo_cameras.md` and `design/V2_PHOTO_CAMERA_DISPLAY_2026-10-05.md` |
| Original photographic counter, thin glass display chamber and seated ledger | `art/blender/photo_counter.md` and `design/V2_PHOTO_COUNTER_2026-10-05.md` |
| Original photographic rear shelves and fifteen seated supply cartons | `art/blender/photo_stock.md` and `design/V2_PHOTO_STOCK_2026-10-05.md` |
| Three original second-hand photographic enlargers and their supported high shelf | `art/blender/photo_enlargers.md` and `design/V2_PHOTO_ENLARGERS_2026-10-05.md` |
| Original photographic trays, tanks, dryer, folded tripods and supported flash tins | `art/blender/photo_process.md` and `design/V2_PHOTO_PROCESS_2026-10-05.md` |
| Seven source-owned unclaimed photographic prints, seated rail and local generated image content | `art/blender/photo_portraits.md` and `design/V2_PHOTO_PORTRAITS_2026-10-05.md` |
| Source-owned bodega stock, display case, icebox, practicals and preserved depletion | `art/blender/bodega_fittings.md` |
| Source-fitted Orison front entrance, glazed oak leaf, original marquee and seated neon blade | `art/blender/front_facade.md` |
| Verified front-door routes, arrival correction, ledger refresh and retained street views | `design/V2_FRONT_FACADE_PROGRESS_2026-10-05.md` |
| Controlled front-faÃ§ade air finish, current key contract and remaining roof lighting check | `design/V2_FRONT_FACADE_AIR_FINISH_2026-10-05.md` |
| Fitted steel beneath the front-court roof and calibrated exterior soffit finish | `art/blender/front_court_roof.md` |
| Verified front-court roof contacts, strict landing envelopes and current ledger provenance | `design/V2_FRONT_COURT_ROOF_PROGRESS_2026-10-05.md` |
| Equal-output lamp comparison, waking V2 surface detail balance and current scoped contract | `design/V2_LAMP_SURFACE_BALANCE_2026-10-05.md` |
| Source-fitted bar gallery, original atlas, seated picture attachments and retained observations | `art/blender/bar_gallery.md` |
| Fitted Harukiya curtain folds, cloth-covered fascia and wall-supported rail | `art/blender/bar_stage.md` |
| Quiet trowelled concrete/slab maps, physical height calibration and retained city geometry | `art/blender/concrete_trowelled.md` |
| Source-owned public light court, fitted stairs/supports, pitched skylight and bounded roof weathering | `art/blender/light_court.md` |
| Fitted roof-wall base flashings, retained door apertures and single-owner deck/wall contacts | `art/blender/roof_base_flashings.md` |
| Fitted roof field, closed native finish, catalogue PBR maps and retained flat datum | `art/blender/roof_membrane.md` |
| Neighboring city parapet corner unions, original source stocks and local metre charts | `art/blender/city_closure.md` |
| October 1 composed city/bar batch, bound verification and next service connections | `design/V2_CITY_COMPOSITION_HANDOFF_2026-10-01.md` and `design/V2_CITY_PRODUCTION_MAP_2026-10-01.md` |
| Retained bar restroom clearance, working sink input and pool inspection fit | `art/blender/bar_service_access.md` |
| Supported bodega receiving room, fitted delivery leaf and sales-aisle route | `art/blender/bodega_receiving.md` |
| Fitted bodega display frame, upper lights and original hinged-leaf infill | `art/blender/bodega_frontage.md` |
| Resident original keys, permission at Keys Cut and saved hinged-door locks | `art/blender/resident_keys.md` |
| Fitted front public slab, retained room/shop/shed floor ownership and paving validation | `art/blender/front_pavement.md` |
| Bounded Orison subgrade, graded alley, boiler well and construction-stage drain collector | `art/blender/groundworks.md` |
| Operating boiler-well window, fitted hardware, physical panes and household setting | `art/blender/boiler_window.md` |
| Registered neighboring foundations, retained-slab fit and expanded terrain joins | `art/blender/city_foundations.md` |
| All ground-level city bases, southwest assembly separation and finite distant grade | `art/blender/city_grade.md` |
| Source-owned rooftop masts, supported guy anchors and exact city bearing checks | `art/blender/city_masts.md` |
| Original roof aerial frames, curved collectors and supported downlead terminals | `art/blender/city_aerials.md` |
| Original red mast-head beacon housings | `art/blender/city_beacons.md` |
| Calibrated local bronze, galvanized roof hardware and red lacquer | `art/blender/city_hardware_finishes.md` |
| Original neighbouring roof tanks, fitted hardware clearance and calibrated stave finish | `art/blender/city_tanks.md` |
| Common surface charts for fixed city roof hardware, with exact unchanged-geometry comparison | `art/blender/city_hardware_uvs.md` |
| Sloped service-bulkhead cover, open gutter outlet and fitted external rainleader | `art/blender/roof_service_weathering.md` |
| All eleven arcade thresholds, source parked leaves and closed-hours survey | `art/blender/arcade_thresholds.md` |
| Existing ventilation branch hangers, ceiling contact and mapped steel fittings | `art/blender/duct_supports.md` |
| Radiator wall-tie seating, slotted plates and retained service mechanisms | `art/blender/radiator_wall_ties.md` |
| Hollow ventilation sheets, seam airways and fitted fan slab/curb throats | `art/blender/ventilation_throats.md` |
| Ventilation storey slab ports, shared sleeve linings and upper branch clearance | `art/blender/ventilation_slab_ports.md` |
| Ventilation wall/chase/masonry ports, fitted steel linings and full-bore inspection | `art/blender/ventilation_fabric_ports.md` |
| Independent bodega lighting intake, supported conduit and fitted wall sleeves | `art/blender/bodega_power.md` |
| V2 city architecture/infrastructure continuation by location and transition | `design/V2_CITYSCAPE_CONTINUATION_PROMPT_2026-10-01.md` |
| Blender exterior masonry, deeper reveals and narrow light-slot preservation | `art/blender/exterior_masonry.md` |
| September 29 boiler fixes, verified commits, full-pass exceptions and continuation | `design/V2_FABRICATION_HANDOFF_2026-09-29.md` |
| Full V2 geometry work index, coverage decisions and pending material families | `art/blender/v2_fabrication_coverage.md` |
| Original shop chairs, chapel benches and soda-counter stools | `art/blender/shop_seating.md` |
| Wrapped hand-laundry parcels, hung shirts, supported rail and ironing furniture | `art/blender/laundry_fittings.md` |
| Open laundry tubs, opposed-roll wringer, flat irons and supported drying racks | `art/blender/laundry_apparatus.md` |
| Fitted Harukiya pool frame, six open pockets and five original balls | `art/blender/bar_pool.md` |
| Source-fitted Harukiya light mounts, inward sconces and canopy stays | `art/blender/bar_fixture_mounts.md` |
| Source-fitted Harukiya ceiling-pipe split collars, bolts and bearing plates | `art/blender/bar_pipe_supports.md` |
| Local smoke-film ceiling finish with exact original faces and physical ownership | `art/blender/bar_ceiling_finish.md` |
| All 200 production room overviews, capture method and concrete follow-ups | `art/blender/v2_space_sweep.md` |
| Rear service door, receiving approach and continuous street-connected alley | `art/blender/service_alley.md` |
| Boiler instrument mounts, guards and moving-handle clearance | `art/blender/boiler_instruments.md` |
| Boiler steam header, exposed equalizer, discharge and fitted supports | `art/blender/boiler_pipework.md` |
| Retained steam inlet wall/chase sleeves, fitted plates and opened internal tee | `art/blender/boiler_inlet.md` |
| Source-bound one-pipe distribution, structural ports and open support/access construction | `art/blender/heating_distribution.md` |
| Roof slab-edge support, retained parapet bearing and open shell-readiness findings | `art/blender/roof_edge_support.md` |
| Roof bulkhead upper closures, retained ceiling faces and physical wall contacts | `art/blender/roof_bulkhead_caps.md` |
| Source-derived foundation stems, basement footings and retained occupied volumes | `art/blender/orison_foundations.md` |
| Uncovered ceiling upper closures and single-owner floor, landing and alley interfaces | `art/blender/ceiling_top_closures.md` |
| Fitted frame beneath the shifted ground stair-core wall, retained basement landings and west passage | `art/blender/ground_core_transfer.md` |
| Fitted first-upper A rear-wing beams, posts, storage seats and independent external footings | `art/blender/rear_wing_a_support.md` |
| Fitted first-upper C rear-wing beams, posts, retained basement roof seats and external footings | `art/blender/rear_wing_c_support.md` |
| First-upper hall brackets, fitted beam seats and retained watch-wall toe ledger | `art/blender/first_upper_hall_seats.md` |
| Repeated upper-core wall transfers and fitted C west toe against its retained inner wall | `art/blender/upper_wall_seats.md` |
| Remaining F03â€“F05 wall transfers, connected T frames and retained wet-stack/light-slot boundaries | `art/blender/remaining_upper_transfers.md` |
| Exposed landing soffits, retained slab bodies and single-owner ceiling interfaces | `art/blender/landing_soffits.md` |
| Exposed room-slab soffits, retained apertures and roof-wall contact observations | `art/blender/room_slab_soffits.md` |
| Fabricated bedding, preserved frames and fitted collision on fourteen beds | `art/blender/bedding.md` |
| Lobby waiting benches and fixed parcel shelving | `art/blender/public_furnishings.md` |
| Basement stair foundation and Blender coal pile | `art/blender/basement_fabrication.md` |
| Blender common-room reading table, chairs, bookcases and walking clearance | `art/blender/reading_furniture.md` |
| Blender boiler breeching, open gores, collar seating and bend collision | `art/blender/breeching.md` |
| Blender boiler casing, recessed firebox/ash pit, grate and matching fixed collision | `art/blender/boiler_body.md` |
| Boiler firing/ash door outward swing and matching moving plate collision | `art/blender/boiler_door_swing.md` |
| Blender room millwork, wainscot, door casings, service frames and brass lift reveals | `art/blender/millwork_profile.md` |
| Blender lift call plates, seated wall mounting and mechanical button caps | `art/blender/lift_call_plate.md` |
| Blender lift handrails, wall-mounted supports and fasteners | `art/blender/lift_handrails.md` |
| Fitted Blender cab panels, control clearances and rear enamel field | `art/blender/lift_joinery.md` |
| Fitted Blender lift ceiling lamp, opal bowl and retaining hardware | `art/blender/lift_ceiling_lamp.md` |
| Blender passive bathroom grilles, folded louvers and plenum seating | `art/blender/vent_register.md` |
| Blender shared roof ventilators, motor housings and live rotor/shutter pivots | `art/blender/roof_ventilator.md` |
| Blender bonded chimney masonry, mortar joints and open stone coping | `art/blender/chimney_crown.md` |
| Blender roof tank, timber staves, binding hardware and retained maintenance | `art/blender/house_tank.md` |
| Blender roof coping, mitered corners, weather slopes and drip grooves | `art/blender/roof_coping.md` |
| Architecture batch handoff, validation locations and remaining work | `design/V2_ARCHITECTURE_HANDOFF_2026-09-27.md` |
| Blender V2 mortise knobs, fitted backplates and clear lock stiles | `art/blender/door_knob_set.md` |
| Blender butt hinges, fixed/moving halves and opposite-swing axis alignment | `art/blender/door_butt_hinge.md` |
| Complete Blender V2 window frames, sash fields and projecting sills | `art/blender/window_joinery.md` |
| Blender lift mirror surround and shared live reflection | `art/blender/lift_mirror.md` |
| Blender lift floor dial, ceiling mounts and height-driven needle | `art/blender/lift_indicator.md` |
| Blender cab control board, collars and working button presentation | `art/blender/lift_cab_controls.md` |
| Blender sliding lift leaves, clear vision apertures and retained shaft barriers | `art/blender/lift_panels.md` |
| Articulated Blender car gate, fixed-thickness links and landing-door separation | `art/blender/lift_gate.md` |
| Blender enamel floor signs, mounting spacers and readable runtime lettering | `art/blender/wayfinding_plate.md` |
| Blender stair rails, tread stringers and landing support geometry | `art/blender/stair_ironwork.md` |
| Honed stair marble, independent physical microrelief and real semantic shader binding | `art/blender/stair_honed.md` |
| Editable Blender light switches, moving toggles and preserved V2 circuit ownership | `art/blender/light_switch.md` |
| How to test all sixteen critters and live encroachment in Mina's actual V2 apartment | `game/docs/mina_debug_infestation.md` |
| Which checkout to use and where retired worktrees were preserved | `design/WORKTREE_CONSOLIDATION_2026-09-21.md` |
| Household inspection, preventative care, tips and low-pressure rent | `game/docs/caretaking_and_economy.md` and `design/ORISON_V2_CARE_ECONOMY_PROGRESS_2026-09-26.md` |
| Floor plates in both V2 stair cores and lamp-readable lettering | `design/ORISON_V2_WAYFINDING_PROGRESS_2026-09-26.md` |
| Connected boiler flue, roof chimney and saved water-column service | `design/ORISON_V2_BOILER_FLUE_PROGRESS_2026-09-26.md` |
| Wider sixteen-metre service light and physical lamp aim toward nearby controls | `design/ORISON_V2_LAMP_COVERAGE_PROGRESS_2026-09-26.md` |
| Grounded V2 boiler, clear firing aisle, physical door/damper controls and water-column route | `design/ORISON_V2_BOILER_ACCESS_PROGRESS_2026-09-26.md` |
| Continuous V2 opening-shift regression, natural dream onset and conversation field-copy readability | `design/ORISON_V2_CONTINUOUS_SHIFT_PROGRESS_2026-09-26.md` |
| Completed V2 fuse and roof-tank repairs across saves and building reconstruction | `design/ORISON_V2_SERVICE_SAVE_PROGRESS_2026-09-26.md` |
| V2 lift ropes, deflectors, counterweight, guide channels and guarded roof penetrations | `design/ORISON_V2_LIFT_SUSPENSION_PROGRESS_2026-09-26.md` |
| V2 four physical ventilation stacks, bathroom branches and geographic motor ownership | `design/ORISON_V2_SHARED_DUCTWORK_PROGRESS_2026-09-26.md` |
| V2 street coal cover, gravity delivery chute and raised basement aperture | `design/ORISON_V2_COAL_DELIVERY_PROGRESS_2026-09-26.md` |
| Guarded roof lift machinery driven by the existing passenger car | `design/ORISON_V2_LIFT_DRIVE_PROGRESS_2026-09-26.md` |
| Basement electrical, workshop, coal, storage and lower service-stair construction | `design/ORISON_V2_BASEMENT_PROGRESS_2026-09-26.md` |
| Occupied-home radiators, brighter service light and zoo optical-source ownership | `design/ORISON_V2_HEATING_AND_PRIMARY_LIGHT_PROGRESS_2026-09-25.md` |
| How to launch the V2 default, use V1 rollback, and walk into or inspect the Dream zoo | `game/docs/v2_launch.md` |
| V2 remaining homes, passenger lift, shared roof ventilation and scoped route checks | `design/ORISON_V2_HOMES_AND_LIFT_PROGRESS_2026-09-25.md` |
| Spatial-only evidence for the six added homes and staff restroom | `design/ORISON_V2_COMPLETION_INTERIORS_CHECKPOINT_2026-09-25.md` |
| The landed V2 roof-access shell, Mina's door passages, and remaining architecture/lighting work | `design/ORISON_V2_ROOF_AND_RESIDENT_PROGRESS_2026-09-25.md` |
| The V2 roof water tank, production maintenance approach and scoped validation | `design/ORISON_V2_ROOF_PLANT_PROGRESS_2026-09-25.md` |
| What is true about this world | `design/ORISON_BIBLE.md` |
| How to work in this repository: git in a shared tree, the Godot lane, what counts as proof | `AGENTS.md` (Claude reads it through `CLAUDE.md`) |
| Whether a change made anything worse, and whether a branch is mergeable | `tools/PIPELINE_TOOLS.md`: gate board, run receipts, candidate verifier |
| Where the v2 rebuild stands and what the ledger will accept as evidence | `python tools/audit_orison_v2_completeness.py`, `design/ORISON_V2_COMPLETENESS_LEDGER_GUIDE.md`, and the current snapshot in `design/orison_v2_completeness_reports/ORISON_V2_COMPLETENESS_LEDGER.md` |
| Which standing ruling a brief or review cites as RUL-nnn | `design/RULINGS.json` *(an index with sources; the Bible and the cited source win)* |
| How V2 household authoring metadata becomes shipped data and test proofs | `art/data/orison_v2/AUTHORING_PROJECTIONS.md`, then `tools/build_v2_authoring_projection.py` |
| How each prop compares with the real object, and which to rebuild first | `design/PROP_MODELING_TEXTURING_BRIEF_2026-09-18.md`, then `tools/prop_reference/README.md` |
| What the game loop is and which milestone comes next | `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`, then `design/next_session_plan.md` |
| The final playable map: three zones, the Passage, measured perf baseline | `design/FINAL_MAP_REDESIGN_BRIEF.md` |
| Why an object looks forty years early | Bible Â§VIII.2, the Rule of Signal |
| What is open right now, and who has it | `TASKS.md` |
| Whether a system is actually used | `design/AUDIT_UNUSED_SYSTEMS_REPORT.md` |
| How to build the layout â†’ Blender â†’ Godot chain | `HANDOFF.md` |
| How to run a test, and which ones exist | `HANDOFF.md`, then `game/tests/` |
| What phase the art is in | `art/docs/photoreal_target.md` |
| Who lives in a flat and what their wound is | Bible Â§IV, then `game/docs/resident_character_cast.md` |
| How a prop should be built | `design/PROP_ART_BRIEF.md`, `design/PROP_REFERENCE_NOTES.md` |
| What a prop *does* | `design/PROP_ACTIVITIES.md` |
| Which foreground props and set heroes receive E, inspection, refusal or stay ambient | `design/PROP_SET_INTERACTION_MATRIX.md` |
| Where service-wire object facts and card sources live | `design/PROP_TRIVIA_RESEARCH.md`, then `game/data/prop_service_wire.json` |
| How the complete maintenance/case/dream-request loop is wired | `game/docs/core_loop.md` |
| How the bar works | `docs/harukiya_reference_notes.md` |
| How the karaoke/song system works | `docs/songbook_brief.md` |
| The machines in the bar | `game/docs/arcade_cabinets.md`, ruled in Bible Â§VIII.5.g |
| The proposed basement studio | `design/ORISON_STUDIO_BRIEF.md` *(proposal)* |
| The narcolepsy dream / the maze | `design/ORISON_MAZE_BRIEF.md` *(ruled production design)*, then `game/docs/dream_boundary.md` for the landed scene/save seam and `game/docs/dream_onset.md` for the protected onset owner |
| The ruled dream flora/fauna ecosystem and landed FA1â€“FA2 slices | `design/DREAM_FAUNA_BRIEF.md`, then `art/renders/dream_fauna_f1/README.md` and `art/renders/dream_fauna_fa2/README.md` |
| How the sixteen warehouse critters will be rebuilt from the biology dossier with continuous Blender anatomy and preserved behaviors | `design/astra/DREAM_CRITTER_BLENDER_REBUILD_2026-09-19_BRIEF.md`, with `design/astra/DREAM_CRITTER_REFERENCE_MAP_2026-09-19.json` *(INERT analysis, implementation proposal and reference map)* |
| Editable Blender sources, native warehouse gallery and completed verification for all sixteen critters | `design/astra/DREAM_CRITTER_BLENDER_REBUILD_2026-09-19.md` *(INERT implementation report)* |
| Recovered hero source, live organelle warehouse station and reserved zoo bays | `design/astra/DREAM_ZOO_WAREHOUSE_RESCUE_2026-09-19.md` *(INERT debug implementation and source-recovery report)* |
| The six case-specific dream surface incarnations and AI-plate boundary | `design/SIX_INCARNATIONS.md` *(owner-approved; shared data seam landed)* |
| Image references for Dream anatomy: real specimens, period plates, motion and artistic interpretations, with licences | `design/DREAM_BIOLOGY_REFERENCE_DOSSIER_2026-09-19.md` *(reference, not canon)* |
| Which real specimen each landed Dream organ is grown from, at what scale and era, and what the being misreads about it | `design/DREAM_TEMPORAL_SPECIMEN_LEDGER.md` *(audit)*, over the doctrine it classifies: `design/DREAM_TEMPORAL_BIOLOGY.md`, `design/DREAM_ORGANELLE_COMMUNICATION.md`, `design/DREAM_ECOLOGY_ARCHITECTURE.md` |
| Ruled waking-world vermin, birds and invasive flora | `design/ORISON_COMMENSALS_BRIEF.md` *(C1 landed; later breadth gated)* |
| The no-screen radio and attached work light in the player's hand | `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md`, `game/docs/service_set.md` *(ruled and landed)* |
| The HUD, telegram paper, type hierarchy and institutional world text | Bible Â§VIII.5.k, then `game/docs/telegram_style.md` *(ruled and landed)* |
| How sound moves through the building | `game/data/acoustic_graph.json`, `game/docs/sanity_system.md` |
| Why a texture tiles badly | `art/tools/ingest_material_sources.py`, and the compiler's `docs/provider-api.md` |
| What clothes people wear | `design/ORISON_WARDROBE_BIBLE.md` |
| What appliances exist | `design/ORISON_APPLIANCE_BIBLE.md` |
| How a household decorates | `design/resident_decor_profiles.json` *(brief, not loaded)* |

## The two repositories

| | |
|---|---|
| `C:\PleaseRemainOnTheLine` | this one. The game, the art pipeline, the design canon. Git-backed. |
| `C:\FPSengine01` | the **Semantic World Compiler**, which builds the machines in the bar. |

The compiler is a separate project that produces a build output consumed here
(`game/assets/arcade/`). It shares a *format* with this repo, not code. Its own
map is its `README.md`, and its cross-project contract is
`docs/orison-arcade.md`.

> **`C:\FPSengine01` is not a git repository.** Everything in it is unversioned
> files on disk. This is tracked as **H2** in `TASKS.md` and is the largest
> single risk on that list.

## Two names for the same thing

`arcade` is the **subsystem**; the **signal parlour** is the fiction. The code
says `arcade_*` throughout because that is the lineage it grew from; the world
says receivers and programme cards because the Bible rules it so (Â§VIII.5.g).
They agree. See the note in `game/docs/arcade_cabinets.md`.

## Three "status" documents, three jobs

They have collided before. They do not overlap:

`design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md` is not a fourth status ledger.
It defines product direction, milestone order and acceptance gates; it changes
only when the product plan changes.

- **`art/docs/photoreal_target.md`** â€” the eight-phase art roadmap and its
  per-phase assessment. Long-lived.
- **`TASKS.md`** â€” the live queue. One line per open task, anyone may add,
  deleted when done.
- **`HANDOFF.md`** â€” how to build and verify, and nothing else.

Do not duplicate status between them. Two copies of a status always disagree,
and the reader has no way to tell which one is lying.

## Adding a document

- **A rule** goes in the Bible as a dated ruling, not in a new file. A
  standing process ruling may also be indexed in `design/RULINGS.json` with
  its source, so reviews can cite it by id; the index never replaces the
  Bible.
- **A design document** states its class in an `Evidence class:` header in
  its first 30 lines; run `python tools/lint_design_doc.py <path>` before
  committing it (`AGENTS.md`).
- **A proposal** goes in `design/` ending `_BRIEF.md`, and says at the top that
  it is not canon.
- **A task** goes in `TASKS.md` as one line. If it needs a paragraph, it needs a
  brief.
- **A subsystem explanation** goes in `game/docs/` or `art/docs/` next to the
  thing it explains.
- **Then add it to the table above**, or nobody will find it.

## Known gaps in the documentation itself

- The eleven shops, the archived phone OS and the case network have reference
  docs of uneven depth. The carried-device migration is recorded in
  `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md` and `game/docs/service_set.md`;
  the old phone documents are historical inputs, not production authority.
- `docs/harukiya_reference_notes.md` owes an asset manifest and an interaction
  manifest, deliberately unwritten so far.
- Bible Â§VI holds eight disputed texts awaiting a ruling. They are disputes, not
  oversights.
- An audit is not a queue. `AUDIT_UNUSED_SYSTEMS_REPORT.md` carries the evidence
  and its findings live in `TASKS.md` Â§U; if the two ever disagree, the audit is
  the older document and the queue is what is being worked.
