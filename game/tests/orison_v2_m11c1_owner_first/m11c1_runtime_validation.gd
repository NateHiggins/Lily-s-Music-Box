extends Node
## Complete disposable target-cell rehearsal. Two same-process cycles exercise
## independent cells, every canonical residency set, full recomposition, the
## real named consumers, and collision-bearing bidirectional seam traversal.

const Support := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd")
const AdapterScript := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_consumer_adaptation.gd")
const MarkerAdapterScript := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_marker_consumer_adapter.gd")
const ScannerAdapterScript := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_scanner_consumer_adapter.gd")

const RECEIPT_ENV := "M11C1_RUNTIME_RECEIPT"
const DEFAULT_RECEIPT := "user://m11c1/m11c1_runtime_receipt.json"
const PLAYER_SCRIPT := "res://scripts/player/player_controller.gd"
const LAYOUT_PATH := "res://data/building_layout.json"
const M11A_SCENE := "res://scenes/building/orison_v2_exterior_cell.tscn"
const SCANNER_REQUIRED_ASSETS := [
	"res://assets/building/textures/atmospheric_decals/institutional_wear_atlas.png",
	"res://assets/building/textures/atmospheric_decals/domestic_residue_atlas.png",
	"res://assets/building/textures/found_art/fine_art_01.webp",
	"res://assets/building/textures/found_art/posters_01.webp",
	"res://assets/building/textures/found_art/editorial_01.webp",
	"res://assets/building/textures/found_art/editorial_02.webp",
	"res://assets/building/textures/found_art/billboards_01.webp",
	"res://assets/arcade/arcade_cabinets.json",
]

var _failures: Array[String] = []
var _blockers: Array[String] = []
var _reality_snapshot: Dictionary = {}


func _ready() -> void:
	_reality_snapshot = _snapshot_reality_state()
	RealityState.persistence_enabled = false
	await _run()


func _run() -> void:
	var inputs: Dictionary = Support.load_inputs()
	for reason: Variant in inputs.get("errors", []):
		_fail(str(reason))
	for reason: Variant in inputs.get("blockers", []):
		_block(str(reason))
	if not bool(inputs.get("ok", false)):
		_finish(_base_receipt(inputs))
		return
	_gate_input_completeness(inputs)
	RenderingServer.viewport_set_measure_render_time(
			get_viewport().get_viewport_rid(), true)
	var process_start := Support.object_counts()
	var warmup := await _warmup(inputs)
	if str(warmup.get("status", "FAIL")) != "PASS":
		_fail("unrecorded cache warm-up did not complete")
	var warmed_baseline := Support.object_counts()
	var first := await _run_cycle("warmed_cycle_1", inputs)
	_gate_cycle_result(first, "warmed_cycle_1")
	var between_cycles := Support.object_counts()
	var second := await _run_cycle("warmed_cycle_2", inputs)
	_gate_cycle_result(second, "warmed_cycle_2")
	call_deferred("_finalize", {
		"inputs":inputs,
		"process_start":process_start,
		"warmup":warmup,
		"warmed_baseline":warmed_baseline,
		"first":first,
		"between_cycles":between_cycles,
		"second":second,
	})


func _gate_cycle_result(cycle: Dictionary, expected_id: String) -> void:
	if str(cycle.get("id", "")) != expected_id:
		_fail("%s aborted before producing a cycle receipt" % expected_id)
		return
	var independent: Array = cycle.get("independent_cells", [])
	var residencies: Array = cycle.get("residency_sets", [])
	var seams: Array = cycle.get("seams", [])
	if independent.size() != Support.TARGET_CELL_IDS.size():
		_fail("%s did not measure all 17 independent cells" % expected_id)
	if residencies.size() != Support.REQUIRED_RESIDENCY.size():
		_fail("%s did not measure every declared residency set" % expected_id)
	if seams.size() != Support.REQUIRED_SEAM_IDS.size():
		_fail("%s did not execute all five dangerous seams" % expected_id)
	var seam_ids: Array[String] = []
	var traversal_count := 0
	for raw_seam: Variant in seams:
		if raw_seam is Dictionary:
			seam_ids.append(str(raw_seam.get("id", "")))
			traversal_count += (raw_seam.get("traversals", []) as Array).size()
	var required_seams: Array[String] = Support.string_array(
			Support.REQUIRED_SEAM_IDS)
	seam_ids.sort()
	required_seams.sort()
	if seam_ids != required_seams or traversal_count != 15:
		_fail("%s must receipt exactly five named seams and 15 traversal contracts" \
				% expected_id)
	for group: Array in [independent, residencies, seams]:
		for raw: Variant in group:
			if raw is not Dictionary or str(raw.get("status", "FAIL")) != "PASS":
				_fail("%s contains an incomplete or non-PASS measured row" % expected_id)
	var consumer: Dictionary = cycle.get("consumer_adaptations", {})
	if str(consumer.get("status", "BLOCKED")) != "PASS":
		_fail("%s did not complete the consumer-adaptation census" % expected_id)
	var full: Dictionary = cycle.get("full_recomposition", {})
	if str(full.get("status", "FAIL")) != "PASS" \
			or str(full.get("residency_set", "")) != "FULL_RECOMPOSITION":
		_fail("%s lacks a successful full recomposition row" % expected_id)
	var semantics: Dictionary = cycle.get("semantic_ownership", {})
	if str(semantics.get("status", "FAIL")) != "PASS" \
			or int(semantics.get("identity_count", 0)) <= 0 \
			or (semantics.get("rows", []) as Array).is_empty():
		_fail("%s lacks a nonempty source-semantic ownership census" % expected_id)


func _gate_input_completeness(inputs: Dictionary) -> void:
	if (inputs.get("cells", []) as Array).size() != Support.TARGET_CELL_IDS.size():
		_fail("validated input must contain exactly 17 target-cell descriptors")
	for key: String in ["config_sha256", "partition_sha256", "lineage_sha256",
			"equivalence_sha256"]:
		if str(inputs.get(key, "")).length() != 64:
			_fail("validated input has an empty or malformed provenance hash: %s" % key)
	var disk := Support.disk_metrics(inputs)
	if str(disk.get("status", "FAIL")) != "PASS" \
			or int(disk.get("cell_total_bytes", 0)) <= 0 \
			or int(disk.get("protected_total_bytes", 0)) <= 0:
		_fail("validated input has incomplete or zero disk metrics")


func _warmup(inputs: Dictionary) -> Dictionary:
	var before := Support.object_counts()
	var adapter = AdapterScript.new()
	if not adapter.configure(inputs):
		_fail("warm-up adapter refused configuration")
		return {"status":"FAIL"}
	add_child(adapter)
	var mounted: Dictionary = adapter.mount_residency("FULL_RECOMPOSITION", true)
	await _settle()
	var scanner_warmup: Dictionary = {}
	var warmup_layout := _load_layout()
	if bool(mounted.get("ok", false)) and not warmup_layout.is_empty():
		scanner_warmup = await _exercise_scanner_adapter(adapter, warmup_layout)
	var metrics := Support.tree_metrics(adapter.registry)
	var adapter_weak: WeakRef = weakref(adapter)
	var registry_weak: WeakRef = weakref(adapter.registry)
	var host_weak: WeakRef = weakref(adapter.composition_host)
	var teardown: Dictionary = adapter.public_teardown()
	adapter.queue_free()
	adapter = null
	await _settle()
	var root_release := {
		"adapter":adapter_weak.get_ref() == null,
		"registry":registry_weak.get_ref() == null,
		"composition_host":host_weak.get_ref() == null,
	}
	var owner_released: bool = bool(root_release.adapter) \
			and bool(root_release.registry) and bool(root_release.composition_host)
	if not owner_released:
		_fail("unrecorded warm-up retained an owned scene root")
	var scanner_ok := str(scanner_warmup.get("status", "FAIL")) == "PASS"
	# Scanner warm-up alone does not touch the save/reconstruction, exterior,
	# detail-pass, nav, or production-player caches used by recorded cycles.
	# Exercise the identical consumer path once before establishing the warmed
	# lifecycle baseline. This row is explicit and remains unmeasured.
	var consumer_warmup: Dictionary = await _exercise_real_consumers(
			"unrecorded_consumer_warmup", inputs)
	var consumer_ok := str(consumer_warmup.get("status", "FAIL")) == "PASS"
	return {
		"recorded":false,
		"purpose":"import, renderer, physics and real-consumer cache control",
		"status":"PASS" if bool(mounted.get("ok", false)) and scanner_ok \
				and consumer_ok and owner_released \
				else "FAIL",
		"metrics":metrics,
		"scanner_static_cache_warmup":scanner_warmup,
		"real_consumer_cache_warmup":consumer_warmup,
		"public_teardown":teardown,
		"owner_released":owner_released,
		"owned_root_release":root_release,
		"delta":Support.object_delta(Support.object_counts(), before),
	}


func _run_cycle(cycle_id: String, inputs: Dictionary) -> Dictionary:
	var before := Support.object_counts()
	var independent_cells: Array[Dictionary] = []
	for cell: Dictionary in inputs.get("cells", []):
		independent_cells.append(await _measure_cells(cycle_id,
				"CELL/%s" % str(cell.id), [str(cell.id)], inputs, true))
	var residency_rows: Array[Dictionary] = []
	for residency_id: String in Support.REQUIRED_RESIDENCY:
		residency_rows.append(await _measure_residency(cycle_id,
				residency_id, inputs))
	var full_row: Dictionary = {}
	for row: Dictionary in residency_rows:
		if str(row.get("residency_set", "")) == "FULL_RECOMPOSITION":
			full_row = row
			break
	var consumer_execution := await _exercise_real_consumers(cycle_id, inputs)
	var seam_rows := await _exercise_seams(cycle_id, inputs)
	await _settle()
	var after := Support.object_counts()
	return {
		"id":cycle_id,
		"root":"M11C1OwnerFirstHarness/RuntimeValidation",
		"profile":_profile_label(),
		"simulation_state":"same-process warmed production physics enabled",
		"before":before,
		"independent_cells":independent_cells,
		"residency_sets":residency_rows,
		"full_recomposition":full_row,
		"consumer_adaptations":consumer_execution,
		"semantic_ownership":_semantic_receipt(inputs),
		"seams":seam_rows,
		"after_teardown":after,
		"delta":Support.object_delta(after, before),
	}


func _measure_cells(cycle_id: String, measurement_id: String,
		cell_ids: Array[String], inputs: Dictionary,
		require_imported: bool) -> Dictionary:
	var before := Support.object_counts()
	var adapter = AdapterScript.new()
	if not adapter.configure(inputs):
		_fail("%s adapter refused configuration" % measurement_id)
		return {"status":"FAIL", "id":measurement_id}
	add_child(adapter)
	var started := Time.get_ticks_usec()
	var mounted: Dictionary = adapter.mount_explicit_cells(cell_ids,
			not require_imported)
	var total_ms := Support.elapsed_ms(started)
	await _settle()
	var metrics := Support.tree_metrics(adapter.registry)
	var performance := _labeled_performance(measurement_id, cell_ids,
			"independent target-cell scene attached; production physics enabled")
	var loads: Array = mounted.get("loads", [])
	for load: Dictionary in loads:
		if not bool(load.get("ok", false)):
			_fail("%s could not load %s: %s" % [measurement_id,
					load.get("cell_id", ""), load.get("error", "")])
	var teardown: Dictionary = adapter.public_teardown()
	var adapter_id := adapter.get_instance_id()
	adapter.queue_free()
	adapter = null
	await _settle()
	var released := instance_from_id(adapter_id) == null
	if not released:
		_fail("%s retained its adapter root" % measurement_id)
	var after := Support.object_counts()
	return {
		"status":"PASS" if bool(mounted.get("ok", false)) and released else "FAIL",
		"id":measurement_id,
		"root":"M11C1ConsumerAdaptation/OwnerFirstGeometryCells",
		"profile":_profile_label(),
		"residency_set":"INDEPENDENT_CELL" if cell_ids.size() == 1 \
				else "EXPLICIT_CELL_SET",
		"cell_ids":cell_ids,
		"simulation_state":"production physics enabled; no player",
		"total_load_instantiate_ms":total_ms,
		"loads":loads,
		"metrics":metrics,
		"performance":performance,
		"before":before,
		"after_teardown":after,
		"teardown_delta":Support.object_delta(after, before),
		"public_teardown":teardown,
		"owner_released":released,
	}


func _measure_residency(cycle_id: String, residency_id: String,
		inputs: Dictionary) -> Dictionary:
	var residency_sets: Dictionary = inputs.get("residency_sets", {})
	var cells: Array[String] = Support.string_array(
			residency_sets.get(residency_id, []))
	var row := await _measure_cells(cycle_id, "RESIDENCY/%s" % residency_id,
			cells, inputs, true)
	row["residency_set"] = residency_id
	return row


func _exercise_real_consumers(cycle_id: String,
		inputs: Dictionary) -> Dictionary:
	var before := Support.object_counts()
	# These authorities own spatial state outside floor_01. Exercise them while
	# no target-cell composition is alive; otherwise a nominally isolated M11A
	# run would overlap the street/bodega cells held by the outer adapter.
	var executions := {}
	executions["M11A_EXTERIOR_COMPOSITION"] = await _exercise_m11a(inputs)
	executions["SAVE_RECONSTRUCTION"] = await _exercise_save_reconstruction(inputs)
	var adapter = AdapterScript.new()
	if not adapter.configure(inputs):
		_fail("consumer execution adapter refused configuration")
		return {"status":"FAIL"}
	add_child(adapter)
	var mounted: Dictionary = adapter.mount_residency("FULL_RECOMPOSITION", false)
	if not bool(mounted.get("ok", false)):
		_block("real consumer adaptation requires all 17 imported target cells")
	var layout := _load_layout()
	if not layout.is_empty() and bool(mounted.get("ok", false)):
		executions["ORISON_DETAIL_PASS"] = await _exercise_orison_detail(
				adapter, layout)
		executions["VANTRY_POINT_NETWORK"] = await _exercise_vantry(
				adapter, layout)
		executions["EXTERIOR_DETAIL_PASS"] = await _exercise_exterior_detail(
				adapter, layout)
		executions["F01_SCANNER_PASS_DIRECTOR_CENSUS"] = \
				await _exercise_scanner_adapter(adapter, layout)
	else:
		for contract_id: String in ["ORISON_DETAIL_PASS",
				"VANTRY_POINT_NETWORK", "EXTERIOR_DETAIL_PASS",
				"F01_SCANNER_PASS_DIRECTOR_CENSUS"]:
			executions[contract_id] = {"status":"BLOCKED",
					"reason":"full imported residency or layout unavailable"}
	executions["RESIDENT_NAV"] = await _exercise_resident_nav_queries(
			adapter, inputs, layout, "ALL")
	for contract_id: Variant in executions:
		var status := str((executions[contract_id] as Dictionary).get(
				"status", "BLOCKED"))
		if status == "FAIL":
			_fail("consumer adaptation failed: %s" % str(contract_id))
		elif status == "BLOCKED":
			_block("consumer adaptation blocked: %s — %s" % [contract_id,
					(executions[contract_id] as Dictionary).get("reason", "")])
	var census: Dictionary = adapter.exercise_consumer_contracts(executions)
	if str(census.get("status", "BLOCKED")) != "PASS":
		_block("isolated BuildingRoot residency/index/visibility or real F01 scanner consumer contract failed")
	var teardown: Dictionary = adapter.public_teardown()
	var adapter_id := adapter.get_instance_id()
	adapter.queue_free()
	adapter = null
	await _settle()
	var released := instance_from_id(adapter_id) == null
	if not released:
		_fail("real consumer adaptation retained its root")
	return {
		"status":census.get("status", "BLOCKED"),
		"root":"M11C1ConsumerAdaptation/F01",
		"profile":_profile_label(),
		"residency_set":"FULL_RECOMPOSITION",
		"simulation_state":"real production consumer APIs exercised in isolated test composition",
		"executions":executions,
		"census":census,
		"public_teardown":teardown,
		"owner_released":released,
		"delta":Support.object_delta(Support.object_counts(), before),
		"cycle":cycle_id,
	}


func _exercise_scanner_adapter(adapter: Node3D,
		layout: Dictionary) -> Dictionary:
	var missing_assets: Array[String] = []
	for path: String in SCANNER_REQUIRED_ASSETS:
		if not FileAccess.file_exists(path):
			missing_assets.append(path)
	if not missing_assets.is_empty():
		return {
			"status":"BLOCKED",
			"reason":"real F01 scanner consumers require their production asset inputs",
			"missing_assets":missing_assets,
		}
	var scanner = ScannerAdapterScript.new()
	scanner.name = "M11C1RealScannerConsumerAdapter"
	adapter.add_child(scanner)
	var configured: bool = scanner.configure(layout, adapter.composition_host,
			adapter.registry)
	var result: Dictionary = await scanner.exercise(
			Support.string_array(Support.TARGET_CELL_IDS),
			["CELL_ORISON_F01_INTERIOR", "CELL_ORISON_FACADE_SHELL"]) \
			if configured else {"status":"BLOCKING",
					"reason":"scanner adapter refused F01 host/registry configuration"}
	var raw_status := str(result.get("status", "BLOCKING"))
	if raw_status == "BLOCKING":
		result["status"] = "BLOCKED"
	result["raw_adapter_status"] = raw_status
	var teardown: Dictionary = scanner.public_teardown()
	var scanner_id := scanner.get_instance_id()
	scanner.queue_free()
	scanner = null
	await _settle()
	var released := instance_from_id(scanner_id) == null
	result["public_teardown"] = teardown
	result["owner_released"] = released
	if not released:
		result["status"] = "FAIL"
		result["reason"] = "scanner adapter root retained after public teardown"
	return result


func _exercise_orison_detail(adapter: Node3D,
		layout: Dictionary) -> Dictionary:
	var scoped_layout := Support.f01_layout(layout)
	if scoped_layout.is_empty():
		return {"status":"BLOCKED",
				"reason":"unchanged layout does not contain exactly one F01 record"}
	var before_children: int = int(adapter.composition_host.get_child_count())
	var detail_pass := OrisonDetailPass.new()
	detail_pass.name = "M11C1RealOrisonDetailPass"
	adapter.add_child(detail_pass)
	var started := Time.get_ticks_usec()
	var result: Dictionary = detail_pass.build(scoped_layout,
			{"F01":adapter.composition_host})
	await _settle()
	var installed: int = int(adapter.composition_host.get_child_count()) \
			- before_children
	var ok: bool = not result.is_empty() and installed > 0
	return {
		"status":"PASS" if ok else "FAIL",
		"production_class":"OrisonDetailPass",
		"public_api":"build(layout, floor_nodes)",
		"layout_scope":"unchanged F01 authoring record only",
		"floor_nodes":{"F01":"persistent geometry-free composition host"},
		"result":result,
		"installed_host_children":installed,
		"elapsed_ms":Support.elapsed_ms(started),
	}


func _exercise_vantry(adapter: Node3D,
		layout: Dictionary) -> Dictionary:
	var scoped := layout.duplicate(true)
	var f01_points: Array = []
	for raw: Variant in layout.get("vantry_points", []):
		if raw is Dictionary and str(raw.get("floor", "")) == "F01":
			f01_points.append((raw as Dictionary).duplicate(true))
	scoped["vantry_points"] = f01_points
	var work_orders := WorkOrders.new()
	work_orders.name = "M11C1VantryWorkOrders"
	adapter.add_child(work_orders)
	var network := VantryPointNetwork.new()
	network.name = "M11C1RealVantryPointNetwork"
	adapter.add_child(network)
	var count := network.build(scoped,
			{"F01":adapter.composition_host}, work_orders)
	var ids := network.cached_point_ids()
	var activated := false
	var activated_point := ""
	if not ids.is_empty():
		activated_point = str(ids[0])
		activated = network.activate(activated_point)
	await _settle()
	var ok := count == f01_points.size() and count > 0 \
			and network.floor_batch_count() == 1 and activated
	var chirp_stopped := false
	var released_voices := 0
	if activated and is_instance_valid(network.active_owner):
		network.active_owner.set_chirping(false)
		chirp_stopped = network.active_owner.state \
				== VantryPointProp.PState.IDLE
		released_voices = AudioPolicy.release_source(
				StringName(activated_point), &"nav.vantry_fault")
	ok = ok and chirp_stopped and not AudioPolicy.active_voice(
			StringName(activated_point), &"nav.vantry_fault")
	return {
		"status":"PASS" if ok else "FAIL",
		"production_class":"VantryPointNetwork",
		"public_apis":["build", "cached_point_ids", "activate",
				"floor_batch_count"],
		"authored_f01_points":f01_points.size(),
		"built_points":count,
		"floor_batches":network.floor_batch_count(),
		"activated_point":activated_point,
		"activated":activated,
		"chirp_stopped_before_teardown":chirp_stopped,
		"audio_policy_released_voice_count":released_voices,
		"audio_policy_active_after_release":AudioPolicy.active_voice(
				StringName(activated_point), &"nav.vantry_fault") \
				if not activated_point.is_empty() else false,
		"host":"F01",
	}


func _exercise_exterior_detail(adapter: Node3D,
		layout: Dictionary) -> Dictionary:
	var site_root := Node3D.new()
	site_root.name = "M11C1GovernedExteriorDetail"
	site_root.set_meta(&"m11c1_owner_cell", "CELL_SITE_STREET_COMMON")
	var site_cell: Node = adapter.registry.instance_for_cell(
			"CELL_SITE_STREET_COMMON")
	if site_cell == null:
		return {"status":"BLOCKED",
				"reason":"CELL_SITE_STREET_COMMON is not resident"}
	site_cell.add_child(site_root)
	var detail_pass := ExteriorDetailPass.new()
	detail_pass.name = "M11C1RealExteriorDetailPass"
	site_root.add_child(detail_pass)
	var started := Time.get_ticks_usec()
	var result: Dictionary = detail_pass.build(layout, site_root)
	detail_pass.set_weather_flash(0.0)
	detail_pass.set_weather_profile(Color(0.12, 0.145, 0.19))
	detail_pass.set_neighbour_occupancy_gain(1.0)
	await _settle()
	var metrics := Support.tree_metrics(site_root)
	var ok := not result.is_empty() and int(metrics.get("nodes", 0)) > 2
	return {
		"status":"PASS" if ok else "FAIL",
		"production_class":"ExteriorDetailPass",
		"public_apis":["build", "set_weather_flash",
				"set_weather_profile", "set_neighbour_occupancy_gain"],
		"governed_owner_cell":"CELL_SITE_STREET_COMMON",
		"result":result,
		"metrics":metrics,
		"elapsed_ms":Support.elapsed_ms(started),
		"persistent_output_outside_governed_root":false,
	}


func _exercise_m11a(inputs: Dictionary) -> Dictionary:
	var packed := load(M11A_SCENE) as PackedScene
	if packed == null:
		return {"status":"BLOCKED", "reason":"M11A production scene missing"}
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return {"status":"FAIL", "reason":"M11A production scene did not instantiate"}
	var started := Time.get_ticks_usec()
	add_child(instance)
	await _settle()
	var startup_failed := bool(instance.get("startup_failed"))
	var census: Variant = instance.call("authority_census") \
			if instance.has_method("authority_census") else {}
	var cost: Variant = instance.call("cost_report") \
			if instance.has_method("cost_report") else {}
	var config: Dictionary = inputs.get("config", {})
	var fixture: Dictionary = config.get("save_reconstruction", {}) \
			if config.get("save_reconstruction", {}) is Dictionary else {}
	var route_id := str(fixture.get("route_id", ""))
	var threshold_id := str(fixture.get("threshold_id", ""))
	var route: Dictionary = instance.call("route", route_id) \
			if instance.has_method("route") else {}
	var resolver: Variant = instance.get("spatial_resolver")
	var threshold: Dictionary = resolver.resolve_threshold(threshold_id) \
			if resolver != null and resolver.has_method("resolve_threshold") else {}
	var semantic_index: Dictionary = inputs.get("semantic_index", {})
	var v1_door: Dictionary = semantic_index.get("F01_BODEGA_DOOR", {})
	var v2_threshold: Dictionary = semantic_index.get(threshold_id, {})
	var module_transform_identity := instance.global_transform.is_equal_approx(
			Transform3D.IDENTITY)
	var module_parent_is_harness := instance.get_parent() == self
	var semantic_distinct := not v1_door.is_empty() and not v2_threshold.is_empty() \
			and str(v1_door.get("source_id", "")) \
			!= str(v2_threshold.get("source_id", "")) \
			and str(v1_door.get("identity", "F01_BODEGA_DOOR")) != threshold_id
	var teardown: Variant = instance.call("teardown") \
			if instance.has_method("teardown") else {}
	var instance_id := instance.get_instance_id()
	instance.queue_free()
	instance = null
	packed = null
	await _settle()
	var released := instance_from_id(instance_id) == null
	var ok := not startup_failed and released and module_transform_identity \
			and module_parent_is_harness and not route.is_empty() \
			and not threshold.is_empty() and semantic_distinct
	return {
		"status":"PASS" if ok else "FAIL",
		"production_scene":M11A_SCENE,
		"production_class":"OrisonV2ExteriorCell",
		"authority_census":census,
		"cost_report":cost,
		"route_id":route_id,
		"route_resolved":not route.is_empty(),
		"threshold_id":threshold_id,
		"threshold_resolved":not threshold.is_empty(),
		"v1_bodega_door_source":v1_door,
		"v2_bodega_threshold_source":v2_threshold,
		"v1_v2_semantic_identity_distinct":semantic_distinct,
		"public_teardown":teardown,
		"adaptation_topology":"separate labeled lifecycle; never co-mounted with owner-first street/bodega cells",
		"module_root_transform_identity":module_transform_identity,
		"module_parent_is_isolated_harness":module_parent_is_harness,
		"target_cell_overlap_tested":false,
		"target_cell_overlap_reason":"separate lifecycle avoids duplicating M11A geometry/collision with full F01 recomposition",
		"released":released,
		"elapsed_ms":Support.elapsed_ms(started),
	}


func _exercise_save_reconstruction(inputs: Dictionary) -> Dictionary:
	var config: Dictionary = inputs.get("config", {})
	var fixture: Variant = config.get("save_reconstruction", {})
	if fixture is not Dictionary:
		return {"status":"BLOCKED", "reason":"save fixture missing"}
	var state_id := str(fixture.get("state_id", ""))
	var route_id := str(fixture.get("route_id", ""))
	var waypoint_id := str(fixture.get("waypoint_id", ""))
	var threshold_id := str(fixture.get("threshold_id", ""))
	if state_id.is_empty() or route_id.is_empty() or waypoint_id.is_empty() \
			or threshold_id.is_empty():
		return {"status":"BLOCKED",
				"reason":"semantic state/route/waypoint/threshold fixture is incomplete"}
	var required_cells: Array[String] = Support.string_array(fixture.get(
			"required_cell_ids", Support.TARGET_CELL_IDS))
	var canonical_cells: Array[String] = Support.string_array(Support.TARGET_CELL_IDS)
	required_cells.sort()
	canonical_cells.sort()
	if required_cells != canonical_cells:
		return {"status":"FAIL",
				"reason":"save reconstruction must destroy/rebuild all 17 target cells"}
	var prior_state := _snapshot_reality_state()
	var test_path := "user://m11c1/runtime_reconstruction_%d.json" \
			% Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			test_path).get_base_dir())
	RealityState.save_path = test_path
	RealityState.persistence_enabled = true
	RealityState.reset_campaign_for_tests()

	var packed := load(M11A_SCENE) as PackedScene
	# The production M11A exterior module is an independent spatial authority.
	# Rebuild and release the owner-first cells before creating it so save proof
	# cannot accidentally double-mount street/bodega geometry or collision.
	var first_cells: Dictionary = await _save_full_cell_phase(
			inputs, "pre_save_full_recomposition")
	var first_cells_released_before_m11a := str(first_cells.get(
			"status", "FAIL")) == "PASS" and bool(first_cells.get(
			"owner_released", false))
	var first_module := packed.instantiate() as Node3D if packed != null else null
	if first_module != null:
		add_child(first_module)
	await _settle()
	var first_started := first_module != null \
			and not bool(first_module.get("startup_failed"))
	var first_resolver: Variant = first_module.get("spatial_resolver") \
			if first_module != null else null
	var semantic_state := OrisonV2ExteriorSemanticState.new()
	var recorded := first_started and first_cells_released_before_m11a \
			and semantic_state.record_progress(state_id, first_resolver, route_id,
					waypoint_id, threshold_id)
	var canonical_semantics: Dictionary = semantic_state.snapshot(state_id) \
			if recorded else {}
	var forbidden := _find_forbidden_save_fact(canonical_semantics,
			"exterior_semantics.%s" % state_id)
	var saved := recorded and forbidden.is_empty() and RealityState.save_game()
	var file_hash := Support.file_sha256(test_path) if saved else ""

	var first_module_weak: WeakRef = weakref(first_module) \
			if first_module != null else null
	var first_player_weak: WeakRef = weakref(first_module.get("player")) \
			if first_module != null and first_module.get("player") is Object \
			else null
	var first_module_teardown: Dictionary = first_module.call("teardown") as Dictionary \
			if first_module != null and first_module.has_method("teardown") else {}
	if first_module != null:
		first_module.queue_free()
	first_module = null
	first_resolver = null
	await _settle()
	var first_roots_released := (first_module_weak == null \
			or first_module_weak.get_ref() == null) \
			and (first_player_weak == null or first_player_weak.get_ref() == null)

	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	var loaded_value: Variant = RealityState.data.get("exterior_semantics", {})
	var loaded_semantics: Dictionary = (loaded_value as Dictionary).duplicate(true) \
			if loaded_value is Dictionary else {}
	var second_cells: Dictionary = await _save_full_cell_phase(
			inputs, "post_load_full_recomposition")
	var second_cells_released_before_m11a := str(second_cells.get(
			"status", "FAIL")) == "PASS" and bool(second_cells.get(
			"owner_released", false))
	var second_module := packed.instantiate() as Node3D if packed != null else null
	if second_module != null:
		add_child(second_module)
	await _settle()
	var second_started := second_cells_released_before_m11a \
			and second_module != null \
			and not bool(second_module.get("startup_failed"))
	var second_resolver: Variant = second_module.get("spatial_resolver") \
			if second_module != null else null
	var reconstructed_state := OrisonV2ExteriorSemanticState.new()
	var reconstructed: Dictionary = reconstructed_state.reconstruct(
			state_id, second_resolver) if second_started else {}
	var cursor: Dictionary = reconstructed.get("cursor", {})
	var placement: Dictionary = cursor.get("placement", {})
	var expected_position: Vector3 = placement.get("position", Vector3.INF) \
			if placement.get("position", Vector3.INF) is Vector3 else Vector3.INF
	var placement_consumed := second_started and not reconstructed.is_empty() \
			and second_module.has_method("place_player_at_route_waypoint") \
			and bool(second_module.call("place_player_at_route_waypoint", route_id,
					waypoint_id))
	for _frame: int in range(8):
		await get_tree().physics_frame
	var reconstructed_player: PlayerController = null
	if second_module != null:
		reconstructed_player = second_module.get("player") as PlayerController
	var placement_grounded := placement_consumed \
			and is_instance_valid(reconstructed_player) \
			and reconstructed_player.global_position.distance_to(
					expected_position) <= 0.10 and reconstructed_player.is_on_floor()
	var identities_exact := str(reconstructed.get("route_id", "")) == route_id \
			and str(reconstructed.get("waypoint_id", "")) == waypoint_id \
			and str(reconstructed.get("threshold_id", "")) == threshold_id
	var reconstructed_semantics: Dictionary = reconstructed_state.snapshot(state_id)
	# RealityState is JSON-backed. Compare every key and value after the same
	# canonical JSON round-trip so legitimate integer/float and Variant-backed
	# vector representation changes do not create a false difference. The
	# exact strings and their hashes are receipted below; no key is discarded.
	var canonical_json := _canonical_json(canonical_semantics)
	var loaded_json := _canonical_json(loaded_semantics.get(state_id, {}))
	var reconstructed_json := _canonical_json(reconstructed_semantics)
	var semantic_exact: bool = not canonical_json.is_empty() \
			and loaded_json == canonical_json \
			and reconstructed_json == canonical_json

	var second_module_weak: WeakRef = weakref(second_module) \
			if second_module != null else null
	var second_player_weak: WeakRef = weakref(reconstructed_player) \
			if reconstructed_player != null else null
	var second_module_teardown: Dictionary = second_module.call("teardown") as Dictionary \
			if second_module != null and second_module.has_method("teardown") else {}
	if second_module != null:
		second_module.queue_free()
	second_module = null
	second_resolver = null
	reconstructed_player = null
	packed = null
	await _settle()
	var second_roots_released := (second_module_weak == null \
			or second_module_weak.get_ref() == null) \
			and (second_player_weak == null or second_player_weak.get_ref() == null)

	var state_restoration := _restore_reality_state(prior_state)
	var absolute := ProjectSettings.globalize_path(test_path)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)
	var test_file_removed := not FileAccess.file_exists(absolute)
	var ok: bool = first_cells_released_before_m11a \
			and second_cells_released_before_m11a and first_started \
			and second_started and recorded and saved and not file_hash.is_empty() \
			and forbidden.is_empty() and first_roots_released \
			and second_roots_released and semantic_exact and identities_exact \
			and placement_grounded and bool(state_restoration.get("restored", false)) \
			and test_file_removed
	return {
		"status":"PASS" if ok else "FAIL",
		"production_authorities":["RealityState",
				"OrisonV2ExteriorSemanticState", "OrisonV2ExteriorCell"],
		"public_apis":["record_progress", "save_game", "teardown",
				"load_game", "reconstruct", "place_player_at_route_waypoint"],
		"isolated_test_path":test_path,
		"isolated_file_sha256":file_hash,
		"saved":saved,
		"state_id":state_id,
		"route_id":route_id,
		"waypoint_id":waypoint_id,
		"threshold_id":threshold_id,
		"canonical_semantic_cursor":canonical_semantics,
		"loaded_semantic_cursor":loaded_semantics.get(state_id, {}),
		"semantic_roundtrip_exact":semantic_exact,
		"semantic_canonical_json":{
			"pre_save":canonical_json,
			"loaded":loaded_json,
			"reconstructed":reconstructed_json,
		},
		"semantic_canonical_sha256":{
			"pre_save":canonical_json.sha256_text(),
			"loaded":loaded_json.sha256_text(),
			"reconstructed":reconstructed_json.sha256_text(),
		},
		"reconstructed_cursor":reconstructed,
		"semantic_identities_exact":identities_exact,
		"public_route_placement_consumed":placement_consumed,
		"reconstruction_player_grounded":placement_grounded,
		"reconstruction_expected_position":Support.vector3_array(
				expected_position) if expected_position.is_finite() else [],
		"first_full_cell_load":first_cells,
		"second_full_cell_load":second_cells,
		"adaptation_topology":"serial owner-first cell rebuild and isolated M11A semantic reconstruction",
		"m11a_and_target_cells_co_mounted":false,
		"first_cells_released_before_m11a":first_cells_released_before_m11a,
		"second_cells_released_before_m11a":second_cells_released_before_m11a,
		"first_module_teardown":first_module_teardown,
		"first_roots_released":first_roots_released,
		"second_module_teardown":second_module_teardown,
		"second_roots_released":second_roots_released,
		"reality_state_restoration":state_restoration,
		"selector_persisted":false,
		"gltf_path_persisted":false,
		"node_path_persisted":false,
		"raw_world_coordinate_persisted":false,
		"forbidden_fact_scan":forbidden,
		"test_file_removed":test_file_removed,
	}


func _save_full_cell_phase(inputs: Dictionary, phase_id: String) -> Dictionary:
	var before := Support.object_counts()
	var adapter = AdapterScript.new()
	var configured: bool = adapter.configure(inputs)
	add_child(adapter)
	var mounted: Dictionary = adapter.mount_residency(
			"FULL_RECOMPOSITION", false) if configured else {"ok":false}
	await _settle()
	var metrics := Support.tree_metrics(adapter.registry) if configured else {}
	var mounted_ids: Array[String] = adapter.registry.mounted_cell_ids() \
			if configured and adapter.registry.has_method("mounted_cell_ids") else []
	var complete := bool(mounted.get("ok", false)) \
			and mounted_ids.size() == Support.TARGET_CELL_IDS.size()
	var teardown: Dictionary = adapter.public_teardown()
	var adapter_weak: WeakRef = weakref(adapter)
	adapter.queue_free()
	adapter = null
	await _settle()
	var released := adapter_weak.get_ref() == null
	return {
		"status":"PASS" if configured and complete and released else "FAIL",
		"phase":phase_id,
		"residency_set":"FULL_RECOMPOSITION",
		"configured":configured,
		"mounted":mounted,
		"mounted_cell_ids":mounted_ids,
		"metrics":metrics,
		"public_teardown":teardown,
		"owner_released":released,
		"m11a_mounted_during_phase":false,
		"delta":Support.object_delta(Support.object_counts(), before),
	}


func _find_forbidden_save_fact(value: Variant, path: String) -> String:
	if value is Dictionary:
		for raw_key: Variant in value:
			var key := str(raw_key).to_lower()
			if key in ["selector", "gltf", "gltf_path", "node_path",
					"world_position", "position", "transform", "coordinates"]:
				return "%s.%s is forbidden durable geometry/session state" % [path, key]
			var nested := _find_forbidden_save_fact(value[raw_key],
					"%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
	elif value is Array:
		for index in value.size():
			var nested := _find_forbidden_save_fact(value[index],
					"%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
	elif value is String and (value.contains("res://") \
			or value.to_lower().contains("floor_01.gltf")):
		return "%s persists a resource/GLTF path" % path
	return ""


func _exercise_seams(cycle_id: String,
		inputs: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var config: Dictionary = inputs.get("config", {})
	for raw: Variant in config.get("seams", []):
		if raw is Dictionary:
			rows.append(await _exercise_seam(cycle_id, raw, inputs))
	return rows


func _exercise_seam(cycle_id: String, seam: Dictionary,
		inputs: Dictionary) -> Dictionary:
	var seam_id := str(seam.get("id", ""))
	var cell_ids: Array[String] = Support.string_array(seam.get("cell_ids", []))
	var before := Support.object_counts()
	var adapter = AdapterScript.new()
	if not adapter.configure(inputs):
		_fail("%s adapter refused configuration" % seam_id)
		return {"status":"FAIL", "id":seam_id}
	add_child(adapter)
	var mounted: Dictionary = adapter.mount_explicit_cells(cell_ids, false)
	if not bool(mounted.get("ok", false)):
		var reason := "%s requires imported res:// cells preserving -col/-colonly" % seam_id
		_block(reason)
		var teardown: Dictionary = adapter.public_teardown()
		adapter.queue_free()
		await _settle()
		return {"status":"BLOCKED", "id":seam_id, "reason":reason,
				"cell_ids":cell_ids, "loads":mounted.get("loads", []),
				"public_teardown":teardown}
	await _settle()
	var layout := _load_layout()
	var marker_adapter = MarkerAdapterScript.new()
	marker_adapter.name = "M11C1RealMarkerDoorAdapter"
	adapter.composition_host.add_child(marker_adapter)
	var semantic_index: Dictionary = inputs.get("semantic_index", {})
	var door_mount: Dictionary = marker_adapter.mount_doors(layout,
			semantic_index, Support.string_array(seam.get(
					"door_identities", [])), cell_ids)
	if str(door_mount.get("status", "PASS")) != "PASS":
		_fail("%s could not mount real source-owned DoorProp set" % seam_id)
	await get_tree().physics_frame
	var collision_probes := _run_collision_probes(seam, adapter)
	var traversals: Array[Dictionary] = []
	for raw: Variant in seam.get("traversals", []):
		if raw is Dictionary:
			traversals.append(await _run_player_traversal(seam, raw, adapter,
					marker_adapter))
	var nav := await _exercise_resident_nav_queries(adapter, inputs, layout,
			seam_id)
	var status := "PASS"
	for probe: Dictionary in collision_probes:
		if str(probe.get("status", "FAIL")) != "PASS":
			status = "FAIL"
	for traversal: Dictionary in traversals:
		if str(traversal.get("status", "FAIL")) != "PASS":
			status = str(traversal.get("status", "FAIL"))
	if str(nav.get("status", "PASS")) != "PASS":
		status = str(nav.get("status", "BLOCKED"))
	if status == "FAIL":
		_fail("bidirectional seam traversal failed: %s" % seam_id)
	elif status == "BLOCKED":
		_block("navigation seam is blocked: %s — %s" % [seam_id,
				nav.get("reason", "")])
	var metrics := Support.tree_metrics(adapter.registry)
	var marker_teardown: Dictionary = marker_adapter.public_teardown()
	marker_adapter.queue_free()
	marker_adapter = null
	var teardown: Dictionary = adapter.public_teardown()
	var adapter_id := adapter.get_instance_id()
	adapter.queue_free()
	adapter = null
	await _settle()
	var released := instance_from_id(adapter_id) == null
	if not released:
		_fail("%s retained its seam composition" % seam_id)
	return {
		"status":status,
		"id":seam_id,
		"root":"M11C1ConsumerAdaptation/OwnerFirstGeometryCells",
		"profile":_profile_label(),
		"residency_set":"EXPLICIT_DANGEROUS_SEAM_SET",
		"cell_ids":cell_ids,
		"simulation_state":"production PlayerController + physics + scoped ResidentNav",
		"traversals":traversals,
		"collision_regression_probes":collision_probes,
		"source_owned_door_mount":door_mount,
		"door_teardown":marker_teardown,
		"resident_nav":nav,
		"metrics":metrics,
		"performance":_labeled_performance(seam_id, cell_ids,
				"production PlayerController traversal complete"),
		"public_teardown":teardown,
		"owner_released":released,
		"delta":Support.object_delta(Support.object_counts(), before),
		"cycle":cycle_id,
	}


func _run_collision_probes(seam: Dictionary, adapter: Node3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var state := adapter.get_world_3d().direct_space_state
	for raw: Variant in seam.get("collision_probes", []):
		if raw is not Dictionary:
			continue
		var probe := raw as Dictionary
		var from := Support.vector3(probe.get("from", []))
		var to := Support.vector3(probe.get("to", []))
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var hit := state.intersect_ray(query)
		var owner := _collider_cell_id(hit.get("collider")) \
				if not hit.is_empty() else ""
		var collider := hit.get("collider") as Node \
				if hit.get("collider") is Node else null
		var expected := str(probe.get("expected_owner_cell", ""))
		var forbidden := str(probe.get("forbidden_owner_cell", ""))
		var hit_position: Vector3 = hit.get("position", Vector3.INF) \
				if not hit.is_empty() else Vector3.INF
		var ok := not hit.is_empty() and owner == expected \
				and (forbidden.is_empty() or owner != forbidden)
		rows.append({
			"status":"PASS" if ok else "FAIL",
			"id":probe.get("id", ""),
			"from":Support.vector3_array(from),
			"to":Support.vector3_array(to),
			"hit":not hit.is_empty(),
			"hit_position":Support.vector3_array(hit_position) \
					if hit_position.is_finite() else [],
			"hit_owner_cell":owner,
			"expected_owner_cell":expected,
			"forbidden_owner_cell":forbidden,
			"legacy_hit_elevation_m":probe.get("legacy_hit_elevation_m"),
			"legacy_intercept_resolved":ok and not forbidden.is_empty(),
			"collider_class":hit.get("collider").get_class() \
					if hit.get("collider") is Object else "",
			"collider_name":collider.name if collider != null else "",
			"collider_ancestry":_node_ancestry(collider),
		})
	return rows


func _node_ancestry(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cursor := node
	while cursor != null and result.size() < 8:
		result.append({
			"name":cursor.name,
			"class":cursor.get_class(),
			"owner_cell":str(cursor.get_meta(&"m11c1_owner_cell", "")),
			"semantic_identity":str(cursor.get_meta(
					&"m11c1_semantic_identity", "")),
		})
		cursor = cursor.get_parent()
	return result


func _run_player_traversal(seam: Dictionary, spec: Dictionary,
		adapter: Node3D, marker_adapter: Node3D) -> Dictionary:
	var traversal_id := str(spec.get("id", ""))
	var player := PlayerController.new()
	player.name = "M11C1ProductionPlayer"
	player.position = Support.vector3(spec.get("start", []))
	var initial_position := player.position
	var door_identity := str(spec.get("door_identity", ""))
	var door_action := str(spec.get("door_action", "none"))
	var accessibility := str(spec.get("expectation", "crossable"))
	var door: DoorProp = marker_adapter.call("door", door_identity) \
			if not door_identity.is_empty() else null
	var door_interaction := {
		"identity":door_identity,
		"action":door_action,
		"expectation":accessibility,
		"production_class":door.get_class() if door != null else "",
		"leaf_state_before":door.leaf_state if door != null else "",
		"open_before":door.open if door != null else false,
		"public_interact_called":false,
	}
	if door != null and (door_action == "interact_locked_refusal" \
			or (door_action == "interact_open" and not door.open)):
		# DoorProp.interact does not require the actor to be in-tree (the
		# production npc_set_open contract also calls interact(null)). Opening
		# before the controller enters physics prevents an outward-swinging leaf
		# from sweeping through its initial capsule. This is one initial player
		# placement, not a teleport or collision waiver; the same production
		# PlayerController object is passed to the public interaction method and
		# then performs both collision-bearing traversal legs.
		door.interact(player)
		door_interaction.public_interact_called = true
		door_interaction["interaction_before_player_physics"] = true
		for _unused in 40:
			await get_tree().physics_frame
	elif door != null and door_action == "interact_open" and door.open:
		door_interaction["public_open_not_repeated_reason"] = \
				"source marker instantiated already open; interaction would close it"
	door_interaction["open_after"] = door.open if door != null else false
	door_interaction["leaf_state_after"] = door.leaf_state \
			if door != null else ""
	door_interaction["owner_cell"] = str(door.get_meta(
			&"m11c1_owner_cell", "")) if door != null else ""
	adapter.add_child(player)
	if player.camera != null:
		player.camera.current = false
	var initial_settle_frames := 0
	while not player.is_on_floor() and initial_settle_frames < 30:
		player.autopilot = Vector3.ZERO
		await get_tree().physics_frame
		initial_settle_frames += 1
	var script_path := str(player.get_script().resource_path)
	var production_script := script_path == PLAYER_SCRIPT
	var collision_bearing := not player.noclip and player.collision_layer != 0 \
			and player.collision_mask != 0
	var initial_support_owner := _support_owner(player)
	var start_supported := player.is_on_floor() \
			and not initial_support_owner.is_empty()
	var plane: Dictionary = spec.get("plane", {})
	var plane_point := Support.vector3(plane.get("point", []))
	var plane_normal := Support.vector3(plane.get("normal", [])).normalized()
	var start_signed := (player.global_position - plane_point).dot(plane_normal)
	var forward := await _walk_waypoints(player,
			Support.vector3_list(spec.get("forward_waypoints", [])), spec,
			"forward")
	var forward_position := player.global_position
	var forward_signed := (forward_position - plane_point).dot(plane_normal)
	var back := await _walk_waypoints(player,
			Support.vector3_list(spec.get("return_waypoints", [])), spec,
			"return")
	var final_position := player.global_position
	var final_signed := (final_position - plane_point).dot(plane_normal)
	const MINIMUM_PLANE_OVERSHOOT_M := 0.15
	var forward_crossed := start_signed * forward_signed < 0.0 \
			and absf(start_signed) >= MINIMUM_PLANE_OVERSHOOT_M \
			and absf(forward_signed) >= MINIMUM_PLANE_OVERSHOOT_M \
			and not (forward.get("plane_crossings", []) as Array).is_empty()
	var return_crossed := forward_signed * final_signed < 0.0 \
			and absf(final_signed) >= MINIMUM_PLANE_OVERSHOOT_M \
			and not (back.get("plane_crossings", []) as Array).is_empty()
	var forward_opening := _opening_clearance(forward, spec, "forward")
	var return_opening := _opening_clearance(back, spec, "return")
	var expected_owners: Array[String] = Support.string_array(
			spec.get("expected_collision_owner_cells", []))
	var observed_owners: Array[String] = []
	for leg: Dictionary in [forward, back]:
		var leg_owners := Support.string_array(leg.get("contact_owner_cells", []))
		leg_owners.append_array(Support.string_array(leg.get(
				"support_owner_cells", [])))
		for owner: String in leg_owners:
			if owner.is_empty():
				continue
			if owner not in observed_owners:
				observed_owners.append(owner)
	var unexpected_owners: Array[String] = []
	for owner: String in observed_owners:
		if not owner.is_empty() and owner not in expected_owners:
			unexpected_owners.append(owner)
	var missing_owners: Array[String] = []
	for owner: String in expected_owners:
		if owner not in observed_owners:
			missing_owners.append(owner)
	var unknown_contacts := int(forward.get("unknown_contact_count", 0)) \
			+ int(back.get("unknown_contact_count", 0))
	var door_contact := door_identity.is_empty() \
			or door_identity in Support.string_array(forward.get(
					"contact_semantic_identities", []))
	var public_door_contract_ok := door_identity.is_empty() or (door != null \
			and ((accessibility == "crossable" and (door.open \
					and (bool(door_interaction.public_interact_called) \
					or bool(door_interaction.open_before)))) \
			or (accessibility == "locked_non_crossable" \
					and bool(door_interaction.public_interact_called))))
	var crossable_ok := bool(forward.get("reached", false)) \
			and bool(back.get("reached", false)) and forward_crossed \
			and return_crossed and bool(forward_opening.get("passed", false)) \
			and bool(return_opening.get("passed", false)) \
			and (door == null or door.open)
	var locked_ok := accessibility == "locked_non_crossable" \
			and door != null and door.leaf_state == "locked" and not door.open \
			and not bool(forward.get("reached", false)) and not forward_crossed \
			and bool(back.get("reached", false)) and door_contact \
			and str(spec.get("shop_cell_id", "")) == "CELL_SHOP_NEWS_CIGARS"
	var accessibility_ok := locked_ok if accessibility == "locked_non_crossable" \
			else crossable_ok
	var ok := production_script and collision_bearing and start_supported \
			and accessibility_ok and public_door_contract_ok \
			and unexpected_owners.is_empty() \
			and missing_owners.is_empty() and unknown_contacts == 0 \
			and not observed_owners.is_empty()
	player.autopilot = Vector3.ZERO
	var player_id := player.get_instance_id()
	player.queue_free()
	player = null
	await _settle()
	var released := instance_from_id(player_id) == null
	ok = ok and released
	return {
		"status":"PASS" if ok else "FAIL",
		"id":traversal_id,
		"production_player_class":"PlayerController",
		"production_player_script":script_path,
		"production_player_script_sha256":Support.file_sha256(PLAYER_SCRIPT),
		"body_radius_m":PlayerController.BODY_RADIUS,
		"body_height_m":PlayerController.STANDING_HEIGHT,
		"collision_bearing":collision_bearing,
		"noclip":false,
		"initial_placement_count":1,
		"intermediate_transform_writes":0,
		"teleport_count":0,
		"initial_position":Support.vector3_array(initial_position),
		"initial_supported":start_supported,
		"initial_support_owner_cell":initial_support_owner,
		"initial_grounded_settle_frames":initial_settle_frames,
		"forward":forward,
		"return":back,
		"door_interaction":door_interaction,
		"public_door_contract_satisfied":public_door_contract_ok,
		"proof_class":"LOCKED_COLLISION_BOUNDARY" \
				if accessibility == "locked_non_crossable" \
				else "BIDIRECTIONAL_ACCESSIBLE_ROUTE",
		"accessible_route_proven":accessibility == "crossable" and crossable_ok,
		"locked_boundary_proven":accessibility == "locked_non_crossable" and locked_ok,
		"plane":{
			"point":Support.vector3_array(plane_point),
			"normal":Support.vector3_array(plane_normal),
			"minimum_endpoint_overshoot_m":MINIMUM_PLANE_OVERSHOOT_M,
			"start_signed_m":start_signed,
			"forward_signed_m":forward_signed,
			"return_signed_m":final_signed,
			"forward_crossed_with_margin":forward_crossed,
			"return_crossed_with_margin":return_crossed,
		},
		"forward_path_distance_m":forward.get("path_distance_m", 0.0),
		"forward_opening_clearance":forward_opening,
		"return_opening_clearance":return_opening,
		"expected_collision_owner_cells":expected_owners,
		"observed_collision_owner_cells":observed_owners,
		"missing_collision_owner_cells":missing_owners,
		"unexpected_collision_owner_cells":unexpected_owners,
		"unknown_contact_count":unknown_contacts,
		"player_released":released,
	}


func _walk_waypoints(player: PlayerController,
		waypoints: Array[Vector3], spec: Dictionary, direction_id: String) -> Dictionary:
	var tolerance := float(spec.get("waypoint_tolerance_m", 0.14))
	var vertical_tolerance := float(spec.get("vertical_tolerance_m", 0.22))
	var max_frames := int(spec.get("max_frames_per_waypoint", 360))
	var minimum_grounded := maxf(0.90, float(spec.get(
			"minimum_grounded_fraction", 0.90)))
	var samples := 0
	var grounded := 0
	var collision_frames := 0
	var path_distance := 0.0
	var contact_owners: Array[String] = []
	var support_owners: Array[String] = []
	var contact_semantics: Array[String] = []
	var contacts: Array[Dictionary] = []
	var plane_crossings: Array[Dictionary] = []
	var unknown_contacts := 0
	var waypoint_rows: Array[Dictionary] = []
	var reached_all := true
	var previous := player.global_position
	for waypoint_index in waypoints.size():
		var target := waypoints[waypoint_index]
		var frames := 0
		while not _waypoint_reached(player.global_position, target, tolerance,
				vertical_tolerance) \
				and frames < max_frames:
			var delta := target - player.global_position
			delta.y = 0.0
			player.autopilot = delta.normalized() if delta.length_squared() > 0.0001 \
					else Vector3.ZERO
			await get_tree().physics_frame
			frames += 1
			samples += 1
			if player.is_on_floor():
				grounded += 1
			path_distance += previous.distance_to(player.global_position)
			var crossing := _plane_crossing(previous, player.global_position,
					spec.get("plane", {}))
			if not crossing.is_empty():
				plane_crossings.append(crossing)
			previous = player.global_position
			var support_owner := _support_owner(player)
			if not support_owner.is_empty() and support_owner not in support_owners:
				support_owners.append(support_owner)
			if player.get_slide_collision_count() > 0:
				collision_frames += 1
			for collision_index in player.get_slide_collision_count():
				var collision: KinematicCollision3D = player.get_slide_collision(
						collision_index)
				var owner := _collider_cell_id(collision.get_collider())
				var semantic := _collider_semantic_id(collision.get_collider())
				if owner.is_empty():
					unknown_contacts += 1
				elif owner not in contact_owners:
					contact_owners.append(owner)
				if not semantic.is_empty() and semantic not in contact_semantics:
					contact_semantics.append(semantic)
				if contacts.size() < 64:
					contacts.append({
						"position":Support.vector3_array(collision.get_position()),
						"normal":Support.vector3_array(collision.get_normal()),
						"owner_cell":owner,
						"semantic_identity":semantic,
						"collider_class":collision.get_collider().get_class()
								if collision.get_collider() is Object else "",
					})
		var reached := _waypoint_reached(player.global_position, target, tolerance,
				vertical_tolerance)
		waypoint_rows.append({
			"index":waypoint_index,
			"target":Support.vector3_array(target),
			"finish":Support.vector3_array(player.global_position),
			"remaining_horizontal_m":_planar_distance(player.global_position, target),
			"remaining_vertical_m":absf(player.global_position.y - target.y),
			"frames":frames,
			"reached":reached,
		})
		if not reached:
			reached_all = false
			break
	player.autopilot = Vector3.ZERO
	await get_tree().physics_frame
	var grounded_fraction := float(grounded) / maxf(1.0, float(samples))
	return {
		"id":direction_id,
		"reached":reached_all and grounded_fraction >= minimum_grounded,
		"waypoints":waypoint_rows,
		"path_distance_m":path_distance,
		"physics_frames":samples,
		"grounded_frames":grounded,
		"grounded_fraction":grounded_fraction,
		"minimum_grounded_fraction":minimum_grounded,
		"collision_frames":collision_frames,
		"collision_fraction":float(collision_frames) / maxf(1.0, float(samples)),
		"contact_owner_cells":contact_owners,
		"support_owner_cells":support_owners,
		"contact_semantic_identities":contact_semantics,
		"contact_samples":contacts,
		"unknown_contact_count":unknown_contacts,
		"plane_crossings":plane_crossings,
		"vertical_tolerance_m":vertical_tolerance,
	}


func _waypoint_reached(at: Vector3, target: Vector3,
		horizontal_tolerance: float, vertical_tolerance: float) -> bool:
	return _planar_distance(at, target) <= horizontal_tolerance \
			and absf(at.y - target.y) <= vertical_tolerance


func _plane_crossing(first: Vector3, second: Vector3,
		raw_plane: Variant) -> Dictionary:
	if raw_plane is not Dictionary:
		return {}
	var point := Support.vector3(raw_plane.get("point", []))
	var normal := Support.vector3(raw_plane.get("normal", [])).normalized()
	if not point.is_finite() or not normal.is_finite():
		return {}
	var first_signed := (first - point).dot(normal)
	var second_signed := (second - point).dot(normal)
	if first_signed * second_signed > 0.0 \
			or is_equal_approx(first_signed, second_signed):
		return {}
	var amount := first_signed / (first_signed - second_signed)
	if amount < 0.0 or amount > 1.0:
		return {}
	var crossing := first.lerp(second, amount)
	return {"point":Support.vector3_array(crossing),
			"from_signed_m":first_signed, "to_signed_m":second_signed,
			"segment_fraction":amount}


func _opening_clearance(leg: Dictionary, spec: Dictionary,
		direction_id: String) -> Dictionary:
	var crossings: Array = leg.get("plane_crossings", [])
	var opening: Dictionary = spec.get("opening_bounds", {})
	if crossings.is_empty() or opening.is_empty():
		return {"passed":false, "reason":"no actual plane intersection/opening"}
	var crossing := Support.vector3((crossings[0] as Dictionary).get("point", []))
	var centre := Support.vector3(opening.get("center", []))
	var right := Support.vector3(opening.get("right_axis", [])).normalized()
	var half_width := float(opening.get("half_width_m", 0.0))
	var bottom := float(opening.get("bottom_y_m", 0.0))
	var top := float(opening.get("top_y_m", 0.0))
	var side_clearance := half_width \
			- absf((crossing - centre).dot(right)) - PlayerController.BODY_RADIUS
	var head_clearance := top \
			- (crossing.y + PlayerController.STANDING_HEIGHT)
	var foot_clearance := crossing.y - bottom
	var required_side := float(opening.get("minimum_side_clearance_m", 0.02))
	var required_head := float(opening.get("minimum_head_clearance_m", 0.02))
	var passed := crossing.is_finite() and side_clearance >= required_side \
			and head_clearance >= required_head and foot_clearance >= -0.08
	return {
		"passed":passed,
		"direction":direction_id,
		"actual_crossing_point":Support.vector3_array(crossing),
		"opening_center":Support.vector3_array(centre),
		"opening_width_m":half_width * 2.0,
		"opening_height_m":top - bottom,
		"production_capsule_diameter_m":PlayerController.BODY_RADIUS * 2.0,
		"production_capsule_height_m":PlayerController.STANDING_HEIGHT,
		"side_clearance_m":side_clearance,
		"head_clearance_m":head_clearance,
		"foot_clearance_m":foot_clearance,
		"minimum_side_clearance_m":required_side,
		"minimum_head_clearance_m":required_head,
		"source":"authored opening bounds + actual production-controller plane intersection",
	}


func _support_owner(player: PlayerController) -> String:
	var query := PhysicsRayQueryParameters3D.create(
			player.global_position + Vector3.UP * 0.18,
			player.global_position + Vector3.DOWN * 0.30)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return _collider_cell_id(hit.get("collider")) if not hit.is_empty() else ""


func _exercise_resident_nav_queries(adapter: Node3D, inputs: Dictionary,
		layout: Dictionary, seam_filter: String) -> Dictionary:
	if layout.is_empty():
		return {"status":"BLOCKED", "reason":"unchanged runtime layout unavailable"}
	var f01: Dictionary = {}
	for raw: Variant in layout.get("floors", []):
		if raw is Dictionary and str(raw.get("id", "")) == "F01":
			f01 = (raw as Dictionary).duplicate(true)
			break
	if f01.is_empty():
		return {"status":"BLOCKED", "reason":"F01 authoring record unavailable"}
	var nav := ResidentNav.new()
	nav.name = "M11C1RealResidentNav"
	adapter.add_child(nav)
	var node_count := nav.build({"floors":[f01]})
	await get_tree().physics_frame
	nav.validate_with_collision(adapter.get_world_3d())
	var rows: Array[Dictionary] = []
	var failed := false
	var matched := 0
	var config: Dictionary = inputs.get("config", {})
	for raw: Variant in config.get("resident_nav_queries", []):
		if raw is not Dictionary:
			continue
		var query := raw as Dictionary
		if seam_filter != "ALL" and str(query.get("seam_id", "")) != seam_filter:
			continue
		matched += 1
		var route_from := Support.vector3(query.get("from", []))
		var route_to := Support.vector3(query.get("to", []))
		var terminal_tolerance := float(query.get("terminal_tolerance_m", 0.20))
		var forward := _resident_route_direction(nav, route_from, route_to,
				terminal_tolerance, "forward")
		var reverse := _resident_route_direction(nav, route_to, route_from,
				terminal_tolerance, "reverse")
		var expected_reachable := bool(query.get("expected_reachable", true))
		var passed := not expected_reachable or (str(forward.get(
				"status", "FAIL")) == "PASS" and str(reverse.get(
				"status", "FAIL")) == "PASS")
		var passage_place := str(query.get("passage_place", ""))
		var passage_anchor := Vector3.INF
		var passage_route := PackedVector3Array()
		if not passage_place.is_empty():
			passage_anchor = nav.passage_anchor(passage_place)
			passage_route = nav.passage_route(passage_place)
			passed = passed and nav.has_passage_anchor(passage_place) \
					and passage_anchor.is_finite() \
					and passage_anchor.distance_to(route_to) <= terminal_tolerance \
					and passage_route.size() > 1
		failed = failed or not passed
		rows.append({
			"id":query.get("id", ""),
			"seam_id":query.get("seam_id", ""),
			"from":Support.vector3_array(route_from),
			"to":Support.vector3_array(route_to),
			"forward":forward,
			"reverse":reverse,
			"route":forward.get("route", []),
			"route_point_count":forward.get("route_point_count", 0),
			"expected_reachable":expected_reachable,
			"origin_distance_m":forward.get("origin_distance_m", INF),
			"terminal_distance_m":forward.get("terminal_distance_m", INF),
			"terminal_tolerance_m":terminal_tolerance,
			"finite_points":forward.get("finite_points", false) \
					and reverse.get("finite_points", false),
			"passage_place":passage_place,
			"passage_anchor":Support.vector3_array(passage_anchor) \
					if passage_anchor.is_finite() else [],
			"passage_route_point_count":passage_route.size(),
			"status":"PASS" if passed else "FAIL",
		})
	var reason := ""
	if matched == 0:
		reason = "no explicit production ResidentNav query for %s" % seam_filter
	var unreachable := nav.unreachable_route_count()
	failed = failed or unreachable != 0
	var status := "BLOCKED" if matched == 0 else ("FAIL" if failed else "PASS")
	return {
		"status":status,
		"reason":reason,
		"production_class":"ResidentNav",
		"public_apis":["build", "validate_with_collision", "route"],
		"layout_scope":"unchanged F01 authoring record only",
		"active_world_scope":adapter.registry.mounted_cell_ids(),
		"graph_nodes":node_count,
		"collision_cut":nav.collision_cut,
		"collision_relinked":nav.collision_relinked,
		"stair_blocked":nav.stair_blocked,
		"unreachable_route_count":unreachable,
		"unreachable_route_keys":nav.unreachable_route_keys(),
		"collision_validation_executed":true,
		"queries":rows,
	}


func _resident_route_direction(nav: ResidentNav, route_from: Vector3,
		route_to: Vector3, tolerance: float, direction_id: String) -> Dictionary:
	var route := nav.route(route_from, route_to)
	var finite := true
	var points: Array = []
	for point: Vector3 in route:
		finite = finite and point.is_finite()
		points.append(Support.vector3_array(point))
	var terminal_distance := route[-1].distance_to(route_to) \
			if not route.is_empty() else INF
	var origin_distance := route[0].distance_to(route_from) \
			if not route.is_empty() else INF
	var unreachable := nav.unreachable_route_count()
	var unreachable_keys: Array = nav.unreachable_route_keys()
	var passed := route.size() > 1 and finite \
			and origin_distance <= tolerance and terminal_distance <= tolerance \
			and unreachable == 0 and unreachable_keys.is_empty()
	return {
		"status":"PASS" if passed else "FAIL",
		"direction":direction_id,
		"from":Support.vector3_array(route_from),
		"to":Support.vector3_array(route_to),
		"route":points,
		"route_point_count":route.size(),
		"finite_points":finite,
		"origin_distance_m":origin_distance,
		"terminal_distance_m":terminal_distance,
		"terminal_tolerance_m":tolerance,
		"unreachable_route_count":unreachable,
		"unreachable_route_keys":unreachable_keys,
	}


func _canonical_json(value: Variant) -> String:
	# Sorted keys and full-precision numbers make the machine comparison and
	# hash deterministic. Parsing once normalizes every side to the exact
	# representation the production JSON save boundary supports.
	var encoded := JSON.stringify(value, "", true, true)
	var parsed: Variant = JSON.parse_string(encoded)
	return JSON.stringify(parsed, "", true, true) if parsed != null else ""


func _semantic_receipt(inputs: Dictionary) -> Dictionary:
	var index: Dictionary = inputs.get("semantic_index", {})
	var rows: Array[Dictionary] = []
	for identity: Variant in index:
		var entry: Dictionary = (index[identity] as Dictionary).duplicate(true)
		entry["identity"] = str(identity)
		rows.append(entry)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.identity) < str(b.identity))
	var special := _semantic_subset(index, Support.SPECIAL_SEMANTICS)
	var site_shop := _semantic_prefix(index, "SITE_SHOP_")
	var complete := not rows.is_empty() and not site_shop.is_empty() \
			and not (index.get("THRESHOLD_SHOP_BODEGA_FRONT", {}) \
					as Dictionary).is_empty()
	for row: Dictionary in special:
		complete = complete and not row.is_empty() and row.size() > 1
	return {
		"status":"PASS" if complete else "FAIL",
		"source":"lineage.semantic_owners",
		"identity_count":rows.size(),
		"unique_identity_count":index.size(),
		"special_results":special,
		"site_shop_results":site_shop,
		"bodega_identity_distinction":{
			"v1":index.get("F01_BODEGA_DOOR", {}),
			"v2":index.get("THRESHOLD_SHOP_BODEGA_FRONT", {}),
			"conflated":false,
		},
		"rows":rows,
	}


func _semantic_subset(index: Dictionary, ids: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for identity: Variant in ids:
		var row: Dictionary = (index.get(identity, {}) as Dictionary).duplicate(true)
		row["identity"] = str(identity)
		rows.append(row)
	return rows


func _semantic_prefix(index: Dictionary, prefix: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for identity: Variant in index:
		if str(identity).begins_with(prefix):
			var row: Dictionary = (index[identity] as Dictionary).duplicate(true)
			row["identity"] = str(identity)
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.identity) < str(b.identity))
	return rows


func _load_layout() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			LAYOUT_PATH)) if FileAccess.file_exists(LAYOUT_PATH) else null
	if parsed is not Dictionary:
		_fail("unchanged runtime layout could not be read")
		return {}
	return parsed as Dictionary


func _collider_cell_id(collider: Variant) -> String:
	var node := collider as Node
	while node != null:
		if node.has_meta(&"m11c1_owner_cell"):
			return str(node.get_meta(&"m11c1_owner_cell"))
		node = node.get_parent()
	return ""


func _collider_semantic_id(collider: Variant) -> String:
	var node := collider as Node
	while node != null:
		if node.has_meta(&"m11c1_semantic_identity"):
			return str(node.get_meta(&"m11c1_semantic_identity"))
		node = node.get_parent()
	return ""


func _planar_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))


func _labeled_performance(root_id: String, cell_ids: Array[String],
		simulation_state: String) -> Dictionary:
	var snapshot := Support.performance_snapshot(get_viewport())
	snapshot.merge({
		"root":root_id,
		"profile":_profile_label(),
		"residency_set":cell_ids,
		"simulation_state":simulation_state,
	}, true)
	return snapshot


func _profile_label() -> String:
	return "%s/%s/%s" % [RenderingServer.get_current_rendering_method(),
			DisplayServer.get_name(), RenderingServer.get_video_adapter_name()]


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _finalize(pending: Dictionary) -> void:
	var final_counts := Support.object_counts()
	var first_plateau: Dictionary = pending.first.get("after_teardown", {})
	var second_plateau: Dictionary = pending.second.get("after_teardown", {})
	var second_growth := Support.object_delta(second_plateau, first_plateau)
	var final_from_warmed := Support.object_delta(final_counts,
			pending.warmed_baseline)
	for key: String in ["objects", "resources", "nodes", "orphan_nodes"]:
		if int(second_growth.get(key, 0)) > 0:
			_fail("second cycle retains additional %s" % key)
		if int(final_from_warmed.get(key, 0)) > 0:
			_fail("two recorded cycles retain %s above warmed baseline" % key)
	var receipt := _base_receipt(pending.inputs)
	var retained_flags: Array[Dictionary] = []
	_collect_retained_flags(pending.first, "cycles[0]", retained_flags)
	_collect_retained_flags(pending.second, "cycles[1]", retained_flags)
	receipt.merge({
		"process_start":pending.process_start,
		"warmup":pending.warmup,
		"warmed_baseline":pending.warmed_baseline,
		"cycles":[pending.first, pending.second],
		"between_cycles":pending.between_cycles,
		"final_counts":final_counts,
		"lifecycle":{
			"complete_load_unload_cycles":2,
			"second_cycle_growth_from_first":second_growth,
			"final_delta_from_warmed_baseline":final_from_warmed,
			"public_apis":["M11C1CellRegistry.public_teardown",
					"M11C1ConsumerAdaptation.public_teardown"],
			"retained_tracked_owners":retained_flags,
			"retained_tracked_owner_count":retained_flags.size(),
			"forced_object_deletion":false,
			"node_name_reach_ins":false,
		},
	}, true)
	_finish(receipt)


func _base_receipt(inputs: Dictionary) -> Dictionary:
	return {
		"schema":"orison.m11c1.target-cell-runtime-rehearsal.v1",
		"status":"PENDING",
		"authority":"disposable_harness_only",
		"root":"M11C1OwnerFirstHarness",
		"profile":_profile_label(),
		"simulation_state":"production physics and real production consumer APIs",
		"engine":Engine.get_version_info(),
		"input_provenance":{
			"config":inputs.get("config_path", ""),
			"config_sha256":inputs.get("config_sha256", ""),
			"partition":inputs.get("partition_path", ""),
			"partition_sha256":inputs.get("partition_sha256", ""),
			"lineage":inputs.get("lineage_path", ""),
			"lineage_sha256":inputs.get("lineage_sha256", ""),
			"equivalence":inputs.get("equivalence_path", ""),
			"equivalence_sha256":inputs.get("equivalence_sha256", ""),
			"target_cell_count":(inputs.get("cells", []) as Array).size(),
			"legacy_mixed_present":false,
		},
		"disk":Support.disk_metrics(inputs),
		"actual_protected_hashes":Support.protected_hash_receipt(
				inputs.get("config", {})),
	}


func _finish(receipt: Dictionary) -> void:
	var state_restoration := _restore_reality_state(_reality_snapshot)
	receipt["reality_state_restoration"] = state_restoration
	if not bool(state_restoration.get("restored", false)):
		_fail("RealityState globals were not restored")
	receipt["status"] = "FAIL" if not _failures.is_empty() else (
			"BLOCKED" if not _blockers.is_empty() else "PASS")
	receipt["failures"] = _failures
	receipt["blockers"] = _blockers
	var output := OS.get_environment(RECEIPT_ENV).strip_edges()
	if output.is_empty():
		output = DEFAULT_RECEIPT
	if not Support.write_json(output, receipt):
		push_error("M11C1 RUNTIME: could not write %s" % output)
		get_tree().quit(2)
		return
	print("M11C1 OWNER-FIRST RUNTIME: %s" % receipt.status)
	get_tree().quit(2 if receipt.status == "FAIL" else (
			3 if receipt.status == "BLOCKED" else 0))


func _fail(reason: String) -> void:
	if reason not in _failures:
		_failures.append(reason)
	push_error("M11C1 RUNTIME: " + reason)


func _block(reason: String) -> void:
	if reason not in _blockers:
		_blockers.append(reason)
	push_warning("M11C1 RUNTIME BLOCKED: " + reason)


func _snapshot_reality_state() -> Dictionary:
	return {
		"data":RealityState.data.duplicate(true),
		"persistence_enabled":RealityState.persistence_enabled,
		"save_path":RealityState.save_path,
		"save_write_blocked":RealityState.save_write_blocked,
		"incompatible_save_version":RealityState.incompatible_save_version,
		"player_notice":RealityState.player_notice(),
	}


func _restore_reality_state(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {"restored":true, "reason":"snapshot not taken before input refusal"}
	RealityState.data = (snapshot.get("data", {}) as Dictionary).duplicate(true)
	RealityState.persistence_enabled = bool(snapshot.get(
			"persistence_enabled", true))
	RealityState.save_path = str(snapshot.get("save_path", RealityState.SAVE_PATH))
	RealityState.save_write_blocked = bool(snapshot.get("save_write_blocked", false))
	RealityState.incompatible_save_version = int(snapshot.get(
			"incompatible_save_version", 0))
	RealityState.set("_player_notice", (snapshot.get("player_notice", {}) \
			as Dictionary).duplicate(true))
	RealityState.state_changed.emit()
	RealityState.player_notice_changed.emit(RealityState.player_notice())
	var restored: bool = RealityState.data == snapshot.get("data", {}) \
			and RealityState.persistence_enabled == bool(snapshot.get(
					"persistence_enabled", true)) \
			and RealityState.save_path == str(snapshot.get("save_path", "")) \
			and RealityState.save_write_blocked == bool(snapshot.get(
					"save_write_blocked", false)) \
			and RealityState.incompatible_save_version == int(snapshot.get(
					"incompatible_save_version", 0)) \
			and RealityState.player_notice() == snapshot.get("player_notice", {})
	return {"restored":restored,
			"state_changed_emitted":true,
			"player_notice_changed_emitted":true,
			"signal_connections_modified":false}


func _collect_retained_flags(value: Variant, path: String,
		result: Array[Dictionary]) -> void:
	if value is Dictionary:
		for raw_key: Variant in value:
			var key := str(raw_key)
			if key in ["owner_released", "player_released"] \
					and not bool(value[raw_key]):
				result.append({"path":"%s.%s" % [path, key], "released":false})
			else:
				_collect_retained_flags(value[raw_key], "%s.%s" % [path, key], result)
	elif value is Array:
		for index in value.size():
			_collect_retained_flags(value[index], "%s[%d]" % [path, index], result)
