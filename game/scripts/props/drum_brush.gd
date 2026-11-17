extends RefCounted
## Native rigid brush presentation. Two instances make a pair; the caller
## owns placement and performance. No collision, inventory or autonomous motion.
const DATA := "res://data/orison_v2/harukiya_drum_brush.json"

static func _point(value: Variant) -> Vector3:
	if value is not Array or value.size() != 3:
		return Vector3(INF, INF, INF)
	for coordinate in value:
		if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)):
			return Vector3(INF, INF, INF)
	return Vector3(value[0], value[1], value[2])

static func _contacts_valid(contacts: Dictionary) -> bool:
	# Reject a bad grip/contact frame before a caller can put it in a hand.
	var grip: Dictionary = contacts.get("grip", {})
	var root: Dictionary = contacts.get("fan_root", {})
	var contact: Dictionary = contacts.get("fan_contact", {})
	var tip_rows: Array = contacts.get("fan_tips", {}).get("positions", [])
	var at := _point(grip.get("position"))
	var axis := _point(grip.get("axis"))
	var start := _point(root.get("position"))
	var end := _point(contact.get("position"))
	var normal := _point(contact.get("normal"))
	var radius := float(grip.get("radius_m", 0.0))
	var width := float(contact.get("half_width_m", 0.0))
	if not at.is_finite() or not start.is_finite() or not end.is_finite() or not axis.is_finite() or not normal.is_finite():
		return false
	if not is_equal_approx(axis.length(), 1.0) or not is_equal_approx(normal.length(), 1.0) or absf(axis.dot(normal)) > 0.0001:
		return false
	if not is_finite(radius) or not is_finite(width) or radius <= 0.0 or width <= radius or tip_rows.is_empty():
		return false
	if (start - at).dot(axis) <= radius or (end - start).dot(axis) <= radius:
		return false
	for value in tip_rows:
		var tip := _point(value)
		if not tip.is_finite() or (tip - start).dot(axis) <= 0.0 or absf(tip.x - end.x) > width + 0.00001:
			return false
	return true

static func create() -> Node3D:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or int(decoded.get("schema_version", 0)) != 1:
		return null
	var data: Dictionary = decoded
	if not _contacts_valid(data.get("contacts", {})):
		return null
	var packed := load(str(data.asset)) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null
	var finishes := {}
	for row: Dictionary in data.materials:
		var key := str(row.catalog_key)
		var identity := str(row.key)
		if finishes.has(identity) or not MatLib.SETS.has(key) or absf(float(MatLib.SETS[key][3]) - float(row.meters_per_tile)) > 0.000001:
			model.free()
			return null
		var finish := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		finish.uv1_triplanar = false
		finish.uv1_scale = Vector3.ONE / float(row.meters_per_tile)
		finish.normal_scale = float(row.normal)
		finish.roughness = float(row.roughness)
		var tint: Array = row.tint
		finish.albedo_color = Color(tint[0], tint[1], tint[2], tint[3])
		finishes[identity] = {"material": finish, "source": row}
	var parts := {}
	var seen := {}
	for part: Dictionary in data.partitions:
		if parts.has(str(part.mesh)):
			model.free()
			return null
		parts[str(part.mesh)] = part
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		if not parts.has(identity) or seen.has(identity) or draw.mesh == null:
			model.free()
			return null
		var part: Dictionary = parts[identity]
		if draw.mesh.get_surface_count() != part.materials.size() or draw.mesh.get_faces().size() != int(part.triangles) * 3:
			model.free()
			return null
		draw.mesh = draw.mesh.duplicate() as ArrayMesh
		for surface in part.materials.size():
			var finish: Dictionary = finishes.get(str(part.materials[surface]), {})
			if finish.is_empty():
				model.free()
				return null
			draw.mesh.surface_set_material(surface, finish.material)
			draw.set_meta("material_key", str(finish.source.catalog_key))
			draw.set_meta("harukiya_pigment", float(finish.source.pigment))
		seen[identity] = true
	if seen.size() != parts.size():
		model.free()
		return null
	model.name = "DrumBrush"
	model.set_meta("contacts", data.contacts.duplicate(true))
	model.set_meta("coordinates", str(data.coordinates))
	model.set_meta("integration", str(data.integration))
	return model
