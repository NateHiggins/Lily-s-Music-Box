extends RefCounted
## A route owner's transient visit handle. It never chooses attendance, moves
## or spawns a body, plays a pose, advances time, or writes persistent state.
## Bind once per body; cancel when its route leaves the venue or is retired.
var _registry: WeakRef
var _actor: WeakRef
var _resident := ""

func bind(registry: Node3D, resident: String, actor: Node3D) -> bool:
	if _registry != null or not is_instance_valid(registry) or not is_instance_valid(actor): return false
	if registry.is_queued_for_deletion() or actor.is_queued_for_deletion(): return false
	if not registry.has_method("reserve") or not registry.has_method("preferred"): return false
	var place: Dictionary = registry.call("preferred", resident)
	if place.is_empty(): return false
	_registry = weakref(registry)
	_actor = weakref(actor)
	_resident = resident
	return true

func reserve() -> bool:
	return _request("reserve")

func occupy() -> bool:
	return _request("occupy")

func begin_departure() -> bool:
	return _request("begin_departure")

func finish_departure() -> bool:
	return phase() == "departing" and _request("release")

func phase() -> String:
	var registry := _node(_registry)
	var actor := _node(_actor)
	return str(registry.call("phase", _resident, actor)) if registry != null and actor != null else ""

func wait_at(passage: String) -> Node3D:
	var registry := _node(_registry)
	var actor := _node(_actor)
	return registry.call("enqueue_passage", passage, _resident, actor) as Node3D if registry != null and actor != null else null

func try_enter(passage: String, clear: bool) -> bool:
	var registry := _node(_registry)
	var actor := _node(_actor)
	return bool(registry.call("try_admit", passage, _resident, actor, clear)) if registry != null and actor != null else false

func leave_passage(passage: String) -> bool:
	var registry := _node(_registry)
	var actor := _node(_actor)
	return bool(registry.call("leave_passage", passage, _resident, actor)) if registry != null and actor != null else false

func cancel() -> void:
	var registry := _node(_registry)
	var actor := _node(_actor)
	if registry != null and actor != null: registry.call("cancel_visit", _resident, actor)

func _request(method: String) -> bool:
	var registry := _node(_registry)
	var actor := _node(_actor)
	return bool(registry.call(method, _resident, actor)) if registry != null and actor != null else false

func _node(reference: WeakRef) -> Node3D:
	if reference == null: return null
	var node := reference.get_ref() as Node3D
	return node if is_instance_valid(node) and not node.is_queued_for_deletion() else null
