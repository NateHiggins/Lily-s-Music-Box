extends CharacterBody3D
## Independent flight presentation. No inventory, dialogue, case or save writes.
## The world adapter supplies witnesses and explicit requests; this body owns
## only its movement. One sphere replaces per-part moving concave colliders.
signal behavior_changed(behavior: StringName)
signal recovery_requested
const Mechanism := preload("res://scripts/device/companion_mechanism.gd")

@export var preferred_distance := 1.25
@export var distance_band := Vector2(.85, 1.85)
@export var lateral_offset := .72
@export var reading_distance := .48
@export var maximum_speed := 8.0
@export var acceleration := 9.0
@export var deceleration := 13.0
@export var hull_radius := .31
@export var clearance := .01
@export var probe_interval := .125
@export var attention_dwell := .45
@export var attention_release := .9
@export_range(0.0, 1.0) var motion_intensity := .6

const REQUESTS: Array[StringName] = [&"accompany", &"observe", &"present", &"listen", &"think", &"speak", &"type", &"sleep", &"retreat"]
const READING: Array[StringName] = [&"present", &"listen", &"think", &"speak", &"type"]
const ROUTE_LIMIT := 64
var behavior: StringName = &"accompany"
var initialized := false
var query_count := 0
var recovery_count := 0
var _player: CharacterBody3D
var _camera: Camera3D
var _rig: Mechanism
var _requested: StringName = &"accompany"
var _space: PhysicsDirectSpaceState3D
var _sphere := SphereShape3D.new()
var _probe := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _excluded: Array[RID] = []
var _anchor_yaw := 0.0
var _reading_basis := Basis.IDENTITY
var _target := Vector3.ZERO
var _candidate := 0
var _accepted_candidate := -1
var _primary_retry := 1.4
var _probe_left := 0.0
var _current_visible := false
var _direct_clear := true
var _routing := false
var _attended := false
var _gaze := 0.0
var _away := 0.0
var _stalled := 0.0
var _lost := 0.0
var _last_player := Vector3.ZERO
var _breadcrumbs: Array[Vector3] = []
var _route_cursor := 0
var _eye_avoid_side := 0.0
var _eye_waypoint := Vector3.ZERO
var _eye_waypoint_active := false

func _ready() -> void:
	set_physics_process(false)

func setup(player: CharacterBody3D, camera: Camera3D, rig: Mechanism) -> bool:
	if initialized or not is_instance_valid(player) or not is_instance_valid(camera) or not is_instance_valid(rig): return false
	for number: float in [preferred_distance, reading_distance, maximum_speed, acceleration, deceleration, hull_radius, probe_interval, attention_dwell, attention_release]:
		if not is_finite(number) or number <= 0.0: return false
	if not is_finite(clearance) or clearance < 0.0 or reading_distance < hull_radius + clearance + .08: return false
	if not is_finite(lateral_offset) or not is_finite(motion_intensity) or motion_intensity < 0.0 or motion_intensity > 1.0: return false
	if not distance_band.is_finite() or distance_band.x <= 0.0 or distance_band.y < distance_band.x: return false
	_player = player; _camera = camera; _rig = rig
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0 # Player movement has priority; this machine cannot block it.
	collision_mask = 1
	max_slides = 4
	safe_margin = .003
	_sphere.radius = hull_radius + clearance
	var collision := CollisionShape3D.new()
	collision.shape = _sphere
	add_child(collision)
	add_collision_exception_with(player)
	_excluded = [get_rid(), player.get_rid()]
	_probe.shape = _sphere; _probe.collision_mask = collision_mask
	_probe.collide_with_areas = false; _probe.exclude = _excluded
	_ray.collision_mask = collision_mask; _ray.collide_with_areas = false; _ray.exclude = _excluded
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space = get_world_3d().direct_space_state
	_anchor_yaw = _camera.global_rotation.y
	_reading_basis = _camera.global_basis
	var placed := false
	for index in 8:
		var point := _candidate_position(index)
		if _clear(point):
			global_position = point; _target = point; _accepted_candidate = index; _candidate = index; placed = true
			break
	if not placed: return false
	_last_player = _player.global_position
	_breadcrumbs.append(_route_point())
	initialized = true
	_update_pose(1.0, 0.0)
	reset_physics_interpolation()
	set_physics_process(true)
	return true

func request_behavior(value: StringName) -> bool:
	if value not in REQUESTS: return false
	if _requested != value:
		_requested = value; _candidate = 0; _accepted_candidate = -1; _probe_left = 0.0
	return true

func recall() -> void:
	request_behavior(&"present")
	if is_instance_valid(_camera): _reading_basis = _camera.global_basis
	_eye_waypoint_active = false; _eye_avoid_side = 0.0
	_candidate = 0; _accepted_candidate = -1; _probe_left = 0.0

func release_attention() -> void:
	_requested = &"accompany"; _attended = false; _gaze = 0.0; _away = 0.0
	_candidate = 0; _probe_left = 0.0

func steady_for_input() -> bool:
	return initialized and not _routing and _accepted_candidate >= 0 and behavior in READING and _current_visible and velocity.length() < .12 and global_position.distance_to(_target) < .06

func _physics_process(delta: float) -> void:
	if not initialized or not is_instance_valid(_player) or not is_instance_valid(_camera): return
	var flat_velocity := Vector3(_player.velocity.x, 0, _player.velocity.z)
	if flat_velocity.length() > .25:
		var desired_yaw := atan2(-flat_velocity.x, -flat_velocity.z)
		_anchor_yaw = rotate_toward(_anchor_yaw, desired_yaw, delta * 2.4)
	_record_route()
	_update_attention(delta)
	var next: StringName = _requested
	if next == &"accompany":
		next = &"present" if _attended else (&"travel" if flat_velocity.length() > 3.8 else &"accompany")
	if flat_velocity.length() > 3.8 and next != &"retreat": next = &"travel"
	if next != behavior:
		if next in READING and behavior not in READING: _reading_basis = _camera.global_basis
		behavior = next; _candidate = 0; _accepted_candidate = -1; _primary_retry = 1.4; _probe_left = 0.0
		if behavior in [&"travel", &"retreat", &"sleep"]: _rig.request_keyboard(false)
		behavior_changed.emit(behavior)
	_probe_left -= delta
	_primary_retry -= delta
	if _probe_left <= 0.0:
		_probe_left = maxf(.04, probe_interval)
		# Bounded work: one visibility ray, one candidate shape, and at most
		# one candidate visibility ray and one full-hull path cast per interval.
		# At most four probes; no furnishings scan.
		_current_visible = _visible_from_player(global_position)
		var point := _candidate_position(_candidate)
		if _clear(point) and (behavior not in READING or _visible_from_player(point)):
			_target = point
			_accepted_candidate = _candidate
			_direct_clear = _path_clear(point)
			# Keep a useful alternate position. An occasional primary retry
			# must not make the machine oscillate between two furnishings.
			if _candidate != 0 and _primary_retry <= 0.0:
				_candidate = 0; _primary_retry = 1.4
		else:
			_direct_clear = false
			if _accepted_candidate == _candidate: _accepted_candidate = -1
			_candidate = _accepted_candidate if _candidate == 0 and _accepted_candidate > 0 else (_candidate + 1) % 8
	var following_route := not _current_visible or not _direct_clear or _stalled > .65
	if following_route and not _routing: _rig.request_keyboard(false)
	_routing = following_route
	var goal := _route_goal() if following_route else _target
	goal = _avoid_eye(goal)
	var error := goal - global_position
	var far := global_position.distance_to(_camera.global_position) > distance_band.y
	var correction_limit := maximum_speed if behavior in [&"travel", &"retreat"] or far else 1.7
	var correction := (error * (5.0 if behavior in READING else 3.2)).limit_length(correction_limit)
	if following_route and error.length() > .15:
		correction = error.normalized() * minf(maximum_speed, maxf(2.5, _player.velocity.length() + 1.3))
	var wanted := correction + (_player.velocity if not following_route else Vector3.ZERO)
	if error.length() < .018 and _player.velocity.length() < .05: wanted = Vector3.ZERO
	wanted = wanted.limit_length(maximum_speed)
	var slowing := wanted.length_squared() < velocity.length_squared()
	velocity = velocity.move_toward(wanted, (deceleration if slowing else acceleration) * delta)
	move_and_slide()
	var actual := get_position_delta().length() / maxf(delta, .000001)
	_stalled = _stalled + delta if wanted.length() > .2 and actual < .04 else 0.0
	_lost = _lost + delta if global_position.distance_to(_camera.global_position) > 8.0 else 0.0
	if _lost > 3.0:
		_lost = 0.0
		recovery_requested.emit() # Adapter must prove invisibility before relocation.
	_update_pose(delta, actual)

func _candidate_position(index: int) -> Vector3:
	var basis := Basis(Vector3.UP, _anchor_yaw)
	var distance := clampf(preferred_distance, distance_band.x, distance_band.y)
	var side := clampf(lateral_offset, -distance * .8, distance * .8)
	var forward := sqrt(distance * distance - side * side)
	var offsets: Array[Vector3] = [Vector3(side, -.12, -forward), Vector3(-side, -.12, -forward), Vector3(.85, -.12, -.6), Vector3(-.85, -.12, -.6), Vector3(.7, -.12, .8), Vector3(-.7, -.12, .8), Vector3(.45, .3, -.8), Vector3(0, -.12, 1.2)]
	var prediction := _player.velocity.limit_length(4.0) * .18
	if behavior in READING:
		basis = _reading_basis
		offsets = [Vector3(0, -.08, -reading_distance), Vector3(.15, -.08, -reading_distance-.1), Vector3(-.15, -.08, -reading_distance-.1), Vector3(.3, -.08, -.7), Vector3(-.3, -.08, -.7), Vector3(0, -.08, -.85), Vector3(.4, .05, -.9), Vector3(-.4, .05, -.9)]
		prediction = Vector3.ZERO
	elif behavior == &"sleep":
		offsets[index] += Vector3(0, -.2, .3)
	elif behavior == &"retreat":
		offsets[index] += Vector3(0, .2, .6)
	return _camera.global_position + basis * offsets[index] + prediction

func _update_attention(delta: float) -> void:
	var direction := global_position - _camera.global_position
	var looking := _current_visible and direction.length_squared() > .001 and (-_camera.global_basis.z).dot(direction.normalized()) > .966
	if looking:
		_gaze += delta; _away = 0.0
		if _gaze >= attention_dwell: _attended = true
	else:
		_away += delta; _gaze = 0.0
		if _away >= attention_release: _attended = false

func _route_point() -> Vector3:
	return Vector3(_player.global_position.x, _camera.global_position.y - .12, _player.global_position.z)

func _record_route() -> void:
	var point := _route_point()
	if _last_player.distance_to(_player.global_position) > 4.0:
		_breadcrumbs.clear(); _route_cursor = 0
	_last_player = _player.global_position
	if _breadcrumbs.is_empty() or _breadcrumbs.back().distance_to(point) >= .3:
		_breadcrumbs.append(point)
		if _breadcrumbs.size() > ROUTE_LIMIT:
			_breadcrumbs.pop_front(); _route_cursor = maxi(0, _route_cursor - 1)
	if _current_visible and not _routing and not _breadcrumbs.is_empty():
		var nearest := INF
		for index in _breadcrumbs.size():
			var distance := global_position.distance_squared_to(_breadcrumbs[index])
			if distance <= nearest: nearest = distance; _route_cursor = index

func _route_goal() -> Vector3:
	if _breadcrumbs.is_empty(): return _target
	_route_cursor = mini(_route_cursor, _breadcrumbs.size() - 1)
	while _route_cursor < _breadcrumbs.size() - 1 and global_position.distance_to(_breadcrumbs[_route_cursor]) < .35:
		_route_cursor += 1
	return _breadcrumbs[_route_cursor]

func _avoid_eye(goal: Vector3) -> Vector3:
	# Fixed camera-relative waypoints: chasing a freshly rotated tangent every
	# tick creates a permanent orbit instead of a route around the eye.
	var eye := _camera.global_position
	var away := global_position - eye
	var radius := hull_radius + clearance + .08
	if away.length_squared() < .000001: away = Vector3.RIGHT
	var normal := away.normalized()
	var destination := goal - eye
	if destination.length() < radius + .02: goal = eye + normal * (radius + .06)
	var segment := goal - global_position
	if segment.length_squared() < .000001: return goal
	var along := clampf((eye - global_position).dot(segment) / segment.length_squared(), 0.0, 1.0)
	if (global_position + segment * along).distance_to(eye) >= radius + .015:
		_eye_avoid_side = 0.0; _eye_waypoint_active = false
		return goal
	if _eye_waypoint_active:
		var held := eye + _eye_waypoint
		if global_position.distance_to(held) > .045: return held
		_eye_waypoint_active = false
	if away.length() < radius + .06:
		_eye_waypoint = normal * (radius + .14)
	else:
		var tangent := normal.cross(Vector3.UP)
		if tangent.length_squared() < .001: tangent = normal.cross(Vector3.RIGHT)
		tangent = tangent.normalized()
		if is_zero_approx(_eye_avoid_side):
			var preference := tangent.dot(destination)
			_eye_avoid_side = signf(preference) if absf(preference) > .02 else 1.0
		_eye_waypoint = (normal + tangent * _eye_avoid_side).normalized() * (radius + .14)
	_eye_waypoint_active = true
	return eye + _eye_waypoint

func _clear(point: Vector3) -> bool:
	_probe.transform = Transform3D(Basis.IDENTITY, point)
	_probe.motion = Vector3.ZERO
	query_count += 1
	return _space.intersect_shape(_probe, 1).is_empty()

func _path_clear(point: Vector3) -> bool:
	_probe.transform = Transform3D(Basis.IDENTITY, global_position)
	_probe.motion = point - global_position
	if _probe.motion.length_squared() < .000001: return true
	query_count += 1
	var progress := _space.cast_motion(_probe)
	_probe.motion = Vector3.ZERO
	return progress.size() == 2 and progress[0] > .99999

func _visible_from_player(point: Vector3) -> bool:
	_ray.from = _camera.global_position; _ray.to = point
	query_count += 1
	return _space.intersect_ray(_ray).is_empty()

func _update_pose(delta: float, speed: float) -> void:
	var direction := _camera.global_position - global_position
	if direction.length_squared() > .001 and absf(direction.normalized().dot(Vector3.UP)) < .98:
		var goal := Basis.looking_at(direction, Vector3.UP, true)
		var lean := -.09 * clampf(speed / maximum_speed, 0, 1) * motion_intensity if behavior not in READING else 0.0
		goal *= Basis.from_euler(Vector3(lean, 0, 0))
		_rig.basis = _rig.basis.orthonormalized().slerp(goal, 1.0 - exp(-delta * 8.0))
	_rig.propulsion = clampf(.42 + speed * .15 + _stalled * .05, .28, 1.8)

func recover_unobserved(point: Vector3, observable: Callable) -> bool:
	# The adapter must account for the main view AND mirrors/other live cameras.
	# Missing visibility authority forbids a teleport, even if pursuit is stuck.
	if not initialized or not point.is_finite() or not observable.is_valid(): return false
	var current: Variant = observable.call(global_position, hull_radius)
	var destination: Variant = observable.call(point, hull_radius)
	if current is not bool or destination is not bool or current or destination: return false
	if not _clear(point): return false
	global_position = point; velocity = Vector3.ZERO; _target = point
	_breadcrumbs.clear(); _route_cursor = 0; _lost = 0.0; _stalled = 0.0; _routing = false; _direct_clear = true
	_eye_waypoint_active = false; _eye_avoid_side = 0.0; _accepted_candidate = -1; _candidate = 0; _probe_left = 0.0
	recovery_count += 1
	reset_physics_interpolation()
	return true
