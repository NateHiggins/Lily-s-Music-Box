extends SkeletonModifier3D
## One coordinated pose pipeline per actor. It runs once a frame after the
## AnimationPlayer has posed the skeleton, and composes on top of that, in a
## fixed order:
##
##   1. base        the clip, already applied; never rewritten here
##   2. posture     breath in the lower spine
##   3. gaze        chest, neck and head toward what the actor attends to
##   4. contact     feet and hands meeting the world (not yet built)
##   5. secondary   settle and overshoot (not yet built)
##
## Each layer owns its own bones and no two layers share one, so every bone
## has exactly one writer after the clip. `writers` records who wrote what in
## the last frame, and a second write to a bone is refused and counted, which
## a test holds at zero.
##
## Nothing here moves the actor: navigation owns where a body is. Nothing here
## decides what to look at: `attend` is told by whoever owns attention.

const Profile := preload("res://scripts/characters/rig_profile.gd")
const LAYERS: Array[String] = ["posture", "gaze", "contact", "secondary"]

var profile: RefCounted
## Bone index to the layer that wrote it this frame.
var writers: Dictionary = {}
var refused_writes := 0
## How quickly attention turns the head, as the time to cover most of the way.
var gaze_seconds := 0.35
## The fastest a head turns, in degrees a second.
var gaze_degrees_per_second := 240.0
var breathe := true
## A phase so a room of people does not breathe together.
var breath_phase := 0.0
var _target := Vector3.ZERO
var _attending := false
var _weight := 0.0
## The direction being looked in now, in the skeleton's own space, eased.
var _looking := Vector3.ZERO
var _clock := 0.0
var _last_usec := 0
## A set frame time, for a test that needs the same motion every run.
var fixed_delta := 0.0
## The engine puts the clip's pose back after the skin is updated, so what the
## pipeline did is only readable from what it recorded: the way the head and
## chest faced after the last frame's writes, in the skeleton's own space.
var last_facing := Vector3.ZERO
var last_chest_forward := Vector3.ZERO
var last_eye := Vector3.ZERO
var last_goal := Vector3.ZERO
var frames := 0
var cost_usec := 0


## Fit the pipeline to a skeleton. False when no rig profile fits it.
func bind(body: Skeleton3D) -> bool:
	profile = Profile.for_skeleton(body)
	if profile == null or not (profile.errors as Array).is_empty():
		return false
	_looking = profile.forward
	breath_phase = fposmod(float(body.get_instance_id() % 997) * 0.618, 1.0) * TAU
	return true


## Look at a point in the world. The owner of attention calls this; the
## pipeline only carries it out, within what a neck can do.
func attend(world_point: Vector3) -> void:
	_target = world_point
	_attending = true


## Stop attending: the head eases back to wherever the clip has it.
func rest() -> void:
	_attending = false


func attending() -> bool:
	return _attending


## How far the head is turned from the clip's own pose, 0 to 1.
func gaze_weight() -> float:
	return _weight


func _write(bone: int, pose: Transform3D, layer: String) -> bool:
	if writers.has(bone):
		refused_writes += 1
		return false
	writers[bone] = layer
	get_skeleton().set_bone_global_pose(bone, pose)
	return true


func _process_modification() -> void:
	var body := get_skeleton()
	if body == null or profile == null:
		return
	var now := Time.get_ticks_usec()
	var delta := clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.1) if _last_usec > 0 else 0.016
	_last_usec = now
	step(fixed_delta if fixed_delta > 0.0 else delta)
	frames += 1
	cost_usec += Time.get_ticks_usec() - now


## One frame of the pipeline. Only the engine's modification callback may call
## this: a write made at any other time would stay in the pose.
func step(delta: float) -> void:
	var body := get_skeleton()
	if body == null or profile == null:
		return
	writers.clear()
	_clock += delta
	_posture(body)
	_gaze(body, delta)
	last_facing = head_facing()
	last_eye = body.get_bone_global_pose(int(profile.bones.head)).origin


## Where the head faced after the last frame, in the world.
func facing_world() -> Vector3:
	return (get_skeleton().global_transform.basis.orthonormalized() * last_facing).normalized()


func eye_world() -> Vector3:
	return get_skeleton().global_transform * last_eye


func _turned(pose: Transform3D, turn: Quaternion) -> Transform3D:
	return Transform3D(Basis(turn) * pose.basis, pose.origin)


## Breath: the lower spine tips a little, about the body's side-to-side axis.
func _posture(body: Skeleton3D) -> void:
	if not breathe or not profile.has("spine_low") or profile.breath_radians <= 0.0:
		return
	var bone := int(profile.bones.spine_low)
	var side: Vector3 = (profile.up as Vector3).cross(profile.forward).normalized()
	var angle: float = sin(_clock * TAU / float(profile.breath_seconds) + breath_phase) * float(profile.breath_radians)
	_write(bone, _turned(body.get_bone_global_pose(bone), Quaternion(side, angle)), "posture")


## The way the head faces now, in skeleton space, from the present pose.
func head_facing() -> Vector3:
	var body := get_skeleton()
	return (body.get_bone_global_pose(int(profile.bones.head)).basis.orthonormalized() * (profile.head_forward_local as Vector3)).normalized()


## Keep a wanted direction within what the neck allows, measured from the way
## the chest faces: so many degrees to either side, so many up or down.
func _bounded(wanted: Vector3, chest_forward: Vector3) -> Vector3:
	var up: Vector3 = profile.up
	var level := chest_forward - up * chest_forward.dot(up)
	if level.length() < 0.001:
		return chest_forward
	level = level.normalized()
	var side := up.cross(level).normalized()
	var flat := Vector2(wanted.dot(level), wanted.dot(side))
	var yaw := clampf(atan2(flat.y, flat.x), -float(profile.gaze_yaw), float(profile.gaze_yaw))
	var pitch := clampf(atan2(wanted.dot(up), maxf(flat.length(), 0.0001)), -float(profile.gaze_pitch), float(profile.gaze_pitch))
	return ((level * cos(yaw) + side * sin(yaw)) * cos(pitch) + up * sin(pitch)).normalized()


func _gaze(body: Skeleton3D, delta: float) -> void:
	for joint: String in ["chest", "neck", "head"]:
		if not profile.has(joint):
			return
	var ease := 1.0 - exp(-delta * 3.0 / maxf(gaze_seconds, 0.01))
	_weight = move_toward(_weight, 1.0 if _attending else 0.0, delta / maxf(gaze_seconds * 1.4, 0.01))
	var chest := int(profile.bones.chest)
	var neck := int(profile.bones.neck)
	var head := int(profile.bones.head)
	# The chest's own facing before this layer turns it: limits are measured
	# from the body, so a turned body carries its gaze with it.
	var chest_forward: Vector3 = (body.get_bone_global_pose(chest).basis.orthonormalized()
			* (body.get_bone_global_rest(chest).basis.orthonormalized().inverse() * (profile.forward as Vector3))).normalized()
	last_chest_forward = chest_forward
	var clip_facing := head_facing()
	var wanted := clip_facing
	if _attending:
		var eye := body.get_bone_global_pose(head).origin
		var aim := body.global_transform.affine_inverse() * _target - eye
		if aim.length() > 0.05:
			wanted = _bounded(aim.normalized(), chest_forward)
	if _attending:
		# Eased, never faster than a head turns, and kept inside the neck's
		# limits on the way: the short way between two allowed directions can
		# pass over the top.
		var apart := _looking.angle_to(wanted)
		if apart > 0.0001:
			var turn_by := minf(apart * ease, deg_to_rad(gaze_degrees_per_second) * delta)
			_looking = _bounded(_looking.slerp(wanted, turn_by / apart).normalized(), chest_forward)
	# Released, the direction is held and only its weight lets go, so the head
	# goes back at the pace it came.
	if _weight <= 0.0005:
		_looking = clip_facing
		return
	var goal := clip_facing.slerp(_looking, smoothstep(0.0, 1.0, _weight)).normalized()
	last_goal = goal
	# Chest, then neck, then head, each taking its share of what is left, so
	# the three add up to the whole turn and the head lands on the goal.
	var shares := [[chest, float(profile.chest_share)], [neck, float(profile.neck_share) / maxf(1.0 - float(profile.chest_share), 0.01)], [head, 1.0]]
	for step_row: Array in shares:
		var facing := head_facing()
		if facing.dot(goal) > 0.999999:
			_write(int(step_row[0]), body.get_bone_global_pose(int(step_row[0])), "gaze")
			continue
		var turn := Quaternion(facing, goal)
		var part := Quaternion.IDENTITY.slerp(turn, clampf(float(step_row[1]), 0.0, 1.0))
		_write(int(step_row[0]), _turned(body.get_bone_global_pose(int(step_row[0])), part), "gaze")
