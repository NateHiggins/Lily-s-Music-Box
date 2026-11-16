extends Node
## Diagnostic only: unchanged native fitting source versus new placement.
## No new shop layout, player/NPC passage, commerce/save or art acceptance.
const Seating = preload("res://scripts/building/orison_v2_shop_seating.gd")
const Counter = preload("res://scripts/building/orison_v2_diner_counter.gd")
const Till = preload("res://scripts/building/orison_v2_diner_till.gd")
const Backbar = preload("res://scripts/building/orison_v2_diner_backbar.gd")
const Urns = preload("res://scripts/building/orison_v2_diner_urns.gd")
const Apparatus = preload("res://scripts/building/orison_v2_diner_apparatus.gd")
const Overhead = preload("res://scripts/building/orison_v2_diner_overhead.gd")
const Errors = preload("res://tests/guide_bell_error_capture.gd")
const SOURCE := "res://data/building_layout.json"
const CELL := "res://assets/building/floor_01_cells/shop_luncheonette.gltf"
const MODELS := ["ShopSeating", "DinerCounter", "DinerTill", "DinerBackbar", "DinerUrns", "DinerApparatus", "DinerOverhead"]
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var extracted: Array[Dictionary] = []
var errors: Errors

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})
	if not ok: failures.append(label)
	print("ARCADE CARRIER: ", label, " = ", ok)

func _mount(which: String, cell: Node3D, layout: Dictionary) -> bool:
	match which:
		"ShopSeating": return Seating.mount_cell(cell, layout)
		"DinerCounter": return Counter.mount_cell(cell, layout)
		"DinerTill": return Till.mount_cell(cell, layout)
		"DinerBackbar": return Backbar.mount_cell(cell, layout)
		"DinerUrns": return Urns.mount_cell(cell, layout)
		"DinerApparatus": return Apparatus.mount_cell(cell, layout)
		"DinerOverhead": return Overhead.mount_cell(cell, layout)
	return false

func _new_carrier() -> Node3D:
	var packed: PackedScene = load(CELL) as PackedScene
	if packed == null: return null
	var cell: Node3D = packed.instantiate() as Node3D
	if cell != null: cell.name = "shop_luncheonette"
	return cell

func _run() -> void:
	RealityState.persistence_enabled = false
	errors = Errors.new()
	OS.add_logger(errors)
	var before := FileAccess.get_sha256(SOURCE)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var carrier: Node3D = _new_carrier()
	_check(carrier != null and not carrier.is_inside_tree(), "actual source carrier remains outside live physics tree")
	if carrier == null:
		_finish(before)
		return
	for model: String in MODELS:
		_check(_mount(model, carrier, layout), "unchanged exact-source fitting " + model)
		if not failures.is_empty(): break
	if failures.is_empty():
		var target := Node3D.new()
		target.name = "NativeStockOnly"
		add_child(target)
		# A declared quarter-turn fixture tests placement without modifying mesh
		# coordinates. It is not a proposed installed arcade destination.
		target.basis = Basis(Vector3.UP, PI / 2.0)
		for model_name: String in MODELS:
			var model: Node3D = carrier.get_node_or_null(NodePath(model_name)) as Node3D
			_check(model != null, "explicit validated model exists " + model_name)
			if model == null: continue
			var removed: Dictionary = model.get_meta("removed_triangles", {})
			var native_draws := model.find_children("*", "MeshInstance3D", true, false)
			var meshes: Array = []
			for draw: MeshInstance3D in native_draws:
				meshes.append({"node": draw, "mesh": draw.mesh, "pose": draw.transform})
			_check(not removed.is_empty() and not meshes.is_empty(), "native model carries actual source-removal evidence " + model_name)
			# Old raw-mesh Node references belong to the disposable source carrier.
			# Capture its removal counts, then do not retain those dead references.
			if model.has_meta("original_meshes"): model.remove_meta("original_meshes")
			carrier.remove_child(model)
			target.add_child(model)
			var intact := true
			for row: Dictionary in meshes:
				intact = intact and row.node.mesh == row.mesh and row.node.transform == row.pose
			_check(intact, "rigid parent placement retains native buffers and local poses " + model_name)
			extracted.append({"model": model_name, "draws": meshes.size(), "removed_source_triangles": removed})
		var seat_ids: Array[String] = []
		var pattern := RegEx.create_from_string("stool([0-9]+)")
		for draw: MeshInstance3D in target.get_node("ShopSeating").find_children("*", "MeshInstance3D", true, false):
			var match_result := pattern.search(str(draw.name))
			if match_result != null and match_result.get_string(1) not in seat_ids:
				seat_ids.append(match_result.get_string(1))
		seat_ids.sort()
		_check(seat_ids == ["2", "4", "6"], "only the three owner-approved diner stools survive extraction")
		carrier.free()
		_check(not is_instance_valid(carrier), "old shell and its collision carrier are destroyed")
		_check(target.get_child_count() == MODELS.size(), "published test tree contains only explicit native models")
		await get_tree().physics_frame
		target.queue_free()
		await get_tree().process_frame
	else:
		carrier.free()
	# Real malformed-source negative: a relocated counter rectangle must not
	# masquerade as the historical source consumed by the unchanged native fit.
	var bad: Dictionary = layout.duplicate(true)
	for floor: Dictionary in bad.floors:
		if floor.id != "F01": continue
		for row: Dictionary in floor.furniture:
			if row.id == "storm_shop_luncheonette_counter_top": row.rect[0] += .1
	var negative: Node3D = _new_carrier()
	_check(negative != null and not Counter.mount_cell(negative, bad), "relocated fake fabrication source is refused")
	if negative != null: negative.free()
	_check(FileAccess.get_sha256(SOURCE) == before, "protected source bytes remain unchanged")
	_check(errors.errors.is_empty(), "engine reports no script or runtime errors")
	_finish(before)

func _finish(before: String) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var result := {"evidence_class": "INERT", "status": "PASS" if failures.is_empty() else "FAIL",
			"scope": "Actual unchanged source-fitting carrier and explicit native extraction diagnostic. No complete room fit, routes, dynamic controls, purchase/save, residency replay, rendering or artistic acceptance.",
			"fabrication_source_sha256": before, "cell_asset": CELL,
			"models": extracted, "checks": checks, "failures": failures,
			"engine_errors": errors.errors}
		FileAccess.open(output.path_join("diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("ARCADE CARRIER SUMMARY: ", checks.size(), " checks; ", failures.size(), " failures")
	OS.remove_logger(errors)
	get_tree().quit(0 if failures.is_empty() else 1)
