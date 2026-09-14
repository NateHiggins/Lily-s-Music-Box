extends Node
## Matched original/recomposed seam capture for the external rehearsal project.
## The harness contributes one camera and no geometry, lights, environment,
## labels or arrows. Camera records come from the split receipt where present;
## plane-derived fallback views are explicitly marked UNPROVEN for framing.

const Support := preload("res://m11c0_harness_support.gd")
const CompositionScript := preload("res://m11c0_cell_composition.gd")
const EXPECTED_SIZE := Vector2i(1600, 900)
const RECEIPT_ENV := "M11C0_CAPTURE_RECEIPT"
const OUTPUT_ENV := "M11C0_CAPTURE_DIR"

var _failures: Array[String] = []
var _unproven: Array[String] = []
var _camera: Camera3D
var _run_state_provenance := {}


func _ready() -> void:
	_run_state_provenance = {
		"class": "engine-internal GDScript coroutine await-state",
		"owner": "M11C0Capture._run awaited by _ready",
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
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("capture requires Forward+; observed %s" %
				RenderingServer.get_current_rendering_method())
		_finish(_base_receipt(inputs))
		return
	var output_dir := OS.get_environment(OUTPUT_ENV).strip_edges()
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://captures")
	elif output_dir.begins_with("res://") or output_dir.begins_with("user://"):
		output_dir = ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(output_dir)
	_camera = Camera3D.new()
	_camera.name = "MatchedEvidenceCamera"
	_camera.near = 0.05
	_camera.far = 500.0
	add_child(_camera)
	_camera.make_current()
	RenderingServer.viewport_set_measure_render_time(
			get_viewport().get_viewport_rid(), true)
	await _settle_render()
	var views := _capture_views(inputs.config, inputs.manifest)
	if views.is_empty():
		_fail("no explicit or derivable seam capture views were available")
		_finish(_base_receipt(inputs))
		return
	# Warm both subject paths before the lifecycle baseline. This isolates import
	# and renderer cache initialization from capture-owned retention.
	await _warm_subject([{"id":"ORIGINAL_FLOOR_01",
			"scene_path":inputs.original_scene_path}])
	await _warm_subject(inputs.cells)
	var warmed_baseline: Dictionary = Support.object_counts()
	var pairs: Array[Dictionary] = []
	var pair_index := 1
	for view: Dictionary in views:
		var prefix := "%02d_%s" % [pair_index, _safe_slug(str(view.id))]
		var original_path := output_dir.path_join(prefix + "_original.png")
		var recomposed_path := output_dir.path_join(prefix + "_recomposed.png")
		var original := await _capture_subject("original",
				[{"id":"ORIGINAL_FLOOR_01",
				"scene_path":inputs.original_scene_path}], view, original_path)
		var recomposed := await _capture_subject("recomposed", inputs.cells,
				view, recomposed_path)
		var comparison := _compare_pngs(original_path, recomposed_path)
		pairs.append({
			"view": view,
			"original": original,
			"recomposed": recomposed,
			"pixel_comparison": comparison,
			"matched_camera": original.get("camera", {}) \
					== recomposed.get("camera", {}),
		})
		if original.get("camera", {}) != recomposed.get("camera", {}):
			_fail("%s did not preserve an identical camera transform" % str(view.id))
		pair_index += 1
	await _settle_render()
	# Count only after this coroutine and _ready release their function-state
	# Objects. The deferred non-coroutine finalizer prevents the instrument from
	# diagnosing its own active await state as capture retention.
	call_deferred("_finalize_after_capture", {
		"inputs": inputs,
		"output_directory": output_dir,
		"warmed_baseline": warmed_baseline,
		"pairs": pairs,
	})


func _finalize_after_capture(pending: Dictionary) -> void:
	var inputs: Dictionary = pending.inputs
	var output_dir := str(pending.output_directory)
	var warmed_baseline: Dictionary = pending.warmed_baseline
	var pairs: Array = pending.pairs
	var final_counts: Dictionary = Support.object_counts()
	var lifecycle_delta := Support.delta(final_counts, warmed_baseline)
	if _scene_retention(lifecycle_delta):
		_fail("capture pairs retain resources/nodes beyond the warmed plateau")
	elif int(lifecycle_delta.get("objects", 0)) > 0:
		_mark_unproven("capture harness lifetime retains %d non-node, non-resource ObjectDB object(s); every mounted subject ID is released" % int(lifecycle_delta.objects))
	var receipt := _base_receipt(inputs)
	receipt.merge({
		"output_directory": output_dir,
		"resolution": [EXPECTED_SIZE.x, EXPECTED_SIZE.y],
		"warmed_baseline": warmed_baseline,
		"pairs": pairs,
		"final_counts": final_counts,
		"lifecycle_delta": lifecycle_delta,
		"capture_boundary": {
			"harness_added_geometry": false,
			"harness_added_lights": false,
			"harness_added_world_environment": false,
			"harness_added_labels_or_arrows": false,
			"camera_only": true,
			"public_teardown_api": "M11C0CellComposition.public_teardown",
			"node_name_reach_ins": false,
			"forced_object_deletion": false,
			"instrument_coroutine_state": _run_state_provenance,
			"final_observation_boundary": "deferred non-coroutine after _run and _ready release their await states",
		},
	}, true)
	_finish(receipt)


func _capture_subject(kind: String, descriptors: Array, view: Dictionary,
		png_path: String) -> Dictionary:
	var before: Dictionary = Support.object_counts()
	var composition = CompositionScript.new()
	composition.name = "OriginalSubject" if kind == "original" \
			else "RecomposedSubject"
	add_child(composition)
	var instance_ids: Array[int] = []
	var load_rows: Array[Dictionary] = []
	for raw: Variant in descriptors:
		if raw is not Dictionary:
			continue
		var descriptor := raw as Dictionary
		var started := Time.get_ticks_usec()
		var packed: PackedScene = Support.load_packed_scene(
				str(descriptor.get("scene_path", "")))
		var load_ms := _elapsed_ms(started)
		if packed == null:
			_fail("capture could not load %s" % str(descriptor.get("scene_path", "")))
			continue
		started = Time.get_ticks_usec()
		var instance: Node = composition.mount_packed(
				str(descriptor.get("id", "UNNAMED")), packed)
		var instantiate_ms := _elapsed_ms(started)
		if instance == null:
			_fail("capture could not instantiate %s" % str(descriptor.get("id", "")))
		else:
			instance_ids.append(instance.get_instance_id())
		load_rows.append({"id":descriptor.get("id", ""),
				"path":descriptor.get("scene_path", ""), "load_ms":load_ms,
				"instantiate_ms":instantiate_ms, "ok":instance != null})
		instance = null
		packed = null
	_apply_camera(view)
	await _settle_render()
	var metrics: Dictionary = Support.tree_metrics(composition)
	var render_metrics := _render_metrics()
	var image := get_viewport().get_texture().get_image()
	var save_error := ERR_CANT_CREATE
	if image != null and not image.is_empty():
		save_error = image.save_png(png_path)
	var dimensions := image.get_size() if image != null else Vector2i.ZERO
	image = null
	var png_hash := Support.file_sha256(png_path) if save_error == OK else ""
	if save_error != OK or dimensions != EXPECTED_SIZE or png_hash.length() != 64:
		_fail("%s/%s did not produce a %dx%d hashed PNG" % [
				view.id, kind, EXPECTED_SIZE.x, EXPECTED_SIZE.y])
	var public_teardown: Dictionary = composition.public_teardown()
	var composition_id := composition.get_instance_id()
	composition.queue_free()
	composition = null
	await _settle_render()
	var unreleased: Array[int] = []
	for instance_id: int in instance_ids:
		if instance_from_id(instance_id) != null:
			unreleased.append(instance_id)
	if instance_from_id(composition_id) != null:
		unreleased.append(composition_id)
	if not unreleased.is_empty():
		_fail("%s/%s retained subject instances after public teardown" % [
				view.id, kind])
	var after: Dictionary = Support.object_counts()
	return {
		"kind": kind,
		"png": png_path,
		"png_sha256": png_hash,
		"dimensions": [dimensions.x, dimensions.y],
		"save_error": save_error,
		"camera": _camera_provenance(view),
		"subject_metrics": metrics,
		"render_metrics": render_metrics,
		"subject_light_count": metrics.get("lights", 0),
		"load_rows": load_rows,
		"before": before,
		"after_teardown": after,
		"teardown_delta": Support.delta(after, before),
		"public_teardown": public_teardown,
		"unreleased_instance_ids": unreleased,
	}


func _warm_subject(descriptors: Array) -> void:
	var composition = CompositionScript.new()
	composition.name = "WarmSubject"
	add_child(composition)
	for raw: Variant in descriptors:
		if raw is not Dictionary:
			continue
		var descriptor := raw as Dictionary
		var packed: PackedScene = Support.load_packed_scene(
				str(descriptor.get("scene_path", "")))
		if packed != null:
			composition.mount_packed(str(descriptor.get("id", "WARM")), packed)
		packed = null
	await _settle_render()
	composition.public_teardown()
	composition.queue_free()
	composition = null
	await _settle_render()


func _capture_views(config: Dictionary, manifest: Dictionary) -> Array[Dictionary]:
	var explicit: Variant = config.get("capture_views", [])
	var capture: Variant = config.get("capture", {})
	if (explicit is not Array or explicit.is_empty()) and capture is Dictionary:
		explicit = capture.get("views", [])
	if explicit is not Array or explicit.is_empty():
		explicit = manifest.get("capture_views", [])
	var views: Array[Dictionary] = []
	if explicit is Array:
		for raw: Variant in explicit:
			if raw is not Dictionary:
				continue
			var view := _normalized_view(raw as Dictionary, "split_receipt")
			if not view.is_empty():
				views.append(view)
	if not views.is_empty():
		return views
	# A plane alone can produce a matched diagnostic, but not prove that the
	# intended architecture is framed. Such captures are always marked UNPROVEN.
	for raw: Variant in manifest.get("shared_boundaries", []):
		if raw is not Dictionary:
			continue
		var seam := raw as Dictionary
		var derived := _derived_view(seam)
		if not derived.is_empty():
			views.append(derived)
			_mark_unproven("%s camera is plane-derived without an authored framing record" % str(seam.get("id", "UNNAMED")))
		else:
			_mark_unproven("%s has no finite capture plane or explicit camera; visual seam is UNPROVEN" % str(seam.get("id", "UNNAMED")))
	return views


func _normalized_view(raw: Dictionary, source: String) -> Dictionary:
	var eye := Support.vector3(raw.get("eye", raw.get("camera", [])))
	var target := Support.vector3(raw.get("target", raw.get("look_at", [])))
	if not eye.is_finite() or not target.is_finite() \
			or eye.distance_to(target) < 0.01:
		_mark_unproven("explicit capture view %s has invalid eye/target" %
				str(raw.get("id", "UNNAMED")))
		return {}
	return {
		"id": str(raw.get("id", raw.get("seam_id", "view"))),
		"seam_id": str(raw.get("seam_id", raw.get("id", ""))),
		"eye": Support.vector3_array(eye),
		"target": Support.vector3_array(target),
		"fov_degrees": float(raw.get("fov_degrees", raw.get("fov", 70.0))),
		"source": source,
		"framing_status": "PROVIDED",
	}


func _derived_view(seam: Dictionary) -> Dictionary:
	var axis := ""
	var value := NAN
	var plane: Variant = seam.get("plane", {})
	if plane is Dictionary:
		axis = str(plane.get("axis", ""))
		value = float(plane.get("value", NAN))
	elif seam.has("gltf_z"):
		axis = "z"
		value = float(seam.gltf_z)
	elif seam.has("source_plan_y") and seam.source_plan_y is not Array:
		axis = "z"
		value = float(seam.source_plan_y)
	elif seam.has("gltf_x"):
		axis = "x"
		value = float(seam.gltf_x)
	elif seam.has("source_plan_x") and seam.source_plan_x is not Array:
		axis = "x"
		value = float(seam.source_plan_x)
	if not is_finite(value) or axis not in ["x", "z"]:
		return {}
	var center := Support.vector3(seam.get("capture_center", []))
	if not center.is_finite():
		center = Vector3.ZERO
	var target := center + Vector3.UP * 1.15
	var eye := center + Vector3.UP * 1.65
	if axis == "z":
		target.z = value
		eye.z = value - 6.0
	else:
		target.x = value
		eye.x = value - 6.0
	return {
		"id": str(seam.get("id", "derived_seam")),
		"seam_id": str(seam.get("id", "")),
		"eye": Support.vector3_array(eye),
		"target": Support.vector3_array(target),
		"fov_degrees": 70.0,
		"source": "manifest_plane_fallback",
		"framing_status": "UNPROVEN",
	}


func _apply_camera(view: Dictionary) -> void:
	var eye := Support.vector3(view.eye)
	var target := Support.vector3(view.target)
	_camera.global_position = eye
	_camera.fov = float(view.get("fov_degrees", 70.0))
	_camera.look_at(target, Vector3.UP)
	_camera.make_current()


func _camera_provenance(view: Dictionary) -> Dictionary:
	return {
		"class": "Camera3D",
		"harness_camera": true,
		"eye": Support.vector3_array(_camera.global_position),
		"target": view.target,
		"forward": Support.vector3_array(
				-_camera.global_transform.basis.z.normalized()),
		"fov_degrees": _camera.fov,
		"near": _camera.near,
		"far": _camera.far,
		"source": view.source,
		"framing_status": view.framing_status,
	}


func _render_metrics() -> Dictionary:
	var viewport_rid := get_viewport().get_viewport_rid()
	return {
		"draw_calls": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"visible_primitives": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"render_objects": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(
				viewport_rid),
		"gpu_timing_claimed": RenderingServer.viewport_get_measured_render_time_gpu(
				viewport_rid) > 0.0,
	}


func _compare_pngs(first_path: String, second_path: String) -> Dictionary:
	var first_sha256 := Support.file_sha256(first_path)
	var second_sha256 := Support.file_sha256(second_path)
	var first := Image.load_from_file(first_path)
	var second := Image.load_from_file(second_path)
	if first == null or second == null or first.is_empty() or second.is_empty() \
			or first.get_size() != second.get_size():
		return {"status":"UNPROVEN", "reason":"PNG pair is missing or mismatched"}
	if first_sha256 == second_sha256:
		return {
			"status": "BYTE_IDENTICAL",
			"byte_identical": true,
			"first_sha256": first_sha256,
			"second_sha256": second_sha256,
			"stride_pixels": 0,
			"samples": first.get_width() * first.get_height(),
			"changed_samples": 0,
			"changed_fraction": 0.0,
			"mean_absolute_channel_difference": 0.0,
			"max_channel_difference": 0.0,
		}
	# A coarse stride hid a demonstrated 20-pixel raster-order difference at
	# the bodega threshold. Byte-different pairs therefore receive an exact
	# full-frame comparison; this is measurement, not a geometry-equivalence
	# substitute.
	var stride := 1
	var samples := 0
	var changed := 0
	var absolute_channel_sum := 0.0
	var max_channel_difference := 0.0
	for y in range(0, first.get_height(), stride):
		for x in range(0, first.get_width(), stride):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			var difference := Vector3(absf(a.r - b.r), absf(a.g - b.g),
					absf(a.b - b.b))
			var local_max := maxf(difference.x, maxf(difference.y, difference.z))
			if local_max > 1.0 / 255.0:
				changed += 1
			absolute_channel_sum += difference.x + difference.y + difference.z
			max_channel_difference = maxf(max_channel_difference, local_max)
			samples += 1
	return {
		"status": "MEASURED_FULL_FRAME",
		"byte_identical": false,
		"first_sha256": first_sha256,
		"second_sha256": second_sha256,
		"stride_pixels": stride,
		"samples": samples,
		"changed_samples": changed,
		"changed_fraction": float(changed) / maxf(1.0, float(samples)),
		"mean_absolute_channel_difference": absolute_channel_sum \
				/ maxf(1.0, float(samples * 3)),
		"max_channel_difference": max_channel_difference,
	}


func _base_receipt(inputs: Dictionary) -> Dictionary:
	return {
		"schema": "orison.m11c0.floor01-matched-capture.v1",
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


func _positive_retention(value: Dictionary) -> bool:
	return int(value.get("objects", 0)) > 0 \
			or int(value.get("resources", 0)) > 0 \
			or int(value.get("nodes", 0)) > 0 \
			or int(value.get("orphan_nodes", 0)) > 0


func _scene_retention(value: Dictionary) -> bool:
	return int(value.get("resources", 0)) > 0 \
			or int(value.get("nodes", 0)) > 0 \
			or int(value.get("orphan_nodes", 0)) > 0


func _safe_slug(value: String) -> String:
	var result := ""
	for character in value.to_lower():
		if character.is_valid_identifier() or character >= "0" and character <= "9":
			result += character
		else:
			result += "_"
	return result.strip_edges().strip_escapes().substr(0, 80)


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _settle_render() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _finish(receipt: Dictionary) -> void:
	receipt["status"] = "FAIL" if not _failures.is_empty() else (
			"PASS_WITH_UNPROVEN_VIEWS" if not _unproven.is_empty() else "PASS")
	receipt["failures"] = _failures
	receipt["unproven"] = _unproven
	var output := OS.get_environment(RECEIPT_ENV).strip_edges()
	if output.is_empty():
		output = ProjectSettings.globalize_path("res://m11c0_capture_receipt.json")
	if not Support.write_json(output, receipt):
		push_error("M11C0 CAPTURE: could not write receipt %s" % output)
		get_tree().quit(2)
		return
	print("M11C0 FLOOR01 CAPTURE: %s" % receipt.status)
	get_tree().quit(2 if receipt.status == "FAIL" else 0)


func _fail(reason: String) -> void:
	_failures.append(reason)
	push_error("M11C0 CAPTURE: " + reason)


func _mark_unproven(reason: String) -> void:
	if reason not in _unproven:
		_unproven.append(reason)
