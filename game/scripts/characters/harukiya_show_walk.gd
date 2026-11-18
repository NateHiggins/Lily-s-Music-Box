extends RefCounted
## Moves a member of the existing bar cast along the supplied room-frame route.
## These dimensions match the ordinary resident world motor.
const SPEED := 1.05
const FLOOR_LIFT := .25
const STEP_LIMIT := .25
const TARGET_RADIUS := .001

var actor: Node3D
var arrived := false
var blocked_by := ""
var travelled := 0.0
var _points: PackedVector3Array
var _next := 0
var _moves: AnimationPlayer
var _walking := false
var _former_process := false
var _query := PhysicsShapeQueryParameters3D.new()


func begin(person: Node3D, points: PackedVector3Array) -> bool:
	if is_instance_valid(actor) or not is_instance_valid(person) or not person.is_visible_in_tree() or points.is_empty():
		return false
	for point: Vector3 in points:
		if not point.is_finite():
			return false
	if not person.model.find_children("*", "AnimationPlayer", true, false).is_empty():
		return false
	if not ResidentMovesLibrary.apply(person.model):
		return false
	_moves = person.model.get_node_or_null("GraftedMoves") as AnimationPlayer
	if _moves == null or not _moves.has_animation("walk"):
		if is_instance_valid(_moves):
			_moves.free()
		return false
	actor = person
	_points = points
	_next = 0
	arrived = false
	travelled = 0.0
	_former_process = actor.is_processing()
	actor.set_process(false)
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.40
	_query.shape = capsule
	_query.collision_mask = 1
	return true


func advance(delta: float) -> void:
	if not is_instance_valid(actor) or arrived:
		return
	if not actor.is_visible_in_tree():
		_set_walking(false)
		return
	var at := actor.global_position
	var direction := _points[_next] - at
	direction.y = 0.0
	if direction.length() <= TARGET_RADIUS:
		_next += 1
		if _next == _points.size():
			arrived = true
			_set_walking(false)
			return
		direction = _points[_next] - at
		direction.y = 0.0
	if direction.length_squared() <= 0.000001:
		return
	var next := at + direction.limit_length(SPEED * delta)
	var ground := PhysicsRayQueryParameters3D.create(next + Vector3.UP * .34, next - Vector3.UP * .50, 1)
	var space := actor.get_world_3d().direct_space_state
	var hit := space.intersect_ray(ground)
	var rise := absf(float(hit.position.y) - at.y) if not hit.is_empty() else INF
	if hit.is_empty() or rise > STEP_LIMIT or ((hit.normal as Vector3).y < .45 and rise > .06):
		blocked_by = "floor support"
		_set_walking(false)
		return
	next.y = hit.position.y
	_query.transform.origin = next + Vector3.UP * (FLOOR_LIFT + .70)
	var obstacles := space.intersect_shape(_query, 1)
	if not obstacles.is_empty():
		blocked_by = str(obstacles[0].collider.get_path())
		_set_walking(false)
		return
	var yaw := lerp_angle(actor.global_rotation.y, atan2(direction.x, direction.z), clampf(delta * 12.0, 0.0, 1.0))
	actor.global_transform = Transform3D(Basis(Vector3.UP, yaw), next)
	blocked_by = ""
	travelled += at.distance_to(next)
	_set_walking(true)


func _set_walking(value: bool) -> void:
	if _walking == value:
		return
	_walking = value
	if value:
		_moves.play("walk")
	else:
		_moves.pause()


func retreat_to(home: Vector3) -> PackedVector3Array:
	var path := PackedVector3Array()
	for index in range(_next - 1, -1, -1):
		path.append(_points[index])
	path.append(home)
	return path


func release() -> void:
	if is_instance_valid(_moves):
		_moves.stop()
		_moves.free()
	_moves = null
	_walking = false
	if is_instance_valid(actor):
		actor.set_process(_former_process and actor.is_visible_in_tree())
	actor = null
