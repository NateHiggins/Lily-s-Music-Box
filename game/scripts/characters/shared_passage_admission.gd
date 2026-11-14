extends RefCounted
## Transient exact-body FIFO state only. Callers own geometry and motion.
## Active entries retain their holding slot. Nothing advances without try_admit.
var _bindings: Dictionary = {}
var _passages: Dictionary = {}

func bind(resident: String, actor: Node3D) -> bool:
	prune_stale()
	if resident.strip_edges().is_empty() or not _live(actor): return false
	if _bindings.has(resident): return _node(_bindings[resident]) == actor
	for reference: WeakRef in _bindings.values():
		if _node(reference) == actor: return false
	_bindings[resident] = weakref(actor)
	return true

func configure_passage(identity: String, holding_nodes: Array[Node3D]) -> bool:
	prune_stale()
	if identity.is_empty() or holding_nodes.is_empty(): return false
	if _passages.has(identity):
		var previous: Dictionary = _passages[identity]
		if not previous.queue.is_empty() or not previous.active.is_empty(): return false
	var nodes: Array[WeakRef] = []
	var seen := {}
	for node: Node3D in holding_nodes:
		if not _live(node) or seen.has(node.get_instance_id()): return false
		for other_id: String in _passages:
			if other_id == identity: continue
			for other: WeakRef in _passages[other_id].holding:
				if other.get_ref() == node: return false
		seen[node.get_instance_id()] = true
		nodes.append(weakref(node))
	_passages[identity] = {"holding": nodes, "queue": [], "active": {}}
	return true

func matches_passage(identity: String, holding_nodes: Array[Node3D]) -> bool:
	prune_stale()
	if not _passages.has(identity) or _passages[identity].holding.size() != holding_nodes.size(): return false
	for index in holding_nodes.size():
		if not _live(holding_nodes[index]): return false
		if (_passages[identity].holding[index] as WeakRef).get_ref() != holding_nodes[index]: return false
	return true

## Retry returns the same slot; null is refusal, never an overflow position.
## One actor may request only one passage in this instance at a time.
func enqueue_passage(identity: String, resident: String, actor: Node3D,
		allowed_slots: Array[int] = []) -> Node3D:
	prune_stale()
	if not _passages.has(identity) or not _bound(resident, actor): return null
	for other_id: String in _passages:
		for entry: Dictionary in _entries(_passages[other_id]):
			if _owner(entry) == actor:
				return (_holding(_passages[identity], entry) if other_id == identity
					and (allowed_slots.is_empty() or allowed_slots.has(int(entry.slot))) else null)
	var passage: Dictionary = _passages[identity]
	var used := {}
	for entry: Dictionary in _entries(passage): used[int(entry.slot)] = true
	for slot in passage.holding.size():
		if used.has(slot) or (not allowed_slots.is_empty() and not allowed_slots.has(slot)): continue
		var node := _node(passage.holding[slot])
		if node == null: continue
		passage.queue.append({"resident": resident, "owner": weakref(actor), "slot": slot})
		return node
	return null

## False clearance never revokes a crossing or promotes its follower.
func try_admit(identity: String, resident: String, actor: Node3D, clear: bool) -> bool:
	prune_stale()
	if not clear or not _bound(resident, actor) or not _passages.has(identity): return false
	var passage: Dictionary = _passages[identity]
	if not passage.active.is_empty(): return _matches(passage.active, resident, actor)
	if passage.queue.is_empty() or not _matches(passage.queue[0], resident, actor): return false
	passage.active = passage.queue.pop_front()
	return true

func has_admission(identity: String, resident: String, actor: Node3D) -> bool:
	prune_stale()
	return (_bound(resident, actor) and _passages.has(identity)
		and _matches(_passages[identity].active, resident, actor))

## Cancel a waiter or release a crossing; exact resident AND body must match.
func leave_passage(identity: String, resident: String, actor: Node3D) -> bool:
	prune_stale()
	if not _passages.has(identity) or not _bound(resident, actor): return false
	var passage: Dictionary = _passages[identity]
	if _matches(passage.active, resident, actor):
		passage.active = {}
		return true
	for index in passage.queue.size():
		if _matches(passage.queue[index], resident, actor):
			passage.queue.remove_at(index)
			return true
	return false

## Retarget cancellation retains the live binding for ordinary revisit.
## The controller retires its own handle; dead bodies lose their binding below.
func cancel(resident: String, actor: Node3D) -> bool:
	prune_stale()
	if not _bound(resident, actor): return false
	for identity: String in _passages: leave_passage(identity, resident, actor)
	return true

func prune_stale() -> void:
	for resident: String in _bindings.keys():
		if _node(_bindings[resident]) == null: _bindings.erase(resident)
	for identity: String in _passages:
		var passage: Dictionary = _passages[identity]
		if _owner(passage.active) == null: passage.active = {}
		for index in range(passage.queue.size() - 1, -1, -1):
			var entry: Dictionary = passage.queue[index]
			if _owner(entry) == null or _holding(passage, entry) == null:
				passage.queue.remove_at(index)

func _bound(resident: String, actor: Node3D) -> bool:
	return _live(actor) and _bindings.has(resident) and _node(_bindings[resident]) == actor

func _entries(passage: Dictionary) -> Array:
	var entries: Array = passage.queue.duplicate()
	if not passage.active.is_empty(): entries.append(passage.active)
	return entries

func _holding(passage: Dictionary, entry: Dictionary) -> Node3D:
	var slot := int(entry.slot)
	return _node(passage.holding[slot]) if slot >= 0 and slot < passage.holding.size() else null

func _matches(entry: Dictionary, resident: String, actor: Node3D) -> bool:
	return _live(actor) and str(entry.get("resident", "")) == resident and _owner(entry) == actor

func _owner(entry: Dictionary) -> Node3D:
	return _node(entry.get("owner") as WeakRef)

func _node(reference: WeakRef) -> Node3D:
	if reference == null: return null
	var node := reference.get_ref() as Node3D
	return node if _live(node) else null

func _live(node: Node3D) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
