extends "res://tests/orison_v2_vertical_route_test.gd"
## Diagnostic only: real world/controller, raw frame samples, no ledger promotion.
var phase := "startup"
var samples: Array = []
var sampling := false
var last_usec := 0
var extra_monitors: Dictionary = {}

func _init() -> void:
	route_label = "V2 RESPONSIVENESS DIAGNOSTIC"

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if sampling and last_usec > 0:
		var rid := get_viewport().get_viewport_rid()
		samples.append([phase, (now-last_usec)/1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(rid),
			RenderingServer.viewport_get_measured_render_time_gpu(rid),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			world.passage_region.residency.state, _monitor_values()])
	last_usec = now

func _route() -> void:
	for monitor: String in ClassDB.class_get_integer_constant_list("Performance"):
		if monitor.begins_with("PIPELINE_COMPILATIONS_") or monitor in ["RENDER_VIDEO_MEM_USED","RENDER_TEXTURE_MEM_USED","RENDER_BUFFER_MEM_USED"]:
			extra_monitors[monitor]=ClassDB.class_get_integer_constant("Performance",monitor)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	player._grab.profiling=true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for i in 60: await get_tree().process_frame
	sampling = true
	for cycle in 2:
		phase = "lobby_turn_%d" % cycle
		for i in 120:
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(6, 0)
			player._unhandled_input(motion)
			await get_tree().process_frame
		phase = "walk_and_grab_%d" % cycle
		if not await _leave_front_entrance(): break
		phase = "street_turn_%d" % cycle
		for i in 120:
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(-6, 0)
			player._unhandled_input(motion)
			await get_tree().process_frame
		phase = "return_and_stream_%d" % cycle
		if not await _enter_front_entrance(): break
		if not await _walk(Vector3(1.925,0,-3.5)): break
	phase = "idle"
	for i in 120: await get_tree().process_frame
	sampling = false
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT", "kind":"performance_diagnostic",
		"columns":["phase","wall_ms","process_ms","physics_ms","render_cpu_ms","render_gpu_ms","draw_calls","primitives","residency","engine_monitors"],
		"resolution":str(get_viewport().get_visible_rect().size), "vsync":false,
		"startup_ms":world.startup_ms,"samples":samples,"failures":failures,
		"streaming":world.passage_region.residency.snapshot(),"interaction_costs":player._grab.profile_records}, "\t"))
	file.close()
	print("RESPONSIVENESS samples=", samples.size(), " failures=", failures)
	if OS.get_environment("ORISON_LAMP_GLARE")=="1" or FileAccess.file_exists(directory.path_join("run_glare_controls.request")):
		await preload("res://tests/v2_lamp_glare_probe.gd").new().run(world,directory.path_join("glare_controls"))
	if OS.get_environment("ORISON_PERF_ATTRIBUTION") == "1":
		await _attribution(directory)

func _monitor_values() -> Dictionary:
	var result: Dictionary={}
	for name: String in extra_monitors:result[name]=Performance.get_monitor(extra_monitors[name])
	return result

func _attribution(directory: String) -> void:
	# Stationary in-run controls separate world ticking from rendering costs.
	# Disabled ticking is diagnostic only and is always restored before teardown.
	var results := {}
	var shadow: Node3D=world.get_node("LampAtmosphere").scene_shadow
	for treatment in ["live", "world_ticks_disabled", "frozen_without_lamp_shadow_view", "world_ticks_restored_control", "live_restored"]:
		world.process_mode = Node.PROCESS_MODE_INHERIT if treatment in ["live","live_restored"] else Node.PROCESS_MODE_DISABLED
		shadow.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if treatment=="frozen_without_lamp_shadow_view" else SubViewport.UPDATE_ALWAYS
		for i in 30: await get_tree().process_frame
		var rows: Array = []
		for i in 120:
			var start := Time.get_ticks_usec()
			await get_tree().process_frame
			rows.append([(Time.get_ticks_usec()-start)/1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
				RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())])
		results[treatment]=rows
	FileAccess.open(directory.path_join("attribution.json"),FileAccess.WRITE).store_string(JSON.stringify({"kind":"diagnostic","columns":["wall_ms","viewport_cpu_ms","viewport_gpu_ms"],"treatments":results},"\t"))
