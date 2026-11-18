extends Node3D
## Borrows the existing cast writers and stage instruments for one performance.
const Contacts := preload("res://scripts/characters/harukiya_show_contacts.gd")
const Pose := preload("res://scripts/characters/harukiya_show_pose.gd")
const Transport := preload("res://scripts/characters/harukiya_show_transport.gd")
const PERFORMERS := ["adela_voss", "lily", "stacy"]

signal finished

var _transport: Node3D
var _contacts: RefCounted
var _poses := {}
var _performing := false


func prepare(room: OrisonV2BarRegion, actors: Dictionary) -> bool:
	if _transport != null or room.destination == null:
		return false
	for id: String in PERFORMERS:
		var actor: Node3D = actors.get(id)
		if not is_instance_valid(actor) or not actor.ready_ok or not actor.is_visible_in_tree():
			return false
	_transport = Transport.new()
	add_child(_transport)
	if not _transport.prepare():
		_clear()
		return false
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


func start() -> bool:
	if _contacts == null or _performing:
		return false
	for id: String in PERFORMERS:
		var actor: Node3D = _poses[id].actor
		var target: Vector3 = _contacts.placements[id].origin
		var offset := actor.global_position - target
		if not actor.is_visible_in_tree() or Vector2(offset.x, offset.z).length() > .08:
			return false
	for id: String in PERFORMERS:
		var pose: SkeletonModifier3D = _poses[id]
		pose.actor.global_transform = _contacts.placements[id]
		pose.contact = _contacts.apply
		pose.acquire(_transport.score.voices.get(id, []))
	_contacts.bass.show()
	_performing = true
	_seek(0.0)
	if _transport.start():
		return true
	_on_end()
	return false


func stop() -> void:
	if _performing:
		_transport.stop()
	else:
		_clear()


func _seek(seconds: float) -> void:
	_contacts.seconds = seconds
	for id: String in PERFORMERS:
		_poses[id].seek(seconds, _contacts.state_for(id))


func _on_end() -> void:
	_performing = false
	_clear()
	finished.emit()


func _clear() -> void:
	for pose: SkeletonModifier3D in _poses.values():
		if is_instance_valid(pose):
			pose.release()
			pose.queue_free()
	_poses.clear()
	if _contacts != null:
		_contacts.release()
		_contacts = null
	if is_instance_valid(_transport):
		_transport.queue_free()
		_transport = null


func _exit_tree() -> void:
	_clear()
