class_name M11C0HarnessSupport
extends RefCounted
## Shared, config-driven support for the disposable runtime and capture tools.

const DEFAULT_CONFIG_CANDIDATES := [
	"res://generated/m11c0_rehearsal_receipt.json",
	"res://m11c0_rehearsal_receipt.json",
	"res://split_receipt.json",
]
const DEFAULT_MANIFEST_CANDIDATES := [
	"res://generated/m11c0_partition_manifest.json",
	"res://m11c0_partition_manifest.json",
	"res://partition_manifest.json",
]


static func load_inputs() -> Dictionary:
	var config_path := _find_input("M11C0_CONFIG", DEFAULT_CONFIG_CANDIDATES)
	var manifest_path := _find_input("M11C0_MANIFEST",
			DEFAULT_MANIFEST_CANDIDATES)
	var errors: Array[String] = []
	var config := _load_json_dictionary(config_path, errors, "split receipt")
	var manifest := _load_json_dictionary(manifest_path, errors,
			"partition manifest")
	var cells := _cell_descriptors(config, manifest)
	if cells.is_empty():
		errors.append("no compact cell scene paths resolved from the split receipt")
	var original_path := _original_scene_path(config)
	if original_path.is_empty():
		errors.append("the split receipt does not identify the copied original scene")
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"config_path": config_path,
		"manifest_path": manifest_path,
		"config": config,
		"manifest": manifest,
		"cells": cells,
		"original_scene_path": original_path,
		"config_sha256": file_sha256(config_path),
		"manifest_sha256": file_sha256(manifest_path),
	}


static func _find_input(environment_name: String,
		candidates: Array) -> String:
	var explicit := OS.get_environment(environment_name).strip_edges()
	if not explicit.is_empty():
		return explicit
	for raw_candidate: Variant in candidates:
		var candidate := str(raw_candidate)
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


static func _load_json_dictionary(path: String, errors: Array[String],
		label: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		errors.append("%s is missing: %s" % [label, path])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		errors.append("%s is not a JSON object: %s" % [label, path])
		return {}
	return parsed as Dictionary


static func _cell_descriptors(config: Dictionary,
		manifest: Dictionary) -> Array[Dictionary]:
	var raw_cells: Variant = config.get("cells", [])
	if raw_cells is not Array:
		var outputs: Variant = config.get("outputs", {})
		if outputs is Dictionary:
			raw_cells = outputs.get("cells", [])
	if raw_cells is not Array:
		raw_cells = []
	var result: Array[Dictionary] = []
	for raw: Variant in raw_cells:
		if raw is not Dictionary:
			continue
		var entry := raw as Dictionary
		var cell_id := str(entry.get("id", entry.get("cell_id", "")))
		var path := str(entry.get("scene_path", entry.get("resource_path",
				entry.get("gltf_path", entry.get("gltf",
				entry.get("path", ""))))))
		path = resource_path(path)
		if not cell_id.is_empty() and not path.is_empty():
			result.append({
				"id": cell_id,
				"slug": str(entry.get("slug", cell_id.to_lower())),
				"scene_path": path,
				"source_record": entry.duplicate(true),
			})
	if not result.is_empty():
		return result
	# Tolerant fallback for splitters that emit only the authored manifest.
	# This is path discovery, never an ownership inference.
	for raw: Variant in manifest.get("cells", []):
		if raw is not Dictionary:
			continue
		var entry := raw as Dictionary
		var cell_id := str(entry.get("id", ""))
		var slug := str(entry.get("slug", cell_id.to_lower()))
		var candidates := [
			"res://cells/%s.gltf" % slug,
			"res://cells/%s.tscn" % slug,
			"res://generated/cells/%s.gltf" % slug,
			"res://generated/cells/%s.tscn" % slug,
		]
		for candidate: String in candidates:
			if ResourceLoader.exists(candidate, "PackedScene"):
				result.append({"id":cell_id, "slug":slug,
						"scene_path":candidate, "source_record":entry.duplicate(true)})
				break
	return result


static func _original_scene_path(config: Dictionary) -> String:
	var path := str(config.get("original_scene_path",
			config.get("source_scene_path", "")))
	if path.is_empty():
		var source: Variant = config.get("source", {})
		if source is Dictionary:
			path = str(source.get("copied_scene_path",
					source.get("scene_path", source.get("gltf_path",
					source.get("gltf", "")))))
	return resource_path(path)


static func resource_path(path: String) -> String:
	var normalized := path.strip_edges().replace("\\", "/")
	if normalized.is_empty() or normalized.begins_with("res://") \
			or normalized.begins_with("user://"):
		return normalized
	if normalized.is_absolute_path():
		return ProjectSettings.localize_path(normalized)
	return "res://" + normalized.trim_prefix("./")


static func load_packed_scene(path: String) -> PackedScene:
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return null
	return ResourceLoader.load(path, "PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE) as PackedScene


static func object_counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(
				Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(
				Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


static func delta(after: Dictionary, before: Dictionary) -> Dictionary:
	return {
		"objects": int(after.get("objects", 0)) - int(before.get("objects", 0)),
		"resources": int(after.get("resources", 0)) \
				- int(before.get("resources", 0)),
		"nodes": int(after.get("nodes", 0)) - int(before.get("nodes", 0)),
		"orphan_nodes": int(after.get("orphan_nodes", 0)) \
				- int(before.get("orphan_nodes", 0)),
	}


static func tree_metrics(root: Node) -> Dictionary:
	var accumulator := {
		"nodes": 0,
		"mesh_instances": 0,
		"unique_mesh_resources": {},
		"mesh_primitives": 0,
		"render_primitives_estimate": 0,
		"collision_objects": 0,
		"collision_shapes": 0,
		"lights": 0,
		"aabb_valid": false,
		"aabb_min": Vector3.ZERO,
		"aabb_max": Vector3.ZERO,
	}
	_collect_tree_metrics(root, accumulator)
	var unique_mesh_count := (accumulator.unique_mesh_resources as Dictionary).size()
	var result := accumulator.duplicate()
	result.erase("unique_mesh_resources")
	result["unique_mesh_resources"] = unique_mesh_count
	if bool(result.aabb_valid):
		result["aabb_min"] = vector3_array(result.aabb_min)
		result["aabb_max"] = vector3_array(result.aabb_max)
	else:
		result["aabb_min"] = []
		result["aabb_max"] = []
	return result


static func _collect_tree_metrics(node: Node, accumulator: Dictionary) -> void:
	accumulator.nodes = int(accumulator.nodes) + 1
	if node is CollisionObject3D:
		accumulator.collision_objects = int(accumulator.collision_objects) + 1
	if node is CollisionShape3D:
		accumulator.collision_shapes = int(accumulator.collision_shapes) + 1
	if node is Light3D:
		accumulator.lights = int(accumulator.lights) + 1
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		accumulator.mesh_instances = int(accumulator.mesh_instances) + 1
		if mesh_instance.mesh != null:
			(accumulator.unique_mesh_resources as Dictionary)[
					mesh_instance.mesh.get_instance_id()] = true
			accumulator.mesh_primitives = int(accumulator.mesh_primitives) \
					+ mesh_instance.mesh.get_surface_count()
			accumulator.render_primitives_estimate = int(
					accumulator.render_primitives_estimate) \
					+ _mesh_primitive_estimate(mesh_instance.mesh)
			_expand_aabb(mesh_instance, accumulator)
	for child: Node in node.get_children():
		_collect_tree_metrics(child, accumulator)


static func _mesh_primitive_estimate(mesh: Mesh) -> int:
	var total := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var element_count := 0
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices != null:
			element_count = indices.size()
		else:
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			if vertices != null:
				element_count = vertices.size()
		match mesh.surface_get_primitive_type(surface_index):
			Mesh.PRIMITIVE_POINTS:
				total += element_count
			Mesh.PRIMITIVE_LINES:
				total += element_count / 2
			Mesh.PRIMITIVE_LINE_STRIP:
				total += maxi(0, element_count - 1)
			Mesh.PRIMITIVE_TRIANGLES:
				total += element_count / 3
			Mesh.PRIMITIVE_TRIANGLE_STRIP:
				total += maxi(0, element_count - 2)
	return total


static func _expand_aabb(mesh_instance: MeshInstance3D,
		accumulator: Dictionary) -> void:
	var local := mesh_instance.get_aabb()
	var transform := mesh_instance.global_transform
	for corner_index in 8:
		var corner := local.position + Vector3(
				local.size.x if (corner_index & 1) != 0 else 0.0,
				local.size.y if (corner_index & 2) != 0 else 0.0,
				local.size.z if (corner_index & 4) != 0 else 0.0)
		var point := transform * corner
		if not bool(accumulator.aabb_valid):
			accumulator.aabb_valid = true
			accumulator.aabb_min = point
			accumulator.aabb_max = point
		else:
			accumulator.aabb_min = (accumulator.aabb_min as Vector3).min(point)
			accumulator.aabb_max = (accumulator.aabb_max as Vector3).max(point)


static func seam_probe_specs(config: Dictionary,
		manifest: Dictionary) -> Array[Dictionary]:
	var explicit: Variant = config.get("collision_probes", [])
	var validation: Variant = config.get("validation", {})
	if (explicit is not Array or explicit.is_empty()) and validation is Dictionary:
		explicit = validation.get("collision_probes", [])
	if explicit is not Array or explicit.is_empty():
		explicit = manifest.get("collision_probes", [])
	if explicit is not Array:
		explicit = []
	var by_seam := {}
	for raw: Variant in explicit:
		if raw is Dictionary:
			var seam_id := str(raw.get("seam_id", ""))
			if not by_seam.has(seam_id):
				by_seam[seam_id] = []
			(by_seam[seam_id] as Array).append((raw as Dictionary).duplicate(true))
	var result: Array[Dictionary] = []
	for raw: Variant in manifest.get("shared_boundaries", []):
		if raw is not Dictionary:
			continue
		var seam := raw as Dictionary
		var seam_id := str(seam.get("id", ""))
		result.append({
			"seam_id": seam_id,
			"owner": str(seam.get("owner", "")),
			"counterpart": str(seam.get("counterpart", "")),
			"probes": by_seam.get(seam_id, []),
			"manifest_record": seam.duplicate(true),
		})
	for seam_id: Variant in by_seam:
		var already_present := false
		for existing: Dictionary in result:
			if str(existing.seam_id) == str(seam_id):
				already_present = true
				break
		if not already_present:
			result.append({"seam_id":str(seam_id), "owner":"",
					"counterpart":"", "probes":by_seam[seam_id],
					"manifest_record":{}})
	return result


static func vector3(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", NAN)), float(value.get("y", NAN)),
				float(value.get("z", NAN)))
	return Vector3(NAN, NAN, NAN)


static func vector3_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func file_sha256(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return context.finish().hex_encode()


static func write_json(path: String, payload: Dictionary) -> bool:
	var absolute := path
	if path.begins_with("res://") or path.begins_with("user://"):
		absolute = ProjectSettings.globalize_path(path)
	var directory := absolute.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	return true
