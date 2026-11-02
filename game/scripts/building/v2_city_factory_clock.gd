extends "res://scripts/building/orison_v2_arcade_clock_movement.gd"
## Passive native hand instances; inherited presentation reads CampaignClock.
## No saved field, clock writer, collision owner, light or new material key.
const HAND_STOCK := preload("res://assets/props/arcade_clock.glb")

static func face_failures(faces: Variant, buildings: Array) -> Array[String]:
	var problems: Array[String] = []
	if not faces is Array: return ["factory clock faces must be an array"]
	if faces.is_empty(): return problems
	if faces.size() != 2: return ["factory clock requires exactly two dial faces"]
	var identities: Dictionary = {}
	var normals: Array[Vector3] = []
	var dial_building := ""
	for face: Variant in faces:
		if not face is Dictionary:
			problems.append("factory clock face must be a dictionary"); continue
		var identity := str(face.get("id", ""))
		var building := str(face.get("building", ""))
		if identity.is_empty() or identities.has(identity): problems.append("missing/duplicate factory dial identity")
		identities[identity] = true
		if not buildings.has(building): problems.append("factory dial has no registered building")
		if dial_building.is_empty(): dial_building = building
		elif dial_building != building: problems.append("factory dials must belong to the same building")
		var vectors: Dictionary = {}
		for key: String in ["center_godot", "right_godot", "up_godot", "normal_godot"]:
			var values: Variant = face.get(key)
			if not values is Array or values.size() != 3:
				problems.append("invalid factory dial vector " + key); continue
			var valid := true
			for value: Variant in values:
				if not (value is float or value is int) or not is_finite(float(value)): valid = false
			if not valid:
				problems.append("nonfinite/nonnumeric factory dial vector " + key); continue
			vectors[key] = _v(values)
		if vectors.size() == 4:
			var right: Vector3 = vectors.right_godot
			var up: Vector3 = vectors.up_godot
			var normal: Vector3 = vectors.normal_godot
			if not right.is_normalized() or not up.is_normalized() or not normal.is_normalized() or not right.cross(up).is_equal_approx(normal):
				problems.append("factory dial requires an outward orthonormal frame")
			normals.append(normal)
		var scale_value: Variant = face.get("hand_scale")
		if not (scale_value is float or scale_value is int) or not is_equal_approx(float(scale_value), 3.6):
			problems.append("factory native hand scale must be 3.6")
	if normals.size() == 2 and absf(normals[0].dot(normals[1])) > .00001:
		problems.append("factory clock requires two perpendicular faces")
	return problems

func configure_faces(model: Node3D, faces: Array, buildings: Array) -> bool:
	if model == null or not _hands.is_empty() or faces.size() != 2 or not _clock.bind_state(): return false
	if not face_failures(faces, buildings).is_empty(): return false
	var stock := HAND_STOCK.instantiate() as Node3D
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/arcade_clock.json"))
	var definitions: Dictionary = {}
	for part: Dictionary in metadata.cells[0].parts:
		if str(part.name) in ["south_hour_hand", "south_minute_hand"]: definitions[str(part.name)] = part
	var pending: Array[MeshInstance3D] = []
	for face: Dictionary in faces:
		var identity := str(face.id)
		var right := _v(face.right_godot)
		var up := _v(face.up_godot)
		var normal := _v(face.normal_godot)
		var center := _v(face.center_godot)
		var hand_scale := float(face.hand_scale)
		for kind: String in ["hour", "minute"]:
			var source_key := "south_" + kind + "_hand"
			var source := stock.find_child(source_key, true, false) as MeshInstance3D
			if source == null or not definitions.has(source_key):
				stock.free(); _discard(pending); return false
			var definition: Dictionary = definitions[source_key]
			if str(definition.catalog_key) != "iron_blackened" or not is_equal_approx(float(definition.tile), .4):
				stock.free(); _discard(pending); return false
			var material := MatLib.get_mat(str(definition.catalog_key)).duplicate() as StandardMaterial3D
			material.uv1_triplanar = false
			# Native charts measure metres. Scale repeats with the instance so
			# the registered .4m material retains its physical grain size.
			material.uv1_scale = Vector3.ONE * hand_scale / float(definition.tile)
			var draw := MeshInstance3D.new()
			draw.name = identity + "_" + kind + "_hand"
			draw.mesh = source.mesh
			draw.material_override = material
			# Center is already at .045m dial-front depth. These offsets give
			# .070/.082m wall depth: clear of .060m ticks and each other.
			draw.transform = Transform3D(Basis(right,up,normal).scaled(Vector3.ONE*hand_scale),center+normal*(.037 if kind == "minute" else .025))
			draw.set_meta("city_clock_hand", true)
			draw.set_meta("city_clock_building", str(face.building))
			draw.set_meta("city_clock_source_part", source_key)
			pending.append(draw)
	stock.free()
	for draw: MeshInstance3D in pending:
		model.add_child(draw)
		_hands[str(draw.name)] = draw
		_rest[str(draw.name)] = draw.transform
	return refresh_from_campaign()

func _discard(pending: Array[MeshInstance3D]) -> void:
	for draw: MeshInstance3D in pending: draw.free()
