extends Node
## M11B's four-frame human-review packet. Each floor is composed from its
## committed review scene, but the review controller never owns a captured
## frame. One real PlayerController is placed on the derived service landing
## before tree entry and then crosses the data-authored opening in both
## directions under ordinary collision-bearing autopilot movement.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const F02_REVIEW := preload("res://scenes/building/orison_v2_f02_review.tscn")
const F04_REVIEW := preload("res://scenes/building/orison_v2_f04_review.tscn")

const LAYOUT_PATH := "res://data/orison_v2_blockout.json"
const SCRIPT_PATH := "res://tests/orison_v2_m11b_service_openings_shot.gd"
const EXPECTED_RESOLUTION := Vector2i(1600, 900)
const METRIC_SAMPLE_FRAMES := 8
const WALK_TOLERANCE_M := 0.14
const MAX_ROUTE_EXTRA_FRAMES := 150
const CORE_STANDOFF_MAX_M := 0.95
const CORE_VIEW_TANGENT_M := 1.45
const HALL_VIEW_TANGENT_M := 1.05
const MIN_FRAME_MEAN_LUMA_255 := 18.0
const MAX_FRAME_DARK_FRACTION := 0.72
const OPENING_IDS := {
	"F02": "F02_SERVICE_HALL_CORE_OPENING",
	"F04": "F04_SERVICE_HALL_CORE_OPENING",
}
const FRAME_LABELS := {
	"F02": ["01_f02_core_side_approach", "02_f02_hall_side_return"],
	"F04": ["03_f04_core_side_approach", "04_f04_hall_side_return"],
}

var shots = ShotHarnessScript.new()
var layout: Dictionary = {}
var floor_specs: Dictionary = {}
var frame_records: Array[Dictionary] = []
var traversal_records: Array[Dictionary] = []
var composition_records: Array[Dictionary] = []
var teardown_records: Array[Dictionary] = []
var startup_counts: Dictionary = {}
var final_counts: Dictionary = {}
var _failed := false
var _failure_reasons: Array[String] = []

var active_review: Node3D
var active_blockout: Node3D
var active_review_player: CharacterBody3D
var active_review_camera: Camera3D
var active_player: PlayerController
var active_camera: Camera3D
var active_floor := ""


func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M11B-SERVICE-OPENINGS", 4):
		get_tree().quit(2)
		return
	seed(1102)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("evidence capture requires the Forward+ renderer")
		await _finish_run()
		return
	startup_counts = _object_counts()
	layout = _load_layout()
	if layout.is_empty():
		await _finish_run()
		return
	for floor_id in ["F02", "F04"]:
		var specification := _derive_floor_spec(floor_id)
		if specification.is_empty():
			_fail("%s opening composition could not be derived" % floor_id)
		else:
			floor_specs[floor_id] = specification
	if _failed:
		await _finish_run()
		return
	var viewport_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for floor_id in ["F02", "F04"]:
		if _failed:
			break
		await _run_floor(floor_id)
	await _finish_run()


func _run_floor(floor_id: String) -> void:
	var composed := _compose_floor(floor_id)
	if not composed:
		return
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_hide_non_packet_visuals()
	if not await shots.settle(0.35, floor_id.to_lower() + "_review_ready"):
		_fail("%s review composition did not settle inside the capture budget" % floor_id)
	if not _failed:
		_validate_active_composition()
	var specification: Dictionary = floor_specs[floor_id]
	var labels: Array = FRAME_LABELS[floor_id]
	if not _failed:
		await _capture_frame(str(labels[0]), specification,
				str(specification.get("core_id", "")), "core_side_approach")
	if not _failed:
		await _walk_direction(floor_id + "_CORE_TO_HALL", specification,
				[specification.get("hall_threshold"),
				specification.get("hall_view_position")], "core", "hall")
	if not _failed:
		await _capture_frame(str(labels[1]), specification,
				str(specification.get("hall_id", "")), "hall_side_return")
	if not _failed:
		await _walk_direction(floor_id + "_HALL_TO_CORE", specification,
				[specification.get("hall_threshold"),
				specification.get("core_threshold"),
				specification.get("core_position")], "hall", "core")
	await _teardown_active_floor()


func _compose_floor(floor_id: String) -> bool:
	var review_scene: PackedScene = F02_REVIEW if floor_id == "F02" \
			else F04_REVIEW
	var review := review_scene.instantiate() as Node3D
	if review == null:
		_fail("%s committed review scene did not instantiate" % floor_id)
		return false
	var blockout := review.get_node_or_null("Blockout") as Node3D
	var review_player := review.get_node_or_null("Player") as CharacterBody3D
	var review_camera := review.get_node_or_null(
			"Player/Head/Camera3D") as Camera3D
	var world_environment := review.get_node_or_null(
			"WorldEnvironment") as WorldEnvironment
	var sun := review.get_node_or_null("Sun") as DirectionalLight3D
	if blockout == null or review_player == null or review_camera == null \
			or world_environment == null or sun == null:
		review.free()
		_fail("%s committed review composition is incomplete" % floor_id)
		return false
	# This export prevents anchor-envelope meshes from being built at all. The
	# schema-owned envelope and landing-clearance meshes are hidden after build.
	blockout.set("show_clearance_anchors", false)
	review_player.process_mode = Node.PROCESS_MODE_DISABLED
	review_camera.current = false
	var production_player := PlayerController.new()
	production_player.name = "M11BProductionPlayer"
	production_player.position = floor_specs[floor_id].get(
			"core_position", Vector3.INF)
	var player_added_before_tree := not review.is_inside_tree()
	review.add_child(production_player)
	player_added_before_tree = player_added_before_tree \
			and not production_player.is_inside_tree()
	active_floor = floor_id
	active_review = review
	active_blockout = blockout
	active_review_player = review_player
	active_review_camera = review_camera
	active_player = production_player
	add_child(review)
	active_camera = production_player.camera
	if active_camera == null:
		_fail("%s production PlayerController did not compose its camera" % floor_id)
		return true
	active_camera.fov = 78.0
	active_camera.make_current()
	composition_records.append({
		"floor": floor_id,
		"review_scene": "res://scenes/building/orison_v2_%s_review.tscn" \
				% floor_id.to_lower(),
		"review_world_environment_preserved": true,
		"review_sun_preserved": true,
		"review_player_camera_disabled_before_tree_entry": \
				not review_camera.current,
		"production_player_added_before_tree_entry": player_added_before_tree,
		"production_player_class": active_player.get_class(),
		"production_player_script": str(active_player.get_script().resource_path),
		"capture_camera_owner": "M11BProductionPlayer",
		"capture_camera_path": str(active_player.get_path_to(active_camera)),
		"capture_only_geometry": false,
		"capture_only_lights": false,
		"capture_only_camera": false,
		"initial_placement_count": 1,
		"initial_placement_side": "core",
		"initial_placement": _vec(active_player.global_position),
		"scene_census_before_cue_hiding": _scene_census(review),
	})
	return true


func _validate_active_composition() -> void:
	if active_blockout == null or active_player == null or active_camera == null:
		_fail("%s active review owners are missing" % active_floor)
		return
	var blockout_failures: Variant = active_blockout.get("failures")
	if blockout_failures is Array and not blockout_failures.is_empty():
		_fail("%s blockout refused its schema: %s" % [active_floor,
				blockout_failures])
	if active_review_camera.current:
		_fail("%s review-controller camera became current" % active_floor)
	if get_viewport().get_camera_3d() != active_camera:
		_fail("%s production PlayerController camera is not current" % active_floor)
	if active_player.noclip or active_player.collision_layer == 0 \
			or active_player.collision_mask == 0:
		_fail("%s production player lacks collision-bearing state" % active_floor)
	if not active_player.is_on_floor():
		_fail("%s derived core-side initial placement is not supported" % active_floor)
	var census := _scene_census(active_review)
	if int(census.get("visible_label_3d", -1)) != 0 \
			or int(census.get("visible_canvas_layers", -1)) != 0 \
			or int(census.get("visible_readability_cues", -1)) != 0:
		_fail("%s packet still exposes labels, overlays, or review cues" % active_floor)
	for record: Dictionary in composition_records:
		if str(record.get("floor", "")) == active_floor:
			record["scene_census_packet_state"] = census
			record["review_camera_current_after_tree_entry"] = \
					active_review_camera.current
			record["production_camera_current_after_tree_entry"] = \
					get_viewport().get_camera_3d() == active_camera
			record["derived_initial_placement_supported"] = \
					active_player.is_on_floor()
			break


func _hide_non_packet_visuals() -> void:
	var hidden_cues := 0
	for envelope_value: Variant in layout.get("envelopes", []):
		if envelope_value is not Dictionary:
			continue
		var node := active_blockout.get_node_or_null(
				str(envelope_value.get("id", ""))) as Node3D
		if node != null:
			node.visible = false
			node.set_meta("m11b_readability_cue", true)
			hidden_cues += 1
	for landing_value: Variant in layout.get("lift_landings", []):
		if landing_value is not Dictionary:
			continue
		var clearance := active_blockout.get_node_or_null(
				"%s/Clearance" % str(landing_value.get("id", ""))) as Node3D
		if clearance != null:
			clearance.visible = false
			clearance.set_meta("m11b_readability_cue", true)
			hidden_cues += 1
	var hidden_labels := 0
	var hidden_layers := 0
	for node in _descendants(active_review):
		if node is Label3D:
			(node as Label3D).visible = false
			node.set_meta("m11b_readability_cue", true)
			hidden_labels += 1
		elif node is CanvasLayer:
			(node as CanvasLayer).visible = false
			node.set_meta("m11b_readability_cue", true)
			hidden_layers += 1
	for record: Dictionary in composition_records:
		if str(record.get("floor", "")) == active_floor:
			record["hidden_schema_envelopes_and_landing_cues"] = hidden_cues
			record["hidden_label_3d"] = hidden_labels
			record["hidden_canvas_layers"] = hidden_layers
			record["anchor_envelope_construction_disabled"] = true
			break


func _capture_frame(label: String, specification: Dictionary,
		station_owner: String, view_kind: String) -> void:
	var opening_center: Vector3 = specification.get("opening_center",
			Vector3.INF)
	var opening_height := float(specification.get("opening_height", 0.0))
	var opening_aim := opening_center + Vector3.UP * minf(
			PlayerController.STANDING_EYE * 0.94, opening_height * 0.58)
	# Extend the eye-to-opening ray beyond the shared plane. This keeps the
	# aperture centred from either oblique stance while showing the continuing
	# hall or supporting core behind it; no plan coordinate is introduced.
	var through_direction := Vector3(opening_aim.x - active_camera.global_position.x,
			0.0, opening_aim.z - active_camera.global_position.z).normalized()
	var target := opening_aim + through_direction * (
			1.8 if view_kind == "core_side_approach" else 1.4)
	active_camera.fov = 76.0
	_aim_player_at(target)
	# Yaw belongs to the production body, exactly as it does under live input.
	# Give the sibling service-set hand time to finish its authored follow so
	# the real carried lamp illuminates what the player is actually viewing.
	await get_tree().create_timer(0.45, true, false, true).timeout
	await get_tree().physics_frame
	var metrics := await _sample_metrics()
	var capture_ok := await shots.capture(label)
	var capture_width := 0
	var capture_height := 0
	if capture_ok and not shots.captures.is_empty():
		var capture: Dictionary = shots.captures[-1]
		capture_width = int(capture.get("width", 0))
		capture_height = int(capture.get("height", 0))
	var luminance := _saved_frame_luminance(label) if capture_ok else {}
	var dimensions_ok := Vector2i(capture_width,
			capture_height) == EXPECTED_RESOLUTION
	var census := _scene_census(active_review)
	var record := {
		"label": label,
		"file": label + ".png",
		"floor": active_floor,
		"view": view_kind,
		"station_owner": station_owner,
		"opening_id": str(specification.get("opening_id", "")),
		"capture": "PASS" if capture_ok else "FAIL",
		"dimensions": [capture_width, capture_height],
		"dimensions_ok": dimensions_ok,
		"renderer": RenderingServer.get_current_rendering_method(),
		"camera_class": "playable",
		"camera_owner_class": "PlayerController",
		"camera_child": str(active_player.get_path_to(active_camera)),
		"player_origin": _vec(active_player.global_position),
		"eye": _vec(active_camera.global_position),
		"target": _vec(target),
		"forward": _vec(-active_camera.global_transform.basis.z.normalized()),
		"fov_degrees": active_camera.fov,
		"standing_eye_m": PlayerController.STANDING_EYE,
		"body_radius_m": PlayerController.BODY_RADIUS,
		"body_height_m": PlayerController.STANDING_HEIGHT,
		"camera_current": get_viewport().get_camera_3d() == active_camera,
		"review_camera_current": active_review_camera.current,
		"supporting_floor": active_player.is_on_floor(),
		"noclip": active_player.noclip,
		"collision_layer": active_player.collision_layer,
		"collision_mask": active_player.collision_mask,
		"visible_readability_cues": census.get("visible_readability_cues", -1),
		"visible_label_3d": census.get("visible_label_3d", -1),
		"visible_canvas_layers": census.get("visible_canvas_layers", -1),
		"luminance": luminance,
		"metrics": metrics,
	}
	frame_records.append(record)
	if not capture_ok or not dimensions_ok or not active_player.is_on_floor() \
			or active_player.noclip \
			or active_player.collision_layer == 0 \
			or active_player.collision_mask == 0 \
			or get_viewport().get_camera_3d() != active_camera \
			or active_review_camera.current \
			or int(census.get("visible_readability_cues", -1)) != 0 \
			or int(census.get("visible_label_3d", -1)) != 0 \
			or int(census.get("visible_canvas_layers", -1)) != 0 \
			or float(luminance.get("mean_luma_255", 0.0)) \
					< MIN_FRAME_MEAN_LUMA_255 \
			or float(luminance.get("fraction_below_16", 1.0)) \
					> MAX_FRAME_DARK_FRACTION:
		_fail("%s violated packet camera, collision, dimensions, or visual provenance" \
				% label)


func _saved_frame_luminance(label: String) -> Dictionary:
	var image := Image.load_from_file(shots.output_dir.path_join(label + ".png"))
	if image == null or image.is_empty():
		return {}
	image.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var total := image.get_width() * image.get_height()
	var sum_luma := 0.0
	var below_16 := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color := image.get_pixel(x, y)
			var luma := (color.r * 0.2126 + color.g * 0.7152
					+ color.b * 0.0722) * 255.0
			sum_luma += luma
			if luma < 16.0:
				below_16 += 1
	return {
		"mean_luma_255": sum_luma / maxf(1.0, float(total)),
		"fraction_below_16": float(below_16) / maxf(1.0, float(total)),
		"sample_dimensions": [image.get_width(), image.get_height()],
		"minimum_mean_luma_255": MIN_FRAME_MEAN_LUMA_255,
		"maximum_fraction_below_16": MAX_FRAME_DARK_FRACTION,
	}


func _aim_player_at(target: Vector3) -> void:
	var flat_target := Vector3(target.x, active_player.global_position.y,
			target.z)
	active_player.look_at(flat_target, Vector3.UP)
	var eye := active_camera.global_position
	var delta := target - eye
	var planar := Vector2(delta.x, delta.z).length()
	active_camera.rotation = Vector3(atan2(delta.y, planar), 0.0, 0.0)


func _walk_direction(direction_id: String, specification: Dictionary,
		waypoints: Array, from_side: String, to_side: String) -> bool:
	var start := active_player.global_position
	var opening_center: Vector3 = specification.get("opening_center",
			Vector3.INF)
	var normal_into_hall: Vector3 = specification.get("normal_into_hall",
			Vector3.INF)
	var started_usec := Time.get_ticks_usec()
	var legs: Array[Dictionary] = []
	var total_physics_frames := 0
	var grounded_frames := 0
	var collision_frames := 0
	var maximum_vertical_drift := 0.0
	var route_ok := true
	for waypoint_index in waypoints.size():
		var target_value: Variant = waypoints[waypoint_index]
		if target_value is not Vector3 or not (target_value as Vector3).is_finite():
			route_ok = false
			_fail("%s has a non-finite derived waypoint" % direction_id)
			break
		var target := target_value as Vector3
		var leg_start := active_player.global_position
		var horizontal_distance := Vector2(leg_start.x, leg_start.z).distance_to(
				Vector2(target.x, target.z))
		var maximum_frames := ceili(horizontal_distance \
				/ PlayerController.WALK * 60.0) + MAX_ROUTE_EXTRA_FRAMES
		var frames := 0
		var reached := false
		while frames < maximum_frames:
			var here := active_player.global_position
			var planar_delta := Vector3(target.x - here.x, 0.0,
					target.z - here.z)
			if planar_delta.length() <= WALK_TOLERANCE_M:
				reached = true
				break
			active_player.autopilot = planar_delta.normalized()
			await get_tree().physics_frame
			frames += 1
			total_physics_frames += 1
			if active_player.is_on_floor():
				grounded_frames += 1
			if not active_player.noclip and active_player.collision_layer != 0 \
					and active_player.collision_mask != 0:
				collision_frames += 1
			maximum_vertical_drift = maxf(maximum_vertical_drift,
					absf(active_player.global_position.y - target.y))
			if active_player.noclip:
				break
		active_player.autopilot = Vector3.ZERO
		active_player.velocity.x = 0.0
		active_player.velocity.z = 0.0
		var leg_end := active_player.global_position
		var remaining := Vector2(leg_end.x, leg_end.z).distance_to(
				Vector2(target.x, target.z))
		legs.append({
			"index": waypoint_index,
			"start": _vec(leg_start),
			"target": _vec(target),
			"end": _vec(leg_end),
			"planned_distance_m": horizontal_distance,
			"remaining_m": remaining,
			"physics_frames": frames,
			"status": "PASS" if reached else "FAIL",
		})
		if not reached:
			route_ok = false
			_fail("collision-bearing traversal stopped short on %s leg %d" \
					% [direction_id, waypoint_index])
			break
	await get_tree().physics_frame
	var finish := active_player.global_position
	var start_sign := normal_into_hall.dot(start - opening_center)
	var finish_sign := normal_into_hall.dot(finish - opening_center)
	var crossed_expected_plane := start_sign < -PlayerController.BODY_RADIUS \
			and finish_sign > PlayerController.BODY_RADIUS \
			if from_side == "core" else start_sign > PlayerController.BODY_RADIUS \
			and finish_sign < -PlayerController.BODY_RADIUS
	var grounded_fraction := float(grounded_frames) / maxf(1.0,
			float(total_physics_frames))
	var collision_fraction := float(collision_frames) / maxf(1.0,
			float(total_physics_frames))
	var record := {
		"direction": direction_id,
		"floor": active_floor,
		"opening_id": str(specification.get("opening_id", "")),
		"from_side": from_side,
		"to_side": to_side,
		"start": _vec(start),
		"finish": _vec(finish),
		"opening_plane_signed_start_m": start_sign,
		"opening_plane_signed_finish_m": finish_sign,
		"crossed_expected_opening_plane": crossed_expected_plane,
		"legs": legs,
		"physics_frames": total_physics_frames,
		"elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
		"grounded_fraction": grounded_fraction,
		"collision_enabled_fraction": collision_fraction,
		"maximum_vertical_drift_m": maximum_vertical_drift,
		"player_controller_physics": true,
		"autopilot_only": true,
		"noclip": active_player.noclip,
		"intermediate_teleports": 0,
		"test_only_collision_removal": false,
		"status": "PASS" if route_ok and crossed_expected_plane else "FAIL",
	}
	traversal_records.append(record)
	if not crossed_expected_plane:
		_fail("%s did not cross the derived opening plane in the expected direction" \
				% direction_id)
	if active_player.noclip or collision_fraction < 0.999:
		_fail("%s lost production collision-bearing state" % direction_id)
	return route_ok and crossed_expected_plane and not active_player.noclip


func _derive_floor_spec(floor_id: String) -> Dictionary:
	var opening := _record_by_id("openings", str(OPENING_IDS.get(floor_id, "")))
	if opening.is_empty():
		_fail("%s required opening record is missing" % floor_id)
		return {}
	var connects: Array = opening.get("connects", [])
	if connects.size() != 2:
		_fail("%s opening does not have exactly two endpoints" % floor_id)
		return {}
	var first := _record_by_id("spaces", str(connects[0]))
	var second := _record_by_id("spaces", str(connects[1]))
	if first.is_empty() or second.is_empty():
		_fail("%s opening endpoint record is missing" % floor_id)
		return {}
	var hall := first if str(first.get("class", "")) == "service" else second
	var core := first if str(first.get("class", "")) == "core" else second
	var expected_hall_id := floor_id + "_SERVICE_HALL"
	var expected_core_id := floor_id + "_SERVICE_CORE"
	if str(hall.get("id", "")) != expected_hall_id \
			or str(core.get("id", "")) != expected_core_id:
		_fail("%s opening endpoints are not the service hall and service core" \
				% floor_id)
		return {}
	var boundary := _shared_boundary(hall, core)
	if boundary.is_empty():
		_fail("%s service endpoints have no shared wall" % floor_id)
		return {}
	var axis := str(opening.get("axis", ""))
	var center_value: Variant = opening.get("center")
	if center_value is not Array or center_value.size() != 2:
		_fail("%s opening has no valid center" % floor_id)
		return {}
	var center: Array = center_value
	var width := float(opening.get("width", 0.0))
	var height := float(opening.get("height", 0.0))
	var fixed := float(center[1] if axis == "x" else center[0])
	var along := float(center[0] if axis == "x" else center[1])
	var interval_start := along - width * 0.5
	var interval_finish := along + width * 0.5
	var boundary_ok := axis == str(boundary.get("axis", "")) \
			and is_equal_approx(fixed, float(boundary.get("fixed", INF))) \
			and interval_start >= float(boundary.get("start", INF)) - 0.001 \
			and interval_finish <= float(boundary.get("finish", -INF)) + 0.001
	if not boundary_ok:
		_fail("%s opening is not wholly on its independently derived shared wall" \
				% floor_id)
		return {}
	var floor_y := _level_y(floor_id)
	if not is_finite(floor_y):
		_fail("%s level record is missing" % floor_id)
		return {}
	var opening_center := Vector3(float(center[0]), floor_y, float(center[1]))
	var hall_rect: Array = hall.get("rect", [])
	var core_rect: Array = core.get("rect", [])
	var hall_plan_center := _rect_center_plan(hall_rect, floor_y)
	var core_plan_center := _rect_center_plan(core_rect, floor_y)
	var normal_into_hall := Vector3.ZERO
	var tangent := Vector3.ZERO
	var hall_depth := 0.0
	var core_depth := 0.0
	var positive_space := 0.0
	var negative_space := 0.0
	if axis == "z":
		normal_into_hall = Vector3(signf(hall_plan_center.x - opening_center.x),
				0.0, 0.0)
		hall_depth = absf(hall_plan_center.x - opening_center.x) * 2.0
		core_depth = absf(core_plan_center.x - opening_center.x) * 2.0
		positive_space = float(hall_rect[3]) - along
		negative_space = along - float(hall_rect[1])
		tangent = Vector3(0.0, 0.0, 1.0 if positive_space >= negative_space \
				else -1.0)
	else:
		normal_into_hall = Vector3(0.0, 0.0,
				signf(hall_plan_center.z - opening_center.z))
		hall_depth = absf(hall_plan_center.z - opening_center.z) * 2.0
		core_depth = absf(core_plan_center.z - opening_center.z) * 2.0
		positive_space = float(hall_rect[2]) - along
		negative_space = along - float(hall_rect[0])
		tangent = Vector3(1.0 if positive_space >= negative_space else -1.0,
				0.0, 0.0)
	if normal_into_hall == Vector3.ZERO or hall_depth <= 0.0 or core_depth <= 0.0:
		_fail("%s shared-wall side normal could not be derived" % floor_id)
		return {}
	var hall_threshold := opening_center + normal_into_hall * hall_depth * 0.5
	var core_threshold := opening_center - normal_into_hall * hall_depth * 0.5
	var landing := _record_by_id("platforms", floor_id + "_SERVICE_LANDING")
	if landing.is_empty():
		_fail("%s service landing platform record is missing" % floor_id)
		return {}
	var landing_return := _record_by_id("platforms", floor_id + "_SERVICE_RETURN")
	if landing_return.is_empty():
		_fail("%s service landing-return platform record is missing" % floor_id)
		return {}
	var landing_rect: Array = landing.get("rect", [])
	var core_standoff := minf(CORE_STANDOFF_MAX_M, core_depth * 0.58)
	var opposite_tangent_space := 0.0
	if axis == "z":
		opposite_tangent_space = along - float(landing_rect[1]) \
				if tangent.z > 0.0 else float(landing_rect[3]) - along
	else:
		opposite_tangent_space = along - float(landing_rect[0]) \
				if tangent.x > 0.0 else float(landing_rect[2]) - along
	var core_tangent_distance := minf(CORE_VIEW_TANGENT_M,
			opposite_tangent_space - PlayerController.BODY_RADIUS - 0.20)
	var core_position := opening_center - normal_into_hall * core_standoff \
			- tangent * core_tangent_distance
	# Put the hall-return stance opposite the authored landing return whenever
	# the longer hall direction would put both on the same side of the opening.
	# The through-aperture sightline then includes that real core landmark.
	var landing_return_center := _rect_center_plan(
			landing_return.get("rect", []), floor_y)
	var hall_view_direction := tangent
	var return_is_along_tangent := (axis == "z" \
			and signf(landing_return_center.z - opening_center.z) == tangent.z) \
			or (axis == "x" \
			and signf(landing_return_center.x - opening_center.x) == tangent.x)
	if return_is_along_tangent:
		hall_view_direction = -tangent
	var direction_is_positive := hall_view_direction.z > 0.0 if axis == "z" \
			else hall_view_direction.x > 0.0
	var chosen_tangent_space := positive_space if direction_is_positive \
			else negative_space
	var tangent_distance := minf(HALL_VIEW_TANGENT_M,
			chosen_tangent_space - PlayerController.BODY_RADIUS - 0.20)
	if tangent_distance <= PlayerController.BODY_RADIUS:
		_fail("%s service hall has no derived return-view stance" % floor_id)
		return {}
	var hall_view_position := hall_threshold \
			+ hall_view_direction * tangent_distance
	if landing.is_empty() or not _point_in_rect(core_position,
			landing_rect, PlayerController.BODY_RADIUS):
		_fail("%s derived core stance is not on its service landing platform" \
				% floor_id)
		return {}
	if not _point_in_rect(hall_threshold, hall_rect,
			PlayerController.BODY_RADIUS * 0.85) \
			or not _point_in_rect(hall_view_position, hall_rect,
			PlayerController.BODY_RADIUS * 0.85):
		_fail("%s derived hall stances do not fit inside the hall record" % floor_id)
		return {}
	var capsule_ok := width >= PlayerController.BODY_RADIUS * 2.0 + 0.20 \
			and height >= PlayerController.STANDING_HEIGHT + 0.20
	if not capsule_ok:
		_fail("%s opening does not clear the production player capsule" % floor_id)
		return {}
	return {
		"floor": floor_id,
		"opening_id": str(opening.get("id", "")),
		"opening_level": str(opening.get("level", "")),
		"opening_axis": axis,
		"opening_center_record": [float(center[0]), float(center[1])],
		"opening_center": opening_center,
		"opening_width": width,
		"opening_height": height,
		"shared_wall_owner": str(opening.get("shared_wall_owner", "")),
		"connects": connects.duplicate(),
		"hall_id": str(hall.get("id", "")),
		"hall_class": str(hall.get("class", "")),
		"hall_rect": hall_rect.duplicate(),
		"core_id": str(core.get("id", "")),
		"core_class": str(core.get("class", "")),
		"core_rect": core_rect.duplicate(),
		"boundary_axis": str(boundary.get("axis", "")),
		"boundary_fixed": float(boundary.get("fixed", 0.0)),
		"boundary_start": float(boundary.get("start", 0.0)),
		"boundary_finish": float(boundary.get("finish", 0.0)),
		"opening_interval_start": interval_start,
		"opening_interval_finish": interval_finish,
		"boundary_fully_contains_opening": boundary_ok,
		"floor_y": floor_y,
		"normal_into_hall": normal_into_hall,
		"tangent_into_longer_hall_continuation": tangent,
		"hall_view_direction": hall_view_direction,
		"core_position": core_position,
		"hall_threshold": hall_threshold,
		"core_threshold": core_threshold,
		"hall_view_position": hall_view_position,
		"hall_view_tangent_distance": tangent_distance,
		"landing_platform_id": str(landing.get("id", "")),
		"landing_platform_rect": (landing.get("rect", []) as Array).duplicate(),
		"capsule_clearance_ok": capsule_ok,
		"width_margin_over_capsule_m": width \
				- PlayerController.BODY_RADIUS * 2.0,
		"head_margin_over_capsule_m": height \
				- PlayerController.STANDING_HEIGHT,
		"authority": "positions recomputed from this floor's opening, two endpoint spaces, level, and service-landing records",
	}


func _shared_boundary(a: Dictionary, b: Dictionary) -> Dictionary:
	var ar: Array = a.get("rect", [])
	var br: Array = b.get("rect", [])
	if not _valid_rect(ar) or not _valid_rect(br):
		return {}
	var z_start := maxf(float(ar[1]), float(br[1]))
	var z_finish := minf(float(ar[3]), float(br[3]))
	if z_finish - z_start > 0.001 and is_equal_approx(float(ar[2]), float(br[0])):
		return {"axis": "z", "fixed": float(ar[2]), "start": z_start,
				"finish": z_finish, "a_side": "east", "b_side": "west"}
	if z_finish - z_start > 0.001 and is_equal_approx(float(ar[0]), float(br[2])):
		return {"axis": "z", "fixed": float(ar[0]), "start": z_start,
				"finish": z_finish, "a_side": "west", "b_side": "east"}
	var x_start := maxf(float(ar[0]), float(br[0]))
	var x_finish := minf(float(ar[2]), float(br[2]))
	if x_finish - x_start > 0.001 and is_equal_approx(float(ar[3]), float(br[1])):
		return {"axis": "x", "fixed": float(ar[3]), "start": x_start,
				"finish": x_finish, "a_side": "north", "b_side": "south"}
	if x_finish - x_start > 0.001 and is_equal_approx(float(ar[1]), float(br[3])):
		return {"axis": "x", "fixed": float(ar[1]), "start": x_start,
				"finish": x_finish, "a_side": "south", "b_side": "north"}
	return {}


func _teardown_active_floor() -> void:
	if active_review == null:
		return
	if active_player != null:
		active_player.autopilot = Vector3.ZERO
	var review_ref: WeakRef = weakref(active_review)
	var blockout_ref: WeakRef = weakref(active_blockout)
	var review_player_ref: WeakRef = weakref(active_review_player)
	var review_camera_ref: WeakRef = weakref(active_review_camera)
	var player_ref: WeakRef = weakref(active_player)
	var camera_ref: WeakRef = weakref(active_camera)
	var floor_id := active_floor
	var before := _object_counts()
	active_review.queue_free()
	active_review = null
	active_blockout = null
	active_review_player = null
	active_review_camera = null
	active_player = null
	active_camera = null
	active_floor = ""
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var after := _object_counts()
	var record := {
		"floor": floor_id,
		"method": "queue_free committed review composition root",
		"review_root_released": review_ref.get_ref() == null,
		"blockout_released": blockout_ref.get_ref() == null,
		"review_player_released": review_player_ref.get_ref() == null,
		"review_camera_released": review_camera_ref.get_ref() == null,
		"production_player_released": player_ref.get_ref() == null,
		"production_camera_released": camera_ref.get_ref() == null,
		"before": before,
		"after": after,
	}
	teardown_records.append(record)
	if not bool(record.get("review_root_released", false)) \
			or not bool(record.get("blockout_released", false)) \
			or not bool(record.get("review_player_released", false)) \
			or not bool(record.get("review_camera_released", false)) \
			or not bool(record.get("production_player_released", false)) \
			or not bool(record.get("production_camera_released", false)):
		_fail("%s review composition retained a strong node reference" % floor_id)


func _finish_run() -> void:
	if active_review != null:
		await _teardown_active_floor()
	_attach_frame_hashes()
	final_counts = _object_counts()
	var receipt_ok := _write_capture_receipt()
	var shots_ok := shots.finish()
	get_tree().quit(0 if shots_ok and receipt_ok and not _failed else 2)


func _write_capture_receipt() -> bool:
	var exact_files := [
		"01_f02_core_side_approach.png",
		"02_f02_hall_side_return.png",
		"03_f04_core_side_approach.png",
		"04_f04_hall_side_return.png",
	]
	var serializable_specs := {}
	for floor_id: String in floor_specs:
		serializable_specs[floor_id] = _serializable_spec(floor_specs[floor_id])
	var receipt := {
		"schema_version": 1,
		"task": "ORISON-V2-M11B",
		"status": "PASS" if not _failed and frame_records.size() == 4 \
				and traversal_records.size() == 4 else "FAIL",
		"human_acceptance": "PENDING",
		"scope": "F02/F04 service hall to service core openings",
		"resolution": [EXPECTED_RESOLUTION.x, EXPECTED_RESOLUTION.y],
		"expected_files": exact_files,
		"renderer": RenderingServer.get_current_rendering_method(),
		"production_source_only": true,
		"camera_provenance": {
			"class": "playable",
			"owner": "production PlayerController",
			"camera_child": "PlayerController-created Camera3D",
			"standing_eye_m": PlayerController.STANDING_EYE,
			"body_height_m": PlayerController.STANDING_HEIGHT,
			"body_radius_m": PlayerController.BODY_RADIUS,
			"one_initial_core_side_placement_per_floor": true,
			"later_station_teleports": 0,
			"review_controller_cameras": "disabled before tree entry",
			"capture_only_geometry": false,
			"capture_only_lights": false,
			"capture_only_camera": false,
			"developer_overlay": false,
			"labels_arrows_and_debug_envelopes": "hidden",
		},
		"source_hashes": {
			"layout_sha256": _sha256_file(LAYOUT_PATH),
			"f02_review_scene_sha256": _sha256_file(
					"res://scenes/building/orison_v2_f02_review.tscn"),
			"f04_review_scene_sha256": _sha256_file(
					"res://scenes/building/orison_v2_f04_review.tscn"),
			"capture_harness_sha256": _sha256_file(SCRIPT_PATH),
		},
		"schema_and_boundary_proofs": serializable_specs,
		"compositions": composition_records,
		"frames": frame_records,
		"traversal": traversal_records,
		"teardown": teardown_records,
		"object_counts": {
			"startup": startup_counts,
			"after_all_teardown": final_counts,
			"orphan_delta": int(final_counts.get("orphan_nodes", 0)) \
					- int(startup_counts.get("orphan_nodes", 0)),
		},
		"determinism": {
			"random_seed": 1102,
			"reality_state": "fresh in-memory campaign fixture",
			"engine_time_scale": Engine.time_scale,
		},
		"failures": _failure_reasons,
	}
	var path: String = shots.output_dir.path_join(
			"m11b_service_openings_capture_receipt.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("M11B capture receipt could not be written: %s" % path)
		return false
	file.store_string(JSON.stringify(receipt, "\t"))
	return true


func _serializable_spec(specification: Dictionary) -> Dictionary:
	var copy := specification.duplicate(true)
	for key in ["opening_center", "normal_into_hall",
			"tangent_into_longer_hall_continuation", "hall_view_direction",
			"core_position",
			"hall_threshold", "core_threshold", "hall_view_position"]:
		var value: Variant = copy.get(key)
		if value is Vector3:
			copy[key] = _vec(value)
	return copy


func _attach_frame_hashes() -> void:
	for record: Dictionary in frame_records:
		var path: String = shots.output_dir.path_join(str(record.get("file", "")))
		var digest := _sha256_file(path)
		record["sha256"] = digest
		if digest.length() != 64:
			_fail("captured frame has no valid SHA-256: %s" % path)


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


func _scene_census(root: Node) -> Dictionary:
	var census := {
		"nodes": 0,
		"node_3d": 0,
		"mesh_instances": 0,
		"visible_mesh_instances": 0,
		"collision_objects": 0,
		"collision_shapes": 0,
		"enabled_collision_shapes": 0,
		"cameras": 0,
		"current_cameras": 0,
		"lights": 0,
		"visible_lights": 0,
		"label_3d": 0,
		"visible_label_3d": 0,
		"canvas_layers": 0,
		"visible_canvas_layers": 0,
		"readability_cues": 0,
		"visible_readability_cues": 0,
	}
	var nodes := [root]
	nodes.append_array(_descendants(root))
	for node: Node in nodes:
		census.nodes += 1
		if node is Node3D:
			census.node_3d += 1
		if node is MeshInstance3D:
			census.mesh_instances += 1
			if (node as MeshInstance3D).is_visible_in_tree():
				census.visible_mesh_instances += 1
		if node is CollisionObject3D:
			census.collision_objects += 1
		if node is CollisionShape3D:
			census.collision_shapes += 1
			if not (node as CollisionShape3D).disabled \
					and (node as CollisionShape3D).shape != null:
				census.enabled_collision_shapes += 1
		if node is Camera3D:
			census.cameras += 1
			if (node as Camera3D).current:
				census.current_cameras += 1
		if node is Light3D:
			census.lights += 1
			if (node as Light3D).is_visible_in_tree():
				census.visible_lights += 1
		if node is Label3D:
			census.label_3d += 1
			if (node as Label3D).is_visible_in_tree():
				census.visible_label_3d += 1
		if node is CanvasLayer:
			census.canvas_layers += 1
			if (node as CanvasLayer).visible:
				census.visible_canvas_layers += 1
		if node.has_meta("m11b_readability_cue"):
			census.readability_cues += 1
			if node is Node3D and (node as Node3D).is_visible_in_tree():
				census.visible_readability_cues += 1
	return census


func _descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var stack: Array[Node] = []
	for child: Node in root.get_children():
		stack.append(child)
	while not stack.is_empty():
		var node := stack.pop_back() as Node
		result.append(node)
		for child: Node in node.get_children():
			stack.append(child)
	return result


func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT_PATH):
		_fail("layout is missing: %s" % LAYOUT_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			LAYOUT_PATH))
	if parsed is not Dictionary:
		_fail("layout is not a JSON object")
		return {}
	return parsed


func _record_by_id(table: String, identity: String) -> Dictionary:
	for value: Variant in layout.get(table, []):
		if value is Dictionary and str(value.get("id", "")) == identity:
			return value
	return {}


func _level_y(level_id: String) -> float:
	for value: Variant in layout.get("levels", []):
		if value is Dictionary and str(value.get("id", "")) == level_id:
			return float(value.get("y", INF))
	return INF


func _rect_center_plan(rect: Array, y: float) -> Vector3:
	if not _valid_rect(rect):
		return Vector3.INF
	return Vector3((float(rect[0]) + float(rect[2])) * 0.5, y,
			(float(rect[1]) + float(rect[3])) * 0.5)


func _point_in_rect(point: Vector3, rect_value: Variant,
		margin: float) -> bool:
	if rect_value is not Array or not _valid_rect(rect_value):
		return false
	var rect: Array = rect_value
	return point.x >= float(rect[0]) + margin \
			and point.x <= float(rect[2]) - margin \
			and point.z >= float(rect[1]) + margin \
			and point.z <= float(rect[3]) - margin


func _valid_rect(value: Variant) -> bool:
	return value is Array and value.size() == 4 \
			and float(value[0]) < float(value[2]) \
			and float(value[1]) < float(value[3])


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
	push_error("M11B SERVICE OPENINGS CAPTURE: " + reason)
	print("[ORISON-V2-M11B-SERVICE-OPENINGS FAIL] " + reason)
