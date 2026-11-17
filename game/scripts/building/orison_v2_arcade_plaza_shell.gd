extends RefCounted
## Prepared native shell only; installation retains the region's actor/service
## owners. Never publish this unfinished shell by discarding unaccounted donors.
const DATA := "res://data/orison_v2/arcade_plaza_shells.json"
const Surface := preload("res://scripts/building/surface_pass.gd")
const Frame := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
var errors: Array[String] = []

func _refuse(message: String, root: Node = null) -> Node3D:
	errors.append(message)
	if root != null: root.free()
	return null

func prepare(spec: Dictionary) -> Node3D:
	errors.clear()
	if spec.get("schema") != "orison.v2.arcade-plaza-shells.v1" or spec.get("native_parts") is not Array \
		or spec.get("materials") is not Array or spec.get("cells") is not Array:
		return _refuse("invalid shell declaration")
	var asset := str(spec.get("asset", ""))
	if not asset.begins_with("res://") or not FileAccess.file_exists(asset) \
		or FileAccess.get_sha256(asset) != str(spec.get("asset_sha256", "")):
		return _refuse("shell asset binding changed")
	# The original compressed import failed the unchanged 50-micron metric-UV
	# check. Keep this asset's authored position-precision exception on reload.
	var imported_settings := ConfigFile.new()
	if imported_settings.load(asset + ".import") != OK \
		or imported_settings.get_value("params", "meshes/force_disable_compression", false) != true:
		return _refuse("shell requires uncompressed imported positions")
	var owners := {"public": "passage"}
	for identity: String in spec.cells:
		if identity.is_empty() or owners.has(identity): return _refuse("duplicate/empty shell owner")
		owners[identity] = identity
	if owners.size() != 12: return _refuse("incomplete shop inventory")
	var materials := {}
	for recipe: Dictionary in spec.materials:
		var identity := str(recipe.get("id", ""))
		if identity.is_empty() or materials.has(identity): return _refuse("duplicate/empty material identity")
		materials[identity] = recipe
	var expected := {}
	for row: Dictionary in spec.native_parts:
		var identity := str(row.get("name", ""))
		if identity.is_empty() or expected.has(identity) or not owners.has(str(row.get("owner", ""))) \
			or not materials.has(str(row.get("material", ""))) or int(row.get("triangles", 0)) <= 0:
			return _refuse("invalid/duplicate shell part")
		expected[identity] = row
	if expected.is_empty(): return _refuse("empty shell")
	var packed := load(asset) as PackedScene
	if packed == null: return _refuse("shell import unavailable")
	var imported := packed.instantiate() as Node3D
	if imported == null: return _refuse("shell root unavailable")
	var frame := Frame.new()
	var seen := {}
	var admitted: Array[Dictionary] = []
	for draw: MeshInstance3D in imported.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		if not expected.has(identity) or seen.has(identity) or draw.mesh == null \
			or draw.mesh.get_surface_count() != 1 or draw.get_script() != null:
			return _refuse("unregistered shell draw: " + identity, imported)
		var row: Dictionary = expected[identity]
		var pose := frame._relative(draw, imported)
		if not frame._same(pose, Transform3D.IDENTITY) or draw.mesh.get_faces().size() != int(row.triangles) * 3:
			return _refuse("shell native frame/count changed: " + identity, imported)
		seen[identity] = true
		admitted.append({"draw": draw, "row": row})
	if seen.size() != expected.size(): return _refuse("missing shell part", imported)
	var finishes := {}
	for key: String in materials:
		var recipe: Dictionary = materials[key]
		var catalog := str(recipe.get("catalog_key", ""))
		var tint := frame._point((recipe.get("tint", []) as Array).slice(0, 3))
		if not MatLib.SETS.has(catalog) or not tint.is_finite() or recipe.tint.size() != 4 \
			or float(recipe.tint[3]) != 1.0 or not is_finite(float(recipe.get("normal", -1.0))) \
			or float(recipe.get("normal", -1.0)) <= 0.0 or not is_finite(float(recipe.get("roughness", -1.0))) \
			or float(recipe.get("roughness", -1.0)) <= 0.0:
			return _refuse("invalid shell material: " + key, imported)
		if recipe.has("optical_role"):
			var optical: Dictionary = recipe.get("runtime_optics", {})
			if recipe.optical_role != "Glazing" or recipe.get("room_class") != "public" \
				or float(recipe.get("surface_roughness", -1.0)) != .06 \
				or optical.get("owner") != "res://scripts/building/orison_v2_architectural_materials.gd" \
				or optical.get("shader") != "res://shaders/lamp_glass_surface.gdshader" \
				or optical.get("material_key") != "glassish" \
				or not is_finite(float(optical.get("normal_strength", -1))) or float(optical.get("normal_strength", -1)) < 0 \
				or float(optical.get("surface_roughness", -1)) != .06:
				return _refuse("invalid shell optical role: " + key, imported)
			var glass := preload("res://scripts/building/orison_v2_architectural_materials.gd").new().material_for("Glazing", "public") as ShaderMaterial
			for parameter: String in ["rough_tex", "normal_tex"]:
				var texture := glass.get_shader_parameter(parameter) as Texture2D
				if texture == null or texture.resource_path != str(optical.get(parameter, "")):
					return _refuse("shell optical map identity changed: " + parameter, imported)
			glass.set_shader_parameter("surface_roughness", .06)
			glass.set_shader_parameter("normal_strength", float(optical.normal_strength))
			finishes[key] = glass
			continue
		var base := MatLib.get_mat(catalog).duplicate() as StandardMaterial3D
		base.resource_name = "M_" + catalog
		base.uv1_triplanar = false
		base.uv1_scale = Vector3.ONE / float(MatLib.SETS[catalog][3])
		base.albedo_color = Color(tint.x, tint.y, tint.z, 1.0)
		base.normal_scale = float(recipe.normal)
		base.roughness = float(recipe.roughness)
		finishes[key] = Surface.surface_for(base, {"uv_mode": 0, "pigment_variation": float(recipe.get("pigment", 1.0))})
	var result := Node3D.new()
	result.name = "ArcadePlazaShell"
	for owner: String in owners:
		var cell := Node3D.new()
		cell.name = str(owners[owner])
		result.add_child(cell)
	for entry: Dictionary in admitted:
		var draw: MeshInstance3D = entry.draw
		var row: Dictionary = entry.row
		frame._clear_scene_owners(draw)
		draw.get_parent().remove_child(draw)
		result.get_node(NodePath(str(owners[str(row.owner)]))).add_child(draw)
		draw.set_surface_override_material(0, finishes[str(row.material)])
		draw.set_meta("material_key", str(materials[str(row.material)].catalog_key))
		draw.set_meta("arcade_shell_part", str(row.name))
		draw.set_meta("arcade_shell_owner", str(row.owner))
		if materials[str(row.material)].has("optical_role"):
			draw.set_meta("material_key", str(materials[str(row.material)].runtime_optics.material_key))
			draw.set_meta("preview_material_key", str(materials[str(row.material)].catalog_key))
			draw.set_meta("arcade_shell_optical_role", "Glazing")
			draw.set_meta("glazing_source_surface", draw.mesh.surface_get_material(0))
		draw.create_trimesh_collision()
	imported.free()
	result.set_meta("arcade_shell_asset_sha256", str(spec.asset_sha256))
	return result
