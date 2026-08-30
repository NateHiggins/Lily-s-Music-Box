class_name OrisonV2RuntimeRoot
extends Node3D
## Production-service composition over the v2 collision construction.
## Domain behavior remains in the existing production classes below.

const BLOCKOUT := preload("res://scenes/building/orison_v2_blockout.tscn")
const CUES := preload("res://scripts/building/orison_v2_readability_cues.gd")
const Adapter := preload("res://scripts/building/orison_v2_anchor_adapter.gd")
const FrameContract := preload("res://scripts/building/orison_v2_frame_contract.gd")
const LineageRegistry := preload("res://scripts/reality/corruption_lineage_registry.gd")

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
var open_shift_ecosystem: Node
var observation_ledger: NpcObservationLedger
var resident_presence: ScheduleDirector
var campaign_clock: CampaignClock
var corruption_lineages: CorruptionLineageRegistry
var watch_station_network: WatchStationNetwork
var street_traffic: Node = null
var elevator: Node = null
var startup_failed := false
var startup_ms := 0.0
var adapter
var _blockout: Node3D
var frame_contract: OrisonV2FrameContract

func _ready() -> void:
	var started := Time.get_ticks_usec()
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
	_blockout = BLOCKOUT.instantiate()
	_blockout.show_clearance_anchors = false
	add_child(_blockout)
	layout = _blockout.layout
	for level: Dictionary in layout.get("levels", []):
		floor_nodes[str(level.id)] = _blockout
	adapter = Adapter.new(_blockout)
	if not adapter.resolves_required_uniquely():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: unresolved or duplicate required anchor")
		return
	add_child(CUES.new())
	if not adapter.install_acoustic_overrides([
			"F02_A_MAIN_VANTRY_POINT", "F02_A_MONITOR_01",
			"F04_B_MONITOR_01"]):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: acoustic binding failed")
		return
	_compose_authorities()
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
	player.position = Vector3(0, 0, -14.25)
	add_child(player)
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
	open_shift_ecosystem.setup(work_orders, open_shift_radiator,
			service_round, Callable(), observation_ledger)
	safety_net = SafetyNet.new()
	safety_net.name = "SafetyNet"
	safety_net.setup(player)
	add_child(safety_net)

## WHO IS ACTUALLY HOME TO SEE IT.
##
## The observation ledger gates in-flat sight on presence, and an unbound
## provider means "assume home" (npc_observation_ledger.gd:107-110): every
## resident is treated as standing in their own flat at the instant of
## every visible event. Lena could therefore earn a durable
## `in_home_sight` belief — committed with provenance, deduped forever —
## while her own timetable had her out on a corridor round. The ledger's
## contract is that nothing else may author NPC knowledge; assume-home
## quietly authored it.
##
## The timetable is the authority that already owns this fact, and it
## owns it as DATA: `ScheduleDirector.resolve()` is pure over
## res://data/resident_schedules.json and needs no resident body, no floor
## node and no layout geometry. v2 has neither bodies nor routines, so the
## director's DISPATCH half stays inert here — its target is null and
## `_process` returns immediately (schedule_director.gd:99-101). Only the
## resolution half is used, which is the half that answers the question.
func _compose_observation_ledger() -> void:
	campaign_clock = CampaignClock.new()
	campaign_clock.bind_state()
	resident_presence = ScheduleDirector.new()
	resident_presence.name = "ResidentPresenceTimetable"
	add_child(resident_presence)
	resident_presence.setup(null, layout)
	observation_ledger = NpcObservationLedger.new()
	observation_ledger.name = "ObservationLedger"
	add_child(observation_ledger)
	# ONE clock for both halves. The situation's own durable simulation
	# minutes stamp the belief and place the resident at that same minute,
	# so a belief can never be dated to a time at which its witness was
	# somewhere else. Lazy by Callable: the situation exists before any
	# observation is recorded.
	var clock := Callable(open_shift_ecosystem, "now_minutes")
	observation_ledger.setup([
		{"npc": ServiceRoundDirector.RESIDENT_ID, "unit": "2B"},
		{"npc": "omar_bell", "unit": "3B"},
	], clock, get_tree().root.get_node_or_null("AcousticGraphData"),
			Callable(self, "resident_is_home"))


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
	if open_shift_ecosystem == null:
		return true
	var info := campaign_clock.day_info_at(
			float(open_shift_ecosystem.now_minutes())) if campaign_clock else {}
	if not bool(info.get("valid", false)):
		return true
	var block := resident_presence.resolve(npc, str(info.day),
			float(open_shift_ecosystem.now_minutes()), int(info.doy),
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
	var radiator := RadiatorProp.new()
	radiator.prop_type = "radiator"
	radiator.unit = "2B"
	radiator.riser = "H-B"
	radiator.section_count = 10
	radiator.installation_drop = 0.75
	_retire_blockout_fixture("F02_B_RADIATOR_MASS")
	_retire_blockout_fixture("F02_B_RADIATOR_USE")
	_mount("F02_B_RADIATOR_01", radiator)
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
	if adapter != null:
		# Consumers are already detached before synchronous free, so tests and
		# selector reconstruction do not leave deferred audio decoders behind.
		adapter.restore_all(true)

func _exit_tree() -> void:
	if adapter != null:
		adapter.restore_all()
