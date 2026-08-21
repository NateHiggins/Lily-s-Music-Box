extends Node3D
## Assembles Orison Apartments: instances per-floor glTF scenes, spawns
## functional props from the shared layout markers, places the player and
## elevator, and manages coarse level-of-interest floor visibility (a
## streaming stand-in until a real HLOD pass lands).
##
## There is deliberately no occlusion-culling pass. One existed, built from
## the same wall data as everything else, emitting a box for every solid
## pier, spandrel and header. The boxes were correct and that was the
## problem: each sat exactly coincident with the masonry it described, so
## the facade occluded itself. Headers and spandrels culled their own
## brick, and the street elevation showed dark bands in a grid matching
## the floors and windows - with the window glazing among the things that
## vanished. Removed 2026-08-05 rather than nudged, because an occluder
## offset far enough not to cull its own wall is far enough to pop the
## corridor beyond a doorway instead.

const FLOOR_SCENES := {
	"B1": "res://assets/building/floor_b1.gltf",
	"F01": "res://assets/building/floor_01.gltf",
	"F02": "res://assets/building/floor_02.gltf",
	"F03": "res://assets/building/floor_03.gltf",
	"F04": "res://assets/building/floor_04.gltf",
	"F05": "res://assets/building/floor_05.gltf",
	"F06": "res://assets/building/floor_06.gltf",
	"ROOF": "res://assets/building/roof.gltf",
}
## WHERE THE BUILDING STOPS, for the rule that decides whether you are
## looking AT it or standing IN it.
##
## This test used to borrow LightRig's 15.2 x 11.2 street-core envelope, and
## the owner found the hole that left: the shell is 14.05 x 10.05, so a band
## of pavement more than a metre wide ran right along every facade in which
## the eye was neither `outside` nor on any interior storey. The rule fell
## through to the active-storey window `absf(p.y - z) < 1.75`, which keeps
## the floor at your feet and culls every floor above it — "when i stand
## next to the building the top floors disapear". You could not see the
## building you were leaning on.
##
## 150 mm clear of the masonry is enough margin to keep a doorway from
## toggling the stack, which is all the old metre was ever buying, and it is
## narrow enough that nowhere a body can stand outside the shell reads as
## inside it. The rear porch decks at |z| 10.05..11.35 sat inside the old
## band too, so a fire escape hung off a building that was not there.
const OUTSIDE_HALF_X := 14.2
const OUTSIDE_HALF_Z := 10.2
## Floor batches that ARE the building seen from outdoors, and so can never be
## classed as enclosed content by the street-core sweep.
##
## Matched as SUBSTRINGS of the batch name, not as whole names, and that is
## deliberate. Giving the slats their own material — which W-JOINERY asks for,
## because a rolled aluminium slat is not skirting-board paint — moved them out
## of the floor-wide `furniture_trim` batch, whose extent reached z 37.57 into
## the Passage and so had always failed the containment test by accident. The
## moment they had an honest extent of their own they became enclosed content
## and vanished from the street: the fix for one half of the owner's report
## created the other half. An exact-name list would have to be extended every
## time a window part is given a material, and the day it is not is the day the
## windows lose something again.
const ENVELOPE_BATCHES := ["glazing", "stone_trim", "sash", "blind"]
const PROP_SCRIPTS := {
	"radiator": preload("res://scripts/props/radiator_prop.gd"),
	"lamp": preload("res://scripts/props/lamp_prop.gd"),
	"washer": preload("res://scripts/props/washer_prop.gd"),
	"laundry_airer": preload("res://scripts/props/laundry_airer_prop.gd"),
	"boiler": preload("res://scripts/props/boiler_prop.gd"),
	"toaster": preload("res://scripts/props/toaster_prop.gd"),
	"fridge": preload("res://scripts/props/fridge_prop.gd"),
	"stove": preload("res://scripts/props/stove_prop.gd"),
	"monitor": preload("res://scripts/props/monitor_prop.gd"),
	"signal_terminal": preload("res://scripts/props/signal_terminal_prop.gd"),
	"boxfan": preload("res://scripts/props/boxfan_prop.gd"),
	"door_anomaly": preload("res://scripts/props/door_anomaly_prop.gd"),
	"case_door": preload("res://scripts/props/case_door_prop.gd"),
	"speaker": preload("res://scripts/props/speaker_prop.gd"),
	"flue_breast": preload("res://scripts/props/flue_breast_prop.gd"),
	"porch_deck": preload("res://scripts/props/porch_deck_prop.gd"),
	"kettle": preload("res://scripts/props/kettle_prop.gd"),
	"wall_clock": preload("res://scripts/props/clock_prop.gd"),
	"vantry_point": preload("res://scripts/props/vantry_point_prop.gd"),
	"exhaust_fan": preload("res://scripts/props/exhaust_fan_prop.gd"),
	"ceiling_light": preload("res://scripts/props/ceiling_light_prop.gd"),
	"pendant_shade": preload("res://scripts/props/light_fixture_prop.gd"),
	"flush_dome": preload("res://scripts/props/light_fixture_prop.gd"),
	"sconce_globe": preload("res://scripts/props/light_fixture_prop.gd"),
	"kitchen_linear": preload("res://scripts/props/light_fixture_prop.gd"),
	"cage_bulb": preload("res://scripts/props/light_fixture_prop.gd"),
	"chandelier": preload("res://scripts/props/light_fixture_prop.gd"),
	"eye_pendant": preload("res://scripts/props/light_fixture_prop.gd"),
	# Spawned from `furniture`, not from a marker, so nothing here will ever
	# instantiate it for the building - it is registered so the inspection shed
	# can show the four chassis. See arcade_row.gd for how the real ones arrive.
	"arcade_cabinet": preload("res://scripts/props/arcade_cabinet_prop.gd"),
	"neon_sign": preload("res://scripts/props/neon_sign_prop.gd"),
	"bodega_signage": preload("res://scripts/props/bodega_signage_prop.gd"),
	"bar_signage": preload("res://scripts/props/harukiya_signage_prop.gd"),
	"shop_sign": preload("res://scripts/props/shop_sign_prop.gd"),
	"sink": preload("res://scripts/props/tap_prop.gd"),
	"shower": preload("res://scripts/props/tap_prop.gd"),
	"mirror": preload("res://scripts/props/medicine_cabinet_prop.gd"),
	"street_lamp": preload("res://scripts/props/light_fixture_prop.gd"),
	"songbook_terminal": preload(
			"res://scripts/props/songbook_terminal_prop.gd"),
	"darts": preload("res://scripts/props/darts_prop.gd"),
	"point_ball": preload("res://scripts/props/point_ball_prop.gd"),
	# Architectural hardware has no layout marker, but the warehouse registry
	# is a catalog of things worth judging, not only things marker-spawned.
	"mail_bank": preload("res://scripts/props/mail_bank_prop.gd"),
	# Plain Node3D actors can opt into warehouse inspection without pretending
	# to be networked FunctionalProps. Runtime door markers are still handled
	# by the dedicated branch below, so this is inspection registration only.
	"door": preload("res://scripts/props/door_prop.gd"),
	"landmark_entry": preload("res://scripts/props/landmark_entry_door.gd"),
	"bookshelf": preload("res://scripts/props/bookshelf_prop.gd"),
}
const HEAT_BALANCE_SCRIPT := preload("res://scripts/props/heat_balance.gd")
const BOILER_TEND_SCRIPT := preload("res://scripts/props/boiler_tend.gd")
const PASSAGE_FINISH_SCRIPT := preload(
		"res://scripts/building/passage_finish_pass.gd")
const FURNITURE_INTERACTION_SCRIPT := preload(
		"res://scripts/building/furniture_interaction_pass.gd")
const NPC_RESIDENTS := [
	{"unit": "1A", "name": "Evelyn Marsh", "sprite": "evelyn_marsh"},
	{"unit": "1D", "name": "Teresa Vale", "sprite": "teresa_vale"},
	{"unit": "2A", "name": "Mina Vale", "sprite": "mina_vale"},
	{"unit": "2B", "name": "Lena Ortiz", "sprite": "lena_ortiz"},
	{"unit": "2C", "name": "Juno Kells", "sprite": "juno_kells"},
	{"unit": "3A", "name": "Malcolm Reed", "sprite": "malcolm_reed"},
	{"unit": "3B", "name": "Omar Bell", "sprite": "omar_bell"},
	{"unit": "3D", "name": "Rhea Sato", "sprite": "rhea_sato"},
	{"unit": "4A", "name": "Peter Wren", "sprite": "peter_wren"},
	{"unit": "4C", "name": "Cam Ortiz", "sprite": "cam_ortiz", "slot": -1},
	{"unit": "4C", "name": "Noel Price", "sprite": "noel_price", "slot": 1},
	{"unit": "4D", "name": "Transient Guests", "sprite": "transient_guests"},
	{"unit": "5A", "name": "Nadia Quell", "sprite": "nadia_quell"},
	{"unit": "5B", "name": "Cal Dwyer", "sprite": "cal_dwyer"},
	{"unit": "5C", "name": "Iris Bell", "sprite": "iris_bell"},
	{"unit": "6A", "name": "Sacha Reed", "sprite": "sacha_reed"},
	{"unit": "6B", "name": "Jonah Price", "sprite": "jonah_price"},
	{"unit": "6C", "name": "Mae Kessler", "sprite": "mae_kessler"},
]
## The textured hero meshes are now the active cast. Sprite sheets remain as
## an explicit missing-asset fallback, not as the normal spawn path.
const USE_RIGGED_RESIDENTS := true

var layout: Dictionary = {}
var player: PlayerController
var elevator: OrisonElevator
var call_interface: CallInterface
var light_rig: LightRig
var virus_director: VirusSoundDirector
var floor_nodes: Dictionary = {}
const FloorCoveragePassScript := preload("res://scripts/building/floor_coverage_pass.gd")
var floor_coverage: RefCounted
## The Passage shell remains part of F01's exterior proxy, but its eleven
## fitted shop batches are a separate render zone.  Imported glTF meshes and
## marker-built actors have different owners, so both are indexed explicitly.
## Visibility changes only at the portal instead of rewriting hundreds of
## nodes every physics tick.
var passage_interior_nodes: Array[GeometryInstance3D] = []
var passage_shell_nodes: Array[GeometryInstance3D] = []
## F01 also contains the original building and the entire street/site export.
## From inside PASSAGE those are a foreign zone, not a 220 x 148 m proxy.
## The shallow `passage_proxy` entrance remains always eligible and is omitted
## from both lists deliberately.
var passage_foreign_f01_nodes: Array[GeometryInstance3D] = []
## Late-built F01 draws, classified by measured position against the ruled
## envelope because they did not exist when the name index ran. Kept apart
## from the early lists because their toggle semantics differ: another
## system may legitimately toggle these (window glow sleeps quads, cabinets
## stage their boot), so the zone gate SAVES their visibility when it hides
## them and RESTORES that saved state on the way back — it never forces
## true onto geometry somebody else turned off.
var passage_late_interior_nodes: Array[GeometryInstance3D] = []
var passage_late_foreign_nodes: Array[GeometryInstance3D] = []
## Foreign-zone lights, gated like foreign geometry: a hidden zone's lamp
## still re-renders every caster in its radius into shadow maps nobody
## can see. The lobby lamps alone carried ~600 casters each at northbound.
var passage_foreign_lights: Array[Light3D] = []
var passage_light_saved: Dictionary = {}
## Shared authored-layer table for every spatial render gate. Passage was the
## first consumer, hence the historical name; STREET now composes a second
## blocker over many of the same F01 nodes. `_zone_layer_blocks` prevents one
## gate from restoring a node while the other still owns it as hidden.
var passage_late_saved: Dictionary = {}
var _zone_layer_blocks: Dictionary = {}
## Explicitly shared F01 draws: classified, never toggled by the zone gate.
## Deliberate, per node, for one of three reasons — it straddles the portal
## (the site-spanning vantry batch), it moves under another system's
## authority (residents, whose schedules legitimately reach Passage
## anchors), or a registered FunctionalProp/DoorProp ancestor already
## zone-gates it. Exists so the ownership audit can insist on ZERO
## unclassified draws without forcing a wrong static answer onto a dynamic
## node.
var passage_shared_f01_nodes: Array[GeometryInstance3D] = []
var passage_runtime_nodes: Array[Node3D] = []
var _passage_light_pass: Node3D
var passage_visible := true
var passage_finish: Node3D
## Low STREET never has a legal sightline to geometry wholly enclosed by the
## F01 shell. These nodes are indexed spatially, while facade-touching compound
## owners, the landmark entry, WindowGlow and moving residents remain eligible.
var street_core_nodes: Array[GeometryInstance3D] = []
var street_core_visible := true
## Same-build control for T7d. The Harukiya is a canonical below-grade F01
## wing south of the central Orison core; its complete ruled mass is known from
## FINAL_MAP_REDESIGN_BRIEF §5. Production streams its enclosed contents with
## the core, while this control restores only that wing for A/B measurement.
var _street_harukiya_gate_enabled := \
		OS.get_environment("PERF_STREET_HARUKIYA_GEOMETRY_ON") != "1"
## Marker-built props deliberately remain direct children: several directors
## discover them through that stable ownership boundary.  They still need to
## ride the same coarse visibility gate as the imported floor, though.  Before
## this index existed all 471 props (and their shadow geometry) rendered on
## every storey even while the floor around them was hidden.
var functional_props_by_floor: Dictionary = {}
## Doors intentionally remain plain Node3D actors: making 120 pieces of
## architectural joinery FunctionalProps would subscribe every hinge to the
## possession network.  They still need exactly the same storey visibility
## ownership, otherwise a closed F06 door submits geometry and shadows while
## the player is in F02.
var doors_by_floor: Dictionary = {}
var window_glow: OrisonWindowGlow
var door_glow: OrisonDoorGlow
var broadcast: BroadcastDirector
var arcade_row: ArcadeRow
var resident_routines: ResidentRoutines
var switch_system: SwitchSystem
var commensals: CommensalDirector
var moon_fill: MoonFill
var street_traffic: StreetTraffic
var shots: ShotCapture
var heightmaps: HeightmapPass
var warehouse: PropWarehouse
var touch: TouchControls
var service_set_carrier: ServiceSetCarrier
var weather: WeatherFX
var day_night_director: DayNightDirector
var mina_manifestation: MinaCaptionManifestation
var mina_gameplay: MinaCaseGameplay
var portal_rule_display: PortalRuleDisplay
var environment_detail_pass: OrisonDetailPass
var atmospheric_decal_pass: AtmosphericDecalPass
var exterior_detail_pass: ExteriorDetailPass
var found_art_pass: FoundArtPass
var wayfinding_signage: WayfindingSignagePass
var maintenance_headquarters: MaintenanceHeadquarters
var objective_tracker: ObjectiveTracker
var work_orders: WorkOrders
var maintenance_inventory: MaintenanceInventory
var shop_service: MaintenanceShopService
var core_loop: CoreLoopDirector
var vantry_points: VantryPointNetwork
var chirp_hunt: ChirpHunt
var first_shift_director: FirstShiftDirector
var safety_net: SafetyNet
var sanity: SanityDirector
var building_personality: BuildingPersonalityDirector
var intrusions: Intrusions
var fourth_wall: FourthWallLayer
var ambient_soundscape: AmbientSoundscape
var music_director: OrisonMusicDirector
var domestic_witnesses: DomesticWitnessSystem
const ApartmentEncroachmentScript := preload("res://scripts/reality/apartment_encroachment.gd")
var apartment_encroachment: Node
var furniture_interactions: FurnitureInteractionPass
## One finite steam cycle shared by all twenty-three radiators. Props expose
## fittings; this model owns the consequence of changing one of them.
var heat_balance
var boiler_tend
var affected_prop_count := 0
var reality_controllers: Dictionary = {}
var show_all_floors := false
## Coarse visibility is region state, not continuous motion.  The camera can
## move hundreds of physics ticks inside one room, pavement or Passage segment
## without changing a single floor/prop/door answer.  Keep the last exact
## answer so those ticks do not rescan every registered actor.  Direct calls to
## `_apply_visibility()` remain authoritative (the focused tests and camera
## tools use them), and changing `show_all_floors` is part of the key.
var _visibility_key := -1
var _visibility_apply_count := 0
## Same-build performance control. Inert unless the focused benchmark asks for
## the old every-tick scan explicitly; production and ordinary tests cache.
var _visibility_cache_enabled := \
		OS.get_environment("PERF_VISIBILITY_CACHE_OFF") != "1"


func _ready() -> void:
	# Findable by group rather than only as the current scene. Systems
	# that need the building reach for this group first and fall back to
	# get_tree().current_scene — a fallback that works in play, where the
	# building IS the scene, and silently fails in every test, where it
	# is a child of the test node. That is how the torch's reaction to
	# intrusions came to be wired to a director it could never find.
	add_to_group("building_root")
	var f := FileAccess.open("res://data/building_layout.json", FileAccess.READ)
	layout = JSON.parse_string(f.get_as_text())
	_build_environment()
	for fid in FLOOR_SCENES:
		var scene := load(FLOOR_SCENES[fid]) as PackedScene
		if scene == null:
			push_warning("missing floor scene %s" % fid)
			continue
		var node := scene.instantiate()
		node.name = fid
		add_child(node)
		floor_nodes[fid] = node
	# M-COVER (owner ruling 2026-08-21): the floor sets trade their shipping
	# StandardMaterial3D for the same maps under the structure-aware coverage
	# shader. Same surfaces, same draw count, no new texture. FLOOR_COVERAGE=0
	# keeps the shipping materials for an A/B.
	floor_coverage = FloorCoveragePassScript.new()
	floor_coverage.apply(floor_nodes)
	_index_passage_geometry()
	# Work orders are a gameplay owner, not UI text. The tracker presents their
	# state, but the state exists before the first customer is constructed.
	objective_tracker = ObjectiveTracker.new()
	objective_tracker.name = "ObjectiveTracker"
	add_child(objective_tracker)
	work_orders = WorkOrders.new()
	work_orders.name = "WorkOrders"
	work_orders.setup(objective_tracker)
	work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(work_orders)
	# The errand half of the spine: item facts and the shop transaction each
	# keep their own owner; the counter point stands on the shop's authored
	# counter anchor.
	maintenance_inventory = MaintenanceInventory.new()
	maintenance_inventory.name = "MaintenanceInventory"
	maintenance_inventory.setup()
	add_child(maintenance_inventory)
	shop_service = MaintenanceShopService.new()
	shop_service.name = "MaintenanceShopService"
	add_child(shop_service)
	shop_service.setup(maintenance_inventory, work_orders)
	shop_service.build_counters(layout)
	# The 119 quiet heads are batched by floor. Exactly one full prop is kept
	# ready to become the current audible/serviceable owner without a blink.
	vantry_points = VantryPointNetwork.new()
	vantry_points.name = "VantryPointNetwork"
	add_child(vantry_points)
	vantry_points.build(layout, floor_nodes, work_orders)
	# Re-attach the height maps the glTF could not carry. Must run after
	# every floor scene is in the tree and before anything else touches
	# their materials.
	heightmaps = HeightmapPass.new()
	add_child(heightmaps)
	heightmaps.build(floor_nodes)
	environment_detail_pass = OrisonDetailPass.new()
	add_child(environment_detail_pass)
	var detail_stats := environment_detail_pass.build(layout, floor_nodes)
	atmospheric_decal_pass = AtmosphericDecalPass.new()
	add_child(atmospheric_decal_pass)
	var atmospheric_decals := atmospheric_decal_pass.build(layout, floor_nodes)
	var railing_polish := OrisonRailingPolish.new()
	add_child(railing_polish)
	var railing_details := railing_polish.build(layout)
	window_glow = OrisonWindowGlow.new()
	window_glow.name = "WindowGlow"
	add_child(window_glow)
	var n_lit := window_glow.build(layout)
	# Corridor-side spill from the closed doors, asking the window pass which
	# rooms are awake so both sides of the same wall tell the same story.
	door_glow = OrisonDoorGlow.new()
	door_glow.name = "DoorGlow"
	add_child(door_glow)
	door_glow.build(layout, window_glow)
	# One video decode feeding every television in the building.
	# The station: per-clip shuffle, live cards, per-set power, one decode.
	broadcast = BroadcastDirector.new()
	broadcast.name = "Broadcast"
	add_child(broadcast)
	broadcast.build(layout, floor_nodes)
	# A game in every arcade cabinet. The carcasses are already in the floor
	# mesh; this gives each one a live screen, a marquee, and a title that has
	# nothing to do with what it runs.
	arcade_row = ArcadeRow.new()
	arcade_row.name = "Arcade"
	add_child(arcade_row)
	arcade_row.install(layout, floor_nodes)
	call_interface = CallInterface.new()
	add_child(call_interface)
	# Cases change the building, so the runner needs a handle on it: a
	# `reveal` beat looks its prop up by the same node name the marker
	# pipeline spawned it under. Props are spawned below, and no case can
	# fire before the player has sat down, so the ordering is safe.
	call_interface.world = self
	heat_balance = HEAT_BALANCE_SCRIPT.new()
	heat_balance.configure(layout)
	# Clocks are wall art's older, more authoritative cousins.  Reserve their
	# hooks before either the functional props or the eighteen case witnesses
	# are built; clearing this registry after them was why later picture passes
	# could unknowingly hang a frame through a clock face.
	WallArtLaw.clear_reservations()
	_spawn_props()
	# Furniture bodies remain baked into the floor glTF. Restore only the
	# individually generated mechanisms that need an E owner; the overlay pass
	# reads the same records and never edits or duplicates the porcelain/body.
	furniture_interactions = FURNITURE_INTERACTION_SCRIPT.new()
	furniture_interactions.name = "FurnitureInteractions"
	add_child(furniture_interactions)
	furniture_interactions.build(layout, floor_nodes)
	# One physical coal plant feeds both systems. The props remain individually
	# interactable; this clock is only the shared consequence of tending them.
	var plant := get_node_or_null("B1_BOILER_01") as BoilerProp
	var water_fixtures: Array[TapProp] = []
	for child in get_children():
		if child is TapProp:
			water_fixtures.append(child)
	boiler_tend = BOILER_TEND_SCRIPT.new()
	boiler_tend.name = "BoilerTend"
	add_child(boiler_tend)
	boiler_tend.configure(plant, heat_balance, water_fixtures)
	exterior_detail_pass = ExteriorDetailPass.new()
	add_child(exterior_detail_pass)
	exterior_detail_pass.build(layout, floor_nodes["F01"])
	exterior_detail_pass.configure_street_lights(self)
	# The shell is construction; this is the hall's lived, movable layer.
	# Runtime ownership keeps the rigid handcarts out of the Blender buffers and
	# lets the portal gate freeze their physics with their rendering.
	passage_finish = PASSAGE_FINISH_SCRIPT.new()
	add_child(passage_finish)
	passage_finish.build(layout)
	passage_shell_nodes.append_array(passage_finish.geometry_nodes)
	for cart in passage_finish.pushcarts:
		passage_runtime_nodes.append(cart)
	# Hours owns a compositional state (open/folded versus closed/extended),
	# so the zone gate calls its public boundary instead of forcing visibility.
	passage_runtime_nodes.append(passage_finish.hours_director)
	_build_passage_light_pass()
	# Shop signs are read-only presenters of that same state.  Bind the owner
	# after it exists; no sign duplicates or infers the hours rule from its id.
	for floor_prop in functional_props_by_floor.get("F01", []):
		if floor_prop is ShopSignProp:
			floor_prop.bind_hours_director(passage_finish.hours_director)
	_spawn_npc_placeholders()
	# Eighteen people with somewhere to be, and a mesh instead of a sprite
	# for whoever has one yet.
	resident_routines = ResidentRoutines.new()
	resident_routines.name = "ResidentRoutines"
	add_child(resident_routines)
	resident_routines.build(layout,
			get_tree().get_nodes_in_group("resident_placeholders"))
	# The wall switches go live, and the moon keeps switched-off rooms
	# readable instead of void-black.
	switch_system = SwitchSystem.new()
	switch_system.name = "Switches"
	add_child(switch_system)
	switch_system.build(layout, self)
	# The street is a stream you cross now, not a corridor you walk along.
	street_traffic = StreetTraffic.new()
	add_child(street_traffic)
	street_traffic.build()
	moon_fill = MoonFill.new()
	moon_fill.name = "MoonFill"
	add_child(moon_fill)
	moon_fill.build(layout, player)
	moon_fill._root = self
	_spawn_reality_controllers()
	wayfinding_signage = WayfindingSignagePass.new()
	add_child(wayfinding_signage)
	wayfinding_signage.build(self)
	_spawn_reality_affected_props()
	domestic_witnesses = DomesticWitnessSystem.new()
	domestic_witnesses.name = "DomesticWitnessSystem"
	add_child(domestic_witnesses)
	domestic_witnesses.bind_vantry_network(vantry_points)
	domestic_witnesses.build(layout, floor_nodes)
	# The dream reaching into each case's flat (encroachment ruling 2026-08-21):
	# presentation only, reads case state, overrides that unit's finish quads.
	apartment_encroachment = ApartmentEncroachmentScript.new()
	add_child(apartment_encroachment)
	apartment_encroachment.build(layout, floor_nodes, domestic_witnesses)
	_spawn_character_memory_art()
	_spawn_character_wall_art()
	_spawn_hallway_art()
	_spawn_landing_art()
	found_art_pass = FoundArtPass.new()
	found_art_pass.name = "FoundArtPass"
	add_child(found_art_pass)
	found_art_pass.build(layout, floor_nodes)
	_build_front_entry_details()
	_build_original_orison_ad_board()
	maintenance_headquarters = MaintenanceHeadquarters.new()
	floor_nodes["F01"].add_child(maintenance_headquarters)
	mina_manifestation = MinaCaptionManifestation.new()
	mina_manifestation.name = "MinaCaptionManifestation"
	mina_manifestation.setup(self)
	add_child(mina_manifestation)
	mina_gameplay = MinaCaseGameplay.new()
	mina_gameplay.name = "MinaCaseGameplay"
	mina_gameplay.setup(objective_tracker, work_orders)
	add_child(mina_gameplay)
	portal_rule_display = PortalRuleDisplay.new()
	# East wall of F04 west storage, inset and facing west into the room.
	portal_rule_display.position = GameBoot.b2g([-5.615, 1.10, 11.25])
	portal_rule_display.rotation.y = -PI * 0.5
	add_child(portal_rule_display)
	# The map distortion lab is gone (2026-08-06). It captured every
	# MeshInstance3D on the player's floor and drove their global
	# transforms - walls, floors, ceilings - while the StaticBody3D
	# collision those meshes came with stayed exactly where it was. So
	# the floor you could see moved and the floor you were standing on
	# did not, which is not a haunting, it is the player falling through
	# the world. A poltergeist may move a prop; it may not move the
	# building.
	light_rig = LightRig.new()
	add_child(light_rig)
	if GameBoot.launch_mode == GameBoot.LaunchMode.CINEMATIC \
			and int(GameBoot.settings.get("quality", 0)) == 0:
		# SIXTY-FOUR LIGHTS, SIXTEEN SHADOWS (owner direction 2026-08-16).
		#
		# This said sixteen, justified as "the renderer's actual per-object
		# ceiling, so requesting more would only reshuffle winners". That
		# ceiling became 128 when project.godot was raised, and the budget
		# was never re-derived — partly because the documented LIGHT_BUDGET
		# sweep silently no-opped against this very call (see TASKS P8a).
		# With the sweep repaired, measurement said extra lights are free at
		# every station except the light court, which charged ~3 ms from 16
		# to 64 because it sees seven storeys of fixtures at once. The court
		# has since had its lantern count halved (atrium_tree, sixteen
		# "fruit" to eight composed brackets), which is what pays for this.
		#
		# Shadows stay at sixteen and are a different currency: the
		# positional atlas is a fixed 8192 that subdivides per caster, so
		# raising this number makes every shadow smaller. See TASKS L13.
		light_rig.set_budgets(64, 16)
	else:
		# Known-safe development profile retained from the live debug controls.
		light_rig.set_budgets(14, 8)
	elevator = OrisonElevator.new()
	add_child(elevator)
	elevator.setup(layout["elevator"])
	resident_routines.bind_elevator(elevator)
	# TASKS.md V4: give the routines the same floor nodes the visibility
	# gate drives, so a resident who walks or rides to another storey is
	# reparented to the floor they occupy instead of being culled with the
	# one they left.
	resident_routines.bind_floors(floor_nodes)
	# The archetype timetables, driving the routines off the same clock
	# the sky reads. Inert under DAYNIGHT=0 so the tests' canonical 03:00
	# building keeps its exact pre-schedule behaviour.
	var schedule_director := ScheduleDirector.new()
	schedule_director.name = "ScheduleDirector"
	add_child(schedule_director)
	schedule_director.setup(resident_routines, layout)
	# The bar keeps hours on the same clock: OPEN / AFTER-HOURS / CLOSED.
	var harukiya_states := HarukiyaStateDirector.new()
	harukiya_states.name = "HarukiyaStateDirector"
	add_child(harukiya_states)
	harukiya_states.setup(self)
	# And gains its hands-on layer: pictures, barrels, pool table, seats.
	var harukiya_hands := HarukiyaInteractables.new()
	harukiya_hands.name = "HarukiyaInteractables"
	add_child(harukiya_hands)
	harukiya_hands.build(self)
	player = PlayerController.new()
	player.position = GameBoot.b2g([0.0, -9.0, 0.1])  # vestibule
	add_child(player)
	# Traffic is constructed earlier with the exterior, before the player exists.
	# Bind now so its distance voices, shove contract and T6 arrival all share the
	# real production player instead of the null startup placeholder.
	street_traffic.bind_player(player)
	vantry_points.bind_player(player)
	# The no-screen Vantry service radiophone, in the hand already carrying
	# the work light. PhoneOS and its private viewport are not instantiated.
	service_set_carrier = ServiceSetCarrier.new()
	service_set_carrier.name = "ServiceSetCarrier"
	service_set_carrier.setup(player, player.camera, work_orders)
	player.carried_device = service_set_carrier
	player.set_lamp_enabled(true)
	ambient_soundscape = AmbientSoundscape.new()
	ambient_soundscape.setup(player)
	add_child(ambient_soundscape)
	music_director = OrisonMusicDirector.new()
	music_director.setup(self)
	add_child(music_director)
	virus_director = VirusSoundDirector.new()
	add_child(virus_director)
	virus_director.setup(self)
	first_shift_director = FirstShiftDirector.new()
	first_shift_director.name = "FirstShiftDirector"
	first_shift_director.setup(self, objective_tracker, virus_director)
	add_child(first_shift_director)
	chirp_hunt = ChirpHunt.new()
	chirp_hunt.name = "ChirpHunt"
	add_child(chirp_hunt)
	chirp_hunt.setup(vantry_points, work_orders, maintenance_inventory)
	# Production's CampaignShell keeps the coordinator while this entire world
	# is replaced. Focused scenes and historical tests that instantiate the
	# building directly retain a local coordinator with the same contract.
	var shell := get_tree().get_first_node_in_group("campaign_shell")
	if shell != null and shell.is_ancestor_of(self) \
			and shell.has_method("bind_waking_services"):
		core_loop = shell.call("bind_waking_services",
				work_orders, player, layout, elevator,
				street_traffic) as CoreLoopDirector
	else:
		core_loop = CoreLoopDirector.new()
		core_loop.name = "CoreLoopDirector"
		add_child(core_loop)
		core_loop.setup(work_orders, player, layout)
	mina_manifestation.bind_wake(core_loop)
	var room0 := Room0.new()
	add_child(room0)
	var anomaly: DoorAnomalyProp = get_node_or_null("F04_B_DOOR_ANOMALY")
	if anomaly:
		anomaly.room0 = room0
	# The world is allowed to lie about its own floor — chaos mode, reality
	# thresholds, room-local gravity, furniture moving under the player. The
	# net is what makes all of that safe to ship: it silently remembers the
	# last real standing position and puts the player back if they leave the
	# world. Created before the haunting that can cause the fall.
	safety_net = SafetyNet.new()
	safety_net.name = "SafetyNet"
	safety_net.setup(player)
	add_child(safety_net)
	# The sanity system: an invisible pressure model, eighteen poltergeists
	# built from the residents' own traumas, and a meta layer that breaks the
	# frame. There is no meter and there must never be one — see
	# sanity_director.gd for why.
	fourth_wall = FourthWallLayer.new()
	fourth_wall.name = "FourthWall"
	add_child(fourth_wall)
	intrusions = Intrusions.new()
	intrusions.name = "Intrusions"
	add_child(intrusions)
	intrusions.setup(self, player, fourth_wall)
	sanity = SanityDirector.new()
	sanity.name = "SanityDirector"
	add_child(sanity)
	sanity.setup(self, player, intrusions, fourth_wall)
	building_personality = BuildingPersonalityDirector.new()
	building_personality.name = "BuildingPersonalityDirector"
	add_child(building_personality)
	building_personality.setup(self, player, intrusions)
	sanity.bind_personality(building_personality)
	domestic_witnesses.bind_director(sanity, player)
	ambient_soundscape.bind_sanity(sanity)
	weather = WeatherFX.new()
	weather.name = "WeatherFX"
	weather.setup(player, Callable(self, "weather_exposure_at"),
			Callable(self, "weather_cover_at"))
	add_child(weather)
	weather.build_reflections(layout)
	day_night_director.bind_weather(weather, exterior_detail_pass)
	if OS.get_environment("PERF_COMMENSALS_OFF") != "1":
		commensals = CommensalDirector.new()
		commensals.name = "CommensalDirector"
		add_child(commensals)
		commensals.setup(self, layout, switch_system, ambient_soundscape,
				day_night_director, player)
	# DayNightDirector carries no signal -- resolved_profile() is a pull API --
	# so the passage pass polls it. Slowly: the hour moves in minutes and two
	# spot uniforms are not worth a per-frame visit.
	var sky_tick := Timer.new()
	sky_tick.name = "PassageLightTick"
	sky_tick.wait_time = 2.0
	sky_tick.autostart = true
	sky_tick.timeout.connect(_tune_passage_lights)
	add_child(sky_tick)
	_tune_passage_lights()
	touch = TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.look_delta.connect(player.apply_look)
	player.touch_input = touch.enabled
	# Always present, debug launch or not: F is how a shot gets taken and
	# a review tool that only exists in one launch mode is one you have to
	# remember the state of.
	shots = ShotCapture.new()
	shots.name = "ShotCapture"
	add_child(shots)
	if GameBoot.launch_mode == GameBoot.LaunchMode.DEBUG \
			and OS.get_environment("SHOT_ROOMS") == "":
		# One of every prop, lit and labelled, 400 m east. Unreachable by
		# design and built in debug launches only, so play never pays for
		# it. See prop_warehouse.gd for why it exists.
		warehouse = PropWarehouse.new()
		add_child(warehouse)
		warehouse.build(PROP_SCRIPTS)
		if safety_net:
			safety_net.exempt_zones.append(warehouse.hall_aabb())
		var debug := preload("res://scripts/ui/building_debug.gd").new()
		debug.setup(self)
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		layer.add_child(debug)
		shots.chrome = layer
	print("[BUILDING] Orison assembled: %d floors, "
			% [floor_nodes.size()] +
			"%d windows lit, %d railing details, player in lobby"
			% [n_lit, railing_details])
	print("[BUILDING] %d low-overhead environment details and %d story decals"
			% [detail_stats.details, detail_stats.decals])
	print("[BUILDING] %d atmospheric evidence decals" % atmospheric_decals)
	# LAST, deliberately: every builder above may parent geometry into F01,
	# and this sweep is only exhaustive if nothing is constructed after it.
	_index_late_f01_geometry()
	_index_street_core_geometry()


func _build_environment() -> void:
	## Tuned for the fixture pools: lower flat ambient so tungsten pools
	## own the rooms, gentle depth fog for aerial perspective down long
	## corridors and the atrium eye, soft glow so emissive envelopes and
	## halos bloom the way bright sources do to a dark-adapted eye.
	var env := Environment.new()
	var panorama := load(
			"res://assets/building/textures/sky/" +
			"orison_queens_night_rain_half_dome_4k.png") as Texture2D
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Target look: moonlit. Shadows read as midnight BLUE, not black —
	# a cool saturated floor under everything, so the tungsten pools and
	# the service-set lamp both land as warm/cold contrast against it instead
	# of against a void. Deep enough to keep the pools' authority.
	env.ambient_light_color = Color(0.17, 0.23, 0.42)
	env.ambient_light_energy = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.10)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 0.86
	env.fog_depth_begin = 13.0
	env.fog_depth_end = 50.0
	env.fog_depth_curve = 1.48
	env.glow_enabled = true
	env.glow_intensity = 0.68
	env.glow_bloom = 0.10
	# Fixtures emit around 1.0-1.2 after grading, so a 1.28 threshold
	# meant no source in the building ever bloomed. Below their output,
	# and the bulbs finally have haloes.
	env.glow_hdr_threshold = 0.85
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	_build_sky_dome(panorama)
	_build_atrium_atmosphere()
	var moon := DirectionalLight3D.new()
	moon.name = "ExteriorMoon"
	moon.light_color = Color(0.65, 0.7, 0.9)
	moon.light_energy = 0.052
	moon.rotation_degrees = Vector3(-38, 30, 0)
	moon.shadow_enabled = true
	moon.shadow_bias = 0.035
	moon.shadow_normal_bias = 0.55
	moon.directional_shadow_max_distance = 48.0
	moon.directional_shadow_fade_start = 0.80
	add_child(moon)
	day_night_director = DayNightDirector.new()
	day_night_director.name = "DayNightDirector"
	add_child(day_night_director)
	var dome := get_node_or_null("NightSkyHalfDome") as MeshInstance3D
	day_night_director.setup(self, env, moon,
			dome.material_override if dome else null)


func _build_sky_dome(panorama: Texture2D) -> void:
	## PanoramaSkyMaterial is unreliable on the Compatibility backend used
	## by this project. This camera-centered upper-hemisphere projection keeps
	## the horizon stable from street to roof and never samples a lower
	## hemisphere. The two adjacent authored states and a seam-safe procedural
	## lower cloud deck still cost ONE sky submission: depth comes from drift
	## and occlusion inside this material, never from a second dome or volume.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled,
		shadows_disabled;
uniform sampler2D panorama_a : source_color, filter_linear_mipmap,
		repeat_enable;
uniform sampler2D panorama_b : source_color, filter_linear_mipmap,
		repeat_enable;
uniform float sky_blend = 0.0;
uniform float exposure = 0.76;
uniform vec3 fog_horizon_color = vec3(0.05, 0.06, 0.10);
uniform vec3 celestial_direction = vec3(0.0, 0.6, -0.8);
uniform vec3 celestial_color = vec3(0.60, 0.68, 0.88);
uniform float celestial_strength = 0.30;
uniform float celestial_core_radius = 0.038;
uniform float celestial_halo_radius = 0.31;
uniform float ray_strength = 0.0;
uniform float lower_cloud_strength = 0.28;
uniform float high_cloud_strength = 0.22;
uniform float cloud_phase = 0.0;
uniform float weather_flash = 0.0;

// Hash value noise. No sampler: weather_sky_test pins the shader to exactly
// two panorama_* samplers, and the road-mist shader already proves hash noise
// compiles and runs on this renderer. It also costs no VRAM and no import.
float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(91.73, 37.11, 141.7))) * 43758.5453);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
			mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// Lacunarity 2.03 rather than 2.0 so the octaves never lock into a lattice
// and print a visible grid overhead.
float fbm3(vec3 p, int octaves) {
	float a = 0.5;
	float sum = 0.0;
	for (int k = 0; k < octaves; k++) {
		sum += a * vnoise3(p);
		p *= 2.03;
		a *= 0.52;
	}
	return sum;
}

// Project a view direction onto a flat cloud slab at a notional altitude.
// This is what makes the strata read as a CEILING rather than a painted
// shell: features stretch toward the horizon and are largest directly
// overhead, which is exactly where the panorama has to go soft.
vec3 slab(vec3 d, float floor_y) {
	return d / max(d.y, floor_y);
}

// The high veil. It owns the zenith now. The authored plate is deliberately
// blurred overhead by the pole LOD, and the panorama's own top rows are a
// near-constant convergence band, so without this the sky directly above the
// player carries no detail at all -- which is the whole complaint.
float high_veil(vec3 direction) {
	// Frequency matters more than it looks. The slab coordinate at the zenith
	// is barely a unit long, so a scale near 1 puts ONE noise feature across
	// the whole visible sky and reads as a flat wash -- which is the thing
	// this layer exists to prevent. 5.2 gives cells a few degrees across
	// overhead, stretching toward the horizon as the slab divides out.
	// ANISOTROPIC. Isotropic fbm makes round cells, and round pale cells
	// overhead read as cotton wool, not cirrus. Cirrus is drawn out by wind
	// shear, so stretch the sample 4.6:1 along the drift axis and the same
	// noise becomes streaks.
	vec3 plate = slab(direction, 0.06) * vec3(1.0, 1.0, 4.6);
	float n = fbm3(plate * 4.4
			+ vec3(TIME * 0.0035 + cloud_phase, 0.0, TIME * 0.0021), 4);
	float fine = fbm3(plate * 11.0
			+ vec3(TIME * 0.0052, 0.0, TIME * -0.0031), 3);
	// A wide ramp, not a threshold. The veil should never reach full opacity
	// anywhere -- it is thin ice miles up, and anything with a hard edge
	// stops being that.
	return smoothstep(0.18, 0.86, n * 0.80 + fine * 0.26);
}

float lower_clouds(float u, float v) {
	// Integer azimuth frequencies make both moving bands exactly periodic at
	// the panorama seam. Two slow, opposed drifts give the painted storm a
	// nearer layer without advertising a rotating texture shell.
	// Was three summed sines, which read as a rotating shell because that is
	// what it was. The name stays -- weather_sky_test pins it -- but the body
	// is now slab-projected fbm, drifting on its own vector.
	float elev = (1.0 - v) * 0.5 * PI;
	float horiz = cos(elev);
	vec3 direction = vec3(cos((u - 0.5) * 2.0 * PI) * horiz, sin(elev),
			sin((u - 0.5) * 2.0 * PI) * horiz);
	vec3 plate = slab(direction, 0.14);
	float broad = fbm3(plate * 1.35
			+ vec3(TIME * -0.0130 + cloud_phase, 0.0, TIME * 0.0074), 3);
	broad = broad * 2.0 - 0.72;
	// This is the lower deck, not cloud pasted over the skyline: it lives in
	// the middle elevations and is gone before the authored roofline begins.
	float altitude = smoothstep(0.12, 0.28, v)
			* (1.0 - smoothstep(0.70, 0.86, v));
	return smoothstep(-0.34, 0.43, broad) * altitude;
}

void fragment() {
	vec3 direction = normalize(
			(INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	float u = atan(direction.z, direction.x) / (2.0 * PI) + 0.5;
	// Half-dome source: top edge is zenith; bottom edge is horizon.
	// Views below the horizon hold on that final skyline texel instead of
	// exposing the dome's lower half. Fade that edge into distance haze
	// immediately so skyline pixels never stretch into vertical bars.
	float elevation = asin(clamp(direction.y, 0.0, 1.0));
	float v = 1.0 - elevation / (0.5 * PI);
	// THE ZENITH. Three separate faults met directly overhead and together
	// made a smooth pucker ringed by cloud snapping back on.
	//
	// (1) Both samplers repeat on BOTH axes, so the bilinear tap at v=0 wrapped
	// to row 2047 and put a dark dot at the exact pole. u must still wrap for
	// the panorama seam and Godot has no per-axis hint, so clamp v instead.
	const float SKY_TEXEL_V = 1.0 / 2048.0;
	v = clamp(v, SKY_TEXEL_V * 0.5, 1.0 - SKY_TEXEL_V * 0.5);
	// (2) Equirectangular has a projection singularity at the pole: 4096
	// texels span 360 degrees of azimuth but only 360*sin(theta) degrees of
	// arc, so tangential density runs 11.4 texels/deg at the horizon and 206
	// at 3.2 degrees off vertical -- an 18:1 minification the hardware's
	// screen-space derivatives cannot resolve, because they are undefined
	// there. -log2(sin_theta) IS that minification, so compute the mip level
	// rather than letting the GPU guess it.
	float sin_theta = max(sqrt(max(0.0, 1.0 - direction.y * direction.y)),
			1e-4);
	float pole_lod = clamp(-log2(sin_theta), 0.0, 7.0);
	vec4 authored_a = textureLod(panorama_a, vec2(u, v), pole_lod);
	vec4 authored_b = textureLod(panorama_b, vec2(u, v), pole_lod);
	// (3) AND THE FAN IS GEOMETRIC, NOT A FILTERING ARTEFACT. Every azimuth
	// collapses onto one point at the pole, so a radial pinwheel survives any
	// amount of blurring -- verified by forcing lod 6 across the whole dome,
	// which turned the sky to soup and left the fan perfectly intact.
	//
	// So stop sampling the plate up there. Row 0 of every authored panorama is
	// already the azimuthal MEAN of its top band -- measured std across all
	// 4096 columns is exactly 0.000 -- so it is the correct cap colour and
	// costs nothing to lose. Sampling that one constant row gives a clean
	// disc with no convergence, crossfading out to real cloud by ~17 degrees.
	// The high veil then puts detail back over the cap.
	float cap_v = SKY_TEXEL_V * 0.5;
	vec4 cap_a = textureLod(panorama_a, vec2(u, cap_v), 0.0);
	vec4 cap_b = textureLod(panorama_b, vec2(u, cap_v), 0.0);
	// Wide, because the fan is the projection of the plate's REAL detail and
	// extends far past the flattened band. Cap dominates to ~20 degrees off
	// vertical and the plate is fully back by ~40; the veil below carries the
	// overhead structure across that whole span, and it has no pole to
	// converge on because it is projected onto a flat slab.
	float zen = smoothstep(0.05, 0.64, sin_theta);
	authored_a = mix(cap_a, authored_a, zen);
	authored_b = mix(cap_b, authored_b, zen);
	vec4 authored = mix(authored_a, authored_b, sky_blend);
	float lower = lower_clouds(u, v) * lower_cloud_strength;
	// The veil is masked BY the storm deck, so the two read as separate
	// altitudes: where the lower deck is solid the high cloud is hidden
	// behind it, which is the parallax cue doing the work a second shell
	// would otherwise have to.
	// Lifted toward the zenith in exact compensation for the plate fading
	// out: overhead the veil IS the sky, at the horizon it is a thin gauze.
	float veil = high_veil(direction)
			* high_cloud_strength * (1.0 + (1.0 - zen) * 1.35)
			* (1.0 - lower * 0.65);
	float thickness = clamp(authored.a + lower + veil * 0.5, 0.0, 1.0);
	vec3 color = authored.rgb * exposure;
	// A veil lightens and desaturates rather than darkening: it is thin ice
	// crystal miles up catching whatever light there is, not rain-bearing.
	color = mix(color, mix(color, celestial_color * 0.86, 0.5), veil);
	// The close deck is cooler and slightly darker than the painted upper
	// cloud. Its changing overlap is the parallax cue.
	color = mix(color, color * vec3(0.69, 0.73, 0.78), lower * 0.48);
	float source_angle = acos(clamp(dot(direction,
			normalize(celestial_direction)), -1.0, 1.0));
	float halo = 1.0 - smoothstep(celestial_core_radius,
			celestial_halo_radius, source_angle);
	float core = 1.0 - smoothstep(0.0, celestial_core_radius, source_angle);
	float obscured = pow(1.0 - thickness, 2.4);
	color += celestial_color * celestial_strength
			* (halo * 0.42 + core * 0.24) * obscured;
	// Rare, vague fingers belong to the same hidden source. Cloud density
	// breaks them up; no crisp radial god-ray fan survives the rain.
	float fingers = pow(max(0.0, sin((u * 18.0 + cloud_phase) * 2.0 * PI)), 12.0);
	color += celestial_color * ray_strength * fingers * halo
			* (1.0 - thickness) * 0.18;
	float horizon_haze = smoothstep(0.78, 0.98, v);
	color = mix(color, fog_horizon_color, horizon_haze * 0.58);
	color += celestial_color * weather_flash * (0.09 + (1.0 - thickness) * 0.14);
	if (direction.y < 0.0) {
		float haze = smoothstep(0.0, 0.025, -direction.y);
		color = mix(color, fog_horizon_color * 0.34, haze);
	}
	ALBEDO = color;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("panorama_a", panorama)
	material.set_shader_parameter("panorama_b", panorama)
	var cloud_seed := 19280731
	if OS.get_environment("WEATHER_SEED").is_valid_int():
		cloud_seed = int(OS.get_environment("WEATHER_SEED"))
	material.set_shader_parameter("cloud_phase",
			float(posmod(cloud_seed, 997)) / 997.0 * TAU)
	var sphere := SphereMesh.new()
	sphere.radius = 120.0
	sphere.height = 240.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var dome := MeshInstance3D.new()
	dome.name = "NightSkyHalfDome"
	dome.mesh = sphere
	dome.material_override = material
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)


## The atrium eye under its skylight earns the money atmosphere: a faked
## volumetric shaft (additive gradient cone, no volumetrics on the
## Compatibility backend), slow dust motes riding it, and a soft
## vignette that pulls every frame toward the lens.
func _build_atrium_atmosphere() -> void:
	# The court's eye is a 2.92 m SQUARE — the stair wraps it with 1.70 m
	# flights on the east and west and landings north and south. A round
	# cone in a square well spilled through the balustrades at the corners
	# and stopped short of both ends. This is a square prism matched to the
	# eye, running from the skylight glazing down to the lobby floor, so
	# the light arrives from where the glass actually is.
	var shaft := MeshInstance3D.new()
	shaft.name = "AtriumShaft"
	var prism := BoxMesh.new()
	var top := 21.35            # underside of the monitor's skylight
	var bottom := -2.6          # basement floor, where the stair starts
	prism.size = Vector3(2.86, top - bottom, 2.86)
	shaft.mesh = prism
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# You STAND INSIDE this thing — it fills the eye you are looking up. So
	# render the far wall only (CULL_FRONT drops the faces between you and
	# the middle of the volume). With both faces additive, every sightline
	# crossed two of them and the whole frame washed to white.
	sm.cull_mode = BaseMaterial3D.CULL_FRONT
	sm.no_depth_test = false
	# A gradient texture cannot do this: a box's UVs restart per face, so
	# "bright toward the skylight" would repeat six times.
	#
	# The dimming lives in the COLOUR, not the alpha. Additive blending adds
	# albedo.rgb, and leaning on a low alpha to hold it back did not work —
	# the volume came through at nearly full strength and washed the court
	# white with a hard box edge across the stair. A near-black colour adds
	# a near-nothing amount no matter how the blend treats alpha.
	sm.albedo_color = Color(0.055, 0.062, 0.082, 1.0)
	shaft.material_override = sm
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.position = Vector3(0.0, (top + bottom) * 0.5, 0.0)
	add_child(shaft)
	# The source itself: a soft pool right under the skylight glazing, so
	# the shaft visibly begins AT the glass instead of merely existing.
	var mouth := MeshInstance3D.new()
	mouth.name = "AtriumSkylightPool"
	var mq := QuadMesh.new()
	mq.size = Vector2(2.86, 2.86)
	mouth.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mg := Gradient.new()
	mg.set_color(0, Color(0.30, 0.33, 0.42, 1.0))
	mg.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var mt := GradientTexture2D.new()
	mt.gradient = mg
	mt.fill = GradientTexture2D.FILL_RADIAL
	mt.fill_from = Vector2(0.5, 0.5)
	mt.fill_to = Vector2(0.5, 0.0)
	mm.albedo_texture = mt
	mouth.material_override = mm
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth.position = Vector3(0.0, top - 0.06, 0.0)
	mouth.rotation_degrees = Vector3(90, 0, 0)
	add_child(mouth)
	var dust := CPUParticles3D.new()
	dust.name = "AtriumDust"
	dust.amount = 110
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(2.4, 10.2, 2.4)
	dust.gravity = Vector3(0, -0.015, 0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.06
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 180.0
	var dq := QuadMesh.new()
	dq.size = Vector2(0.02, 0.02)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.albedo_color = Color(0.95, 0.92, 0.85, 0.30)
	dq.material = dm
	dust.mesh = dq
	dust.position = Vector3(0.0, 10.4, 0.0)
	add_child(dust)
	var vg_layer := CanvasLayer.new()
	vg_layer.layer = 6
	add_child(vg_layer)
	var vg := TextureRect.new()
	vg.name = "Vignette"
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vgrad := Gradient.new()
	vgrad.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
	vgrad.colors = PackedColorArray([
			Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0),
			Color(0, 0, 0, 0.26)])
	var vt := GradientTexture2D.new()
	vt.gradient = vgrad
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(0.5, 0.0)
	vt.width = 512
	vt.height = 512
	vg.texture = vt
	vg_layer.add_child(vg)


func _spawn_props() -> void:
	var count := 0
	for fl in layout["floors"]:
		var floor_id := String(fl["id"])
		if not functional_props_by_floor.has(floor_id):
			functional_props_by_floor[floor_id] = []
		if not doors_by_floor.has(floor_id):
			doors_by_floor[floor_id] = []
		for m in fl["markers"]:
			if m["kind"] == "desk_zone":
				var desk := DeskZone.new()
				desk.call_interface = call_interface
				# Named like every other marker-spawned node, so the desk
				# can be found by id the way the props can.
				desk.name = m["id"]
				add_child(desk)
				desk.global_position = GameBoot.b2g(m["pos"])
				continue
			if m["kind"] == "door":
				var door: DoorProp = LandmarkEntryDoor.new() \
						if str(m["id"]) == "F01_DOOR_06" else DoorProp.new()
				door.width = float(m["w"])
				door.height = float(m["h"])
				door.leaf_state = m["leaf"]
				door.swing_out = String(m.get("swing", "")) == "out"
				door.door_kind = String(m.get("subtype", "apartment_interior"))
				door.unit = String(m.get("unit", ""))
				door.finish_variant = int(m.get("finish_variant", 0))
				door.name = m["id"]
				# transform BEFORE add_child: a sync_to_physics leaf keeps
				# its global transform if the parent moves after entry
				door.position = GameBoot.b2g(m["pos"])
				door.rotation.y = deg_to_rad(-float(m.get("yaw_deg", 0)))
				add_child(door)
				doors_by_floor[floor_id].append(door)
				if String(m.get("zone", "")) == "PASSAGE":
					door.add_to_group("passage_runtime")
					passage_runtime_nodes.append(door)
				continue
			var script: GDScript = PROP_SCRIPTS.get(m["kind"])
			if script == null:
				continue
			var prop: FunctionalProp = script.new()
			prop.prop_type = m["kind"]
			prop.name = m["id"]
			if m.has("range") and prop is LightFixtureProp:
				prop.range_clamp = float(m["range"])
			if m.has("energy") and prop is LightFixtureProp:
				prop.energy_scale = float(m["energy"])
			if m.has("standby"):
				prop.set("standby_scale", float(m["standby"]))
			if m.get("navigation", false):
				prop.set("navigation_light", true)
			# The refrigerator needs to know whose kitchen it is, so its
			# contents are somebody's, and whether it is one of the four
			# 1927 monitor-tops, whose door is a different size.
			# A tap needs to know whether it is over a basin or in a
			# stall: same prop, different handles and a different drop.
			if prop is MedicineCabinetProp:
				prop.unit = String(m.get("unit", ""))
				prop.hinge_side = String(m.get("hinge_side", "left"))
			# Five owners, five different lamps. The marker names which, because
			# a lamp with no variant is a lamp nobody chose - see lamp_prop.gd.
			if prop is LampProp:
				prop.variant = String(m.get("variant", "landlord_enamel"))
			if prop is ClockProp:
				prop.unit = String(m.get("unit", ""))
				prop.clock_variant = String(m.get("variant", "drop_octagon"))
				prop.bind_order_spine(work_orders)
			if prop is SpeakerProp and m.has("bed"):
				# An ambience bed named in DATA: the bodega radio murmurs
				# because its marker says so, not because the prop grew a
				# special case for one shop.
				prop.bed = String(m["bed"])
			if prop is TapProp:
				prop.fixture = String(m.get("fixture",
						"shower" if m["kind"] == "shower" else "bath_sink"))
				prop.unit = String(m.get("unit", ""))
				prop.drain_side = int(m.get("drain_side", 1))
				prop.compact_kitchen = bool(m.get("compact", false))
				prop.has_drainboard = bool(m.get("drainboard", true))
			if prop is FridgeProp:
				prop.unit = String(m.get("unit", ""))
				prop.monitor_top = bool(m.get("monitor", false))
			if prop is StoveProp:
				prop.unit = String(m.get("unit", ""))
				prop.ambient_lit = bool(m.get("ambient_lit", false))
			if prop is ToasterProp:
				# Crumb placement is deterministic per household, and the future
				# archaeology content belongs to a resident rather than a marker id.
				prop.unit = String(m.get("unit", ""))
				if String(m.get("tray_axis", "")) == "-x":
					prop.tray_axis = Vector3.LEFT
			if prop is KettleProp:
				# Finish and the 4C evidence binding are household facts. They
				# must arrive before _ready() chooses copper, nickel and wear.
				prop.unit = String(m.get("unit", ""))
				prop.case_id = String(m.get("case_id", ""))
			if prop is BoxFanProp:
				# Household finish and room ownership are generator facts.  The
				# latter is also the possession cut: leave this room, and only then
				# may Sacha's attachment plug move without being witnessed.
				prop.unit = String(m.get("unit", ""))
				prop.fan_variant = String(m.get("variant", "plain"))
				prop.room_id = String(m.get("room", ""))
			if prop is ExhaustFanProp:
				# Four roof motors own the shared system.  Riser identity controls
				# both their quiet mechanical variation and the bathroom mouths
				# from which their sound is allowed to emerge.
				prop.riser = String(m.get("riser", "V-A"))
				prop.fan_variant = String(m.get("variant", "west_weathered"))
			if prop is FlueBreastProp:
				# The marker id binds the acoustic graph and must never be rebuilt
				# from this value.  Unit is only household/wear metadata; it used
				# to be the nonexistent hybrid F02C rather than the real 2C.
				prop.unit = String(m.get("unit", "5C"))
			if prop is BookshelfProp:
				# Ownership, silhouette and Mae's evidence are generator facts.
				# They arrive before _ready() deals the shelf and builds the case.
				prop.owner_name = String(m.get("owner", ""))
				prop.unit = String(m.get("unit", ""))
				prop.case_style = String(m.get("variant", "plain"))
				prop.canonical_book = String(m.get("canonical_book", ""))
			if prop is RadiatorProp:
				prop.unit = String(m.get("unit", ""))
				prop.riser = String(m.get("riser", "H-X"))
				prop.section_count = int(m.get("sections", 9))
				prop.bind_heat_balance(heat_balance)
			# A fitting under the entrance marquee hangs off the facade,
			# not off a storey ceiling. Carried through as a group so the
			# "too low for its floor" audit can tell the difference
			# between a canopy lamp and one that punched through a slab.
			if m.get("exterior", false):
				prop.add_to_group("exterior_fixtures")
			if prop is ShopSignProp:
				# All of it comes off the marker so that adding a shop to
				# SHOPS in gen_layout is the entire job — see the prop.
				prop.sign_text = String(m.get("text", "SHOP"))
				prop.shop_name = String(m.get("shop_name", prop.sign_text))
				prop.trade = String(m.get("trade", ""))
				prop.sub_text = String(m.get("sub", ""))
				prop.blade_text = String(m.get("blade_text", ""))
				prop.blade_dx = float(m.get("blade_dx", 0.0))
				prop.half_width = float(m.get("half_width", 2.4))
				prop.compact = bool(m.get("compact", false))
				var lt: Array = m.get("tint", [0.90, 0.86, 0.74])
				prop.tint = Color(float(lt[0]), float(lt[1]), float(lt[2]))
			if prop is NeonSignProp:
				prop.sign_text = String(m.get("text", "ORISON"))
				prop.vertical = bool(m.get("vertical", true))
				var t: Array = m.get("tint", [1.0, 0.3, 0.42])
				prop.tint = Color(float(t[0]), float(t[1]), float(t[2]))
			if AcousticGraphData.nodes.has(m["id"]):
				prop.graph_node_id = m["id"]  # bound to the shared graph
			# Compatibility renderer light transforms must be authored before
			# _ready() creates the Light3D children. Moving the prop afterward
			# moved its mesh but left the rendered light pool at the origin.
			var clock_spot: Dictionary = {}
			if prop is ClockProp and m.has("room"):
				var clock_room := _room_on_floor(fl, String(m.room))
				if not clock_room.is_empty():
					var clock_height := float(m.pos[2]) - float(fl.z)
					var half_h := 0.38 if prop.clock_variant == "drop_octagon" else 0.25
					clock_spot = WallArtLaw.legal_spot(fl, clock_room,
							String(m.get("mount_wall", "south")),
							float(m.get("mount_along", 0.5)), clock_height,
							Callable(), 0.26, half_h)
			if not clock_spot.is_empty() and bool(clock_spot.get("ok", false)):
				prop.position = GameBoot.b2g([clock_spot.x, clock_spot.y,
						float(fl.z) + float(clock_spot.height)])
			else:
				prop.position = GameBoot.b2g(m["pos"])
			# Complete appliances are authored with local -Z as their front,
			# matching the room-facing vector used by the generator's clearance
			# audit. Blender's +Z yaw therefore carries through with the same
			# sign. Legacy marker props were authored around the old negation and
			# keep it until each becomes the sole owner of its own geometry.
			prop.rotation.y = float(clock_spot.yaw) \
					if not clock_spot.is_empty() and bool(clock_spot.get("ok", false)) \
					else deg_to_rad(float(m.get("yaw_deg", 0)) \
					if prop is FridgeProp or prop is StoveProp or prop is TapProp \
							or prop is ToasterProp or prop is WasherProp \
							or prop is LaundryAirerProp or prop is KettleProp \
							or prop is MedicineCabinetProp or prop is ClockProp \
							or prop is BoxFanProp or prop is ExhaustFanProp \
							or prop is FlueBreastProp \
					else -float(m.get("yaw_deg", 0)))
			add_child(prop)
			functional_props_by_floor[floor_id].append(prop)
			if String(m.get("zone", "")) == "PASSAGE":
				prop.add_to_group("passage_runtime")
				passage_runtime_nodes.append(prop)
			count += 1
	print("[BUILDING] %d functional props spawned" % count)


## Blender keeps the shell and each fitted shop in separately named batches.
## Retaining that source identity in the glTF is what makes a real zone gate
## possible; a merged F01 buffer could only be hidden as one indivisible site.
func _index_passage_geometry() -> void:
	var floor: Node = floor_nodes.get("F01")
	if floor == null:
		return
	for candidate in floor.find_children("*", "GeometryInstance3D", true, false):
		var geometry := candidate as GeometryInstance3D
		if geometry == null:
			continue
		var geometry_name := String(geometry.name)
		if geometry_name.contains("_retail_shop_"):
			passage_interior_nodes.append(geometry)
		elif geometry_name.contains("_retail_passage_shell_"):
			passage_shell_nodes.append(geometry)
		elif not geometry_name.contains("_retail_passage_proxy_"):
			passage_foreign_f01_nodes.append(geometry)
	print("[PASSAGE] %d interior, %d shell and %d foreign F01 draws indexed" %
			[passage_interior_nodes.size(), passage_shell_nodes.size(),
			passage_foreign_f01_nodes.size()])


## The name-based index above runs at _ready line ~210, before any late
## builder has constructed a node — so everything VantryPointNetwork, the
## detail passes, MaintenanceHeadquarters, the lobby boards, the wall-art
## catalogs, the arcade spawner and the street ends parent into F01 lands in
## NO list, and `_set_passage_visibility` cannot touch it. Measured at the
## northbound station before this sweep existed: 532 visible unclassified
## draws, ~500 of them shadow casters, submitted from inside a zone that
## cannot see them (PassageOwnershipAudit.tscn, own_audit_before2.log).
##
## Names cannot classify late geometry — a Passage shop cabinet and a lobby
## cabinet share a naming scheme — but the ruled envelope can: geometry
## fully inside the throat/hall volume is Passage interior, fully outside is
## foreign, and anything dynamic or straddling is EXPLICITLY shared rather
## than silently skipped, so the audit can demand zero unclassified draws.
##
## Runs at the end of _ready to front-load the bulk, and again on EVERY
## zone transition — because construction does not stop at _ready. The
## arcade spawner boots cabinets asynchronously, so 207 of the 732 late
## draws did not exist yet when _ready returned; a sweep that runs once can
## never be exhaustive, and one that runs on each portal crossing is, for
## everything built by the time the player can see either side. Incremental
## via the `known` set, so repeat sweeps only pay for what is new.
func _index_late_f01_geometry() -> void:
	var floor: Node = floor_nodes.get("F01")
	if floor == null:
		return
	# Late-built geometry can also be late-FREED — a cabinet going live
	# rebuilds its screen, and the first windowed run crashed 0xC0000005 on
	# exactly that: a dead reference in these arrays touched during the
	# transition sweep. Prune the dynamic arrays first, then index.
	for arr: Array in [passage_late_interior_nodes,
			passage_late_foreign_nodes, passage_shared_f01_nodes]:
		for i in range(arr.size() - 1, -1, -1):
			if not is_instance_valid(arr[i]):
				arr.remove_at(i)
	var known := {}
	for arr: Array in [passage_interior_nodes, passage_shell_nodes,
			passage_foreign_f01_nodes, passage_late_interior_nodes,
			passage_late_foreign_nodes, passage_shared_f01_nodes]:
		for g in arr:
			if is_instance_valid(g):
				known[g.get_instance_id()] = true
	# Membership in the prop registries, not class ancestry: the prop loop
	# gates exactly what is IN functional_props_by_floor / doors_by_floor.
	# A node that merely extends FunctionalProp but was never registered
	# (the reality props) is gated by nobody, and calling it shared would
	# have left the second-largest leak in place.
	var registered := {}
	for fid in functional_props_by_floor:
		for p in functional_props_by_floor[fid]:
			registered[p.get_instance_id()] = true
	for fid in doors_by_floor:
		for d in doors_by_floor[fid]:
			registered[d.get_instance_id()] = true
	var added := {"interior": 0, "foreign": 0, "shared": 0}
	for candidate in floor.find_children("*", "GeometryInstance3D", true, false):
		var geometry := candidate as GeometryInstance3D
		if geometry == null or known.has(geometry.get_instance_id()):
			continue
		if String(geometry.name).contains("_retail_passage_proxy_"):
			continue                # STREET-owned by ruling; never indexed
		if _late_owner_is_dynamic(geometry, floor, registered):
			passage_shared_f01_nodes.append(geometry)
			added["shared"] += 1
			continue
		match _envelope_side(geometry.global_transform * geometry.get_aabb()):
			1:
				passage_late_interior_nodes.append(geometry)
				added["interior"] += 1
			-1:
				passage_late_foreign_nodes.append(geometry)
				added["foreign"] += 1
			_:
				passage_shared_f01_nodes.append(geometry)
				added["shared"] += 1
	if added["interior"] + added["foreign"] + added["shared"] > 0:
		print("[PASSAGE] late sweep: %d interior, %d foreign, %d shared "
				% [added["interior"], added["foreign"], added["shared"]]
				+ "late-built F01 draws registered")
	_index_root_zone_content()


## The F01 sweep covers the floor SUBTREE, and two populations live
## outside it. Root-parented builders — RailingPolish, WayfindingSignage,
## the marquee, window glow, the wall-art and case passes — submit their
## geometry from root, and with occlusion culling removed (2026-08-05)
## the hall's shell hides none of it: the northbound submission census
## measured ~850 of 1786 in-frustum objects belonging to the foreign zone
## through walls. And the zone gate has never touched a LIGHT: the lobby
## lamps (r=13, ~678 casters each, two shadowed lights per lamp), the
## entry rakes and the parked player's phone kept re-rendering hundreds
## of foreign casters into shadow maps nobody inside the hall can see —
## ~3400 of 5169 visible-pass submissions were shadow re-renders.
##
## Same law, two more node populations: classify by the ruled envelope,
## save/restore on the transition, skip what another system owns.
func _index_root_zone_content() -> void:
	var registered := {}
	for fid in functional_props_by_floor:
		for p in functional_props_by_floor[fid]:
			registered[p.get_instance_id()] = true
	for fid in doors_by_floor:
		for d in doors_by_floor[fid]:
			registered[d.get_instance_id()] = true
	var known := {}
	for arr: Array in [passage_interior_nodes, passage_shell_nodes,
			passage_foreign_f01_nodes, passage_late_interior_nodes,
			passage_late_foreign_nodes, passage_shared_f01_nodes]:
		for g in arr:
			if is_instance_valid(g):
				known[g.get_instance_id()] = true
	for i in range(passage_foreign_lights.size() - 1, -1, -1):
		if not is_instance_valid(passage_foreign_lights[i]):
			passage_foreign_lights.remove_at(i)
		else:
			known[passage_foreign_lights[i].get_instance_id()] = true

	var added := {"interior": 0, "foreign": 0, "lights": 0}
	var floor_set: Array = floor_nodes.values()
	for child in get_children():
		if child in floor_set or child == player \
				or child is Camera3D or child is CanvasLayer:
			continue
		# WeatherFX re-centres on the camera every frame — it is wherever
		# the player is, including the hall, and is never foreign.
		if child == weather:
			continue
		var candidates: Array = child.find_children("*",
				"GeometryInstance3D", true, false)
		if child is GeometryInstance3D:
			candidates.append(child)
		for candidate in candidates:
			var geometry := candidate as GeometryInstance3D
			if geometry == null or known.has(geometry.get_instance_id()):
				continue
			if _late_owner_is_dynamic(geometry, self, registered):
				passage_shared_f01_nodes.append(geometry)
				continue
			match _envelope_side(geometry.global_transform
					* geometry.get_aabb()):
				1:
					passage_late_interior_nodes.append(geometry)
					added["interior"] += 1
				-1:
					passage_late_foreign_nodes.append(geometry)
					added["foreign"] += 1
				_:
					passage_shared_f01_nodes.append(geometry)

	# Lights, whole tree: a light is zone-owned by WHERE IT STANDS, not by
	# what it is parented to (the lobby lamp lights hang inside imported
	# floor scenes). Skips: anything under the player (the phone travels
	# with them), lights owned by registered props or Passage actors
	# (their owners already gate them), and directional lights (the moon
	# is everyone's).
	var lights: Array = []
	_collect_zone_lights(self, lights)
	for light in lights:
		if known.has(light.get_instance_id()):
			continue
		if light is DirectionalLight3D:
			continue
		if player != null and (light == player
				or player.is_ancestor_of(light)):
			continue
		if _late_owner_is_dynamic(light, self, registered):
			continue
		var c: Vector3 = light.global_position
		# Foreign lights only. The Passage's own shop and aisle lights
		# stay untouched in both zones: hiding them when the player is on
		# the street would change what glows behind the portal proxy, and
		# their caster sets are the hall's legitimate local cost.
		if _envelope_side(AABB(c, Vector3.ZERO)) == -1:
			passage_foreign_lights.append(light)
			added["lights"] += 1
	if added["interior"] + added["foreign"] + added["lights"] > 0:
		print("[PASSAGE] root sweep: %d interior, %d foreign draws, "
				% [added["interior"], added["foreign"]]
				+ "%d foreign lights registered" % added["lights"])


## Indexes the low-F01 content that is provably behind the Orison shell from
## STREET. Classification is by the complete world AABB, never its centre: any
## geometry touching a facade boundary remains eligible. Compound functional
## props and doors are atomic owners, so one exterior child retains the whole
## assembly instead of shearing letters from neon or leaves from joinery.
func _index_street_core_geometry() -> void:
	for i in range(street_core_nodes.size() - 1, -1, -1):
		if not is_instance_valid(street_core_nodes[i]):
			street_core_nodes.remove_at(i)
	var known := {}
	for geometry in street_core_nodes:
		known[geometry.get_instance_id()] = true
	var protected := _street_core_protected_geometry()
	var candidates: Array[GeometryInstance3D] = []
	_collect_street_geometry(self, candidates)
	var added := 0
	for geometry in candidates:
		if known.has(geometry.get_instance_id()) \
				or protected.has(geometry.get_instance_id()):
			continue
		if player != null and (geometry == player
				or player.is_ancestor_of(geometry)):
			continue
		if _has_moving_resident_ancestor(geometry):
			continue
		if not _is_street_hidden_geometry(geometry):
			continue
		street_core_nodes.append(geometry)
		added += 1
	if added > 0:
		print("[STREET] %d enclosed F01 draws indexed" % added)


func _street_core_protected_geometry() -> Dictionary:
	var protected := {}
	# These cards are the designed view of occupied rooms from outdoors.
	if window_glow != null:
		_protect_street_geometry(window_glow, protected)
	# THE WINDOWS THEMSELVES, by the identical argument one line above.
	#
	# The owner reported the lower windows losing "their treatment and glass
	# entirely" from the carriageway. They were: `F01_glazing` and
	# `F01_stone_trim` are whole-floor batches whose extents sit inside the
	# 15.2 x 11.2 core envelope — the core is the STREET REGION and the building
	# stands within it — so both were indexed as enclosed content and layered
	# off. That is every pane of ground-floor glass plus every limestone jamb,
	# head, projecting sill and sash meeting rail on the ground storey, leaving
	# each opening a raw hole in the brick with a blind hanging in it.
	#
	# Only F01 is ever caught, because every storey above it sills higher than
	# the envelope's 2.80 m ceiling. The class is named rather than the instance
	# anyway: a batch carrying the building's own glazing and joinery IS the
	# exterior view of it, whichever floor it belongs to.
	for fid in floor_nodes:
		for child in floor_nodes[fid].get_children():
			var suffix := String(child.name).trim_prefix(fid + "_")
			for token in ENVELOPE_BATCHES:
				if suffix.contains(token):
					_protect_street_geometry(child, protected)
					break
	var owners: Array = []
	for fid in functional_props_by_floor:
		owners.append_array(functional_props_by_floor[fid])
	for fid in doors_by_floor:
		owners.append_array(doors_by_floor[fid])
	for owner in owners:
		var owned: Array[GeometryInstance3D] = []
		_collect_street_geometry(owner, owned)
		var boundary_owned := String(owner.name) == "F01_DOOR_06"
		for geometry in owned:
			if not _is_street_hidden_geometry(geometry):
				boundary_owned = true
				break
		if boundary_owned:
			for geometry in owned:
				protected[geometry.get_instance_id()] = true
	# Explicit exterior architecture assembled at runtime.
	#
	# StreetTraffic belongs here and its absence was a real bug: the sweep
	# indexes any F01 geometry that reads as enclosed, the traffic multimeshes
	# sit at carriageway height inside that test, and so every vehicle had its
	# layers zeroed at exactly the moment the player stepped onto the pavement.
	# The stream you are meant to cross was visible from everywhere except the
	# kerb. It hid rather than vanished visibly, because `_zone_toggle` writes
	# `layers = 0` and leaves `visible` alone — so the node reports itself
	# visible, with a populated multimesh, drawing nothing. Worth remembering
	# the next time something "is definitely there" and is not on screen.
	for child in get_children():
		if String(child.name) in ["EntranceMarqueeDress", "BuildingEntrySign",
				"StreetTraffic"]:
			_protect_street_geometry(child, protected)
	return protected


func _protect_street_geometry(owner: Node, protected: Dictionary) -> void:
	var owned: Array[GeometryInstance3D] = []
	_collect_street_geometry(owner, owned)
	for geometry in owned:
		protected[geometry.get_instance_id()] = true


func _collect_street_geometry(node: Node,
		out: Array[GeometryInstance3D]) -> void:
	if node is SubViewport:
		return
	if node is GeometryInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_street_geometry(child, out)


func _has_moving_resident_ancestor(node: Node) -> bool:
	var cursor := node
	while cursor != null and cursor != self:
		if String(cursor.name).begins_with("NPC_"):
			return true
		cursor = cursor.get_parent()
	return false


## AN AABB NOBODY COULD MEASURE IS NOT EVIDENCE OF ENCLOSURE.
##
## Under the HEADLESS dummy renderer every MultiMeshInstance3D and particle
## node reports an EMPTY box from `get_aabb()`, because the dummy storage
## keeps no instance transforms to compute one from. An empty box sitting at
## the node's own origin then passes the containment test below trivially —
## lo == hi == (0,0,0) is inside any envelope that spans the origin — so a
## headless run indexed forty-one draws as enclosed F01 content that a real
## run does not, among them the street-end hoardings and work beacons at
## |x| ~ 20 m, the driving rain, the roadway mist and every Vantry point
## batch in the building.
##
## MEASURED BOTH WAYS BEFORE BELIEVING EITHER. Under Vulkan the same nodes
## report real extents and are classified correctly, so this was the
## instrument rather than the game — no player has ever lost the hoardings.
## The guard stays because every automated harness in this project runs
## headless, and a gate that hides forty-one street draws only when it is
## being watched is a measurement waiting to be believed.
##
## Reconstructing the extent from the multimesh's own instance transforms
## was tried and does not work: the dummy renderer returns identity for
## every one of them, so the reconstruction lands the whole batch on the
## origin, which is where the trouble was. Unmeasurable therefore means NOT
## enclosed, because the safe answer for a visibility blocker is to leave a
## draw it cannot place alone.
func _measured_world_aabb(geometry: GeometryInstance3D) -> AABB:
	var local: AABB = geometry.get_aabb()
	if local.size.length_squared() <= 0.0:
		if geometry is GPUParticles3D:
			local = (geometry as GPUParticles3D).visibility_aabb
		elif geometry is CPUParticles3D:
			local = (geometry as CPUParticles3D).visibility_aabb
	if local.size.length_squared() <= 0.0:
		return AABB()
	return geometry.global_transform * local


func _fully_in_street_core(geometry: GeometryInstance3D) -> bool:
	var world := _measured_world_aabb(geometry)
	if world.size.length_squared() <= 0.0:
		return false
	var lo := world.position
	var hi := world.end
	return lo.x > -LightRig.ORISON_CORE_HALF_X \
			and hi.x < LightRig.ORISON_CORE_HALF_X \
			and lo.z > -LightRig.ORISON_CORE_HALF_Z \
			and hi.z < LightRig.ORISON_CORE_HALF_Z \
			and lo.y >= -0.50 and hi.y <= 2.80


## Harukiya's approved Blender envelope is x -12.0..6.4,
## y -38.2..-28.32, which maps to Godot z 28.32..38.2. Keep the exact street
## face and entrance reveal eligible by requiring 0.28 m of depth; anything
## touching another mass boundary remains visible. The lower y bound includes
## the sunken bar floor and stage without admitting substrate below it.
func _fully_in_harukiya_core(geometry: GeometryInstance3D) -> bool:
	var world := _measured_world_aabb(geometry)
	if world.size.length_squared() <= 0.0:
		return false
	var lo := world.position
	var hi := world.end
	return lo.x > -12.0 and hi.x < 6.4 \
			and lo.z > 28.60 and hi.z < 38.20 \
			and lo.y >= -3.35 and hi.y <= 2.80


func _is_street_hidden_geometry(geometry: GeometryInstance3D) -> bool:
	return _fully_in_street_core(geometry) \
			or (_street_harukiya_gate_enabled \
					and _fully_in_harukiya_core(geometry))


func _collect_zone_lights(n: Node, out: Array) -> void:
	if n is SubViewport:
		return
	if n is Light3D:
		out.append(n)
	for c in n.get_children():
		_collect_zone_lights(c, out)


## Ancestry that makes a static zone answer WRONG, not merely uncertain.
## Geometry under a REGISTERED FunctionalProp/DoorProp is already zone-gated
## per prop by `_apply_visibility`'s prop loop — indexing it here would give
## the same node two visibility writers. Residents move: their schedules
## legitimately reach Passage anchors, so a resident hidden by a static
## foreign entry would walk the hall invisibly.
func _late_owner_is_dynamic(geometry: Node, floor: Node,
		registered: Dictionary) -> bool:
	var cursor: Node = geometry
	while cursor != null and cursor != floor:
		if registered.has(cursor.get_instance_id()):
			return true
		if String(cursor.name).begins_with("NPC_"):
			return true
		cursor = cursor.get_parent()
	return false


## Which side of the ruled Passage envelope a world AABB sits on:
## 1 fully inside, -1 fully outside, 0 straddling. The bounds are the same
## throat and hall boxes as `_point_is_in_passage` — keep them in lockstep,
## because a probe that names the zone and an index that hides it must not
## disagree about where the zone is.
func _envelope_side(world: AABB) -> int:
	var x0 := world.position.x
	var x1 := x0 + world.size.x
	var y0 := world.position.y
	var y1 := y0 + world.size.y
	var z0 := world.position.z
	var z1 := z0 + world.size.z
	var touches_throat := z1 > 28.316 and z0 <= 38.6 \
			and x1 > 11.0 and x0 < 17.0
	var touches_hall := z1 > 38.6 and z0 <= 64.6 \
			and x1 > 4.0 and x0 < 24.0
	if not ((touches_throat or touches_hall)
			and y1 > -0.50 and y0 < 5.80):
		return -1
	# The union is L-shaped, so containment depends on which segment the
	# box occupies: anything reaching into the throat must fit the throat's
	# narrower x, and a box spanning the seam must fit both.
	var x_ok := (x0 >= 4.0 and x1 <= 24.0) if z0 >= 38.6 \
			else (x0 >= 11.0 and x1 <= 17.0)
	if z0 > 28.316 and z1 <= 64.6 and x_ok \
			and y0 >= -0.50 and y1 <= 5.80:
		return 1
	return 0


func _room_on_floor(floor_data: Dictionary, room_id: String) -> Dictionary:
	for room in floor_data.get("rooms", []):
		if String(room.get("id", "")) == room_id:
			return room
	return {}


## Smallest authored room containing a world-space point. Rooms nest — a bath
## sits inside its apartment envelope — so first-match would call the whole
## flat one room and let a possession swap happen through an open bathroom
## door. WindowGlow uses the same smallest-footprint law for the same reason.
## This is geometry/data partitioning, not a visibility guess, and therefore
## remains deterministic in tests without a camera or an occlusion query.
func room_at_world(world_position: Vector3) -> String:
	var floor_data: Dictionary = {}
	var floor_distance := INF
	for fl in layout.get("floors", []):
		var distance := absf(world_position.y - float(fl.get("z", 0.0)))
		if distance < floor_distance:
			floor_distance = distance
			floor_data = fl
	if floor_data.is_empty():
		return ""
	var bx := world_position.x
	var by := -world_position.z
	var best_id := ""
	var best_area := INF
	for room in floor_data.get("rooms", []):
		var rect: Array = room.get("rect", [])
		if rect.size() != 4 or bx < float(rect[0]) or bx > float(rect[2]) \
				or by < float(rect[1]) or by > float(rect[3]):
			continue
		var area := (float(rect[2]) - float(rect[0])) \
				* (float(rect[3]) - float(rect[1]))
		if area < best_area:
			best_area = area
			best_id = String(room.get("id", ""))
	return best_id



## The seven half-landings. They are not rooms - they are stair parts -
## so they cannot go through the hallway-art path, which hangs by room
## id. Each piece rides the north wall of the well at eye height above
## its own landing deck, facing south into the turn, which is the one
## wall a climber faces squarely twice per storey.
func _spawn_landing_art() -> void:
	var file := FileAccess.open("res://data/stair_landing_art.json",
			FileAccess.READ)
	if file == null:
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var stairs: Array = layout.get("stairs", [])
	if stairs.is_empty():
		return
	var well: Array = stairs[0]["well"]
	var north := float(well[3])
	var count := 0
	for spec in catalog.get("pieces", []):
		var lz := float(spec["landing_z"])
		var art := CharacterMemoryArt.new()
		art.setup({
			"id": spec.id, "atlas": catalog.atlas,
			"col": spec.col, "row": spec.row,
			"cols": catalog.get("cols", 3), "rows": catalog.get("rows", 3),
			"medium": spec.get("medium", "print"),
			"width": spec.get("width", 0.58),
			"height": spec.get("height", 0.58),
			"collection": "hallway_art",
		})
		add_child(art)
		# 6 cm off the plaster, centred on the well, 1.5 m above the deck
		art.global_position = GameBoot.b2g([0.0, north - 0.155, lz + 1.50])
		art.rotation.y = PI
		count += 1
	print("[BUILDING] %d stair-landing pieces hung" % count)


## V4: the two lights the arcade cannot get from the governed rig.
##
## Both are UNGOVERNED on purpose -- not in group "light_fixtures", so they
## take none of the 64 rank slots and none of the 16 shadow slots -- and both
## are SHADOWLESS, which on gl_compatibility means per-object ALU in the base
## pass rather than a second submission. On a submission-bound frame that is
## close to free. They still count against the renderer's per-object 128,
## which has 2x slack.
##
## They live in passage_runtime_nodes so the zone gate hides them whole the
## moment the player leaves the arcade.
func _build_passage_light_pass() -> void:
	var pass_root := Node3D.new()
	pass_root.name = "PassageLightPass"
	add_child(pass_root)

	# 1. The crossing shaft. Daylight down the lantern well, which the
	#    authored plate cannot supply because it is a texture on a dome.
	var shaft := SpotLight3D.new()
	shaft.name = "PassageCrossingShaft"
	shaft.position = Vector3(14.0, 9.80, 51.6)
	shaft.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	shaft.spot_angle = 42.0
	shaft.spot_range = 11.0
	shaft.shadow_enabled = false
	pass_root.add_child(shaft)

	# 2. The lunette. It sits in the 0.14 m cavity between its own glass and
	#    the soot blackout that was moved OUTBOARD on 2026-08-16 -- until then
	#    the plate hung between the viewer and the glass and the lunette had
	#    been fully occluded since V1, which is why no night frame ever showed
	#    it. Aimed north, up the aisle.
	#
	#    Ungoverned is not a convenience here. At y 6.30 the rig's storey rule
	#    resolves F02 and would gate this off for every player standing on
	#    F01, i.e. always. A light nobody can reach, that stays lit, is the
	#    brief's first sanctioned abnormality; escaping the storey rule is
	#    how it earns that rather than by a name-prefix trick.
	var lunette := SpotLight3D.new()
	lunette.name = "PassageLunetteKey"
	lunette.position = Vector3(14.0, 6.30, 64.61)
	lunette.rotation_degrees = Vector3(-6.0, 180.0, 0.0)
	lunette.spot_angle = 38.0
	lunette.spot_range = 14.0
	lunette.shadow_enabled = false
	pass_root.add_child(lunette)

	# 3. INSIDE the lantern drum. The station added to VantryDepthShot
	#    immediately showed the crossing lantern reading as a BLACK SQUARE in
	#    the ceiling at midday, with bright glazed roof either side of it: the
	#    diaphragms are `glassish`, an opaque material with a 0.35/0.45/0.5
	#    base colour, and nothing was lighting them from within. A lantern
	#    that is darker than the roof around it is not a lantern.
	#
	#    The shaft above sits BELOW the diaphragms and aims down, so it lights
	#    the floor and never the lantern. This one lives in the drum, where a
	#    real one's lamp would be, and lights the glazing from inside.
	var drum := OmniLight3D.new()
	drum.name = "PassageLanternDrum"
	drum.position = Vector3(14.0, 10.50, 51.6)
	drum.omni_range = 6.0
	drum.shadow_enabled = false
	pass_root.add_child(drum)

	# 4. UNDER the diaphragms, inside the well. The drum omni above lights
	#    the TOP of the glazing, and the face the player sees from the aisle
	#    is the underside -- which is why the first attempt lifted the panel
	#    out of black but left it dimmer than the roof beside it. A lantern
	#    reads bright because its own glass is bright toward you.
	#
	#    Two, spread across the well rather than one at its centre, so the
	#    coffered underside gets modelling instead of a single hot spot.
	for wi in range(2):
		var well := OmniLight3D.new()
		well.name = "PassageLanternWell%d" % wi
		well.position = Vector3(14.0, 9.55, 51.6 + (1.6 if wi == 0 else -1.6))
		well.omni_range = 7.5
		well.shadow_enabled = false
		pass_root.add_child(well)

	_passage_light_pass = pass_root
	passage_runtime_nodes.append(pass_root)
	_tune_passage_lights()


## Both lights follow the hour through DayNightDirector's own pull API, which
## has existed with zero callers.
func _tune_passage_lights() -> void:
	if _passage_light_pass == null or day_night_director == null:
		return
	var profile: Dictionary = day_night_director.resolved_profile()
	if profile.is_empty():
		return
	var sky: Color = profile.get("fog", Color(0.2, 0.22, 0.26))
	var day_weight := clampf(sky.get_luminance() * 3.4, 0.0, 1.0)
	var shaft := _passage_light_pass.get_node_or_null(
			"PassageCrossingShaft") as SpotLight3D
	if shaft:
		shaft.light_color = Color(0.86, 0.89, 0.98).lerp(
				Color(0.62, 0.70, 0.92), 1.0 - day_weight)
		shaft.light_energy = lerpf(0.12, 0.90, day_weight)
	var drum := _passage_light_pass.get_node_or_null(
			"PassageLanternDrum") as OmniLight3D
	if drum:
		# Bright by day so the lantern is the brightest thing overhead, and
		# never fully out: a glass lantern over a covered arcade catches
		# streetlight and sky even at three in the morning.
		drum.light_color = Color(0.94, 0.95, 1.00).lerp(
				Color(0.74, 0.80, 0.96), 1.0 - day_weight)
		drum.light_energy = lerpf(0.90, 3.60, day_weight)
	for wi in range(2):
		var well := _passage_light_pass.get_node_or_null(
				"PassageLanternWell%d" % wi) as OmniLight3D
		if well:
			well.light_color = Color(0.96, 0.96, 1.00).lerp(
					Color(0.80, 0.85, 0.98), 1.0 - day_weight)
			well.light_energy = lerpf(0.70, 2.60, day_weight)
	var lunette := _passage_light_pass.get_node_or_null(
			"PassageLunetteKey") as SpotLight3D
	if lunette:
		# The lunette does NOT follow the hour down. It is the thing that is
		# always lit and cannot be reached.
		lunette.light_color = Color(0.98, 0.86, 0.58)
		lunette.light_energy = 1.25


func _spawn_npc_placeholders() -> void:
	var count := 0
	var animated_count := 0
	for spec in NPC_RESIDENTS:
		var unit: String = spec.unit
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") != unit:
				continue
			if candidate.get("kind", "") == "living" \
					or str(candidate.id).ends_with("_MAIN"):
				room = candidate
				break
		if room.is_empty():
			# Studios without a MAIN tag still receive the largest unit room.
			var best_area := -1.0
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") != unit:
					continue
				var rect: Array = candidate.rect
				var area := (float(rect[2]) - float(rect[0])) \
						* (float(rect[3]) - float(rect[1]))
				if area > best_area:
					best_area = area
					room = candidate
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var slot: float = float(spec.get("slot", 0))
		var x := lerpf(float(rect[0]), float(rect[2]), 0.52) + slot * 0.48
		var y := lerpf(float(rect[1]), float(rect[3]), 0.58)
		var npc: Node3D
		var model_path := "res://assets/characters/%s/%s.gltf" % [
				spec.sprite, spec.sprite]
		if not ResourceLoader.exists(model_path):
			model_path = "res://assets/characters/%s/%s_rigged.glb" % [
					spec.sprite, spec.sprite]
		if USE_RIGGED_RESIDENTS and ResourceLoader.exists(model_path):
			var animated := AnimatedResident.new()
			animated.setup(spec.name, spec.sprite, unit, model_path)
			npc = animated
			animated_count += 1
		else:
			var placeholder := NPCPlaceholder.new()
			placeholder.setup(spec.name,
					"res://assets/npcs/%s.png" % spec.sprite,
					spec.sprite, unit)
			npc = placeholder
		npc.position = GameBoot.b2g([x, y, float(floor_data.z) + 0.03])
		var parent: Node = floor_nodes.get(floor_id, self)
		parent.add_child(npc)
		count += 1
	print("[BUILDING] %d residents spawned (%d rigged, %d sprite fallbacks)" %
			[count, animated_count, count - animated_count])


func _spawn_reality_affected_props() -> void:
	var file := FileAccess.open(
			"res://data/reality_affected_props.json", FileAccess.READ)
	if file == null:
		push_warning("reality affected-prop catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	affected_prop_count = 0
	var catalog_ids := {}
	for cluster in catalog.get("case_clusters", []):
		var unit: String = cluster.unit
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") == unit \
					and candidate.get("kind", "") == "living":
				room = candidate
				break
		if room.is_empty():
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") == unit \
						and str(candidate.id).ends_with("_MAIN"):
					room = candidate
					break
		if room.is_empty():
			continue
		var rect: Array = room.rect
		for spec in cluster.props:
			if catalog_ids.has(spec.id):
				push_error("duplicate reality-affected prop id: " + spec.id)
				continue
			catalog_ids[spec.id] = true
			var prop := RealityAffectedProp.new()
			prop.setup(spec.id, spec.name, spec.kind, cluster.case_id)
			var x := lerpf(float(rect[0]), float(rect[2]), float(spec.u))
			var y := lerpf(float(rect[1]), float(rect[3]), float(spec.v))
			var height := 0.80 if spec.get("surface", "floor") == "table" \
					else 0.04
			prop.position = GameBoot.b2g(
					[x, y, float(floor_data.z) + height])
			floor_nodes[floor_id].add_child(prop)
			if reality_controllers.has(cluster.case_id):
				reality_controllers[cluster.case_id].register_node(prop)
			affected_prop_count += 1
	for spec in catalog.get("shared_props", []):
		if catalog_ids.has(spec.id):
			push_error("duplicate reality-affected prop id: " + spec.id)
			continue
		catalog_ids[spec.id] = true
		var prop := RealityAffectedProp.new()
		prop.setup(spec.id, spec.name, spec.kind)
		prop.position = GameBoot.b2g(spec.position)
		var floor_id: String = spec.get("floor", "F01")
		floor_nodes.get(floor_id, self).add_child(prop)
		affected_prop_count += 1
	var expected_count := int(catalog.get("expected_prop_count",
			affected_prop_count))
	if affected_prop_count != expected_count:
		push_error("reality-affected prop placement mismatch: expected %d, placed %d"
				% [expected_count, affected_prop_count])
	print("[BUILDING] %d reality-affected props placed" %
			affected_prop_count)


func _spawn_reality_controllers() -> void:
	for case_id in RealityCases.definitions:
		var definition: Dictionary = RealityCases.definition(case_id)
		var unit: String = definition.get("unit", "")
		if unit.length() < 2:
			continue
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") == unit \
					and candidate.get("kind", "") == "living":
				room = candidate
				break
		if room.is_empty():
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") == unit \
						and str(candidate.id).ends_with("_MAIN"):
					room = candidate
					break
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var corner_a := GameBoot.b2g(
				[float(rect[0]), float(rect[1]), float(floor_data.z)])
		var corner_b := GameBoot.b2g(
				[float(rect[2]), float(rect[3]), float(floor_data.z) + 3.0])
		var bounds_min := Vector3(
				minf(corner_a.x, corner_b.x),
				minf(corner_a.y, corner_b.y),
				minf(corner_a.z, corner_b.z))
		var bounds_max := Vector3(
				maxf(corner_a.x, corner_b.x),
				maxf(corner_a.y, corner_b.y),
				maxf(corner_a.z, corner_b.z))
		var controller := ApartmentRealityController.new()
		controller.setup(case_id, unit, bounds_min, bounds_max)
		floor_nodes[floor_id].add_child(controller)
		reality_controllers[case_id] = controller
	print("[BUILDING] %d apartment reality controllers ready" %
			reality_controllers.size())


func _spawn_character_memory_art() -> void:
	_spawn_character_art_catalog(
			"res://data/character_memory_art.json",
			"character memory-art", "character memory artworks")


func _spawn_character_wall_art() -> void:
	_spawn_character_art_catalog(
			"res://data/character_wall_art.json",
			"character wall-art", "character-specific wall artworks",
			"character_wall_art")


func _spawn_hallway_art() -> void:
	var file := FileAccess.open("res://data/hallway_art.json", FileAccess.READ)
	if file == null:
		push_warning("hallway-art catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var count := 0
	for spec in catalog.get("pieces", []):
		var floor_id: String = spec.floor
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty() or not floor_nodes.has(floor_id):
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.id == spec.room:
				room = candidate
				break
		if room.is_empty():
			continue
		spec["collection"] = "hallway_art"
		var art := CharacterMemoryArt.new()
		art.setup(spec)
		var spot := _legal_art_spot(floor_data, room,
				str(spec.get("wall", "north")),
				float(spec.get("along", 0.5)),
				float(spec.get("height", 1.52)))
		if not spot.ok:
			push_warning("no legal wall for hallway piece %s"
					% spec.get("id", "?"))
			art.queue_free()
			continue
		art.position = GameBoot.b2g([
				spot.x, spot.y, float(floor_data.z) + float(spot.height)])
		art.rotation.y = spot.yaw
		floor_nodes[floor_id].add_child(art)
		count += 1
	var expected := int(catalog.get("expected_count", count))
	if count != expected:
		push_error("hallway-art mismatch: expected %d, placed %d"
				% [expected, count])
	print("[BUILDING] %d hallway artworks placed" % count)


func _build_front_entry_details() -> void:
	# Main street door is F01_DOOR_06 at Blender y=-9.795. Both pieces sit
	# beyond the south facade and face the sidewalk.
	# The door's sconce is authored in gen_layout as F01_ENTRY_SCONCE, not
	# built here. A fixture spawned outside the marker pipeline is invisible
	# to the generator's fixture manifest, which then reports one fewer
	# light than the building actually has — and that manifest is what the
	# lighting audit checks itself against.
	var entry_sign := BuildingEntrySign.new()
	entry_sign.position = GameBoot.b2g([0.72, -9.905, 1.58])
	add_child(entry_sign)
	# The marquee's structure ships in floor_01.gltf; its lamps and its
	# name panel cannot. Same origin as the Blender assembly - the facade
	# face at the door centreline - so the two stay welded together.
	# The building's notice board, on the left of the walk from the street
	# door to the stairs, facing east into the route.
	var notices := LobbyBulletinBoard.new()
	# Clear of the dado. At 1.52 the board's lower third sat on the
	# beadboard and the rail ran straight through it; a notice board is
	# hung on the wall above the panelling, never across it.
	notices.position = GameBoot.b2g([-3.14, -5.00, 1.80])
	notices.rotation.y = PI * 0.5
	floor_nodes["F01"].add_child(notices)
	var marquee := EntranceMarqueeDress.new()
	marquee.position = GameBoot.b2g([0.0, -10.00, 0.0])
	add_child(marquee)
	# Cellar light up through the pavement prisms. Origins and panel sizes
	# match the vault_lights assemblies in gen_layout exactly; if one moves
	# the other has to move with it.
	for spec in [[-2.60, -10.72, 2.60, 1.15], [4.10, -10.72, 1.85, 1.15]]:
		var vault := VaultLightGlow.new()
		vault.panel_w = spec[2]
		vault.panel_d = spec[3]
		vault.position = GameBoot.b2g([spec[0], spec[1], 0.052])
		add_child(vault)
	print("[BUILDING] front-door exterior light and signage placed")


func _build_original_orison_ad_board() -> void:
	# Moved off the east wall 2026-08-05. It was hung at y -8.40 and the
	# mail bank sits at -8.85: at 1.42 m wide against the bank's 1.58 m,
	# the board buried 1.05 m of the boxes and stood 70 mm proud of them,
	# so the mail corner read as a frame with some cardboard behind it.
	# The lobby's east run has only 1.13 m clear beside the bank, which
	# the board does not fit into — so it changes walls rather than slides.
	#
	# The west run is 2.72 m of unbroken plaster (its only door is five
	# metres north) and it is the left-hand side of the walk from the
	# street door to the stairs, which is where a notice board belongs.
	# Centred at -8.29 it hangs directly opposite the lobby chandelier,
	# clears the south-wall radiator (which ends at y -9.2) by 200 mm,
	# and still owns the view immediately after the front door.
	var board := LobbyOrisonAdBoard.new()
	board.position = GameBoot.b2g([-5.17, -8.29, 1.52])
	board.rotation.y = PI * 0.5
	floor_nodes["F01"].add_child(board)


func _spawn_character_art_catalog(path: String, error_label: String,
		report_label: String, collection := "character_memories") -> void:
	var file := FileAccess.open(
			path, FileAccess.READ)
	if file == null:
		push_warning(error_label + " catalog missing")
		return
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	var count := 0
	for spec in catalog.get("pieces", []):
		spec["collection"] = collection
		var unit: String = spec.unit
		var floor_id := "F0" + unit.left(1)
		var floor_data: Dictionary = {}
		for candidate in layout["floors"]:
			if candidate.id == floor_id:
				floor_data = candidate
				break
		if floor_data.is_empty():
			continue
		var room: Dictionary = {}
		for candidate in floor_data["rooms"]:
			if candidate.get("unit", "") == unit \
					and candidate.get("kind", "") == "living":
				room = candidate
				break
		if room.is_empty():
			for candidate in floor_data["rooms"]:
				if candidate.get("unit", "") == unit \
						and str(candidate.id).ends_with("_MAIN"):
					room = candidate
					break
		if room.is_empty():
			continue
		var rect: Array = room.rect
		var art := CharacterMemoryArt.new()
		art.setup(spec)
		if spec.get("placement", "wall") == "tabletop":
			var wanted_x := lerpf(float(rect[0]), float(rect[2]),
					float(spec.get("u", 0.5)))
			var wanted_y := lerpf(float(rect[1]), float(rect[3]),
					float(spec.get("v", 0.5)))
			var surface := _nearest_art_surface(floor_data, room,
					Vector2(wanted_x, wanted_y))
			var x: float = surface.x
			var y: float = surface.y
			art.position = GameBoot.b2g(
					[x, y, float(floor_data.z) + float(surface.height)])
			art.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
		else:
			# The character chose the wall; the legality pass chooses the
			# exact hook — real wall behind, no opening through it, no
			# tall furniture against it — sliding along before conceding
			# a different wall. Pieces with nowhere legal are not hung.
			var spot := _legal_art_spot(floor_data, room,
					str(spec.get("wall", "north")),
					float(spec.get("along", 0.5)),
					float(spec.get("height", 1.52)))
			if not spot.ok:
				push_warning("no legal wall for %s in %s"
						% [spec.get("id", "?"), unit])
				art.queue_free()
				continue
			art.position = GameBoot.b2g(
					[spot.x, spot.y, float(floor_data.z) +
					float(spot.height)])
			art.rotation.y = spot.yaw
		floor_nodes[floor_id].add_child(art)
		count += 1
	var expected := int(catalog.get("expected_count", count))
	if count != expected:
		push_error("%s mismatch: expected %d, placed %d"
				% [error_label, expected, count])
	print("[BUILDING] %d %s placed" % [count, report_label])


## The old tabletop portraits were suspended at z=.82 wherever their u/v
## landed. Choose the nearest plausible horizontal furniture surface instead;
## this keeps keepsakes on desks/tables and out of bodies, floors, and walls.
func _nearest_art_surface(floor_data: Dictionary, room: Dictionary,
		wanted: Vector2) -> Dictionary:
	var rr: Array = room.rect
	var best := {"x": wanted.x, "y": wanted.y, "height": 0.82}
	var best_distance := INF
	for fu in floor_data.get("furniture", []):
		if not fu.has("rect"):
			continue
		var r: Array = fu.rect
		var cx := (float(r[0]) + float(r[2])) * 0.5
		var cy := (float(r[1]) + float(r[3])) * 0.5
		if cx < float(rr[0]) or cx > float(rr[2]) \
				or cy < float(rr[1]) or cy > float(rr[3]):
			continue
		var top := float(fu.get("z0", 0.0)) + float(fu.get("h", 0.0))
		var width := absf(float(r[2]) - float(r[0]))
		var depth := absf(float(r[3]) - float(r[1]))
		if top < 0.58 or top > 1.08 or width < 0.38 or depth < 0.30:
			continue
		if WallArtLaw.surface_blocks(room, cx, cy, top + 0.025, 0.20):
			continue
		var distance := wanted.distance_to(Vector2(cx, cy))
		if distance < best_distance:
			best_distance = distance
			best = {"x": cx, "y": cy, "height": top + 0.025}
	return best


## Finds a spot on a room wall where a picture can actually hang: a real
## wall segment behind it, no door or window cut through it at frame
## height, no furniture pressed against it. Tries the authored position
## first — the character chose that wall — then slides along the same wall,
## then concedes other walls. Returns {ok, x, y, yaw, wall}.
## Delegates to WallArtLaw — one law for every picture hook, shared with
## FoundArtPass and the story-decal placements. (The in-file original
## read openings from a key named "cuts" that the generator never wrote,
## so its doorway check never fired; the law reads the real key and also
## keeps art off the wainscot rail.)
func _legal_art_spot(floor_data: Dictionary, room: Dictionary,
		want_wall: String, want_along: float, height: float) -> Dictionary:
	return WallArtLaw.legal_spot(floor_data, room, want_wall, want_along,
			height)


func teleport_player(fid: String) -> void:
	var z: float = layout["meta"]["levels"][fid]
	if fid == "ROOF":
		player.global_position = GameBoot.b2g([0.0, -8.0, z + 0.1])
	else:
		player.global_position = GameBoot.b2g([4.3, 0.0, z + 0.1])
	player.velocity = Vector3.ZERO


func _physics_process(_delta: float) -> void:
	_update_floor_visibility()


## Coarse streaming: only the player's level renders — EXCEPT in the atrium,
## where the open eye is a sightline
## through every storey (lobby runner to skylight), so the whole stack
## renders there. The zone spans the stair volume plus the elevator
## hall, whose archway frames the same view. Each imported floor owns the
## opposite wall at its own height, so a court-window view does not require
## the 220 x 148 m F01 site or the storeys above and below it. Keeping those
## hidden shells used to multiply 3,431 meshes through every shadow view.
## A free camera is the eye when one is flying; the player's parked body
## is not. Without this the debug camera renders whatever floor the body
## happens to stand on, and forcing the whole stack on instead costs a
## frame that never finishes.
var view_override: Node3D


func _update_floor_visibility() -> void:
	var eye: Vector3
	if view_override != null and is_instance_valid(view_override):
		eye = view_override.global_position
	elif player != null:
		eye = player.global_position
	else:
		return
	var key := _visibility_signature(eye)
	if _visibility_cache_enabled and key == _visibility_key:
		return
	_apply_visibility(eye)


## Packs every boolean that `_apply_visibility()` can derive from a viewpoint.
## This still checks the eight authored storey elevations, but replaces the
## old per-tick walk over ~600 props and 120 doors with eight cheap comparisons.
func _visibility_signature(p: Vector3) -> int:
	var in_passage := _point_is_in_passage(p)
	var in_eye := absf(p.x) < 3.7 and p.z > -3.7 and p.z < 6.9
	var outside := not in_passage \
			and (absf(p.x) > OUTSIDE_HALF_X or absf(p.z) > OUTSIDE_HALF_Z)
	var low_street := _point_is_low_street(p)
	var key := (1 if show_all_floors else 0) \
			| ((1 if in_passage else 0) << 1) \
			| ((1 if in_eye else 0) << 2) \
			| ((1 if outside else 0) << 3) \
			| ((1 if low_street else 0) << 4)
	var bit := 5
	for fid in floor_nodes:
		var z: float = layout["meta"]["levels"][fid]
		# Must stay identical to `_apply_visibility`'s `should_show`, including
		# the Passage term: this key is the cache's whole claim that nothing
		# changed, and a signature that models a different rule than the one
		# applied would skip a frame that needed applying.
		var floor_visible: bool = show_all_floors or in_eye or outside \
				or (in_passage and fid == "F01") \
				or absf(p.y - z) < 1.75 \
				or (fid == "ROOF" and p.y > 15.0)
		var props_visible: bool = show_all_floors or in_eye or outside \
				or (in_passage and fid == "F01") \
				or absf(p.y - z) < 1.75 \
				or (fid == "ROOF" and p.y > 15.0)
		key |= (1 if floor_visible else 0) << bit
		key |= (1 if props_visible else 0) << (bit + 1)
		bit += 2
	return key


func _apply_visibility(p: Vector3) -> void:
	# Explicit callers always apply, even when the derived region is unchanged.
	# Record the answer afterward so the next ordinary physics tick can skip.
	_visibility_key = _visibility_signature(p)
	_visibility_apply_count += 1
	var in_passage := _point_is_in_passage(p)
	# Restore STREET's blocker before Passage decides its own eligibility. The
	# shared layer-block table keeps direct portal transitions correct in either
	# direction even where both gates own the same F01 node.
	_set_street_core_visibility(not _point_is_low_street(p))
	_set_passage_visibility(in_passage)
	if commensals:
		commensals.set_visibility_context(p)
	var in_eye := absf(p.x) < 3.7 and p.z > -3.7 and p.z < 6.9
	# Outside the shell you are looking AT the building, and a
	# building that renders two storeys is a stage flat. The envelope is 28
	# by 20 metres and the margin is 150 mm — see OUTSIDE_HALF_X for what
	# the old metre of it was costing along every facade.
	# PASSAGE is geometrically south of the old site envelope, but it is not an
	# exterior camera. Treating it as `outside` submitted all eight Orison floors
	# through the north end of the glass hall: 16.7k objects northbound versus
	# 6.5k southbound in the same zone. Its imported shell lives on F01; the
	# apartment stack is neither visible nor owned here.
	var outside := not in_passage \
			and (absf(p.x) > OUTSIDE_HALF_X or absf(p.z) > OUTSIDE_HALF_Z)
	for fid in floor_nodes:
		var z: float = layout["meta"]["levels"][fid]
		# `in_passage` belongs here for the same reason it belongs in the prop
		# rule below, and its absence was a real defect rather than a spare
		# clause. The Passage hall IS F01 — its shell, vault and shopfronts are
		# parented into that floor node — while `_point_is_in_passage` admits an
		# eye anywhere from -0.50 to 5.80 m, because the glass crown reaches
		# 5.55. Between 1.75 and 5.80 the storey rule therefore culled the floor
		# out from under a zone that was still reporting itself active, and
		# Godot's hierarchical visibility took the whole arcade down with it.
		# The props escaped, being root-owned and already exempted one clause
		# down, which is why the symptom was an aisle pendant hanging alone in
		# the night sky rather than an obviously empty frame. Costs nothing at
		# standing height: a body's origin is its feet, so a player in the hall
		# already satisfied the 1.75 window and this term never fires for them.
		var should_show: bool = show_all_floors or in_eye or outside \
				or (in_passage and fid == "F01") \
				or absf(p.y - z) < 1.75 or (fid == "ROOF" and p.y > 15.0)
		if floor_nodes[fid].visible != should_show:
			floor_nodes[fid].visible = should_show
		# Props are root-owned for discovery, not floor-owned for inheritance.
		# Give them the same active-storey rule: from a corridor or flat there is
		# no legal view into the kitchen above.
		#
		# The exterior term used to read `(outside or in_passage) and fid ==
		# "F01"`, so a view from the street kept every floor's SHELL and only the
		# ground floor's CONTENTS: a lit apartment three storeys up was an empty
		# room behind glass. That asymmetry was sized for a submission budget
		# §DP's ruling retired ("dont worry about budget until we hit performance
		# issues on a desktop"), and the owner opened it to every floor on
		# 2026-08-18. The exterior clause now matches the floor rule exactly. The
		# Passage term stays F01-only because the Passage IS F01, and that clause
		# is about its own hall rather than the apartment stack above it.
		var show_props: bool = show_all_floors or in_eye or outside \
				or (in_passage and fid == "F01") \
				or absf(p.y - z) < 1.75 \
				or (fid == "ROOF" and p.y > 15.0)
		for prop in functional_props_by_floor.get(fid, []):
			var passage_owned: bool = prop.is_in_group("passage_runtime")
			var zone_visible: bool = show_all_floors \
					or (passage_owned if in_passage else not passage_owned)
			var should_show_prop := show_props and zone_visible
			if prop.visible != should_show_prop:
				prop.visible = should_show_prop
		for door in doors_by_floor.get(fid, []):
			var passage_owned: bool = door.is_in_group("passage_runtime")
			var zone_visible: bool = show_all_floors \
					or (passage_owned if in_passage else not passage_owned)
			var should_show_door := show_props and zone_visible
			if door.visible != should_show_door:
				door.visible = should_show_door


## Godot z is the negation of the ruled Blender y controls.  The portal plane
## at z=28.316 belongs to STREET; crossing it enters the 6 m throat, which then
## expands into the exact 20 x 26 m hall fixed by Check 3.
func _point_is_in_passage(p: Vector3) -> bool:
	# The glass crown reaches 5.55 m. Without a vertical bound the old aerial
	# street-elevation benchmark at x=16/z=34/y=12 became a Passage camera and
	# hid the apartment facade it was explicitly meant to measure.
	var in_height := p.y >= -0.50 and p.y <= 5.80
	var in_throat := in_height and p.x >= 11.0 and p.x <= 17.0 \
			and p.z > 28.316 and p.z <= 38.6
	var in_hall := in_height and p.x >= 4.0 and p.x <= 24.0 \
			and p.z > 38.6 and p.z <= 64.6
	return in_throat or in_hall


## The precipitation owner asks the building, rather than inferring exposure
## from one height. STREET and the open roof get rain; the atrium, apartments,
## basement and the roofed Vantry Arcade do not. This is deliberately the
## same Passage predicate as the render/navigation gates.
func weather_exposure_at(p: Vector3) -> bool:
	if _point_is_in_passage(p):
		return false
	if p.y > 18.25:
		return p.x >= -14.8 and p.x <= 14.8 \
				and p.z >= -10.5 and p.z <= 10.5
	if p.y < -0.45 or p.y > 2.25:
		return false
	return absf(p.x) > 14.2 or p.z > 10.4 or p.z < -10.4


func _point_is_low_street(p: Vector3) -> bool:
	# Retained same-build control for T7c measurement and A/A/B renders.
	if OS.get_environment("PERF_STREET_CORE_GEOMETRY_ON") == "1":
		return false
	return not _point_is_in_passage(p) \
			and p.y >= -0.45 and p.y <= 2.25 \
			and (absf(p.x) > 15.2 or absf(p.z) > 11.2)


## Exterior cover is not the same thing as an interior. The T5 transit shelter
## remains visibly surrounded by STREET rain while its roof suppresses the
## player-following close streaks and ground spatter. Coordinates are the
## exact generated 4.4 x 1.4 m footprint, expressed in Godot axes.
func weather_cover_at(p: Vector3) -> bool:
	return p.y >= -0.10 and p.y <= 2.57 \
			and p.x >= -12.60 and p.x <= -8.20 \
			and p.z >= 25.55 and p.z <= 26.95


func _set_passage_visibility(should_show: bool) -> void:
	if passage_visible == should_show:
		return
	# Sweep before toggling, on the transition and only on the transition:
	# whatever was built asynchronously since the last crossing gets its
	# ownership decided now, before either zone renders a frame of it.
	_index_late_f01_geometry()
	passage_visible = should_show
	for geometry in passage_interior_nodes:
		geometry.visible = should_show
	for geometry in passage_shell_nodes:
		geometry.visible = should_show
	for geometry in passage_foreign_f01_nodes:
		geometry.visible = not should_show
	# Late-built geometry may have another legitimate visibility writer
	# (window glow sleeps quads, cabinets stage their boot), so the zone
	# gate saves what it hides and restores exactly that — forcing true
	# here would wake geometry some other system deliberately put down.
	for geometry in passage_late_interior_nodes:
		if is_instance_valid(geometry):
			_zone_toggle(geometry, should_show)
	for geometry in passage_late_foreign_nodes:
		if is_instance_valid(geometry):
			_zone_toggle(geometry, not should_show)
	# Lights are gated by SHADOW, not visibility. Their `visible` has other
	# legitimate writers (day/night, directors) and a save/restore stomped
	# them — the first treatment run doubled object counts at the interior
	# stations by re-lighting lamps another system had put out. Nothing
	# else writes shadow_enabled on non-fixture scene lights, the caster
	# re-renders are the entire measured cost, and the lamp's LIGHT still
	# shines identically in both zones, so there is no visual state to
	# get wrong.
	for light in passage_foreign_lights:
		if not is_instance_valid(light):
			continue
		var id := light.get_instance_id()
		if should_show:
			if not passage_light_saved.has(id):
				passage_light_saved[id] = light.shadow_enabled
			light.shadow_enabled = false
		elif passage_light_saved.has(id):
			light.shadow_enabled = passage_light_saved[id]
			passage_light_saved.erase(id)
	for actor in passage_runtime_nodes:
		if actor.has_method("set_passage_active"):
			actor.set_passage_active(should_show)
		else:
			actor.visible = should_show


func _set_street_core_visibility(should_show: bool) -> void:
	if street_core_visible == should_show:
		return
	# A transition is the deterministic late-build sweep. Gameplay takes several
	# seconds to reach the pavement, but async arcade screens are still handled
	# rather than being assumed complete after `_ready`.
	_index_street_core_geometry()
	street_core_visible = should_show
	for geometry in street_core_nodes:
		if is_instance_valid(geometry):
			_zone_toggle(geometry, should_show, "street_core")


## LAYERS, not `visible`. Visibility has co-writers — the root-parented
## passes gate their own children per floor, window glow sleeps quads,
## cabinets stage their boot — and a visible save/restore stomped them
## with state captured on the other side of the portal (the treatment
## runs gained two thousand objects at the F04 corridor from signage
## forced visible on the wrong floor). Nothing else writes render
## layers, and layers == 0 removes a node from every camera and every
## light's shadow pass at once, so the zone gate composes with the
## owners instead of contending: a node renders when its owner shows it
## AND the zone allows it.
func _zone_toggle(node: Node3D, eligible: bool,
		blocker := "passage") -> void:
	var vi := node as VisualInstance3D
	if vi == null:
		return
	var id := vi.get_instance_id()
	var blocks: Dictionary = _zone_layer_blocks.get(id, {})
	if eligible:
		blocks.erase(blocker)
	else:
		if not passage_late_saved.has(id):
			passage_late_saved[id] = vi.layers
		blocks[blocker] = true
	if blocks.is_empty():
		_zone_layer_blocks.erase(id)
		if passage_late_saved.has(id):
			vi.layers = passage_late_saved[id]
			passage_late_saved.erase(id)
	else:
		_zone_layer_blocks[id] = blocks
		vi.layers = 0
