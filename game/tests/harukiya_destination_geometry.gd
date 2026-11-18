extends RefCounted
## Independent read-only loaded-buffer witnesses. Does not call the production
## retirement matcher or trust its success flag.
const RETIREMENT := "res://data/orison_v2/harukiya_destination_retirement.json"
var face_cache: Dictionary = {}

func visible_support(root: Node3D, world_at: Vector3) -> Dictionary:
	var best := {}; var gap := INF
	for draw: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if draw.mesh == null or not draw.is_visible_in_tree(): continue
		var from := draw.to_local(world_at + Vector3.UP * .12)
		var to := draw.to_local(world_at - Vector3.UP * .15)
		if draw.mesh.get_aabb().grow(.001).intersects_segment(from, to) == null: continue
		var key := draw.mesh.get_instance_id()
		if not face_cache.has(key): face_cache[key] = draw.mesh.get_faces()
		var faces: PackedVector3Array = face_cache[key]
		for start in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, faces[start], faces[start+1], faces[start+2])
			if hit == null: continue
			var at := draw.to_global(hit)
			var distance := absf(at.y - world_at.y)
			if distance < gap:
				gap = distance; best = {"draw": str(draw.get_path()), "at": at, "gap_m": gap}
	return best

func retirement(cell: Node3D) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RETIREMENT))
	var raw := (load(OrisonV2BarRegion.CELL) as PackedScene).instantiate() as Node3D
	var rows: Array = []; var errors: Array[String] = []
	var render_left := 0; var collision_left := 0; var negative_count := 0
	for record: Dictionary in data.retirement:
		var source := raw.get_node_or_null(str(record.name)) as Node3D
		var live := cell.get_node_or_null(str(record.name)) as Node3D
		if source == null or live == null:
			errors.append("missing affected imported owner " + str(record.name)); continue
		var expected := _buckets(record.triangles)
		var original := _faces(source, bool(record.hull_only), raw)
		var tolerance := _tolerance(original)
		var negative := _matches(original, expected, tolerance)
		if negative < int(record.count): errors.append("untouched original fails positive detector control " + str(record.name))
		negative_count += negative
		var current := _faces(live, bool(record.hull_only), cell)
		var left := _matches(current, expected, tolerance)
		var collision := 0
		if bool(record.hull_only): collision = left; collision_left += left
		else:
			render_left += left
			if bool(record.colliding):
				collision = _matches(_faces(live, true, cell), expected, tolerance)
				collision_left += collision
		if left != 0 or collision != 0: errors.append("retired faces survive in active buffers " + str(record.name))
		rows.append({"owner": record.name, "expected_removed": record.count, "original_detector_hits": negative,
			"live_render_or_hull_hits": left, "live_collision_hits": collision, "position_tolerance_m": tolerance})
	raw.free()
	return {"rows": rows, "errors": errors, "remaining_render_triangles": render_left,
		"remaining_collision_triangles": collision_left, "unmodified_original_negative_control_hits": negative_count,
		"retirement_source_sha256": FileAccess.get_sha256(RETIREMENT)}

func _faces(owner: Node3D, collision: bool, frame: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not collision:
		if owner is not MeshInstance3D or owner.mesh == null or not owner.visible: return result
		var transform := _relative(owner, frame)
		for point: Vector3 in owner.mesh.get_faces(): result.append(transform * point)
	else:
		for shape: CollisionShape3D in owner.find_children("*", "CollisionShape3D", true, false):
			if shape.disabled or shape.shape == null: continue
			if shape.shape is not ConcavePolygonShape3D: continue
			var transform := _relative(shape, frame)
			for point: Vector3 in shape.shape.get_faces(): result.append(transform * point)
	return result

func _relative(node: Node3D, frame: Node3D) -> Transform3D:
	var transform := node.transform
	var parent := node.get_parent()
	while parent != null and parent != frame:
		if parent is Node3D: transform = parent.transform * transform
		parent = parent.get_parent()
	return transform

func _tolerance(points: PackedVector3Array) -> float:
	if points.is_empty(): return .00003
	var bounds := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points: bounds = bounds.expand(point)
	return .00003 + maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) / 65535.0

func _buckets(triangles: Array) -> Dictionary:
	var result := {}
	for triangle: Array in triangles:
		var points: Array[Vector3] = []
		for corner: Array in triangle: points.append(Vector3(corner[0], corner[1], corner[2]))
		var center := Vector3i((((points[0] + points[1] + points[2]) / 3.0) / .01).floor())
		if not result.has(center): result[center] = []
		result[center].append(points)
	return result

func _matches(faces: PackedVector3Array, buckets: Dictionary, tolerance: float) -> int:
	var count := 0
	for start in range(0, faces.size(), 3):
		var points: Array[Vector3] = [faces[start], faces[start+1], faces[start+2]]
		var center := Vector3i((((points[0] + points[1] + points[2]) / 3.0) / .01).floor())
		var found := false
		for dx in range(-1, 2):
			if found: break
			for dy in range(-1, 2):
				if found: break
				for dz in range(-1, 2):
					if found: break
					for expected: Array in buckets.get(center + Vector3i(dx, dy, dz), []):
						# Check all six vertex permutations, independent of face winding.
						for permutation: Array in [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:
							if points[0].distance_to(expected[permutation[0]]) <= tolerance and points[1].distance_to(expected[permutation[1]]) <= tolerance and points[2].distance_to(expected[permutation[2]]) <= tolerance:
								found = true; break
						if found: break
		if found: count += 1
	return count
