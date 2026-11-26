extends "res://scripts/characters/pose_pipeline.gd"
## Temporary pose writer for an actor borrowed from the Harukiya cast.
const Stand := preload("res://scripts/characters/stand_pose.gd")

var person_id := ""
var actor: Node3D
var model: Node3D
var skeleton: Skeleton3D
var pipeline: SkeletonModifier3D
var ready_ok := false
var stand := Stand.new()
var contact: Callable
var _state := {}
var _sample := 0.0
var _active_sample := false
var _cues: Array = []
var _prior := {}
var _arrival_pose: Array[Transform3D] = []


func attach(owner: Node3D) -> bool:
	actor = owner
	person_id = actor.person_id
	model = actor.model
	skeleton = actor.skeleton
	pipeline = self
	active = false
	skeleton.add_child(self)
	skeleton.move_child(self, 0)
	ready_ok = stand.load_table() and bind(skeleton, person_id)
	return ready_ok


func acquire(cues: Array) -> void:
	_prior = {
		"actor": actor.is_processing(), "attention": actor.attention.is_processing(),
		"modifier": actor.attention.pipeline.active, "face": actor.face.is_processing(),
	}
	_cues = cues
	actor.set_process(false)
	actor.attention.set_process(false)
	actor.attention.pipeline.active = false
	actor.face.set_process(false)
	actor.face.stop_speaking()
	_arrival_pose.clear()
	for index in skeleton.get_bone_count():
		_arrival_pose.append(skeleton.get_bone_pose(index))
	active = true


func release() -> void:
	active = false
	_active_sample = false
	contact = Callable()
	if _prior.is_empty() or not is_instance_valid(actor):
		return
	actor.face.stop_speaking()
	actor.face.step(0.25)
	actor.face.set_process(bool(_prior.face) and actor.visible)
	actor.attention.pipeline.active = bool(_prior.modifier) and actor.visible
	actor.attention.set_process(bool(_prior.attention) and actor.visible)
	actor.set_process(bool(_prior.actor) and actor.visible)
	_prior.clear()


func seek(seconds: float, state: Dictionary) -> void:
	_sample = seconds
	_state = state
	_active_sample = true
	var pose := str(state.pose)
	skeleton.reset_bone_poses()
	stand.apply(skeleton, pose, false, seconds, 0.0)


func settle(weight: float, state: Dictionary) -> void:
	seek(0.0, state)
	_active_sample = false
	for index in _arrival_pose.size():
		skeleton.set_bone_pose(index, _arrival_pose[index].interpolate_with(skeleton.get_bone_pose(index), weight))


func _process_modification_with_delta(_delta: float) -> void:
	if not _active_sample:
		return
	_clock = _sample
	_attending = true
	_target = _state.gaze_target
	_weight = float(_state.gaze_weight)
	var eye := skeleton.get_bone_global_pose(int(profile.bones.head)).origin
	var aim := skeleton.to_local(_target) - eye
	var chest := int(profile.bones.chest)
	var forward: Vector3 = profile.forward
	var rest := skeleton.get_bone_global_rest(chest).basis.orthonormalized()
	var posed := skeleton.get_bone_global_pose(chest).basis.orthonormalized()
	var chest_forward := (posed * rest.inverse() * forward).normalized()
	_looking = _bounded(aim.normalized(), chest_forward) if aim.length_squared() > 0.0025 else head_facing()
	step(0.0)
	if contact.is_valid():
		contact.call(self)
	_apply_mouth()
	frames += 1


func _apply_mouth() -> void:
	var face: Node = actor.face
	var data: Dictionary = face.get("_data")
	var mouth := {}
	for tap: Vector2 in [Vector2(0.005, 0.25), Vector2(0.04, 0.5), Vector2(0.075, 0.25)]:
		var at := _sample + tap.x
		var lo := 0
		var hi := _cues.size()
		while lo < hi:
			var mid := (lo + hi) >> 1
			if float(_cues[mid].end) <= at:
				lo = mid + 1
			else:
				hi = mid
		if lo >= _cues.size() or float(_cues[lo].start) > at:
			continue
		var cue: Dictionary = _cues[lo]
		var targets: Dictionary = data.mouth_shapes.get(str(cue.value), {})
		for shape: String in targets:
			mouth[shape] = float(mouth.get(shape, 0.0)) + float(targets[shape]) * tap.y * float(cue.strength)
	face.set("_mouth", mouth)
	face.set("_talk", 0.0 if mouth.is_empty() else 1.0)
	face.step(0.0)
