extends "res://tests/orison_v2_vertical_route_test.gd"
## Diagnostic only: real world/controller, raw frame samples, no ledger promotion.
var phase := "startup"
var samples: Array = []
var sampling := false
var last_usec := 0
var extra_monitors: Dictionary = {}

func _init() -> void:
	route_label = "V2 RESPONSIVENESS DIAGNOSTIC"

func _ready() -> void:
	GameBoot.settings.weather_network_enabled=false
	CampaignTime.set_frozen_for_tests(true)
	super._ready()

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
	var stationary_only := OS.get_environment("ORISON_PERF_STATIONARY") == "1"
	for cycle in (0 if stationary_only else 2):
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
		"scope":"Two nearby lobby/entrance/streaming cycles, then stationary attribution if requested; no whole-world or cold-start performance acceptance.",
		"columns":["phase","wall_ms","process_ms","physics_ms","render_cpu_ms","render_gpu_ms","draw_calls","primitives","residency","engine_monitors"],
		"resolution":str(get_viewport().get_visible_rect().size), "vsync":false,
		"settings":{"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),
			"adapter":RenderingServer.get_video_adapter_name(),"msaa_3d":get_viewport().msaa_3d,"taa":get_viewport().use_taa,
			"max_fps":Engine.max_fps,"physics_ticks_per_second":Engine.physics_ticks_per_second,
			"campaign_minute":world.campaign_clock.minute_of_day(),"calendar_frozen":true,"weather_network":false},
		"counter_limits":"Process/physics monitors are overlapping one-second peaks, not independent per-frame script/physics costs. Main viewport GPU excludes private viewports. Global rendering/compilation counters retain global scope; no additive attribution or matched speedup inferred.",
		"startup_ms":world.startup_ms,"samples":samples,"failures":failures,
		"streaming":world.passage_region.residency.snapshot(),"interaction_costs":player._grab.profile_records}, "\t"))
	file.close()
	print("RESPONSIVENESS samples=", samples.size(), " failures=", failures)
	if OS.get_environment("ORISON_LAMP_GLARE")=="1" or FileAccess.file_exists(directory.path_join("run_glare_controls.request")):
		await preload("res://tests/v2_lamp_glare_probe.gd").new().run(world,directory.path_join("glare_controls"))
	if OS.get_environment("ORISON_PERF_ATTRIBUTION") == "1":
		await _attribution(directory)
	if OS.get_environment("ORISON_PERF_CALLBACKS") == "1":
		await _callback_attribution(directory)

func _callback_attribution(directory: String) -> void:
	# Test-only subtraction controls. Never call callbacks manually or save the
	# diagnostically frozen state. Keep processing modes and renderer unchanged.
	var states: Array[Dictionary] = []
	var inventory := {}
	var selected := OS.get_environment("ORISON_PERF_SCRIPT")
	var nodes: Array[Node] = [world]
	nodes.append_array(world.find_children("*", "", true, false))
	for node: Node in nodes:
		var script := node.get_script() as Script
		var path := script.resource_path if script != null else "<native>"
		var process := node.is_processing()
		var physics := node.is_physics_processing()
		if not process and not physics: continue
		if not inventory.has(path): inventory[path] = {"process":0,"physics":0}
		inventory[path].process += int(process)
		inventory[path].physics += int(physics)
		if selected.is_empty() or path == selected:
			states.append({"node":node,"process":process,"physics":physics})
	if states.is_empty(): failures.append("callback selection matched no active nodes: " + selected)
	var results := {}
	for treatment: String in ["live_before", "process_disabled", "live_between", "physics_disabled", "live_after"]:
		for state: Dictionary in states:
			var node: Node = state.node
			if not is_instance_valid(node): continue
			node.set_process(state.process and treatment != "process_disabled")
			node.set_physics_process(state.physics and treatment != "physics_disabled")
		for i in 30: await get_tree().process_frame
		var rows: Array = []
		for i in 120:
			var start := Time.get_ticks_usec()
			await get_tree().process_frame
			rows.append([(Time.get_ticks_usec()-start)/1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
				RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		results[treatment] = {"samples":rows,"player_position":str(player.global_position)}
	var restored := true
	for state: Dictionary in states:
		var node: Node = state.node
		if not is_instance_valid(node): continue
		node.set_process(state.process)
		node.set_physics_process(state.physics)
		restored = restored and node.is_processing() == state.process and node.is_physics_processing() == state.physics
	if not restored: failures.append("callback flags failed restoration")
	FileAccess.open(directory.path_join("callbacks.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","kind":"performance_diagnostic","selected_script":selected,
		"scope":"Stationary subtraction controls; callbacks are disabled individually, not invoked manually. Physics server, rendering and autoloads remain live. Frozen behavior can affect presentation; differences are not additive script timings or production speedups.",
		"columns":["wall_ms","viewport_cpu_ms","viewport_gpu_ms","draw_calls","primitives"],
		"active_script_inventory":inventory,"selected_nodes":states.size(),"flags_restored":restored,"treatments":results},"\t"))

func _monitor_values() -> Dictionary:
	var result: Dictionary={}
	for name: String in extra_monitors:result[name]=Performance.get_monitor(extra_monitors[name])
	return result

func _attribution(directory: String) -> void:
	# Stationary in-run controls separate world ticking from rendering costs.
	# Disabled ticking is diagnostic only and is always restored before teardown.
	var results := {}
	var shadow: Node3D=world.get_node("LampAtmosphere").scene_shadow
	var original_process_mode:=world.process_mode
	var original_shadow_mode: int=shadow.viewport.render_target_update_mode
	for treatment in ["live", "world_ticks_disabled", "frozen_without_lamp_shadow_view", "world_ticks_restored_control", "live_restored"]:
		world.process_mode = original_process_mode if treatment in ["live","live_restored"] else Node.PROCESS_MODE_DISABLED
		shadow.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if treatment=="frozen_without_lamp_shadow_view" else original_shadow_mode
		for i in 30: await get_tree().process_frame
		var rows: Array = []
		for i in 120:
			var start := Time.get_ticks_usec()
			await get_tree().process_frame
			rows.append([(Time.get_ticks_usec()-start)/1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
				RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())])
		results[treatment]=rows
	world.process_mode=original_process_mode
	shadow.viewport.render_target_update_mode=original_shadow_mode
	FileAccess.open(directory.path_join("attribution.json"),FileAccess.WRITE).store_string(JSON.stringify({"kind":"diagnostic",
		"scope":"Same-process stationary controls; no readback during samples. Freezing world scripts/physics does not isolate their individual costs or stop all rendering-server work. The fourth block restores the original shadow mode while world ticking remains disabled; the final block restores live ticking.",
		"initial_process_mode":original_process_mode,"initial_shadow_mode":original_shadow_mode,
		"columns":["wall_ms","viewport_cpu_ms","viewport_gpu_ms"],"treatments":results},"\t"))
