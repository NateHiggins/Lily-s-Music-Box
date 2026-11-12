extends Node
## Private per-actor bindings over the reviewed shared hair shader.
## Attach under the presentation; bind only after its pose/skirt modifiers.
## Source catalogue and vertex/UV qualification remain the intake owner's job.
const Motion := preload("res://scripts/characters/head_hair_motion.gd")
const SHADER_PATH := "res://shaders/character_hair.gdshader"
const MESH_NAMES: Array[String] = ["Hair", "HairCap"]
## The same hair cut off at the band of a hat, shown in place of Hair under one. Optional; it wears the material of Hair.
const HAT_HAIR := "HatHair"
## A head made by art/blender/scripts/build_card_hair.py brings <person>_hair_look.json beside its model.
const LOOK_KEYS: Array[String] = ["cap_shade", "cap_feather", "cap_bald", "underside", "roundness", "gloss", "hair_centre"]

var ready_ok := false
var errors: Array[String] = []
var materials: Dictionary = {}
var source_materials: Dictionary = {}
var motion: Motion
var person_id := ""
var _meshes: Dictionary = {}
var _attempted := false
## The look the head brought; empty for a head that wears the shader as it stands.
var look: Dictionary = {}
var _body: Skeleton3D
var _head := -1
## The middle of the skull, in the rest space of the Head bone: the rounded shading is centred on it.
var _centre_in_head := Vector3.ZERO


func _refuse(message: String) -> bool:
	errors.append(message)
	unbind()
	return false


func bind(model: Node3D, person: String) -> bool:
	if _attempted:
		return _refuse("hair presentation can bind only once")
	_attempted = true
	person_id = person
	if not is_inside_tree() or model == null or not model.is_inside_tree() or person.is_empty():
		return _refuse("hair presentation and model must be attached with a person id before bind")
	if not ResourceLoader.exists(SHADER_PATH):
		return _refuse("reviewed shared hair shader missing: " + SHADER_PATH)
	var shader := load(SHADER_PATH) as Shader
	if shader == null or shader.get_mode() != Shader.MODE_SPATIAL:
		return _refuse("reviewed hair resource is not a spatial shader")
	var uniforms: Dictionary = {}
	for uniform: Dictionary in shader.get_shader_uniform_list():
		uniforms[str(uniform.get("name", ""))] = int(uniform.get("type", TYPE_NIL))
	for key: String in ["albedo_tex", "normal_tex", "rough_tex"]:
		if int(uniforms.get(key, TYPE_NIL)) != TYPE_OBJECT:
			return _refuse("shared hair shader lacks texture uniform: " + key)
	if int(uniforms.get("roughness_channel", TYPE_NIL)) != TYPE_VECTOR3:
		return _refuse("shared hair shader must expose roughness_channel vec3 for imported glTF G channel")
	if int(uniforms.get("is_cap", TYPE_NIL)) != TYPE_BOOL or int(uniforms.get("sway", TYPE_NIL)) != TYPE_VECTOR3 or int(uniforms.get("breeze", TYPE_NIL)) != TYPE_FLOAT:
		return _refuse("shared hair shader motion/cap uniform contract incomplete")
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() != 1:
		return _refuse("hair requires one shared skeleton")
	var body := skeletons[0] as Skeleton3D
	if body.find_bone("Head") < 0 or body.get_node_or_null("HeadHairMotion") != null:
		return _refuse("Head missing or hair motion reader already installed")
	_body = body
	_head = body.find_bone("Head")
	var look_path := model.scene_file_path.get_base_dir().path_join(person + "_hair_look.json") if not model.scene_file_path.is_empty() else ""
	if not look_path.is_empty() and FileAccess.file_exists(look_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(look_path))
		if parsed is not Dictionary:
			return _refuse("hair look file is unreadable: " + look_path)
		for key: String in LOOK_KEYS:
			if not (parsed as Dictionary).has(key):
				return _refuse("hair look file lacks " + key)
		if parsed.hair_centre is not Array or (parsed.hair_centre as Array).size() != 3:
			return _refuse("hair look centre must be three numbers")
		for key: String in ["cap_shade", "cap_feather", "cap_bald", "hair_centre", "roundness", "specular", "roughness_scale", "normal_depth", "anisotropy"]:
			if not uniforms.has(key):
				return _refuse("shared hair shader lacks look uniform: " + key)
		look = parsed
	# Validate both sources before replacing any material on either mesh.
	for mesh_name: String in MESH_NAMES:
		var found := model.find_children(mesh_name, "MeshInstance3D", true, false)
		if found.size() != 1:
			return _refuse("expected exactly one actual " + mesh_name + " mesh")
		var draw := found[0] as MeshInstance3D
		if draw.mesh == null or draw.mesh.get_surface_count() != 1 or draw.skin == null or draw.get_node_or_null(draw.skeleton) != body:
			return _refuse(mesh_name + " must carry one surface and skin on the shared skeleton")
		if draw.material_override != null or draw.material_overlay != null or draw.get_surface_override_material(0) != null:
			return _refuse(mesh_name + " already has a material override or overlay")
		var source := draw.mesh.surface_get_material(0) as BaseMaterial3D
		if source == null or source.next_pass != null:
			return _refuse(mesh_name + " requires imported PBR material without a next pass")
		if not source.albedo_color.is_equal_approx(Color.WHITE) or not is_equal_approx(source.roughness, 1.0):
			return _refuse(mesh_name + " requires imported albedo and roughness scalar factors of one")
		# Retain the imported normal texture and source factor (r25 uses 0.6).
		# The reviewed shared shader owns its intentional NORMAL_MAP_DEPTH 0.4;
		# this binder neither applies nor multiplies the imported normal factor.
		if source.get_flag(BaseMaterial3D.FLAG_UV1_USE_TRIPLANAR) or not source.uv1_scale.is_equal_approx(Vector3.ONE) or not source.uv1_offset.is_equal_approx(Vector3.ZERO):
			return _refuse(mesh_name + " requires unchanged UV0 texture coordinates")
		var albedo := source.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
		var normal := source.get_texture(BaseMaterial3D.TEXTURE_NORMAL)
		var rough: Texture2D
		if source is ORMMaterial3D:
			rough = source.get_texture(BaseMaterial3D.TEXTURE_ORM)
		else:
			rough = source.get_texture(BaseMaterial3D.TEXTURE_ROUGHNESS)
			if source.get_roughness_texture_channel() != BaseMaterial3D.TEXTURE_CHANNEL_GREEN:
				return _refuse(mesh_name + " imported glTF roughness must select packed green channel")
		if albedo == null or normal == null or rough == null:
			return _refuse(mesh_name + " lacks imported albedo, normal or packed roughness texture")
		var material := ShaderMaterial.new()
		material.shader = shader
		material.resource_name = person + "_" + mesh_name
		material.set_shader_parameter("albedo_tex", albedo)
		material.set_shader_parameter("normal_tex", normal)
		material.set_shader_parameter("rough_tex", rough)
		material.set_shader_parameter("roughness_channel", Vector3(0.0, 1.0, 0.0))
		material.set_shader_parameter("is_cap", mesh_name == "HairCap")
		material.set_shader_parameter("sway", Vector3.ZERO)
		# Leave breeze and every appearance constant at the reviewed shader default.
		materials[mesh_name] = material
		source_materials[mesh_name] = source
		_meshes[mesh_name] = draw
	# Hair cut for a hat: the same cards, so the same material. Checked as strictly as Hair before anything is set.
	var hat_found := model.find_children(HAT_HAIR, "MeshInstance3D", true, false)
	if hat_found.size() > 1:
		return _refuse("more than one " + HAT_HAIR + " mesh")
	if hat_found.size() == 1:
		var under := hat_found[0] as MeshInstance3D
		if under.mesh == null or under.mesh.get_surface_count() != 1 or under.skin == null or under.get_node_or_null(under.skeleton) != body:
			return _refuse(HAT_HAIR + " must carry one surface and skin on the shared skeleton")
		if under.material_override != null or under.material_overlay != null or under.get_surface_override_material(0) != null:
			return _refuse(HAT_HAIR + " already has a material override or overlay")
		if under.mesh.surface_get_material(0) != (_meshes["Hair"] as MeshInstance3D).mesh.surface_get_material(0):
			return _refuse(HAT_HAIR + " must share the imported material of Hair")
		_meshes[HAT_HAIR] = under
	if not look.is_empty():
		# The settings the head was reviewed under, set explicitly on both materials.
		var gloss := clampf(float(look.gloss), 0.0, 1.0)
		var centre := Vector3(float(look.hair_centre[0]), float(look.hair_centre[1]), float(look.hair_centre[2]))
		# The look gives the centre in model space at rest; kept in the space of the Head bone it follows a nod.
		_centre_in_head = body.get_bone_global_rest(_head).affine_inverse() * centre
		for mesh_name: String in MESH_NAMES:
			var look_material: ShaderMaterial = materials[mesh_name]
			for key: String in ["cap_shade", "cap_feather", "cap_bald", "underside", "roundness"]:
				look_material.set_shader_parameter(key, float(look[key]))
			look_material.set_shader_parameter("specular", lerpf(0.14, 0.22, gloss))
			look_material.set_shader_parameter("roughness_scale", lerpf(1.0, 0.92, gloss))
			look_material.set_shader_parameter("normal_depth", 0.3)
			look_material.set_shader_parameter("anisotropy", 0.0)
			look_material.set_shader_parameter("hair_centre", centre)
	for mesh_name: String in MESH_NAMES:
		(_meshes[mesh_name] as MeshInstance3D).set_surface_override_material(0, materials[mesh_name])
	if _meshes.has(HAT_HAIR):
		(_meshes[HAT_HAIR] as MeshInstance3D).set_surface_override_material(0, materials["Hair"])
	motion = Motion.new()
	motion.name = "HeadHairMotion"
	# Skeleton3D evaluates modifiers in child order. This observer goes last.
	body.add_child(motion)
	if not motion.bind(_meshes["Hair"], materials["Hair"]):
		return _refuse("hair motion reader refused: " + "; ".join(motion.errors))
	ready_ok = true
	set_process(not look.is_empty())
	return true


func _ready() -> void:
	set_process(false)


## The centre of the rounded shading rides the head: the shader works in the space of the mesh, after skinning.
func _process(_delta: float) -> void:
	if not ready_ok or look.is_empty() or not is_instance_valid(_body):
		return
	var cards := _meshes.get("Hair") as MeshInstance3D
	if cards == null or not cards.is_inside_tree():
		return
	var centre := cards.global_transform.affine_inverse() * (_body.global_transform * (_body.get_bone_global_pose(_head) * _centre_in_head))
	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("hair_centre", centre)


func set_presentation_active(enabled: bool) -> void:
	if motion != null and is_instance_valid(motion):
		motion.set_presentation_active(enabled and ready_ok)
	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("sway", Vector3.ZERO)
	set_process(enabled and ready_ok and not look.is_empty())


func unbind() -> void:
	ready_ok = false
	if motion != null and is_instance_valid(motion):
		motion.set_presentation_active(false)
		motion.queue_free()
	motion = null
	for mesh_name: String in _meshes:
		var draw := _meshes[mesh_name] as MeshInstance3D
		if is_instance_valid(draw) and draw.get_surface_override_material(0) == materials.get("Hair" if mesh_name == HAT_HAIR else mesh_name):
			draw.set_surface_override_material(0, null)
	set_process(false)
	look = {}
	_meshes.clear()
	materials.clear()
	source_materials.clear()


func _exit_tree() -> void:
	unbind()
