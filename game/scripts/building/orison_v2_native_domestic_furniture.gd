extends RefCounted
## Prepare each shared variant once; original furniture bodies own all copies.
const SEATING_PATH := "res://data/orison_v2/domestic_seating.json"
const TABLES_PATH := "res://data/orison_v2/domestic_tables.json"
var _instances: Dictionary = {}
var _variants: Dictionary = {}

func prepare() -> bool:
	var seats: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEATING_PATH))
	var tables: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLES_PATH))
	return _prepare_family(seats) and _prepare_family(tables)

func _prepare_family(data: Variant) -> bool:
	if data is not Dictionary or data.get("schema_version") != 1 or data.get("floor_y") != 0 or data.get("tint_space") != "linear" \
			or data.get("assemblies") is not Array or data.get("instances") is not Array: return false
	var glass: ShaderMaterial
	if data.has("local_materials"):
		if data.local_materials.keys() != ["glassish"]: return false
		var source: Dictionary = data.local_materials.glassish
		if source.files.size() != 3 or source.files[0] != null or source.color.size() != 4 \
				or not source.alpha or source.metallic != 0: return false
		var optics: Dictionary = data.optics
		var factory := preload("res://scripts/building/orison_v2_architectural_materials.gd").new()
		glass = factory.material_for(str(optics.role),str(optics.room_class)) as ShaderMaterial
		if glass == null or glass.shader.resource_path != str(optics.shader): return false
		glass.set_shader_parameter("surface_roughness",float(optics.surface_roughness))
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: return false
	var model := packed.instantiate()
	for row: Dictionary in data.assemblies:
		var variant := str(row.id)
		if _variants.has(variant) or not Vector3(row.position[0],row.position[1],row.position[2]).is_zero_approx() \
				or not is_zero_approx(float(row.yaw)): model.free(); return false
		var parts: Array = []
		for part: Dictionary in row.parts:
			var draw := model.find_child(str(part.name),true,false) as MeshInstance3D
			if draw == null: model.free(); return false
			var mesh := draw.mesh.duplicate() as Mesh
			var material: StandardMaterial3D
			if part.has("catalog_key"):
				material = MatLib.get_mat(str(part.catalog_key)).duplicate() as StandardMaterial3D
			else:
				material = preload("res://scripts/building/orison_v2_reading_nook.gd")._source_material(data.local_materials[str(part.key)])
			if material == null: model.free(); return false
			if part.has("tint"):
				var tint: Array = part.tint
				material.albedo_color = Color(tint[0],tint[1],tint[2],tint[3]).linear_to_srgb()
			if part.has("finish"):
				material.normal_scale = float(part.finish.normal_scale)
				material.roughness = float(part.finish.roughness)
			material.uv1_triplanar = false
			material.uv1_scale = Vector3.ONE / float(part.tile)
			mesh.surface_set_material(0,material)
			parts.append({"name":str(part.name),"key":str(part.key),"mesh":mesh,
				"pose":draw.transform,"shape":mesh.create_trimesh_shape(),
				"override":glass if str(part.key) == "glassish" else null})
		_variants[variant] = parts
	model.free()
	for row: Dictionary in data.instances:
		if _instances.has(str(row.id)) or not _variants.has(str(row.variant)): return false
		_instances[str(row.id)] = str(row.variant)
	return true

func mount_on(body: StaticBody3D, identity: String) -> bool:
	if not _instances.has(identity): return false
	var variant: String = _instances[identity]
	for part: Dictionary in _variants[variant]:
		var draw := MeshInstance3D.new()
		draw.name = part.name
		draw.mesh = part.mesh
		draw.transform = part.pose
		draw.material_override = part.override
		draw.set_meta("native_domestic_part",part.name)
		draw.set_meta("material_key",part.key)
		body.add_child(draw)
		var collision := CollisionShape3D.new()
		collision.shape = part.shape
		collision.transform = part.pose
		body.add_child(collision)
		# Mesh, material and immutable collision shape are shared by this variant.
		# Body, node identity and transforms remain private to each source actor.
	body.set_meta("v2_native_domestic_variant",variant)
	return true

func finish() -> void:
	_instances.clear()
	_variants.clear()
