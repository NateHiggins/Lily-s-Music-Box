extends RefCounted
## Native machine visuals; existing projector owns all latches and decoding.
const PATH := "res://data/orison_v2/active_household_projector.json"
var parts: Array = []
var errors: Array[String] = []

func prepare() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data.get("schema_version") != 1: return false
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: errors.append("native projector missing"); return false
	var model := packed.instantiate()
	var materials: Dictionary = {}
	for row: Dictionary in data.parts:
		var draw := model.find_child(str(row.name), true, false) as MeshInstance3D
		var key := str(row.material)
		if draw == null or not MatLib.SETS.has(key): errors.append("projector stock/finish absent"); continue
		if not materials.has(key):
			var mat := MatLib.get_mat(key).duplicate() as StandardMaterial3D
			mat.uv1_triplanar = false; mat.normal_scale = .08
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			materials[key] = mat
		parts.append({"name":str(row.name),"component":str(row.component),"mesh":draw.mesh,"pose":draw.transform,"material":materials[key]})
	model.free()
	return errors.is_empty()

func mount_on(prop: ProjectorProp) -> bool:
	if parts.size() != 13 or not prop._spin.is_empty(): return false
	for part: Dictionary in parts:
		if part.component == "Lens":
			prop.glass.mesh = part.mesh
			prop.glass.rotation = Vector3.ZERO
			prop.glass.set_meta("native_projector_lens", true)
			continue
		var draw := MeshInstance3D.new(); draw.name = part.name
		draw.mesh = part.mesh; draw.material_override = part.material
		prop.add_child(draw); draw.transform = part.pose
		if part.component == "Reel": prop._spin.append(draw)
		draw.set_meta("native_active_projector_part", part.name)
	prop.set_meta("v2_native_active_projector", true)
	return prop._spin.size() == 8
