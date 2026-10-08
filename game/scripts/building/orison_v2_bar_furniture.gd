extends RefCounted
## Replace exact passive source triangles; all live bar actors remain separate.
const DATA := "res://data/orison_v2/bar_furniture.json"

static func mount_cell(cell: Node3D, layout: Dictionary) -> bool:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or decoded.get("schema_version") != 1 or cell.has_node("BarFurniture"): return false
	var data: Dictionary = decoded
	var sources := {}
	for floor: Dictionary in layout.floors:
		if floor.id == "F01":
			for row: Dictionary in floor.furniture: sources[str(row.id)] = row
	for row: Dictionary in data.source_records:
		if not sources.has(str(row.id)) or sources[str(row.id)] != row or not _valid_source(row): return _fail("source record: "+str(row.id))
	var originals := {}; var changes := {}; var retired := {}
	for record: Dictionary in data.retirement:
		var draw := cell.get_node_or_null(str(record.name)) as MeshInstance3D
		if draw == null or draw.mesh == null or draw.has_meta("material_key") or originals.has(draw): return _fail("source draw: "+str(record.name))
		if draw.mesh.get_faces().size() > int(record.source_triangles)*3: return _fail("source draw count: "+str(record.name))
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if bool(record.colliding):
			if shapes.size() != 1 or (shapes[0] as CollisionShape3D).shape is not ConcavePolygonShape3D: return _fail("source collision: "+str(record.name))
		elif not shapes.is_empty(): return _fail("unexpected source collision: "+str(record.name))
		var result := _without_source_triangles(draw, record)
		if result == null: return _fail("source triangle selection: "+str(record.name))
		originals[draw] = draw.mesh; changes[draw] = result; retired[str(draw.name)] = int(record.count)
	var packed := ResourceLoader.load(str(data.asset), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed == null: return false
	var model := packed.instantiate() as Node3D
	if model == null: return false
	model.name = "BarFurniture"
	var parts := {}; var materials := {}; var mounted := {}
	for part: Dictionary in data.parts:
		if parts.has(str(part.name)) or not MatLib.SETS.has(str(part.catalog_key)) or float(part.tile) <= 0.0:
			model.free(); return false
		if absf(float(MatLib.SETS[str(part.catalog_key)][3])-float(part.tile)) > 0.000001:
			model.free(); return false
		parts[str(part.name)] = part
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var identity := str(draw.name)
		if not parts.has(identity) or mounted.has(identity) or draw.mesh.get_surface_count() != 1:
			model.free(); return false
		var part: Dictionary = parts[identity]; var key := str(part.key)
		if draw.mesh.get_faces().size() != int(part.triangles)*3: model.free(); return false
		if not materials.has(key):
			var material := MatLib.get_mat(str(part.catalog_key)).duplicate() as StandardMaterial3D
			material.uv1_triplanar = false; material.uv1_scale = Vector3.ONE / float(part.tile)
			material.normal_scale = float(part.normal); material.roughness = float(part.roughness)
			if part.has("metallic"): material.metallic = float(part.metallic)
			var tint: Array = part.tint; material.albedo_color = Color(tint[0],tint[1],tint[2],tint[3])
			materials[key] = material
		draw.mesh.surface_set_material(0, materials[key]); draw.set_meta("material_key", str(part.catalog_key))
		draw.set_meta("bar_furniture_part", identity); draw.set_meta("bar_furniture_pigment", float(part.pigment))
		draw.name = "F01_retail_bar_native_" + identity
		# The microphone keeps its original coarse base hull. Tiny flexible
		# and grille stock is visual only; piano/cabinet solids own their fit.
		if str(part.assembly) != "Microphone": draw.create_trimesh_collision()
		mounted[identity] = true
	if mounted.size() != parts.size(): model.free(); return false
	for draw: MeshInstance3D in changes:
		draw.mesh = changes[draw]
		if cell.has_meta("bar_ceiling_finish"):
			var ceiling: Dictionary = cell.get_meta("bar_ceiling_finish")
			if ceiling.owner == draw:
				# The earlier ceiling repair added a second surface to the
				# shared soot draw. Keep its exact buffer and remap its index
				# when the separate score-panel surface becomes empty.
				ceiling.finish_surface = (draw.mesh.get_meta("bar_source_surface_indices") as Array).find(int(ceiling.finish_surface))
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		if draw.mesh.get_surface_count() == 0:
			draw.hide()
			if not shapes.is_empty(): (shapes[0] as CollisionShape3D).disabled = true
		elif not shapes.is_empty():
			var shape := ConcavePolygonShape3D.new(); shape.set_faces(draw.mesh.get_faces())
			(shapes[0] as CollisionShape3D).shape = shape
	model.set_meta("original_meshes", originals); model.set_meta("removed_triangles", retired)
	cell.add_child(model)
	return true

static func calibrate(cell: Node3D) -> void:
	var model := cell.get_node_or_null("BarFurniture")
	if model == null: return
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		# SurfacePass owns state and cache lifetime. Apply the local finish to
		# its already-distinct per-key material, preserving that owner.
		var surface := draw.get_surface_override_material(0) as ShaderMaterial
		if surface != null: surface.set_shader_parameter("pigment_variation", float(draw.get_meta("bar_furniture_pigment")))

static func _without_source_triangles(draw: MeshInstance3D, record: Dictionary) -> ArrayMesh:
	if draw.mesh.get_surface_count() < 1 or int(record.count) != record.triangles.size():
		_fail("surface/count structure: "+str(draw.name)+" surfaces="+str(draw.mesh.get_surface_count())+" record="+str(record.count)+" expected="+str(record.triangles.size())); return null
	var expected: Array = record.triangles
	var extent := draw.mesh.get_aabb().size
	var tolerance := 0.00003 + maxf(maxf(extent.x,extent.y),extent.z)/65535.0
	var bins := {}; var used := {}
	for i in expected.size():
		var triangle: Array = expected[i]
		if triangle.size() != 3: return null
		var center := (_v(triangle[0])+_v(triangle[1])+_v(triangle[2]))/3.0
		var key := Vector3i((center/.01).floor())
		if not bins.has(key): bins[key] = []
		bins[key].append(i)
	var source_surfaces: Array = draw.mesh.get("_surfaces")
	var surfaces: Array = []; var surface_indices: Array = []
	for surface in draw.mesh.get_surface_count():
		var arrays := draw.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var retained := PackedInt32Array()
		for start in range(0, indices.size(), 3):
			var points: Array[Vector3] = []
			for j in 3: points.append(draw.transform*vertices[indices[start+j]])
			var key := Vector3i(((points[0]+points[1]+points[2])/3.0/.01).floor())
			var match_index := -1
			for dx in range(-1,2):
				for dy in range(-1,2):
					for dz in range(-1,2):
						for candidate: int in bins.get(key+Vector3i(dx,dy,dz),[]):
							if _same_triangle(points,expected[candidate],tolerance):
								if match_index != -1 or used.has(candidate):
									_fail("ambiguous triangle "+str(draw.name)+" candidate="+str(candidate)+" prior="+str(match_index)); return null
								match_index = candidate
			if match_index == -1:
				for j in 3: retained.append(indices[start+j])
			else: used[match_index] = true
		if retained.is_empty(): continue
		var packed: Dictionary = source_surfaces[surface].duplicate(true)
		if retained.size() != indices.size():
			# Preserve imported attributes, changing only selected indices.
			var width: int = packed.index_data.size()/int(packed.index_count)
			if width != 2 and width != 4:
				_fail("imported index width: "+str(width)+" "+str(draw.name)); return null
			var bytes := PackedByteArray(); bytes.resize(retained.size()*width)
			for i in retained.size():
				if width == 2: bytes.encode_u16(i*width,retained[i])
				else: bytes.encode_u32(i*width,retained[i])
			packed.index_data = bytes; packed.index_count = retained.size(); packed.lods = {}
		surfaces.append(packed); surface_indices.append(surface)
	if used.size() != expected.size():
		push_error("Bar source triangle mismatch: "+str(draw.name)+" "+str(used.size())+"/"+str(expected.size())); return null
	var result := ArrayMesh.new()
	if not surfaces.is_empty(): result.set("_surfaces",surfaces)
	result.set_meta("bar_source_surface_indices",surface_indices)
	return result

static func _same_triangle(points: Array[Vector3], expected: Array, tolerance: float) -> bool:
	for start in 3:
		for direction in [-1,1]:
			var same := true
			for i in 3:
				if points[i].distance_to(_v(expected[posmod(start+direction*i,3)])) > tolerance: same = false
			if same: return true
	return false

static func _v(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])

static func _fail(reason: String) -> bool:
	push_error("Bar furniture: "+reason)
	return false

static func _valid_source(row: Dictionary) -> bool:
	if row.has("rect"):
		var rect: Array = row.rect
		if rect.size()!=4 or float(row.h)<=0. or not is_finite(float(row.z0)) or str(row.mat).is_empty(): return false
		for component: float in rect:
			if not is_finite(component): return false
		return absf(float(rect[2])-float(rect[0]))>.0001 and absf(float(rect[3])-float(rect[1]))>.0001
	var at: Array = row.at
	if at.size()!=2 or not is_finite(float(at[0])) or not is_finite(float(at[1])) or not is_finite(float(row.yaw)): return false
	if str(row.asm)=="micstand": return bool(row.exterior) and is_finite(float(row.z0))
	if str(row.asm)!="pipe" or float(row.r)<=0. or str(row.mat).is_empty(): return false
	return _v(row.p0).is_finite() and _v(row.p1).is_finite() and _v(row.p0).distance_to(_v(row.p1))>.0001
