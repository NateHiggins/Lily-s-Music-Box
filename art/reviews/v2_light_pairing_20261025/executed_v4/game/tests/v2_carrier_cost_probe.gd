extends Node
## INERT paired occupied-world cost diagnostic. No ledger/runtime promotion.
@export var companion := false
var world: OrisonV2RuntimeRoot
var player: PlayerController
var carrier: ServiceSetCarrier
var samples: Array[Dictionary] = []
var draws: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var events: Array[Dictionary] = []
var phase := "prepare"
var directory := ""
var finished := false
var _sampling := false
var _last_usec := 0
var _last_phase := ""
var _last_frame := -1
var _pre_draw_usec := 0
var _pre_draw_frame := 0
var _construct_start := 0
var _construct_end := 0
var _source_before := ""
var _old_fps := 0
var _old_settings: Dictionary

func check(ok: bool, label: String) -> void:
	checks.append({"name":label, "passed":ok})
	if not ok: failures.append(label); push_error(label)

func _ready() -> void:
	process_priority = 200
	set_process(false)
	get_tree().create_timer(540.0).timeout.connect(func():
		if not finished: check(false, "cost probe exceeded its deadline"); finish())
	_run.call_deferred()

func digest() -> String:
	var output: Array = []
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python", [root.path_join("tools/run_receipt.py"), "digest", "--root", root], output) != 0: return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	_source_before = digest()
	_old_fps = Engine.max_fps
	_old_settings = GameBoot.settings.duplicate(true)
	RealityState.persistence_enabled = false; RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	GameBoot.settings["look_sensitivity"] = 1.0
	GameBoot.settings["weather_network_enabled"] = false
	OS.set_environment("ORISON_COMPANION_WORLD", "1" if companion else "0")
	OS.set_environment("CAMPAIGN_TIME_FREEZE", "1")
	var clock := CampaignClock.new()
	check(clock.bind_state() and clock.configure_date(1928,11,10,1200), "same frozen campaign clock before constructing either world")
	seed(1928)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	RenderingServer.frame_post_draw.connect(_post_draw)
	phase = "construction"
	_sampling = true; set_process(true)
	_construct_start = Time.get_ticks_usec()
	world = load("res://scenes/building/orison_v2_runtime.tscn").instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0: await get_tree().process_frame
	_construct_end = Time.get_ticks_usec()
	if world.startup_failed:
		check(false, "production world composes: " + world.startup_failure_reason); finish(); return
	player = world.player; carrier = world.service_set_carrier
	player.profile_physics = true; player._grab.profiling = true
	world.household_state.profiling = true
	carrier.profile_callbacks = true
	if companion:
		carrier.get("motion").profile_callbacks = true
		carrier.get("rig").profile_callbacks = true
	else: RenderingServer.viewport_set_measure_render_time(carrier._pass_view.get_viewport_rid(), true)
	player.camera.make_current(); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	check(companion == carrier.has_method("world_lamp_transform"), "requested production carrier is installed")
	await ticks(180, "initial_settle")
	await ticks(120, "idle_live")
	for repeat in 2:
		var before := player.global_position
		phase = "walk_forward_" + str(repeat)
		key(KEY_W, true); await ticks(24, phase); key(KEY_W, false)
		key(KEY_S, true); await ticks(24, "walk_back_" + str(repeat)); key(KEY_S, false)
		phase = "turns_" + str(repeat)
		for index in 48:
			var event := InputEventMouseMotion.new(); event.relative = Vector2(3.0 if index<24 else -3.0,0)
			var started := Time.get_ticks_usec(); Input.parse_input_event(event)
			events.append({"kind":"look", "phase":phase, "physics_frame":Engine.get_physics_frames(), "dispatch_usec":Time.get_ticks_usec()-started})
			await get_tree().physics_frame
		await ticks(120, "route_settle_" + str(repeat))
		check(player.global_position.distance_to(before) < 1.5, "same short forward/back route retains the entrance area: " + str(repeat))
	carrier.set_capture_hidden(true)
	await ticks(120, "hidden_presentation")
	carrier.set_capture_hidden(false)
	await ticks(120, "presentation_restored")
	if companion: carrier.get("motion").set_physics_process(false)
	await ticks(120, "idle_motion_control")
	if companion: carrier.get("motion").set_physics_process(true)
	await tap(KEY_L)
	await ticks(120, "lamp_off")
	await tap(KEY_L)
	await ticks(240, "lamp_recovery")
	check(player.lamp_is_enabled(), "actual lamp circuit restored after control")
	await tap(KEY_E)
	await ticks(180, "reading_settle")
	check(carrier.reading and carrier.can_inspect_controls(), "same actual recall reaches supported controls")
	await tap(KEY_SPACE)
	check(player.inspecting() and player.inspect_owner == carrier, "actual Space enters the physical instrument inspection")
	var helper: Node
	if companion: helper = preload("res://tests/companion_world_hand_bench.gd").new()
	else: helper = preload("res://tests/service_set_hand_test.gd").new()
	helper.standalone = false; helper.player = player; helper.carrier = carrier; helper.directory = directory
	add_child(helper)
	phase = "target_acquisition"
	var part: Node3D = carrier._hand.controls.lamp
	if await helper.aim(part):
		phase = "grab_lamp"
		await click()
		check(player._grab.active() and player._grab.target.part == part, "real primary click grabs the specific lamp contact")
		var before: float = carrier._hand.read("lamp")
		for index in 4:
			await helper.drag(Vector2(0,4))
			await ticks(6, "drag_lamp")
		check(not is_equal_approx(before,carrier._hand.read("lamp")), "actual mouse produces physical partial travel")
		await click()
		check(not player._grab.active(), "next real click releases the part")
	else: check(false, "actual free cursor reaches the native lamp contact")
	await ticks(120, "inspection_idle")
	await tap(KEY_SPACE); await tap(KEY_E)
	check(not player.inspecting() and not carrier.reading, "actual input returns to walking")
	await ticks(120, "final_idle")
	# Diagnostic-only A-B-A quality control. Transition stalls remain in raw
	# records; warmed windows are separately named. Restore the exact setting.
	var original_msaa := get_viewport().msaa_3d
	check(original_msaa == Viewport.MSAA_8X, "baseline uses the repository's8x main MSAA")
	await ticks(180, "msaa8_before")
	await capture("msaa8_before")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	await ticks(180, "msaa4_transition")
	await ticks(180, "msaa4_warmed")
	await capture("msaa4_warmed")
	get_viewport().msaa_3d = original_msaa
	await ticks(180, "msaa8_transition")
	await ticks(180, "msaa8_return")
	await capture("msaa8_return")
	check(get_viewport().msaa_3d == original_msaa, "quality control restores the actual original MSAA")
	_sampling = false
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join("final_world.png")) == OK, "actual-world final capture outside timed intervals")
	check(not _source_before.is_empty() and digest() == _source_before, "runtime inputs unchanged through both controls and route")
	finish()

func ticks(count: int, label: String) -> void:
	phase = label
	# Never reset the sampling clock at a physics tick or phase transition.
	for index in count: await get_tree().physics_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code,true); await RenderingServer.frame_post_draw
	key(code,false); await RenderingServer.frame_post_draw

func click() -> void:
	for pressed in [true,false]:
		var before: bool = player._grab.active()
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
		event.position=get_viewport().get_mouse_position()
		var started := Time.get_ticks_usec()
		Input.parse_input_event(event)
		var dispatched := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		var focus := get_viewport().gui_get_focus_owner()
		events.append({"kind":"primary", "pressed":pressed, "phase":phase,
			"dispatch_usec":dispatched-started, "to_frame_post_draw_usec":Time.get_ticks_usec()-started,
			"held_before":before,"held_after":player._grab.active(),"inspecting":player.inspecting(),"call_locked":player.call_locked,
			"mouse_mode":Input.mouse_mode,"focus":str(focus.name) if focus!=null else ""})

func capture(label: String) -> void:
	_sampling=false; _last_usec=0
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))==OK, "captured diagnostic " + label)
	await RenderingServer.frame_post_draw
	_sampling=true

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame := Engine.get_process_frames()
	if not _sampling: _last_usec = 0; return
	var main := get_viewport().get_viewport_rid()
	var observer_start := Time.get_ticks_usec()
	var main_cpu := RenderingServer.viewport_get_measured_render_time_cpu(main)
	var main_gpu := RenderingServer.viewport_get_measured_render_time_gpu(main)
	var held_cpu: Variant = null; var held_gpu: Variant = null
	if is_instance_valid(carrier) and carrier._pass_view != null:
		var held := carrier._pass_view.get_viewport_rid()
		held_cpu = RenderingServer.viewport_get_measured_render_time_cpu(held)
		held_gpu = RenderingServer.viewport_get_measured_render_time_gpu(held)
	var observer_end := Time.get_ticks_usec()
	var row := {"phase":phase, "previous_phase":_last_phase, "process_frame":frame, "physics_frame":Engine.get_physics_frames(),
		"start_usec":now, "wall_ms":(now-_last_usec)/1000.0 if _last_usec else null,
		"full_interval":_last_usec!=0 and frame==_last_frame+1 and phase==_last_phase,
		"observer_query_usec":observer_end-observer_start,
		"main_cpu_ms":main_cpu, "main_gpu_ms":main_gpu, "held_cpu_ms":held_cpu, "held_gpu_ms":held_gpu,
		"process_monitor_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
		"physics_monitor_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
		"msaa":get_viewport().msaa_3d, "resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"pipeline_draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW), "pipeline_surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
		"pipeline_specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}
	if is_instance_valid(player): row.player = [player.global_position.x, player.global_position.y, player.global_position.z]
	if is_instance_valid(world) and is_instance_valid(world.passage_region) and is_instance_valid(world.passage_region.residency):
		var residency: Node = world.passage_region.residency
		row.streaming_state = residency.state; row.load_cycles = residency.load_cycles; row.unload_cycles = residency.unload_cycles
	if is_instance_valid(world) and world.has_node("V2RoomReflections"):
		var reflections := world.get_node("V2RoomReflections")
		row.reflection_refreshes = reflections.refresh_count; row.reflection_probes = reflections.probes.size()
	samples.append(row)
	_last_usec=now; _last_phase=phase; _last_frame=frame

func _pre_draw() -> void:
	if not _sampling: return
	_pre_draw_usec = Time.get_ticks_usec(); _pre_draw_frame = Engine.get_process_frames()

func _post_draw() -> void:
	if not _sampling or _pre_draw_usec == 0: return
	draws.append({"process_frame":_pre_draw_frame,"pre_usec":_pre_draw_usec,"post_usec":Time.get_ticks_usec(),"phase":phase})
	_pre_draw_usec = 0

func finish() -> void:
	if finished: return
	finished = true; _sampling=false; set_process(false)
	key(KEY_W,false); key(KEY_S,false)
	var evidence := {"evidence_class":"INERT", "scope":"Paired actual production-world carrier cost probe, short entrance route and physical lamp contact. Not full V2 coverage, human input/display latency, or runtime qualification.",
		"companion":companion, "settings":{"viewport":str(get_viewport().size),"fov":player.camera.fov if is_instance_valid(player) else null,"physics_hz":Engine.physics_ticks_per_second,"vsync_requested":"off","vsync_readback":DisplayServer.window_get_vsync_mode(),"fps_limit_requested":0,"fps_limit_readback":Engine.max_fps,"campaign_clock":"1928-11-10T20:00 frozen before composition","random_seed":1928,"driver_cache":"existing; not cleared or controlled"},
		"checks":checks,"failures":failures,"samples":samples,"draws":draws,"events":events,"source_before":_source_before,"main_msaa_baseline":3,"msaa_control":"8x/4x/8x diagnostic; configuration transition intervals retained; not a shipping setting",
		"world_construct_start_usec":_construct_start,"world_construct_end_usec":_construct_end,
		"limitations":"Render/process/physics monitors lag and overlap. Pipeline/resource counts correlate, not isolated shader or GPU upload timing. Callback probes add observer overhead; no averages summed. Same short route does not cover cells or all furnishings."}
	if is_instance_valid(carrier):
		evidence.carrier_callbacks=carrier.callback_records; evidence.carrier_setup=carrier.setup_records
		if companion:
			evidence.motion_callbacks=carrier.get("motion").callback_records
			evidence.mechanism_callbacks=carrier.get("rig").callback_records
	if is_instance_valid(player): evidence.player_physics=player.physics_profile_records; evidence.grab_callbacks=player._grab.profile_records
	if is_instance_valid(world):
		if is_instance_valid(world.household_state): evidence.household_callbacks=world.household_state.profile_records
		if is_instance_valid(world.passage_region) and is_instance_valid(world.passage_region.residency):
			var residency: Node = world.passage_region.residency
			evidence.streaming_stages=residency.stage_records; evidence.streaming_fittings=residency.fit_records
	if not directory.is_empty():
		FileAccess.open(directory.path_join("carrier_cost.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"\t"))
	print("CARRIER COST: ","companion" if companion else "original"," checks=",checks.size()," failures=",failures.size()," samples=",samples.size())
	Engine.max_fps=_old_fps; GameBoot.settings=_old_settings
	if is_instance_valid(world):
		world.process_mode=Node.PROCESS_MODE_DISABLED
		world.shutdown_for_tests(); world.queue_free()
		await get_tree().process_frame; await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
