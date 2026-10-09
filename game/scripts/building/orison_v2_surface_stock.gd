extends RefCounted
## One imported model serves every passive actor; no new gameplay owners.
const PATH := "res://data/orison_v2/surface_stock.json"
var data: Dictionary
var model: Node3D
var rows: Dictionary = {}
var clear_glass: ShaderMaterial

func prepare() -> bool:
	data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1 or data.get("assemblies") is not Array: return false
	if data.assemblies.size() != 206 or data.get("floor_y") != 0: return false
	if data.local_materials.size() != 1 or not data.local_materials.has("glassish"): return false
	var source_glass: Dictionary = data.local_materials.glassish
	if source_glass.files.size() != 3 or source_glass.files[0] != null or source_glass.color.size() != 4 or source_glass.alpha != true or float(source_glass.metallic) != 0.: return false
	var optics: Dictionary = data.optics
	if optics.role != "Glazing" or optics.room_class != "public" or optics.shader != "res://shaders/lamp_glass_surface.gdshader" or float(optics.surface_roughness) != .06: return false
	var factory := preload("res://scripts/building/orison_v2_architectural_materials.gd").new()
	clear_glass = factory.material_for(str(optics.role),str(optics.room_class)) as ShaderMaterial
	if clear_glass == null or clear_glass.shader.resource_path != str(optics.shader): return false
	clear_glass.set_shader_parameter("surface_roughness",float(optics.surface_roughness))
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: return false
	model = packed.instantiate()
	for row: Dictionary in data.assemblies:
		if rows.has(row.id): finish(); return false
		if not Vector3(row.position[0],row.position[1],row.position[2]).is_zero_approx() or not is_zero_approx(float(row.yaw)): finish(); return false
		for part: Dictionary in row.parts:
			if model.find_child(str(part.name),true,false) == null: finish(); return false
		rows[row.id] = row
	return true

func mount_on(prop: Node3D, identity: String) -> bool:
	if not rows.has(identity) or model == null: return false
	for part: Dictionary in rows[identity].parts:
		var draw := model.find_child(str(part.name),true,false) as MeshInstance3D
		draw.owner = null
		draw.get_parent().remove_child(draw)
		prop.add_child(draw)
		draw.mesh = draw.mesh.duplicate() as Mesh
		var material: StandardMaterial3D
		if part.has("catalog_key"):
			material = MatLib.get_mat(str(part.catalog_key)).duplicate() as StandardMaterial3D
		else:
			material = preload("res://scripts/building/orison_v2_reading_nook.gd")._source_material(data.local_materials[str(part.key)])
		if part.has("tint"):
			var tint: Array = part.tint
			material.albedo_color = Color(tint[0],tint[1],tint[2],tint[3])
		if part.has("finish"):
			material.normal_scale = float(part.finish.normal_scale)
			material.roughness = float(part.finish.roughness)
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE / float(part.tile)
		draw.mesh.surface_set_material(0,material)
		if part.key == "glassish": draw.material_override = clear_glass
		draw.set_meta("surface_stock_part",str(part.name))
		draw.set_meta("material_key",str(part.key))
	prop.set_meta("v2_native_surface_stock",identity)
	return true

func finish() -> void:
	if is_instance_valid(model): model.free()
	model = null
