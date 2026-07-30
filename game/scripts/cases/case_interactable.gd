class_name CaseInteractable
extends StaticBody3D
## Small physical interaction target used by case-specific gameplay.

var prompt_text := "Inspect"
var action := Callable()
var enabled := true
var _label: Label3D


func setup(title: String, prompt: String, callback: Callable,
		color := Color(0.28, 0.38, 0.34),
		size := Vector3(0.34, 0.16, 0.24)) -> void:
	name = title.replace(" ", "_")
	prompt_text = prompt
	action = callback
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.64
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position.y = size.y * 0.5
	add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)
	_label = Label3D.new()
	_label.text = title
	_label.position.y = size.y + 0.15
	_label.font_size = 28
	_label.pixel_size = 0.002
	_label.outline_size = 8
	_label.outline_modulate = Color(0.01, 0.02, 0.02, 0.9)
	_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(_label)


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


func interact(_player: Node) -> void:
	if enabled and action.is_valid():
		action.call()
