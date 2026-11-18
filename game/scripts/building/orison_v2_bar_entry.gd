extends RefCounted
## Native entrance presentation. Door/access, hours and passage retain owners.
const DATA := "res://data/orison_v2/harukiya_entry.json"
const Retirement := preload("res://scripts/building/harukiya_entry_retirement.gd")
const ROOT_NAME := "HarukiyaEntry"

static func read_spec(data_path: String = DATA) -> Dictionary:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if decoded is not Dictionary or decoded.get("schema_version") != 1: return {}
	return decoded

static func prepare_model(spec: Dictionary, door: bool = false) -> Node3D:
	var part_field := "door_parts" if door else "native_parts"
	var asset_field := "door_asset" if door else "asset"
	if spec.get(part_field) is not Array or spec[part_field].is_empty() or spec.get("materials") is not Dictionary:
		return null
	var packed := load(str(spec.get(asset_field, ""))) as PackedScene
	if packed == null: return null
	var model := packed.instantiate() as Node3D
	if model == null: return null
	var expected := {}; var seen := {}; var finishes := {}
	for part: Dictionary in spec[part_field]:
		var identity := str(part.get("name", ""))
		if identity.is_empty() or expected.has(identity): model.free(); return null
		expected[identity] = part
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		if not expected.has(identity) or seen.has(identity) or draw.mesh == null:
			model.free(); return null
		var part: Dictionary = expected[identity]
		if draw.mesh.get_surface_count() != 1 or draw.mesh.get_faces().size() != int(part.triangles)*3:
			model.free(); return null
		var finish_id := str(part.matkey)
		var finish: Dictionary = spec.materials.get(finish_id, {})
		var key := str(finish.get("catalog_key", ""))
		if not MatLib.SETS.has(key) or finish.get("tint") is not Array or finish.tint.size() != 4:
			model.free(); return null
		if not finishes.has(finish_id):
			var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar = false
			material.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
			material.albedo_color = Color(finish.tint[0], finish.tint[1], finish.tint[2], finish.tint[3])
			material.normal_scale = float(finish.get("normal", material.normal_scale))
			material.roughness = float(finish.get("roughness", material.roughness))
			finishes[finish_id] = material
		draw.mesh = draw.mesh.duplicate() as ArrayMesh
		draw.mesh.surface_set_material(0, finishes[finish_id])
		draw.set_meta("material_key", key)
		draw.set_meta("harukiya_entry_part", identity)
		draw.set_meta("harukiya_entry_pigment", float(finish.get("pigment", 1.0)))
		# Select the existing mapped ageing recipes for this native architecture.
		# Identity metadata and collision geometry remain the exported originals.
		var surface_class := ""
		var finish_role := finish_id.trim_prefix("entry_")
		if finish_role in ["brick", "teal"]: surface_class = "_walls"
		elif finish_role == "step": surface_class = "_floors_"
		elif finish_role == "red": surface_class = "_finish_"
		draw.name = "F01_retail_bar_entry_" + identity + surface_class
		if not door: draw.create_trimesh_collision()
		seen[identity] = true
	if seen.size() != expected.size(): model.free(); return null
	return model

static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	if cell.has_node(ROOT_NAME): return false
	var model := prepare_model(read_spec())
	if model == null: return false
	# Prepare the replacement first; a failed retirement publishes nothing.
	var audit := Retirement.apply(cell, layout)
	if audit.is_empty(): model.free(); return false
	model.name = ROOT_NAME
	model.set_meta("retirement_audit", audit)
	cell.add_child(model)
	return true

static func calibrate(cell: Node3D) -> void:
	var model := cell.get_node_or_null(ROOT_NAME)
	if model == null: return
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in draw.mesh.get_surface_count():
			var material := draw.get_surface_override_material(surface) as ShaderMaterial
			if material != null:
				material.set_shader_parameter("pigment_variation", float(draw.get_meta("harukiya_entry_pigment", 1.0)))
