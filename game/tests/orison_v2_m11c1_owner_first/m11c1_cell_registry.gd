extends Node3D
## Explicit-ID registry for disposable owner-first cell instances. It never
## classifies a node by name, bounds, centroid, connected component, or world
## position. The source-owned descriptor determines the cell before loading.

const Support := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd")

var _descriptors := {}
var _mounted := {}
var _active := {}
var _load_rows: Array[Dictionary] = []


func configure(descriptors_by_id: Dictionary) -> bool:
	if is_inside_tree() or not _descriptors.is_empty():
		return false
	_descriptors = descriptors_by_id.duplicate(true)
	return true


func mount_cell(cell_id: String, allow_raw_diagnostic := true) -> Dictionary:
	if not _descriptors.has(cell_id):
		return {"ok":false, "cell_id":cell_id,
				"error":"cell is not in the explicit descriptor registry"}
	if _mounted.has(cell_id):
		return {"ok":false, "cell_id":cell_id,
				"error":"cell is already mounted"}
	var loaded := Support.instantiate_cell(_descriptors[cell_id],
			allow_raw_diagnostic)
	var row := {
		"cell_id": cell_id,
		"resource_path": str((_descriptors[cell_id] as Dictionary).get(
				"resource_path", "")),
		"gltf_path": str((_descriptors[cell_id] as Dictionary).get(
				"gltf_path", "")),
		"ok": bool(loaded.get("ok", false)),
		"mode": str(loaded.get("mode", "")),
		"collision_contract_proven": bool(loaded.get(
				"collision_contract_proven", false)),
		"load_ms": float(loaded.get("load_ms", 0.0)),
		"instantiate_ms": float(loaded.get("instantiate_ms", 0.0)),
		"error": str(loaded.get("error", "")),
	}
	if not bool(row.ok):
		_load_rows.append(row)
		return row
	var instance := loaded.get("node") as Node
	if instance == null:
		row.ok = false
		row.error = "loader returned no scene root"
		_load_rows.append(row)
		return row
	instance.name = "OwnerFirst_%s" % cell_id
	instance.set_meta(&"m11c1_owner_cell", cell_id)
	instance.set_meta(&"m11c1_import_mode", row.mode)
	add_child(instance)
	_mounted[cell_id] = instance
	_active[cell_id] = true
	row["instance_id"] = instance.get_instance_id()
	_load_rows.append(row)
	return row


func mount_cells(cell_ids: Array[String],
		allow_raw_diagnostic := true) -> Dictionary:
	var rows: Array[Dictionary] = []
	var ok := true
	for cell_id: String in cell_ids:
		var row := mount_cell(cell_id, allow_raw_diagnostic)
		rows.append(row)
		ok = ok and bool(row.get("ok", false))
	return {"ok":ok, "cell_ids":cell_ids.duplicate(), "loads":rows}


func instance_for_cell(cell_id: String) -> Node:
	return _mounted.get(cell_id) as Node


func active_instance_for_cell(cell_id: String) -> Node:
	return _mounted.get(cell_id) as Node if _active.has(cell_id) else null


func mounted_cell_ids() -> Array[String]:
	var result: Array[String] = []
	for cell_id: Variant in _mounted:
		result.append(str(cell_id))
	result.sort()
	return result


func active_cell_ids() -> Array[String]:
	var result: Array[String] = []
	for cell_id: Variant in _active:
		result.append(str(cell_id))
	result.sort()
	return result


func set_visible_cells(cell_ids: Array[String]) -> Dictionary:
	var requested := {}
	for cell_id: String in cell_ids:
		requested[cell_id] = true
	var rows: Array[Dictionary] = []
	_active.clear()
	for raw_id: Variant in _mounted:
		var cell_id := str(raw_id)
		var instance := _mounted[cell_id] as Node
		var visible := requested.has(cell_id)
		if visible:
			_active[cell_id] = true
		if instance is Node3D:
			(instance as Node3D).visible = visible
		rows.append({"cell_id":cell_id, "visible":visible})
	return {"requested":cell_ids.duplicate(), "cells":rows,
			"active_index_ids":active_cell_ids(),
			"explicit_id_lookup":true, "node_scan":false,
			"spatial_classification":false,
			"visibility_changes_collision":false,
			"collision_residency_requires_mount_or_teardown":true}


func all_imported_for_collision() -> bool:
	for row: Dictionary in _load_rows:
		if bool(row.get("ok", false)) \
				and not bool(row.get("collision_contract_proven", false)):
			return false
	return not _mounted.is_empty()


func load_rows() -> Array[Dictionary]:
	return _load_rows.duplicate(true)


func public_teardown() -> Dictionary:
	var queued_ids: Array[int] = []
	for raw_id: Variant in _mounted:
		var instance := _mounted[raw_id] as Node
		if is_instance_valid(instance):
			queued_ids.append(instance.get_instance_id())
			instance.queue_free()
	_mounted.clear()
	_active.clear()
	_load_rows.clear()
	_descriptors.clear()
	return {
		"api": "M11C1CellRegistry.public_teardown",
		"queued_instance_ids": queued_ids,
		"retained_strong_references": _mounted.size() + _active.size()
				+ _load_rows.size()
				+ _descriptors.size(),
		"node_name_reach_ins": false,
		"spatial_inference": false,
		"forced_object_deletion": false,
	}
