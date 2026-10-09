extends RefCounted
## Visual replacements only. Original street/floor collision and guide owners remain.
static func mount(world: OrisonV2RuntimeRoot) -> Node3D:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/street_paving_details.json"))
	if int(data.schema_version) != 1: return null
	var source := FileAccess.get_file_as_string(OrisonV2ExteriorCell.GEOMETRY_PATH).replace("\r\n", "\n").sha256_text()
	if source != str(data.source_geometry_sha256): return null
	var street: Node3D = world.exterior_cell.instance_node("STREET_ORISON_01")
	var originals := {}
	for part: Dictionary in data.parts:
		var draw := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(street, str(part.id))
		if draw == null: return null
		originals[str(part.id)] = draw
	if not data.finishes.has_all(["joint", "coping", "panel", "damp"]): return null
	var materials := {}
	for key: String in data.finishes:
		var finish: Dictionary = data.finishes[key]
		if float(finish.pigment) != 1.0: return null
		var tint: Array = finish.tint
		var mat := MatLib.get_mat(str(finish.catalog_key)).duplicate() as StandardMaterial3D
		mat.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		mat.uv1_triplanar = false
		mat.normal_scale = float(finish.normal)
		mat.roughness = float(finish.roughness)
		if key == "damp":
			mat.albedo_color.a = .72
			mat.vertex_color_use_as_albedo = true
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		materials[key] = mat
	var model := (preload("res://assets/props/street_paving_details.glb") as PackedScene).instantiate() as Node3D
	model.name = "StreetPavingDetails"
	street.add_child(model)
	for part: Dictionary in data.parts:
		var draw := model.get_node(str(part.id)) as MeshInstance3D
		if draw == null:
			model.free()
			return null
		draw.material_override = materials[str(part.kind)]
		draw.set_meta("source_record", str(part.id))
		if str(part.kind) in ["damp", "joint"]: draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for original: MeshInstance3D in originals.values(): original.hide()
	model.set_meta("original_draws", originals)
	return model
