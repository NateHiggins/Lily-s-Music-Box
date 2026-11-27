extends "res://scripts/characters/orison_v2_resident_route.gd"
## During an authored visit, yield to real neighboring bodies before the
## existing route motor takes a step. Keep its geometry, doors and collision
## work in the parent; never move around a person by cutting a new corner.

var _sewing_seat: RefCounted

var _bar_identities: Dictionary[int, String] = {}


func _point(identity: String, point: Vector3) -> int:
	var id := super._point(identity, point)
	if identity.begins_with("bar_"):
		_bar_identities[id] = identity
	return id


func _is_bar_point(id: int) -> bool:
	var identity: String = _bar_identities.get(id, "")
	# A rebuilt graph can reuse an old numeric point ID.
	return not identity.is_empty() and identities.get(identity, -1) == id


func _route_step_allowed(next: Vector3) -> bool:
	if not is_instance_valid(world) or world.get("loop_performances") == null:
		return true
	# The independently owned bar route keeps its measured seat/aisle clearance.
	if destination == "harukiya_bar" or _is_bar_point(current_id) \
			or (not path.is_empty() and _is_bar_point(path[0])):
		return true
	return bool(world.loop_performances.allow_step(resident, next))


func _physics_process(delta: float) -> void:
	if _sewing_seat != null and _sewing_seat.active() and _sewing_seat.tick(delta): return
	super._physics_process(delta)


func sewing_seat_active() -> bool:
	return _sewing_seat != null and _sewing_seat.active()


func sewing_seat_arrived() -> bool:
	return sewing_seat_active() and _sewing_seat.arrived()


func _exit_tree() -> void:
	if _sewing_seat != null: _sewing_seat.close()
	super._exit_tree()


func _route_tick(delta: float) -> void:
	super._route_tick(delta)
	# Restore the work-facing stance after a caller releases Lena. The base
	# motor still owns all movement and refuses dialogue/player locks first.
	if resident != "lena_ortiz" or destination != "unit:sewing" or actor == null: return
	if _talking() or _player_lock_holds_route() or world.get("loop_performances") == null: return
	var machine: Node3D = world.loop_performances.sewing_work_target(resident)
	if machine == null: return
	if _sewing_seat == null: _sewing_seat = preload("res://scripts/characters/sewing_seat_route.gd").new()
	if _sewing_seat.begin(self): return
	if not face_sewing_station(actor, machine, delta): _parked = false


static func face_sewing_station(body: Node3D, machine: Node3D, delta: float) -> bool:
	var toward := (machine.global_position - body.global_position).slide(Vector3.UP)
	if toward.is_zero_approx(): return true
	var yaw := atan2(toward.x, toward.z)
	body.global_rotation.y = rotate_toward(body.global_rotation.y, yaw, deg_to_rad(120.0) * maxf(0.0, delta))
	return absf(angle_difference(body.global_rotation.y, yaw)) < .001
