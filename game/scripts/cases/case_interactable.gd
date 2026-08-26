class_name CaseInteractable
extends StaticBody3D
## Small physical interaction target used by case-specific gameplay.

var prompt_text := "Inspect"
var action := Callable()
var enabled := true
var response_kind := ""
var _label: Label3D
var _visual: MeshInstance3D
var _response_sound: AudioStreamPlayer3D
var _response_tween: Tween
var _visual_home := Vector3.ZERO
var _visual_rotation_home := Vector3.ZERO


func setup(title: String, prompt: String, callback: Callable,
		color := Color(0.28, 0.38, 0.34),
		size := Vector3(0.34, 0.16, 0.24),
		physical_response := "paper") -> void:
	name = title.replace(" ", "_")
	prompt_text = prompt
	action = callback
	response_kind = physical_response
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.64
	_visual = MeshInstance3D.new()
	_visual.name = "CaseOwnedObject"
	_visual.mesh = mesh
	_visual.material_override = material
	_visual.position.y = size.y * 0.5
	add_child(_visual)
	_visual_home = _visual.position
	_visual_rotation_home = _visual.rotation
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)
	if GameBoot.developer_overlays_enabled():
		_label = Label3D.new()
		_label.name = "DeveloperObjectLabel"
		_label.text = title
		_label.position.y = size.y + 0.15
		_label.font_size = 28
		_label.pixel_size = 0.002
		_label.outline_size = 8
		_label.outline_modulate = Color(0.01, 0.02, 0.02, 0.9)
		_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(_label)
	_response_sound = AudioStreamPlayer3D.new()
	_response_sound.bus = "Dialogue"
	_response_sound.name = "CaseOwnedHandling"
	_response_sound.stream = PropAudio.get_stream("tick")
	_response_sound.volume_db = -20.0
	_response_sound.unit_size = 1.1
	_response_sound.max_distance = 6.0
	add_child(_response_sound)


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	collision_layer = 1 if on else 0
	collision_mask = 1 if on else 0


func set_title(title: String) -> void:
	if _label:
		_label.text = title


func interact_prompt() -> String:
	return prompt_text if enabled else ""


func interact(_player: Node) -> Dictionary:
	if not enabled or not action.is_valid():
		return {}
	_acknowledge_hand()
	var result: Variant = action.call()
	return (result as Dictionary).duplicate(true) if result is Dictionary else {}


func _acknowledge_hand() -> void:
	if _visual == null or _response_sound == null:
		return
	if _response_tween and _response_tween.is_valid():
		_response_tween.kill()
	_visual.position = _visual_home
	_visual.rotation = _visual_rotation_home
	var offset := Vector3.ZERO
	var turn := Vector3.ZERO
	match response_kind:
		"cards":
			offset.y = 0.012
			turn.z = deg_to_rad(-2.0)
			_response_sound.pitch_scale = 1.12
		"book":
			turn.x = deg_to_rad(-4.0)
			_response_sound.pitch_scale = 0.86
		"pencil":
			offset.x = 0.032
			turn.y = deg_to_rad(11.0)
			_response_sound.pitch_scale = 1.28
		"calibrator":
			offset.y = -0.012
			_response_sound.pitch_scale = 0.94
		"time_clock":
			offset.z = 0.018
			_response_sound.pitch_scale = 0.78
		"letter":
			offset.y = 0.010
			turn.z = deg_to_rad(2.5)
			_response_sound.pitch_scale = 1.06
		_:
			return
	_response_sound.play()
	_response_tween = create_tween()
	_response_tween.tween_property(_visual, "position",
			_visual_home + offset, 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_response_tween.parallel().tween_property(_visual, "rotation",
			_visual_rotation_home + turn, 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_response_tween.tween_property(_visual, "position", _visual_home, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_response_tween.parallel().tween_property(_visual, "rotation",
			_visual_rotation_home, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
