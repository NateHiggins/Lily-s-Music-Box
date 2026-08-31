extends Node
## Five-seam visual packet using only real target cells, their source-owned
## production DoorProps, the production PlayerController camera/flashlight,
## real detail passes, and the production M11A environment resource. No capture
## geometry, collision, labels, arrows, noclip, or seam-masking prop is added.

const Support := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd")
const AdapterScript := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_consumer_adaptation.gd")
const MarkerAdapterScript := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_marker_consumer_adapter.gd")

const EXPECTED_SIZE := Vector2i(1600, 900)
const RECEIPT_ENV := "M11C1_CAPTURE_RECEIPT"
const OUTPUT_ENV := "M11C1_CAPTURE_DIR"
const DEFAULT_RECEIPT := "user://m11c1/m11c1_capture_receipt.json"
const LAYOUT_PATH := "res://data/building_layout.json"
const M11A_SCENE := "res://scenes/building/orison_v2_exterior_cell.tscn"
const MINIMUM_MEAN_LUMA := 8.0
const MAXIMUM_DARK_PIXEL_FRACTION := 0.92
const MINIMUM_TARGET_VISIBILITY_FRACTION := 0.65

var _failures: Array[String] = []
var _blockers: Array[String] = []


func _ready() -> void:
	await _run()


func _run() -> void:
	var inputs: Dictionary = Support.load_inputs()
	for reason: Variant in inputs.get("errors", []):
		_fail(str(reason))
	for reason: Variant in inputs.get("blockers", []):
		_block(str(reason))
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("capture requires Forward+")
	if get_viewport().get_visible_rect().size != Vector2(EXPECTED_SIZE):
		_fail("capture requires an exact 1600x900 viewport")
	if not bool(inputs.get("ok", false)):
		_finish(_base_receipt(inputs))
		return
	RenderingServer.viewport_set_measure_render_time(
			get_viewport().get_viewport_rid(), true)
	var output_dir := OS.get_environment(OUTPUT_ENV).strip_edges()
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("user://m11c1/captures")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var process_start := Support.object_counts()
	var layout := _load_layout()
	var config: Dictionary = inputs.get("config", {})
	var seams := Support.index_by_id(config.get("seams", []))
	var views: Array = config.get("capture_views", [])
	# Warm every distinct residency/presentation path before retention is
	# measured. This control emits no packet image and permits only first-use
	# resource-cache growth; all owned nodes still have to release.
	var warm_control: Array[Dictionary] = []
	for warm_raw: Variant in views:
		if warm_raw is Dictionary:
			warm_control.append(await _capture_view(warm_raw, seams, inputs,
					layout, output_dir, false, true))
	for row: Dictionary in warm_control:
		if str(row.get("status", "FAIL")) != "PASS":
			_fail("capture warm control did not complete")
	await _settle_render()
	var warmed_baseline := Support.object_counts()
	var frames: Array[Dictionary] = []
	for raw: Variant in views:
		if raw is Dictionary:
			frames.append(await _capture_view(raw, seams, inputs, layout,
					output_dir))
	await _settle_render()
	var final_counts := Support.object_counts()
	var lifecycle_delta := Support.object_delta(final_counts, warmed_baseline)
	for key: String in ["objects", "resources", "nodes", "orphan_nodes"]:
		if int(lifecycle_delta.get(key, 0)) > 0:
			_fail("capture packet retained %s above warmed baseline" % key)
	if frames.size() != Support.REQUIRED_SEAM_IDS.size():
		_fail("capture packet must contain exactly five dangerous-seam frames")
	for frame: Dictionary in frames:
		if str(frame.get("status", "FAIL")) != "PASS":
			_fail("capture packet contains a non-PASS frame")
	var receipt := _base_receipt(inputs)
	receipt.merge({
		"process_start":process_start,
		"warm_control":warm_control,
		"warmed_baseline":warmed_baseline,
		"cold_to_warmed_delta":Support.object_delta(warmed_baseline,
				process_start),
		"frames":frames,
		"frame_count":frames.size(),
		"required_dangerous_seam_count":Support.REQUIRED_SEAM_IDS.size(),
		"final_counts":final_counts,
		"lifecycle_delta_from_warmed_baseline":lifecycle_delta,
		"cold_process_delta":Support.object_delta(final_counts, process_start),
		"capture_boundary":{
			"harness_added_geometry":false,
			"harness_added_collision":false,
			"harness_added_light_implementation":false,
			"production_player_flashlight_included":true,
			"production_detail_passes_included":true,
			"production_m11a_environment_resource_included":true,
			"harness_added_labels_or_arrows":false,
			"production_player_camera":true,
			"production_marker_door_geometry_included":true,
			"noclip":false,
			"authored_initial_capture_placement_count_per_frame":1,
			"navigation_seam_proof_delegated_to_runtime_receipt":true,
		},
	}, true)
	_finish(receipt)


func _capture_view(view: Dictionary, seams: Dictionary,
		inputs: Dictionary, layout: Dictionary, output_dir: String,
		record_output := true, allow_cache_growth := false) -> Dictionary:
	var seam_id := str(view.get("seam_id", ""))
	var seam: Dictionary = seams.get(seam_id, {})
	var cell_ids: Array[String] = Support.string_array(view.get("cell_ids", []))
	var before := Support.object_counts()
	var adapter = AdapterScript.new()
	if not adapter.configure(inputs):
		_fail("%s capture adapter refused configuration" % seam_id)
		return {"status":"FAIL", "seam_id":seam_id}
	add_child(adapter)
	var mounted: Dictionary = adapter.mount_explicit_cells(cell_ids, false)
	if not bool(mounted.get("ok", false)):
		var reason := "%s capture requires imported target-cell resources" % seam_id
		_block(reason)
		var teardown: Dictionary = adapter.public_teardown()
		adapter.queue_free()
		await _settle_render()
		return {"status":"BLOCKED", "seam_id":seam_id, "reason":reason,
				"public_teardown":teardown}
	var marker_adapter = MarkerAdapterScript.new()
	marker_adapter.name = "M11C1CaptureProductionDoors"
	adapter.composition_host.add_child(marker_adapter)
	var semantic_index: Dictionary = inputs.get("semantic_index", {})
	var doors: Dictionary = marker_adapter.mount_doors(layout,
			semantic_index, Support.string_array(seam.get(
					"door_identities", [])), cell_ids)
	if str(doors.get("status", "PASS")) != "PASS":
		_fail("%s capture could not mount source-owned doors" % seam_id)
	var production_composition := _compose_production_presentation(adapter,
			cell_ids, layout)
	if str(production_composition.get("status", "FAIL")) != "PASS":
		_fail("%s capture production presentation did not compose" % seam_id)
	var player := PlayerController.new()
	player.name = "M11C1CaptureProductionPlayer"
	var eye := Support.vector3(view.get("eye", []))
	player.position = eye - Vector3.UP * PlayerController.STANDING_EYE
	adapter.composition_host.add_child(player)
	await get_tree().physics_frame
	var camera := player.camera
	if camera == null:
		_fail("%s production PlayerController camera is unavailable" % seam_id)
		var blocked_teardown: Dictionary = marker_adapter.public_teardown()
		marker_adapter.queue_free()
		var blocked_adapter_teardown: Dictionary = adapter.public_teardown()
		adapter.queue_free()
		await _settle_render()
		return {"status":"FAIL", "seam_id":seam_id,
				"door_teardown":blocked_teardown,
				"public_teardown":blocked_adapter_teardown}
	_apply_camera(camera, view)
	await _settle_render()
	var occlusion := _camera_occlusion(player, camera,
			Support.vector3(view.get("target", [])))
	var image := get_viewport().get_texture().get_image()
	var readability := _image_readability(image)
	var png_path := output_dir.path_join("%s.png" % _safe_slug(str(
			view.get("id", seam_id)))) if record_output else ""
	var save_error := image.save_png(png_path) \
			if record_output and image != null else (OK if not record_output \
			else ERR_CANT_CREATE)
	var dimensions := image.get_size() if image != null else Vector2i.ZERO
	image = null
	var hash := Support.file_sha256(png_path) \
			if record_output and save_error == OK else ""
	if dimensions != EXPECTED_SIZE or (record_output \
			and (save_error != OK or hash.length() != 64)):
		_fail("%s did not emit a hashed 1600x900 PNG" % seam_id)
	if not bool(readability.get("passed", false)):
		_fail("%s capture is not objectively readable" % seam_id)
	if not bool(occlusion.get("passed", false)):
		_fail("%s capture target is intercepted by a near occluder" % seam_id)
	var metrics := Support.tree_metrics(adapter)
	var performance := Support.performance_snapshot(get_viewport())
	performance.merge({
		"root":"M11C1Capture/%s" % str(view.get("id", seam_id)),
		"profile":_profile_label(),
		"residency_set":cell_ids,
		"simulation_state":"target cells + real marker doors/details + production PlayerController camera",
	}, true)
	var camera_receipt := {
		"eye":Support.vector3_array(camera.global_position),
		"target":view.get("target", []),
		"fov_degrees":camera.fov,
		"source":"explicit M11C1 runtime config",
		"production_class":"PlayerController/Camera3D",
		"initial_placement_count":1,
		"noclip":false,
	}
	var player_weak: WeakRef = weakref(player)
	var door_teardown: Dictionary = marker_adapter.public_teardown()
	marker_adapter.queue_free()
	marker_adapter = null
	var teardown: Dictionary = adapter.public_teardown()
	var adapter_id := adapter.get_instance_id()
	adapter.queue_free()
	adapter = null
	await _settle_render()
	var released := instance_from_id(adapter_id) == null
	var player_released := player_weak.get_ref() == null
	var frame_delta := Support.object_delta(Support.object_counts(), before)
	var frame_retained := false
	for key: String in ["objects", "resources", "nodes", "orphan_nodes"]:
		frame_retained = frame_retained or int(frame_delta.get(key, 0)) > 0
	if not released or not player_released \
			or (frame_retained and not allow_cache_growth):
		_fail("%s retained its capture composition" % seam_id)
	var frame_ok := save_error == OK and released and player_released \
			and (allow_cache_growth or not frame_retained) \
			and bool(readability.get("passed", false)) \
			and bool(occlusion.get("passed", false)) \
			and str(production_composition.get("status", "FAIL")) == "PASS"
	return {
		"status":"PASS" if frame_ok else "FAIL",
		"recorded_packet_frame":record_output,
		"cache_growth_allowed":allow_cache_growth,
		"id":view.get("id", ""),
		"seam_id":seam_id,
		"png":png_path,
		"png_sha256":hash,
		"dimensions":[dimensions.x, dimensions.y],
		"root":"M11C1Capture/TargetCells",
		"profile":_profile_label(),
		"residency_set":cell_ids,
		"simulation_state":"target cells + real marker doors/details + production PlayerController camera",
		"camera":camera_receipt,
		"camera_occlusion":occlusion,
		"readability":readability,
		"production_presentation":production_composition,
		"source_owned_doors":doors,
		"metrics":metrics,
		"performance":performance,
		"door_teardown":door_teardown,
		"public_teardown":teardown,
		"owner_released":released,
		"player_released":player_released,
		"delta":frame_delta,
		"retained_count_classes":_positive_count_classes(frame_delta),
	}


func _apply_camera(camera: Camera3D, view: Dictionary) -> void:
	var target := Support.vector3(view.get("target", []))
	camera.fov = float(view.get("fov_degrees", 70.0))
	camera.look_at(target, Vector3.UP)
	camera.make_current()


func _compose_production_presentation(adapter: Node3D,
		cell_ids: Array[String], layout: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	if "CELL_ORISON_F01_INTERIOR" in cell_ids \
			or "CELL_ORISON_FACADE_SHELL" in cell_ids:
		var scoped_layout := Support.f01_layout(layout)
		if scoped_layout.is_empty():
			rows.append({"production_class":"OrisonDetailPass",
					"status":"FAIL",
					"reason":"unchanged layout does not contain exactly one F01 record"})
			return {"status":"FAIL", "executions":rows}
		var detail := OrisonDetailPass.new()
		detail.name = "M11C1CaptureOrisonDetailPass"
		adapter.add_child(detail)
		var detail_result: Dictionary = detail.build(scoped_layout,
				{"F01":adapter.composition_host})
		rows.append({"production_class":"OrisonDetailPass",
				"public_api":"build",
				"layout_scope":"unchanged F01 authoring record only",
				"result":detail_result,
				"status":"PASS" if not detail_result.is_empty() else "FAIL"})
	if "CELL_SITE_STREET_COMMON" in cell_ids:
		var street: Node = adapter.registry.instance_for_cell(
				"CELL_SITE_STREET_COMMON")
		if street == null:
			rows.append({"production_class":"ExteriorDetailPass",
					"status":"FAIL", "reason":"street cell instance absent"})
		else:
			var exterior := ExteriorDetailPass.new()
			exterior.name = "M11C1CaptureExteriorDetailPass"
			street.add_child(exterior)
			var exterior_result: Dictionary = exterior.build(layout, street)
			rows.append({"production_class":"ExteriorDetailPass",
					"public_api":"build", "result":exterior_result,
					"status":"PASS" if not exterior_result.is_empty() else "FAIL"})
	var environment_row := _mount_production_environment(adapter)
	rows.append(environment_row)
	var ok := true
	for row: Dictionary in rows:
		ok = ok and str(row.get("status", "FAIL")) == "PASS"
	return {"status":"PASS" if ok else "FAIL", "executions":rows}


func _mount_production_environment(adapter: Node3D) -> Dictionary:
	var packed := ResourceLoader.load(M11A_SCENE, "PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return {"status":"FAIL", "reason":"production M11A scene unavailable"}
	# Read the production scene's Environment property from its SceneState.
	# Instantiating the whole M11A composition here would create geometry that
	# the capture is forbidden to use and would require an immediate free() of
	# an off-tree node.  Type/property lookup keeps this resource-only and makes
	# the no-force-deletion lifecycle claim literal.
	var state := packed.get_state()
	var source_environment: Environment = null
	for node_index in state.get_node_count():
		if state.get_node_type(node_index) != &"WorldEnvironment":
			continue
		for property_index in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index,
					property_index) != &"environment":
				continue
			var value: Variant = state.get_node_property_value(node_index,
					property_index)
			if value is Environment:
				source_environment = value as Environment
	if source_environment == null:
		return {"status":"FAIL", "reason":"production environment resource absent"}
	var world := WorldEnvironment.new()
	world.name = "M11C1ProductionM11AEnvironment"
	world.environment = source_environment.duplicate(true) as Environment
	adapter.add_child(world)
	packed = null
	return {"status":"PASS", "production_source_scene":M11A_SCENE,
			"production_source_sha256":Support.file_sha256(M11A_SCENE),
			"resource_class":"Environment", "geometry_extracted":false,
			"collision_extracted":false}


func _camera_occlusion(player: PlayerController, camera: Camera3D,
		target: Vector3) -> Dictionary:
	var total := camera.global_position.distance_to(target)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var hit_distance := total
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", camera.global_position)
		hit_distance = camera.global_position.distance_to(hit_position)
	var fraction := hit_distance / maxf(total, 0.001)
	return {"passed":fraction >= MINIMUM_TARGET_VISIBILITY_FRACTION,
			"target_distance_m":total, "first_hit_distance_m":hit_distance,
			"visible_fraction":fraction,
			"minimum_visible_fraction":MINIMUM_TARGET_VISIBILITY_FRACTION,
			"first_hit_class":hit.get("collider").get_class() \
					if hit.get("collider") is Object else ""}


func _image_readability(image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return {"passed":false, "reason":"viewport image unavailable"}
	var sample := image.duplicate() as Image
	sample.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var luma_total := 0.0
	var dark := 0
	var pixels := sample.get_width() * sample.get_height()
	for y: int in sample.get_height():
		for x: int in sample.get_width():
			var color := sample.get_pixel(x, y)
			var luma := (color.r * 0.2126 + color.g * 0.7152 \
					+ color.b * 0.0722) * 255.0
			luma_total += luma
			if luma < 16.0:
				dark += 1
	var mean := luma_total / maxf(1.0, float(pixels))
	var dark_fraction := float(dark) / maxf(1.0, float(pixels))
	return {"passed":mean >= MINIMUM_MEAN_LUMA \
			and dark_fraction <= MAXIMUM_DARK_PIXEL_FRACTION,
			"mean_luma_255":mean, "fraction_below_16":dark_fraction,
			"minimum_mean_luma_255":MINIMUM_MEAN_LUMA,
			"maximum_fraction_below_16":MAXIMUM_DARK_PIXEL_FRACTION,
			"sample_dimensions":[sample.get_width(), sample.get_height()]}


func _positive_count_classes(delta: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: String in ["objects", "resources", "nodes", "orphan_nodes"]:
		if int(delta.get(key, 0)) > 0:
			result.append(key)
	return result


func _load_layout() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			LAYOUT_PATH)) if FileAccess.file_exists(LAYOUT_PATH) else null
	if parsed is not Dictionary:
		_fail("unchanged runtime layout could not be read for capture doors")
		return {}
	return parsed as Dictionary


func _safe_slug(value: String) -> String:
	var result := ""
	for character: String in value.to_lower():
		result += character if character.is_valid_identifier() \
				or (character >= "0" and character <= "9") else "_"
	return result.substr(0, 80)


func _profile_label() -> String:
	return "%s/%s/%s" % [RenderingServer.get_current_rendering_method(),
			DisplayServer.get_name(), RenderingServer.get_video_adapter_name()]


func _settle_render() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _base_receipt(inputs: Dictionary) -> Dictionary:
	return {
		"schema":"orison.m11c1.target-cell-dangerous-seam-capture.v1",
		"status":"PENDING",
		"authority":"disposable_harness_only",
		"root":"M11C1OwnerFirstHarness/Capture",
		"profile":_profile_label(),
		"simulation_state":"real target cells and marker consumers; camera-only harness",
		"renderer":RenderingServer.get_current_rendering_method(),
		"input_provenance":{
			"config":inputs.get("config_path", ""),
			"config_sha256":inputs.get("config_sha256", ""),
			"partition_sha256":inputs.get("partition_sha256", ""),
			"lineage_sha256":inputs.get("lineage_sha256", ""),
			"equivalence_sha256":inputs.get("equivalence_sha256", ""),
		},
	}


func _finish(receipt: Dictionary) -> void:
	receipt["status"] = "FAIL" if not _failures.is_empty() else (
			"BLOCKED" if not _blockers.is_empty() else "PASS")
	receipt["failures"] = _failures
	receipt["blockers"] = _blockers
	var output := OS.get_environment(RECEIPT_ENV).strip_edges()
	if output.is_empty():
		output = DEFAULT_RECEIPT
	if not Support.write_json(output, receipt):
		push_error("M11C1 CAPTURE: could not write receipt")
		get_tree().quit(2)
		return
	print("M11C1 OWNER-FIRST CAPTURE: %s" % receipt.status)
	get_tree().quit(2 if receipt.status == "FAIL" else (
			3 if receipt.status == "BLOCKED" else 0))


func _fail(reason: String) -> void:
	if reason not in _failures:
		_failures.append(reason)
	push_error("M11C1 CAPTURE: " + reason)


func _block(reason: String) -> void:
	if reason not in _blockers:
		_blockers.append(reason)
	push_warning("M11C1 CAPTURE BLOCKED: " + reason)
