extends "res://tests/lamp_optics_l1b_review.gd"
## L1C exact-five visual gate. Uses accepted S2H runtime assets; no Orison edit.

const PROFILE_PATH := "res://../art/renders/lamp_optics_l1c/optimized/profile_receipt.json"
const FROXEL_48_PATH := "res://../art/renders/lamp_optics_l1c/froxel_48/profile_receipt.json"

var cellular: DreamSurfaceHeroPresenter
var cellular_light: OmniLight3D
var teardown_result := {}


func _ready() -> void:
	output_dir = "res://../art/renders/lamp_optics_l1c/review_01"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	vram_before = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	_build_calibration_room()
	await _settle(30)
	await _capture_l1c()
	await _clean_review_teardown()
	_write_l1c_receipt()
	get_tree().quit(0)


func _capture_l1c() -> void:
	await _capture_profile_table()
	_set_state(0.94, 2773.0, 1.0, 0.0)
	_set_columns(false)
	caption.text = "OPTIMIZED STABLE BEAM — HERO TIER"
	await _settle(30)
	await _save_view("02_optimized_stable_beam.png")
	_set_columns(true)
	caption.text = "TWO REAL OCCLUDERS — VOLUME CARVED"
	await _settle(24)
	await _save_view("03_carved_volumetric_occlusion.png")
	_set_columns(false)
	caption.text = "SHARED MATERIALS • BOUNDED DUST • DIRECTIONAL GOLD"
	await _settle(20)
	await _save_view("04_material_dust_gold_response.png")
	await _capture_cellular_sheet()


func _capture_profile_table() -> void:
	var profile := _load_json(PROFILE_PATH)
	var overlay := CanvasLayer.new()
	overlay.layer = 50
	add_child(overlay)
	var background := ColorRect.new()
	background.color = Color("11151b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	var title := Label.new()
	title.position = Vector2(58, 40)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("f3c889"))
	title.text = "LAMP-OPTICS-L1C — WARM FORWARD+ A/B PROFILE"
	overlay.add_child(title)
	var table := Label.new()
	table.position = Vector2(62, 108)
	table.add_theme_font_size_override("font_size", 19)
	table.add_theme_color_override("font_color", Color("e8edf2"))
	table.text = _profile_text(profile)
	overlay.add_child(table)
	await _settle(3)
	await _save_view("01_performance_ab_profile.png")
	overlay.queue_free()
	await _settle(3)


func _profile_text(profile: Dictionary) -> String:
	var froxel_48 := _load_json(FROXEL_48_PATH)
	var lines := PackedStringArray([
		"CONFIGURATION                         CPU WALL ms (MED / P95 / MAX)     GPU ms (MED / P95 / MAX)     DRAWS",
		"──────────────────────────────────────────────────────────────────────────────────────────────────────",
	])
	for key in profile.configurations.keys():
		if key == "teardown":
			continue
		var row: Dictionary = profile.configurations[key]
		lines.append("%-35s %6.3f / %6.3f / %6.3f       %6.3f / %6.3f / %6.3f     %5d" % [
			key, row.wall_frame_ms.median, row.wall_frame_ms.p95, row.wall_frame_ms.max,
			row.gpu_frame_ms.median, row.gpu_frame_ms.p95, row.gpu_frame_ms.max,
			int(row.draw_calls.median)])
	lines.append("")
	lines.append("Controller: %.5f ms/update (gate < 0.20 ms)" % profile.controller_cpu_ms_per_update)
	lines.append("GPU source: %s" % profile.gpu_instrumentation)
	lines.append("Capture excluded from ordinary frames: readback %.3f ms • resize/PNG %.3f ms" % [
		profile.capture_overhead.texture_readback_ms, profile.capture_overhead.resize_png_ms])
	lines.append("Froxel A/B, spot+fog GPU median: 64³ %.3f ms • 48³ %.3f ms (48³ retained only as low-cost evidence)" % [
		profile.configurations["05_spot_plus_fog"].gpu_frame_ms.median,
		froxel_48.configurations["05_spot_plus_fog"].gpu_frame_ms.median])
	lines.append("Focused feature delta is derived only by matched A/B rows; GPU is never inferred from CPU.")
	return "\n".join(lines)


func _capture_cellular_sheet() -> void:
	_set_visuals_visible(self, false)
	if rig:
		rig.visible = false
	cellular = DreamSurfaceHeroPresenter.new()
	cellular.name = "AcceptedS2HCellularInterior"
	add_child(cellular)
	cellular.setup(DreamSurfaceHeroPresenter.HeroKind.INTERIOR, null)
	cellular.force_lod(0)
	cellular.set_examination_mode(false)
	cellular.scale = Vector3.ONE * 0.50
	cellular.position = Vector3(0.0, 0.62, -3.2)
	cellular_light = OmniLight3D.new()
	cellular_light.light_color = Color("ffc493")
	cellular_light.light_energy = 4.0
	cellular_light.omni_range = 5.0
	cellular_light.omni_attenuation = 1.6
	cellular_light.shadow_enabled = true
	cellular_light.light_volumetric_fog_energy = 0.0
	add_child(cellular_light)
	var cellular_fill := DirectionalLight3D.new()
	cellular_fill.rotation_degrees = Vector3(-42, -28, 0)
	cellular_fill.light_color = Color("8fa8c4")
	cellular_fill.light_energy = 1.15
	cellular_fill.shadow_enabled = false
	cellular_fill.light_volumetric_fog_energy = 0.0
	add_child(cellular_fill)
	camera.position = Vector3(3.2, 2.05, 0.25)
	camera.look_at(cellular.position + Vector3(0, 0.12, 0))
	camera.fov = 37.0
	camera.make_current()
	var subject := cellular.global_position + Vector3(0, 0.12, 0)
	var to_camera := (camera.global_position - subject).normalized()
	var right := camera.global_transform.basis.x.normalized()
	var views: Array[Image] = []
	for setup in [
		{"label": "FRONT — WET MEMBRANE / CILIA / PHASE BOUNDARY",
			"energy": 3.2, "position": subject + to_camera * 2.0 + right * 0.55 + Vector3.UP * 0.35},
		{"label": "SIDE — THICKNESS / RIDGES / ANISOTROPIC GOLD",
			"energy": 6.0, "position": subject + right * 2.1 + Vector3.UP * 0.32},
		{"label": "BACK — TRANSMISSION / CLOUDY CYTOPLASM / DEPTH",
			"energy": 8.0, "position": subject - to_camera * 1.7 + Vector3.UP * 0.22},
	]:
		cellular_light.global_position = setup.position
		cellular_light.light_energy = setup.energy
		caption.text = setup.label
		await _settle(18)
		views.append(await _grab())
	_save_contact_sheet(views, 3, 1, "05_cellular_front_side_back.png")


func _clean_review_teardown() -> void:
	var cellular_ref: WeakRef = weakref(cellular)
	var rig_ref: WeakRef = weakref(rig)
	if cellular_light:
		cellular_light.visible = false
		cellular_light.light_cull_mask = 0
		cellular_light.queue_free()
	if rig:
		if rig.light:
			rig.light.visible = false
			rig.light.light_cull_mask = 0
			rig.light.light_energy = 0.0
		if rig.fog_volume:
			rig.fog_volume.material = null
		if rig.particles:
			rig.particles.emitting = false
			rig.particles.process_material = null
		rig.queue_free()
	if cellular:
		cellular.queue_free()
	world_environment.environment = null
	for child in get_children():
		child.queue_free()
	for _i in 16:
		await RenderingServer.frame_post_draw
	teardown_result = {
		"retained_cellular_presenter": cellular_ref.get_ref() != null,
		"retained_optical_rig": rig_ref.get_ref() != null,
		"render_objects_after_release": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"resource_count_after_release": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"result": "clean" if RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME) == 0 else "retained_render_objects",
	}


func _write_l1c_receipt() -> void:
	var profile := _load_json(PROFILE_PATH)
	var froxel_48 := _load_json(FROXEL_48_PATH)
	profile.packet = "LAMP-OPTICS-L1C/review_01"
	profile.acceptance_artifacts = 5
	profile.calibration_and_cellular_teardown = teardown_result
	profile.full_orison_teardown = {
		"result": "blocked_by_clean_main_godot_4_7_1_renderer_bug",
		"clean_main_pairing_error_count": 1264,
		"l1c_pairing_error_count_before_isolation": 1246,
		"retained_render_objects_after_error": 0,
		"error": "BUG, indexing did not unpair geometries from light.",
		"owner_class": "Orison internal Light3D RIDs paired to batched GeometryInstance3D RIDs",
	}
	profile.cellular_asset = {
		"source": "approved S2H cellular_interior LOD0/1/2",
		"authority": "presentation-only consumer",
		"materials_shared": 4,
		"emissive_gold": false,
		"painted_internal_anatomy": false,
	}
	profile.froxel_ab = {
		"default_64": profile.configurations["05_spot_plus_fog"],
		"lower_cost_48": froxel_48.configurations["05_spot_plus_fog"],
		"decision": "keep project default unchanged; production optical tier uses tighter local bounds, lower density, one noise octave, and 48 particles",
	}
	var configs: Dictionary = profile.configurations
	profile.optical_breakdown = {
		"main_thread_script_ms": profile.controller_cpu_ms_per_update,
		"main_thread_scope": "allocation-free LampOpticalState advance/output only; Godot TIME_PROCESS was stale under uncapped frame_post_draw sampling and is not misreported as script time",
		"physics_ms": {"status": "engine monitor stale in uncapped harness", "controller_measured_separately": true},
		"render_preparation_and_sync_cpu_delta_ms": configs["07_ecology_materials_added"].wall_frame_ms.median - configs["01_lamp_off"].wall_frame_ms.median,
		"shadow_gpu_delta_ms": configs["03_spot_with_shadows"].gpu_frame_ms.median - configs["02_spot_no_shadows"].gpu_frame_ms.median,
		"volumetric_fog_gpu_delta_ms": configs["05_spot_plus_fog"].gpu_frame_ms.median - configs["03_spot_with_shadows"].gpu_frame_ms.median,
		"particles_gpu_delta_ms": configs["06_particles_added"].gpu_frame_ms.median - configs["05_spot_plus_fog"].gpu_frame_ms.median,
		"transparent_sss_gpu_delta_ms": configs["07_ecology_materials_added"].gpu_frame_ms.median - configs["06_particles_added"].gpu_frame_ms.median,
		"capture_overhead_ms": profile.capture_overhead,
		"ordinary_frame_has_sync_readback": false,
	}
	profile.production_tier = {
		"fog_volume_size_m": [3.9, 3.9, 6.5], "fog_density_gain": 0.034,
		"fog_noise_octaves": 1, "particle_count": 48,
		"off_threshold": LampOpticalInstrument.USEFUL_INTENSITY,
		"hero_tier_particle_count": 120,
		"meshes_and_materials_shared": true,
		"per_frame_resource_loads": 0,
		"per_frame_image_readbacks": 0,
	}
	profile.vram_delta_optical_bytes = int(configs["07_ecology_materials_added"].vram_bytes) - int(configs["01_lamp_off"].vram_bytes)
	var file := FileAccess.open(output_dir + "/receipt.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(profile, "  "))


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else {}
