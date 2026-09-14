extends Node
## Matched, warmed lifecycle control for M11A-A capture accounting.
##
## One windowed process performs the same viewport read/write in three cases:
## a camera-only harness control, one production-cell cycle, then a second
## production-cell cycle. Production cells leave only through their public
## shutdown API. The source-object census records IDs and provenance before
## teardown without retaining the objects it observes.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const CELL_SCENE := preload(
		"res://scenes/building/orison_v2_exterior_cell.tscn")
const RECEIPT_FILE := "m11a_a_capture_lifecycle_receipt.json"
const RECEIPT_ENV := "M11AA_LIFECYCLE_RECEIPT"

var shots = ShotHarnessScript.new()
var _failed := false
var _failure_reasons: Array[String] = []


func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M11A-A-LIFECYCLE", 3):
		get_tree().quit(2)
		return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if DisplayServer.get_name() == "headless":
		_fail("lifecycle control requires the same windowed capture path")
		await _finish({})
		return
	await _settle()
	var process_start := _counts()
	var control := await _run_control_cycle()
	await _settle()
	control["after_teardown"] = _counts()
	control["matlib_cache_after_plateau"] = _matlib_cache_snapshot()
	var control_resource_records := _control_resource_census()
	var control_resource_ids := _resource_id_set(control_resource_records)
	control["resource_id_snapshot_after_plateau"] = _resource_snapshot_summary(
			control_resource_records)
	var first := await _run_module_cycle("module_cycle_1")
	await _settle()
	first["after_teardown"] = _counts()
	var first_census: Array[Dictionary] = first.get(
			"_source_object_census", []) as Array[Dictionary]
	first.erase("_source_object_census")
	var first_retained := _retained_source_objects(first_census)
	first["retained_source_objects"] = first_retained
	first["amplified_retained_objects"] = _amplified_retained_objects(
			first_retained, control_resource_ids)
	first["matlib_cache_after_plateau"] = _matlib_cache_snapshot()
	var second := await _run_module_cycle("module_cycle_2")
	await _settle()
	second["after_teardown"] = _counts()
	var second_census: Array[Dictionary] = second.get(
			"_source_object_census", []) as Array[Dictionary]
	second.erase("_source_object_census")
	var second_retained := _retained_source_objects(second_census)
	second["retained_source_objects"] = second_retained
	second["amplified_retained_objects"] = _amplified_retained_objects(
			second_retained, control_resource_ids)
	second["matlib_cache_after_plateau"] = _matlib_cache_snapshot()
	var control_plateau: Dictionary = control.get("after_teardown", {})
	var first_plateau: Dictionary = first.get("after_teardown", {})
	var second_plateau: Dictionary = second.get("after_teardown", {})
	var first_delta := _delta(first_plateau, control_plateau)
	var second_delta := _delta(second_plateau, control_plateau)
	var second_growth := _delta(second_plateau, first_plateau)
	var first_amplifies := _positive_retention(first_delta)
	var second_amplifies := _positive_retention(second_delta)
	var module_amplifies_control := first_amplifies or second_amplifies
	var identical_plateaus := first_plateau == control_plateau \
			and second_plateau == control_plateau
	var first_cache: Dictionary = first.get("matlib_cache_after_plateau", {})
	var second_cache_before: Dictionary = second.get("matlib_cache_before", {})
	var second_cache: Dictionary = second.get("matlib_cache_after_plateau", {})
	var cache_reused_without_growth := first_cache == second_cache_before \
			and first_cache == second_cache
	var first_live_survivors := _retained_live_object_count(
			first.get("retained_source_objects", []))
	var second_live_survivors := _retained_live_object_count(
			second.get("retained_source_objects", []))
	var first_amplified: Array = first.get("amplified_retained_objects", [])
	var second_amplified: Array = second.get("amplified_retained_objects", [])
	var first_unattributed := _unattributed_count(first_amplified)
	var second_unattributed := _unattributed_count(second_amplified)
	var first_attribution_complete := not first_amplifies \
			or (not first_amplified.is_empty() and first_unattributed == 0)
	var second_attribution_complete := not second_amplifies \
			or (not second_amplified.is_empty() and second_unattributed == 0)
	var attribution_complete := first_attribution_complete \
			and second_attribution_complete
	var receipt := {
		"schema_version": 2,
		"status": "PASS" if not _failed else "FAIL",
		"process": {
			"renderer": RenderingServer.get_current_rendering_method(),
			"display_server": DisplayServer.get_name(),
			"single_process": true,
			"matched_viewport_operations_per_case": 1,
			"process_start_after_harness_settle": process_start,
		},
		"cases": [control, first, second],
		"comparison": {
			"control_plateau": control_plateau,
			"harness_control_delta_from_process_start": _delta(
					control_plateau, process_start),
			"module_cycle_1_delta_from_control": first_delta,
			"module_cycle_2_delta_from_control": second_delta,
			"module_cycle_2_growth_from_cycle_1": second_growth,
			"module_amplifies_control": module_amplifies_control,
			"all_plateaus_identical": identical_plateaus,
			"module_owned_live_object_survivors": {
				"cycle_1": first_live_survivors,
				"cycle_2": second_live_survivors,
			},
			"amplified_retained_attribution": {
				"control_resource_ids": control_resource_ids.size(),
				"cycle_1_objects": first_amplified.size(),
				"cycle_2_objects": second_amplified.size(),
				"cycle_1_unattributed": first_unattributed,
				"cycle_2_unattributed": second_unattributed,
				"cycle_1_retainer_owners": _retainer_owner_counts(
						first_amplified),
				"cycle_2_retainer_owners": _retainer_owner_counts(
						second_amplified),
				"complete": attribution_complete,
			},
			"process_global_material_cache": {
				"owner": "MatLib._cache",
				"cycle_1_after": first_cache,
				"cycle_2_before": second_cache_before,
				"cycle_2_after": second_cache,
				"second_cycle_reuses_exact_resource_ids":
						cache_reused_without_growth,
			},
			"interpretation": "production module leaves only attributed " \
					+ "process-global MatLib and ResourceLoader cache resources and " \
					+ "no module-owned live node/non-resource object; " \
					+ "the second module cycle adds no resource or cache growth" \
					if module_amplifies_control else "both module cycles settle at " \
					+ "or below the warmed harness plateau",
		},
		"diagnostic_boundary": {
			"cleanup": "public OrisonV2ExteriorCell.shutdown_for_tests plus " \
					+ "ordinary queued owner disposal",
			"node_name_reach_ins": false,
			"forced_object_deletion": false,
			"tracked_source_objects_are_held_by_instance_id_only": true,
		},
		"failures": _failure_reasons,
	}
	if first_amplifies and first_amplified.is_empty():
		_fail("cycle 1 amplifies the control without an attributable source object")
	if second_amplifies and second_amplified.is_empty():
		_fail("cycle 2 amplifies the control without an attributable source object")
	if module_amplifies_control and not attribution_complete:
		_fail("module amplification includes a retained object/resource without an actual current retainer")
	if _positive_retention(second_growth):
		_fail("the second production-cell cycle grows beyond the first plateau")
	if first_live_survivors != 0 or second_live_survivors != 0:
		_fail("a module-owned node/object survived public teardown")
	if not cache_reused_without_growth:
		_fail("the second cycle did not reuse the exact process-global cache")
	receipt["status"] = "PASS" if not _failed else "FAIL"
	receipt["failures"] = _failure_reasons
	await _finish(receipt)


func _run_control_cycle() -> Dictionary:
	var matlib_before := _matlib_cache_snapshot()
	var root := Node3D.new()
	root.name = "CaptureHarnessControlRoot"
	var camera := Camera3D.new()
	camera.name = "CaptureHarnessControlCamera"
	root.add_child(camera)
	add_child(root)
	camera.make_current()
	await _settle()
	var before_capture := _counts()
	var capture_ok := await shots.capture("00_warmed_harness_control")
	await _settle()
	var after_capture := _counts()
	var root_id := root.get_instance_id()
	root.queue_free()
	root = null
	camera = null
	await _settle()
	var released := instance_from_id(root_id) == null
	if not capture_ok:
		_fail("camera-only harness control did not complete its viewport capture")
	if not released:
		_fail("camera-only control owner did not release")
	return {
		"id": "capture_harness_without_module",
		"production_module_present": false,
		"before_capture": before_capture,
		"after_capture": after_capture,
		"owner_released": released,
		"capture_ok": capture_ok,
		"matlib_cache_before": matlib_before,
	}


func _run_module_cycle(case_id: String) -> Dictionary:
	var matlib_before := _matlib_cache_snapshot()
	var root := CELL_SCENE.instantiate() as Node3D
	if root == null:
		_fail("%s could not instantiate the production cell" % case_id)
		return {"id":case_id, "after_teardown":_counts()}
	add_child(root)
	await _settle()
	if bool(root.get("startup_failed")):
		_fail("%s production startup refused: %s" % [
				case_id, root.get("startup_errors")])
	var player: PlayerController = root.get("player") as PlayerController
	if player != null and player.camera != null:
		player.camera.make_current()
	var before_capture := _counts()
	var capture_ok := await shots.capture("01_first_module_cycle" \
			if case_id.ends_with("1") else "02_second_module_cycle")
	await _settle()
	var after_capture := _counts()
	var source_objects := _source_object_census(root)
	var root_id := root.get_instance_id()
	var player_id := player.get_instance_id() if player != null else 0
	var public_receipt: Dictionary = root.call("shutdown_for_tests") \
			if root.has_method("shutdown_for_tests") else {}
	if public_receipt.is_empty():
		_fail("%s has no successful public shutdown receipt" % case_id)
	root.queue_free()
	root = null
	player = null
	await _settle()
	var root_released := instance_from_id(root_id) == null
	var player_released := player_id == 0 or instance_from_id(player_id) == null
	if not capture_ok:
		_fail("%s did not complete its matched viewport capture" % case_id)
	if not root_released or not player_released:
		_fail("%s retained its root or production PlayerController" % case_id)
	if int(public_receipt.get("retained_strong_references", -1)) != 0:
		_fail("%s public teardown reports retained strong references" % case_id)
	return {
		"id": case_id,
		"production_module_present": true,
		"before_capture": before_capture,
		"after_capture": after_capture,
		"root_released": root_released,
		"player_released": player_released,
		"capture_ok": capture_ok,
		"public_teardown": public_receipt,
		"source_object_census_count": source_objects.size(),
		"matlib_cache_before": matlib_before,
		"_source_object_census": source_objects,
	}


func _source_object_census(root: Node) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var seen := {}
	var pending: Array[Dictionary] = [{"node":root, "path":String(root.get_path())}]
	while not pending.is_empty():
		var entry: Dictionary = pending.pop_back()
		var node := entry.node as Node
		if node == null:
			continue
		var node_path := String(node.get_path())
		var node_id := node.get_instance_id()
		if not seen.has(node_id):
			seen[node_id] = true
			records.append({
				"instance_id": node_id,
				"kind": "Node",
				"class": node.get_class(),
				"source_owner_class": node.get_class(),
				"source_owner_path": node_path,
				"property_chain": "self",
			})
		for property: Dictionary in node.get_property_list():
			var property_name := StringName(property.get("name", ""))
			if property_name == &"":
				continue
			_collect_resources(node.get(property_name), node, node_path,
					String(property_name), seen, records, 0)
		for child: Node in node.get_children():
			pending.append({"node":child, "path":String(child.get_path())})
	return records


func _collect_resources(value: Variant, source_owner: Node,
		source_path: String, chain: String, seen: Dictionary,
		records: Array[Dictionary], depth: int) -> void:
	if depth > 5:
		return
	if value is Resource:
		var resource := value as Resource
		var resource_id := resource.get_instance_id()
		if seen.has(resource_id):
			return
		seen[resource_id] = true
		records.append({
			"instance_id": resource_id,
			"kind": "Resource",
			"class": resource.get_class(),
			"resource_path": resource.resource_path,
			"source_owner_class": source_owner.get_class(),
			"source_owner_path": source_path,
			"property_chain": chain,
		})
		for property: Dictionary in resource.get_property_list():
			if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
				continue
			var property_name := StringName(property.get("name", ""))
			if property_name == &"":
				continue
			_collect_resources(resource.get(property_name), source_owner,
					source_path, chain + "." + String(property_name), seen,
					records, depth + 1)
	elif value is Array:
		var index := 0
		for child: Variant in value:
			_collect_resources(child, source_owner, source_path,
					"%s[%d]" % [chain, index], seen, records, depth + 1)
			index += 1
	elif value is Dictionary:
		for key: Variant in value:
			_collect_resources(value[key], source_owner, source_path,
					"%s[%s]" % [chain, str(key)], seen, records, depth + 1)


func _retained_source_objects(records: Array[Dictionary]) -> Array[Dictionary]:
	var retained: Array[Dictionary] = []
	for original: Dictionary in records:
		var instance: Object = instance_from_id(int(original.instance_id))
		if instance == null:
			continue
		var record := original.duplicate(true)
		record["retained_class"] = instance.get_class()
		if instance is Resource:
			record["retained_resource_path"] = (instance as Resource).resource_path
			record["retention_kind"] = "source_or_cache_resource" \
					if not (instance as Resource).resource_path.is_empty() \
					else "dynamic_resource"
		else:
			record["retention_kind"] = "live_node_or_object"
		var observed_retainer := _matlib_retainer_chain(
				int(original.instance_id))
		if not observed_retainer.is_empty():
			record["observed_retainer"] = observed_retainer
		retained.append(record)
	return retained


## Snapshot the resource IDs already reachable from the preloaded production
## scene and process-global material cache at the warmed control plateau. The
## snapshot contains integers and provenance only; it retains no Resource.
func _control_resource_census() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var seen := {}
	_collect_resources(CELL_SCENE, self, String(get_path()), "CELL_SCENE",
			seen, records, 0)
	for raw_key: Variant in MatLib._cache:
		_collect_resources(MatLib._cache[raw_key], self, String(get_path()),
				"MatLib._cache[%s]" % str(raw_key), seen, records, 0)
	var resources: Array[Dictionary] = []
	for record: Dictionary in records:
		if str(record.get("kind", "")) == "Resource":
			resources.append(record)
	return resources


func _resource_id_set(records: Array[Dictionary]) -> Dictionary:
	var result := {}
	for record: Dictionary in records:
		result[int(record.get("instance_id", 0))] = true
	return result


func _resource_snapshot_summary(records: Array[Dictionary]) -> Dictionary:
	var ids: Array[int] = []
	var classes := {}
	var paths: Array[String] = []
	for record: Dictionary in records:
		var instance_id := int(record.get("instance_id", 0))
		if instance_id != 0:
			ids.append(instance_id)
		var resource_class := str(record.get("class", ""))
		classes[resource_class] = int(classes.get(resource_class, 0)) + 1
		var path := str(record.get("resource_path", ""))
		if not path.is_empty():
			paths.append(path)
	ids.sort()
	paths.sort()
	return {
		"count": ids.size(),
		"instance_ids": ids,
		"class_counts": classes,
		"resource_paths": paths,
	}


## Retained records whose IDs were absent from the control plateau are the
## module-amplified set. Each must name a live current retainer, not merely the
## module node that referenced it before teardown.
func _amplified_retained_objects(records: Array[Dictionary],
		control_resource_ids: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for original: Dictionary in records:
		var instance_id := int(original.get("instance_id", 0))
		if control_resource_ids.has(instance_id):
			continue
		var record := original.duplicate(true)
		var current: Object = instance_from_id(instance_id)
		var retainer := _actual_current_retainer(instance_id, current)
		record["present_at_control_plateau"] = false
		record["actual_current_retainer"] = retainer
		record["attributed"] = not retainer.is_empty()
		result.append(record)
	return result


func _actual_current_retainer(instance_id: int, current: Object) -> Dictionary:
	if current == null:
		return {}
	var matlib_chain := _matlib_retainer_chain(instance_id)
	if not matlib_chain.is_empty():
		return {
			"owner": "MatLib._cache",
			"chain": matlib_chain,
			"class": current.get_class(),
		}
	if current is Resource:
		var resource := current as Resource
		var path := resource.resource_path
		if not path.is_empty() and ResourceLoader.has_cached(path):
			return {
				"owner": "ResourceLoader path cache",
				"chain": "ResourceLoader cache[%s]" % path,
				"class": resource.get_class(),
				"resource_path": path,
			}
	return {}


func _unattributed_count(records: Array) -> int:
	var count := 0
	for value: Variant in records:
		if value is not Dictionary or not bool(value.get("attributed", false)):
			count += 1
	return count


func _retainer_owner_counts(records: Array) -> Dictionary:
	var result := {}
	for value: Variant in records:
		if value is not Dictionary:
			continue
		var retainer: Dictionary = value.get("actual_current_retainer", {})
		var owner := str(retainer.get("owner", "UNATTRIBUTED"))
		result[owner] = int(result.get(owner, 0)) + 1
	return result


func _matlib_cache_snapshot() -> Dictionary:
	var entries := {}
	var unique_resource_ids := {}
	var unique_records := {}
	for raw_key: Variant in MatLib._cache:
		var material: Variant = MatLib._cache[raw_key]
		if material is not Resource:
			continue
		var resources: Array[Dictionary] = []
		_collect_cache_resources(material as Resource, "material", {},
				resources, 0)
		for record: Dictionary in resources:
			unique_resource_ids[int(record.instance_id)] = true
			unique_records[int(record.instance_id)] = record
		entries[str(raw_key)] = resources
	var class_counts := {}
	var resource_paths: Array[String] = []
	for raw_id: Variant in unique_records:
		var record: Dictionary = unique_records[raw_id]
		var resource_class := str(record.get("class", ""))
		class_counts[resource_class] = int(
				class_counts.get(resource_class, 0)) + 1
		var path := str(record.get("resource_path", ""))
		if not path.is_empty():
			resource_paths.append(path)
	resource_paths.sort()
	return {
		"owner": "MatLib._cache",
		"entries": entries,
		"entry_count": entries.size(),
		"unique_resource_count": unique_resource_ids.size(),
		"class_counts": class_counts,
		"resource_paths": resource_paths,
	}


func _collect_cache_resources(resource: Resource, chain: String,
		seen: Dictionary, records: Array[Dictionary], depth: int) -> void:
	if depth > 5 or resource == null or seen.has(resource.get_instance_id()):
		return
	seen[resource.get_instance_id()] = true
	records.append({
		"instance_id": resource.get_instance_id(),
		"class": resource.get_class(),
		"resource_path": resource.resource_path,
		"chain": chain,
	})
	for property: Dictionary in resource.get_property_list():
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name := StringName(property.get("name", ""))
		if property_name == &"":
			continue
		var value: Variant = resource.get(property_name)
		if value is Resource:
			_collect_cache_resources(value as Resource,
					chain + "." + String(property_name), seen, records,
					depth + 1)


func _matlib_retainer_chain(instance_id: int) -> String:
	for raw_key: Variant in MatLib._cache:
		var material: Variant = MatLib._cache[raw_key]
		if material is not Resource:
			continue
		var resources: Array[Dictionary] = []
		_collect_cache_resources(material as Resource, "material", {},
				resources, 0)
		for record: Dictionary in resources:
			if int(record.instance_id) == instance_id:
				return "MatLib._cache[%s].%s" % [
						str(raw_key), str(record.chain)]
	return ""


func _retained_live_object_count(records: Variant) -> int:
	if records is not Array:
		return -1
	var count := 0
	for value: Variant in records:
		if value is Dictionary \
				and str(value.get("retention_kind", "")) \
				== "live_node_or_object":
			count += 1
	return count


func _settle() -> void:
	# Fixed matched observation boundary, not a cleanup substitute.
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(
				Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(
				Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _delta(after: Dictionary, before: Dictionary) -> Dictionary:
	return {
		"objects": int(after.get("objects", 0)) - int(before.get("objects", 0)),
		"resources": int(after.get("resources", 0)) \
				- int(before.get("resources", 0)),
		"nodes": int(after.get("nodes", 0)) - int(before.get("nodes", 0)),
		"orphan_nodes": int(after.get("orphan_nodes", 0)) \
				- int(before.get("orphan_nodes", 0)),
	}


func _positive_retention(delta: Dictionary) -> bool:
	return int(delta.get("objects", 0)) > 0 \
			or int(delta.get("resources", 0)) > 0 \
			or int(delta.get("orphan_nodes", 0)) > 0


func _finish(receipt: Dictionary) -> void:
	var receipt_ok := false
	if not receipt.is_empty():
		var path := OS.get_environment(RECEIPT_ENV).strip_edges()
		if path.is_empty():
			path = shots.output_dir.path_join(RECEIPT_FILE)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_fail("could not write lifecycle receipt: %s" % path)
		else:
			file.store_string(JSON.stringify(receipt, "\t"))
			receipt_ok = true
	var shots_ok := shots.finish()
	print("[ORISON-V2-M11A-A-LIFECYCLE] RESULT: %s" % [
			"PASS" if shots_ok and receipt_ok and not _failed else "FAIL"])
	get_tree().quit(0 if shots_ok and receipt_ok and not _failed else 2)


func _fail(reason: String) -> void:
	_failed = true
	_failure_reasons.append(reason)
	push_error("M11A-A CAPTURE LIFECYCLE: " + reason)
	print("[ORISON-V2-M11A-A-LIFECYCLE FAIL] " + reason)
