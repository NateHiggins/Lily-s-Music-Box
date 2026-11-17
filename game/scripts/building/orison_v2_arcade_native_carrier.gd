extends RefCounted
## Native fittings only. Fabrication is validated in the original detached
## carrier before this seam. Startup and residency reload must use this same
## projection. The detached donor retains raw stock/architecture for explicit
## disposition; this helper never silently discards that remaining content.
var errors: Array[String] = []

func _refuse(message: String) -> Node3D:
	errors.append(message)
	return null

func _hash_lf(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()

func _matrix(value: Variant) -> Transform3D:
	if value is not Array or value.size() != 4:
		return Transform3D(Basis.IDENTITY, Vector3.INF)
	for row in value:
		if row is not Array or row.size() != 4:
			return Transform3D(Basis.IDENTITY, Vector3.INF)
		for number in row:
			if not (number is float or number is int) or not is_finite(float(number)):
				return Transform3D(Basis.IDENTITY, Vector3.INF)
	if float(value[3][0]) != 0.0 or float(value[3][1]) != 0.0 or float(value[3][2]) != 0.0 or float(value[3][3]) != 1.0:
		return Transform3D(Basis.IDENTITY, Vector3.INF)
	return Transform3D(Basis(Vector3(value[0][0], value[1][0], value[2][0]),
		Vector3(value[0][1], value[1][1], value[2][1]), Vector3(value[0][2], value[1][2], value[2][2])),
		Vector3(value[0][3], value[1][3], value[2][3]))

func _same(a: Transform3D, b: Transform3D) -> bool:
	return a.is_finite() and b.is_finite() and a.origin.distance_to(b.origin) < 0.00001 \
		and a.basis.x.distance_to(b.basis.x) < 0.00001 and a.basis.y.distance_to(b.basis.y) < 0.00001 \
		and a.basis.z.distance_to(b.basis.z) < 0.00001

func _point(value: Variant) -> Vector3:
	if value is not Array or value.size() != 3:
		return Vector3.INF
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)):
			return Vector3.INF
	return Vector3(value[0], value[1], value[2])

func _rigid(pose: Transform3D) -> bool:
	return pose.is_finite() and _same(Transform3D(pose.basis, Vector3.ZERO),
		Transform3D(pose.basis.orthonormalized(), Vector3.ZERO)) and absf(pose.basis.determinant() - 1.0) < 0.00001

func _relative(node: Node3D, root: Node3D) -> Transform3D:
	# Global transforms are invalid before entering a SceneTree. Compose actual
	# local ancestors instead, including every imported native-node frame once.
	var pose := node.transform
	var parent := node.get_parent()
	while parent != root:
		if parent is not Node3D:
			return Transform3D(Basis.IDENTITY, Vector3.INF)
		pose = (parent as Node3D).transform * pose
		parent = parent.get_parent()
	return pose

func _node_reference(value: Variant) -> bool:
	if value is Object:
		return value is not Resource
	if value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key in value:
			if _node_reference(key) or _node_reference(value[key]):
				return true
	elif value is Array:
		for entry in value:
			if _node_reference(entry):
				return true
	return false

func _passive(node: Node) -> bool:
	if node.get_script() != null:
		return false
	for key in node.get_meta_list():
		if _node_reference(node.get_meta(key)):
			return false
	for child in node.get_children():
		if not _passive(child):
			return false
	return true

func _clear_scene_owners(node: Node) -> void:
	# Scene serialization ownership is not an inventory/service authority.
	# No serialized owner may point back to a subsequently freed donor.
	node.owner = null
	for child in node.get_children():
		_clear_scene_owners(child)

func extract_native(donor: Node3D, contract: Dictionary) -> Node3D:
	errors.clear()
	if donor == null or donor.is_inside_tree() or donor.get_parent() != null:
		return _refuse("original fitting carrier must be detached")
	if donor.has_meta("arcade_native_extracted") or not _same(donor.transform, Transform3D.IDENTITY):
		return _refuse("fresh original identity-frame carrier required")
	if int(contract.get("schema_version", 0)) != 1 or str(contract.get("cell", "")) != str(donor.name):
		return _refuse("projection/cell identity mismatch")
	var fabrication := str(contract.get("fabrication_source", ""))
	var cell_source := str(contract.get("cell_source", ""))
	if not fabrication.begins_with("res://") or not cell_source.begins_with("res://") \
		or not FileAccess.file_exists(fabrication) or not FileAccess.file_exists(cell_source):
		return _refuse("missing fabrication/carrier source")
	if _hash_lf(fabrication) != str(contract.get("fabrication_sha256_lf", "")) \
		or _hash_lf(cell_source) != str(contract.get("cell_source_sha256_lf", "")):
		return _refuse("fabrication/carrier source changed")
	var assets: Dictionary = contract.get("native_assets", {})
	if assets.is_empty():
		return _refuse("native asset bindings required")
	for path: String in assets:
		if not path.begins_with("res://") or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(assets[path]):
			return _refuse("native source changed: " + path)
	var bindings: Dictionary = contract.get("source_bindings", {})
	if bindings.is_empty():
		return _refuse("native recipe/owner bindings required")
	for path: String in bindings:
		var binding: Dictionary = bindings[path]
		var kind := str(binding.get("kind", ""))
		if kind not in ["lf", "raw"] or not path.begins_with("res://") or not FileAccess.file_exists(path):
			return _refuse("native recipe/owner changed: " + path)
		var digest := _hash_lf(path) if kind == "lf" else FileAccess.get_sha256(path)
		if digest != str(binding.get("sha256", "")):
			return _refuse("native recipe/owner changed: " + path)
	var models := {}
	var required := {}
	var required_labels := {}
	for row: Dictionary in contract.get("models", []):
		var identity := str(row.get("name", ""))
		var metadata := str(row.get("part_meta", ""))
		var model := donor.get_node_or_null(NodePath(identity)) as Node3D
		if identity.is_empty() or identity.contains("/") or metadata.is_empty() or model == null or models.has(identity):
			return _refuse("missing/duplicate native model: " + identity)
		if model.get_script() != null:
			return _refuse("native model has an untransferred controller: " + identity)
		models[identity] = {"node": model, "part_meta": metadata}
		for node in model.find_children("*", "Node", true, false):
			if node.get_script() != null:
				return _refuse("native descendant has an untransferred controller: " + identity + "/" + str(node.name))
			if node is Label3D:
				var label_key := identity + "/" + str(node.name)
				if required_labels.has(label_key):
					return _refuse("duplicate authored label: " + label_key)
				required_labels[label_key] = node
			if node is MeshInstance3D:
				var part := str(node.get_meta(metadata, ""))
				var key := identity + "/" + part
				if part.is_empty() or required.has(key):
					return _refuse("missing/duplicate native part identity: " + key)
				required[key] = node
	if required.is_empty():
		return _refuse("empty native inventory")
	# Detect an unlisted native owner, rather than publishing a partial room.
	for node: MeshInstance3D in donor.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("material_key") and not node in required.values():
			return _refuse("unaccounted native fitting: " + str(node.name))
	var transfers: Array[Dictionary] = []
	var seen := {}
	var names := {}
	for row: Dictionary in contract.get("entries", []):
		var model_id := str(row.get("model", ""))
		var key := model_id + "/" + str(row.get("part_id", ""))
		var target_name := str(row.get("target_name", ""))
		if not required.has(key) or seen.has(key) or not models.has(model_id) or str(row.get("part_meta", "")) != str(models[model_id].part_meta):
			return _refuse("unknown/duplicate projected part: " + key)
		if target_name.is_empty() or target_name.contains("/") or names.has(target_name):
			return _refuse("missing/duplicate published name: " + target_name)
		var draw := required[key] as MeshInstance3D
		if draw.mesh == null or draw.mesh.get_faces().size() != int(row.get("triangles", -1)) * 3 or not _passive(draw):
			return _refuse("changed/active native geometry or donor reference: " + key)
		var original := _matrix(row.get("source_transform"))
		var delta := _matrix(row.get("delta_transform"))
		var wanted := _matrix(row.get("target_transform"))
		if not _same(_relative(draw, donor), original) or not _rigid(delta) or not _same(delta * original, wanted):
			return _refuse("source/placement frame mismatch: " + key)
		seen[key] = true
		names[target_name] = true
		transfers.append({"node": draw, "target": wanted, "name": target_name, "identity": key})
	if seen.size() != required.size():
		return _refuse("incomplete native projection")
	var seen_labels := {}
	for row: Dictionary in contract.get("labels", []):
		var key := str(row.get("model", "")) + "/" + str(row.get("node_name", ""))
		var target_name := str(row.get("target_name", ""))
		if not required_labels.has(key) or seen_labels.has(key) or str(row.get("node_name", "")) != "Words_" + str(row.get("label_id", "")):
			return _refuse("unknown/duplicate authored label: " + key)
		var words := required_labels[key] as Label3D
		if words.text != str(row.get("text", "")) or not _passive(words):
			return _refuse("authored label content/controller changed: " + key)
		if target_name.is_empty() or target_name.contains("/") or names.has(target_name):
			return _refuse("missing/duplicate published label name: " + target_name)
		var original := _matrix(row.get("source_transform"))
		var delta := _matrix(row.get("delta_transform"))
		var wanted := _matrix(row.get("target_transform"))
		if not _same(_relative(words, donor), original) or not _rigid(delta) or not _same(delta * original, wanted):
			return _refuse("authored label source/placement frame mismatch: " + key)
		seen_labels[key] = true
		names[target_name] = true
		transfers.append({"node": words, "target": wanted, "name": target_name, "identity": key})
	if seen_labels.size() != required_labels.size():
		return _refuse("incomplete authored label projection")
	# Mutation begins only after the complete inventory and every frame pass.
	var target := Node3D.new()
	target.name = donor.name
	for row in transfers:
		var draw := row.node as Node3D
		_clear_scene_owners(draw)
		draw.get_parent().remove_child(draw)
		draw.name = row.name
		target.add_child(draw)
		draw.transform = row.target
		draw.set_meta("arcade_native_identity", row.identity)
	donor.set_meta("arcade_native_extracted", true)
	target.set_meta("arcade_native_projection", true)
	target.set_meta("fabrication_sha256_lf", str(contract.fabrication_sha256_lf))
	return target

func _raw_slice(draw: MeshInstance3D, donor: Node3D, row: Dictionary, used: Dictionary) -> Dictionary:
	var original := draw.mesh as ArrayMesh
	if original == null or original.get_blend_shape_count() != 0:
		return {"error": "raw stock requires static imported ArrayMesh"}
	var low: Array = row.source_low
	var high: Array = row.source_high
	var bottom := Vector3(low[0], low[1], low[2])
	var top := Vector3(high[0], high[1], high[2])
	var frame := _relative(draw, donor)
	var normals := frame.basis.inverse().transposed()
	var serialized: Array = original.get("_surfaces")
	var selected: Array = []
	var surface_sources: Array[int] = []
	var count := 0
	var bounds := AABB()
	var first := true
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var vertex_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if vertex_normals.size() != vertices.size() or indices.is_empty():
			return {"error": "raw source must retain indexed geometry and normals"}
		var retained := PackedInt32Array()
		for start in range(0, indices.size(), 3):
			var points: Array[Vector3] = []
			var normal := Vector3.ZERO
			for corner in 3:
				points.append(frame * vertices[indices[start + corner]])
				normal += normals * vertex_normals[indices[start + corner]]
			if normal.length_squared() < .5:
				return {"error": "invalid raw source normal"}
			normal = normal.normalized()
			var a := points[0].min(points[1]).min(points[2])
			var b := points[0].max(points[1]).max(points[2])
			if a.x < bottom.x - .00002 or a.y < bottom.y - .00002 or a.z < bottom.z - .00002 \
				or b.x > top.x + .00002 or b.y > top.y + .00002 or b.z > top.z + .00002:
				continue
			var axis := normal.abs().max_axis_index()
			if absf(normal[axis]) < .999:
				continue
			var plane := top[axis] if normal[axis] > 0.0 else bottom[axis]
			if absf(points[0][axis] - plane) > .00002 or absf(points[1][axis] - plane) > .00002 or absf(points[2][axis] - plane) > .00002:
				continue
			var identity := "%d/%d/%d" % [draw.get_instance_id(), surface, start / 3]
			if used.has(identity):
				return {"error": "ambiguous raw source triangle: " + identity}
			used[identity] = str(row.id)
			for corner in 3:
				var index := indices[start + corner]
				retained.append(index)
				bounds = AABB(vertices[index], Vector3.ZERO) if first else bounds.expand(vertices[index])
				first = false
			count += 1
		if retained.is_empty():
			continue
		var packed: Dictionary = serialized[surface].duplicate(true)
		var width: int = packed.index_data.size() / int(packed.index_count)
		if width != 2 and width != 4:
			return {"error": "unsupported raw source index encoding"}
		var bytes := PackedByteArray()
		bytes.resize(retained.size() * width)
		for index in retained.size():
			if width == 2: bytes.encode_u16(index * width, retained[index])
			else: bytes.encode_u32(index * width, retained[index])
		packed.index_data = bytes
		packed.index_count = retained.size()
		packed.lods = {} # Original LODs would resurrect unrelated donor triangles.
		selected.append(packed)
		surface_sources.append(surface)
	if count == 0:
		return {"triangles": 0}
	var mesh := preload("res://scripts/building/orison_v2_shop_seating.gd")._copy_native_mesh(original, selected)
	# Preserve packed decoding AABBs/buffers. Only the separate culling override
	# can narrow; replacing a packed AABB would reinterpret compressed vertices.
	mesh.custom_aabb = bounds
	mesh.shadow_mesh = null # The old optimized shadow contains unrelated stock.
	var copy := MeshInstance3D.new()
	copy.name = draw.name
	copy.mesh = mesh
	copy.material_override = draw.material_override
	for surface in surface_sources.size():
		copy.set_surface_override_material(surface, draw.get_surface_override_material(surface_sources[surface]))
	copy.set_meta("material_key", str(row.source_record.mat))
	copy.set_meta("arcade_raw_stock", str(row.id))
	copy.set_meta("arcade_raw_source_path", str(donor.get_path_to(draw)))
	copy.set_meta("arcade_raw_source_surfaces", surface_sources)
	copy.transform = _matrix(row.delta_transform) * frame
	copy.create_trimesh_collision()
	return {"triangles": count, "node": copy}

func extract_raw(donor: Node3D, contract: Dictionary) -> Node3D:
	errors.clear()
	if donor == null or donor.is_inside_tree() or donor.get_parent() != null or not donor.has_meta("arcade_native_extracted") \
		or donor.has_meta("arcade_raw_extracted") or not _same(donor.transform, Transform3D.IDENTITY):
		return _refuse("detached native-extracted donor required for raw custody")
	var source := str(contract.fabrication_source)
	if _hash_lf(source) != str(contract.fabrication_sha256_lf) or _hash_lf(str(contract.cell_source)) != str(contract.cell_source_sha256_lf):
		return _refuse("raw fabrication source changed")
	for path: String in contract.source_bindings:
		var binding: Dictionary = contract.source_bindings[path]
		var kind := str(binding.get("kind", ""))
		if kind not in ["raw", "lf"] or not path.begins_with("res://") or not FileAccess.file_exists(path):
			return _refuse("raw input binding invalid: " + path)
		var digest := _hash_lf(path) if kind == "lf" else FileAccess.get_sha256(path)
		if digest != str(binding.sha256):
			return _refuse("raw input changed: " + path)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var records := {}
	for floor: Dictionary in layout.floors:
		if str(floor.id) == "F01":
			for item: Dictionary in floor.furniture: records[str(item.id)] = item
	var target := Node3D.new()
	target.name = "ArcadeRetainedRawStock"
	var used := {}
	var seen := {}
	var total := 0
	var required := {}
	for identity in contract.get("raw_stock_ids", []):
		if required.has(str(identity)):
			target.free()
			return _refuse("duplicate required raw identity")
		required[str(identity)] = true
	for row: Dictionary in contract.get("raw_stocks", []):
		var identity := str(row.get("id", ""))
		var delta := _matrix(row.get("delta_transform"))
		if identity.is_empty() or not required.has(identity) or seen.has(identity) or not records.has(identity) or records[identity] != row.get("source_record") or not _rigid(delta):
			target.free()
			return _refuse("raw stock identity/source/frame mismatch: " + identity)
		var item: Dictionary = records[identity]
		var rect: Array = item.rect
		var low := Vector3(rect[0], item.z0, -float(rect[3]))
		var high := Vector3(rect[2], float(item.z0) + float(item.h), -float(rect[1]))
		var transformed := delta * AABB(low, high - low)
		if not _point(row.get("source_low")).is_finite() or not _point(row.get("source_high")).is_finite() \
			or not _point(row.get("target_low")).is_finite() or not _point(row.get("target_high")).is_finite() \
			or _point(row.source_low).distance_to(low) > 0.00001 or _point(row.source_high).distance_to(high) > 0.00001 \
			or _point(row.target_low).distance_to(transformed.position) > 0.00001 or _point(row.target_high).distance_to(transformed.end) > 0.00001:
			target.free()
			return _refuse("raw stock bounds/frame mismatch: " + identity)
		seen[identity] = true
		var group := Node3D.new()
		group.name = identity
		target.add_child(group)
		var count := 0
		for draw: MeshInstance3D in donor.find_children("*", "MeshInstance3D", true, false):
			var result := _raw_slice(draw, donor, row, used)
			if result.has("error"):
				target.free()
				return _refuse(str(result.error))
			count += int(result.triangles)
			if result.has("node"): group.add_child(result.node)
		if count != int(row.get("expected_triangles", -1)) or count == 0:
			target.free()
			return _refuse("raw stock triangle custody mismatch: %s (%d/%d)" % [identity, count, int(row.get("expected_triangles", -1))])
		total += count
	if seen.is_empty() or seen.size() != required.size():
		target.free()
		return _refuse("empty/incomplete raw stock inventory")
	donor.set_meta("arcade_raw_extracted", true)
	target.set_meta("retained_source_triangles", total)
	return target
