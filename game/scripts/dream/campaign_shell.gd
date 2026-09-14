class_name CampaignShell
extends Node
## Persistent campaign scene boundary. WorldSlot contains exactly one in-tree
## world: waking Orison or the dream root, never both.

signal world_changed(kind: String, world: Node)

const BuildingSelector := preload("res://scripts/building/building_root_selector.gd")
## Empty means the session selector. Focused tests may still inject a stub.
@export_file("*.tscn") var waking_scene_path := ""
@export_file("*.tscn") var dream_scene_path := \
		"res://scenes/dream/DreamMazeRoot.tscn"
## Deterministic proof only; production advances from the engine clock.
@export var sleep_manual_clock := false

var world_slot: Node
var core_loop: CoreLoopDirector
var dream_director: DreamDirector
var sleep_pressure: SleepPressureDirector
var attention_ledger: AttentionLedger
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
	attention_ledger = AttentionLedger.new()
	attention_ledger.name = "AttentionLedger"
	attention_ledger.setup(self)
	add_child(attention_ledger)
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
		traffic: Node = null, return_anchor_resolver := Callable()) -> CoreLoopDirector:
	core_loop.setup(work_orders, player, layout, return_anchor_resolver)
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
			if _replace_world("dream"):
				dream_director.notify_dream_world_active()
		"return_pending":
			if _replace_world("waking"):
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
		if _replace_world("dream"):
			dream_director.notify_dream_world_active()
	elif kind == "waking":
		if _replace_world("waking"):
			dream_director.complete_return()


func _replace_world(kind: String) -> bool:
	if kind not in ["dream", "waking"]:
		push_error("campaign world kind is invalid: %s" % kind)
		return false
	var path := dream_scene_path if kind == "dream" else _selected_waking_path()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("campaign world scene missing: %s" % path)
		return false
	var teardown := teardown_active_world()
	if not bool(teardown.get("ok", false)):
		push_error("campaign world replacement teardown failed: %s" %
				JSON.stringify(teardown))
		return false
	var next := packed.instantiate()
	if kind == "dream" and next.has_method("configure_dream"):
		next.call("configure_dream", dream_director.context())
	world_slot.add_child(next)
	active_world = next
	active_kind = kind
	assert(world_slot.get_child_count() == 1)
	world_changed.emit(kind, next)
	return true


## Public scene-replacement boundary. A waking world first releases its
## independently addressable geometry through the provider's own API; only
## then are gameplay services detached and the complete world queued for the
## next safe deletion boundary. Provider identity remains session-only.
func teardown_active_world() -> Dictionary:
	if active_world == null or not is_instance_valid(active_world):
		active_world = null
		active_kind = ""
		return {"ok": true, "api": "CampaignShell.teardown_active_world",
			"had_world": false, "geometry_teardown": {},
			"world_queued_for_deletion": false,
			"retained_instances": 0, "retained_resources": 0,
			"retained_strong_references": 0}
	var retiring := active_world
	var retiring_kind := active_kind
	var geometry_teardown := {"ok": true,
			"reason": "active world has no independent F01 geometry provider"}
	var geometry_required := retiring_kind == "waking" \
			and retiring.has_method("teardown_floor01_geometry")
	if geometry_required:
		geometry_teardown = retiring.call("teardown_floor01_geometry") \
				as Dictionary
		if not bool(geometry_teardown.get("ok", false)):
			return {"ok": false,
				"api": "CampaignShell.teardown_active_world",
				"had_world": true, "retiring_kind": retiring_kind,
				"geometry_teardown_required": true,
				"geometry_teardown": geometry_teardown,
				"world_queued_for_deletion": false,
				"retained_instances": int(geometry_teardown.get(
						"retained_instances", -1)),
				"retained_resources": int(geometry_teardown.get(
						"retained_resources", -1)),
				"retained_strong_references": int(geometry_teardown.get(
						"retained_strong_references", -1))}
	if retiring_kind == "waking":
		sleep_pressure.detach_waking_services()
		core_loop.detach_world()
	# Queue first so the SceneTree owns deferred deletion even after the world
	# is removed from the one-child slot. This never synchronously frees a live
	# renderer/light graph.
	retiring.queue_free()
	if retiring.get_parent() == world_slot:
		world_slot.remove_child(retiring)
	active_world = null
	active_kind = ""
	return {"ok": true, "api": "CampaignShell.teardown_active_world",
		"had_world": true, "retiring_kind": retiring_kind,
		"geometry_teardown_required": geometry_required,
		"geometry_teardown": geometry_teardown,
		"world_queued_for_deletion": retiring.is_queued_for_deletion(),
		"retained_instances": int(geometry_teardown.get(
				"retained_instances", 0)),
		"retained_resources": int(geometry_teardown.get(
				"retained_resources", 0)),
		"retained_strong_references": int(geometry_teardown.get(
				"retained_strong_references", 0)),
		"synchronous_world_free": false,
		"selector_or_save_authority_changed": false}

func _selected_waking_path() -> String:
	return waking_scene_path if not waking_scene_path.is_empty() \
			else BuildingSelector.scene_path()
