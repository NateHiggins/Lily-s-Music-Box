class_name CampaignShell
extends Node
## Persistent campaign scene boundary. WorldSlot contains exactly one in-tree
## world: waking Orison or the dream root, never both.

signal world_changed(kind: String, world: Node)

@export_file("*.tscn") var waking_scene_path := \
		"res://scenes/building/orison_root.tscn"
@export_file("*.tscn") var dream_scene_path := \
		"res://scenes/dream/DreamMazeRoot.tscn"
## Deterministic proof only; production advances from the engine clock.
@export var sleep_manual_clock := false

var world_slot: Node
var core_loop: CoreLoopDirector
var dream_director: DreamDirector
var sleep_pressure: SleepPressureDirector
var active_world: Node
var active_kind := ""
var _swap_queued := false


func _ready() -> void:
	add_to_group("campaign_shell")
	world_slot = get_node_or_null("WorldSlot")
	if world_slot == null:
		world_slot = Node.new()
		world_slot.name = "WorldSlot"
		add_child(world_slot)
	core_loop = CoreLoopDirector.new()
	core_loop.name = "CoreLoopDirector"
	add_child(core_loop)
	dream_director = DreamDirector.new()
	dream_director.name = "DreamDirector"
	add_child(dream_director)
	dream_director.setup(core_loop)
	sleep_pressure = SleepPressureDirector.new()
	sleep_pressure.name = "SleepPressureDirector"
	sleep_pressure.manual_clock = sleep_manual_clock
	add_child(sleep_pressure)
	sleep_pressure.setup(dream_director)
	dream_director.world_swap_requested.connect(_on_world_swap_requested)
	_restore_world()


## BuildingRoot calls this after all scene-owned domain services and the player
## exist. Direct test instantiation still creates a local coordinator instead.
func bind_waking_services(work_orders: WorkOrders, player: Node3D,
		layout: Dictionary, elevator: Node = null,
		traffic: Node = null) -> CoreLoopDirector:
	core_loop.setup(work_orders, player, layout)
	sleep_pressure.bind_waking_services(player, elevator, traffic)
	return core_loop


func world_kind() -> String:
	return active_kind


func world_child_count() -> int:
	return world_slot.get_child_count() if world_slot else 0


## F1 developer entry. This begins the production warning and transition from
## the current authored dream record without fabricating the work, case or
## inventory history that normally earns it.
func debug_start_dream_sequence() -> bool:
	if GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG \
			or active_kind != "waking" or _swap_queued \
			or core_loop == null or dream_director == null:
		return false
	var request := core_loop.authored_dream_request()
	if request.is_empty():
		return false
	return dream_director.debug_arm_dream(str(request.case_id),
			str(request.profile_id), request.window as Dictionary)


func _restore_world() -> void:
	match dream_director.phase():
		"entered", "active":
			_replace_world("dream")
			dream_director.notify_dream_world_active()
		"return_pending":
			_replace_world("waking")
			dream_director.complete_return()
		_:
			_replace_world("waking")


## Never free the world from inside its own signal callback. The committed
## phase is already durable; replacement happens at the next safe boundary.
func _on_world_swap_requested(kind: String) -> void:
	if _swap_queued:
		return
	_swap_queued = true
	call_deferred("_apply_world_swap", kind)


func _apply_world_swap(kind: String) -> void:
	_swap_queued = false
	if kind == "dream":
		_replace_world("dream")
		dream_director.notify_dream_world_active()
	elif kind == "waking":
		_replace_world("waking")
		dream_director.complete_return()


func _replace_world(kind: String) -> void:
	if active_world != null and is_instance_valid(active_world):
		if active_kind == "waking":
			sleep_pressure.detach_waking_services()
			core_loop.detach_world()
		world_slot.remove_child(active_world)
		active_world.free()
	active_world = null
	active_kind = ""
	var path := dream_scene_path if kind == "dream" else waking_scene_path
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("campaign world scene missing: %s" % path)
		return
	var next := packed.instantiate()
	if kind == "dream" and next.has_method("configure_dream"):
		next.call("configure_dream", dream_director.context())
	world_slot.add_child(next)
	active_world = next
	active_kind = kind
	assert(world_slot.get_child_count() == 1)
	world_changed.emit(kind, next)
