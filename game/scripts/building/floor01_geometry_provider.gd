extends RefCounted
## Scene-owned optional geometry choice. Never stored in RealityState and never
## changes BuildingRootSelector. This initial contract keeps every cell resident.

const Registry := preload("res://scripts/building/floor01_cell_registry.gd")
const LEGACY := "res://assets/building/floor_01.gltf"

var mode := ""
var error := ""
var registry
var _prepared_host: Node3D
var _transferred := false


func prepare(requested_mode: String, registry_path: String, envelope_tokens: Array) -> bool:
	if not mode.is_empty() or requested_mode not in ["legacy", "owner_first_cells"]:
		error = "unknown geometry mode or provider already prepared"
		return false
	mode = requested_mode
	if mode == "legacy":
		var packed := load(LEGACY) as PackedScene
		if packed == null:
			error = "legacy F01 imported scene unavailable"
			return false
		var instance: Node = packed.instantiate()
		if not instance is Node3D:
			if instance != null:
				instance.free()
			error = "legacy F01 root is not spatial"
			return false
		_prepared_host = instance as Node3D
	else:
		registry = Registry.new()
		if not registry.configure(registry_path):
			error = registry.error
			_abort()
			return false
		_prepared_host = Node3D.new()
		if not registry.instantiate_into(_prepared_host, envelope_tokens):
			error = registry.error
			_abort()
			return false
	_prepared_host.name = "F01"
	return true


func take_host() -> Node3D:
	if _transferred or not is_instance_valid(_prepared_host):
		return null
	_transferred = true
	var host := _prepared_host
	_prepared_host = null
	return host


func passage_role(node: GeometryInstance3D) -> String:
	if mode == "owner_first_cells" and registry != null:
		return registry.role_for(node)
	return Registry.passage_role_for_name(str(node.name))


func envelope_targets() -> Array[Node3D]:
	if mode == "owner_first_cells" and registry != null:
		return registry.envelope_targets()
	return []


func alias_targets(alias: String) -> Array[Node3D]:
	if mode == "owner_first_cells" and registry != null:
		return registry.alias_targets(alias)
	return []


func public_census() -> Dictionary:
	return {"mode": mode, "host_transferred": _transferred,
			"registry": registry.public_census() if registry != null else {},
			"streaming_implemented": false, "gameplay_authority_moved": false}


func release_references() -> void:
	# Once transferred, BuildingRoot owns ordinary immediate world destruction.
	# Never queue a second deletion or retain a scene/material after root exit.
	if registry != null:
		registry.release_references()
	registry = null
	if not _transferred and is_instance_valid(_prepared_host):
		_prepared_host.free()
	_prepared_host = null


func _abort() -> void:
	release_references()
