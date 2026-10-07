extends RefCounted
## Dedicated assembled-source replacement; the stateful receiver lives in actors.
const DATA := "res://data/orison_v2/radio_receiving.json"

static func mount_cell(cell: Node3D, layout: Dictionary, enabled: bool = true) -> bool:
	if str(cell.name) != "shop_radio_service": return true
	if cell.has_node("RadioReceiving"): return false
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or int(decoded.get("schema_version", 0)) != 1: return false
	var data: Dictionary = decoded
	var candidates: Array[Dictionary] = []
	for floor: Dictionary in layout.floors:
		if floor.id != "F01": continue
		for row: Dictionary in floor.furniture:
			if str(row.id) == str(data.source_record.id): candidates.append(row)
	if candidates.size() != 1 or candidates[0] != data.source_record: return false
	if str(candidates[0].asm) != "arcade_cab" or int(candidates[0].variant) != 2: return false
	var source: Dictionary = data.source_record
	if str(source.batch) != str(cell.name) or str(source.zone) != "PASSAGE" or not bool(source.exterior): return false
	var tolerance: float = float(data.tolerance)
	if tolerance <= 0.0 or tolerance > 0.00003: return false
	var originals: Dictionary = {}; var removed: Dictionary = {}
	for record: Dictionary in data.original_draws:
		var draw := cell.get_node_or_null(str(record.name)) as MeshInstance3D
		if draw == null or draw.has_meta("material_key") or originals.has(draw): return false
		if not str(draw.name).ends_with("_" + str(record.key)) or draw.mesh.get_surface_count() != 1: return false
		if draw.mesh.get_faces().size() != int(record.expected_triangles) * 3: return false
		var bounds: AABB = draw.transform * draw.mesh.get_aabb()
		if bounds.position.distance_to(_v(record.low)) > tolerance or bounds.end.distance_to(_v(record.high)) > tolerance: return false
		if not draw.find_children("*", "CollisionShape3D", true, false).is_empty(): return false
		originals[draw] = draw.mesh; removed[str(record.name)] = int(record.expected_triangles)
	if originals.size() != 8: return false
	var total := 0
	for count: int in removed.values(): total += count
	if total != 400 or str(data.raw_hull_name) != str(data.hull_name) + "-colonly": return false
	var hull := cell.get_node_or_null(str(data.hull_name)) as StaticBody3D
	if hull == null or hull.collision_layer != 1 or hull.collision_mask != 1: return false
	var shapes := hull.find_children("*", "CollisionShape3D", true, false)
	if shapes.size() != 1: return false
	var old_shape := shapes[0] as CollisionShape3D
	if old_shape.disabled or old_shape.shape is not ConcavePolygonShape3D: return false
	var hull_faces := (old_shape.shape as ConcavePolygonShape3D).get_faces()
	if int(data.hull_triangles) != 12 or hull_faces.size() != int(data.hull_triangles) * 3: return false
	var hull_bounds := AABB(hull_faces[0], Vector3.ZERO)
	for point: Vector3 in hull_faces: hull_bounds = hull_bounds.expand(point)
	hull_bounds = hull.transform * old_shape.transform * hull_bounds
	if hull_bounds.position.distance_to(_v(data.hull_low)) > tolerance or hull_bounds.end.distance_to(_v(data.hull_high)) > tolerance: return false
	var authored_hull := _source_hull(source)
	if authored_hull.position.distance_to(hull_bounds.position) > tolerance or authored_hull.end.distance_to(hull_bounds.end) > tolerance: return false
	# Retire the complete validated source owners without importing a replacement.
	# The authored records and native assets remain available for reinstatement.
	if not enabled:
		for draw: MeshInstance3D in originals: draw.hide()
		old_shape.disabled = true; hull.collision_layer = 0; hull.collision_mask = 0
		return true
	var packed := ResourceLoader.load(str(data.asset), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed == null: return false
	var model := packed.instantiate() as Node3D
	if model == null: return false
	model.name = "RadioReceiving"
	var parts: Dictionary = {}
	for part: Dictionary in data.parts:
		if parts.has(str(part.name)) or str(part.key) != str(part.catalog_key) or not MatLib.SETS.has(str(part.catalog_key)):
			model.free(); return false
		if float(part.tile) <= 0.0 or absf(float(MatLib.SETS[str(part.catalog_key)][3]) - float(part.tile)) > 0.000001:
			model.free(); return false
		parts[str(part.name)] = part
	var mounted: Dictionary = {}; var materials: Dictionary = {}
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not parts.has(str(draw.name)) or mounted.has(str(draw.name)) or draw.mesh.get_surface_count() != 1:
			model.free(); return false
		var part: Dictionary = parts[str(draw.name)]; var key := str(part.key)
		if draw.mesh.get_faces().size() != int(part.triangles) * 3: model.free(); return false
		if not materials.has(key):
			var mat := MatLib.get_mat(str(part.catalog_key)).duplicate() as StandardMaterial3D
			mat.uv1_triplanar = false; mat.uv1_scale = Vector3.ONE / float(part.tile)
			materials[key] = mat
		draw.mesh.surface_set_material(0, materials[key])
		draw.set_meta("radio_receiving_part", str(draw.name)); draw.set_meta("material_key", key)
		mounted[str(draw.name)] = true; draw.name = "radio_receiving_" + str(draw.name)
		draw.create_trimesh_collision()
	if mounted.size() != parts.size(): model.free(); return false
	# Validate every source owner before retiring any part. Full drawn meshes are
	# hidden intact; neighboring source attributes and their collision stay exact.
	var protected: Dictionary = {}; var protected_arrays: Dictionary = {}; var protected_shapes: Dictionary = {}
	for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
		if not draw.has_meta("material_key") and not originals.has(draw):
			protected[draw] = draw.mesh
			var arrays: Array = []
			for i in draw.mesh.get_surface_count(): arrays.append(draw.mesh.surface_get_arrays(i))
			protected_arrays[str(draw.name)] = arrays
			for shape: CollisionShape3D in draw.find_children("*", "CollisionShape3D", true, false):
				protected_shapes[shape] = {"shape":shape.shape, "disabled":shape.disabled, "transform":shape.transform}
	for draw: MeshInstance3D in originals: draw.hide()
	old_shape.disabled = true; hull.collision_layer = 0; hull.collision_mask = 0
	removed[str(hull.name)] = hull_faces.size() / 3
	model.set_meta("original_meshes", originals); model.set_meta("removed_triangles", removed)
	model.set_meta("original_hull", hull); model.set_meta("protected_meshes", protected)
	model.set_meta("protected_arrays", protected_arrays); model.set_meta("protected_shapes", protected_shapes)
	cell.add_child(model)
	return true

static func _v(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])

static func _source_hull(source: Dictionary) -> AABB:
	# Validate this named hull against its authored frame; never select arbitrary
	# triangles by these bounds. The original assembler's hull has fixed margins.
	var shape: Dictionary = ArcadeCabinetProp._VARIANTS[int(source.variant)]
	var w: float = shape.w; var d: float = shape.d; var h: float = shape.h
	var at: Array = source.at; var angle := deg_to_rad(float(source.yaw))
	var low := Vector3(INF, INF, INF); var high := Vector3(-INF, -INF, -INF)
	for x: float in [-w * .5 - .06, w * .5 + .06]:
		for y: float in [-d * .5 - .14, d * .5]:
			for z: float in [0.0, h]:
				var point := GameBoot.b2g([float(at[0]) + cos(angle) * x - sin(angle) * y, float(at[1]) + sin(angle) * x + cos(angle) * y, z])
				low = low.min(point); high = high.max(point)
	return AABB(low, high - low)
