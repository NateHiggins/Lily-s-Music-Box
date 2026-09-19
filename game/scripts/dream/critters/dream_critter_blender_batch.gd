class_name DreamCritterBlenderBatch
extends RefCounted
## One replaceable visual compiler for the existing controller/material.
## Section identity survives nearest-first slot reordering. Membership and
## inspected LOD changes are the only reasons to rebuild the merged mesh.

const AssetsScript := preload("res://scripts/dream/critters/dream_critter_blender_assets.gd")
const CAPACITY := 12
const LEGACY_VERTICES := 4432
const LEGACY_INDICES := 21000
const TRIANGLE_BUDGET := 84000
const MEMBRANE_SHADER := "res://shaders/dream_critter_membrane.gdshader"

var assets: DreamCritterBlenderAssets
var error := ""
var rebuild_count := 0
var last_compile_usec := 0
var total_compile_usec := 0
var inspection_kind := -1
var slot_map := PackedFloat32Array()
var foot_base := PackedFloat32Array()
var cilia_base := PackedFloat32Array()
var sections: Array[Dictionary] = []
var membrane_instance: MeshInstance3D:
	get:
		return _membrane_instance
var membrane_material: ShaderMaterial:
	get:
		return _membrane_material

var _controller: WeakRef
var _material: ShaderMaterial
var _membrane_material: ShaderMaterial
var _membrane_instance: MeshInstance3D
var _membrane_mesh: ArrayMesh
var _uniform_names := PackedStringArray()
var _opaque_triangles := 0
var _membrane_triangles := 0
var _legacy_mesh: ArrayMesh
var _mesh: ArrayMesh
var _legacy: Dictionary = {}
var _pending: Array[Dictionary] = []
var _last_records: Array[Dictionary] = []
var _signature := ""
var _ready := false
var _invalid_slots := false


func setup(controller: DreamCritterController, legacy_mesh: ArrayMesh) -> bool:
	if _ready:
		return _controller.get_ref() == controller and _legacy_mesh == legacy_mesh
	if not is_instance_valid(controller) or controller.material == null \
			or not is_instance_valid(controller.mesh_instance) or legacy_mesh == null:
		error = "Missing controller visual owner"
		return false
	if not _read_legacy(legacy_mesh):
		return false
	assets = AssetsScript.acquire()
	if assets == null or not assets.ready:
		error = "Blender assets unavailable" if assets == null else assets.error
		assets = null
		return false
	_controller = weakref(controller)
	_material = controller.material
	_legacy_mesh = legacy_mesh
	var membrane_shader := load(MEMBRANE_SHADER) as Shader
	if membrane_shader == null:
		error = "Blender membrane shader is unavailable"
		return false
	_membrane_material = _material.duplicate(false) as ShaderMaterial
	_membrane_material.shader = membrane_shader
	for uniform: Dictionary in _material.shader.get_shader_uniform_list():
		_uniform_names.append(String(uniform.name))
	_membrane_instance = MeshInstance3D.new()
	_membrane_instance.name = "BlenderMembranes"
	_membrane_instance.material_override = _membrane_material
	_membrane_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_membrane_instance.layers = controller.mesh_instance.layers
	_membrane_instance.extra_cull_margin = controller.mesh_instance.extra_cull_margin
	_membrane_instance.visible = false
	# Identity child transform shares the packed world-space deformation frame
	# and inherits the controller's existing visual visibility owner.
	controller.mesh_instance.add_child(_membrane_instance)
	slot_map.resize(CAPACITY)
	foot_base.resize(CAPACITY)
	cilia_base.resize(CAPACITY)
	slot_map.fill(-1.0)
	foot_base.fill(-1.0)
	cilia_base.fill(-1.0)
	_material.set_shader_parameter("blender_pose_tex", assets.texture)
	_material.set_shader_parameter("blender_pose_width", assets.width)
	_material.set_shader_parameter("blender_pose_count", assets.pose_count)
	_material.set_shader_parameter("blender_slot_map", slot_map)
	_material.set_shader_parameter("blender_foot_base", foot_base)
	_material.set_shader_parameter("blender_cilia_base", cilia_base)
	# The controller may not have packed any live slots yet.
	_material.set_shader_parameter("blender_provider_enabled", false)
	_ready = true
	sync_uniforms()
	return true


func _read_legacy(mesh: ArrayMesh) -> bool:
	if mesh.get_surface_count() != 1:
		error = "Legacy fallback must have one surface"
		return false
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tags: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.size() != CAPACITY * LEGACY_VERTICES \
			or normals.size() != vertices.size() or uvs.size() != vertices.size() \
			or tags.size() != vertices.size() or indices.size() != CAPACITY * LEGACY_INDICES:
		error = "Legacy fallback topology differs from the declared twelve-slot template"
		return false
	for i in vertices.size():
		if int(roundf(tags[i].x)) != int(i / LEGACY_VERTICES):
			error = "Legacy fallback slot ownership is not contiguous"
			return false
	for i in indices.size():
		var owner := int(i / LEGACY_INDICES)
		if indices[i] < owner * LEGACY_VERTICES or indices[i] >= (owner + 1) * LEGACY_VERTICES:
			error = "Legacy fallback index escapes its owner slot"
			return false
	_legacy = {"positions": vertices.slice(0, LEGACY_VERTICES),
		"normals": normals.slice(0, LEGACY_VERTICES), "uvs": uvs.slice(0, LEGACY_VERTICES),
		"tags": tags.slice(0, LEGACY_VERTICES), "indices": indices.slice(0, LEGACY_INDICES),
		"triangles": LEGACY_INDICES / 3}
	return true


func begin_slots() -> void:
	_pending.clear()
	_invalid_slots = false


func record_slot(slot: int, id: int, twin: bool, kind: int) -> void:
	if not _ready:
		return
	if slot < 0 or slot >= CAPACITY or id < 0 or kind < 0 or kind > 15:
		_invalid_slots = true
		error = "Invalid draw-slot identity"
		return
	var key := "%d:%d" % [id, 1 if twin else 0]
	for record: Dictionary in _pending:
		if int(record.slot) == slot or String(record.key) == key:
			_invalid_slots = true
			error = "Duplicate draw-slot identity"
			return
	_pending.append({"slot": slot, "id": id, "twin": twin, "kind": kind, "key": key})


func finish_slots() -> void:
	if not _ready:
		return
	if _invalid_slots:
		_material.set_shader_parameter("blender_provider_enabled", false)
		_membrane_instance.visible = false
		var controller := _controller.get_ref() as DreamCritterController
		if is_instance_valid(controller) and is_instance_valid(controller.mesh_instance):
			controller.mesh_instance.mesh = _legacy_mesh
		_signature = ""
		return
	_last_records = _pending.duplicate(true)
	_update_mesh(_last_records)


func set_inspection_kind(kind: int) -> void:
	if kind == inspection_kind:
		return
	inspection_kind = kind
	if _ready:
		_update_mesh(_last_records)


func _update_mesh(records: Array[Dictionary]) -> void:
	var by_key: Dictionary = {}
	for record: Dictionary in records:
		by_key[String(record.key)] = record
	var ordered: Array[Dictionary] = []
	# Retain section order for every surviving stable identity.
	for old: Dictionary in sections:
		var key := String(old.key)
		if by_key.has(key):
			ordered.append((by_key[key] as Dictionary).duplicate())
			by_key.erase(key)
	for record: Dictionary in records:
		if by_key.has(String(record.key)):
			ordered.append(record.duplicate())
			by_key.erase(String(record.key))
	var triangles := 0
	for section: Dictionary in ordered:
		var kind := int(section.kind)
		section["lod"] = (0 if kind == inspection_kind else 1) if assets.templates.has(kind) else -1
		triangles += _triangle_count(section)
	# Inspection never silently increases the existing batch's worst case.
	for section: Dictionary in ordered:
		if triangles <= TRIANGLE_BUDGET:
			break
		if int(section.lod) == 0:
			triangles -= _triangle_count(section)
			section.lod = 1
			triangles += _triangle_count(section)
	if triangles > TRIANGLE_BUDGET:
		error = "Validated templates exceed the batch triangle budget"
		return
	var signature_parts := PackedStringArray()
	slot_map.fill(-1.0)
	foot_base.fill(-1.0)
	cilia_base.fill(-1.0)
	for i in ordered.size():
		var section: Dictionary = ordered[i]
		section["packed_slot"] = int(section.slot)
		section["atlas_base"] = -1
		section["foot_base"] = -1
		section["cilium_base"] = -1
		section["cilium_anchor_count"] = 0
		section["vertices"] = LEGACY_VERTICES
		section["triangles"] = _triangle_count(section)
		signature_parts.append("%s/%d/%d" % [section.key, section.kind, section.lod])
		slot_map[i] = float(section.slot)
		if int(section.lod) >= 0:
			var template: Dictionary = assets.templates[int(section.kind)][int(section.lod)]
			foot_base[i] = float(template.foot_base)
			cilia_base[i] = float(template.cilium_base)
			section.atlas_base = int(template.atlas_base)
			section.foot_base = int(template.foot_base)
			section.cilium_base = int(template.cilium_base)
			section.cilium_anchor_count = int(template.cilium_anchor_count)
			section.vertices = (template.positions as PackedVector3Array).size()
	var signature := "|".join(signature_parts)
	if signature != _signature:
		var began := Time.get_ticks_usec()
		if not ordered.is_empty():
			var candidate := _compile(ordered)
			var controller := _controller.get_ref() as DreamCritterController
			if candidate.is_empty():
				# Keep a valid visual if the engine rejects any compiled channel.
				_material.set_shader_parameter("blender_provider_enabled", false)
				_membrane_instance.visible = false
				if is_instance_valid(controller) and is_instance_valid(controller.mesh_instance):
					controller.mesh_instance.mesh = _legacy_mesh
				_signature = ""
				return
			_mesh = candidate.opaque
			_membrane_mesh = candidate.membrane
			_opaque_triangles = int(candidate.opaque_triangles)
			_membrane_triangles = int(candidate.membrane_triangles)
			_membrane_instance.mesh = _membrane_mesh
			if is_instance_valid(controller) and is_instance_valid(controller.mesh_instance):
				controller.mesh_instance.mesh = _mesh
		else:
			_mesh = null
			_membrane_mesh = null
			_membrane_instance.mesh = null
			_opaque_triangles = 0
			_membrane_triangles = 0
			var controller := _controller.get_ref() as DreamCritterController
			if is_instance_valid(controller) and is_instance_valid(controller.mesh_instance):
				controller.mesh_instance.mesh = _legacy_mesh
		_signature = signature
		rebuild_count += 1
		last_compile_usec = Time.get_ticks_usec() - began
		total_compile_usec += last_compile_usec
	sections = ordered
	_material.set_shader_parameter("blender_slot_map", slot_map)
	_material.set_shader_parameter("blender_foot_base", foot_base)
	_material.set_shader_parameter("blender_cilia_base", cilia_base)
	_material.set_shader_parameter("blender_provider_enabled", not ordered.is_empty())
	_membrane_instance.visible = _membrane_triangles > 0 and not ordered.is_empty()


func _triangle_count(section: Dictionary) -> int:
	if int(section.lod) < 0:
		return LEGACY_INDICES / 3
	return int(assets.templates[int(section.kind)][int(section.lod)].triangles)


func _compile(ordered: Array[Dictionary]) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tags := PackedVector2Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	var opaque_indices := PackedInt32Array()
	var membrane_indices := PackedInt32Array()
	for section_index in ordered.size():
		var section: Dictionary = ordered[section_index]
		var is_blender := int(section.lod) >= 0
		var template: Dictionary = assets.templates[int(section.kind)][int(section.lod)] if is_blender else _legacy
		var positions: PackedVector3Array = template.positions
		var offset := vertices.size()
		vertices.append_array(positions)
		normals.append_array(template.normals)
		uvs.append_array(template.uvs)
		for vertex in positions.size():
			if is_blender:
				var leg: Vector2 = template.leg_bind[vertex]
				tags.append(Vector2(section_index, 1000.0))
				colors.append(template.colors[vertex])
				custom.append(float(int(template.atlas_base) + vertex))
				custom.append(leg.x)
				custom.append(leg.y)
				custom.append(0.0)
			else:
				tags.append(Vector2(section_index, template.tags[vertex].y))
				colors.append(Color.WHITE)
				for _component in 4:
					custom.append(0.0)
		var source_indices: PackedInt32Array = template.indices
		for triangle in range(0, source_indices.size(), 3):
			var is_membrane := false
			if is_blender:
				for corner in 3:
					var vertex_color: Color = template.colors[source_indices[triangle + corner]]
					if vertex_color.g > 0.005:
						is_membrane = true
			for corner in 3:
				var index := source_indices[triangle + corner] + offset
				if is_membrane:
					membrane_indices.append(index)
				else:
					opaque_indices.append(index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = tags
	arrays[Mesh.ARRAY_COLOR] = colors
	# Float custom formats require PackedFloat32Array; packed bytes are for
	# byte/half custom formats and are rejected for ARRAY_CUSTOM_RGBA_FLOAT.
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	var opaque: ArrayMesh = null
	var membrane: ArrayMesh = null
	if not opaque_indices.is_empty():
		opaque = _make_surface(arrays, opaque_indices, "opaque")
		if opaque == null:
			return {}
	if not membrane_indices.is_empty():
		membrane = _make_surface(arrays, membrane_indices, "membrane")
		if membrane == null:
			return {}
	if opaque == null and membrane == null:
		error = "Compiled Blender batch contains no triangle indices"
		return {}
	return {"opaque": opaque, "membrane": membrane,
		"opaque_triangles": opaque_indices.size() / 3,
		"membrane_triangles": membrane_indices.size() / 3}


func _make_surface(channels: Array, indices: PackedInt32Array, label: String) -> ArrayMesh:
	var arrays: Array = channels.duplicate()
	arrays[Mesh.ARRAY_INDEX] = indices
	var compiled := ArrayMesh.new()
	compiled.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	if compiled.get_surface_count() != 1:
		error = "Engine rejected the compiled Blender " + label + " surface"
		return null
	if compiled.surface_get_array_len(0) != (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() \
			or compiled.surface_get_array_index_len(0) != indices.size():
		error = "Compiled Blender batch lost vertices or indices"
		return null
	compiled.custom_aabb = _legacy_mesh.custom_aabb
	return compiled


func sync_uniforms() -> void:
	if not _ready or _membrane_material == null:
		return
	for uniform: String in _uniform_names:
		_membrane_material.set_shader_parameter(uniform, _material.get_shader_parameter(uniform))
	var controller := _controller.get_ref() as DreamCritterController
	if is_instance_valid(controller) and is_instance_valid(controller.mesh_instance):
		_membrane_instance.layers = controller.mesh_instance.layers
		_membrane_instance.extra_cull_margin = controller.mesh_instance.extra_cull_margin
	_membrane_instance.visible = _membrane_triangles > 0 \
		and bool(_material.get_shader_parameter("blender_provider_enabled"))


func stats() -> Dictionary:
	var triangles := 0
	var blender_sections := 0
	var section_map: Dictionary = {}
	for section: Dictionary in sections:
		triangles += _triangle_count(section)
		blender_sections += 1 if int(section.lod) >= 0 else 0
	for i in sections.size():
		section_map[String(sections[i].key)] = i
	return {"ready": _ready, "error": error, "rebuild_count": rebuild_count,
		"last_compile_usec": last_compile_usec, "total_compile_usec": total_compile_usec,
		"sections": sections.duplicate(true), "section_map": section_map, "slot_map": slot_map.duplicate(),
		"foot_base": foot_base.duplicate(), "cilia_base": cilia_base.duplicate(),
		"blender_sections": blender_sections,
		"legacy_sections": sections.size() - blender_sections, "triangles": triangles,
		"total_triangles": _opaque_triangles + _membrane_triangles,
		"opaque_triangles": _opaque_triangles, "membrane_triangles": _membrane_triangles,
		"fixed_meshes": (1 if _mesh != null else 0) + (1 if _membrane_mesh != null else 0),
		"membrane_draws": 1 if is_instance_valid(_membrane_instance) \
			and _membrane_instance.is_visible_in_tree() and _membrane_triangles > 0 else 0,
		"membrane_material_id": _membrane_material.get_instance_id() if _membrane_material != null else 0,
		"membrane_mesh_id": _membrane_mesh.get_instance_id() if _membrane_mesh != null else 0,
		"membrane_instance_id": _membrane_instance.get_instance_id() if is_instance_valid(_membrane_instance) else 0,
		"mesh_id": _mesh.get_instance_id() if _mesh != null else 0,
		"material_id": _material.get_instance_id() if _material != null else 0,
		"atlas_instance_id": assets.texture.get_instance_id() if assets != null and assets.texture != null else 0,
		"atlas_dimensions": {"width": assets.width, "height": assets.atlas_height} if assets != null else {},
		"texture_id": assets.texture.get_instance_id() if assets != null and assets.texture != null else 0,
		"assets": assets.stats() if assets != null else {}}


func dispose() -> void:
	if _controller != null:
		var controller := _controller.get_ref() as DreamCritterController
		if is_instance_valid(controller) and is_instance_valid(controller.mesh_instance) \
				and controller.mesh_instance.mesh == _mesh:
			controller.mesh_instance.mesh = _legacy_mesh
	if _material != null:
		_material.set_shader_parameter("blender_provider_enabled", false)
		_material.set_shader_parameter("blender_pose_tex", null)
		slot_map.fill(-1.0)
		foot_base.fill(-1.0)
		cilia_base.fill(-1.0)
		_material.set_shader_parameter("blender_slot_map", slot_map)
		_material.set_shader_parameter("blender_foot_base", foot_base)
		_material.set_shader_parameter("blender_cilia_base", cilia_base)
	if _membrane_material != null:
		for uniform: String in _uniform_names:
			# The retained diagnostic material must not keep any atlas, shared
			# optical volume, or field texture alive after its visual owner exits.
			if _membrane_material.get_shader_parameter(uniform) is Resource:
				_membrane_material.set_shader_parameter(uniform, null)
		_membrane_material.set_shader_parameter("blender_provider_enabled", false)
		_membrane_material.set_shader_parameter("voxel_optics_enabled", 0.0)
		_membrane_material.set_shader_parameter("blender_pose_tex", null)
		_membrane_material.set_shader_parameter("exposure_tex", null)
		_membrane_material.set_shader_parameter("blender_slot_map", slot_map)
		_membrane_material.set_shader_parameter("blender_foot_base", foot_base)
		_membrane_material.set_shader_parameter("blender_cilia_base", cilia_base)
	if is_instance_valid(_membrane_instance):
		_membrane_instance.visible = false
		_membrane_instance.mesh = null
		_membrane_instance.material_override = null
		_membrane_instance.queue_free()
	_ready = false
	_controller = null
	_material = null
	_membrane_material = null
	_membrane_instance = null
	_membrane_mesh = null
	_uniform_names.clear()
	_opaque_triangles = 0
	_membrane_triangles = 0
	_legacy_mesh = null
	_mesh = null
	assets = null
	_legacy.clear()
	_pending.clear()
	_last_records.clear()
	sections.clear()
	_signature = ""
