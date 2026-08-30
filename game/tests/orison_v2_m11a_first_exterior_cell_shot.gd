extends Node
## M11A's four-frame human-review packet. Every frame comes from the real
## PlayerController camera inside the production exterior module. The player
## receives one legitimate semantic initial placement, then reaches every
## later station through ordinary collision-bearing autopilot movement.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const CELL_SCENE := preload(
		"res://scenes/building/orison_v2_exterior_cell.tscn")

const OUTBOUND_ROUTE := "ROUTE_ORISON_TO_SHOP_BODEGA"
const RETURN_ROUTE := "ROUTE_SHOP_BODEGA_TO_ORISON"
const THRESHOLD_ID := "THRESHOLD_SHOP_BODEGA_FRONT"
const LEAF_ID := "SHOP_BODEGA_STOREFRONT_LEAF"
const EXPECTED_RESOLUTION := Vector2i(1600, 900)
const METRIC_SAMPLE_FRAMES := 8
const WALK_TOLERANCE_M := 0.38

var shots = ShotHarnessScript.new()
var cell: Node3D
var player: PlayerController
var camera: Camera3D
var frame_records: Array[Dictionary] = []
var traversal_records: Array[Dictionary] = []
var interaction_record: Dictionary = {}
var startup_counts: Dictionary = {}
var built_counts: Dictionary = {}
var teardown_record: Dictionary = {}
var cell_cost: Dictionary = {}
var _failed := false
var _failure_reasons: Array[String] = []


func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M11A-EXTERIOR", 4):
		get_tree().quit(2)
		return
	seed(1101)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("evidence capture requires the Forward+ renderer")
		await _finish_run()
		return
	startup_counts = _object_counts()
	cell = CELL_SCENE.instantiate() as Node3D
	if cell == null:
		_fail("production exterior scene did not instantiate")
		await _finish_run()
		return
	add_child(cell)
	await get_tree().process_frame
	await get_tree().physics_frame
	if bool(cell.get("startup_failed")):
		_fail("production exterior startup refused: %s" % [
				cell.get("startup_errors")])
		await _finish_run()
		return
	player = cell.get("player") as PlayerController
	if player == null or player.camera == null:
		_fail("production exterior did not compose PlayerController and camera")
		await _finish_run()
		return
	camera = player.camera
	camera.fov = 72.0
	camera.far = 90.0
	camera.make_current()
	var viewport_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if not await shots.settle(0.8, "production_cell_ready"):
		_fail("production exterior did not settle inside the capture budget")
		await _finish_run()
		return
	cell_cost = cell.call("cost_report") as Dictionary
	built_counts = _object_counts()
	shots.checkpoint("production_owners_resolved")
	await _capture_route()
	await _finish_run()


func _capture_route() -> void:
	var outbound := cell.call("route", OUTBOUND_ROUTE) as Dictionary
	var returning := cell.call("route", RETURN_ROUTE) as Dictionary
	if outbound.is_empty() or returning.is_empty():
		_fail("production semantic outbound/return route did not resolve")
		return
	var orison_exit := _route_point(outbound, "ORISON_EXIT")
	var pavement_turn := _route_point(outbound, "PAVEMENT_TURN")
	var alignment := _route_point(outbound, "BODEGA_ALIGNMENT")
	var exterior := _route_point(outbound, "BODEGA_EXTERIOR")
	var interior := _route_point(outbound, "BODEGA_INTERIOR")
	var route_overview_eye := _placement_point("STREET_ORISON_01",
			"route_overview_eye")
	var route_overview_target := _placement_point("STREET_ORISON_01",
			"route_overview_target")
	var inside_view := _placement_point("SHOP_BODEGA", "inside_view")
	if not _all_finite([orison_exit, pavement_turn, alignment, exterior,
			interior, route_overview_eye, route_overview_target, inside_view]):
		_fail("one or more public route/evidence placements are invalid")
		return
	if not bool(cell.call("place_player_at_route_waypoint", OUTBOUND_ROUTE,
			"ORISON_EXIT")):
		_fail("legitimate initial semantic player placement was refused")
		return
	traversal_records.append({
		"kind": "initial_placement",
		"route_id": OUTBOUND_ROUTE,
		"waypoint_id": "ORISON_EXIT",
		"position": _vec(player.global_position),
		"teleport_count": 1,
	})
	await get_tree().physics_frame
	if not await _walk_to(pavement_turn, "outbound:PAVEMENT_TURN"):
		return
	if not await _walk_to(route_overview_eye,
			"outbound:ROUTE_OVERVIEW_EYE"):
		return
	await _capture_frame("01_orison_side_route_beginning",
			route_overview_target, "STREET_ORISON_01:route_overview_eye",
			"Orison-side pavement route beginning")
	if _failed:
		return
	# The overview stance sits beyond the street-lamp post. Return through the
	# named pavement turn before resuming the canonical route so the production
	# controller never shortcuts through that collision-bearing fixture.
	if not await _walk_to(pavement_turn,
			"outbound:OVERVIEW_RETURN_TO_PAVEMENT_TURN"):
		return
	if not await _walk_to(alignment, "outbound:BODEGA_ALIGNMENT"):
		return
	var leaf := cell.call("interaction_leaf", LEAF_ID) as DoorProp
	if leaf == null:
		_fail("production storefront leaf did not resolve")
		return
	var leaf_target := leaf.global_transform * Vector3(leaf.width * 0.5,
			minf(1.15, leaf.height * 0.55), 0.0)
	await _capture_frame("02_bodega_threshold_approach", leaf_target,
			"BODEGA_ALIGNMENT", "bodega threshold approach")
	if _failed:
		return
	if not await _walk_to(exterior, "outbound:BODEGA_EXTERIOR"):
		return
	_aim_at(leaf_target)
	await get_tree().process_frame
	await get_tree().physics_frame
	var interaction_started := Time.get_ticks_usec()
	player.use_primary_interaction()
	var interaction_call_ms := float(Time.get_ticks_usec() \
			- interaction_started) / 1000.0
	await get_tree().create_timer(0.78, true, false, true).timeout
	interaction_record = {
		"surface": LEAF_ID,
		"public_entrypoint": "PlayerController.use_primary_interaction",
		"public_call_wall_ms": interaction_call_ms,
		"animation_settle_wait_ms": 780.0,
		"leaf_open": leaf.open,
		"player_distance_m": player.global_position.distance_to(
				leaf.global_position),
	}
	if not leaf.open:
		_fail("PlayerController targeting did not open the storefront leaf")
		return
	if not await _walk_to(interior, "outbound:BODEGA_INTERIOR"):
		return
	if not await _walk_to(inside_view, "interior:INSIDE_VIEW"):
		return
	var back_surface: Dictionary = cell.get("spatial_resolver").call(
			"resolve_surface", "SHOP_BODEGA", "back_room_threshold")
	var interior_target: Vector3 = back_surface.get("point", Vector3.INF)
	if not interior_target.is_finite():
		_fail("bodega continuing-route target did not resolve")
		return
	interior_target += Vector3.UP * 1.18
	await _capture_frame("03_bodega_interior_continuing_route",
			interior_target, "SHOP_BODEGA:inside_view",
			"bodega interior and continuing route")
	if _failed:
		return
	if not await _walk_to(interior, "return:BODEGA_INTERIOR"):
		return
	if not await _walk_to(exterior, "return:BODEGA_EXTERIOR"):
		return
	if not await _walk_to(alignment, "return:BODEGA_ALIGNMENT"):
		return
	var return_target := pavement_turn.lerp(orison_exit, 0.50) \
			+ Vector3.UP * 1.18
	await _capture_frame("04_return_direction_toward_orison",
			return_target, "BODEGA_ALIGNMENT",
			"semantic return direction toward Orison")
	if _failed:
		return
	# Complete the pictured return after the fourth frame. This keeps camera
	# evidence and traversal evidence in one uninterrupted PlayerController run.
	if not await _walk_to(pavement_turn, "return:PAVEMENT_TURN"):
		return
	await _walk_to(orison_exit, "return:ORISON_EXIT")


func _capture_frame(label: String, target: Vector3, station: String,
		description: String) -> void:
	_aim_at(target)
	await get_tree().process_frame
	var metrics := await _sample_metrics()
	var capture_ok := await shots.capture(label)
	var viewport_size := get_viewport().get_visible_rect().size
	var dimensions_ok := Vector2i(roundi(viewport_size.x),
			roundi(viewport_size.y)) == EXPECTED_RESOLUTION
	var on_floor := player.is_on_floor()
	var camera_current := get_viewport().get_camera_3d() == camera
	frame_records.append({
		"label": label,
		"file": label + ".png",
		"description": description,
		"station": station,
		"capture": "PASS" if capture_ok else "FAIL",
		"dimensions": [roundi(viewport_size.x), roundi(viewport_size.y)],
		"dimensions_ok": dimensions_ok,
		"camera_class": "playable",
		"player_height": true,
		"player_origin": _vec(player.global_position),
		"eye": _vec(camera.global_position),
		"target": _vec(target),
		"forward": _vec(-camera.global_transform.basis.z.normalized()),
		"fov_degrees": camera.fov,
		"standing_eye_m": PlayerController.STANDING_EYE,
		"camera_current": camera_current,
		"carried_lamp_visible": is_instance_valid(player.flashlight)
				and player.flashlight.visible,
		"supporting_floor": on_floor,
		"noclip": player.noclip,
		"metrics": metrics,
	})
	if not capture_ok or not dimensions_ok or not on_floor or player.noclip \
			or not camera_current:
		_fail("%s violated capture/player provenance" % label)


func _walk_to(target: Vector3, leg: String) -> bool:
	var start := player.global_position
	var start_xz := Vector2(start.x, start.z)
	var target_xz := Vector2(target.x, target.z)
	var timeout := start_xz.distance_to(target_xz) / PlayerController.WALK + 3.0
	var started_usec := Time.get_ticks_usec()
	var elapsed := 0.0
	var grounded_samples := 0
	var samples := 0
	while elapsed < timeout:
		var here := Vector2(player.global_position.x, player.global_position.z)
		if here.distance_to(target_xz) < WALK_TOLERANCE_M:
			player.autopilot = Vector3.ZERO
			player.velocity.x = 0.0
			player.velocity.z = 0.0
			var end := player.global_position
			traversal_records.append({
				"kind": "collision_bearing_walk",
				"leg": leg,
				"start": _vec(start),
				"target": _vec(target),
				"end": _vec(end),
				"distance_m": start_xz.distance_to(target_xz),
				"remaining_m": Vector2(end.x, end.z).distance_to(target_xz),
				"elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
				"grounded_fraction": float(grounded_samples) / maxf(1.0,
						float(samples)),
				"noclip": player.noclip,
				"teleport_count": 0,
				"status": "PASS",
			})
			return true
		var direction := (target_xz - here).normalized()
		player.autopilot = Vector3(direction.x, 0.0, direction.y)
		await get_tree().create_timer(0.05, true, false, true).timeout
		elapsed += 0.05
		samples += 1
		if player.is_on_floor():
			grounded_samples += 1
	player.autopilot = Vector3.ZERO
	traversal_records.append({
		"kind": "collision_bearing_walk",
		"leg": leg,
		"start": _vec(start),
		"target": _vec(target),
		"end": _vec(player.global_position),
		"remaining_m": Vector2(player.global_position.x,
				player.global_position.z).distance_to(target_xz),
		"elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		"noclip": player.noclip,
		"teleport_count": 0,
		"status": "FAIL",
	})
	_fail("collision-bearing traversal stopped short on %s" % leg)
	return false


func _sample_metrics() -> Dictionary:
	var process_samples: Array[float] = []
	var physics_samples: Array[float] = []
	var gpu_samples: Array[float] = []
	var draw_samples: Array[float] = []
	var viewport_rid := get_viewport().get_viewport_rid()
	for _sample in METRIC_SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		process_samples.append(Performance.get_monitor(
				Performance.TIME_PROCESS) * 1000.0)
		physics_samples.append(Performance.get_monitor(
				Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_samples.append(Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(
				viewport_rid)
		if is_finite(gpu) and gpu > 0.0:
			gpu_samples.append(gpu)
	var renderer := RenderingServer.get_current_rendering_method()
	var gpu_trustworthy := renderer == "forward_plus" \
			and gpu_samples.size() == METRIC_SAMPLE_FRAMES
	return {
		"samples": METRIC_SAMPLE_FRAMES,
		"renderer": renderer,
		"cpu_process_median_ms": _median(process_samples),
		"physics_median_ms": _median(physics_samples),
		"draw_calls_median": _median(draw_samples),
		"gpu_median_ms": _median(gpu_samples) if gpu_trustworthy else null,
		"gpu_timing_trustworthy": gpu_trustworthy,
		"gpu_samples_observed": gpu_samples.size(),
	}


func _finish_run() -> void:
	if is_instance_valid(player):
		player.autopilot = Vector3.ZERO
	var cell_ref: WeakRef = weakref(cell) if is_instance_valid(cell) else null
	var player_ref: WeakRef = weakref(player) \
			if is_instance_valid(player) else null
	var public_receipt := {}
	if is_instance_valid(cell):
		if cell.has_method("shutdown_for_tests"):
			public_receipt = cell.call("shutdown_for_tests") as Dictionary
		else:
			_fail("production exterior has no public shutdown API")
		cell.queue_free()
	cell = null
	player = null
	camera = null
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var after_counts := _object_counts()
	teardown_record = {
		"public_api": "OrisonV2ExteriorCell.shutdown_for_tests",
		"public_receipt": public_receipt,
		"cell_released": cell_ref == null or cell_ref.get_ref() == null,
		"player_released": player_ref == null or player_ref.get_ref() == null,
		"before_build": startup_counts,
		"while_built": built_counts,
		"after_teardown": after_counts,
		"object_delta_from_before": int(after_counts.get("objects", 0))
				- int(startup_counts.get("objects", 0)),
		"resource_delta_from_before": int(after_counts.get("resources", 0))
				- int(startup_counts.get("resources", 0)),
		"orphan_delta_from_before": int(after_counts.get("orphan_nodes", 0))
				- int(startup_counts.get("orphan_nodes", 0)),
	}
	if not bool(teardown_record.cell_released) \
			or not bool(teardown_record.player_released) \
			or int(public_receipt.get("retained_strong_references", -1)) != 0:
		_fail("public production teardown retained scene ownership")
	_attach_frame_hashes()
	var receipt_ok := _write_production_receipt()
	var shots_ok := shots.finish()
	get_tree().quit(0 if shots_ok and receipt_ok and not _failed else 2)


func _write_production_receipt() -> bool:
	var exact_files := [
		"01_orison_side_route_beginning.png",
		"02_bodega_threshold_approach.png",
		"03_bodega_interior_continuing_route.png",
		"04_return_direction_toward_orison.png",
	]
	var receipt := {
		"schema_version": 1,
		"status": "PASS" if not _failed and frame_records.size() == 4
				else "FAIL",
		"human_acceptance": "PENDING",
		"human_acceptance_scope": "new production M11A four-frame packet",
		"production_scene": "res://scenes/building/orison_v2_exterior_cell.tscn",
		"production_module": "OrisonV2ExteriorCell",
		"production_source_only": true,
		"disposable_second_instance_present": false,
		"resolution": [EXPECTED_RESOLUTION.x, EXPECTED_RESOLUTION.y],
		"expected_files": exact_files,
		"renderer": RenderingServer.get_current_rendering_method(),
		"camera_provenance": {
			"class": "playable",
			"owner": "production PlayerController",
			"camera_child": "PlayerController.Camera3D",
			"standing_eye_m": PlayerController.STANDING_EYE,
			"one_initial_semantic_placement": true,
			"later_station_teleports": 0,
			"carried_lamp": "production PlayerController hand light preserved",
			"audio_listener": "current production PlayerController camera",
			"streaming_origin": "no capture-only streaming override",
			"capture_only_geometry": false,
			"capture_only_lights": false,
			"developer_overlay": false,
			"player_hud": "preserved",
		},
		"determinism": {
			"random_seed": 1101,
			"reality_state": "fresh in-memory campaign fixture",
			"engine_time_scale": Engine.time_scale,
			"weather_override": "none",
			"daynight_override": "none",
		},
		"semantic_routes": [OUTBOUND_ROUTE, RETURN_ROUTE],
		"semantic_threshold": THRESHOLD_ID,
		"frames": frame_records,
		"traversal": traversal_records,
		"storefront_interaction": interaction_record,
		"module_cost": cell_cost,
		"teardown": teardown_record,
		"failures": _failure_reasons,
	}
	var path: String = shots.output_dir.path_join(
			"production_cell_capture_receipt.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("M11A capture receipt could not be written: %s" % path)
		return false
	file.store_string(JSON.stringify(receipt, "\t"))
	return true


func _attach_frame_hashes() -> void:
	for record: Dictionary in frame_records:
		var path: String = shots.output_dir.path_join(
				str(record.get("file", "")))
		var digest := _sha256_file(path)
		record["sha256"] = digest
		if digest.length() != 64:
			_fail("captured frame has no valid SHA-256: %s" % path)


func _route_point(route: Dictionary, waypoint_id: String) -> Vector3:
	for value: Variant in route.get("nodes", []):
		if value is not Dictionary or str(value.get("id", "")) != waypoint_id:
			continue
		var placement: Dictionary = value.get("placement", {})
		var position_value: Variant = placement.get("position")
		return position_value as Vector3 if position_value is Vector3 \
				else Vector3.INF
	return Vector3.INF


func _placement_point(instance_id: String, placement_id: String) -> Vector3:
	var resolver: Variant = cell.get("spatial_resolver")
	if resolver == null:
		return Vector3.INF
	var placement: Dictionary = resolver.call("resolve_placement", instance_id,
			placement_id)
	var value: Variant = placement.get("position")
	return value as Vector3 if value is Vector3 else Vector3.INF


func _aim_at(target: Vector3) -> void:
	camera.look_at(target, Vector3.UP)
	camera.transform.basis = camera.transform.basis.orthonormalized()


func _all_finite(points: Array) -> bool:
	for value: Variant in points:
		if value is not Vector3 or not (value as Vector3).is_finite():
			return false
	return true


func _object_counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(
				Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(
				Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _sha256_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return context.finish().hex_encode()


func _median(values: Array[float]) -> Variant:
	if values.is_empty():
		return null
	values.sort()
	return values[values.size() / 2]


func _vec(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _fail(reason: String) -> void:
	_failed = true
	_failure_reasons.append(reason)
	push_error("M11A EXTERIOR CAPTURE: " + reason)
	print("[ORISON-V2-M11A-EXTERIOR FAIL] " + reason)
