class_name M11C0CellComposition
extends Node3D
## Public lifecycle boundary used by both rehearsal instruments. Compact glTF
## scenes deliberately receive no test script and no production authority.
## This wrapper owns mounting and deterministic teardown without node-name
## reach-ins or forced ObjectDB deletion.

var _mounted: Array[Node] = []
var _cell_ids: Array[String] = []


func mount_packed(cell_id: String, packed: PackedScene) -> Node:
	if cell_id.is_empty() or packed == null:
		return null
	var instance := packed.instantiate()
	if instance == null:
		return null
	instance.set_meta(&"m11c0_cell_id", cell_id)
	add_child(instance)
	_mounted.append(instance)
	_cell_ids.append(cell_id)
	return instance


func mounted_cell_ids() -> Array[String]:
	return _cell_ids.duplicate()


func public_teardown() -> Dictionary:
	var released_instance_ids: Array[int] = []
	for mounted: Node in _mounted:
		if is_instance_valid(mounted):
			released_instance_ids.append(mounted.get_instance_id())
			mounted.queue_free()
	_mounted.clear()
	_cell_ids.clear()
	return {
		"api": "M11C0CellComposition.public_teardown",
		"queued_instance_ids": released_instance_ids,
		"retained_strong_references": _mounted.size() + _cell_ids.size(),
		"node_name_reach_ins": false,
		"forced_object_deletion": false,
	}
