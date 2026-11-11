extends Node
## Who a resident is attending to. This is the one owner of an actor's
## attention: it decides what is looked at and for how long, and tells the
## actor's pose pipeline, which carries it out within what the body can do.
##
## The rules are plain and authored. A resident in conversation holds the
## caller's eye and glances away now and then. A resident the caller comes
## near notices them, looks for a while, and goes back to their own business.
## How long each lasts comes from a per-resident seed, so two residents do not
## keep time with each other and the same resident is the same every run.

const Pipeline := preload("res://scripts/characters/pose_pipeline.gd")

## How near the caller must be to be noticed, and how far before they are let go.
const NOTICE_METRES := 3.2
const RELEASE_METRES := 4.2

var pipeline: Node
var conversing := false
## For a test or a staged scene: a point to attend to instead of the camera.
var staged_target: Variant = null
var _resident_id := ""
var _random := RandomNumberGenerator.new()
var _looking := false
var _until := 0.0
var _clock := 0.0
var _noticed := false


## Fit an attention owner and a pose pipeline to an actor's model. Returns the
## owner, or null when the model's skeleton has no rig profile.
static func install(actor: Node3D, model: Node, resident_id: String) -> Node:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var body := skeletons[0] as Skeleton3D
	var fitted: Node = Pipeline.new()
	fitted.name = "PosePipeline"
	body.add_child(fitted)
	if not fitted.bind(body):
		fitted.queue_free()
		return null
	var attention: Node = (load("res://scripts/characters/resident_attention.gd") as GDScript).new()
	attention.name = "Attention"
	attention.pipeline = fitted
	attention._resident_id = resident_id
	attention._random.seed = hash(resident_id)
	actor.add_child(attention)
	return attention


func _ready() -> void:
	var node := get_parent()
	while node != null and not ("conversations" in node):
		node = node.get_parent()
	if node == null or not (node.get("conversations") is Object):
		return
	var conversations: Object = node.get("conversations")
	if conversations.has_signal("conversation_started"):
		conversations.connect("conversation_started", _on_conversation_started)
		conversations.connect("conversation_ended", _on_conversation_ended)


func _on_conversation_started(resident_id: String, _entry_id: String) -> void:
	if resident_id == _resident_id:
		conversing = true
		_begin_look()


func _on_conversation_ended(resident_id: String) -> void:
	if resident_id == _resident_id:
		conversing = false
		_until = _clock + _random.randf_range(0.6, 1.4)


func _begin_look() -> void:
	_looking = true
	_until = _clock + (_random.randf_range(3.5, 7.0) if conversing else _random.randf_range(1.8, 4.0))


func _begin_look_away() -> void:
	_looking = false
	_until = _clock + (_random.randf_range(0.5, 1.2) if conversing else _random.randf_range(4.0, 9.0))


func _target() -> Variant:
	if staged_target is Vector3:
		return staged_target
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	return camera.global_position if camera != null else null


func _process(delta: float) -> void:
	if pipeline == null or not is_instance_valid(pipeline):
		return
	_clock += delta
	var actor := get_parent() as Node3D
	var target: Variant = _target()
	if actor == null or not actor.is_visible_in_tree() or target == null:
		pipeline.rest()
		return
	var apart: float = (target as Vector3).distance_to(actor.global_position + Vector3(0, 1.4, 0))
	var near := apart < (RELEASE_METRES if _noticed else NOTICE_METRES)
	if near and not _noticed:
		# Noticing takes a moment; it is not a switch.
		_looking = false
		_until = _clock + _random.randf_range(0.25, 0.7)
	_noticed = near
	if not (near or conversing):
		pipeline.rest()
		return
	if _clock >= _until:
		if _looking:
			_begin_look_away()
		else:
			_begin_look()
	if _looking:
		pipeline.attend(target)
	else:
		pipeline.rest()


func is_looking() -> bool:
	return _looking and pipeline != null and pipeline.attending()
