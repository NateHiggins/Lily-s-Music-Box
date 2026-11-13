extends RefCounted
## Independent test expectations from declared source coordinates and witnesses.
const LAYOUT := "res://data/orison_v2/harukiya_destination_layout.json"
const RETIREMENT := "res://data/orison_v2/harukiya_destination_retirement.json"

static func read_layout() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)) as Dictionary

static func relocation(spec: Dictionary, identity: String) -> Transform3D:
	var row: Dictionary = spec.relocations[identity]
	var angle := float(row.get("source_yaw_delta_deg", row.get("yaw_deg", 0.0)))
	var turn := Basis(Vector3.UP, deg_to_rad(angle))
	return Transform3D(turn, GameBoot.b2g(row.at) - turn * GameBoot.b2g(row.source_anchor))

static func faces_in(draw: MeshInstance3D, frame: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for vertex: Vector3 in draw.mesh.get_faces():
		result.append(frame.to_local(draw.to_global(vertex)))
	return result

static func retired_parts(cell: Node3D, fixture: Dictionary, spec: Dictionary, group: String, require: Callable) -> Dictionary:
	var source := {}
	for part: Dictionary in fixture.parts:
		require.call(not source.has(str(part.name)), "unique original partition " + str(part.name))
		source[str(part.name)] = part
	var declared := {}
	for row: Dictionary in spec.retire_native_parts:
		if str(row.parent) != group: continue
		var identity := str(row.name)
		require.call(source.has(identity) and not declared.has(identity), "retired partition exists once in original fixture " + identity)
		declared[identity] = true
	var audit: Dictionary = cell.get_meta("harukiya_destination_retirement")
	var actual := {}
	for row: Dictionary in audit.retired_native_mounts:
		if str(row.parent) != group: continue
		var identity := str(row.name)
		require.call(declared.has(identity) and not actual.has(identity), "retired native audit names exact declared partition " + identity)
		if source.has(identity):
			require.call(int(row.triangles) == int(source[identity].triangles), "retired native partition keeps original face count " + identity)
		actual[identity] = true
	require.call(actual.size() == declared.size(), "every declared native partition has one retirement witness " + group)
	var model := cell.get_node(group)
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var tag := "bar_fixture_mount_part" if group == "BarFixtureMounts" else "bar_pipe_support_part"
		var identity := str(draw.get_meta(tag, ""))
		require.call(source.has(identity) and not declared.has(identity), "current native partition is retained original " + identity)
	return declared

static func support_exclusions(cell: Node3D, original: Array[RID], family: String) -> Array[RID]:
	var result: Array[RID] = original.duplicate()
	for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
		if not str(draw.get_meta("harukiya_destination_part", "")).begins_with(family): continue
		for body: CollisionObject3D in draw.find_children("*", "CollisionObject3D", true, false):
			result.append(body.get_rid())
	return result

static func contact(spec: Dictionary, original: Dictionary, require: Callable) -> Dictionary:
	var result := original.duplicate(true)
	for replacement: Dictionary in spec.support_contacts:
		if str(replacement.id) != str(original.id): continue
		var foot := GameBoot.b2g(replacement.foot)
		var head := GameBoot.b2g(replacement.head)
		require.call(foot.distance_to(head) > 0.0, "replacement support has a nonzero physical span " + str(original.id))
		result.bearing = [head.x, head.y, head.z]
		result.fixture_endpoint = [foot.x, foot.y, foot.z]
		var direction := foot.direction_to(head)
		result.direction = [direction.x, direction.y, direction.z]
		result["destination_replacement"] = true
		return result
	if str(original.id) == "F01_BAR_LT_POOL":
		var movement := relocation(spec, "pool")
		for key: String in ["bearing", "fixture_endpoint"]:
			var values: Array = original[key]
			var value: Vector3 = movement * Vector3(values[0], values[1], values[2])
			result[key] = [value.x, value.y, value.z]
	return result

static func backing(cell: Node3D, point: Vector3, direction: Vector3, exclude: Array[RID]) -> MeshInstance3D:
	var query := PhysicsRayQueryParameters3D.create(cell.to_global(point - direction * .004), cell.to_global(point + direction * .004), 1, exclude)
	var hit: Dictionary = cell.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.position as Vector3).distance_to(cell.to_global(point)) > .00003: return null
	var node: Node = hit.collider
	while node != null and node != cell:
		if node is MeshInstance3D: return node as MeshInstance3D
		node = node.get_parent()
	return null

static func extra_retired(draw: MeshInstance3D, original: Mesh, require: Callable) -> int:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RETIREMENT))
	var records: Array = document.retirement.filter(func(row: Dictionary) -> bool: return str(row.name) == str(draw.name) and not bool(row.hull_only))
	require.call(records.size() <= 1, "one destination record per original source draw " + str(draw.name))
	if records.is_empty(): return 0
	var record: Dictionary = records[0]
	require.call(record.triangles.size() == int(record.count), "destination face list matches exact declared multiplicity " + str(draw.name))
	var before := PackedVector3Array()
	for vertex: Vector3 in original.get_faces(): before.append(draw.transform * vertex)
	var after := PackedVector3Array()
	if draw.mesh.get_surface_count() > 0:
		for vertex: Vector3 in draw.mesh.get_faces(): after.append(draw.transform * vertex)
	var bounds := AABB(before[0], Vector3.ZERO)
	for vertex: Vector3 in before: bounds = bounds.expand(vertex)
	var tolerance := .00003 + maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) / 65535.0
	var bins := {}
	for triangle: Array in record.triangles:
		var vertices: Array[Vector3] = []
		for point: Array in triangle: vertices.append(Vector3(point[0], point[1], point[2]))
		var center := Vector3i(((vertices[0] + vertices[1] + vertices[2]) / .03).floor())
		if not bins.has(center): bins[center] = []
		bins[center].append({"points": vertices, "before": 0, "after": 0})
	for stage: String in ["before", "after"]:
		var faces: PackedVector3Array = before if stage == "before" else after
		for offset in range(0, faces.size(), 3):
			var points: Array[Vector3] = [faces[offset], faces[offset + 1], faces[offset + 2]]
			var center := Vector3i(((points[0] + points[1] + points[2]) / .03).floor())
			var matches: Array[Dictionary] = []
			for x in range(-1, 2):
				for y in range(-1, 2):
					for z in range(-1, 2):
						for expected: Dictionary in bins.get(center + Vector3i(x, y, z), []):
							if _same_triangle(points, expected.points, tolerance): matches.append(expected)
			if not matches.is_empty():
				# Duplicate declarations share a geometric group; count one actual
				# face against every duplicate and verify the group multiplicity below.
				for expected: Dictionary in matches: expected[stage] += 1
	for group: Array in bins.values():
		for expected: Dictionary in group:
			var declared := 0
			for other: Dictionary in group:
				if _same_triangle(expected.points, other.points, 1e-9): declared += 1
			require.call(int(expected.before) == declared, "original witness has exact retired face multiplicity " + str(draw.name))
			require.call(int(expected.after) == 0, "no declared retired face remains in final source draw " + str(draw.name))
	return int(record.count)

static func _same_triangle(actual: Array[Vector3], expected: Array, tolerance: float) -> bool:
	for order: Array in [[0, 1, 2], [1, 2, 0], [2, 0, 1], [0, 2, 1], [2, 1, 0], [1, 0, 2]]:
		if actual[0].distance_to(expected[order[0]]) <= tolerance and actual[1].distance_to(expected[order[1]]) <= tolerance and actual[2].distance_to(expected[order[2]]) <= tolerance:
			return true
	return false

static func retained_attributes(draw: MeshInstance3D, original: Mesh, require: Callable) -> void:
	var old_surfaces: Array = original.get("_surfaces")
	var new_surfaces: Array = draw.mesh.get("_surfaces")
	var seen := {}
	for after: Dictionary in new_surfaces:
		var matches: Array[int] = []
		for index in old_surfaces.size():
			var before: Dictionary = old_surfaces[index]
			var same := true
			for key: String in before:
				if key in ["index_data", "index_count", "lods", "material"]: continue
				same = same and before[key] == after.get(key)
			if same: matches.append(index)
		require.call(matches.size() == 1 and not seen.has(matches[0] if not matches.is_empty() else -1), "each retained surface keeps one exact original vertex/UV/normal/tangent/skin buffer")
		if matches.size() == 1: seen[matches[0]] = true
	var shapes := draw.find_children("*", "CollisionShape3D", true, false)
	if new_surfaces.is_empty():
		require.call(not draw.visible, "fully retired draw is hidden")
		for shape: CollisionShape3D in shapes:
			require.call(shape.disabled, "fully retired source has no enabled collision")
	else:
		for shape: CollisionShape3D in shapes:
			require.call(not shape.disabled and shape.shape is ConcavePolygonShape3D and (shape.shape as ConcavePolygonShape3D).get_faces() == draw.mesh.get_faces(), "remaining source collision equals final rendered triangle multiset")

static func node_point(spec: Dictionary, identity: String) -> Vector3:
	for row: Dictionary in spec.navigation.nodes:
		if str(row.id) == identity: return GameBoot.b2g(row.at)
	push_error("Missing declared destination node " + identity)
	return Vector3(INF, INF, INF)

static func source_snapshot(entry: String) -> Dictionary:
	var result := {}
	var fixture := "res://tests/fixtures/" + entry.get_file().replace("orison_v2_", "orison_").replace("_test.gd", ".json")
	for path: String in [LAYOUT, RETIREMENT, "res://tests/harukiya_fixture_delta.gd", entry, fixture]:
		result[path] = FileAccess.get_sha256(path)
	return result

static func finish_sources(initial: Dictionary, entry: String, require: Callable) -> void:
	var current := source_snapshot(entry)
	require.call(initial == current and not current.values().has(""), "source witness, layout, test and delta helper remain hash-bound throughout the run")
	var directory := OS.get_environment("SHOT_DIR")
	require.call(not directory.is_empty(), "explicit output directory for fixture dependency binding")
	if directory.is_empty(): return
	var path := directory.path_join(entry.get_file().get_basename() + "_dependencies.json")
	require.call(not FileAccess.file_exists(path), "fixture dependency receipt never overwrites original evidence")
	if FileAccess.file_exists(path): return
	var file := FileAccess.open(path, FileAccess.WRITE)
	require.call(file != null, "fixture dependency receipt writable")
	if file == null: return
	file.store_string(JSON.stringify({"schema_version": 1, "evidence_kind": "test_dependency_binding", "source_bindings": initial, "unchanged": initial == current, "scope": "Fixture source custody only; no additional runtime or gameplay acceptance"}, "\t"))
	file.flush()
	require.call(file.get_error() == OK, "fixture dependency receipt saved completely")
	file.close()
