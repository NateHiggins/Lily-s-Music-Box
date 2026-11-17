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
		if str(binding.get("kind", "")) != "lf" or not path.begins_with("res://") \
			or not FileAccess.file_exists(path) or _hash_lf(path) != str(binding.get("sha256", "")):
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
