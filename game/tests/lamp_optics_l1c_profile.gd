extends Node3D
## L1C profiling-only harness. No production scene or selector is modified.

const OUT_ENV := "L1C_PROFILE_OUT"
const WARM_FRAMES := 90
const SAMPLE_FRAMES := 120

var rig: LampOpticalInstrument
var environment: Environment
var world_environment: WorldEnvironment
var camera: Camera3D
var ecology_target: MeshInstance3D
var ecology_material: ShaderMaterial
var production_root: Node3D
var results := {}
var start_objects := 0
var start_resources := 0
var start_vram := 0
var capture_result := {}


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_build_stage()
	await _warm(WARM_FRAMES)
	start_objects = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	start_resources = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	start_vram = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	await _measure("01_lamp_off", false, false, false, false, false)
	await _measure("02_spot_no_shadows", true, false, false, false, false)
	await _measure("03_spot_with_shadows", true, true, false, false, false)
	await _measure("04_fog_only", false, false, true, false, false)
	await _measure("05_spot_plus_fog", true, true, true, false, false)
	await _measure("06_particles_added", true, true, true, true, false)
	await _measure("07_ecology_materials_added", true, true, true, true, true)
	# Full Orison destruction reproduces a clean-main Godot 4.7.1 assertion.
	# Keep it explicit so the default optical profile has a clean lifecycle.
	if OS.get_environment("L1C_INCLUDE_PRODUCTION") == "1":
		await _measure_production()
	await _time_capture()
	await _teardown()
	_write_receipt()
	get_tree().quit(0)


func _build_stage() -> void:
	world_environment = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("25292e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("899198")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0001
	environment.volumetric_fog_length = 12.0
	world_environment.environment = environment
	add_child(world_environment)
	camera = Camera3D.new()
	camera.position = Vector3(5.5, 2.7, 6.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, -3.0))
	add_child(camera)
	camera.make_current()
	_add_box(Vector3(11.0, 0.2, 14.0), Vector3(0, -0.1, -2.0), Color("70757b"))
	_add_box(Vector3(11.0, 4.8, 0.2), Vector3(0, 2.3, -8.5), Color("656b72"))
	for x in [-1.0, 1.0]:
		_add_box(Vector3(0.48, 2.6, 0.48), Vector3(x, 1.3, -3.8), Color("454a50"))
	rig = LampOpticalInstrument.new()
	rig.quality_tier = 1
	rig.range_m = 9.0
	rig.position = Vector3(0, 1.55, 2.2)
	rig.rotation_degrees.x = -5.0
	add_child(rig)
	rig.set_physics_process(false)
	ecology_target = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	ecology_target.mesh = sphere
	ecology_target.position = Vector3(2.25, 0.8, -4.2)
	ecology_material = ShaderMaterial.new()
	ecology_material.shader = load("res://shaders/lamp_ecology_optics.gdshader")
	ecology_target.material_override = ecology_material
	add_child(ecology_target)
	ecology_target.visible = false


func _measure(label: String, spot: bool, shadows: bool, fog: bool,
		particles_on: bool, ecology_on: bool) -> void:
	rig.light.visible = spot
	rig.light.shadow_enabled = shadows
	rig.light.light_energy = 4.2 if spot else 0.0
	rig.light.light_volumetric_fog_energy = 1.0 if spot and fog else 0.0
	if rig.fog_volume:
		rig.fog_volume.visible = fog
	if rig.particles:
		rig.particles.visible = particles_on
		rig.particles.emitting = particles_on
	ecology_target.visible = ecology_on
	await _warm(WARM_FRAMES)
	results[label] = await _sample()
	print("[L1C PROFILE] %s %s" % [label, JSON.stringify(results[label])])


func _measure_production() -> void:
	_set_calibration_visible(false)
	# Do not overlap the calibration light RID with Orison's thousands of
	# geometries. This was the exact owner of the branch-only unpair failure.
	if rig:
		if rig.particles:
			rig.particles.emitting = false
			rig.particles.process_material = null
		if rig.fog_volume:
			rig.fog_volume.material = null
		if rig.light:
			rig.light.light_energy = 0.0
			rig.light.light_volumetric_fog_energy = 0.0
		rig.queue_free()
		rig = null
	if ecology_target:
		ecology_target.material_override = null
		ecology_target.queue_free()
		ecology_target = null
	for _i in 12:
		await RenderingServer.frame_post_draw
	world_environment.environment = null
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	production_root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(production_root)
	for _i in 180:
		await get_tree().process_frame
	var player := production_root.get("player") as PlayerController
	if player:
		player.set_process(false)
		player.set_physics_process(false)
		player.set_lamp_enabled(false)
		player.visible = false
	_hide_ui(production_root)
	camera.global_position = GameBoot.b2g([7.95, -6.65, 1.62])
	camera.look_at(GameBoot.b2g([11.55, -7.15, 1.08]))
	camera.make_current()
	await _warm(WARM_FRAMES)
	results["08_furnished_production_room"] = await _sample()
	print("[L1C PROFILE] 08_furnished_production_room %s" % JSON.stringify(results["08_furnished_production_room"]))


func _sample() -> Dictionary:
	var wall: Array[float] = []
	var process: Array[float] = []
	var physics: Array[float] = []
	var gpu: Array[float] = []
	var draws: Array[float] = []
	var viewport_rid := get_viewport().get_viewport_rid()
	for _i in SAMPLE_FRAMES:
		var t0 := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		wall.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	return {
		"wall_frame_ms": _stats(wall),
		"main_process_ms": _stats(process),
		"physics_ms": _stats(physics),
		"gpu_frame_ms": _stats(gpu),
		"draw_calls": _stats(draws),
		"render_prepare_sync_residual_ms": _stats(_residual(wall, process, physics)),
		"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"vram_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
	}


func _time_capture() -> void:
	var t0 := Time.get_ticks_usec()
	await RenderingServer.frame_post_draw
	var sync_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	var image := get_viewport().get_texture().get_image()
	var readback_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	image.resize(1600, 900, Image.INTERPOLATE_LANCZOS)
	var encode := image.save_png(_out_dir().path_join("diagnostic_capture.png"))
	var encode_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	capture_result = {"frame_sync_ms": sync_ms, "texture_readback_ms": readback_ms,
		"resize_png_ms": encode_ms, "save_error": encode}
	image = null


func _teardown() -> void:
	var before_resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	if rig:
		rig.set_physics_process(false)
		if rig.light:
			rig.light.visible = false
			rig.light.light_energy = 0.0
			rig.light.light_volumetric_fog_energy = 0.0
		if rig.particles:
			rig.particles.emitting = false
			rig.particles.visible = false
			rig.particles.process_material = null
		if rig.fog_volume:
			rig.fog_volume.visible = false
			rig.fog_volume.material = null
	if ecology_target:
		ecology_target.material_override = null
	if world_environment:
		world_environment.environment = null
	if production_root:
		production_root.queue_free()
	if rig:
		rig.queue_free()
	if ecology_target:
		ecology_target.queue_free()
	for _i in 12:
		await get_tree().process_frame
	# Four post-draw frames below are the public synchronization boundary in
	# this Godot build; no private RenderingDevice flush is required.
	for _i in 4:
		await get_tree().process_frame
	results["teardown"] = {
		"resources_before_release": before_resources,
		"resources_after_release": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"resource_delta_from_stage_baseline": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) - start_resources,
		"render_objects_after_release": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"render_objects_stage_baseline": start_objects,
		"vram_after_release_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"renderer_sync_completed": true,
	}


func _write_receipt() -> void:
	var controller := LampOpticalState.new()
	controller.configure(1928, true)
	var t0 := Time.get_ticks_usec()
	for i in 20000:
		controller.advance(1.0 / 120.0, 110.0, 0.5 if i % 5000 == 0 else 0.0)
		controller.output()
	var controller_ms := float(Time.get_ticks_usec() - t0) / 20000.0 / 1000.0
	var receipt := {"packet": "LAMP-OPTICS-L1C/profile", "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "resolution": "1600x900",
		"warmup_frames": WARM_FRAMES, "sample_frames": SAMPLE_FRAMES,
		"controller_cpu_ms_per_update": controller_ms, "controller_gate_ms": 0.20,
		"configurations": results, "capture_overhead": capture_result,
		"vram_stage_baseline_bytes": start_vram,
		"froxel_volume_size": ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_size", 64),
		"froxel_volume_depth": ProjectSettings.get_setting("rendering/environment/volumetric_fog/volume_depth", 64),
		"gpu_instrumentation": "RenderingServer.viewport_get_measured_render_time_gpu",
		"timing_note": "Wall time awaits frame_post_draw; GPU time is engine-measured and is never inferred from CPU time."}
	var file := FileAccess.open(_out_dir().path_join("profile_receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  "))


func _out_dir() -> String:
	var path := OS.get_environment(OUT_ENV)
	if path.is_empty():
		path = ProjectSettings.globalize_path("res://../art/renders/lamp_optics_l1c/profile")
	DirAccess.make_dir_recursive_absolute(path)
	return path


func _warm(frames: int) -> void:
	for _i in frames:
		await RenderingServer.frame_post_draw


func _stats(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	return {"median": sorted[sorted.size() / 2],
		"p95": sorted[mini(sorted.size() - 1, int(ceil(sorted.size() * 0.95)) - 1)],
		"max": sorted[sorted.size() - 1]}


func _residual(wall: Array[float], process: Array[float], physics: Array[float]) -> Array[float]:
	var out: Array[float] = []
	for i in wall.size():
		out.append(maxf(0.0, wall[i] - process[i] - physics[i]))
	return out


func _add_box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	mesh_instance.material_override = material
	mesh_instance.position = at
	add_child(mesh_instance)


func _set_calibration_visible(on: bool) -> void:
	for child in get_children():
		if child != camera and child != world_environment:
			child.visible = on


func _hide_ui(node: Node) -> void:
	if node is CanvasLayer or node is Control:
		node.visible = false
	for child in node.get_children():
		_hide_ui(child)

