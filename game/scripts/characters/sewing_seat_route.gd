extends RefCounted
## One real chair lease beneath the timetable. This owner alone transfers roots;
## presentation supplies an atomic, preflighted pose and never moves the body.
const CHAIR := "2B_din_dc2"
const MACHINE := "2B_sewing_machine"
const RESIDENT := "lena_ortiz"
const ALIGN_LOCAL := Vector3(.50, 0, -.52)
const ROOT_DROP := .0075
const TRANSFER_SECONDS := 1.2
var route: Node3D
var machine: Node3D
var chair: Node3D
var seats: Node3D
var phase := ""
var amount := 0.0
var blocked_reason := ""
var _chair_pose := Transform3D.IDENTITY
var _machine_pose := Transform3D.IDENTITY
var _standing := Transform3D.IDENTITY
var _seated := Transform3D.IDENTITY
var _face_player := false
var _chair_rids: Array[RID] = []
var _capsule := CapsuleShape3D.new()
var _failed := false
var _refused_context := ""
var _settle_left := 0.0

func active() -> bool: return not phase.is_empty()

func arrived() -> bool:
	return phase == "seated" and not _failed and is_equal_approx(amount, 1.0) and _fixtures_still() and _lease_live()

func begin(owner: Node3D) -> bool:
	if active() or owner.resident != RESIDENT or owner.actor == null: return false
	if _context(owner) == _refused_context: return false
	var body: Node3D = owner.actor
	for method: String in ["set_sewing_seat_pose", "can_set_sewing_seat_pose", "stop_sewing_seat_work", "clear_sewing_seat_pose"]:
		if not body.has_method(method): return false
	if owner.world.get("seat_gestures") == null: return false
	route = owner
	machine = route.world.adapter.resolve(MACHINE) as Node3D
	chair = route.world.adapter.resolve(CHAIR) as Node3D
	seats = route.world.seat_gestures
	if not is_instance_valid(machine) or not is_instance_valid(chair) or not machine.is_visible_in_tree() or not chair.is_visible_in_tree(): return false
	if not seats.seats.has(CHAIR) or not is_instance_valid(seats.seats[CHAIR].area) or seats.seats[CHAIR].area.get_parent() != chair: return false
	if chair is RigidBody3D and not (chair as RigidBody3D).freeze and not (chair as RigidBody3D).sleeping: return false
	if not seats.can_reserve(CHAIR, RESIDENT, body): return false
	_chair_pose = chair.global_transform
	_machine_pose = machine.global_transform
	if not _upright(_chair_pose.basis) or not _upright(_machine_pose.basis): return false
	var relative := machine.to_local(chair.global_position)
	if relative.distance_to(Vector3(0, 0, -.6759)) > .01: return false
	var facing := chair.global_basis * Basis(Vector3.UP, PI)
	if facing.z.normalized().dot(machine.global_basis.z.normalized()) < .999: return false
	_seated = Transform3D(facing, chair.global_position - machine.global_basis.y * ROOT_DROP)
	_capsule.radius = .28
	_capsule.height = 1.40
	_chair_rids.clear()
	if chair is CollisionObject3D: _chair_rids.append((chair as CollisionObject3D).get_rid())
	for collider: Node in chair.find_children("*", "CollisionObject3D", true, false):
		_chair_rids.append((collider as CollisionObject3D).get_rid())
	if _chair_rids.is_empty() or not _seat_supported(): return false
	var alignment := machine.to_global(ALIGN_LOCAL)
	if not _motion_clear(body.global_position, alignment, false): return false
	if not seats.reserve(CHAIR, RESIDENT, body): return false
	route.world.loop_performances._release_activity(RESIDENT)
	_face_player = body.face_interacting_player
	body.face_interacting_player = false
	amount = 0.0
	_failed = false
	blocked_reason = ""
	phase = "align"
	return true

func tick(delta: float) -> bool:
	if not active(): return false
	if not is_instance_valid(route) or not is_instance_valid(route.actor):
		close()
		return false
	var body: Node3D = route.actor
	route._parked = false
	route._sample -= delta
	if route._sample <= 0.0:
		route._sample = .5
		route._select_destination()
		route._dress_unseen()
	var wanted: bool = route.world.loop_performances.sewing_phase_requested(RESIDENT)
	var talking: bool = route._talking() or route._player_lock_holds_route()
	if not _fixtures_still() or not _lease_live():
		_fail("sewing chair moved, unloaded or reservation changed")
		return true
	if phase == "align":
		if not wanted:
			close()
			return false
		if talking:
			body._set_walking(false)
			return true
		var alignment := machine.to_global(ALIGN_LOCAL)
		if body.global_position.distance_to(alignment) > .002:
			var next := body.global_position.move_toward(alignment, route.route_speed * minf(delta, .05))
			if not _motion_clear(body.global_position, next, false):
				_fail("standing sewing alignment obstructed")
				close()
				return false
			body.global_position = next
			body.set_route_motion(true, 0.0, route.route_speed)
			return true
		body._set_walking(false)
		var yaw := atan2(_seated.basis.z.x, _seated.basis.z.z)
		body.global_rotation.y = rotate_toward(body.global_rotation.y, yaw, deg_to_rad(120.0)*delta)
		if absf(angle_difference(body.global_rotation.y, yaw)) > .001: return true
		_standing = body.global_transform
		if not body.set_sewing_seat_pose(machine, chair, 0.0, false):
			_fail("standing sewing pose refused")
			close()
			return false
		_settle_left = .25 # Outgoing walking/work crossfade must finish before pose FK preflight.
		phase = "settle"
		return true
	body._set_walking(false)
	# Talking stops handwork immediately and retains the currently supported pose.
	if talking:
		body.set_sewing_seat_pose(machine, chair, amount, false)
		return true
	if not wanted or _failed:
		_stop_work()
		if is_zero_approx(amount):
			close()
			return false
		phase = "stand"
	if phase == "settle":
		_settle_left -= minf(delta, .05)
		if _settle_left > 0.0: return true
		if not _motion_clear(_standing.origin, _seated.origin, true) or not body.can_set_sewing_seat_pose(machine, chair, _seated, 1.0):
			_fail("complete sewing entry clearance or endpoint pose refused")
			close()
			return false
		phase = "sit"
		return true
	if phase == "seated":
		if not body.set_sewing_seat_pose(machine, chair, 1.0, true): _fail("seated sewing pose refused")
		return true
	var goal := 0.0 if phase == "stand" else 1.0
	var next_amount := move_toward(amount, goal, minf(delta, .05)/TRANSFER_SECONDS)
	var next_pose := _standing.interpolate_with(_seated, next_amount)
	if not _motion_clear(body.global_position, next_pose.origin, true) or not _seat_supported():
		_fail("sewing transfer support or swept clearance refused")
		body.set_sewing_seat_pose(machine, chair, amount, false)
		return true
	if not body.can_set_sewing_seat_pose(machine, chair, next_pose, next_amount):
		_fail("sewing transfer pose preflight refused")
		body.set_sewing_seat_pose(machine, chair, amount, false)
		return true
	var previous := body.global_transform
	body.global_transform = next_pose
	# The presentation contract is atomic on false. No signal, route step or
	# lease mutation occurs between this assignment and its pre-render rollback.
	if not body.set_sewing_seat_pose(machine, chair, next_amount, false):
		body.global_transform = previous
		_fail("sewing transfer atomic pose application refused")
		return true
	amount = next_amount
	if is_equal_approx(amount, 1.0): phase = "seated"
	elif is_zero_approx(amount):
		close()
		return false
	return true

func _fail(reason: String) -> void:
	blocked_reason = reason
	_failed = true
	_stop_work()
	if is_instance_valid(route):
		_refused_context = _context(route)
		route.blocked_reason = reason
		if is_instance_valid(route.actor): route.actor._set_walking(false)

func _stop_work() -> void:
	if not is_instance_valid(route) or not is_instance_valid(route.actor): return
	if route.actor.has_method("stop_sewing_seat_work"): route.actor.stop_sewing_seat_work()
	elif is_instance_valid(machine) and is_instance_valid(chair): route.actor.set_sewing_seat_pose(machine, chair, amount, false)

func _context(owner: Node) -> String:
	return str(owner.world.loop_performances._identity) + "/" + str(owner.world.loop_performances.phase_for(RESIDENT).get("phase_id", ""))

func _lease_live() -> bool:
	if not is_instance_valid(seats) or not seats.taken.has(CHAIR): return false
	var claim: Variant = seats.taken[CHAIR]
	return claim is Dictionary and claim.get("owner") is WeakRef and claim.owner.get_ref() == route.actor and claim.get("resident") == RESIDENT

func _fixtures_still() -> bool:
	return is_instance_valid(seats) and seats.seats.has(CHAIR) and is_instance_valid(seats.seats[CHAIR].area) and seats.seats[CHAIR].area.get_parent() == chair and is_instance_valid(chair) and is_instance_valid(machine) and chair.is_visible_in_tree() and machine.is_visible_in_tree() and chair.global_transform.is_equal_approx(_chair_pose) and machine.global_transform.is_equal_approx(_machine_pose)

static func _upright(basis: Basis) -> bool:
	return basis.get_scale().distance_to(Vector3.ONE) < .001 and basis.y.dot(Vector3.UP) > .999

func _seat_supported() -> bool:
	var marker: Node3D = seats.seats[CHAIR].area
	var point := marker.global_position
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.08, point-Vector3.UP*.08, 1)
	var hit := chair.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider is CollisionObject3D and (hit.collider as CollisionObject3D).get_rid() in _chair_rids and hit.normal.y > .8 and absf(hit.position.y-point.y) <= .008

func _motion_clear(from: Vector3, to: Vector3, seat_transition: bool) -> bool:
	if not _fixtures_still() or (seat_transition and not _lease_live()): return false
	if not route._characters_clear(to) or not route._route_step_allowed(to): return false
	var space: PhysicsDirectSpaceState3D = route.actor.get_world_3d().direct_space_state
	var excluded: Array[RID] = _chair_rids if seat_transition else []
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = _capsule
	shape.collision_mask = 1
	shape.exclude = excluded
	shape.transform.origin = from + Vector3.UP*.95
	shape.motion = to-from
	var sweep := space.cast_motion(shape)
	if sweep.size()!=2 or sweep[0] < 1.0: return false
	# cast_motion ignores existing overlaps. Check both ends independently.
	for at: Vector3 in [from, to]:
		shape.motion = Vector3.ZERO
		shape.transform.origin = at+Vector3.UP*.95
		if not space.intersect_shape(shape, 1).is_empty(): return false
		var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.34, at-Vector3.UP*.5, 1, excluded)
		var floor_hit := space.intersect_ray(ray)
		if floor_hit.is_empty() or floor_hit.normal.y < .45 or absf(floor_hit.position.y-at.y) > .03: return false
	return true

func close() -> void:
	if is_instance_valid(route) and is_instance_valid(route.actor):
		if route.actor.has_method("clear_sewing_seat_pose"): route.actor.clear_sewing_seat_pose()
		if not route.actor.face_interacting_player: route.actor.face_interacting_player = _face_player
		if is_instance_valid(seats): seats.release(CHAIR, RESIDENT, route.actor)
	phase = ""
	amount = 0.0
