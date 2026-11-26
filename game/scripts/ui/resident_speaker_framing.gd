extends Node
## A small lens change on a face already in the caller's shot. The cast owns
## the pose; the player keeps the same camera, transform and input throughout.

const RANGE := 3.5
const MAX_LENS_CHANGE := 7.0
var _player: PlayerController
var _camera: Camera3D
var _actor: Node3D
var _body: Skeleton3D
var _head := -1
var _entry_fov := 0.0
var _last_fov := 0.0
var _sight_from := Vector3.INF
var _sight_to := Vector3.INF
var _sight_elapsed := 0.0

func _ready() -> void:
	set_physics_process(false)

func begin(player: PlayerController, resident_id: String) -> void:
	release()
	if not is_instance_valid(player) or player.inspecting() or not is_instance_valid(player.camera):
		return
	var camera := player.camera
	if not camera.is_current() or camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return
	var nearest := RANGE * RANGE
	for node in get_tree().get_nodes_in_group("animated_residents"):
		var actor := node as Node3D
		if actor == null or actor.get("resident_id") != resident_id or not actor.is_visible_in_tree():
			continue
		if actor.get_viewport() != camera.get_viewport():
			continue
		for child in actor.find_children("*", "Skeleton3D", true, false):
			var skeleton := child as Skeleton3D
			var head := skeleton.find_bone("Head")
			if head < 0 or not skeleton.is_visible_in_tree():
				continue
			var eye := _eye(skeleton, head)
			var distance := camera.global_position.distance_squared_to(eye)
			if distance < nearest and distance > 0.8 * 0.8 and _in_shot(camera, eye):
				nearest = distance
				_actor = actor
				_body = skeleton
				_head = head
			break
	if _body == null:
		return
	_player = player
	_camera = camera
	_entry_fov = camera.fov
	_last_fov = _entry_fov
	set_physics_process(true)

func _eye(body: Skeleton3D, head: int) -> Vector3:
	return body.to_global(body.get_bone_global_pose(head).origin + Vector3.UP * 0.08)

func _in_shot(camera: Camera3D, eye: Vector3) -> bool:
	if camera.is_position_behind(eye):
		return false
	var view := camera.get_viewport().get_visible_rect()
	if not view.has_area():
		return false
	var uv := (camera.unproject_position(eye) - view.position) / view.size
	# Leave headroom and the lower-third replies clear after a small push in.
	return Rect2(0.15, 0.12, 0.70, 0.50).has_point(uv)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_player) or not is_instance_valid(_body) \
			or not is_instance_valid(_actor) or not _camera.is_current() or not _body.is_visible_in_tree() or _player.inspecting() \
			or not _player.call_locked or not is_equal_approx(_camera.fov, _last_fov):
		release()
		return
	var eye := _eye(_body, _head)
	var from := _camera.global_position
	var distance := from.distance_to(eye)
	if distance < 0.8 or distance > RANGE or not _in_shot(_camera, eye):
		release()
		return
	# Recheck cover when either endpoint moves, including the first physics tick.
	_sight_elapsed += delta
	if _sight_elapsed >= 0.25 or from.distance_squared_to(_sight_from) > 0.01 or eye.distance_squared_to(_sight_to) > 0.01:
		var query := PhysicsRayQueryParameters3D.create(from, eye, 1, [_player.get_rid()])
		var hit := _camera.get_world_3d().direct_space_state.intersect_ray(query)
		var obstacle := hit.get("collider") as Node
		if not hit.is_empty() and obstacle != _actor and (obstacle == null or not _actor.is_ancestor_of(obstacle)):
			release()
			return
		_sight_elapsed = 0.0
		_sight_from = from
		_sight_to = eye
	var target := _entry_fov - minf(MAX_LENS_CHANGE, _entry_fov * 0.10) * smoothstep(0.8, 2.1, distance)
	_last_fov = move_toward(_last_fov, maxf(1.0, target), 32.0 * delta)
	_camera.fov = _last_fov
	_last_fov = _camera.fov

func release() -> void:
	if is_instance_valid(_camera) and is_equal_approx(_camera.fov, _last_fov):
		_camera.fov = _entry_fov
	_camera = null
	_player = null
	_actor = null
	_body = null
	_head = -1
	_sight_elapsed = 0.0
	_sight_from = Vector3.INF
	_sight_to = Vector3.INF
	set_physics_process(false)

func _exit_tree() -> void:
	release()
