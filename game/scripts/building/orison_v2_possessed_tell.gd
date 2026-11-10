extends Node
## One reversible tell on a household object V2 already has (Lily,
## v1r_witness_tells_20261109). V1 built a stand-in object for each tell;
## here the object the player already knows is the one that misbehaves.
##
## The rule is V1's (possessed_domestic_prop.gd): the tell belongs to its own
## cases unless it relays for the whole building; it never moves while it is
## watched, short of the worst tier, and then only ticks; it holds for a few
## seconds and puts everything back exactly.

signal told(prop_id: String, case_id: String, tier: int)

var prop_id := ""
var kind := ""
var unit := ""
var tell := ""
var case_ids: Array = []
var relay_all := false
## What the tell does: {"turn_y": radians}, {"knob_z": radians},
## {"flip": true}, {"seize": true}; "per_tier" scales the angles.
var motion: Dictionary = {}
var target: Node3D
var busy := false

var _home := Transform3D.IDENTITY
var _knob: Node3D
var _knob_home := Vector3.ZERO
var _tween: Tween
var _sound: AudioStreamPlayer3D
var _tier := 0


func configure(spec: Dictionary, object: Node3D) -> void:
	prop_id = str(spec.id)
	kind = str(spec.get("kind", ""))
	unit = str(spec.get("unit", ""))
	tell = str(spec.get("tell", ""))
	case_ids = (spec.get("cases", []) as Array).duplicate()
	relay_all = bool(spec.get("relay_all", false))
	motion = (spec.get("motion", {}) as Dictionary).duplicate(true)
	target = object
	name = "PossessedTell_" + prop_id


func _ready() -> void:
	add_to_group("possessed_domestic_props")
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = PropAudio.get_stream("tick")
	_sound.volume_db = -34.0
	_sound.unit_size = 4.0
	_sound.max_distance = 4.5
	_sound.bus = "Interaction"
	_sound.set_meta("audio_route", "legacy_helper")
	_sound.set_meta("audio_stream_key", "tick")
	add_child(_sound)
	if is_instance_valid(target):
		_sound.global_position = target.global_position


func stage_haunt(case_id: String, tier: int, player: Node3D) -> bool:
	if (not relay_all and not case_ids.has(case_id)) or busy or not is_instance_valid(target):
		return false
	if _watched(player) and tier < 4:
		_sound.pitch_scale = 0.72
		_sound.play()
		return true
	busy = true
	_tier = tier
	if _tween:
		_tween.kill()
	_apply(tier)
	_tween = create_tween()
	_tween.tween_interval(8.0 + tier * 2.0)
	_tween.tween_callback(restore)
	told.emit(prop_id, case_id, tier)
	return true


func _apply(tier: int) -> void:
	var scale := float(tier) if bool(motion.get("per_tier", false)) else 1.0
	if motion.has("turn_y"):
		_home = target.transform
		target.rotate_object_local(Vector3.UP, float(motion.turn_y) * scale)
	if bool(motion.get("flip", false)):
		# A picture turned on its own face: it hangs where it hung, upside down.
		_home = target.transform
		var box := AABB()
		var first := true
		for draw: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
			var local := target.global_transform.affine_inverse() * draw.global_transform * draw.get_aabb()
			box = local if first else box.merge(local)
			first = false
		var axis := Vector3.RIGHT
		if box.size.y <= box.size.x and box.size.y <= box.size.z:
			axis = Vector3.UP
		elif box.size.z <= box.size.x and box.size.z <= box.size.y:
			axis = Vector3.BACK
		var centre := box.get_center()
		target.transform = target.transform * Transform3D(Basis(), centre) * Transform3D(Basis(axis, PI), Vector3.ZERO) * Transform3D(Basis(), -centre)
	if motion.has("knob_z"):
		_knob = target.get("_tuning_knob") as Node3D
		if is_instance_valid(_knob):
			_knob_home = _knob.rotation
			_knob.rotation.z += float(motion.knob_z) * scale
	if bool(motion.get("seize", false)) and target.has_method("set_possessed"):
		target.set_possessed(true)


## Everything back as it was. Also called when the tell is torn down.
func restore() -> void:
	if not busy:
		return
	busy = false
	if not is_instance_valid(target):
		return
	if motion.has("turn_y") or bool(motion.get("flip", false)):
		target.transform = _home
	if motion.has("knob_z") and is_instance_valid(_knob):
		_knob.rotation = _knob_home
	if bool(motion.get("seize", false)) and target.has_method("set_possessed"):
		target.set_possessed(false)


func _watched(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var candidate: Variant = player.get("camera")
	if not (candidate is Camera3D):
		return false
	var camera: Camera3D = candidate
	var at := target.global_position
	if not camera.is_position_in_frustum(at):
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, at)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(at) < 0.6


func _exit_tree() -> void:
	if _tween:
		_tween.kill()
	restore()
	if _sound != null and _sound.stream != null:
		var stream := _sound.stream
		_sound.stop()
		_sound.stream = null
		PropAudio.release_stream("tick", stream)
