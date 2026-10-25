extends "res://tests/companion_session_world_test.gd"
## INERT diagnostic: actual occupied-world native input, not acceptance.
var phase := "setup"
var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var draws: Array[Dictionary] = []
var last_tick := 0
var last_phase := ""
var sampling := false
var pre_tick := 0
var start_digest := ""

func _ready() -> void:
	process_priority = 200
	_run.call_deferred()
	get_tree().create_timer(650).timeout.connect(func():
		if not finished: check(false, "profiling deadline"); finish())

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	start_digest = digest()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.save_path = directory.path_join("probe_campaign.json")
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	GameBoot.settings["weather_network_enabled"] = false
	GameBoot.settings["look_sensitivity"] = 1.0
	OS.set_environment("ORISON_COMPANION_WORLD", "")
	OS.set_environment("CAMPAIGN_TIME_FREEZE", "1")
	var clock := CampaignClock.new()
	check(clock.bind_state() and clock.configure_date(1928,11,10,1200), "fixed campaign date")
	seed(1928)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	RenderingServer.frame_pre_draw.connect(func():
		if sampling: pre_tick = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func():
		if sampling and pre_tick:
			draws.append({"phase":phase,"frame":Engine.get_process_frames(),"begin_usec":pre_tick,"end_usec":Time.get_ticks_usec()})
			pre_tick = 0)
	if not await build_world(): finish(); return
	player.profile_physics = true
	player._grab.profiling = true
	world.household_state.profiling = true
	RealityState.background_save_profiling = true
	# Avoid unsolicited printing altering the repeated authored question route.
	carrier.session.chatter_enabled = false
	await frames(180)
	# Prime a real validated disk file outside measurement, never the player save.
	RealityState.persistence_enabled = true
	check(RealityState.save_game(), "private occupied campaign saved before route")
	RealityState.persistence_enabled = false
	sampling = true
	phase = "movement"
	await held_key(KEY_W, 24)
	await held_key(KEY_S, 24)
	for i in 48:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(3 if i < 24 else -3, 0)
		Input.parse_input_event(motion)
		await get_tree().physics_frame
	await key(KEY_E)
	check(await wait_for(func(): return carrier.motion.steady_for_input() and not carrier.device.teletype.printing), "actual recall ready")
	# ABBA persistence control; all phases exercise identical native keys and
	# printer. Cache order remains explicit; this is not randomized hardware QA.
	for block in 4:
		var persistent := block == 0 or block == 3
		RealityState.persistence_enabled = persistent
		for question: String in ["who are you", "help", "look"]:
			phase = "%d_%s_%s" % [block, "disk" if persistent else "no_disk", question]
			await frames(30)
			await key(KEY_ENTER)
			if not check(await wait_for(func(): return carrier.session.typing), "native typing ready " + phase): finish(); return
			await type_text(question)
			var before: int = carrier.session.dialogue.memory.history.size()
			await key(KEY_ENTER)
			check(not carrier.session.typing and carrier.session.dialogue.memory.history.size() == before + 1, "actual accepted exchange " + phase)
			if not check(await wait_for(func(): return not carrier.device.teletype.printing, 30), "physical printing completes " + phase): finish(); return
			await frames(45)
	RealityState.persistence_enabled = true
	phase = "settlement"
	var memory: Dictionary = carrier.session.dialogue.memory.snapshot()
	var started := Time.get_ticks_usec()
	check(RealityState.save_game(), "explicit save settlement succeeds")
	events.append({"kind":"save_barrier","phase":phase,"elapsed_usec":Time.get_ticks_usec()-started})
	RealityState.load_game()
	check(Campaign.valid(RealityState.data.get("companion")), "saved companion domain validates")
	check(domain_value(RealityState.data.companion.memory) == domain_value(memory), "last exchange survives actual disk reload")
	finish()

func held_key(code: Key, count: int) -> void:
	var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event)
	for i in count: await get_tree().physics_frame
	event = InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event)

func key(code: Key, unicode := 0, observe_character := "") -> bool:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.unicode = unicode if pressed else 0; event.pressed = pressed
		var began := Time.get_ticks_usec()
		Input.parse_input_event(event)
		var dispatched := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		events.append({"kind":"key","code":code,"pressed":pressed,"phase":phase,"begin_usec":began,"dispatch_usec":dispatched-began,"to_post_draw_usec":Time.get_ticks_usec()-began,"frame":Engine.get_process_frames()})
		await frames(1)
	return false

func _process(_delta: float) -> void:
	if not sampling: last_tick = 0; return
	var now := Time.get_ticks_usec()
	var rid := get_viewport().get_viewport_rid()
	samples.append({"phase":phase,"frame":Engine.get_process_frames(),"tick_usec":now,"wall_ms":float(now-last_tick)/1000 if last_tick else null,"same_phase":last_phase==phase,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"pipeline_draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"pipeline_surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),"pipeline_specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)})
	last_tick = now; last_phase = phase

func finish() -> void:
	if finished: return
	finished = true; sampling = false
	RealityState.flush_background_saves()
	RealityState.persistence_enabled = false
	check(start_digest == digest(), "source frozen during diagnostic")
	var failures := checks.filter(func(row: Dictionary): return not row.passed)
	var result := {"evidence_class":"INERT","scope":"Occupied entrance movement and twelve actual native typed exchanges with ABBA persistence control; not broad V2 qualification or hardware input latency.","checks":checks,"samples":samples,"events":events,"draws":draws,"source":start_digest,"settings":{"viewport":str(get_viewport().size),"msaa":get_viewport().msaa_3d,"vsync":DisplayServer.window_get_vsync_mode(),"fps_limit":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,"driver_cache":"existing uncontrolled"},"background_saves":RealityState.background_save_records,"limits":"Render timers/monitors lag and overlap. Same-process ABBA warms caches and changes bounded conversation history; no separate GPU completion, shader compile or driver isolation. Private save; no resident authority mutation attempted."}
	if is_instance_valid(player): result.player_physics = player.physics_profile_records
	if is_instance_valid(world): result.household = world.household_state.profile_records
	FileAccess.open(directory.path_join("correspondence_cost.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CORRESPONDENCE COST checks=",checks.size()," failures=",failures.size()," samples=",samples.size())
	if is_instance_valid(world):
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.shutdown_for_tests(); world.queue_free()
		await frames(3)
	get_tree().quit(0 if failures.is_empty() else 1)
