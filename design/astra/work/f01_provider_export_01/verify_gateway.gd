extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _fingerprints(scene: PackedScene, filtered: bool) -> Dictionary:
	var instance: Node3D = scene.instantiate()
	root.add_child(instance)
	var result := {}
	for node: Node in instance.find_children("*", "Node3D", true, false):
		var path := str(instance.get_path_to(node))
		if filtered and not path.begins_with("F01_OWN_STREET_retail_passage_proxy_"):
			continue
		var row := {"class": node.get_class(), "transform": str(node.global_transform)}
		if node is MeshInstance3D:
			var surfaces := []
			for index in node.mesh.get_surface_count():
				var bytes := var_to_bytes(node.mesh.surface_get_arrays(index))
				var hash_context := HashingContext.new()
				hash_context.start(HashingContext.HASH_SHA256)
				hash_context.update(bytes)
				var material: Material = node.get_active_material(index)
				var texture := ""
				if material is BaseMaterial3D and material.albedo_texture != null:
					texture = material.albedo_texture.resource_path
				surfaces.append({"arrays_sha256": hash_context.finish().hex_encode(),
					"texture": texture, "material": material.resource_name if material else ""})
			row["surfaces"] = surfaces
		if node is CollisionShape3D:
			row["shape"] = node.shape.get_class()
			if node.shape is ConcavePolygonShape3D:
				row["faces"] = str(node.shape.get_faces())
		result[path] = row
	instance.free()
	return result

func _verify() -> void:
	var source: PackedScene = load("res://assets/building/floor_01_cells/site_street_common.gltf")
	var gateway: PackedScene = load("res://assets/building/orison_v2/exterior/passage_gateway.gltf")
	if source == null or gateway == null:
		push_error("Gateway imported scene missing")
		quit(1)
		return
	var expected := _fingerprints(source, true)
	var actual := _fingerprints(gateway, false)
	var failures: Array[String] = []
	for key: String in expected:
		if expected[key] != actual.get(key):
			failures.append("imported geometry/material/collision mismatch: " + key)
	for key: String in actual:
		if not expected.has(key):
			failures.append("unexpected imported node: " + key)
	if expected.is_empty():
		failures.append("source selection empty")
	print("GATEWAY_PARITY ", JSON.stringify({"expected_nodes": expected.size(),
		"actual_nodes": actual.size(), "failures": failures}))
	quit(failures.size())
