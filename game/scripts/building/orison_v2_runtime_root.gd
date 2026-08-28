class_name OrisonV2RuntimeRoot
extends Node3D
## Production-service composition over the v2 collision construction.
## Domain behavior remains in the existing production classes below.

const BLOCKOUT := preload("res://scenes/building/orison_v2_blockout.tscn")
const CUES := preload("res://scripts/building/orison_v2_readability_cues.gd")
const Adapter := preload("res://scripts/building/orison_v2_anchor_adapter.gd")

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
var street_traffic: Node = null
var elevator: Node = null
var startup_failed := false
var startup_ms := 0.0
var adapter
var _blockout: Node3D

func _ready() -> void:
	var started := Time.get_ticks_usec()
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
	safety_net = SafetyNet.new()
	safety_net.name = "SafetyNet"
	safety_net.setup(player)
	add_child(safety_net)

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

func authority_count(type_name: String) -> int:
	return find_children("*", type_name, true, false).size()

func shutdown_for_tests() -> void:
	if adapter != null:
		adapter.restore_all()

func _exit_tree() -> void:
	if adapter != null:
		adapter.restore_all()
