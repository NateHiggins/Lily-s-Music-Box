extends RefCounted
## Same catalogue ABI as the existing printer, extended for native accessories.
const DATA := "res://data/device/service_companion_v2.json"
const BASE := "res://data/device/service_radiophone_v2.json"

static func apply(model: Node3D) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE))
	assert(int(data.schema_version) == 1)
	assert(FileAccess.get_sha256(str(data.asset)) == str(data.asset_sha256), "companion native export drift")
	assert(FileAccess.get_file_as_string(BASE).replace("\r\n", "\n").sha256_text() == str(data.base_data_sha256), "companion printer source changed")
	assert(FileAccess.get_sha256(str(base.asset)) == str(base.asset_sha256), "original printer export changed")
	var specs: Dictionary = base.finishes.duplicate(true)
	var accessory_names: Array[String] = ["CompanionSteel", "CompanionBrass", "CompanionKeys", "CompanionTileIvory",
		"ShellSteel", "ShellLeather", "ShellBrass", "ShellRubber", "ShellGlass", "StudyVelvet", "KeyboardShellBrass", "RotorCanvas"]
	assert(data.finishes.size() == accessory_names.size(), "companion finish ABI")
	for key: String in accessory_names:
		assert(data.finishes.has(key), "missing companion finish")
		assert(not specs.has(key), "companion may not replace original finishes")
		specs[key] = data.finishes[key]
	var finishes: Dictionary = {}
	for key: String in specs:
		var spec: Dictionary = specs[key]
		var material := MatLib.get_mat(str(spec.catalog_key)).duplicate() as StandardMaterial3D
		assert(material.albedo_texture != null and material.roughness_texture != null and material.normal_texture != null)
		material.uv1_triplanar = false
		material.uv1_world_triplanar = false
		material.uv1_scale = Vector3.ONE / float(MatLib.SETS[str(spec.catalog_key)][3])
		material.normal_enabled = true
		material.normal_scale = float(spec.normal)
		material.roughness = float(spec.roughness)
		assert(float(spec.pigment) > 0.0 and float(spec.pigment) <= 1.0)
		var tint: Array = spec.tint
		material.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if key == "ShellGlass":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.refraction_enabled = true
			# The reading pane keeps the authored drawn-glass relief with a
			# restrained displacement so carbon lettering stays usable.
			material.refraction_scale = .004
		finishes[key] = material
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in draw.mesh.get_surface_count():
			var source: Material = draw.mesh.surface_get_material(surface)
			assert(source != null and finishes.has(source.resource_name), "unknown companion native finish")
			draw.set_surface_override_material(surface, finishes[source.resource_name])
	return base.paper
