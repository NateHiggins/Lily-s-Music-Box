extends Node3D
## Presentation state only. Route guide supplies actual swept clearance and motion.
const Passage := preload("res://scripts/characters/shared_passage_admission.gd")
const POSITIONS := ["resident_wait_front", "resident_wait_rear", "resident_overflow",
	"resident_overflow_approach", "resident_access_front", "resident_access_rear",
	"resident_service_turn", "resident_entry_turn", "service_stance", "exterior_stance",
	"interior_arrival", "street_alignment"]
const SERVICE_HOLDS := ["resident_wait_front", "resident_wait_rear", "resident_overflow"]
const TRANSIT_HOLDS := ["service_stance", "resident_wait_front", "resident_wait_rear",
	"resident_overflow", "resident_overflow_approach"]
const ARRIVAL_RADIUS := .06
const HEIGHT_TOLERANCE := .3 # Same supported endpoint tolerance as the route owner.
var _service := Passage.new()
var _transit := Passage.new()
var _markers: Dictionary = {}
var _bindings: Dictionary = {}
var _serving: Dictionary = {}
var _service_cancelled: Dictionary = {}
var _transit_cancelled: Dictionary = {}
var _exterior: WeakRef
var _configured := false
var _retired := false

## Add this owner to the tree first: holding markers must have a live tree.
func configure(exterior: Node3D) -> bool:
	if _configured or _retired or not is_inside_tree() or not _live(exterior): return false
	var resolver: Object = exterior.get("spatial_resolver")
	if not is_instance_valid(resolver) or not resolver.has_method("resolve_placement"): return false
	var positions := {}
	for identity: String in POSITIONS:
		var row: Dictionary = resolver.call("resolve_placement", "SHOP_BODEGA", identity)
		if row.get("instance_id", "") != "SHOP_BODEGA" or row.get("placement_id", "") != identity: return false
		if not row.get("position") is Vector3 or not (row.position as Vector3).is_finite(): return false
		positions[identity] = row.position
	for identity: String in POSITIONS:
		var marker := Marker3D.new(); marker.name = identity; add_child(marker)
		marker.global_position = positions[identity]; _markers[identity] = marker
	var service_nodes: Array[Node3D] = []; var transit_nodes: Array[Node3D] = []
	for identity: String in SERVICE_HOLDS: service_nodes.append(_markers[identity])
	for identity: String in TRANSIT_HOLDS: transit_nodes.append(_markers[identity])
	if not _service.configure_passage("service", service_nodes) or not _transit.configure_passage("transit", transit_nodes):
		for marker: Node3D in _markers.values(): marker.free()
		_markers.clear(); _service = Passage.new(); _transit = Passage.new(); return false
	_exterior = weakref(exterior); _configured = true
	return true

func position_marker(identity: String) -> Node3D:
	var marker := _markers.get(identity) as Node3D
	return marker if _available() and _live(marker) else null

func bind(resident: String, actor: Node3D) -> bool:
	prune_stale()
	if not _available() or resident.strip_edges().is_empty() or not _live(actor): return false
	if _bindings.has(resident): return _node(_bindings[resident]) == actor
	for reference: WeakRef in _bindings.values():
		if _node(reference) == actor: return false
	if not _service.bind(resident, actor) or not _transit.bind(resident, actor): return false
	_bindings[resident] = weakref(actor)
	return true

## Repeat requests keep their slot; an already-serving owner gets its service marker.
func request_service(resident: String, actor: Node3D) -> Node3D:
	if not _valid(resident, actor) or _service_cancelled.has(resident): return null
	if _matches(_serving, resident, actor): return position_marker("service_stance")
	var allowed: Array[int] = []
	for slot in SERVICE_HOLDS.size():
		if not _held_by_other(_transit, position_marker(SERVICE_HOLDS[slot]), actor): allowed.append(slot)
	return _service.enqueue_passage("service", resident, actor, allowed) if not allowed.is_empty() else null

func try_service(resident: String, actor: Node3D, clear: bool) -> bool:
	if not _valid(resident, actor) or not clear or _service_cancelled.has(resident): return false
	if not _serving.is_empty(): return _matches(_serving, resident, actor)
	var target := position_marker("service_stance")
	if target == null or _held_by_other(_transit, target, actor): return false
	return _service.try_admit("service", resident, actor, clear)

func has_service(resident: String, actor: Node3D) -> bool:
	return _valid(resident, actor) and (_matches(_serving, resident, actor)
		or _service.has_admission("service", resident, actor))

## Actual foot location, not intent, completes the queue-to-physical-owner transfer.
func arrive_service(resident: String, actor: Node3D) -> bool:
	if not _valid(resident, actor) or _service_cancelled.has(resident): return false
	if not _at(actor, position_marker("service_stance")): return false
	if not _serving.is_empty(): return _matches(_serving, resident, actor)
	if not _service.has_admission("service", resident, actor): return false
	_serving = {"resident": resident, "owner": weakref(actor)}
	if not _service.leave_passage("service", resident, actor): _serving = {}; return false
	return true

## Queued requests may cancel immediately. A transferring/standing owner needs clearance.
func release_service(resident: String, actor: Node3D, clear: bool = false) -> bool:
	if not _valid(resident, actor): return false
	if has_service(resident, actor):
		if not clear or _at(actor, position_marker("service_stance")): return false
		if _matches(_serving, resident, actor): _serving = {}
	_service.leave_passage("service", resident, actor)
	_service_cancelled.erase(resident)
	return true

## allowed_slots must describe this body's real side/stance, never an arbitrary free slot.
func request_transit(resident: String, actor: Node3D, allowed_slots: Array[int]) -> Node3D:
	if not _valid(resident, actor) or _transit_cancelled.has(resident) or allowed_slots.is_empty(): return null
	var existing := _request_marker(_transit, resident, actor)
	if existing != null: return _transit.enqueue_passage("transit", resident, actor, allowed_slots)
	var allowed: Array[int] = []
	for slot in allowed_slots:
		if slot < 0 or slot >= TRANSIT_HOLDS.size(): continue
		var marker := position_marker(TRANSIT_HOLDS[slot])
		if not _at(actor, marker) or _held_by_other(_service, marker, actor): continue
		if TRANSIT_HOLDS[slot] == "service_stance" and not _serving.is_empty() and not _matches(_serving, resident, actor): continue
		allowed.append(slot)
	return _transit.enqueue_passage("transit", resident, actor, allowed) if not allowed.is_empty() else null

func try_transit(resident: String, actor: Node3D, clear: bool) -> bool:
	if not _valid(resident, actor) or _transit_cancelled.has(resident): return false
	return _transit.try_admit("transit", resident, actor, clear)

func has_transit(resident: String, actor: Node3D) -> bool:
	return _valid(resident, actor) and _transit.has_admission("transit", resident, actor)

func release_transit(resident: String, actor: Node3D, clear: bool = false) -> bool:
	if not _valid(resident, actor): return false
	if has_transit(resident, actor) and not clear: return false
	_transit.leave_passage("transit", resident, actor)
	_transit_cancelled.erase(resident)
	return true

## Cancelled active claims remain visible until the guide certifies physical clearance.
func cancel(resident: String, actor: Node3D, clear: bool = false) -> bool:
	if not _valid(resident, actor): return false
	if has_service(resident, actor): _service_cancelled[resident] = true
	if has_transit(resident, actor): _transit_cancelled[resident] = true
	var service_done := release_service(resident, actor, clear)
	var transit_done := release_transit(resident, actor, clear)
	return service_done and transit_done

func prune_stale() -> void:
	_service.prune_stale(); _transit.prune_stale()
	for resident: String in _bindings.keys():
		if _node(_bindings[resident]) != null: continue
		_bindings.erase(resident); _service_cancelled.erase(resident); _transit_cancelled.erase(resident)
	if _record_actor(_serving) == null: _serving = {}

func debug_snapshot() -> Dictionary:
	prune_stale()
	return {"configured": _available(), "service_owner": _entry_snapshot(_serving),
		"service": _flow_snapshot(_service, "service"), "transit": _flow_snapshot(_transit, "transit"),
		"service_cancelled": _service_cancelled.keys(), "transit_cancelled": _transit_cancelled.keys()}

func _flow_snapshot(registry: Passage, identity: String) -> Dictionary:
	var flow: Dictionary = registry._passages.get(identity, {"queue": [], "active": {}})
	var queue: Array[Dictionary] = []
	for entry: Dictionary in flow.queue: queue.append(_entry_snapshot(entry, registry._holding(flow, entry)))
	var active: Dictionary = flow.active
	return {"queue": queue, "active": _entry_snapshot(active, registry._holding(flow, active) if not active.is_empty() else null)}

func _entry_snapshot(entry: Dictionary, marker: Node3D = null) -> Dictionary:
	var actor := _record_actor(entry)
	if actor == null: return {}
	return {"resident": str(entry.resident), "actor_instance_id": actor.get_instance_id(),
		"feet": actor.global_position, "holding": str(marker.name) if _live(marker) else "",
		"slot": int(entry.get("slot", -1))}

func _held_by_other(registry: Passage, marker: Node3D, actor: Node3D) -> bool:
	if marker == null: return true
	for flow: Dictionary in registry._passages.values():
		for entry: Dictionary in registry._entries(flow):
			if registry._holding(flow, entry) == marker and _record_actor(entry) != actor: return true
	return false

func _request_marker(registry: Passage, resident: String, actor: Node3D) -> Node3D:
	for flow: Dictionary in registry._passages.values():
		for entry: Dictionary in registry._entries(flow):
			if _matches(entry, resident, actor): return registry._holding(flow, entry)
	return null

func _at(actor: Node3D, marker: Node3D) -> bool:
	if not _live(actor) or not _live(marker): return false
	var offset := actor.global_position - marker.global_position
	return Vector2(offset.x, offset.z).length() <= ARRIVAL_RADIUS and absf(offset.y) <= HEIGHT_TOLERANCE

func _valid(resident: String, actor: Node3D) -> bool:
	prune_stale()
	return _available() and _live(actor) and _bindings.has(resident) and _node(_bindings[resident]) == actor

func _available() -> bool:
	return _configured and not _retired and is_inside_tree() and _node(_exterior) != null

func _matches(entry: Dictionary, resident: String, actor: Node3D) -> bool:
	return _live(actor) and str(entry.get("resident", "")) == resident and _record_actor(entry) == actor

func _record_actor(entry: Dictionary) -> Node3D:
	return _node(entry.get("owner") as WeakRef)

func _node(reference: WeakRef) -> Node3D:
	if reference == null: return null
	var node := reference.get_ref() as Node3D
	return node if _live(node) else null

func _live(node: Node3D) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()

func _exit_tree() -> void:
	_retired = true; _configured = false; _bindings.clear(); _serving.clear()
	_service_cancelled.clear(); _transit_cancelled.clear()
	_service = Passage.new(); _transit = Passage.new()
