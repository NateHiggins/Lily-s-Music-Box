extends RefCounted
## Original basement nook, fitted to the existing north landing.
const PATH := "res://data/orison_v2/reading_nook.json"
const Stock := preload("res://scripts/building/v2_readable_library_stock.gd")
const COPIES := Stock.PHYSICAL_COPIES
const LooseLibrary := preload("res://scripts/building/v2_loose_library.gd")
const SOURCE_FINISHES := ["fabric_green", "glassish"]

static func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1 or data.get("assemblies") is not Array: return false
	if data.get("local_materials") is not Dictionary or data.local_materials.size() != SOURCE_FINISHES.size(): return false
	for key: String in SOURCE_FINISHES:
		if not data.local_materials.has(key): return false
	var stock:=Stock.new()
	if not stock.prepare(): return false
	var copies: Dictionary=stock.load_copy_programme()
	if copies.is_empty(): return false
	var assemblies: Dictionary={}
	for row: Dictionary in data.assemblies:
		if assemblies.has(str(row.id)): return false
		assemblies[str(row.id)]=true
	for record: Dictionary in copies.copies+copies.ends:
		if not assemblies.has(str(record.get("assembly",""))): return false
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
				# Native MixRGB tints are linear; StandardMaterial stores sRGB.
				material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3]).linear_to_srgb()
			draw.mesh.surface_set_material(0, material)
			draw.set_meta("reading_nook_part", str(part.name))
			draw.set_meta("material_key", str(part.key))
			var collision := CollisionShape3D.new()
			collision.shape = draw.mesh.create_trimesh_shape()
			collision.transform = draw.transform
			body.add_child(collision)
		var owned: Array=[]
		for copy: Dictionary in copies.copies:
			if str(copy.assembly)==str(row.id): owned.append(copy)
		var owned_ends: Array=[]
		for record: Dictionary in copies.ends:
			if str(record.assembly)==str(row.id): owned_ends.append(record)
		if not owned.is_empty():
			var collection:=LooseLibrary.new();collection.name=str(row.id)+"_library"
			collection.native_stock=stock;collection.copy_records=owned;collection.end_records=owned_ends
			body.add_child(collection)
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
		material.refraction_enabled = true
		material.refraction_scale = .035
	return material
