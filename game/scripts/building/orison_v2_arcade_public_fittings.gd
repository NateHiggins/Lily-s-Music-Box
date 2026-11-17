extends RefCounted
## Prepared public fittings only. Never disposes the detached original carrier.
const DATA := "res://data/orison_v2/arcade_public_fittings.json"
const SOURCE := "res://data/building_layout.json"
const CLOCK := "res://data/orison_v2/arcade_clock.json"
const Frame := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
const Surface := preload("res://scripts/building/surface_pass.gd")
var errors: Array[String] = []
const SOURCE_KINDS := {
	"site_crossing_clock_stem":"clock", "site_crossing_clock_drop":"clock",
	"storm_sf_model_laundry_hatch":"hatch", "storm_sf_luncheonette_hatch":"hatch",
	"storm_sf_shoe_rebuilding_hatch":"hatch", "storm_sf_funeral_parlour_hatch":"hatch",
	"storm_sf_photo_supplies_hatch":"hatch",
}

func _refuse(message: String, node: Node = null) -> Node3D:
	errors.append(message)
	if node != null: node.free()
	return null

func _sources(spec: Dictionary) -> bool:
	if spec.get("schema") != "orison.v2.arcade-public-fittings.v1": return false
	if FileAccess.get_file_as_string(SOURCE).replace("\r\n", "\n").sha256_text() != str(spec.get("fabrication_sha256_lf", "")): return false
	if FileAccess.get_file_as_string(CLOCK).replace("\r\n", "\n").sha256_text() != str(spec.get("clock_source_sha256_lf", "")): return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLOCK))
	return FileAccess.get_sha256(str(data.asset)) == str(spec.get("clock_asset_sha256", ""))

func _native(spec: Dictionary, kind: String) -> Node3D:
	if not _sources(spec) or spec.get("parts") is not Array or spec.parts.size() != 7 or spec.get("materials") is not Array:
		return _refuse("public fitting source/declaration changed")
	var asset := str(spec.get("asset", ""))
	if asset != "res://assets/props/arcade_public_fittings.glb" or FileAccess.get_sha256(asset) != str(spec.get("asset_sha256", "")):
		return _refuse("public fitting native payload changed")
	var settings := ConfigFile.new()
	if settings.load(asset + ".import") != OK or settings.get_value("params","meshes/force_disable_compression",false) != true:
		return _refuse("public fittings require authored import precision")
	var expected := {}
	for row: Dictionary in spec.parts:
		var name := str(row.get("name", ""))
		if not SOURCE_KINDS.has(name) or expected.has(name) or row.get("source_id") != name \
			or row.get("kind") != SOURCE_KINDS[name] or int(row.get("triangles", 0)) <= 0:
			return _refuse("public fitting part inventory")
		expected[name] = row
	var materials := {}
	for row: Dictionary in spec.materials:
		var key := str(row.get("key", ""))
		if key not in ["cast_iron", "brass_dull", "metal"] or materials.has(key) or row.get("tint") is not Array or row.tint.size() != 4:
			return _refuse("public fitting registered material inventory")
		for value: Variant in row.tint:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0:
				return _refuse("nonfinite/out-of-range public fitting tint")
		for parameter: String in ["normal", "roughness", "metallic", "pigment"]:
			if typeof(row.get(parameter)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(row[parameter])) \
				or float(row[parameter]) < 0.0 or float(row[parameter]) > 1.0:
				return _refuse("nonfinite/out-of-range public fitting response")
		var original := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		original.uv1_triplanar = false
		original.uv1_scale = Vector3.ONE / float(MatLib.SETS[key][3])
		original.albedo_color = Color(row.tint[0],row.tint[1],row.tint[2],row.tint[3])
		original.normal_scale = float(row.normal)
		original.roughness = float(row.roughness)
		original.metallic = float(row.metallic)
		materials[key] = Surface.surface_for(original,{"uv_mode":0,"pigment_variation":float(row.pigment)})
	if materials.size() != 3: return _refuse("incomplete public fitting materials")
	var packed := load(asset) as PackedScene
	if packed == null: return _refuse("public fitting import unavailable")
	var imported := packed.instantiate() as Node3D
	var frame := Frame.new()
	var seen := {}
	var admitted: Array[Dictionary] = []
	for draw: MeshInstance3D in imported.find_children("*", "MeshInstance3D", true, false):
		var name := str(draw.name)
		if not expected.has(name) or seen.has(name): return _refuse("unexpected public fitting draw", imported)
		var row: Dictionary = expected[name]
		if draw.mesh == null or draw.mesh.get_surface_count() != 1 or draw.mesh.get_faces().size() != int(row.triangles)*3 \
			or not materials.has(str(row.material)) or not frame._same(frame._relative(draw, imported),frame._matrix(row.transform)):
			return _refuse("public fitting native geometry/frame declaration changed", imported)
		seen[name] = true
		if row.kind == kind: admitted.append({"draw":draw,"row":row})
	if seen.size() != 7 or admitted.size() != (2 if kind == "clock" else 5):
		return _refuse("public fitting kind coverage", imported)
	var root := Node3D.new()
	root.name = "ClockSuspension" if kind == "clock" else "ArcadeHatches"
	for record: Dictionary in admitted:
		var draw: MeshInstance3D = record.draw
		var row: Dictionary = record.row
		var part := MeshInstance3D.new()
		part.name = str(row.source_id)
		part.mesh = draw.mesh
		part.transform = frame._matrix(row.transform)
		part.material_override = materials[str(row.material)]
		part.set_meta("material_key", str(row.material))
		part.set_meta("arcade_public_source_id", str(row.source_id))
		root.add_child(part)
		if kind == "hatch": part.create_trimesh_collision()
	root.set_meta("source_disposal_authorized", false)
	imported.free()
	return root

func prepare_hatches(spec: Dictionary) -> Node3D:
	errors.clear()
	return _native(spec, "hatch")

func extract_clock(donor: Node3D, spec: Dictionary) -> Node3D:
	errors.clear()
	if donor == null or donor.is_inside_tree() or donor.name != "passage": return _refuse("clock requires detached original carrier")
	var model := donor.get_node_or_null("ArcadeClock") as Node3D
	if model == null or not model.transform.is_equal_approx(Transform3D.IDENTITY): return _refuse("original clock model/frame absent")
	var movement := model.get_node_or_null("ClockMovement")
	if movement == null or movement.get_script() == null or movement.get_script().resource_path != "res://scripts/building/orison_v2_arcade_clock_movement.gd":
		return _refuse("original clock movement owner absent")
	for node: Node in model.find_children("*", "Node", true, false):
		if node.get_script() != null and node != movement: return _refuse("unregistered clock script owner")
	if model.find_children("*", "Label3D", true, false).size() != 48: return _refuse("original numbered dials incomplete")
	var clock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLOCK))
	var expected := {}
	for row: Dictionary in clock.cells[0].parts: expected[str(row.name)] = row
	var draws := {}
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.get_meta("arcade_clock_part", ""))
		if not expected.has(identity) or draws.has(identity): return _refuse("original clock part inventory changed")
		draws[identity] = draw
	if draws.size() != 13: return _refuse("original clock thirteen parts required")
	var hands: Dictionary = movement.get("_hands")
	var rests: Dictionary = movement.get("_rest")
	if hands.size() != 8 or rests.size() != 8: return _refuse("original clock hand references incomplete")
	for key: String in hands:
		if not draws.has(key) or hands[key] != draws[key] or not model.is_ancestor_of(hands[key]): return _refuse("clock hand authority left original model")
	var delta := Frame.new()._point(spec.get("clock_delta"))
	if not delta.is_finite(): return _refuse("nonfinite clock projection")
	var suspension := _native(spec, "clock")
	if suspension == null: return null
	# Only this known scripted assembly is transferred. Its direct hand refs,
	# local rest frames, optical resource and 48 labels survive unchanged.
	var root := Node3D.new()
	root.name = "ArcadePublicClock"
	root.position = delta
	Frame.new()._clear_scene_owners(model)
	donor.remove_child(model)
	root.add_child(model)
	root.add_child(suspension)
	root.set_meta("arcade_public_clock_projection", true)
	root.set_meta("source_disposal_authorized", false)
	return root
