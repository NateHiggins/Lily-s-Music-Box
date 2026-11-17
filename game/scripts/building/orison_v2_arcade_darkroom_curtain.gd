extends RefCounted
## Native opaque infill. Existing single leaf owns movement, lock and save.
const DATA := "res://data/orison_v2/arcade_darkroom_curtain.json"
const SOURCE := "res://data/orison_v2/photo_radio_fittings.json"
const Surface := preload("res://scripts/building/surface_pass.gd")
const Finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd")
var errors: Array[String] = []

func _refuse(message: String, node: Node = null) -> MeshInstance3D:
	errors.append(message)
	if node != null: node.free()
	return null

func prepare(spec: Dictionary) -> MeshInstance3D:
	errors.clear()
	if spec.get("schema") != "orison.v2.arcade-darkroom-curtain.v1": return _refuse("curtain declaration schema")
	var asset := str(spec.get("asset", ""))
	if asset != "res://assets/props/arcade_darkroom_curtain.glb" or FileAccess.get_sha256(asset) != str(spec.get("asset_sha256", "")):
		return _refuse("curtain native asset changed")
	var settings := ConfigFile.new()
	if settings.load(asset + ".import") != OK or settings.get_value("params", "meshes/force_disable_compression", false) != true \
		or FileAccess.get_file_as_string(asset + ".import").replace("\r\n", "\n").sha256_text() != str(spec.get("import_sha256_lf", "")):
		return _refuse("curtain authored import precision changed")
	var text := FileAccess.get_file_as_string(SOURCE).replace("\r\n", "\n")
	if text.sha256_text() != str(spec.get("source_sha256_lf", "")): return _refuse("curtain original material authority changed")
	var source: Dictionary = JSON.parse_string(text)
	var matches: Array[Dictionary] = []
	for cell: Dictionary in source.cells:
		if cell.id != "shop_photo_supplies": continue
		for row: Dictionary in cell.parts:
			if row.name == "storm_shop_photo_supplies_dr_door__fabric_warm": matches.append(row)
	if matches.size() != 1: return _refuse("original fabric witness absent/duplicate")
	var recipe: Dictionary = matches[0]
	if recipe.catalog_key != "fabric_warm" or recipe.key != "fabric_warm" or not is_equal_approx(float(recipe.tile), float(MatLib.SETS.fabric_warm[3])):
		return _refuse("original registered curtain finish changed")
	var packed := load(asset) as PackedScene
	if packed == null: return _refuse("curtain import unavailable")
	var imported := packed.instantiate() as Node3D
	var draws := imported.find_children("*", "MeshInstance3D", true, false)
	if draws.size() != 1: return _refuse("one native curtain draw required", imported)
	var draw := draws[0] as MeshInstance3D
	if draw.name != "LeftDarkroomCurtain" or draw.mesh == null or draw.mesh.get_surface_count() != 1 or draw.mesh.get_faces().size() != 1288 * 3 or not draw.transform.is_equal_approx(Transform3D.IDENTITY):
		return _refuse("curtain native frame/count changed", imported)
	var original := MatLib.get_mat("fabric_warm").duplicate() as StandardMaterial3D
	var tint: Array = recipe.tint
	original.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
	original.uv1_triplanar = false
	original.uv1_scale = Vector3.ONE / float(recipe.tile)
	var material := Finishes.new().material_for(original, "shop") as ShaderMaterial
	material.set_shader_parameter("uv_mode", 0)
	var result := MeshInstance3D.new()
	result.name = draw.name
	result.mesh = draw.mesh
	result.material_override = material
	result.set_meta("material_key", "fabric_warm")
	result.set_meta("arcade_darkroom_curtain", true)
	# All physical collision stays with the unchanged original moving wood core.
	imported.free()
	return result
