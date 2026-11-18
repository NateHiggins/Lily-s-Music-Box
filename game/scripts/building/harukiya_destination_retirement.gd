extends RefCounted
## Retire only original, named stocks proven against the shipping cell.
## Duplicate faces are consumed with their exact original multiplicity.
const DATA := "res://data/orison_v2/harukiya_destination_retirement.json"
const DESTINATION_LAYOUT := "res://data/orison_v2/harukiya_destination_layout.json"
const Compare := preload("res://scripts/building/orison_v2_bar_cafe_seating.gd")

static func apply(cell: Node3D, layout: Dictionary) -> Dictionary:
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if decoded is not Dictionary or decoded.get("schema_version") != 1: return {}
	var data: Dictionary = decoded
	var rows := {}
	for floor: Dictionary in layout.floors:
		if str(floor.id) == "F01":
			for row: Dictionary in floor.furniture: rows[str(row.id)] = row
	for row: Dictionary in data.source_records:
		if rows.get(str(row.id)) != row: return _fail("source stock changed: " + str(row.id))
	if FileAccess.get_file_as_string(OrisonV2BarRegion.CELL).replace("\r\n", "\n").sha256_text() != str(data.source_cell_sha256) \
			or FileAccess.get_sha256(OrisonV2BarRegion.CELL.get_basename() + ".bin") != str(data.source_buffer_sha256):
		return _fail("shipping cell differs from original retirement witness")
	var changes: Array[Dictionary] = []
	var audit := {"stocks": data.stock_counts, "source_ids": data.stock_counts.keys(), "draws": [],
		"removed_render_triangles": 0, "removed_collision_triangles": 0,
		"remaining_retired_render_triangles": 0, "remaining_retired_collision_triangles": 0, "verified": false}
	for record: Dictionary in data.retirement:
		var owner := cell.get_node_or_null(str(record.name)) as Node3D
		if owner == null: return _fail("missing source owner " + str(record.name))
		var matcher := Matcher.new(record)
		if not matcher.valid: return _fail("invalid source triangle record")
		var change := {"owner": owner, "record": record}
		if bool(record.hull_only):
			if owner is not StaticBody3D: return _fail("expected original hull owner")
			var shapes := owner.find_children("*", "CollisionShape3D", true, false)
			if shapes.size() != 1 or shapes[0].shape is not ConcavePolygonShape3D: return _fail("original hull shape ABI")
			var faces: PackedVector3Array = shapes[0].shape.get_faces()
			matcher.set_tolerance(faces)
			var retained := PackedVector3Array()
			for start in range(0, faces.size(), 3):
				var points: Array[Vector3] = [owner.transform * faces[start], owner.transform * faces[start+1], owner.transform * faces[start+2]]
				if not matcher.consume(points):
					retained.append_array(faces.slice(start, start + 3))
			if not matcher.complete(): return _fail("hull face mismatch " + str(record.name))
			var replacement := ConcavePolygonShape3D.new()
			if not retained.is_empty(): replacement.set_faces(retained)
			change["shape"] = shapes[0]; change["replacement_shape"] = replacement
			change["empty"] = retained.is_empty()
			audit.removed_collision_triangles += int(record.count)
			audit.remaining_retired_collision_triangles += _remaining(retained, owner.transform, record, matcher.tolerance)
		else:
			if owner is not MeshInstance3D or owner.mesh == null: return _fail("expected original draw")
			var draw := owner as MeshInstance3D
			matcher.set_tolerance(draw.mesh.get_faces())
			var mesh := _without_faces(draw, matcher)
			if mesh == null or not matcher.complete(): return _fail("draw face mismatch " + str(record.name))
			var shapes := draw.find_children("*", "CollisionShape3D", true, false)
			if shapes.size() != (1 if bool(record.colliding) else 0): return _fail("source collision ownership changed")
			change["replacement_mesh"] = mesh
			if not shapes.is_empty():
				if shapes[0].shape is not ConcavePolygonShape3D: return _fail("source collision type changed")
				var replacement := ConcavePolygonShape3D.new()
				if mesh.get_surface_count() > 0: replacement.set_faces(mesh.get_faces())
				change["shape"] = shapes[0]; change["replacement_shape"] = replacement
			change["empty"] = mesh.get_surface_count() == 0
			audit.removed_render_triangles += int(record.count)
			var retained := mesh.get_faces() if mesh.get_surface_count() > 0 else PackedVector3Array()
			audit.remaining_retired_render_triangles += _remaining(retained, owner.transform, record, matcher.tolerance)
			if bool(record.colliding):
				audit.removed_collision_triangles += int(record.count)
				audit.remaining_retired_collision_triangles += _remaining(retained, owner.transform, record, matcher.tolerance)
		changes.append(change)
		audit.draws.append({"name": record.name, "source_name": record.source_name,
			"removed": record.count, "owners": record.owners, "hull_only": record.hull_only})
	if audit.remaining_retired_render_triangles != 0 or audit.remaining_retired_collision_triangles != 0:
		return _fail("retired original faces remain after replacement")
	var supports := _prepare_seat_supports(cell, data, rows, changes)
	if supports.is_empty(): return {}
	# Publish only after every exact source selection and shape has passed.
	for change: Dictionary in changes:
		if change.has("replacement_mesh"):
			(change.owner as MeshInstance3D).mesh = change.replacement_mesh
			if bool(change.empty): change.owner.hide()
		if change.has("shape"):
			change.shape.shape = change.replacement_shape
			change.shape.disabled = bool(change.empty)
	var support_root := Node3D.new(); support_root.name = "HarukiyaRetainedSeatSupports"
	cell.add_child(support_root)
	audit["retained_seat_supports"] = []
	for support: Dictionary in supports.records:
		var body := StaticBody3D.new(); body.name = str(support.id)
		var collision := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new(); shape.set_faces(support.faces)
		collision.shape = shape; body.add_child(collision); support_root.add_child(body)
		body.set_meta("retained_seat_support", str(support.seat_id))
		audit.retained_seat_supports.append({"id": support.id, "seat_id": support.seat_id,
			"source_draw": support.source_draw, "triangles": support.faces.size() / 3,
			"closed": true, "matches_loaded_render": true})
	audit.verified = true
	cell.set_meta("harukiya_destination_retirement", audit)
	return audit

## Only the five retained stool tops lack support collision. Match their closed
## native face sets against the mesh that will remain after retirement, then use
## those actual loaded points. Never collide the entire merged vinyl draw.
static func _prepare_seat_supports(cell: Node3D, data: Dictionary, rows: Dictionary, changes: Array[Dictionary]) -> Dictionary:
	if cell.has_node("HarukiyaRetainedSeatSupports"): return _fail("retained seat support owner already mounted")
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESTINATION_LAYOUT))
	if decoded is not Dictionary or decoded.get("schema_version") != 1: return _fail("seat support layout missing")
	var seats := {}
	for seat: Dictionary in decoded.seats:
		var support := str(seat.support)
		if not support.begins_with("retail_bar_stool") or not support.ends_with("_seat"): continue
		if seats.has(support): return _fail("duplicate retained stool support")
		seats[support] = seat
	if seats.size() != 5 or data.get("support_source_records", []).size() != 5 \
			or data.get("seat_supports", []).size() != 5: return _fail("retained stool support count changed")
	var sources := {}
	for row: Dictionary in data.support_source_records:
		var identity := str(row.id)
		if sources.has(identity) or not seats.has(identity) or rows.get(identity) != row \
				or data.stock_counts.has(identity): return _fail("retained stool source changed")
		if str(row.get("asm", "")) != "pipe" or bool(row.get("local", false)) \
				or row.p1 != seats[identity].at: return _fail("stool socket differs from original top")
		sources[identity] = row
	var prepared: Array[Dictionary] = []
	var seen := {}
	for record: Dictionary in data.seat_supports:
		var identity := str(record.id)
		if seen.has(identity) or not sources.has(identity) or not bool(record.get("closed", false)) \
				or str(record.seat_id) != str(seats[identity].id): return _fail("invalid retained support witness")
		var draw := cell.get_node_or_null(str(record.name)) as MeshInstance3D
		if draw == null or draw.mesh == null or not draw.find_children("*", "CollisionShape3D", true, false).is_empty():
			return _fail("retained stool draw or collision ownership changed")
		var retained: Mesh = draw.mesh
		for change: Dictionary in changes:
			if change.owner == draw: retained = change.get("replacement_mesh", draw.mesh)
		var matcher := Matcher.new(record)
		matcher.set_tolerance(draw.mesh.get_faces())
		var faces := retained.get_faces()
		var selected := PackedVector3Array()
		for start in range(0, faces.size(), 3):
			var points: Array[Vector3] = [draw.transform * faces[start], draw.transform * faces[start+1], draw.transform * faces[start+2]]
			if matcher.consume(points): selected.append_array(points)
		if not matcher.complete() or not _closed_faces(selected): return _fail("retained stool differs from loaded rendered support: " + identity)
		prepared.append({"id": identity, "seat_id": record.seat_id, "source_draw": record.name, "faces": selected})
		seen[identity] = true
	return {"records": prepared}

static func _closed_faces(faces: PackedVector3Array) -> bool:
	if faces.is_empty() or faces.size() % 3 != 0: return false
	var edges := {}
	for start in range(0, faces.size(), 3):
		for side in 3:
			var a := str(Vector3i((faces[start + side] * 100000.0).round()))
			var b := str(Vector3i((faces[start + (side + 1) % 3] * 100000.0).round()))
			if a == b: return false
			var edge := a + ":" + b if a < b else b + ":" + a
			edges[edge] = int(edges.get(edge, 0)) + 1
	for count: int in edges.values():
		if count != 2: return false
	return true

static func _remaining(faces: PackedVector3Array, frame: Transform3D, record: Dictionary, import_tolerance: float) -> int:
	if faces.is_empty(): return 0
	# Removing distant stock does not change the original import quantization.
	var probe := Matcher.new(record); probe.tolerance = import_tolerance
	var count := 0
	for start in range(0, faces.size(), 3):
		var points: Array[Vector3] = [frame*faces[start], frame*faces[start+1], frame*faces[start+2]]
		if probe.consume(points): count += 1
	return count if probe.valid else -1

static func _without_faces(draw: MeshInstance3D, matcher: Matcher) -> ArrayMesh:
	var packed_surfaces: Array = draw.mesh.get("_surfaces")
	var next: Array = []
	for surface in draw.mesh.get_surface_count():
		var arrays := draw.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty(): return null # shipping source is indexed; do not synthesize new attributes
		var kept := PackedInt32Array()
		for start in range(0, indices.size(), 3):
			var points: Array[Vector3] = []
			for j in 3: points.append(draw.transform * vertices[indices[start+j]])
			if not matcher.consume(points):
				for j in 3: kept.append(indices[start+j])
		if kept.is_empty(): continue
		var packed: Dictionary = packed_surfaces[surface].duplicate(true)
		if kept.size() != indices.size():
			var width: int = packed.index_data.size() / int(packed.index_count)
			if width != 2 and width != 4: return null
			var bytes := PackedByteArray(); bytes.resize(kept.size() * width)
			for i in kept.size():
				if width == 2: bytes.encode_u16(i*width, kept[i])
				else: bytes.encode_u32(i*width, kept[i])
			packed.index_data = bytes; packed.index_count = kept.size(); packed.lods = {}
		next.append(packed)
	var result := ArrayMesh.new()
	if not next.is_empty(): result.set("_surfaces", next)
	return result

static func _fail(reason: String) -> Dictionary:
	push_error("Harukiya destination retirement: " + reason)
	return {}

class Matcher:
	var groups := {}; var bins := {}; var valid := true; var tolerance := .00003
	func _init(record: Dictionary) -> void:
		if int(record.count) != record.triangles.size(): valid = false; return
		for triangle: Array in record.triangles:
			if triangle.size() != 3: valid = false; return
			var points: Array[Vector3] = []
			for corner: Array in triangle: points.append(Vector3(corner[0], corner[1], corner[2]))
			var key := Compare._triangle_key(points)
			if groups.has(key): groups[key].remaining += 1; continue
			groups[key] = {"triangle": triangle, "remaining": 1}
			var cell := Vector3i((((points[0]+points[1]+points[2])/3.0)/.01).floor())
			if not bins.has(cell): bins[cell] = []
			bins[cell].append(key)
	func set_tolerance(faces: PackedVector3Array) -> void:
		if faces.is_empty(): valid = false; return
		var bounds := AABB(faces[0], Vector3.ZERO)
		for point: Vector3 in faces: bounds = bounds.expand(point)
		tolerance = .00003 + maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))/65535.0
	func consume(points: Array[Vector3]) -> bool:
		var cell := Vector3i((((points[0]+points[1]+points[2])/3.0)/.01).floor())
		var selected := ""
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					for key: String in bins.get(cell+Vector3i(x,y,z), []):
						if Compare._triangle_error(points, groups[key].triangle) > tolerance: continue
						if selected != "" and selected != key: valid = false; return false
						selected = key
		if selected == "": return false
		if int(groups[selected].remaining) <= 0: valid = false; return false
		groups[selected].remaining -= 1
		return true
	func complete() -> bool:
		if not valid: return false
		for group: Dictionary in groups.values():
			if int(group.remaining) != 0: return false
		return true
