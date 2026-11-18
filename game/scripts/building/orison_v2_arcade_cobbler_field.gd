extends RefCounted
const RuntimeBundle := preload("res://scripts/building/orison_v2_arcade_runtime_bundle.gd")
## Fitted supporting field only. Original source fields stay on the donor;
## this declares a successor but never authorizes disposal or installs a region.
const DATA := "res://data/orison_v2/arcade_cobbler_field.json"
const Frame := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
const Finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd")
var errors: Array[String] = []

func _refuse(message: String, root: Node = null) -> Node3D:
	errors.append(message)
	if root != null: root.free()
	return null

func prepare(spec: Dictionary, donor: Node3D, carrier: Dictionary) -> Node3D:
	errors.clear()
	if spec.get("schema") != "orison.v2.arcade-cobbler-field.v1" or spec.get("cell") != "shop_shoe_rebuilding" \
		or carrier.get("cell") != spec.cell or spec.get("source_disposal_authorized", true) != false \
		or spec.get("source_parts") is not Array or spec.source_parts.size() != 2 \
		or donor == null or donor.is_inside_tree(): return _refuse("invalid detached field/source declaration")
	var asset := str(spec.get("asset", ""))
	if asset != "res://assets/props/arcade_cobbler_field.glb" or FileAccess.get_sha256(asset) != str(spec.get("asset_sha256", "")):
		return _refuse("field payload changed")
	var settings := ConfigFile.new()
	if settings.load(RuntimeBundle.source_path(asset + ".import")) != OK or not settings.get_value("params", "meshes/force_disable_compression", false):
		return _refuse("field requires authored imported position/UV precision")
	var required: Array[String] = ["res://data/building_layout.json", "res://data/orison_v2/cobbler_fittings.json",
		"res://data/orison_v2/owner_finish_profiles.json", "res://data/runtime_material_sets.json",
		"res://assets/props/cobbler_fittings.glb", asset + ".import"]
	var maps: Array[String] = []
	for channel in 3:
		var path := "res://assets/building/textures/" + str(MatLib.SETS.linen[channel])
		maps.append(path)
		required.append(path)
	if spec.get("source_bindings") is not Dictionary or spec.source_bindings.size() != required.size():
		return _refuse("field source binding inventory")
	for path: String in required:
		if not spec.source_bindings.has(path): return _refuse("field required source binding absent: " + path)
	for path: String in spec.source_bindings:
		var binding: Dictionary = spec.source_bindings[path]
		if not path.begins_with("res://") or binding.get("kind") not in ["raw", "lf"] or not FileAccess.file_exists(path):
			return _refuse("invalid field source binding")
		var actual := FileAccess.get_sha256(path) if binding.kind == "raw" else FileAccess.get_file_as_string(RuntimeBundle.source_path(path)).replace("\r\n", "\n").sha256_text()
		if actual != str(binding.get("sha256", "")): return _refuse("field source changed: " + path)
	var model := donor.get_node_or_null("CobblerFittings")
	if model == null: return _refuse("original cobbler material owner absent")
	var frame := Frame.new()
	var witnesses := {}
	var source_material: StandardMaterial3D
	for part: Dictionary in spec.source_parts:
		var identity := str(part.get("name", ""))
		if identity not in ["storm_shop_shoe_rebuilding_dust_felt__soot__north", "storm_shop_shoe_rebuilding_dust_felt__soot__south"] or witnesses.has(identity):
			return _refuse("missing/duplicate original field witness")
		var matches: Array = carrier.get("rebuild_entries", []).filter(func(row: Dictionary) -> bool: return row.model == "CobblerFittings" and row.part_id == identity)
		if matches.size() != 1: return _refuse("original field rebuild custody missing")
		var row: Dictionary = matches[0]
		var draws := model.find_children("*", "MeshInstance3D", true, false).filter(func(draw: MeshInstance3D) -> bool: return draw.get_meta("cobbler_part", "") == identity)
		if draws.size() != 1: return _refuse("original field draw missing/duplicate")
		var draw := draws[0] as MeshInstance3D
		if draw.mesh == null or draw.mesh.get_faces().size() != int(row.triangles) * 3 or not frame._same(frame._relative(draw, donor), frame._matrix(row.source_transform)):
			return _refuse("original field geometry/frame changed")
		var material := draw.get_active_material(0) as StandardMaterial3D
		if material == null or material.albedo_texture == null or material.normal_texture == null or material.roughness_texture == null \
			or material.uv1_triplanar or not material.uv1_scale.is_equal_approx(Vector3.ONE / .6) \
			or not material.albedo_color.is_equal_approx(Color(.55, .45, .34, 1)):
			return _refuse("original field material changed")
		if material.albedo_texture.resource_path != maps[0] or material.roughness_texture.resource_path != maps[1] or material.normal_texture.resource_path != maps[2]:
			return _refuse("original field registered linen maps changed")
		if source_material != null and (material.albedo_texture != source_material.albedo_texture or material.normal_texture != source_material.normal_texture or material.roughness_texture != source_material.roughness_texture):
			return _refuse("original field material witnesses disagree")
		source_material = material
		witnesses[identity] = true
	var packed := load(asset) as PackedScene
	if packed == null: return _refuse("field import absent")
	var imported := packed.instantiate() as Node3D
	var draws := imported.find_children("*", "MeshInstance3D", true, false)
	if draws.size() != 1: return _refuse("one native field draw required", imported)
	var draw := draws[0] as MeshInstance3D
	if str(draw.name) != "CobblerSupportingFelt" or draw.mesh == null or draw.mesh.get_surface_count() != 1 \
		or draw.mesh.get_faces().size() != 96 * 3 or not frame._same(frame._relative(draw, imported), Transform3D.IDENTITY):
		return _refuse("native field frame/count changed", imported)
	var root := Node3D.new()
	root.name = "CobblerSupportField"
	var placed := MeshInstance3D.new()
	placed.name = draw.name
	placed.mesh = draw.mesh
	placed.material_override = Finishes.new().material_for(source_material, "shop")
	(placed.material_override as ShaderMaterial).set_shader_parameter("uv_mode", 0)
	placed.set_meta("material_key", "linen")
	root.add_child(placed)
	var body := StaticBody3D.new()
	body.name = "ActualNativeSupportingField"
	var shape := CollisionShape3D.new()
	shape.shape = draw.mesh.create_trimesh_shape()
	body.add_child(shape)
	placed.add_child(body)
	root.set_meta("arcade_native_successors", witnesses.keys())
	root.set_meta("source_disposal_authorized", false)
	imported.free()
	return root
