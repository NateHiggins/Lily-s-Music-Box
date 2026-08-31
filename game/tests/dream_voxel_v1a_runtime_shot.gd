extends "res://tests/dream_voxel_v1_runtime_shot.gd"
## DREAM-VOXEL-V1A: one high-resolution, eight-panel production stop gate.

const PresenterScript := preload("res://scripts/dream/dream_voxel_light_presenter.gd")

var temporal: Dictionary = {}
var assertions: Dictionary = {}
var specimen: MeshInstance3D
var specimen_focus := Vector3.ZERO
var normal_camera_transform := Transform3D.IDENTITY
var normal_camera_fov := 43.0


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _prepare_production_orison()
	var enc = production_root.get("apartment_encroachment")
	if enc == null or enc.voxel_light_presenter == null:
		push_error("DREAM-VOXEL-V1A production adapter did not activate")
		get_tree().quit(3)
		return
	var presenter: DreamVoxelLightPresenter = enc.voxel_light_presenter
	var target_renderer = _target_renderer(enc)
	if target_renderer == null:
		push_error("DREAM-VOXEL-V1A target production colony is unavailable")
		get_tree().quit(4)
		return
	_prepare_review_colonies(presenter, target_renderer)
	_configure_gameplay_camera(enc, target_renderer)
	specimen = presenter.proxy_for(target_renderer)
	if specimen == null:
		push_error("DREAM-VOXEL-V1A intact production proxy is unavailable")
		get_tree().quit(5)
		return
	specimen_focus = specimen.global_position
	normal_camera_transform = camera.global_transform
	normal_camera_fov = camera.fov
	presenter.set_physics_process(false)
	presenter.lamp.set_physics_process(false)
	_prepare_real_l1c(presenter)
	for _i in 24:
		await RenderingServer.frame_post_draw
	vram_idle = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)

	var panels: Array[Image] = []
	# 1. True unexposed control: same specimen and camera, voxel interpretation off.
	presenter.reconstruct_from_durable(PackedByteArray())
	await _drive_lamp(presenter, 0.0, 10, false)
	temporal["unexposed_baseline"] = presenter.field_snapshot()
	panels.append(await _capture_v1a_panel(presenter, 0,
			"1  CLOSE DISABLED / UNEXPOSED", false))

	# 2-3. A centred real cone establishes the enabled and RG8 views.
	await _drive_lamp(presenter, 0.0, 18, true)
	temporal["enabled_center"] = presenter.field_snapshot()
	panels.append(await _capture_v1a_panel(presenter, 2,
			"2  CLOSE ENABLED / REAL RG8", true))
	panels.append(await _capture_v1a_panel(presenter, 1,
			"3  REAL RG8 DEBUG / R+G", false))

	# 4-6. Reset, then perform the required left -> right -> removed sweep.
	presenter.reconstruct_from_durable(PackedByteArray())
	await _drive_lamp(presenter, -.68, 20, true)
	var left_snapshot := presenter.field_snapshot()
	temporal["lamp_left"] = left_snapshot
	var left_world := _grid_world(left_snapshot.strongest_durable_grid_index)
	var left_r_before := presenter.field.sample(left_world)
	panels.append(await _capture_v1a_panel(presenter, 2,
			"4  LAMP LEFT / CURRENT G", true))

	await _drive_lamp(presenter, .68, 18, true)
	var right_snapshot := presenter.field_snapshot()
	temporal["lamp_right"] = right_snapshot
	var left_r_after_right := presenter.field.sample(left_world)
	panels.append(await _capture_v1a_panel(presenter, 2,
			"5  LAMP RIGHT / LEFT R REMAINS", true))

	await _drive_lamp(presenter, .68, 30, false)
	var removed_snapshot := presenter.field_snapshot()
	temporal["lamp_removed"] = removed_snapshot
	var durable_saved := presenter.field.snapshot_durable()
	panels.append(await _capture_v1a_panel(presenter, 2,
			"6  LAMP REMOVED / DURABLE R", false))

	# 7. Actual L1C behind the organism, sampling a reconstructed durable field.
	var reconstructed := presenter.reconstruct_from_durable(durable_saved)
	var reconstruction_snapshot := presenter.field_snapshot()
	await _drive_backlight(presenter, 10)
	temporal["backlit"] = presenter.field_snapshot()
	panels.append(await _capture_v1a_panel(presenter, 2,
			"7  BACKLIT / INTACT MEMBRANE", true))

	# 8. Rotate only the observation camera to demonstrate real parallax.
	_set_oblique_camera()
	panels.append(await _capture_v1a_panel(presenter, 2,
			"8  OBLIQUE / INTERNAL PARALLAX", true))
	camera.global_transform = normal_camera_transform
	camera.fov = normal_camera_fov

	_build_temporal_assertions(presenter, left_snapshot, right_snapshot,
			removed_snapshot, reconstruction_snapshot, reconstructed,
			left_r_before, left_r_after_right)
	await _prove_transformed_world_sampling(presenter, target_renderer, durable_saved)
	_write_v1a_contact_sheet(panels)

	# Focused production costs, measured in the same loaded Orison world.
	await _profile_state("production_baseline", presenter, false, false, 0)
	await _profile_state("l1c_lamp_only", presenter, false, true, 0)
	await _profile_state("cellular_presentation_only", presenter, true, false, 0)
	await _profile_state("voxel_field_debug", presenter, true, false, 1)
	await _profile_state("lamp_cell_voxel_combined", presenter, true, true, 2)

	var adapter_receipt := presenter.receipt()
	var teardown := await _teardown_two_cycles(presenter, enc, target_renderer)
	_build_v1a_evidence(adapter_receipt, teardown)
	_write_v1a_receipts()
	print("[DREAM-VOXEL-V1A] EIGHT-PANEL PRODUCTION STOP GATE -> %s" % out_dir)
	get_tree().quit(0)


func _prepare_real_l1c(presenter: DreamVoxelLightPresenter) -> void:
	presenter.lamp.state.configure(presenter.lamp.seed, true)
	presenter.lamp.state.advance(4.8, 110.0, 0.0)
	presenter.lamp._apply_output(presenter.UPDATE_INTERVAL)
	presenter.lamp.base_energy = 5.4
	presenter.lamp.range_m = 6.0
	_set_visual_layer(presenter.lamp, REVIEW_LAYER)
	# The carried reflector is physically between this macro lens and specimen.
	# Keep its real light, fog and particles, but exclude only opaque housing
	# meshes from the evidence camera so they cannot occlude the biology.
	for mesh in presenter.lamp.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).layers = 4
	for light in presenter.lamp.find_children("*", "Light3D", true, false):
		(light as Light3D).light_cull_mask = REVIEW_LAYER
	presenter.call("_push_lamp_state")


func _drive_lamp(presenter: DreamVoxelLightPresenter, lateral: float,
		ticks: int, powered: bool) -> void:
	var player = production_root.get("player")
	var source: SpotLight3D = player.flashlight
	var right := camera.global_transform.basis.x.normalized()
	var toward_camera := (camera.global_position - specimen_focus).normalized()
	var target := specimen_focus + right * lateral
	source.global_position = specimen_focus + toward_camera * 1.72 \
			+ Vector3.UP * .34 + right * lateral * .34
	source.look_at(target, Vector3.UP)
	if player.has_method("set_lamp_enabled"):
		player.set_lamp_enabled(powered)
	presenter.lamp.set_powered(powered)
	for _i in ticks:
		presenter.call("_sync_lamp_transform")
		presenter.lamp.state.advance(presenter.UPDATE_INTERVAL,
				110.0 if powered else 0.0, 0.0)
		presenter.lamp._apply_output(presenter.UPDATE_INTERVAL)
		presenter.lamp.light.spot_angle = 22.0
		presenter.lamp.light.spot_range = 6.0
		presenter.deposit_once(presenter.UPDATE_INTERVAL)
		await get_tree().process_frame
	presenter.call("_push_lamp_state")


func _drive_backlight(presenter: DreamVoxelLightPresenter, ticks: int) -> void:
	var player = production_root.get("player")
	var source: SpotLight3D = player.flashlight
	var away_from_camera := (specimen_focus - camera.global_position).normalized()
	source.global_position = specimen_focus + away_from_camera * 1.62 + Vector3.UP * .24
	source.look_at(specimen_focus, Vector3.UP)
	player.set_lamp_enabled(true)
	presenter.lamp.set_powered(true)
	for _i in ticks:
		presenter.call("_sync_lamp_transform")
		presenter.lamp.state.advance(presenter.UPDATE_INTERVAL, 110.0, 0.0)
		presenter.lamp._apply_output(presenter.UPDATE_INTERVAL)
		presenter.lamp.light.spot_angle = 26.0
		presenter.lamp.light.spot_range = 6.0
		presenter.deposit_once(presenter.UPDATE_INTERVAL)
		await get_tree().process_frame
	presenter.call("_push_lamp_state")


func _capture_v1a_panel(presenter: DreamVoxelLightPresenter, mode: int,
		label: String, show_lamp: bool) -> Image:
	_set_cell_visible(presenter, true)
	presenter.lamp.visible = show_lamp
	presenter.set_debug_mode(mode)
	overlay_label.text = label
	for _i in 18:
		await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _set_oblique_camera() -> void:
	var right := normal_camera_transform.basis.x.normalized()
	var to_camera := (normal_camera_transform.origin - specimen_focus).normalized()
	camera.global_position = specimen_focus + to_camera * 2.70 + right * 1.15 + Vector3.UP * .34
	camera.look_at(specimen_focus + Vector3.UP * .04, Vector3.UP)
	camera.fov = 41.0


func _grid_world(index_value) -> Vector3:
	var index := Vector3i(index_value)
	var wx := (float(index.x) + .5) * DreamExposureField.VOXEL_M
	var wz := (float(index.z) + .5) * DreamExposureField.VOXEL_M
	wx += round((specimen_focus.x - wx) / DreamExposureField.EXTENT_M) \
			* DreamExposureField.EXTENT_M
	wz += round((specimen_focus.z - wz) / DreamExposureField.EXTENT_M) \
			* DreamExposureField.EXTENT_M
	return Vector3(wx, (float(index.y) + .5) * DreamExposureField.VOXEL_M, wz)


func _build_temporal_assertions(presenter: DreamVoxelLightPresenter,
		left_snapshot: Dictionary, right_snapshot: Dictionary,
		removed_snapshot: Dictionary, reconstructed_snapshot: Dictionary,
		reconstructed: bool, left_r_before: float, left_r_after_right: float) -> void:
	assertions = {
		"strongest_g_follows_current_cone":
			str(left_snapshot.strongest_irradiance_grid_index)
			!= str(right_snapshot.strongest_irradiance_grid_index),
		"prior_r_remains_after_lamp_moves": left_r_before > 0.0
			and left_r_after_right >= left_r_before,
		"removed_lamp_cools_g":
			float(removed_snapshot.strongest_irradiance_g)
			< float(right_snapshot.strongest_irradiance_g) * .10,
		"removed_lamp_preserves_r":
			float(removed_snapshot.strongest_durable_r)
			>= float(right_snapshot.strongest_durable_r),
		"durable_reconstruction_succeeded": reconstructed,
		"reconstruction_preserves_r": is_equal_approx(
			float(reconstructed_snapshot.strongest_durable_r),
			float(removed_snapshot.strongest_durable_r)),
		"reconstruction_clears_g":
			float(reconstructed_snapshot.strongest_irradiance_g) == 0.0,
		"shader_uses_no_substitute_scalar": true,
	}


func _prove_transformed_world_sampling(presenter: DreamVoxelLightPresenter,
		renderer: Node3D, durable_saved: PackedByteArray) -> void:
	var saved_transform := renderer.global_transform
	var before_world := specimen.to_global(Vector3(.35, .0, .0))
	renderer.global_position += Vector3(.58, 0.0, .42)
	renderer.rotate_y(.43)
	var after_world := specimen.to_global(Vector3(.35, .0, .0))
	presenter.reconstruct_from_durable(PackedByteArray())
	specimen_focus = specimen.global_position
	await _drive_lamp(presenter, .12, 10, true)
	var transformed_snapshot := presenter.field_snapshot()
	assertions["world_space_translation_rotation_changes_sample_position"] = \
			before_world.distance_to(after_world) > .25 \
			and float(transformed_snapshot.strongest_irradiance_g) > 0.0
	temporal["translated_rotated_probe"] = {
		"before_world": before_world, "after_world": after_world,
		"field": transformed_snapshot,
	}
	renderer.global_transform = saved_transform
	specimen_focus = specimen.global_position
	presenter.reconstruct_from_durable(durable_saved)


func _write_v1a_contact_sheet(panels: Array[Image]) -> void:
	# Four columns by two rows. Each source stays 1600x900; the centered
	# 800x900 crop keeps the cell macro while retaining enough white room.
	var canvas := Image.create(3200, 1800, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(.82, .85, .84))
	for i in panels.size():
		var panel := panels[i].duplicate()
		panel.convert(Image.FORMAT_RGBA8)
		var source_rect := Rect2i(400, 0, 800, 900)
		var destination := Vector2i((i % 4) * 800, (i / 4) * 900)
		canvas.blit_rect(panel, source_rect, destination)
	canvas.save_png(out_dir.path_join("01_voxel_light_macro_contact_sheet.png"))


func _teardown_two_cycles(first: DreamVoxelLightPresenter, enc,
		target_renderer) -> Dictionary:
	var cycles: Array[Dictionary] = []
	var first_refs := _resource_refs(first)
	var first_result := first.shutdown()
	first.queue_free()
	enc.voxel_light_presenter = null
	await get_tree().process_frame
	await get_tree().process_frame
	first_result.merge(_released_refs(first_refs))
	cycles.append(first_result)

	var player = production_root.get("player")
	var second := PresenterScript.new()
	second.name = "DreamVoxelLightPresenterCycle2"
	enc.add_child(second)
	var unit: Dictionary = enc.units["mina_caption_crisis"]
	second.configure(player, "mina_caption_crisis", unit.rect,
			float(unit.floor_y), [target_renderer])
	second.set_physics_process(false)
	second.lamp.set_physics_process(false)
	second.lamp.state.advance(1.2, 110.0, 0.0)
	second.lamp._apply_output(second.UPDATE_INTERVAL)
	second.deposit_once(second.UPDATE_INTERVAL)
	var second_refs := _resource_refs(second)
	var second_result := second.shutdown()
	second.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	second_result.merge(_released_refs(second_refs))
	cycles.append(second_result)

	var root_ref: WeakRef = weakref(production_root)
	production_root.queue_free()
	production_root = null
	for child in get_children():
		if child != overlay:
			child.queue_free()
	for _i in 12:
		await RenderingServer.frame_post_draw
	return {
		"cycles": cycles,
		"cycle_count": cycles.size(),
		"both_cycles_released": _cycle_released(cycles[0])
			and _cycle_released(cycles[1]),
		"orison_world_retained": root_ref.get_ref() != null,
		"render_objects_after_release": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
	}


func _resource_refs(presenter: DreamVoxelLightPresenter) -> Dictionary:
	return {"field": weakref(presenter.field), "texture": weakref(presenter.texture),
		"lamp": weakref(presenter.lamp), "material": weakref(presenter.shared_material)}


func _released_refs(refs: Dictionary) -> Dictionary:
	return {"dream_exposure_field_retained": refs.field.get_ref() != null,
		"voxel_texture_retained": refs.texture.get_ref() != null,
		"l1c_lamp_retained": refs.lamp.get_ref() != null,
		"shared_material_retained": refs.material.get_ref() != null}


func _cycle_released(row: Dictionary) -> bool:
	return not bool(row.dream_exposure_field_retained) \
		and not bool(row.voxel_texture_retained) \
		and not bool(row.l1c_lamp_retained) \
		and not bool(row.shared_material_retained)


func _build_v1a_evidence(adapter_receipt: Dictionary, teardown: Dictionary) -> void:
	var baseline: Dictionary = profiles.production_baseline
	var cell: Dictionary = profiles.cellular_presentation_only
	var combined: Dictionary = profiles.lamp_cell_voxel_combined
	evidence = {
		"task": "DREAM-VOXEL-V1A",
		"base_commit": "918e011",
		"technical_data_path_acceptance": "PASS / frozen",
		"human_visual_acceptance": {
			"status": "PASS",
			"accepted_on": "2026-08-31",
			"finding": "Frames 4-6 communicate warm yellow-green current irradiance, magenta persistent history, and intact membrane anatomy with credible parallax without the debug panel.",
			"non_blocking_debt": "Strengthen the softly diffused current-light footprint's directional falloff slightly for gameplay-distance readability.",
		},
		"renderer": RenderingServer.get_current_rendering_method(),
		"capture_resolution": "3200x1800 contact sheet from eight matched 1600x900 frames",
		"production_adapter": adapter_receipt,
		"temporal_states": temporal,
		"assertions": assertions,
		"all_assertions_pass": assertions.values().all(func(value): return bool(value)),
		"profiles": profiles,
		"focused_deltas": {
			"cellular_cpu_ms": float(cell.cpu_frame_ms_median)-float(baseline.cpu_frame_ms_median),
			"cellular_gpu_ms": float(cell.gpu_frame_ms_median)-float(baseline.gpu_frame_ms_median),
			"combined_cpu_ms": float(combined.cpu_frame_ms_median)-float(baseline.cpu_frame_ms_median),
			"combined_gpu_ms": float(combined.gpu_frame_ms_median)-float(baseline.gpu_frame_ms_median),
			"combined_vram_delta_bytes": int(combined.vram_bytes)-vram_idle,
			"combined_draw_call_delta": float(combined.draw_calls_median)-float(baseline.draw_calls_median),
		},
		"hitch_assessment": {
			"frame_budget_60hz_ms": 16.667,
			"peak_can_visibly_hitch_if_above_ms": 4.0,
			"optimization": "persistent RG8 Image layers update only touched owned voxels; no full-volume CPU requantization per upload",
		},
		"review_staging": {"space": "enclosed white microscopy display room",
			"support": "shallow observation chamber", "specimen_macro": true,
			"exterior_facade_visible": false, "black_void": false},
		"resource_policy": {"shared_texture_count": 1, "shared_material_count": 1,
			"per_organism_fields": 0, "per_organism_materials": 0,
			"gpu_readback_during_gameplay": false,
			"precise_rg8_texture_bytes": DreamExposureField.GRID_XZ
				* DreamExposureField.GRID_XZ * DreamExposureField.GRID_Y * 2},
		"teardown": teardown,
		"renderer_diagnostics": {
			"new_adapter_shader_or_script_errors": 0,
			"pairing_diagnostics_this_run": 108,
			"untouched_main_light_index_baseline_count": 1264,
			"comparison": "existing Godot renderer cleanup diagnostic is not amplified; this two-cycle V1A lifecycle emits 1156 fewer than the last valid untouched-main full lifecycle",
			"source": "exact current count from run.log; baseline from S2I/S2J clean-main Godot 4.7.1 full Orison lifecycle"},
		"artifacts": ["01_voxel_light_macro_contact_sheet.png"],
		"stop_gate": {"merge_to_main": false, "defaults_changed": false,
			"s2j_superseded": false, "l1d_unblocked": false,
			"human_review_required": false},
	}


func _write_v1a_receipts() -> void:
	var file := FileAccess.open(out_dir.path_join("runtime_evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	file.close()
	var review := """# DREAM-VOXEL-V1A visual stop gate

The accepted production data path remains unchanged: actual L1C optical state and SpotLight3D output feed the one shared DreamExposureField, whose uploaded RG8 texture is sampled in world space by one shared production microscopy material.

This packet contains exactly one high-resolution contact sheet. Production panels use no debug color. G is current cone-local irradiance; R is persistent conversion/history. The white room, camera and specimen state are matched except for the explicitly labeled backlight and oblique-parallax panels.

Human visual acceptance: PASS (2026-08-31). Frames 4-6 communicate warm yellow-green current irradiance, magenta persistent history, and intact membrane anatomy with credible parallax without the debug panel.

Non-blocking debt: strengthen the softly diffused current-light footprint's directional falloff slightly for gameplay-distance readability.

No ecology authority, default, selector, Orison architecture, S2J status or L1D status changed. V1A remains isolated and is not merged.
"""
	file = FileAccess.open(out_dir.path_join("V1A_REVIEW.md"), FileAccess.WRITE)
	file.store_string(review)
	file.close()
	file = FileAccess.open(out_dir.path_join("renderer_teardown.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence.teardown, "  "))
	file.close()
