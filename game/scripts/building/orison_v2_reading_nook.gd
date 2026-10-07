extends RefCounted
## Original basement nook, fitted to the existing north landing.
const PATH := "res://data/orison_v2/reading_nook.json"
const SOURCE_FINISHES := ["fabric_green", "glassish", "rug_warm"]

static func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1 or data.get("assemblies") is not Array: return false
	if data.get("local_materials") is not Dictionary or data.local_materials.size() != SOURCE_FINISHES.size(): return false
	for key: String in SOURCE_FINISHES:
		if not data.local_materials.has(key): return false
	var root := Node3D.new()
	root.name = "V2ReadingNook"
	root.position.y = float(data.floor_y)
	adapter.root.add_child(root)
	var packed := load(str(data.asset)) as PackedScene
	var model := packed.instantiate() as Node3D
	for row: Dictionary in data.assemblies:
		if adapter.resolve(str(row.id)) != null: model.free(); root.free(); return false
		var body := StaticBody3D.new()
		body.name = str(row.id)
		body.position = Vector3(row.position[0], row.position[1], row.position[2])
		body.rotation.y = float(row.yaw)
		body.set_meta("v2_nook_source", str(row.id))
		root.add_child(body)
		for part: Dictionary in row.parts:
			var draw := model.find_child(str(part.name), true, false) as MeshInstance3D
			if draw == null: model.free(); root.free(); return false
			var pose := body.transform.affine_inverse() * draw.transform
			draw.owner = null
			draw.get_parent().remove_child(draw)
			body.add_child(draw)
			draw.transform = pose
			draw.mesh = draw.mesh.duplicate() as Mesh
			var material: StandardMaterial3D
			if part.has("catalog_key"):
				material = MatLib.get_mat(str(part.catalog_key)).duplicate() as StandardMaterial3D
			else:
				material = _source_material(data.local_materials[str(part.key)])
			material.uv1_triplanar = false
			material.uv1_scale = Vector3.ONE / float(part.tile)
			if part.has("tint"):
				var tint: Array = part.tint
				material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
			draw.mesh.surface_set_material(0, material)
			draw.set_meta("reading_nook_part", str(part.name))
			draw.set_meta("material_key", str(part.key))
			var collision := CollisionShape3D.new()
			collision.shape = draw.mesh.create_trimesh_shape()
			collision.transform = draw.transform
			body.add_child(collision)
	model.free()
	return true

static func _source_material(spec: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var tint: Array = spec.color
	material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
	material.metallic = float(spec.metallic)
	material.roughness = float(spec.roughness)
	material.normal_enabled = true
	material.normal_scale = float(spec.normal_scale)
	if spec.files[0] != null: material.albedo_texture = load("res://assets/building/textures/" + str(spec.files[0]))
	material.roughness_texture = load("res://assets/building/textures/" + str(spec.files[1]))
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.normal_texture = load("res://assets/building/textures/" + str(spec.files[2]))
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if bool(spec.alpha):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
