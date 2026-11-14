extends RefCounted
## Attach the retained street approach and the destination's authored graph to
## an existing resident route. No second body, calendar or persistent authority.
const Visit := preload("res://scripts/characters/orison_v2_bar_visit.gd")
# Unchanged world-frame approach exercised by OrisonV2BarRouteTest. Interior,
# stair and holding coordinates belong exclusively to the destination layout.
const STREET_APPROACH := [Vector3(0, 0, 3), Vector3(7, 0, 3), Vector3(7, 0, 4.2),
	Vector3(7, -.1, 8), Vector3(7, -.1, 13.6), Vector3(7, 0, 15),
	Vector3(5.65, 0, 17.3), Vector3(4.8, 0, 18)]
const SEAT_TRANSITION_SECONDS := .75
# Carried from the old presentation bench, not an approved cast fit. Each live
# model/socket pairing remains visibly unqualified until the crowd fit review.
const PROVISIONAL_SEATED_SUPPORT := .478
var route: Node3D
var registry: Node3D
var graph: AStar3D
var visit
var _nodes: Dictionary = {}
var _passages: Array[Dictionary] = []
var _gate: Dictionary = {}
var _place: Dictionary = {}
var _approach_id := -1
var _transition := ""
var _transition_time := 0.0
var _transition_start := Vector3.ZERO
var _transition_target := Vector3.ZERO
var _transition_points := PackedVector3Array()
var _transition_leg := 1
var _transition_length := 0.0
var _retry := 0.0
var _torso := CapsuleShape3D.new()

func attach(owner: Node3D) -> bool:
	route = owner
	graph = route.graph
	var region := route.world.get("bar_region") as Node3D
	if not is_instance_valid(region): return false
	var destination := region.get("destination") as Node3D
	if destination == null: return false
	registry = region.get("resident_places") as Node3D
	if not is_instance_valid(registry) or not registry.has_method("preferred"): return false
	_place = registry.call("preferred", str(route.resident))
	if _place.is_empty() or str(_place.get("approach_node", "")).is_empty(): return false
	var navigation := destination.get_node_or_null("Navigation")
	var spec: Dictionary = destination.get("spec")
	if navigation == null or not spec.navigation.has("passages"): return false
	for marker: Node3D in navigation.get_children():
		_nodes[str(marker.name)] = int(route._point("bar_" + str(marker.name), marker.global_position))
	for edge: Array in spec.navigation.edges:
		if edge.size() != 2 or not _nodes.has(str(edge[0])) or not _nodes.has(str(edge[1])): return false
		graph.connect_points(int(_nodes[str(edge[0])]), int(_nodes[str(edge[1])]))
	var entry_a := ""
	for source: Dictionary in spec.navigation.passages:
		var identity := str(source.id)
		if not _nodes.has(str(source.a)) or not _nodes.has(str(source.b)): return false
		var holding: Array[Node3D] = []
		var a_slots: Array[int] = []
		var b_slots: Array[int] = []
		for side: String in ["a_holding", "b_holding"]:
			if source.get(side, []).is_empty(): return false
			for name: String in source[side]:
				var marker := navigation.get_node_or_null(name) as Node3D
				if marker == null or not _nodes.has(name): return false
				if side == "a_holding": a_slots.append(holding.size())
				else: b_slots.append(holding.size())
				holding.append(marker)
		if not bool(registry.call("matches_passage", identity, holding)) \
			and not bool(registry.call("configure_passage", identity, holding)): return false
		var a := int(_nodes[str(source.a)])
		var b := int(_nodes[str(source.b)])
		var crossing := graph.get_id_path(a, b)
		if crossing.size() < 2: return false
		for index in holding.size():
			var same_side := a if a_slots.has(index) else b
			var other_side := b if a_slots.has(index) else a
			var access := graph.get_id_path(same_side, int(_nodes[str(holding[index].name)]))
			if access.is_empty() or access.has(other_side): return false
		_passages.append({"id": identity, "a": a, "b": b, "a_slots": a_slots,
			"b_slots": b_slots, "path": crossing})
		if identity == "entry_descent": entry_a = str(source.a)
	if entry_a.is_empty() or _passages.size() != 2: return false
	var previous := int(route.identities.street)
	for index in STREET_APPROACH.size():
		var next := int(route._point("bar_street_%d" % index, STREET_APPROACH[index]))
		graph.connect_points(previous, next); previous = next
	# The authored sidewalk is the same endpoint as the retained street route.
	# Join here so queuing does not walk to the stair top then double back.
	if not _nodes.has("entry_sidewalk"): return false
	graph.connect_points(previous, int(_nodes.entry_sidewalk))
	var approach_name := str(_place.approach_node)
	if not _nodes.has(approach_name): return false
	_approach_id = int(_nodes[approach_name])
	if graph.get_point_position(_approach_id).distance_to(registry.to_global(_place.approach)) > .001: return false
	if graph.get_id_path(int(route.identities.street), _approach_id).is_empty(): return false
	route.places["harukiya_bar"] = "bar_" + approach_name
	var door := region.doors.get("F01_BAR_RED_DOOR") as DoorProp
	if door == null: return false
	route._doors.append(door)
	return true

func bind_actor() -> bool:
	if visit != null or not is_instance_valid(route) or not is_instance_valid(registry): return false
	var next_visit = Visit.new()
	if not bool(next_visit.bind(registry, str(route.resident), route.actor)): return false
	visit = next_visit
	_torso.radius = .28
	_torso.height = 1.0
	return true

## Called after the route has sampled its authoritative destination. The brief
## seat transition is fitted to authored approach/socket datums; the ordinary
## collision motor remains in charge of all travel between those datums.
func update_place(delta: float) -> bool:
	if visit == null: return false
	var state := str(visit.phase())
	if route.destination != "harukiya_bar" and state in ["reserved", "occupied"]:
		visit.begin_departure()
		_start_transition("leaving", graph.get_point_position(_approach_id))
		route.actor._play_named("idle")
	if not _transition.is_empty():
		var leg_length := _transition_start.distance_to(_transition_target)
		var seconds := SEAT_TRANSITION_SECONDS * leg_length / maxf(_transition_length, .00001)
		var next_time := minf(1.0, _transition_time + delta / maxf(seconds, .00001))
		var weight := smoothstep(0.0, 1.0, next_time)
		var next := _transition_start.lerp(_transition_target, weight)
		if not _transition_clear(next):
			route.blocked_reason = "seat transition waiting for physical clearance"
			return true
		_transition_time = next_time
		route.actor.global_position = next
		if _transition_time >= 1.0:
			_transition_leg += 1
			if _transition_leg < _transition_points.size():
				_transition_start = next
				_transition_target = _transition_points[_transition_leg]
				_transition_time = 0.0
			else:
				if _transition == "leaving": visit.finish_departure()
				_transition = ""
		return true
	if state == "occupied": return true
	if route.destination != "harukiya_bar" or route.current_id != _approach_id or not route.path.is_empty(): return false
	_retry -= delta
	if _retry > 0: return true
	_retry = .5
	if not bool(visit.reserve()) or not bool(visit.occupy()): return true
	route.actor._set_walking(false)
	route.actor.global_rotation.y = float(_place.npc_yaw)
	if bool(route.actor.play_seated()):
		var marker: Marker3D = _place.marker
		route.actor.set_meta("bar_seated_support_qualification", {
			"status": "UNVERIFIED", "seat": str(_place.seat_id),
			"model": route.actor.model_path, "support_offset_m": PROVISIONAL_SEATED_SUPPORT,
			"reason": "personal clip_06 geometry requires measured support and crowd review"})
		_start_transition("seating", marker.global_position - Vector3.UP * PROVISIONAL_SEATED_SUPPORT)
	# Mina retains her own approved standing idle at the niche approach.
	return true

func _start_transition(kind: String, target: Vector3) -> void:
	_transition = kind
	_transition_time = 0.0
	_transition_start = route.actor.global_position
	_transition_points = seat_transition_points(_transition_start, target)
	_transition_leg = 1
	_transition_target = _transition_points[1]
	_transition_length = 0.0
	for index in range(1, _transition_points.size()):
		_transition_length += _transition_points[index - 1].distance_to(_transition_points[index])

## Lift beside a high stool before moving over its cushion; on departure,
## move clear before lowering. For ordinary low seats the same path lowers
## only after reaching the socket. Every leg keeps the original torso sweep.
## Never interpolate across a corner: even a long frame ends at that vertex.
static func seat_transition_points(start: Vector3, target: Vector3) -> PackedVector3Array:
	var height := maxf(start.y, target.y)
	var points := PackedVector3Array([start])
	for point: Vector3 in [Vector3(start.x, height, start.z),
			Vector3(target.x, height, target.z), target]:
		if not point.is_equal_approx(points[-1]): points.append(point)
	if points.size() == 1: points.append(target)
	return points

func _transition_clear(next: Vector3) -> bool:
	if not _people_clear(next): return false
	# The torso stays above the supporting cushion. Do not exclude an entire
	# merged bench collider: that would also ignore other seats and its back.
	# Feet/cloth contact and each model's support fit are separate review items.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _torso
	query.collision_mask = 1
	query.transform.origin = route.actor.global_position + Vector3.UP * (PROVISIONAL_SEATED_SUPPORT + .52)
	query.motion = next - route.actor.global_position
	var space: PhysicsDirectSpaceState3D = route.actor.get_world_3d().direct_space_state
	var sweep: PackedFloat32Array = space.cast_motion(query)
	if sweep.size() != 2 or sweep[0] < 1.0: return false
	query.transform.origin += query.motion
	query.motion = Vector3.ZERO
	return space.intersect_shape(query, 1).is_empty()

## Called after normal graph planning, before taking its next physical step.
func guide_path() -> bool:
	if visit == null: return true
	if not _gate.is_empty():
		var identity := str(_gate.id)
		var active := bool(registry.call("has_admission", identity, str(route.resident), route.actor))
		if active and int(route.current_id) == int(_gate.exit):
			visit.leave_passage(identity); _gate = {}
		elif int(route.desired_id) != int(_gate.goal) and not active:
			visit.leave_passage(identity); _gate = {}
			# Finish a partly travelled edge before adopting the new timetable.
			if not route.path.is_empty(): route.path.resize(1)
			route.planned_id = route.desired_id
			return true
		elif active:
			if int(route.desired_id) != int(_gate.goal) and _at_vertex(): _walk_to(int(_gate.exit))
			return true
		else:
			# A queued body can be delayed on its way to the waiting pocket.
			# Recheck the real FIFO owner whenever the passage clears, rather
			# than requiring it to finish a now-unnecessary detour first.
			if bool(visit.try_enter(identity, _passage_clear(_gate.path))):
				var returning_to_vertex := not _at_vertex()
				_walk_to(int(route.desired_id))
				# Reverse only along the partly travelled edge. The ordinary
				# motor still checks every step; never cut to the new graph leg.
				if returning_to_vertex: route.path.insert(0, int(route.current_id))
				return true
			if int(route.current_id) != int(_gate.holding):
				_walk_to(int(_gate.holding))
				return true
			route.path.clear()
			return false
	var remaining: Array[int] = [int(route.current_id)]
	for index in route.path: remaining.append(int(index))
	if not _at_vertex(): return true
	for passage: Dictionary in _passages:
		var a := remaining.find(int(passage.a)); var b := remaining.find(int(passage.b))
		if a < 0 or b < 0 or mini(a, b) > 2: continue
		var slots: Array[int] = []
		slots.assign(passage.a_slots if a < b else passage.b_slots)
		var holding := registry.call("enqueue_passage", str(passage.id), str(route.resident), route.actor, slots) as Node3D
		if holding == null: return false # Overflow waits with body spacing, never piles onto a slot.
		_gate = {"id": passage.id, "holding": int(_nodes[str(holding.name)]),
			"exit": int(passage.b if a < b else passage.a), "goal": int(route.desired_id), "path": passage.path}
		# Acquire a free, clear passage in FIFO before choosing a waiting detour.
		# Doubling back to a remote pocket can oppose bodies following this actor.
		# Refused admission still uses the stable slot; no body spacing is bypassed.
		if bool(visit.try_enter(str(passage.id), _passage_clear(passage.path))):
			return true
		_walk_to(int(_gate.holding))
		return true
	return true

func _at_vertex() -> bool:
	var at: Vector3 = route.actor.global_position
	var vertex := graph.get_point_position(int(route.current_id))
	return Vector2(at.x - vertex.x, at.z - vertex.z).length() < .05 and absf(at.y - vertex.y) < .3

func _walk_to(identity: int) -> void:
	route.path = graph.get_id_path(int(route.current_id), identity)
	if not route.path.is_empty(): route.path.remove_at(0)
	route.planned_id = route.desired_id

func _passage_clear(points: PackedInt64Array) -> bool:
	for body: Node3D in _people():
		if body == route.actor: continue
		var radius := .75 if body is PlayerController else .62
		for index in points.size() - 1:
			var nearest := Geometry3D.get_closest_point_to_segment(body.global_position,
				graph.get_point_position(points[index]), graph.get_point_position(points[index + 1]))
			if nearest.distance_to(body.global_position) < radius: return false
	return true

func clear_step(next: Vector3) -> bool:
	var current_name := str(route.identities.find_key(int(route.current_id)))
	var next_name := str(route.identities.find_key(int(route.path[0]))) if not route.path.is_empty() else ""
	if not current_name.begins_with("bar_") and not next_name.begins_with("bar_"): return true
	# Retired bar travel needs an explicit bind; non-bar route work is unaffected.
	if visit == null: return false
	return _people_clear(next)

func _people_clear(next: Vector3) -> bool:
	for body: Node3D in _people():
		if body == route.actor or absf(body.global_position.y - next.y) > 1.6: continue
		var separation := .65 if body is PlayerController else .60
		var to_next := Vector2(next.x - body.global_position.x, next.z - body.global_position.z).length()
		var at: Vector3 = route.actor.global_position
		var before := Vector2(at.x - body.global_position.x, at.z - body.global_position.z).length()
		if to_next < separation and to_next <= before + .00001: return false
	return true

func _people() -> Array[Node3D]:
	var people: Array[Node3D] = []
	for node in route.get_tree().get_nodes_in_group("animated_residents"):
		if is_instance_valid(node) and node is Node3D and node.visible and not node.is_queued_for_deletion(): people.append(node)
	if is_instance_valid(route.world.player): people.append(route.world.player)
	return people

## Retire this visit, including unfinished presentation. Normal scheduled
## departure uses finish_departure(), so it can return without rebinding.
## A fixture reusing a retired route must explicitly bind_actor() again.
func cancel() -> void:
	if visit != null: visit.cancel()
	visit = null
	_gate = {}
	_transition = ""
	_transition_time = 0.0
	_transition_points.clear()
	_transition_leg = 1
	_transition_length = 0.0
	_retry = 0.0
