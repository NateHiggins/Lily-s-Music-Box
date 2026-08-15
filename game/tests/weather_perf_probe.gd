extends Node
## Focused T8 cost probe. Unlike the historical aerial street station, the
## production player stands at the lens so near rain, middle rain, mist and
## the sky all contribute to the timed frame.

## Performance.TIME_FPS is a rolling monitor. Thirty frames let shader/startup
## work remain in that window and overstated the settled playable street by
## 5-7 ms versus a direct frame clock. Give both clocks two seconds to settle
## and report them together so neither can silently substitute for the other.
const WARMUP := 120
const SAMPLES := 120
const EYE := Vector3(-16.0, 1.68, 13.5)
const LOOK := Vector3(26.0, 1.30, 19.6)


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.set_environment("DAYNIGHT", "0")
	if OS.get_environment("WEATHER_SEED") == "":
		OS.set_environment("WEATHER_SEED", "19280731")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	root.light_rig.set_budgets(16, 16)
	for child in root.get_children():
		if child is CanvasLayer:
			child.visible = false
	await get_tree().create_timer(1.0).timeout
	var camera := Camera3D.new()
	camera.fov = 72.0
	add_child(camera)
	camera.global_position = EYE
	camera.look_at(LOOK)
	camera.make_current()
	root.player.global_position = EYE - Vector3(0.0,
			PlayerController.STANDING_EYE, 0.0)
	# This is a production-player benchmark: BuildingRoot must stream from the
	# controller's feet, as it does in play. A detached-camera override streams
	# from eye height and accidentally admits F02 through the floor overlap band.
	root.view_override = null
	root.player.set_physics_process(false)
	for i in WARMUP:
		await get_tree().process_frame
	var monitor_total := 0.0
	var direct_total := 0.0
	for i in SAMPLES:
		var started := Time.get_ticks_usec()
		await get_tree().process_frame
		direct_total += (Time.get_ticks_usec() - started) / 1000.0
		monitor_total += 1000.0 / maxf(1.0, Performance.get_monitor(
				Performance.TIME_FPS))
	var monitor_average := monitor_total / SAMPLES
	var direct_average := direct_total / SAMPLES
	var objects := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var calls := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var state: Dictionary = root.weather.diagnostic_snapshot()
	print("[WEATHER PERF] rain=%s mist=%s exposed=%s objects=%d calls=%d "
			% [state.rain_enabled, state.mist_enabled, state.exposed,
			objects, calls] + "primitives=%d direct_ms=%.3f monitor_ms=%.3f" %
			[primitives, direct_average, monitor_average])
	get_tree().quit(0 if objects > 500 and state.exposed else 1)
