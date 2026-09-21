class_name OrisonV2RuntimeRoot
extends Node3D
## Production-service composition over the v2 collision construction.
## Domain behavior remains in the existing production classes below.

const BLOCKOUT := preload("res://scenes/building/orison_v2_blockout.tscn")
const CUES := preload("res://scripts/building/orison_v2_readability_cues.gd")
const Adapter := preload("res://scripts/building/orison_v2_anchor_adapter.gd")
const FrameContract := preload("res://scripts/building/orison_v2_frame_contract.gd")
const LineageRegistry := preload("res://scripts/reality/corruption_lineage_registry.gd")
const WorldConnection := preload("res://scripts/building/orison_v2_world_connection.gd")
const ExteriorResolver := preload("res://scripts/building/orison_v2_exterior_spatial_resolver.gd")
const ExteriorCell := preload("res://scripts/building/orison_v2_exterior_cell.gd")
const ShopSimulation := preload("res://scripts/building/orison_v2_shop_simulation.gd")
const Atmosphere := preload("res://scripts/building/orison_v2_atmosphere.gd")
const DomesticFittings := preload("res://scripts/building/orison_v2_domestic_fittings.gd")
const DomesticFurniture := preload("res://scripts/building/orison_v2_domestic_furniture.gd")
const RoomLighting := preload("res://scripts/building/orison_v2_room_lighting.gd")
const DomesticDoors := preload("res://scripts/building/orison_v2_domestic_doors.gd")
const PassageRegion := preload("res://scripts/building/orison_v2_passage_region.gd")
const StreetBoundaries := preload("res://scripts/building/orison_v2_street_boundaries.gd")
const HouseholdState := preload("res://scripts/building/orison_v2_household_state.gd")

var layout: Dictionary = {}
var floor_nodes: Dictionary = {}
var player: PlayerController
var objective_tracker: ObjectiveTracker
var work_orders: WorkOrders
var maintenance_inventory: MaintenanceInventory
var vantry_points: VantryPointNetwork
var chirp_hunt: ChirpHunt
var call_interface: CallInterface
var virus_director: VirusSoundDirector
var mina_gameplay: MinaCaseGameplay
var core_loop: CoreLoopDirector
var safety_net: SafetyNet
var service_set_carrier: ServiceSetCarrier
var first_shift_director: FirstShiftDirector
var service_round: ServiceRoundDirector
var boiler_tend: BoilerTend
var heat_balance: HeatBalance
var mirror_renderer: PlanarMirrorRenderer
var household_state: HouseholdState
var open_shift_ecosystem: Node
var observation_ledger: NpcObservationLedger
var resident_presence: ScheduleDirector
var mina_routine: Node3D
var campaign_clock: CampaignClock
var corruption_lineages: CorruptionLineageRegistry
var watch_station_network: WatchStationNetwork
var street_traffic: Node = null
var elevator: Node = null
var startup_failed := false
var startup_failure_reason := ""
var startup_ms := 0.0
var adapter
var _blockout: Node3D
var frame_contract: OrisonV2FrameContract
var exterior_cell: OrisonV2ExteriorCell
var passage_region: OrisonV2PassageRegion
var shop_service: MaintenanceShopService
var shop_simulation: Node
var day_night_director: DayNightDirector
var light_rig: LightRig
var touch: TouchControls
var shots: ShotCapture
var warehouse: PropWarehouse
var view_override: Camera3D
var _exterior_resolver: Variant
var _connection: Dictionary = {}

func _read_street_frame() -> Dictionary:
	return preload("res://scripts/building/orison_v2_street_frame.gd").load_default()

func _ready() -> void:
	# Refuse the source boundary before creating campaign services, imported
	# geometry or any actor. Child _ready errors cannot close startup for us.
	if not preload("res://scripts/building/orison_v2_street_frame.gd").valid_source_header(_read_street_frame()):
		startup_failed = true
		startup_failure_reason = "missing or invalid street coordinate frame"
		return
	var started := Time.get_ticks_usec()
	campaign_clock = CampaignClock.new()
	if not campaign_clock.bind_state():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: valid campaign calendar required")
		return
	frame_contract = FrameContract.load_default()
	if not frame_contract.errors.is_empty():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: invalid shared-frame contract: %s" %
				[frame_contract.errors])
		return
	corruption_lineages = LineageRegistry.new()
	if not corruption_lineages.load_registry():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: invalid corruption lineage registry")
		return
	add_to_group("building_root")
	add_to_group("orison_v2_runtime")
	var atmosphere := Atmosphere.new()
	atmosphere.name = "WakingAtmosphere"
	add_child(atmosphere)
	day_night_director = atmosphere.director
	_blockout = BLOCKOUT.instantiate()
	_blockout.show_clearance_anchors = false
	_blockout.show_reservation_volumes = false
	_blockout.production_materials = true
	_exterior_resolver = ExteriorResolver.load_default()
	_connection = WorldConnection.prepare(
			WorldConnection.read_object(_blockout.layout_path),
			WorldConnection.read_object(ExteriorCell.GEOMETRY_PATH),
			_exterior_resolver, WorldConnection.read_object(WorldConnection.CONFIG_PATH))
	if _connection.is_empty():
		_blockout.free()
		_blockout = null
		startup_failed = true
		push_error("ORISON V2 RUNTIME: front-door world connection refused")
		return
	_blockout.transform = _connection.interior_transform
	_blockout.space_geometry_exclusions.assign([_connection.excluded_space])
	add_child(_blockout)
	if not _blockout.failures.is_empty():
		startup_failed = true
		return
	layout = _blockout.layout
	for level: Dictionary in layout.get("levels", []):
		floor_nodes[str(level.id)] = _blockout
	adapter = Adapter.new(_blockout)
	if not adapter.resolves_required_uniquely():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: unresolved or duplicate required anchor")
		return
	var cues := CUES.new()
	cues.show_bed_context = false
	cues.show_terminal_context = false
	_blockout.add_child(cues)
	if not adapter.install_acoustic_overrides([
			"F02_A_MAIN_VANTRY_POINT", "F02_A_MONITOR_01",
			"F04_B_MONITOR_01", "F03_B_RADIATOR_01"]):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: acoustic binding failed")
		return
	_compose_authorities()
	if startup_failed:
		return
	var lamp_air := preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new()
	lamp_air.name = "LampAtmosphere"
	add_child(lamp_air)
	if not lamp_air.setup(player, atmosphere.environment):
		startup_failed = true
		push_error("V2 lamp optical state could not be restored")
		return
	_compose_debug_controls()
	startup_ms = float(Time.get_ticks_usec() - started) / 1000.0
	print("[ORISON V2 RUNTIME] ready startup_ms=%.3f" % startup_ms)

func _compose_authorities() -> void:
	objective_tracker = ObjectiveTracker.new()
	objective_tracker.name = "ObjectiveTracker"
	objective_tracker.presentation_enabled = false
	add_child(objective_tracker)
	work_orders = WorkOrders.new()
	work_orders.name = "WorkOrders"
	work_orders.setup(objective_tracker)
	work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(work_orders)
	maintenance_inventory = MaintenanceInventory.new()
	maintenance_inventory.name = "MaintenanceInventory"
	maintenance_inventory.setup()
	add_child(maintenance_inventory)
	_compose_vantry()
	_mount("LobbyMailBank", MailBankProp.new())
	_mount("LobbyPorterBoard", OtisProp.new())
	_compose_service_round_props()
	if startup_failed: return
	if not DomesticDoors.new().mount(adapter, layout):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: domestic door mounting refused")
		return
	if not preload("res://scripts/building/orison_v2_upper_floor_doors.gd").new().mount(adapter, layout):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: upper floor door mounting refused")
		return
	var fittings := DomesticFittings.new()
	if not fittings.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: domestic fittings refused: %s" % [fittings.errors])
		return
	if not _compose_hot_water():
		return
	var furniture := DomesticFurniture.new()
	if not preload("res://scripts/building/orison_v2_laundry.gd").new().mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: laundry mounting refused")
		return
	if not furniture.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: furniture refused: %s" % [furniture.errors])
		return
	# All replacement fittings/furniture now exist. Standalone gray-box scenes
	# retain their masses; the playable apartment has one physical owner per use.
	for identity in ["F02_B_FABRIC_TABLE_MASS", "F02_B_KITCHEN_RUN_MASS",
			"F02_B_BED_MASS", "F02_B_STORAGE_MASS", "F02_B_BATH_MASS"]:
		_retire_blockout_fixture(identity)
	if startup_failed:
		return
	var lighting := RoomLighting.new()
	if not lighting.mount(adapter, self):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: room lighting refused: %s" % [lighting.errors])
		return
	light_rig = LightRig.new()
	light_rig.name = "LightRig"
	get_node("WakingAtmosphere").add_child(light_rig)
	var telephone := HouseSwitchboardProp.new()
	var line := HouseTelephoneNetwork.new()
	line.name = "HouseTelephoneNetwork"
	add_child(line)
	line.register_endpoint({"id": "F02_A_TELEPHONE", "extension": "2A"})
	telephone.bind_line(line)
	_mount("F01_HOUSE_TELEPHONE_BOARD", telephone)
	_mount("LobbyServiceDumbwaiter", DumbwaiterProp.new())
	var terminal := SignalTerminalProp.new()
	terminal.prop_type = "signal_terminal"
	_mount("F04_B_MONITOR_01", terminal)
	player = PlayerController.new()
	player.name = "Player"
	player.position = _connection.arrival.position
	add_child(player)
	if not _compose_exterior():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: exterior composition failed")
		return
	vantry_points.bind_player(player)
	service_set_carrier = ServiceSetCarrier.new()
	service_set_carrier.name = "ServiceSetCarrier"
	service_set_carrier.setup(player, player.camera, work_orders)
	player.carried_device = service_set_carrier
	player.set_lamp_enabled(true)
	call_interface = CallInterface.new()
	call_interface.name = "CallInterface"
	call_interface.world = _blockout
	add_child(call_interface)
	if not _compose_call_station(terminal):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: invalid support desk anchors")
		return
	virus_director = VirusSoundDirector.new()
	virus_director.name = "VirusSoundDirector"
	virus_director.setup(self)
	add_child(virus_director)
	first_shift_director = FirstShiftDirector.new()
	first_shift_director.name = "FirstShiftDirector"
	first_shift_director.setup(self, objective_tracker, virus_director, work_orders)
	add_child(first_shift_director)
	_bind_first_shift_station()
	mina_gameplay = MinaCaseGameplay.new()
	mina_gameplay.name = "MinaCaseGameplay"
	mina_gameplay.setup(objective_tracker, work_orders)
	add_child(mina_gameplay)
	if not preload("res://scripts/building/orison_v2_case_one_placement.gd").new().mount(adapter, mina_gameplay):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: incomplete case-one placement")
		return
	var surface_props := preload("res://scripts/building/orison_v2_surface_props.gd").new()
	if not surface_props.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: surface props refused: %s" % [surface_props.errors])
		return
	var bath_details := preload("res://scripts/building/orison_v2_bath_details.gd").new()
	if not bath_details.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: bathroom details refused: %s" % [bath_details.errors])
		return
	var radios := preload("res://scripts/building/orison_v2_radios.gd").new()
	if not radios.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: household radios refused: %s" % [radios.errors])
		return
	var projectors := preload("res://scripts/building/orison_v2_projectors.gd").new()
	if not projectors.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: apartment projectors refused: %s" % [projectors.errors])
		return
	var accessories := preload("res://scripts/building/orison_v2_household_accessories.gd").new()
	if not accessories.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: household accessories refused: %s" % [accessories.errors])
		return
	var bookshelves := preload("res://scripts/building/orison_v2_bookshelves.gd").new()
	if not bookshelves.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: bookshelves refused: %s" % [bookshelves.errors])
		return
	mirror_renderer = PlanarMirrorRenderer.new()
	add_child(mirror_renderer)
	mirror_renderer.setup(player.camera)
	chirp_hunt = ChirpHunt.new()
	chirp_hunt.name = "ChirpHunt"
	add_child(chirp_hunt)
	chirp_hunt.setup(vantry_points, work_orders, maintenance_inventory)
	var shell := get_tree().get_first_node_in_group("campaign_shell")
	var resolver := Callable(adapter, "resolve_return_anchor")
	if shell != null and shell.is_ancestor_of(self):
		core_loop = shell.call("bind_waking_services", work_orders, player, layout,
				null, null, resolver) as CoreLoopDirector
	else:
		core_loop = CoreLoopDirector.new()
		core_loop.name = "CoreLoopDirector"
		add_child(core_loop)
		core_loop.setup(work_orders, player, layout, resolver)
	mina_gameplay.bind_wake(core_loop)
	first_shift_director.bind_opening_report_offer(
			Callable(core_loop, "offer_opening_report"))
	service_round = ServiceRoundDirector.new()
	service_round.name = "ServiceRoundDirector"
	add_child(service_round)
	service_round.setup(work_orders, _blockout, player, service_set_carrier)
	open_shift_ecosystem = preload("res://scripts/game/open_shift_radiator_ecosystem.gd").new()
	open_shift_ecosystem.name = "OpenShiftRadiatorEcosystem"
	add_child(open_shift_ecosystem)
	var open_shift_radiator := _blockout.get_node_or_null(
			ServiceRoundDirector.RADIATOR_ID) as RadiatorProp
	if open_shift_radiator:
		open_shift_radiator.bind_inventory(maintenance_inventory)
	_compose_observation_ledger()
	mina_routine = preload("res://scripts/characters/orison_v2_mina_routine.gd").new()
	mina_routine.name = "MinaRoutine"
	add_child(mina_routine)
	if not mina_routine.setup(self):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: Mina route composition refused")
		return
	if not preload("res://scripts/building/orison_v2_case_one_placement.gd").new().mount_captions(adapter,mina_routine.actor):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: case caption subjects missing")
		return
	var remote_captions := preload("res://scripts/cases/orison_v2_remote_caption_display.gd").new()
	remote_captions.name = "MinaRemoteCaptions"
	remote_captions.adapter = adapter
	add_child(remote_captions)
	shop_simulation = ShopSimulation.new()
	shop_simulation.name = "ShopSimulation"
	add_child(shop_simulation)
	if not shop_simulation.setup(campaign_clock, resident_presence,
			exterior_cell.shop_bucket_registry, Callable(exterior_cell, "refresh_shop_presentation")):
		startup_failed = true
		return
	open_shift_ecosystem.setup(work_orders, open_shift_radiator,
			service_round, Callable(campaign_clock, "absolute_minutes"),
			observation_ledger, null, Callable(), "campaign_absolute_minutes")
	safety_net = SafetyNet.new()
	safety_net.name = "SafetyNet"
	safety_net.setup(player)
	safety_net.anchor = _connection.arrival.position
	add_child(safety_net)
	household_state = HouseholdState.new()
	household_state.name = "HouseholdState"
	add_child(household_state)
	if not household_state.bind(adapter, get_node("V2RoomSwitches") as SwitchSystem):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: household save refused: %s" % [household_state.errors])
		return

func arrival_placement() -> Dictionary:
	return (_connection.get("arrival", {}) as Dictionary).duplicate(true)


## Share the existing controls and the accepted prop/ecology catalogue. The
## debug shell owns no replacement gameplay or specimen implementations.
func _compose_debug_controls() -> void:
	touch = TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.look_delta.connect(player.apply_look)
	player.touch_input = touch.enabled
	shots = ShotCapture.new()
	shots.name = "ShotCapture"
	add_child(shots)
	if GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG \
			or not OS.get_environment("SHOT_ROOMS").is_empty():
		return
	warehouse = PropWarehouse.new()
	add_child(warehouse)
	warehouse.build(preload("res://scripts/building/building_root.gd").PROP_SCRIPTS)
	safety_net.exempt_zones.append(warehouse.hall_aabb())
	var panel := BuildingDebug.new()
	panel.setup(self)
	var layer := CanvasLayer.new()
	layer.name = "BuildingDebugLayer"
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	layer.add_child(panel)
	shots.chrome = layer


## V2 destinations are in its composed world frame. V1 plan coordinates are
## never valid shortcuts here, especially after visiting an off-site exhibit.
func debug_destinations() -> Dictionary:
	var destinations := {"Arrival": _connection.arrival.position}
	for pair in [["4B desk", "F04_B_MONITOR_STANCE"],
			["4B bedside", "F04_B_BEDSIDE_RETURN"]]:
		var anchor := adapter.resolve(str(pair[1])) as Node3D
		if anchor != null:
			destinations[str(pair[0])] = anchor.global_position + Vector3.UP * 0.05
	return destinations

func _compose_exterior() -> bool:
	shop_service = MaintenanceShopService.new()
	shop_service.name = "MaintenanceShopService"
	add_child(shop_service)
	shop_service.setup(maintenance_inventory, work_orders)
	if not shop_service.is_valid():
		return false
	exterior_cell = ExteriorCell.new()
	exterior_cell.name = "StreetAndBodega"
	if not exterior_cell.configure_dependencies({"player": player,
			"work_orders": work_orders, "maintenance_inventory": maintenance_inventory,
			"shop_service": shop_service, "spatial_resolver": _exterior_resolver,
			"geometry_source": _connection.geometry}):
		exterior_cell.free()
		exterior_cell = null
		return false
	add_child(exterior_cell)
	if exterior_cell.startup_failed:
		return false
	var street_boundaries := StreetBoundaries.new()
	street_boundaries.name = "StreetBoundaries"
	add_child(street_boundaries)
	passage_region = PassageRegion.new()
	passage_region.name = "VantryArcade"
	if not passage_region.configure(shop_service):
		passage_region.free()
		passage_region = null
		return false
	add_child(passage_region)
	if passage_region.startup_failed:
		return false
	if not passage_region.enable_residency(player, _blockout, layout):
		return false
	return bool(exterior_cell.set_route_guides_visible(false).get("ok", false))

func _compose_call_station(terminal: SignalTerminalProp) -> bool:
	var operator := adapter.resolve("F04_B_MONITOR_STANCE") as Node3D
	var use := adapter.resolve("F04_B_TERMINAL_USE") as MeshInstance3D
	if operator == null or use == null or terminal == null:
		return false
	var bounds: AABB = use.global_transform * use.get_aabb()
	var toward_operator: Vector3 = operator.global_position - terminal.global_position
	toward_operator.y = 0.0
	if toward_operator.length_squared() < 0.000001 or bounds.size.x <= 0.0 or bounds.size.z <= 0.0:
		return false
	# The instrument face is local +X. Preserve the authored anchor transform;
	# only the mounted production consumer turns toward its operator.
	terminal.global_rotation.y = atan2(-toward_operator.z, toward_operator.x)
	# The ordinary player ray does not hit an Area from inside it. Keep this
	# target inside the existing terminal-use footprint, ahead of the stance.
	var desk := DeskZone.new()
	desk.name = "F04_B_DESK_ZONE"
	desk.call_interface = call_interface
	desk.interaction_footprint = Vector2(bounds.size.x, bounds.size.z)
	_blockout.add_child(desk)
	var center: Vector3 = bounds.position + bounds.size * 0.5
	desk.global_position = Vector3(center.x, operator.global_position.y, center.z)
	return true


## WHO IS ACTUALLY HOME TO SEE IT.
##
## The observation ledger gates in-flat sight on presence, and an unbound
## provider means "assume home" (npc_observation_ledger.gd:107-110): every
## resident is treated as standing in their own flat at the instant of
## every visible event. Lena could therefore earn a durable
## `in_home_sight` belief â€” committed with provenance, deduped forever â€”
## while her own timetable had her out on a corridor round. The ledger's
## contract is that nothing else may author NPC knowledge; assume-home
## quietly authored it.
##
## The timetable is the authority that already owns this fact, and it
## owns it as DATA: `ScheduleDirector.resolve()` is pure over
## res://data/resident_schedules.json and needs no resident body, no floor
## node and no layout geometry. The legacy routine dispatcher stays inert
## because its target is null. Mina's V2 route owner consumes this same
## timetable resolution through the V2 spatial graph.
func _compose_observation_ledger() -> void:
	resident_presence = ScheduleDirector.new()
	resident_presence.name = "ResidentPresenceTimetable"
	add_child(resident_presence)
	resident_presence.setup(null, layout)
	observation_ledger = NpcObservationLedger.new()
	observation_ledger.name = "ObservationLedger"
	add_child(observation_ledger)
	# Absolute campaign minutes stamp events. Only schedule lookup wraps to
	# the clock's minute of day; the situation never advances its own clock.
	var clock := Callable(campaign_clock, "absolute_minutes")
	observation_ledger.setup([
		{"npc": ServiceRoundDirector.RESIDENT_ID, "unit": "2B"},
		{"npc": "omar_bell", "unit": "3B"},
	], clock, get_tree().root.get_node_or_null("AcousticGraphData"),
			Callable(self, "resident_is_home"), "campaign_absolute_minutes")


## True only while the resident's own authored timetable puts them inside
## their flat. Reads the `place` token rather than ScheduleDirector's
## mapped directive deliberately: the mapped form resolves world POINTS
## through v1 layout coordinates, which do not exist in this building,
## while the place token is the authored fact itself and needs no
## geometry. Degrades to the ledger's own assume-home if the timetable
## data is unavailable, rather than inventing an absence.
func resident_is_home(npc: String) -> bool:
	if resident_presence == null or resident_presence.data.is_empty():
		return true
	if campaign_clock == null:
		return true
	var info := campaign_clock.day_info()
	if not bool(info.get("valid", false)):
		return true
	var block := resident_presence.resolve(npc, str(info.day),
			campaign_clock.minute_of_day(), int(info.doy),
			bool(info.first_sat))
	var place := str(block.get("place", "unit"))
	return place.is_empty() or place.begins_with("unit")


func _compose_service_round_props() -> void:
	var detector := WatchmanClockProp.new()
	detector.prop_type = "watchman_detector"
	_mount("F01_WATCHMAN_DETECTOR", detector)
	var register := NightRegisterProp.new()
	register.prop_type = "night_register"
	_mount("F01_NIGHT_REGISTER", register)
	var signal_register := WatchRegisterProp.new()
	signal_register.prop_type = "signal_register"
	_mount("F01_SIGNAL_REGISTER", signal_register)
	var tour_guard := TourKeyGuardProp.new()
	tour_guard.prop_type = "tour_key_guard"
	_mount("F01_TOUR_KEY_GUARD", tour_guard)
	_retire_blockout_fixture("F02_B_RADIATOR_MASS")
	_retire_blockout_fixture("F02_B_RADIATOR_USE")
	var heating := preload("res://scripts/building/orison_v2_heating.gd").new()
	if not heating.mount(adapter,maintenance_inventory):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: heating refused: %s" % [heating.errors])
		return
	heat_balance = heating.balance
	var boiler := BoilerProp.new()
	boiler.prop_type = "boiler"
	_mount("B1_BOILER_01", boiler)
	watch_station_network = WatchStationNetwork.new()
	watch_station_network.name = "WatchStationNetwork"
	add_child(watch_station_network)
	watch_station_network.attach_receiver(signal_register)
	watch_station_network.attach_key_guard(tour_guard)

func _bind_first_shift_station() -> void:
	var detector := find_child("F01_WATCHMAN_DETECTOR", true, false) as WatchmanClockProp
	var register := find_child("F01_NIGHT_REGISTER", true, false) as NightRegisterProp
	var signal_register := find_child("F01_SIGNAL_REGISTER", true, false) as WatchRegisterProp
	var tour_guard := find_child("F01_TOUR_KEY_GUARD", true, false) as TourKeyGuardProp
	if detector:
		detector.bind_first_shift(first_shift_director)
	if register:
		register.report_taken.connect(first_shift_director.accept_report)
		register.register_signed.connect(first_shift_director.accept_signed_register)
	if signal_register:
		signal_register.signal_displayed.connect(
				first_shift_director.observe_central_signal)
	if tour_guard:
		tour_guard.tour_key_taken.connect(first_shift_director.observe_tour_key_taken)
		tour_guard.tour_key_returned.connect(first_shift_director.observe_tour_key_returned)

func _compose_hot_water() -> bool:
	var plant := adapter.resolve("B1_BOILER_01") as BoilerProp
	if plant == null:
		startup_failed = true
		push_error("ORISON V2 RUNTIME: hot water has no mounted boiler")
		return false
	var taps: Array[TapProp] = []
	for node in _blockout.find_children("*", "Node3D", true, false):
		if node is TapProp:
			taps.append(node as TapProp)
	boiler_tend = BoilerTend.new()
	boiler_tend.name = "BoilerTend"
	add_child(boiler_tend)
	# One plant supplies both hot water and all 23 authored heating demands.
	# Unbuilt rooms retain logical demand; six migrated radiators expose controls.
	boiler_tend.configure(plant, heat_balance, taps)
	return true

func _compose_vantry() -> void:
	var anchor := adapter.resolve("F02_A_MAIN_VANTRY_POINT") as Node3D
	vantry_points = VantryPointNetwork.new()
	vantry_points.name = "VantryPointNetwork"
	vantry_points.floor_nodes = {"F02": _blockout}
	vantry_points.points = {"F02_A_MAIN_VANTRY_POINT": {
		"pos": [anchor.global_position.x, -anchor.global_position.z,
				anchor.global_position.y], "floor": "F02", "room": "2A"}}
	vantry_points.point_order = ["F02_A_MAIN_VANTRY_POINT"]
	vantry_points.work_orders = work_orders
	add_child(vantry_points)
	var point := VantryPointProp.new()
	point.prop_type = "vantry_point"
	point.bind_order_spine(work_orders)
	vantry_points.active_owner = point
	vantry_points.add_child(point)

func _mount(identity: String, consumer: Node3D) -> void:
	if not adapter.mount_consumer(identity, consumer):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: failed to mount " + identity)


func _retire_blockout_fixture(identity: String) -> void:
	# Gray-box fixture masses reserve space until the real production consumer
	# is composed. Once mounted they must neither obscure nor collide with that
	# authority; semantic anchors and clearance envelopes remain untouched.
	var fixture := _blockout.find_child(identity, true, false) as Node3D
	if fixture == null:
		push_error("ORISON V2 RUNTIME: missing blockout fixture " + identity)
		startup_failed = true
		return
	fixture.visible = false
	for node: Node in fixture.find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).disabled = true

func authority_count(type_name: String) -> int:
	return find_children("*", type_name, true, false).size()

func shutdown_for_tests() -> void:
	if is_instance_valid(household_state): household_state.shutdown()
	if is_instance_valid(mirror_renderer): mirror_renderer.shutdown()
	if is_instance_valid(shop_simulation):
		shop_simulation.shutdown()
	if is_instance_valid(exterior_cell):
		if is_instance_valid(passage_region):
			passage_region.shutdown()
		exterior_cell.shutdown_for_tests()
	if adapter != null:
		# Consumers are already detached before synchronous free, so tests and
		# selector reconstruction do not leave deferred audio decoders behind.
		adapter.restore_all(true)

func _exit_tree() -> void:
	if is_instance_valid(household_state): household_state.shutdown()
	if is_instance_valid(mirror_renderer): mirror_renderer.shutdown()
	if _exterior_resolver != null:
		_exterior_resolver.teardown()
		_exterior_resolver = null
	if adapter != null:
		adapter.restore_all()
