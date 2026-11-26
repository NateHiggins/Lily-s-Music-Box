extends Node3D
## Borrows the existing cast writers and stage instruments for one performance.
const Contacts := preload("res://scripts/characters/harukiya_show_contacts.gd")
const Pose := preload("res://scripts/characters/harukiya_show_pose.gd")
const Transport := preload("res://scripts/characters/harukiya_show_transport.gd")
const Timing := preload("res://scripts/characters/harukiya_ensemble_timing.gd")
const PERFORMERS := ["adela_voss", "lily", "stacy"]
const TRANSFER_SECONDS := .75

signal finished

var _transport: Node3D
var _contacts: RefCounted
var _poses := {}
var _performing := false
var _room: OrisonV2BarRegion
var _standing := {}
var _transition := 0
var _progress := 0.0
var _timing := Timing.new()


func prepare(room: OrisonV2BarRegion, actors: Dictionary) -> bool:
	if _transport != null or room.destination == null:
		return false
	_room = room
	for id: String in PERFORMERS:
		var actor: Node3D = actors.get(id)
		if not is_instance_valid(actor) or not actor.ready_ok or not actor.is_visible_in_tree():
			return false
	_transport = Transport.new()
	add_child(_transport)
	if not _transport.prepare():
		_clear()
		return false
	_timing.prepare(_transport.score.voices)
	_transport.global_position = room.to_global(_transport.score.anchors.music_source)
	for id: String in PERFORMERS:
		var pose := Pose.new()
		_poses[id] = pose
		if not pose.attach(actors[id]):
			_clear()
			return false
	_contacts = Contacts.new()
	if not _contacts.prepare(room, _poses, _transport.score):
		_clear()
		return false
	_transport.played_at.connect(_seek)
	_transport.ended.connect(_on_end)
	return true


func destinations() -> Dictionary:
	return _contacts.placements.duplicate() if _contacts != null else {}


func route(id: String) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point: Vector3 in _transport.score.routes[id]:
		result.append(_room.to_global(point))
	return result


func start() -> bool:
	if _contacts == null or _performing or _transition != 0:
		return false
	for id: String in PERFORMERS:
		var actor: Node3D = _poses[id].actor
		var approach := route(id)
		if not actor.is_visible_in_tree() or actor.global_position.distance_to(approach[-1]) > .06:
			return false
		if not _transfer_clear(id, actor.global_position, _contacts.placements[id].origin):
			return false
	for id: String in PERFORMERS:
		var pose: SkeletonModifier3D = _poses[id]
		_standing[id] = pose.actor.global_transform
		pose.acquire(_transport.score.voices.get(id, []))
	_transition = 1
	_progress = 0.0
	_contacts.bass.show()
	return true


func _transfer_clear(id: String, from: Vector3, to: Vector3) -> bool:
	var torso := CapsuleShape3D.new()
	torso.radius = .28
	torso.height = .75 if id == "stacy" else 1.0
	var state := PhysicsShapeQueryParameters3D.new()
	state.shape = torso
	state.collision_mask = 1
	# Check the drummer's upper body above the rim, throne and resting sticks.
	# The contact pose brings her legs under the kit and her hands onto the grips.
	var torso_height := 1.19 if id == "stacy" else 1.0
	state.transform.origin = from + Vector3.UP * torso_height
	state.motion = to - from
	var space := _room.get_world_3d().direct_space_state
	var sweep := space.cast_motion(state)
	if sweep.size() != 2 or sweep[0] < 1.0:
		return false
	state.transform.origin += state.motion
	state.motion = Vector3.ZERO
	return space.intersect_shape(state, 1).is_empty()


func _physics_process(delta: float) -> void:
	if _transition == 0:
		return
	_progress = clampf(_progress + float(_transition) * delta / TRANSFER_SECONDS, 0.0, 1.0)
	var weight := smoothstep(0.0, 1.0, _progress)
	for id: String in PERFORMERS:
		var origin: Transform3D = _standing[id]
		var pose: SkeletonModifier3D = _poses[id]
		pose.actor.global_transform = origin.interpolate_with(_contacts.placements[id], weight)
		pose.settle(weight, _contacts.state_for(id))
	if _transition == 1 and _progress >= 1.0:
		_play()
	elif _transition == -1 and _progress <= 0.0:
		_finish()


func _play() -> void:
	_transition = 0
	for pose: SkeletonModifier3D in _poses.values():
		pose.contact = _contacts.apply
	_performing = true
	_seek(0.0)
	if not _transport.start():
		_on_end()


func stop() -> void:
	if _performing:
		_transport.stop()
	elif _transition == 1:
		_on_end()


func reset() -> void:
	# Venue shutdown can interrupt a transfer before another physics frame.
	for id: String in _standing:
		var pose: SkeletonModifier3D = _poses.get(id)
		if is_instance_valid(pose) and is_instance_valid(pose.actor):
			pose.actor.global_transform = _standing[id]
	_clear()


func _seek(seconds: float) -> void:
	_contacts.seconds = seconds
	var lead: Vector3 = _contacts.placements.adela_voss.origin + Vector3.UP * .9
	for id: String in PERFORMERS:
		var state: Dictionary = _contacts.state_for(id)
		var look := _timing.look_to_lead(id, seconds)
		if look > 0.0:
			var home: Vector3 = state.gaze_target
			state.gaze_target = home.lerp(lead, look)
			state.gaze_weight = lerpf(float(state.gaze_weight), .55, look)
		_poses[id].seek(seconds, state)


func _on_end() -> void:
	_performing = false
	_transition = -1
	for pose: SkeletonModifier3D in _poses.values():
		pose.contact = Callable()
		pose.actor.face.stop_speaking()
		pose.actor.face.step(.25)


func _finish() -> void:
	_clear()
	finished.emit()


func _clear() -> void:
	_transition = 0
	_performing = false
	if is_instance_valid(_transport):
		if _transport.played_at.is_connected(_seek):
			_transport.played_at.disconnect(_seek)
		if _transport.ended.is_connected(_on_end):
			_transport.ended.disconnect(_on_end)
		_transport.stop()
	for pose: SkeletonModifier3D in _poses.values():
		if is_instance_valid(pose):
			pose.release()
			pose.queue_free()
	_poses.clear()
	_standing.clear()
	if _contacts != null:
		_contacts.release()
		_contacts = null
	if is_instance_valid(_transport):
		_transport.queue_free()
		_transport = null


func _exit_tree() -> void:
	_clear()
