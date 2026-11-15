extends RefCounted
## Entry-only, transactional retirement of exact passive shipping stocks.
## Prior adapters own their changes; this preserves all currently retained data.
const DATA := "res://data/orison_v2/harukiya_entry_retirement.json"
const ENTRY_DATA := "res://data/orison_v2/harukiya_entry.json"
const CELL := "res://assets/building/floor_01_cells/shop_bar.gltf"
const META := "harukiya_entry_retirement"
const Legacy := preload("res://scripts/building/harukiya_destination_retirement.gd")

static func apply(cell: Node3D, layout: Dictionary) -> Dictionary:
	if not is_instance_valid(cell) or cell.has_meta(META): return _fail("missing cell or entry already retired")
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(ENTRY_DATA))
	if decoded is not Dictionary or decoded.get("schema_version") != 1 or spec is not Dictionary or spec.get("schema_version") != 1:
		return _fail("entry data schema")
	var data: Dictionary = decoded
	if data.get("source_records") is not Array or data.get("retirement") is not Array or data.get("stock_counts") is not Dictionary \
			or spec.get("retire_ids") is not Array or data.source_records.is_empty() or data.retirement.is_empty():
		return _fail("entry retirement inventory")
	if data.source_records != spec.get("source_records", []) or not spec.get("retire_components", []).is_empty():
		return _fail("entry source selection differs from native specification")
	var rows := {}; var floors := 0
	for floor: Dictionary in layout.get("floors", []):
		if str(floor.id) != "F01": continue
		floors += 1
		for row: Dictionary in floor.furniture:
			if rows.has(str(row.id)): return _fail("duplicate layout source identity")
			rows[str(row.id)] = row
	if floors != 1: return _fail("unique F01 source floor required")
	var source_ids: Array[String] = []; var expected_totals := {}
	for raw: Variant in data.source_records:
		if raw is not Dictionary: return _fail("source record type")
		var identity := str(raw.get("id", ""))
		if identity.is_empty() or source_ids.has(identity) or rows.get(identity) != raw or data.stock_counts.get(identity) is not Dictionary:
			return _fail("source stock changed or repeated: " + identity)
		source_ids.append(identity)
		var total := 0
		for count: Variant in data.stock_counts[identity].values():
			if not (count is int or count is float) or int(count) < 0 or float(count) != float(int(count)):
				return _fail("invalid source stock triangle count")
			total += int(count)
		if total <= 0: return _fail("empty source stock")
		expected_totals[identity] = total
	if source_ids != spec.retire_ids or source_ids.size() != data.stock_counts.size(): return _fail("source stock roster mismatch")
	if FileAccess.get_file_as_string(CELL).replace("\r\n", "\n").sha256_text() != str(data.get("source_cell_sha256", "")) \
			or FileAccess.get_sha256(CELL.get_basename() + ".bin") != str(data.get("source_buffer_sha256", "")):
		return _fail("shipping cell differs from entry witness")
	# This is an unmounted resource instance, never an actor or a second world.
	# It supplies the existing matcher's original import-quantization bound.
	var originals := _original_imports(data.retirement)
	if originals.is_empty(): return _fail("pristine imported source ABI")
	var changes: Array[Dictionary] = []; var seen := {}; var actual_totals := {}
	var audit := {"verified": false, "source_ids": source_ids, "stocks": data.stock_counts,
		"draws": [], "removed_render_triangles": 0, "removed_collision_triangles": 0,
		"remaining_retired_render_triangles": 0, "remaining_retired_collision_triangles": 0,
		"preservation_scope": "Every current unselected render index and packed vertex channel, surface material and collider face is preserved. Prior adapters remain responsible for their earlier changes."}
	for raw: Variant in data.retirement:
		if raw is not Dictionary: return _fail("retirement record type")
		var record: Dictionary = raw; var identity := str(record.get("name", ""))
		if seen.has(identity) or not originals.has(identity) or record.get("owners") is not Dictionary:
			return _fail("duplicate or unknown source draw")
		seen[identity] = true
		var total := 0
		for stock: String in record.owners:
			var count := int(record.owners[stock])
			if not expected_totals.has(stock) or count <= 0: return _fail("unknown or empty draw stock")
			total += count; actual_totals[stock] = int(actual_totals.get(stock, 0)) + count
		if total != int(record.count): return _fail("draw owner multiplicity differs")
		var owner := cell.get_node_or_null(identity) as Node3D
		if owner == null or owner.get_parent() != cell or owner.transform != originals[identity].transform:
			return _fail("source owner or local frame changed: " + identity)
		var matcher := Legacy.Matcher.new(record)
		if not matcher.valid: return _fail("invalid source triangle record")
		matcher.tolerance = float(originals[identity].tolerance)
		var change := {"owner": owner, "record": record, "empty": false}
		var shapes := owner.find_children("*", "CollisionShape3D", true, false)
		if bool(record.hull_only):
			if owner is not StaticBody3D or shapes.size() != 1: return _fail("hull owner ABI")
		else:
			if owner is not MeshInstance3D or owner.mesh is not ArrayMesh or owner.mesh.get_surface_count() != 1:
				return _fail("single original packed draw required")
			var draw := owner as MeshInstance3D
			var before_count: int = draw.mesh.get_faces().size() / 3
			# Count alone never authorizes earlier losses. Exact matching below
			# binds this removal; packed checks preserve the current remainder.
			if before_count < int(record.count) or before_count > int(record.source_triangles): return _fail("current draw count outside original bounds")
			var replacement := Legacy._without_faces(draw, matcher)
			if replacement == null or not matcher.complete(): return _fail("draw face mismatch: " + identity)
			if not _packed_remainder_preserved(draw.mesh as ArrayMesh, replacement, int(record.count)):
				return _fail("unselected packed draw attributes changed: " + identity)
			var retained := replacement.get_faces() if replacement.get_surface_count() > 0 else PackedVector3Array()
			if Legacy._remaining(retained, owner.transform, record, matcher.tolerance) != 0: return _fail("retired render faces remain")
			change.replacement_mesh = replacement; change.empty = replacement.get_surface_count() == 0
			audit.removed_render_triangles += int(record.count)
			if shapes.size() != (1 if bool(record.colliding) else 0): return _fail("source collision ownership changed")
		if not shapes.is_empty():
			var prepared := _prepare_collision(owner, shapes[0] as CollisionShape3D, record, matcher.tolerance)
			if prepared.is_empty(): return _fail("source collision mismatch: " + identity)
			change.shape = shapes[0]; change.replacement_shape = prepared.shape
			if bool(record.hull_only): change.empty = prepared.empty
			elif bool(change.empty) != bool(prepared.empty): return _fail("render/collision retirement emptiness differs")
			audit.removed_collision_triangles += int(record.count)
		changes.append(change)
		audit.draws.append({"name": identity, "source_name": record.source_name, "removed": record.count,
			"owners": record.owners, "hull_only": record.hull_only, "import_tolerance_m": matcher.tolerance,
			"unselected_packed_channels_preserved": not bool(record.hull_only), "collision_faces_filtered_independently": not shapes.is_empty()})
	if actual_totals != expected_totals: return _fail("source stock occurrence totals differ")
	# No live mesh, shape, visibility or metadata has changed before this point.
	for change: Dictionary in changes:
		if change.has("replacement_mesh"):
			(change.owner as MeshInstance3D).mesh = change.replacement_mesh
			if bool(change.empty): change.owner.hide()
		if change.has("shape"):
			change.shape.shape = change.replacement_shape
			change.shape.disabled = bool(change.empty)
	audit.verified = true; cell.set_meta(META, audit)
	return audit

static func _original_imports(records: Array) -> Dictionary:
	var packed := load(CELL) as PackedScene
	if packed == null: return {}
	var instance := packed.instantiate()
	if instance is not Node3D:
		if instance != null: instance.free()
		return {}
	var original := instance as Node3D
	var result := {}; var valid := true
	for raw: Variant in records:
		if raw is not Dictionary or raw.get("triangles") is not Array or int(raw.get("count", 0)) <= 0:
			valid = false; break
		var record: Dictionary = raw; var identity := str(record.get("name", ""))
		var owner := original.get_node_or_null(identity) as Node3D
		if owner == null or owner.get_parent() != original or result.has(identity): valid = false; break
		var faces := PackedVector3Array()
		if bool(record.get("hull_only", false)):
			var shapes := owner.find_children("*", "CollisionShape3D", true, false)
			if owner is not StaticBody3D or shapes.size() != 1 or shapes[0].shape is not ConcavePolygonShape3D \
					or not _identity_shape_frame(owner, shapes[0] as CollisionShape3D): valid = false; break
			faces = shapes[0].shape.get_faces()
		elif owner is MeshInstance3D and owner.mesh != null and owner.mesh.get_surface_count() == 1:
			faces = owner.mesh.get_faces()
		else: valid = false; break
		if faces.is_empty() or faces.size() != int(record.get("source_triangles", -1))*3: valid = false; break
		var matcher := Legacy.Matcher.new(record)
		if not matcher.valid: valid = false; break
		matcher.set_tolerance(faces)
		result[identity] = {"tolerance": matcher.tolerance, "transform": owner.transform}
	original.free()
	return result if valid else {}

static func _identity_shape_frame(owner: Node3D, shape: CollisionShape3D) -> bool:
	var pose := Transform3D.IDENTITY; var cursor: Node = shape
	while cursor != owner:
		if cursor == null or cursor is not Node3D: return false
		pose = (cursor as Node3D).transform * pose; cursor = cursor.get_parent()
	return pose == Transform3D.IDENTITY

static func _prepare_collision(owner: Node3D, collision: CollisionShape3D, record: Dictionary, tolerance: float) -> Dictionary:
	if collision == null or collision.disabled or collision.shape is not ConcavePolygonShape3D or not _identity_shape_frame(owner, collision): return {}
	var source := collision.shape as ConcavePolygonShape3D
	var faces := source.get_faces()
	if faces.is_empty() or faces.size()%3 != 0 or faces.size() > int(record.source_triangles)*3: return {}
	var matcher := Legacy.Matcher.new(record); matcher.tolerance = tolerance
	if not matcher.valid: return {}
	var retained := PackedVector3Array()
	for start in range(0, faces.size(), 3):
		var points: Array[Vector3] = [owner.transform*faces[start], owner.transform*faces[start+1], owner.transform*faces[start+2]]
		if not matcher.consume(points): retained.append_array(faces.slice(start, start+3))
	if not matcher.complete() or Legacy._remaining(retained, owner.transform, record, tolerance) != 0: return {}
	var replacement := source.duplicate() as ConcavePolygonShape3D
	if retained.is_empty():
		replacement = ConcavePolygonShape3D.new()
		replacement.margin = source.margin; replacement.backface_collision = source.backface_collision
	else: replacement.set_faces(retained)
	if replacement.get_faces() != retained: return {}
	return {"shape": replacement, "empty": retained.is_empty()}

static func _packed_remainder_preserved(before: ArrayMesh, after: ArrayMesh, removed: int) -> bool:
	if before.get_surface_count() != 1: return false
	var original: Array = before.get("_surfaces")
	var old: Dictionary = original[0]
	# Shipping import disables generated LODs; refuse rather than discard any.
	if not old.get("lods", {}).is_empty(): return false
	if after.get_surface_count() == 0: return int(old.index_count) == removed*3
	if after.get_surface_count() != 1: return false
	var packed: Array = after.get("_surfaces"); var current: Dictionary = packed[0]
	if not current.get("lods", {}).is_empty(): return false
	var old_channels := old.duplicate(); var new_channels := current.duplicate()
	for key: String in ["index_data", "index_count", "lods"]:
		old_channels.erase(key); new_channels.erase(key)
	if old_channels != new_channels: return false
	if int(old.index_count)-int(current.index_count) != removed*3 or before.surface_get_material(0) != after.surface_get_material(0): return false
	# Indices must be an ordered triangle subsequence; every referenced original
	# vertex retains its exact packed position/normal/UV/tangent/other channels.
	var old_arrays := before.surface_get_arrays(0); var new_arrays := after.surface_get_arrays(0)
	var old_indices: PackedInt32Array = old_arrays[Mesh.ARRAY_INDEX]
	var new_indices: PackedInt32Array = new_arrays[Mesh.ARRAY_INDEX]
	var next := 0
	for start in range(0, old_indices.size(), 3):
		if next < new_indices.size() and old_indices.slice(start, start+3) == new_indices.slice(next, next+3): next += 3
	return next == new_indices.size()

static func _fail(reason: String) -> Dictionary:
	push_error("Harukiya entry retirement: " + reason)
	return {}
