extends Node3D
## Observation-only bridge for Dream's existing material owners. The accepted
## electrical/presentation owner and DreamExposureField are never advanced here.
const Field = preload("res://scripts/lamp/lamp_optical_voxel_field.gd")
const Observation = preload("res://scripts/lamp/carried_lamp_observation.gd")
var field: RefCounted
var observation: Node3D
var scene_shadow: Node3D
var player: PlayerController
var requested: Array[ShaderMaterial] = []
var bound: Array[ShaderMaterial] = []
var failed_reported := false

func setup(owner_player: PlayerController) -> void:
	player = owner_player
	field = Field.new()
	field.initialize(1)
	observation = Observation.new()
	add_child(observation)
	scene_shadow = preload("res://scripts/lamp/lamp_scene_shadow.gd").new()
	add_child(scene_shadow)
	scene_shadow.setup(field,player.flashlight)
	process_priority = 100

func set_materials(materials: Array[ShaderMaterial]) -> void:
	requested.clear()
	for material in materials:
		if material == null or material.shader == null: continue
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			if uniform.name == "lamp_optical_bound":
				if not requested.has(material): requested.append(material)
				break
	for material in bound.duplicate():
		if not requested.has(material):
			field.unbind_material(material)
			bound.erase(material)
	_bind_ready()

func _bind_ready() -> void:
	if field == null: return
	for material in requested:
		if not bound.has(material):
			field.bind_material(material)
			bound.append(material)
			if not field.failed.is_empty(): material.set_shader_parameter("lamp_volume_shape",Vector4.ZERO)

func _process(delta: float) -> void:
	if field == null or not is_instance_valid(player): return
	if not field.failed.is_empty():
		# Keep the binding semantic (do not fall back to ecological afterglow).
		for material in bound:
			material.set_shader_parameter("lamp_volume_shape",Vector4.ZERO)
		if not failed_reported:
			failed_reported = true
			push_error("Dream optical field: "+field.failed)
		return
	_bind_ready()
	if field.ready:
		observation.observe_player(player,delta)
		field.observe(observation,observation.state.switched_on)

func _exit_tree() -> void:
	if field != null: field.dispose()
	bound.clear()
	requested.clear()
	field = null
	player = null
