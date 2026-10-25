extends Node
## Occupied production V2, native optical source and actual light/control input.
## Diagnostic only: no whole-world, save or performance qualification.
var world: OrisonV2RuntimeRoot
var player: PlayerController
var carrier: ServiceSetCarrier
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var directory := ""
var phase := ""
var previous := 0
var finished := false
var old_network: Variant
var source_before := ""
var old_cap := 0

func check(ok: bool, text: String) -> void:
	checks.append({"name":text, "passed":ok})
	if not ok: failures.append(text); push_error(text)

func _ready() -> void:
	process_priority = 200 # Observe after the player has published this rendered frame.
	set_process(false)
	get_tree().create_timer(540.0).timeout.connect(func():
		if not finished: check(false, "occupied companion light diagnostic deadline"); _finish())
	_run.call_deferred()

func digest() -> String:
	var result: Array = []
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], result) != 0: return ""
	return str(result[0]).strip_edges() if not result.is_empty() else ""

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	source_before = digest()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	old_network = GameBoot.settings.get("weather_network_enabled")
	GameBoot.settings["weather_network_enabled"] = false
	OS.set_environment("ORISON_COMPANION_WORLD", "1")
	OS.set_environment("CAMPAIGN_TIME_FREEZE", "1")
	world = load("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	if not _require(not world.startup_failed, "production V2 starts with the native autonomous companion"): return
	player = world.player; carrier = world.service_set_carrier
	check(bool(carrier.get("world_ready")), "production root binds candidate carrier")
	check(world.campaign_clock.configure_date(1928, 11, 10, 1200), "diagnostic clock fixed to authored November10 1928 at20:00")
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	old_cap = Engine.max_fps; Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	await _frames(90, "settle")
	var original_light := player.flashlight.get_instance_id()
	await _frames(120, "idle_lit")
	await _capture("native_source_lit")
	_key(KEY_W, true)
	await _frames(24, "walk_forward")
	_key(KEY_W, false); _key(KEY_S, true)
	await _frames(24, "walk_back")
	_key(KEY_S, false)
	for index in 48:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(3.0 if index < 24 else -3.0, 0)
		Input.parse_input_event(motion)
		await _frames(1, "actual_turns")
	await _frames(60, "turn_settle")
	var expected_target: Vector3 = carrier.get("motion").light_target
	var to_work := (expected_target - player.flashlight.global_position).normalized()
	var physical_forward := -player.flashlight.global_basis.z.normalized()
	check(to_work.dot(physical_forward) > cos(deg_to_rad(2.0)), "native aperture converges on the authoritative viewed point after actual mouse input")
	var was_on := player.lamp_is_enabled()
	await _tap(KEY_L)
	check(player.lamp_is_enabled() != was_on and carrier.lamp_is_enabled() == player.lamp_is_enabled(), "actual L reaches existing player/device lamp power owners")
	await _frames(60, "lamp_off")
	await _capture("native_source_off")
	await _tap(KEY_R)
	check(not carrier.radio_is_powered(), "actual R opens the independent radio contact")
	await _tap(KEY_L)
	check(player.lamp_is_enabled() and carrier.lamp_is_enabled() and not carrier.radio_is_powered(), "native lamp works while the original radio/printer is off")
	await _frames(90, "lamp_on_radio_off")
	check(player.flashlight.get_instance_id() == original_light, "original real flashlight survives every transition")
	check(player.flashlight.light_projector == null, "retired photographic projector stays absent")
	check(player.flashlight.shadow_enabled, "original physical shadow protection remains")
	check(carrier._pass_view == null, "world companion does not render a second private pass")
	# Restore the actual radio for the inherited hand programme, using real R.
	await _tap(KEY_R)
	var helper := preload("res://tests/companion_world_hand_bench.gd").new()
	helper.standalone = false; helper.player = player; helper.carrier = carrier; helper.directory = directory
	add_child(helper)
	set_process(false)
	await helper.exercise()
	for failure: String in helper.failures: check(false, "occupied hand: " + failure)
	check(helper.checks >= 70 and helper.failures.is_empty(), "occupied six-control grab/motion/release and interruption programme")
	var escaped := false
	for record: Dictionary in helper.input_checks:
		if record.name == "Escape releases grabbed control and restores world" and record.passed: escaped = true
	check(escaped, "Escape is actually executed with a grabbed world control")
	checks.append({"name":"occupied hand programme detail", "passed":helper.failures.is_empty(), "checks":helper.input_checks, "observations":helper.observations})
	await _capture("occupied_controls")
	check(not source_before.is_empty() and source_before == digest(), "runtime sources unchanged through occupied light/input run")
	_finish()

func _require(ok: bool, text: String) -> bool:
	check(ok, text)
	if not ok: _finish()
	return ok

func _frames(count: int, label: String) -> void:
	phase = label
	previous = Time.get_ticks_usec()
	set_process(true)
	for index in count: await get_tree().physics_frame
	set_process(false)

func _process(_delta: float) -> void:
	if not is_instance_valid(carrier) or not bool(carrier.get("world_ready")): return
	var now := Time.get_ticks_usec()
	var actual := player.flashlight.global_transform
	var native: Transform3D = carrier.world_lamp_transform()
	var gap := actual.origin.distance_to(native.origin)
	var angle := acos(clampf(actual.basis.z.normalized().dot(native.basis.z.normalized()), -1.0, 1.0))
	var direction_error := actual.basis.z.normalized().distance_to(native.basis.z.normalized())
	if gap > .00001 or direction_error > .00001: check(false, "real source separates from native lamp: " + str([gap, angle]))
	var view := get_viewport().get_viewport_rid()
	samples.append({"phase":phase, "wall_ms":(now-previous)/1000.0, "source_gap_m":gap, "source_angle_rad":angle, "source_direction_error":direction_error,
		"beam_forward":str(-actual.basis.z), "camera_forward":str(-player.camera.global_basis.z),
		"light_target":str(carrier.get("motion").light_target), "behavior":str(carrier.get("motion").behavior),
		"player":str(player.global_position), "companion":str(carrier.get("motion").global_position), "source":str(actual.origin),
		"lamp_on":player.lamp_is_enabled(), "radio_on":carrier.radio_is_powered(),
		"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
		"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
		"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(view), "render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(view),
		"pipelines_surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE), "pipelines_specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)})
	previous = now

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)

func _tap(code: Key) -> void:
	_key(code, true)
	await RenderingServer.frame_post_draw
	_key(code, false)
	await RenderingServer.frame_post_draw

func _capture(label: String) -> void:
	set_process(false)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "captured " + label)

func _finish() -> void:
	if finished: return
	finished = true
	set_process(false)
	_key(KEY_W, false); _key(KEY_S, false)
	Engine.max_fps = old_cap
	if old_network != null: GameBoot.settings["weather_network_enabled"] = old_network
	if directory.is_empty(): directory = OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("flashlight_diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Actual occupied production V2 candidate; native light source tracking, power/radio independence and six native hand controls. Not full navigation, saves, mirrors, performance comparison or human acceptance.", "checks":checks, "failures":failures, "samples":samples, "source_before":source_before, "settings":{"physics_hz":Engine.physics_ticks_per_second, "viewport":str(get_viewport().size), "vsync":"off", "fps_cap":0, "clock":"1928-11-10T20:00 frozen"}}, "\t"))
	print("COMPANION WORLD LIGHT: ", checks.size(), " checks; ", failures.size(), " failures; ", samples.size(), " samples")
	if is_instance_valid(world):
		# Retire simulation and render-light pairs before dismantling geometry.
		# Captures and all sampled source/power checks have already finished.
		world.process_mode = Node.PROCESS_MODE_DISABLED
		for light: Light3D in world.find_children("*", "Light3D", true, false): light.visible = false
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		world.shutdown_for_tests()
		world.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
