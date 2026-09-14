extends Node
## Headless-capable disposable rehearsal instrument. It measures the copied
## original and every compact cell independently, then recomposes all compact
## cells through one public lifecycle boundary. One unreported warm-up is
## followed by two fully recorded cycles in the same process.

const Support := preload("res://m11c0_harness_support.gd")
const CompositionScript := preload("res://m11c0_cell_composition.gd")
const RECEIPT_ENV := "M11C0_RUNTIME_RECEIPT"
const DEFAULT_RECEIPT := "res://m11c0_runtime_receipt.json"

var _failures: Array[String] = []
var _unproven: Array[String] = []
var _tracked_created_objects := {}
var _warm_tracked_ids := {}
var _run_state_provenance := {}


func _ready() -> void:
	_run_state_provenance = {
		"class": "engine-internal GDScript coroutine await-state",
		"owner": "M11C0RuntimeValidation._run awaited by _ready",
		"enumeration_boundary": "GDScript 4 requires direct await and exposes no ObjectDB iteration API",
		"excluded_from_final_plateau": true,
	}
	await _run()


func _run() -> void:
	var inputs: Dictionary = Support.load_inputs()
	if not bool(inputs.get("ok", false)):
		for reason: Variant in inputs.get("errors", []):
			_fail(str(reason))
		_finish(_base_receipt(inputs))
		return
	var process_start: Dictionary = Support.object_counts()
	# Keep a full matched control result alive across the recorded cycles. The
	# result owns only primitive receipt data, but matching its shape prevents a
	# post-baseline instrumentation allocation from being mislabeled as scene
	# retention.
	var warmup: Dictionary = await _run_cycle("warmup", inputs, true)
	warmup["recorded"] = false
	warmup["purpose"] = "matched cache, physics and receipt-structure control"
	var warmed_baseline: Dictionary = Support.object_counts()
	_warm_tracked_ids = _live_tracked_id_set()
	var first: Dictionary = await _run_cycle("warmed_cycle_1", inputs, true)
	var between_cycles: Dictionary = Support.object_counts()
	var second: Dictionary = await _run_cycle("warmed_cycle_2", inputs, true)
	# Final counting is deferred until this coroutine and _ready have returned.
	# Otherwise their active GDScriptFunctionState is itself counted as a live
	# non-node ObjectDB object and can be mistaken for scene retention.
	call_deferred("_finalize_after_run", {
		"inputs": inputs,
		"process_start": process_start,
		"warmup": warmup,
		"warmed_baseline": warmed_baseline,
		"first": first,
		"between_cycles": between_cycles,
		"second": second,
	})


func _finalize_after_run(pending: Dictionary) -> void:
	var inputs: Dictionary = pending.inputs
	var process_start: Dictionary = pending.process_start
	var warmup: Dictionary = pending.warmup
	var warmed_baseline: Dictionary = pending.warmed_baseline
	var first: Dictionary = pending.first
	var between_cycles: Dictionary = pending.between_cycles
	var second: Dictionary = pending.second
	var final_counts: Dictionary = Support.object_counts()
	var retained_instrument_objects := _retained_tracked_since_warm()
	var runtime_equivalence := _runtime_equivalence(first)
	if not bool(runtime_equivalence.get("pass", false)):
		_fail("runtime recomposition does not preserve original mesh/collision topology")
	var first_plateau: Dictionary = first.get("after_teardown", {})
	var second_plateau: Dictionary = second.get("after_teardown", {})
	var second_growth := Support.delta(second_plateau, first_plateau)
	var final_from_warmed := Support.delta(final_counts, warmed_baseline)
	if _positive_retention(second_growth):
		_fail("second warmed cycle amplifies the first teardown plateau")
	if _scene_retention(final_from_warmed):
		_fail("recorded cycles retain resources/nodes beyond the warmed baseline")
	elif int(final_from_warmed.get("objects", 0)) > 0:
		var owner_summary := "none of the tracked harness/scene objects"
		if not retained_instrument_objects.is_empty():
			owner_summary = JSON.stringify(retained_instrument_objects)
		_mark_unproven("warmed harness lifetime retains %d non-node, non-resource ObjectDB object(s); retained tracked owners: %s" % [int(final_from_warmed.objects), owner_summary])
	var receipt := _base_receipt(inputs)
	receipt.merge({
		"process_start": process_start,
		"warmup": warmup,
		"warmed_baseline": warmed_baseline,
		"cycles": [first, second],
		"between_cycles": between_cycles,
		"final_counts": final_counts,
		"runtime_recomposition_equivalence": runtime_equivalence,
		"lifecycle": {
			"second_cycle_growth_from_first": second_growth,
			"final_delta_from_warmed_baseline": final_from_warmed,
			"public_api": "M11C0CellComposition.public_teardown",
			"node_name_reach_ins": false,
			"forced_object_deletion": false,
			"strong_reference_policy": "all Node and PackedScene locals cleared before matched settlement",
			"retained_tracked_objects_created_after_warm_control": retained_instrument_objects,
			"instrument_coroutine_state": _run_state_provenance,
			"final_observation_boundary": "deferred non-coroutine after _run and _ready release their await states",
			"tracked_object_classes": ["M11C0CellComposition", "PackedScene",
					"scene root Node", "World3D", "PhysicsDirectSpaceState3D",
					"PhysicsRayQueryParameters3D"],
		},
	}, true)
	_finish(receipt)


func _run_cycle(cycle_id: String, inputs: Dictionary,
		record_details: bool) -> Dictionary:
	var before: Dictionary = Support.object_counts()
	var independent: Array[Dictionary] = []
	var original: Dictionary = await _measure_independent(
			"ORIGINAL_FLOOR_01", str(inputs.original_scene_path), cycle_id,
			inputs.config, inputs.manifest)
	if record_details:
		independent.append(original)
	for cell: Dictionary in inputs.cells:
		var row: Dictionary = await _measure_independent(str(cell.id),
				str(cell.scene_path), cycle_id)
		if record_details:
			independent.append(row)
	var recomposed: Dictionary = await _measure_recomposed(inputs, cycle_id)
	await _settle()
	var after: Dictionary = Support.object_counts()
	return {
		"id": cycle_id,
		"recorded": record_details,
		"before": before,
		"independent": independent,
		"recomposed": recomposed if record_details else {
			"ok": bool(recomposed.get("ok", false)),
			"public_teardown": recomposed.get("public_teardown", {}),
		},
		"after_teardown": after,
		"delta": Support.delta(after, before),
	}


func _measure_independent(subject_id: String, scene_path: String,
		cycle_id: String, config: Dictionary = {},
		manifest: Dictionary = {}) -> Dictionary:
	var before: Dictionary = Support.object_counts()
	var load_started := Time.get_ticks_usec()
	var packed: PackedScene = Support.load_packed_scene(scene_path)
	_track_object(packed, "%s packed scene" % subject_id, cycle_id)
	var load_ms := _elapsed_ms(load_started)
	if packed == null:
		_fail("%s could not load %s" % [subject_id, scene_path])
		return {"id":subject_id, "path":scene_path, "ok":false,
				"load_ms":load_ms}
	var composition = CompositionScript.new()
	_track_object(composition, "%s independent composition" % subject_id,
			cycle_id)
	composition.name = "IndependentSubject"
	add_child(composition)
	var instantiate_started := Time.get_ticks_usec()
	var instance: Node = composition.mount_packed(subject_id, packed)
	_track_object(instance, "%s independent scene root" % subject_id,
			cycle_id)
	var instantiate_ms := _elapsed_ms(instantiate_started)
	if instance == null:
		_fail("%s loaded but did not instantiate" % subject_id)
		packed = null
		composition.queue_free()
		await _settle()
		return {"id":subject_id, "path":scene_path, "ok":false,
				"load_ms":load_ms, "instantiate_ms":instantiate_ms}
	await _settle()
	var metrics: Dictionary = Support.tree_metrics(instance)
	var seam_probes: Array[Dictionary] = []
	if subject_id == "ORIGINAL_FLOOR_01" and not manifest.is_empty():
		seam_probes = await _run_seam_probes(composition, config, manifest)
	var attached: Dictionary = Support.object_counts()
	var public_teardown: Dictionary = composition.public_teardown()
	var instance_id := instance.get_instance_id()
	var composition_id := composition.get_instance_id()
	instance = null
	packed = null
	composition.queue_free()
	composition = null
	await _settle()
	var released := instance_from_id(instance_id) == null \
			and instance_from_id(composition_id) == null
	var after: Dictionary = Support.object_counts()
	if not released:
		_fail("%s retained an independently loaded scene owner in %s" % [
				subject_id, cycle_id])
	if int(public_teardown.get("retained_strong_references", -1)) != 0:
		_fail("%s public teardown retained strong references" % subject_id)
	return {
		"id": subject_id,
		"path": scene_path,
		"ok": released,
		"load_ms": load_ms,
		"instantiate_ms": instantiate_ms,
		"metrics": metrics,
		"seam_probes": seam_probes,
		"before": before,
		"attached": attached,
		"after_teardown": after,
		"teardown_delta": Support.delta(after, before),
		"public_teardown": public_teardown,
		"owner_released": released,
	}


func _measure_recomposed(inputs: Dictionary, cycle_id: String) -> Dictionary:
	var before: Dictionary = Support.object_counts()
	var composition = CompositionScript.new()
	_track_object(composition, "recomposed composition", cycle_id)
	composition.name = "RecomposedFloor01"
	add_child(composition)
	var load_rows: Array[Dictionary] = []
	var mounted_ids: Array[int] = []
	for cell: Dictionary in inputs.cells:
		var load_started := Time.get_ticks_usec()
		var packed: PackedScene = Support.load_packed_scene(str(cell.scene_path))
		_track_object(packed, "%s recomposed PackedScene" % str(cell.id),
				cycle_id)
		var load_ms := _elapsed_ms(load_started)
		if packed == null:
			_fail("recomposition could not load %s" % str(cell.scene_path))
			load_rows.append({"id":cell.id, "load_ms":load_ms,
					"ok":false})
			continue
		var instance_started := Time.get_ticks_usec()
		var instance: Node = composition.mount_packed(str(cell.id), packed)
		_track_object(instance, "%s recomposed scene root" % str(cell.id),
				cycle_id)
		var instance_ms := _elapsed_ms(instance_started)
		if instance == null:
			_fail("recomposition could not instantiate %s" % str(cell.id))
		else:
			mounted_ids.append(instance.get_instance_id())
		load_rows.append({"id":cell.id, "path":cell.scene_path,
				"load_ms":load_ms, "instantiate_ms":instance_ms,
				"ok":instance != null})
		instance = null
		packed = null
	await _settle()
	var metrics: Dictionary = Support.tree_metrics(composition)
	var seam_probes: Array[Dictionary] = await _run_seam_probes(composition,
			inputs.config, inputs.manifest)
	var attached: Dictionary = Support.object_counts()
	var public_teardown: Dictionary = composition.public_teardown()
	var composition_id := composition.get_instance_id()
	composition.queue_free()
	composition = null
	await _settle()
	var unreleased: Array[int] = []
	for instance_id: int in mounted_ids:
		if instance_from_id(instance_id) != null:
			unreleased.append(instance_id)
	if instance_from_id(composition_id) != null:
		unreleased.append(composition_id)
	var after: Dictionary = Support.object_counts()
	if not unreleased.is_empty():
		_fail("%s recomposition retained %d scene owners" % [
				cycle_id, unreleased.size()])
	if int(public_teardown.get("retained_strong_references", -1)) != 0:
		_fail("%s recomposition retained public strong references" % cycle_id)
	return {
		"ok": unreleased.is_empty() and load_rows.size() == inputs.cells.size(),
		"cell_loads": load_rows,
		"metrics": metrics,
		"seam_probes": seam_probes,
		"before": before,
		"attached": attached,
		"after_teardown": after,
		"teardown_delta": Support.delta(after, before),
		"public_teardown": public_teardown,
		"unreleased_instance_ids": unreleased,
	}


func _run_seam_probes(composition: Node3D, config: Dictionary,
		manifest: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for seam: Dictionary in Support.seam_probe_specs(config, manifest):
		var probes: Array = seam.get("probes", [])
		if probes.is_empty():
			var reason := "%s has no explicit ray endpoints and expected contact; collision continuity is UNPROVEN" % str(seam.seam_id)
			_mark_unproven(reason)
			results.append({"seam_id":seam.seam_id, "status":"UNPROVEN",
					"reason":reason, "manifest_record":seam.manifest_record})
			continue
		var probe_rows: Array[Dictionary] = []
		var seam_failed := false
		var seam_unproven := false
		for raw: Variant in probes:
			var probe := raw as Dictionary
			var from := Support.vector3(probe.get("from", []))
			var to := Support.vector3(probe.get("to", []))
			var expected := str(probe.get("expect", "")).to_lower()
			if expected.is_empty() and probe.has("expect_hit"):
				expected = "hit" if bool(probe.expect_hit) else "clear"
			if not from.is_finite() or not to.is_finite() \
					or expected not in ["hit", "clear"]:
				var reason := "%s/%s requires finite from/to and expect=hit|clear" % [
						seam.seam_id, probe.get("id", "unnamed")]
				probe_rows.append({"id":probe.get("id", ""),
						"status":"UNPROVEN",
						"reason":reason})
				seam_unproven = true
				_mark_unproven(reason)
				continue
			var world := composition.get_world_3d()
			_track_object(world, "%s World3D" % str(seam.seam_id), "seam_probe")
			var direct_state := world.direct_space_state
			_track_object(direct_state, "%s direct space state" % str(seam.seam_id),
					"seam_probe")
			var query := PhysicsRayQueryParameters3D.create(from, to,
					int(probe.get("collision_mask", 0xFFFFFFFF)))
			_track_object(query, "%s/%s ray query" % [seam.seam_id,
					probe.get("id", "unnamed")], "seam_probe")
			query.collide_with_areas = bool(probe.get("collide_with_areas", true))
			query.collide_with_bodies = true
			var hit := direct_state.intersect_ray(query)
			var observed_hit := not hit.is_empty()
			var passed := observed_hit == (expected == "hit")
			var owner_cell := ""
			if observed_hit:
				owner_cell = _collider_cell_id(hit.get("collider"))
			probe_rows.append({
				"id": str(probe.get("id", "")),
				"from": Support.vector3_array(from),
				"to": Support.vector3_array(to),
				"expected": expected,
				"observed_hit": observed_hit,
				"hit_position": Support.vector3_array(hit.get("position",
						Vector3.ZERO)) if observed_hit else [],
				"collider_class": (hit.get("collider") as Object).get_class()
						if observed_hit else "",
				"owning_cell": owner_cell,
				"status": "PASS" if passed else "FAIL",
			})
			if not passed:
				seam_failed = true
				_fail("collision seam probe failed: %s/%s" % [
						seam.seam_id, probe.get("id", "unnamed")])
		results.append({"seam_id":seam.seam_id,
				"status":"FAIL" if seam_failed else (
						"UNPROVEN" if seam_unproven else "PASS"),
				"probes":probe_rows, "manifest_record":seam.manifest_record})
	return results


func _collider_cell_id(collider: Variant) -> String:
	var node := collider as Node
	while node != null:
		if node.has_meta(&"m11c0_cell_id"):
			return str(node.get_meta(&"m11c0_cell_id"))
		node = node.get_parent()
	return ""


func _base_receipt(inputs: Dictionary) -> Dictionary:
	return {
		"schema": "orison.m11c0.floor01-runtime-rehearsal.v1",
		"status": "PENDING",
		"authority": "disposable_rehearsal_only",
		"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(),
		"input_provenance": {
			"split_receipt": inputs.get("config_path", ""),
			"split_receipt_sha256": inputs.get("config_sha256", ""),
			"partition_manifest": inputs.get("manifest_path", ""),
			"partition_manifest_sha256": inputs.get("manifest_sha256", ""),
			"original_scene_path": inputs.get("original_scene_path", ""),
			"cell_count": (inputs.get("cells", []) as Array).size(),
		},
	}


func _runtime_equivalence(cycle: Dictionary) -> Dictionary:
	var independent: Array = cycle.get("independent", [])
	if independent.is_empty():
		return {"pass":false, "reason":"original independent row missing"}
	var original: Dictionary = independent[0]
	var original_metrics: Dictionary = original.get("metrics", {})
	var recomposed_metrics: Dictionary = cycle.get("recomposed", {}).get(
			"metrics", {})
	var fields := ["mesh_instances", "unique_mesh_resources",
			"mesh_primitives", "render_primitives_estimate",
			"collision_objects", "collision_shapes"]
	var comparisons := {}
	var passed := true
	for field: String in fields:
		var original_value := int(original_metrics.get(field, -1))
		var recomposed_value := int(recomposed_metrics.get(field, -2))
		comparisons[field] = {"original":original_value,
				"recomposed":recomposed_value,
				"equal":original_value == recomposed_value}
		passed = passed and original_value == recomposed_value
	var bounds_equal := _numeric_arrays_close(original_metrics.get("aabb_min", []),
			recomposed_metrics.get("aabb_min", []), 0.0001) \
			and _numeric_arrays_close(original_metrics.get("aabb_max", []),
			recomposed_metrics.get("aabb_max", []), 0.0001)
	comparisons["bounds"] = {
		"original_min":original_metrics.get("aabb_min", []),
		"original_max":original_metrics.get("aabb_max", []),
		"recomposed_min":recomposed_metrics.get("aabb_min", []),
		"recomposed_max":recomposed_metrics.get("aabb_max", []),
		"equal_within_0_1mm":bounds_equal,
	}
	var probe_signature_original := _probe_signature(original.get(
			"seam_probes", []))
	var probe_signature_recomposed := _probe_signature(cycle.get(
			"recomposed", {}).get("seam_probes", []))
	var probes_equal := probe_signature_original == probe_signature_recomposed
	comparisons["collision_probe_observations"] = {
		"original": probe_signature_original,
		"recomposed": probe_signature_recomposed,
		"equal": probes_equal,
	}
	return {"pass":passed and bounds_equal and probes_equal,
			"comparisons":comparisons,
			"node_count_excluded_reason":"cell and composition roots are harness topology, not source geometry"}


func _numeric_arrays_close(first: Variant, second: Variant,
		tolerance: float) -> bool:
	if first is not Array or second is not Array or first.size() != second.size():
		return false
	for index in first.size():
		if absf(float(first[index]) - float(second[index])) > tolerance:
			return false
	return true


func _probe_signature(raw_results: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_results is not Array:
		return result
	for raw_seam: Variant in raw_results:
		if raw_seam is not Dictionary:
			continue
		var seam := raw_seam as Dictionary
		var probes: Array = seam.get("probes", [])
		if probes.is_empty():
			result.append({"seam_id":seam.get("seam_id", ""),
					"status":seam.get("status", "UNPROVEN")})
			continue
		for raw_probe: Variant in probes:
			if raw_probe is not Dictionary:
				continue
			var probe := raw_probe as Dictionary
			result.append({
				"seam_id": seam.get("seam_id", ""),
				"probe_id": probe.get("id", ""),
				"expected": probe.get("expected", ""),
				"observed_hit": probe.get("observed_hit", false),
				"hit_position": probe.get("hit_position", []),
				"collider_class": probe.get("collider_class", ""),
				"status": probe.get("status", ""),
			})
	return result


func _track_object(value: Variant, owner: String, phase: String) -> void:
	if value is not Object or not is_instance_valid(value):
		return
	var object := value as Object
	var instance_id := object.get_instance_id()
	if not _tracked_created_objects.has(instance_id):
		_tracked_created_objects[instance_id] = {
			"instance_id": instance_id,
			"created_class": object.get_class(),
			"owner": owner,
			"phase": phase,
		}


func _live_tracked_id_set() -> Dictionary:
	var result := {}
	for raw_id: Variant in _tracked_created_objects:
		var instance_id := int(raw_id)
		if instance_from_id(instance_id) != null:
			result[instance_id] = true
	return result


func _retained_tracked_since_warm() -> Array[Dictionary]:
	var retained: Array[Dictionary] = []
	for raw_id: Variant in _tracked_created_objects:
		var instance_id := int(raw_id)
		if _warm_tracked_ids.has(instance_id):
			continue
		var current: Object = instance_from_id(instance_id)
		if current == null:
			continue
		var record: Dictionary = (_tracked_created_objects[instance_id] \
				as Dictionary).duplicate(true)
		record["retained_class"] = current.get_class()
		if current is Resource:
			record["resource_path"] = (current as Resource).resource_path
		retained.append(record)
		current = null
	return retained


func _positive_retention(value: Dictionary) -> bool:
	return int(value.get("objects", 0)) > 0 \
			or int(value.get("resources", 0)) > 0 \
			or int(value.get("nodes", 0)) > 0 \
			or int(value.get("orphan_nodes", 0)) > 0


func _scene_retention(value: Dictionary) -> bool:
	return int(value.get("resources", 0)) > 0 \
			or int(value.get("nodes", 0)) > 0 \
			or int(value.get("orphan_nodes", 0)) > 0


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _settle() -> void:
	# Matched observation boundary. It is not a substitute for public teardown.
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _finish(receipt: Dictionary) -> void:
	receipt["status"] = "FAIL" if not _failures.is_empty() else (
			"PASS_WITH_UNPROVEN_SEAMS" if not _unproven.is_empty() else "PASS")
	receipt["failures"] = _failures
	receipt["unproven"] = _unproven
	var output := OS.get_environment(RECEIPT_ENV).strip_edges()
	if output.is_empty():
		output = DEFAULT_RECEIPT
	if not Support.write_json(output, receipt):
		push_error("M11C0 RUNTIME: could not write receipt %s" % output)
		get_tree().quit(2)
		return
	print("M11C0 FLOOR01 RUNTIME: %s" % receipt.status)
	get_tree().quit(2 if receipt.status == "FAIL" else 0)


func _fail(reason: String) -> void:
	_failures.append(reason)
	push_error("M11C0 RUNTIME: " + reason)


func _mark_unproven(reason: String) -> void:
	if reason not in _unproven:
		_unproven.append(reason)
