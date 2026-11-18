extends SkeletonModifier3D
## Head and eyes follow what a person is attending to, on the rebuilt cast's
## skeleton. It runs after the pose or clip of the frame and turns the neck and
## head toward the target within what a neck can do; the eyes go first and
## cover what the head does not. Given a face controller, it tells it where
## the eyes point. Something behind the person is not followed: the head
## comes back to rest, as a person's does.
##
## It writes Neck and Head (and through the face controller, the eye shapes),
## and reads Spine2. Who is attended to is decided elsewhere and handed in
## with attend(); this only carries it out.

## How far the head will turn and tip from the chest, in degrees.
@export var head_yaw := 58.0
@export var head_pitch := 28.0
## How far the eyes will turn in the head.
@export var eye_yaw := 26.0
@export var eye_pitch := 16.0
## The head's share of a turn; the eyes take the rest.
@export var head_share := 0.72
## Degrees a second the head may turn, and how soon it settles.
@export var head_speed := 170.0
@export var settle_seconds := 0.22
## Past this angle from the chest the target is behind and is let go.
@export var give_up := 105.0

var face: Node
var _target_node: Node3D
var _target_point := Vector3.ZERO
var _attending := false
var _yaw := 0.0
var _pitch := 0.0
var _weight := 0.0
var _random := RandomNumberGenerator.new()
var _glance_in := 4.0
var _glance_left := 0.0
var _glance := Vector2.ZERO
var _neck := -1
var _head := -1
var _chest := -1


func bind(seed_text: String = "") -> bool:
	var body := get_skeleton()
	if body == null:
		return false
	_neck = body.find_bone("Neck")
	_head = body.find_bone("Head")
	_chest = body.find_bone("Spine2")
	_random.seed = hash(seed_text)
	_glance_in = _random.randf_range(2.5, 6.0)
	return _neck >= 0 and _head >= 0 and _chest >= 0


## Attend to a node (followed as it moves) or to a point in the world.
func attend(target: Variant) -> void:
	if target is Node3D:
		_target_node = target
		_attending = true
	elif target is Vector3:
		_target_node = null
		_target_point = target
		_attending = true
	else:
		rest()


func rest() -> void:
	_attending = false
	_target_node = null


func attending() -> bool:
	return _attending


## Degrees the head is turned and tipped now: x toward the person's left, y up.
func head_turn() -> Vector2:
	return Vector2(_yaw, _pitch) * _weight


func _process_modification() -> void:
	var body := get_skeleton()
	if body == null or _head < 0:
		return
	var delta := get_process_delta_time()
	var chest_now := body.get_bone_global_pose(_chest).basis.orthonormalized()
	var chest_turn := chest_now * body.get_bone_global_rest(_chest).basis.orthonormalized().inverse()
	var want_yaw := 0.0
	var want_pitch := 0.0
	var seen := false
	if _attending and (_target_node == null or is_instance_valid(_target_node)):
		var point := _target_node.global_position if _target_node != null else _target_point
		var eyes := body.get_bone_global_pose(_head).origin + Vector3(0, 0.09, 0.06)
		var way := chest_turn.inverse() * (body.global_transform.affine_inverse() * point - eyes)
		if way.length() > 0.05:
			want_yaw = rad_to_deg(atan2(way.x, way.z))
			want_pitch = rad_to_deg(atan2(way.y, Vector2(way.x, way.z).length()))
			seen = absf(want_yaw) <= give_up
	_weight = move_toward(_weight, 1.0 if seen else 0.0, delta / 0.5)
	if not seen:
		want_yaw = 0.0
		want_pitch = 0.0
	# The head: its share of the turn, no faster than a neck turns, easing in.
	var head_goal := Vector2(clampf(want_yaw * head_share, -head_yaw, head_yaw), clampf(want_pitch * head_share, -head_pitch, head_pitch))
	var ease := 1.0 - exp(-delta / maxf(settle_seconds, 0.01))
	var step := (head_goal - Vector2(_yaw, _pitch)) * ease
	step = step.limit_length(head_speed * delta)
	_yaw += step.x
	_pitch += step.y
	var eased := smoothstep(0.0, 1.0, _weight)
	var half := Basis(Vector3.UP, deg_to_rad(_yaw * eased * 0.5)) * Basis(Vector3.RIGHT, deg_to_rad(-_pitch * eased * 0.5))
	var turn := chest_turn * half * chest_turn.inverse()
	for bone: int in [_neck, _head]:
		var pose := body.get_bone_global_pose(bone)
		body.set_bone_global_pose(bone, Transform3D(turn * pose.basis, pose.origin))
	# The eyes: what is left of the turn, and now and then a glance aside.
	_glance_in -= delta
	if _glance_in <= 0.0:
		_glance_in = _random.randf_range(3.0, 7.5)
		_glance_left = _random.randf_range(0.25, 0.6)
		_glance = Vector2(_random.randf_range(-14.0, 14.0), _random.randf_range(-7.0, 4.0))
	_glance_left -= delta
	if face != null and face.has_method("look"):
		var eyes_at := Vector2.ZERO
		if seen:
			eyes_at = Vector2(clampf(want_yaw - _yaw, -eye_yaw, eye_yaw), clampf(want_pitch - _pitch, -eye_pitch, eye_pitch))
		if _glance_left > 0.0:
			eyes_at += _glance
		face.call("look", eyes_at)
