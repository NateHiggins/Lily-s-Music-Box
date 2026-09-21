class_name ResidentRouteDoors
extends RefCounted
## Route selection and pending-close bookkeeping. DoorProp alone moves leaves.
## Weak references never retain a scene, a resident, or a World3D.

const BODY_RADIUS := 0.28
const BODY_HEIGHT := 1.55
const CLEARANCE := 0.08
const PLANE_EPSILON := 0.001

var _routes: Dictionary = {}
var _engaged: Dictionary = {}
var _pending_close: Dictionary = {}


func tick(routines: Node3D) -> void:
	_prune()
	_close_pending(routines)


func update(routines: Node3D, actor: Dictionary, walking: bool, max_step: float) -> bool:
	tick(routines)
	var node: Node3D = actor.node
	var key: int = node.get_instance_id()
	if not walking:
		_relinquish(_engaged.get(key, []))
		_engaged.erase(key)
		_routes.erase(key)
		_close_pending(routines)
		return true
	var path: PackedVector3Array = actor.path
	var state: Dictionary = _routes.get(key, {})
	# Only moved() advances this observation. Relocation or an identical-value
	# route reset must reselect, without inventing a physical crossing.
	var relocated: bool = not state.is_empty() \
			and node.global_position.distance_squared_to(state.position) > 0.00000001
	if not state.is_empty() and (state.path != path or relocated):
		_relinquish(_engaged.get(key, []))
		_engaged.erase(key)
	if state.is_empty() or relocated or bool(state.get("reselect", false)) or state.path != path \
			or int(state.revision) != DoorProp.route_registry_revision \
			or _doors_moved(state):
		state = _select(routines, actor)
		_routes[key] = state
	var ready := true
	for passage: Dictionary in state.doors:
		var door: DoorProp = passage.door.get_ref() as DoorProp
		if not _same_world(door, node) or door == actor.get("home_door"):
			continue
		if bool(passage.get("completed", false)):
			continue
		var trigger: float = _sweep_radius(door) + BODY_RADIUS + CLEARANCE \
				+ 2.0 * _sweep_radius(door) * sin(deg_to_rad(0.5)) \
				+ maxf(max_step, 0.0)
		var pivot: Vector3 = door._body.global_position if is_instance_valid(door._body) else door.global_position
		# Selected means the remaining path really crosses this aperture. A
		# bend must not enter the swing area before path-distance lookahead fires.
		if minf(_distance_to_crossing(actor, passage), node.global_position.distance_to(pivot)) > trigger:
			continue
		if not bool(passage.get("engaged", false)):
			passage.engaged = true
			_pending_close.erase(door.get_instance_id())
			var active: Array = _engaged.get(key, [])
			active.append(passage)
			_engaged[key] = active
		if not door.is_ready_for_passage():
			# Opening is directional: a close requester on the side the leaf
			# swings away from is safe even inside the full closing envelope.
			if can_open(routines, door, node):
				door.npc_set_open(true)
			ready = false
	return ready


## Called only after real _follow movement, never for lift/shop teleports.
func moved(routines: Node3D, actor: Dictionary, from: Vector3, to: Vector3) -> void:
	var node: Node3D = actor.node
	var key: int = node.get_instance_id()
	if _routes.has(key): _routes[key].position = to
	var keep: Array = []
	for passage: Dictionary in _engaged.get(key, []):
		var door: DoorProp = passage.door.get_ref() as DoorProp
		if not _same_world(door, node):
			continue
		var a: Vector3 = door.to_local(from)
		var b: Vector3 = door.to_local(to)
		var source_side: float = passage.source_side
		if a.z * source_side > PLANE_EPSILON:
			passage.saw_source = true
		if bool(passage.get("saw_source", false)) and a.z * source_side >= -PLANE_EPSILON \
				and b.z * source_side < -PLANE_EPSILON:
			var ratio: float = clampf(-a.z / (b.z - a.z), 0.0, 1.0)
			if _inside_aperture(door, a.lerp(b, ratio)):
				passage.crossed = true
		if bool(passage.get("crossed", false)) \
				and b.z * source_side < -PLANE_EPSILON and not _occupies_sweep(door, to):
			passage.completed = true
			_pending_close[door.get_instance_id()] = weakref(door)
			if _routes.has(key): _routes[key].reselect = true
		else:
			keep.append(passage)
	_engaged[key] = keep
	_close_pending(routines)


## Shared by the home-entry owner and general route passages. A passed
## resident never closes into a visible neighbour on the same physical floor.
func can_close(routines: Node3D, door: DoorProp) -> bool:
	if not is_instance_valid(door) or not door.is_inside_tree():
		return false
	var residents: Array = routines.get("actors")
	for other: Dictionary in residents:
		var node: Node3D = other.get("node")
		# Floor streaming hides parents but does not remove resident bodies.
		# Only the actor's own hidden lift/shop state is absent physically.
		if _same_world(door, node) and node.visible \
				and _occupies_sweep(door, node.global_position):
			return false
	return true


## Prove the actual owner-authored opening arc against every current resident,
## including the requester. Sampling is conservative: any leaf point between
## samples is within 2*r*sin(step/4) of its nearest sample. Inflate the body
## radius by that bound, so a collision cannot hide in a sampling gap.
func can_open(routines: Node3D, door: DoorProp, requester: Node3D) -> bool:
	if not _same_world(door, requester) or not is_instance_valid(door._body) \
			or door._moving or door.open or door.leaf_state == "locked":
		return false
	var residents: Array = routines.get("actors")
	var feet: Array[Vector3] = [requester.global_position]
	for other: Dictionary in residents:
		var node: Node3D = other.get("node")
		if node != requester and _same_world(door, node) and node.visible:
			feet.append(node.global_position)
	var colliders: Array[CollisionShape3D] = []
	for child in door._body.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.disabled: continue
		if not collision.shape is BoxShape3D: return false
		colliders.append(collision)
	if colliders.is_empty(): return false
	var angle: float = door.opening_angle_radians() - door._body.rotation.y
	var steps: int = maxi(1, ceili(absf(angle) / deg_to_rad(2.0)))
	var arc_radius: float = _sweep_radius(door)
	var arc_margin: float = 2.0 * arc_radius * sin(absf(angle) / float(steps) * 0.25)
	var radius: float = BODY_RADIUS + CLEARANCE + arc_margin
	for i in range(steps + 1):
		var pose: Transform3D = door._body.transform
		pose.basis = Basis(Vector3.UP, angle * float(i) / float(steps)) * pose.basis
		for collision in colliders:
			var box := collision.shape as BoxShape3D
			var transform: Transform3D = door.global_transform * pose * collision.transform
			var x_axis: Vector3 = transform.basis.x.normalized()
			var y_axis: Vector3 = transform.basis.y.normalized()
			var z_axis: Vector3 = transform.basis.z.normalized()
			# The physical door contract is an upright, non-sheared box leaf.
			# Refuse malformed hosts rather than applying yaw math to them.
			if y_axis.dot(Vector3.UP) < 0.999 or absf(x_axis.dot(z_axis)) > 0.001 \
					or absf(x_axis.y) > 0.001 or absf(z_axis.y) > 0.001:
				return false
			var half: Vector3 = box.size * 0.5 * Vector3(transform.basis.x.length(),
				transform.basis.y.length(), transform.basis.z.length())
			for foot in feet:
				if foot.y >= transform.origin.y + half.y + CLEARANCE \
						or foot.y + BODY_HEIGHT <= transform.origin.y - half.y - CLEARANCE:
					continue
				var offset: Vector3 = foot - transform.origin
				var dx: float = maxf(absf(offset.dot(x_axis)) - half.x, 0.0)
				var dz: float = maxf(absf(offset.dot(z_axis)) - half.z, 0.0)
				if dx * dx + dz * dz <= radius * radius: return false
	return true


func _close_pending(routines: Node3D) -> void:
	for key in _pending_close.keys():
		var door: DoorProp = _pending_close[key].get_ref() as DoorProp
		if not is_instance_valid(door) or not door.is_inside_tree():
			_pending_close.erase(key)
			continue
		if can_close(routines, door):
			door.npc_set_open(false)
			if not door.open:
				_pending_close.erase(key)


func _select(routines: Node3D, actor: Dictionary) -> Dictionary:
	var node: Node3D = actor.node
	var key: int = node.get_instance_id()
	var retained: Array = []
	var result := {"node": weakref(node), "path": actor.path.duplicate(), "position": node.global_position,
		"revision": DoorProp.route_registry_revision, "doors": []}
	for candidate in routines.get_tree().get_nodes_in_group("resident_route_doors"):
		var door := candidate as DoorProp
		if door == actor.get("home_door") or not _same_world(door, node) \
				or door.door_kind == "cabinet" or door.height < BODY_HEIGHT:
			continue
		var crossing := _crossing(door, actor)
		if crossing.is_empty():
			continue
		crossing.door = weakref(door)
		crossing.transform = door.global_transform
		# Preserve a currently engaged physical passage through a route refresh.
		for existing: Dictionary in _engaged.get(key, []):
			if existing.door.get_ref() == door and not bool(existing.get("crossed", false)):
				existing.point = crossing.point
				existing.segment = crossing.segment
				existing.transform = crossing.transform
				crossing = existing
				retained.append(existing)
				break
		result.doors.append(crossing)
	for previous: Dictionary in _engaged.get(key, []):
		if previous not in retained:
			# A replaced/abandoned path relinquishes its open request. This is
			# cancellation, not fabricated evidence of crossing the leaf.
			_relinquish([previous])
	_engaged[key] = retained
	return result


## A crossing requires opposite sides of the closed-leaf plane, through the
## actual aperture. Merely travelling near or parallel to a door is irrelevant.
func _crossing(door: DoorProp, actor: Dictionary) -> Dictionary:
	var node: Node3D = actor.node
	var previous: Vector3 = door.to_local(node.global_position)
	var source_side: float = signf(previous.z)
	var plane_point := Vector3.INF
	var plane_segment := -1
	var path: PackedVector3Array = actor.path
	for i in range(int(actor.leg), path.size()):
		var next: Vector3 = door.to_local(path[i])
		if absf(next.z) <= PLANE_EPSILON:
			# Preserve the actual on-plane waypoint even outside the aperture:
			# skipping it would invent a chord through a nearby unrelated door.
			if source_side != 0.0 and (plane_segment < 0 \
					or (not _inside_aperture(door, plane_point) and _inside_aperture(door, next))):
				plane_point = next
				plane_segment = i
			previous = next
			continue
		var next_side: float = signf(next.z)
		if source_side != 0.0 and next_side != source_side:
			var at: Vector3 = plane_point
			var segment: int = plane_segment
			if segment < 0:
				var ratio: float = -previous.z / (next.z - previous.z)
				at = previous.lerp(next, ratio)
				segment = i
			if _inside_aperture(door, at):
				return {"point": door.to_global(at), "segment": segment,
					"source_side": source_side, "saw_source": false,
					"engaged": false, "crossed": false, "completed": false}
		previous = next
		source_side = next_side
		plane_point = Vector3.INF
		plane_segment = -1
	return {}


func _inside_aperture(door: DoorProp, at: Vector3) -> bool:
	if not at.is_finite(): return false
	# Runtime doors are upright yaw-mounted; reject unsupported shear/tilt
	# rather than interpret an unrelated floor as an operable passage.
	var up: Vector3 = door.global_basis.y.normalized()
	if up.dot(Vector3.UP) < 0.999:
		return false
	var scale_y: float = maxf(door.global_basis.y.length(), 0.0001)
	return at.x >= 0.0 and at.x <= door.width and at.y >= -CLEARANCE / scale_y \
			and at.y + BODY_HEIGHT / scale_y <= door.height + CLEARANCE / scale_y


func _distance_to_crossing(actor: Dictionary, passage: Dictionary) -> float:
	var leg: int = actor.leg
	var segment: int = passage.segment
	if leg > segment: return 0.0
	var at: Vector3 = actor.node.global_position
	var distance := 0.0
	var path: PackedVector3Array = actor.path
	for i in range(leg, mini(segment, path.size())):
		distance += at.distance_to(path[i])
		at = path[i]
	return distance + at.distance_to(passage.point)


func _sweep_radius(door: DoorProp) -> float:
	var scale_bound: float = maxf(door.global_basis.x.length(), door.global_basis.z.length())
	if not is_instance_valid(door._body):
		return door.width * scale_bound
	var radius := 0.0
	for child in door._body.get_children():
		var collision := child as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D:
			continue
		var box := collision.shape as BoxShape3D
		var half: Vector3 = box.size * 0.5
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				# Rotation preserves this local radius. The largest host-axis
				# scale bounds every yaw, not merely the current world corners.
				var corner: Vector3 = door._body.basis \
						* (collision.transform * Vector3(half.x * x, 0, half.z * z))
				radius = maxf(radius, Vector2(corner.x, corner.z).length() * scale_bound)
	return maxf(radius, door.width * scale_bound)


func _occupies_sweep(door: DoorProp, foot: Vector3) -> bool:
	var base: Vector3 = door.global_position
	var top: Vector3 = door.to_global(Vector3(0, door.height, 0))
	if foot.y >= maxf(base.y, top.y) + CLEARANCE \
			or foot.y + BODY_HEIGHT <= minf(base.y, top.y) - CLEARANCE:
		return false
	var pivot: Vector3 = door._body.global_position if is_instance_valid(door._body) else base
	return Vector2(foot.x - pivot.x, foot.z - pivot.z).length() \
			<= _sweep_radius(door) + BODY_RADIUS + CLEARANCE


func _same_world(door: DoorProp, node: Node3D) -> bool:
	return is_instance_valid(door) and is_instance_valid(node) \
			and door.is_inside_tree() and node.is_inside_tree() \
			and door.get_world_3d() == node.get_world_3d()


func _doors_moved(state: Dictionary) -> bool:
	for passage: Dictionary in state.doors:
		var door: DoorProp = passage.door.get_ref() as DoorProp
		if not is_instance_valid(door) or not door.is_inside_tree() \
				or door.global_transform != passage.transform:
			return true
	return false


func _prune() -> void:
	for key in _routes.keys():
		var node: Node3D = _routes[key].node.get_ref() as Node3D
		if not is_instance_valid(node) or not node.is_inside_tree():
			_relinquish(_engaged.get(key, []))
			_routes.erase(key)
			_engaged.erase(key)


func _relinquish(passages: Array) -> void:
	for passage: Dictionary in passages:
		var door: DoorProp = passage.door.get_ref() as DoorProp
		if is_instance_valid(door) and door.is_inside_tree():
			_pending_close[door.get_instance_id()] = weakref(door)


func dispose() -> void:
	_routes.clear()
	_engaged.clear()
	_pending_close.clear()


func stats() -> Dictionary:
	return {"actor_routes": _routes.size(), "pending_closes": _pending_close.size(),
		"engaged_actors": _engaged.size()}
