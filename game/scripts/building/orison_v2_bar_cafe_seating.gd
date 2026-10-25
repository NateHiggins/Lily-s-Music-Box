extends RefCounted
## Exact source-bound placement repair. All eight chairs faced tangent to
## their tables. Keep their original geometry and floor shadows; turn the
## rebuilt native seats and matching hulls 90 degrees toward the tables.
const DATA := "res://data/orison_v2/bar_cafe_seating.json"
const Triangles := preload("res://scripts/building/orison_v2_bar_furniture.gd")
const Hulls := preload("res://scripts/building/orison_v2_bar_receiving.gd")

static func mount(cell: Node3D, layout: Dictionary) -> bool:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or decoded.get("schema_version") != 1 or cell.has_node("BarCafeSeating"): return _reject("guard 11")
	var data: Dictionary = decoded
	if float(data.correction_degrees) != -90.0 or data.chairs.size() != 8: return _reject("guard 13")
	var rows := {}
	for floor: Dictionary in layout.floors:
		if floor.id == "F01":
			for row: Dictionary in floor.furniture: rows[str(row.id)] = row
	var owners := {}
	for chair: Dictionary in data.chairs:
		var identity := str(chair.id)
		if owners.has(identity) or rows.get(identity) != chair.source or str(chair.source.asm) != "chair": return _reject("guard 21")
		if chair.source.at.size() != 2 or not bool(chair.source.exterior) \
				or not is_finite(float(chair.source.yaw)) or not is_finite(float(chair.source.z0)): return _reject("guard 23")
		if int(chair.matches.oak_quartered) != 336 or int(chair.matches.hull) != 12 or int(chair.matches.fx_shadow) != 2: return _reject("guard 24")
		owners[identity] = true
	var groups := {}
	for record: Dictionary in data.retirement:
		if not owners.has(str(record.resident_furniture)) or int(record.count) != record.triangles.size(): return _reject("guard 28")
		var key := str(record.draw)
		if not groups.has(key): groups[key] = {"triangles": [], "count": 0, "source_triangles": int(record.source_triangles), "material": str(record.material)}
		var group: Dictionary = groups[key]
		if int(group.source_triangles) != int(record.source_triangles) or str(group.material) != str(record.material): return _reject("guard 32")
		group.triangles.append_array(record.triangles); group.count += int(record.count)
	if groups.size() != 2: return _reject("guard 34")
	var original_draw: MeshInstance3D
	var original_shape: CollisionShape3D
	var next_shape: ConcavePolygonShape3D
	for identity: String in groups:
		var group: Dictionary = groups[identity]
		if str(group.material) == "hull":
			var body := cell.get_node_or_null(identity.trim_suffix("-colonly")) as StaticBody3D
			if body == null or int(group.count) != 96: return _reject("guard 42")
			var shapes := body.find_children("*", "CollisionShape3D", true, false)
			if shapes.size() != 1: return _reject("guard 44")
			original_shape = shapes[0] as CollisionShape3D
			var old := original_shape.shape as ConcavePolygonShape3D
			if old == null or old.get_faces().size() > int(group.source_triangles) * 3: return _reject("guard 47")
			next_shape = Hulls._trim_hull(old.get_faces(), body.transform * original_shape.transform, group)
			if next_shape == null: return _reject("guard 49")
		elif str(group.material) == "oak_quartered":
			original_draw = cell.get_node_or_null(identity) as MeshInstance3D
			if original_draw == null or int(group.count) != 2688: return _reject("guard 52")
			# This complete draw belongs to the eight chairs. Keep its original
			# arrays and mesh owner intact, and hide it only after exact matching.
			if original_draw.mesh.get_faces().size() != 2688 * 3: return _reject("guard 55")
			if not _matches_complete_draw(original_draw, group): return _reject("guard 56")
		else: return _reject("guard 57")
	if original_draw == null or original_shape == null: return _reject("guard 58")
	var packed := load(str(data.asset)) as PackedScene
	if packed == null: return _reject("guard 60")
	var model := packed.instantiate() as Node3D
	model.name = "BarCafeSeating"
	var parts := {}
	for part: Dictionary in data.parts:
		if parts.has(str(part.name)) or not MatLib.SETS.has(str(part.catalog_key)): model.free(); return _reject("guard 65")
		parts[str(part.name)] = part
	var seen := 0
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not parts.has(str(draw.name)):
			_reject("unregistered native draw: " + str(draw.name)); model.free(); return false
		var part: Dictionary = parts[str(draw.name)]
		if draw.mesh.get_surface_count() != 1 or draw.mesh.get_faces().size() != int(part.triangles) * 3:
			_reject("native draw topology changed: " + str(draw.name)); model.free(); return false
		var key := str(part.catalog_key)
		if absf(float(MatLib.SETS[key][3]) - float(part.tile)) > .000001: model.free(); return _reject("guard 73")
		var material := MatLib.get_mat(key).duplicate() as StandardMaterial3D
		material.uv1_triplanar = false; material.uv1_scale = Vector3.ONE / float(part.tile)
		var original := original_draw.get_active_material(0) as StandardMaterial3D
		if original != null:
			material.albedo_color = original.albedo_color
			material.cull_mode = original.cull_mode
		draw.mesh = draw.mesh.duplicate() as ArrayMesh
		draw.mesh.surface_set_material(0, material)
		draw.name = "F01_retail_bar_native_cafe_" + str(part.name)
		draw.set_meta("material_key", key)
		draw.set_meta("bar_cafe_seating", true); seen += 1
	if seen != parts.size() or seen != 1: model.free(); return _reject("guard 85")
	var hulls := model.find_children("*", "CollisionShape3D", true, false)
	if hulls.size() != 1 or (hulls[0] as CollisionShape3D).shape is not ConcavePolygonShape3D:
		_reject("native collision hull ABI: " + str(hulls)); model.free(); return false
	if ((hulls[0] as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().size() != 96 * 3:
		_reject("native collision triangle count: " + str(((hulls[0] as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().size())); model.free(); return false
	model.set_meta("original_draw", original_draw)
	model.set_meta("original_hull", original_shape.shape)
	model.set_meta("hull_owner", original_shape)
	original_draw.hide(); original_shape.shape = next_shape
	cell.add_child(model)
	cell.set_meta("bar_cafe_yaw_correction", deg_to_rad(float(data.correction_degrees)))
	return true

static func _triangle_key(points: Array[Vector3]) -> String:
	var corners: Array[String] = []
	for point in points:
		corners.append(PackedFloat32Array([point.x,point.y,point.z]).to_byte_array().hex_encode())
	corners.sort()
	return "|".join(corners)

static func _triangle_error(points: Array[Vector3], expected: Array) -> float:
	var best := INF
	for start in 3:
		for direction in [-1,1]:
			var worst := 0.0
			for i in 3: worst = maxf(worst,points[i].distance_to(Triangles._v(expected[posmod(start+direction*i,3)])))
			best = minf(best,worst)
	return best

static func _matches_complete_draw(draw: MeshInstance3D, source: Dictionary) -> bool:
	# Reverse-winding copies are real entries in the shipping seat fans.
	# Group only byte-identical source positions; consume every copy once.
	# Retain the original fitter's source/import quantization bound. The
	# failed10um grid comparison and original ambiguity are archived.
	var groups := {}; var bins := {}
	for triangle: Array in source.triangles:
		var points: Array[Vector3] = []
		for corner: Array in triangle: points.append(Vector3(corner[0],corner[1],corner[2]))
		var key := _triangle_key(points)
		if groups.has(key): groups[key].remaining += 1; continue
		groups[key] = {"triangle":triangle,"remaining":1}
		var cell := Vector3i((((points[0]+points[1]+points[2])/3.0)/.01).floor())
		if not bins.has(cell): bins[cell] = []
		bins[cell].append(key)
	var faces := draw.mesh.get_faces()
	if faces.size() != int(source.count)*3: return _reject("complete draw triangle count changed")
	var extent := draw.mesh.get_aabb().size
	var tolerance := .00003+maxf(maxf(extent.x,extent.y),extent.z)/65535.0
	var maximum_error := 0.0
	for face in range(0,faces.size(),3):
		var points: Array[Vector3] = [draw.transform*faces[face],draw.transform*faces[face+1],draw.transform*faces[face+2]]
		var cell := Vector3i((((points[0]+points[1]+points[2])/3.0)/.01).floor())
		var selected := ""; var error := INF
		for x in range(-1,2):
			for y in range(-1,2):
				for z in range(-1,2):
					for key: String in bins.get(cell+Vector3i(x,y,z),[]):
						var distance := _triangle_error(points,groups[key].triangle)
						if distance > tolerance: continue
						if not selected.is_empty() and selected != key: return _reject("distinct source triangles are ambiguous")
						selected = key; error = distance
		if selected.is_empty() or int(groups[selected].remaining) <= 0: return _reject("missing or overused source triangle at "+str(face/3))
		groups[selected].remaining -= 1; maximum_error = maxf(maximum_error,error)
	for group: Dictionary in groups.values():
		if int(group.remaining) != 0: return _reject("source triangle multiplicity differs")
	draw.set_meta("bar_cafe_source_match",{"triangles":source.count,"position_groups":groups.size(),"maximum_vertex_error_m":maximum_error,"retained_import_bound_m":tolerance})
	print("[CAFE SOURCE] complete shipping triangle multiplicities match; max vertex error=",maximum_error," bound=",tolerance)
	return true

static func _reject(reason: String) -> bool:
	push_error("Bar cafe seating: " + reason)
	return false
