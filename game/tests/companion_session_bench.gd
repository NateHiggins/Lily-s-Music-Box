extends Node3D
## Actual native-input/save diagnostic. Occupied-world qualification is separate.
const Campaign = preload("res://scripts/device/companion_campaign_state.gd")
var player: PlayerController
var carrier: Node
var checks: Array[Dictionary] = []
var directory := ""
var finished := false
var saved_campaign := false
var accept_trace: Array[Dictionary] = []
var late_camera_stress := false

func _process(_delta: float) -> void:
	if late_camera_stress and is_instance_valid(player): player.camera.rotation.y += .02

func check(ok: bool, label: String) -> bool:
	checks.append({"name":label, "passed":ok})
	print("COMPANION SESSION: ", label, " = ", ok)
	if not ok and is_instance_valid(carrier) and carrier.session != null:
		var state := {"label":label, "ticks":Time.get_ticks_msec(), "available":carrier.session.available(),
			"reading":carrier.reading, "opening":carrier.session.opening, "typing":carrier.session.typing,
			"printing":carrier.device.teletype.printing, "powered":carrier.device.radio_powered, "incoming_call":carrier.device.incoming_call,
			"protected_input":player.protected_input_active(), "input_owner":str(player.text_input_owner), "mouse_mode":Input.mouse_mode,
			"mouse_released":player.mouse_released, "paused":get_tree().paused, "sleep":carrier._sleep_onset,
			"foreign_editor":carrier.session._foreign_editor_active(), "focus":str(get_viewport().gui_get_focus_owner()),
			"camera_current":player.camera.is_current(), "hidden":carrier.is_capture_hidden(), "inspecting":player.inspecting(),
			"grab_active":player._grab.active(), "hud_conversation":player.telegram_hud != null and player.telegram_hud._conversation_active}
		FileAccess.open(directory.path_join("failure_state_%02d.json" % checks.size()), FileAccess.WRITE).store_string(JSON.stringify(state, "\t"))
	return ok

func _ready() -> void:
	_run.call_deferred()
	get_tree().create_timer(145.0).timeout.connect(func():
		if not finished: check(false, "diagnostic deadline"); finish())

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
	Engine.max_fps = 120
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(12, .2, 12)
	shape.shape = box; shape.position.y = -.1
	floor_body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = box.size
	visual.mesh = mesh; visual.position = shape.position
	floor_body.add_child(visual)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0); add_child(light)
	player = PlayerController.new(); add_child(player)
	player.set_physics_process(false)
	player.camera.make_current(); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	carrier = preload("res://scripts/device/companion_world_carrier.gd").new()
	await carrier.setup(player, player.camera, null)
	player.carried_device = carrier
	if not check(carrier.world_ready, "native companion and session initialize"): finish(); return
	await exercise()

func exercise() -> void:
	await exercise_screen_framing()
	await measure_foreground_cost()
	await joy(JOY_BUTTON_DPAD_DOWN)
	if not check(await wait_for(func(): return carrier.motion.steady_for_input() and not carrier.device.teletype.printing), "recall and existing paper finish before input"):
		finish(); return
	var reports: int = carrier.device.printed_count
	await joy(JOY_BUTTON_A)
	if not check(await wait_for(func(): return carrier.session.typing), "controller recall and accept deploy and settle physical keyboard"):
		finish(); return
	check(player.text_input_owner == carrier.session and player.call_locked and not player.protected_input_active(), "typing acquires a separate movement/input lease")
	await type_text("who are you")
	var space_was_down: bool = await key(KEY_SPACE, 32, "SPACE")
	check(space_was_down, "actual text space depresses native spacebar")
	var backspace_was_down: bool = await key(KEY_BACKSPACE, 0, "BACKSPACE")
	check(backspace_was_down and carrier.session.draft == "who are you", "actual Backspace depresses its key and edits the native draft")
	check(carrier.device.radio_powered, "typed R remains text rather than toggling radio")
	check(carrier.session.draft == "who are you", "native key input reaches preserved draft")
	check(carrier.rig.typing_ready() and carrier.device.teletype._draft_ink.text.contains("who are you"), "native keyboard and physical paper present typed text")
	check(carrier.device.printed_count == reports, "draft editing does not mint received reports")
	await capture("typing.png")
	var paper := carrier.device.teletype._paper as MeshInstance3D
	var tray := carrier.rig.model.find_child("CompanionKeyboard__CompanionSteel", true, false) as MeshInstance3D
	var paper_rect := projected_bounds(paper)
	var keyboard_rect := projected_bounds(tray)
	FileAccess.open(directory.path_join("framing.json"), FileAccess.WRITE).store_string(JSON.stringify({"paper":str(paper_rect), "keyboard":str(keyboard_rect), "paper_height_fraction":paper_rect.size.y/get_viewport().get_visible_rect().size.y, "keyboard_to_paper_width":keyboard_rect.size.x/paper_rect.size.x, "reading_distance":carrier.reading_distance, "fov":player.camera.fov}, "\t"))
	check(keyboard_rect.size.x < paper_rect.size.x * 2.0, "retracted keyboard no longer dominates the reading surface in perspective")
	check(get_viewport().get_visible_rect().encloses(paper_rect) and get_viewport().get_visible_rect().encloses(keyboard_rect), "physical reading surface and keyboard fit within viewport")
	var foreign := LineEdit.new(); add_child(foreign)
	foreign.grab_focus()
	await frames(3)
	check(not carrier.session.typing and carrier.session.draft == "who are you", "foreign native editor suspends typing without discarding draft")
	check(foreign.has_focus() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "suspension preserves another editor's focus and pointer")
	foreign.release_focus(); foreign.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "explicit input resumes after foreign editor leaves"):
		finish(); return
	player.call_locked = true
	await frames(3)
	check(not carrier.session.typing and carrier.session.draft == "who are you", "protected conversation interrupts without losing draft")
	check(player.call_locked and player.protected_input_active() and player.text_input_owner == null, "interruption releases only companion lease")
	await key(KEY_ENTER)
	check(not carrier.session.opening and not carrier.session.typing, "protected owner refuses new typing")
	player.call_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "explicit input resumes after protected owner leaves"):
		finish(); return
	check(carrier.session._edit.text == "who are you", "resumed native editor retains exact draft")
	var enter_was_down: bool = await joy(JOY_BUTTON_A, "ENTER")
	check(enter_was_down, "actual submission depresses native Enter key")
	check(not player._grab.active(), "editor-owned controller submission does not grab the world target behind the console")
	check(carrier.session.draft.is_empty() and not player.call_locked, "submission clears accepted draft and returns player input")
	check(carrier.session.dialogue.memory.history.back().intent == "identity", "physical submission reaches offline conversation")
	check(carrier.device.printed_count == reports + 1 and carrier.device.teletype.printing, "accepted reply uses original animated printer")
	if not check(await wait_for(func(): return not carrier.device.teletype.printing), "reply physically finishes printing"):
		finish(); return
	await get_tree().create_timer(.5).timeout
	var ink: Label3D = carrier.device.teletype.ink
	var ink_rect := projected_aabb(ink, ink.get_aabb())
	var glass_rect := projected_bounds(carrier.rig.glazing)
	FileAccess.open(directory.path_join("reply_layout.json"), FileAccess.WRITE).store_string(JSON.stringify({"ink":str(ink_rect), "glass":str(glass_rect), "ink_local":str(ink.position), "text":ink.text}, "\t"))
	check(glass_rect.grow(2.0).encloses(ink_rect), "delivered physical copy fits within the reading glass after feed settles")
	check(carrier.rig.keyboard_open > .99, "reply reading keeps the keyboard beneath the copy rather than folding its face across it")
	await capture("reply.png")
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "next exchange deploys keyboard"):
		finish(); return
	await type_text("help")
	await joy(JOY_BUTTON_B)
	check(not carrier.session.typing and carrier.session.draft == "help" and player.text_input_owner == null, "controller cancel keeps draft and relinquishes only its lease")
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "controller-cancelled draft explicitly resumes"):
		finish(); return
	carrier.device.set_radio_powered(false)
	await frames(2)
	check(not carrier.session.typing and carrier.session.draft == "help" and not player.call_locked, "power interruption retains draft and relinquishes focus")
	await key(KEY_ENTER)
	check(not carrier.session.typing and not carrier.session.opening, "unpowered radio cannot accept correspondence")
	carrier.device.set_radio_powered(true)
	await key(KEY_ENTER)
	if not check(await wait_for(func(): return carrier.session.typing), "powered keyboard explicitly resumes"):
		finish(); return
	carrier.device.set_incoming_call(true)
	await frames(2)
	check(not carrier.session.typing and carrier.session.draft == "help", "real incoming-call print preempts editing")
	check(carrier.device.teletype.pages[0].contains("L. ORTIZ"), "protected incoming-call paper retains original facts")
	carrier.device.set_incoming_call(false)
	await wait_for(func(): return not carrier.device.teletype.printing)
	await key(KEY_ENTER)
	await wait_for(func(): return carrier.session.typing)
	get_tree().paused = true
	await frames(2)
	check(not carrier.session.typing and carrier.session.draft == "help" and player.text_input_owner == null, "pause suspends focus and preserves exact draft")
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var clock := CampaignClock.new(); clock.configure_date(1928, 11, 10, 1080)
	await publication_pass(clock)
	clock.configure_date(1928, 11, 10, 1080)
	await touch_pass()
	await additional_checks()
	var path := "user://tests/companion_session_bench.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	RealityState.save_path = path
	RealityState.persistence_enabled = true
	var before: Dictionary = carrier.session.dialogue.memory.snapshot()
	var expected_chatter: bool = carrier.session.chatter_enabled
	saved_campaign = RealityState.save_game()
	check(saved_campaign, "existing campaign storage saves companion domain")
	carrier.session.dialogue.respond("eat it", {})
	carrier.session.draft = "unsaved change"
	carrier.witness.last_read = {"paper":"record", "date":"1928-11-10"}
	carrier.session.queue_event("story_discovery")
	RealityState.load_game()
	FileAccess.open(directory.path_join("reload_comparison.json"), FileAccess.WRITE).store_string(JSON.stringify({"before":before, "after":carrier.session.dialogue.memory.snapshot(), "draft":carrier.session.draft}, "\t"))
	check(carrier.session.dialogue.memory.snapshot() == before and carrier.session.draft == "help", "validated disk reload restores correspondence and draft")
	check(carrier.session.chatter_enabled == expected_chatter, "reload preserves the most recent explicit quiet preference")
	check(carrier.witness.last_read.is_empty() and carrier.session._events.is_empty(), "reload retires stale paper witnesses and queued discoveries")
	var invalid := Campaign.fresh(); invalid.memory.extra = "x".repeat(10000)
	check(not Campaign.valid(invalid), "unbounded hidden memory fields are rejected")
	invalid = Campaign.fresh(); invalid.draft = "x".repeat(513)
	check(not Campaign.valid(invalid), "oversized drafts are rejected")
	var corrupt := RealityState.data.duplicate(true); corrupt.companion = invalid
	check(not RealityState._validate_document(corrupt).ok, "campaign validator refuses corrupt companion before adoption")
	var legacy := RealityState.data.duplicate(true); legacy.erase("companion")
	check(RealityState._validate_document(legacy).ok, "existing campaigns without companion domain remain compatible")
	check(RealityState.save_game(), "second validated generation prepares real recovery control")
	var malformed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	malformed.companion.draft = "x".repeat(513)
	var malformed_bytes := JSON.stringify(malformed, "\t")
	FileAccess.open(directory.path_join("malformed_companion.json"), FileAccess.WRITE).store_string(malformed_bytes)
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	damaged.store_string(malformed_bytes); damaged = null
	RealityState.load_game()
	check(RealityState.load_status().status == "recovered" and carrier.session.draft == "help", "real storage rejects malformed companion and recovers validated previous generation")
	check(Campaign.valid(RealityState.data.companion), "recovery never adopts corrupt correspondence fields")
	finish()

func publication_pass(clock: CampaignClock) -> void:
	var catalog := reading_catalog()
	clock.configure_date(1928, 11, 10, 359)
	carrier.witness.last_read.clear()
	var panel := NewspaperPanel.new(); add_child(panel)
	panel.open(player, catalog, "record", "1928-11-10")
	await frames(2)
	check(carrier.witness.last_read.is_empty(), "actual reading owner withholds unpublished morning edition")
	check(panel._page.get_child(0).text == "This edition has not been published.", "future edition is not drawn by reading panel")
	panel.close(); await frames(2)
	clock.configure_date(1928, 11, 10, 360)
	panel = NewspaperPanel.new(); add_child(panel)
	panel.open(player, catalog, "record", "1928-11-10")
	await frames(2)
	check(carrier.witness.last_read == {"paper":"record", "date":"1928-11-10"}, "actual published reading surface supplies exact witnessed edition")
	var calendar: Dictionary = carrier.witness.calendar()
	var context := preload("res://scripts/device/companion_calendar_context.gd").enrich({}, clock, str(calendar.source), calendar.conditions, calendar.catalog, calendar.read_issue)
	check(str(context.get("newspaper_report", "")).contains("Count of Tuesday"), "reading-owner context retains literal published lead")
	panel.close(); await frames(2)
	clock.configure_date(1928, 11, 12, 360)
	panel = NewspaperPanel.new(); add_child(panel)
	panel.open(player, catalog, "record", "1928-11-10")
	calendar = carrier.witness.calendar()
	context = preload("res://scripts/device/companion_calendar_context.gd").enrich({}, clock, str(calendar.source), calendar.conditions, calendar.catalog, calendar.read_issue)
	check(context.get("newspaper_comment_id") == "news_comment_old" and str(context.get("newspaper_report", "")).contains(catalog.long_date("1928-11-10")), "archive reading remains explicitly dated and historically framed")
	panel.close(); await frames(2)
	if catalog.get_parent() == self: catalog.queue_free()

func reading_catalog() -> NewspaperCatalog:
	var catalog := NewspaperCatalog.new(); add_child(catalog)
	return catalog

func additional_checks() -> void:
	pass

func physical_key_down(character: String) -> bool:
	var index: int = carrier.rig._key_names.find(character)
	return index >= 0 and carrier.rig.key_transform(index).origin.z > carrier.rig._key_homes[index].origin.z + .0001

func exercise_screen_framing() -> void:
	var frame: Node = carrier.screen_frame
	check(frame != null and carrier.motion.screen_framed, "production companion uses foreground flight framing")
	var old_priority := process_priority
	process_priority = 2000
	late_camera_stress = true
	var was_physics := player.is_physics_processing()
	player.set_physics_process(false)
	var saved_rotation := player.rotation
	var saved_camera_rotation := player.camera.rotation
	var saved_velocity := player.velocity
	var saved_fov := player.camera.fov
	var saved_fps := Engine.max_fps
	var all_inside := true; var rays_match := true; var center_clear := true
	var largest_error := 0.0
	for cap: int in [30, 60, 144]:
		Engine.max_fps = cap
		for pitch: float in [-1.44, 0.0, 1.44]:
			# Actual mouse events exercise the look path; the staged velocity is
			# a presentation stressor, not a claimed walked route.
			var event := InputEventMouseMotion.new(); event.relative = Vector2(1500.0, pitch * 100.0)
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			player.camera.rotation.x = pitch
			player.velocity = Vector3(8.0, 0.0, -8.0)
			await frames(3)
			await RenderingServer.frame_post_draw
			var size := get_viewport().get_visible_rect().size
			var bounds := projected_bounds(carrier.device.teletype._paper)
			all_inside = all_inside and Rect2(Vector2.ZERO, size).encloses(bounds)
			center_clear = center_clear and not frame.image.get_rect().has_point(size * .5)
			var paper: MeshInstance3D = carrier.device.teletype._paper
			var point := paper.to_global(paper.mesh.get_aabb().get_center())
			var composite: Vector2 = frame.view_camera.unproject_position(point) / Vector2(frame.view.size) * frame.image.size + frame.image.position
			largest_error = maxf(largest_error, composite.distance_to(player.camera.unproject_position(point)))
			rays_match = rays_match and largest_error < 2.0
	check(all_inside, "framed paper stays on screen through abrupt turns and pitch extremes at 30 60 144 fps")
	check(center_clear, "foreground rectangle never covers the centre reticle during travel")
	check(rays_match, "rendered foreground projection agrees within two pixels after late camera updates")
	check(carrier.motion.query_count == 0 and carrier.motion.collision_mask == 0, "screen flight performs no environment sweep or pursuit queries")
	var old_size := get_window().size
	var resize_clear := true; var resize_rays := true
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(960, 540)]:
		print("COMPANION FRAMING RESIZE: ", window_size, " ticks=", Time.get_ticks_msec())
		get_window().size = window_size
		await frames(4)
		await RenderingServer.frame_post_draw
		var size := get_viewport().get_visible_rect().size
		resize_clear = resize_clear and not frame.image.get_rect().has_point(size * .5)
		var paper: MeshInstance3D = carrier.device.teletype._paper
		var point := paper.to_global(paper.mesh.get_aabb().get_center())
		var projected: Vector2 = frame.view_camera.unproject_position(point) / Vector2(frame.view.size) * frame.image.size + frame.image.position
		resize_rays = resize_rays and projected.distance_to(player.camera.unproject_position(point)) < 2.0
	get_window().size = old_size
	check(resize_clear and resize_rays, "resize and 4:3 framing preserve centre clearance and authoritative rays")
	late_camera_stress = false
	process_priority = old_priority
	player.rotation = saved_rotation; player.camera.rotation = saved_camera_rotation
	player.velocity = saved_velocity; player.camera.fov = saved_fov; Engine.max_fps = saved_fps
	player.set_physics_process(was_physics)
	await frames(3)
	await capture("framed_travel.png")
	FileAccess.open(directory.path_join("screen_framing.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Native mouse turning, staged pitch/velocity, cropped projection and centre keepout. Not a walked world route or human readability acceptance.", "maximum_projection_error_px":largest_error, "stock_bounds":str(frame.stock_bounds), "query_count":carrier.motion.query_count, "reserved_rect":str(frame.safe_rect), "pass_size":str(frame.view.size)}, "\t"))

func measure_foreground_cost(allow_switching := true) -> void:
	var rows: Array = []
	var frame: Node = carrier.screen_frame
	var old_cap := Engine.max_fps
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(frame.view.get_viewport_rid(), true)
	for enabled: bool in ([true, false, false, true] if allow_switching else [true]):
		print("COMPANION RENDER DIAGNOSTIC: path=", enabled, " switching=", allow_switching, " ticks=", Time.get_ticks_msec())
		frame.composite_enabled = enabled
		await frames(24)
		var before := Time.get_ticks_usec()
		for index in 90:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			rows.append({"foreground":enabled, "wall_ms":float(now-before)/1000.0,
				"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),
				"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),
				"foreground_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(frame.view.get_viewport_rid()),
				"foreground_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(frame.view.get_viewport_rid())})
			before = now
	frame.composite_enabled = true
	Engine.max_fps = old_cap
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	RenderingServer.viewport_set_measure_render_time(frame.view.get_viewport_rid(), false)
	FileAccess.open(directory.path_join("foreground_cost.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":("Same-world ABBA foreground-visible/hidden diagnostic with fixed native rig pose; main camera always excludes instrument stock; warm-up24 and90 sampled intervals per leg. Render-loop diagnostic, not an FPS gain or full route proof; viewport monitors overlap and are not additive." if allow_switching else "Production foreground cost only; main camera always excludes instrument stock. Warm-up24 and90 intervals; no before/after gain or route qualification; monitors overlap."), "render_path_switching":allow_switching, "vsync_mode":DisplayServer.window_get_vsync_mode(), "rows":rows}, "\t"))

func projected_bounds(draw: MeshInstance3D) -> Rect2:
	return projected_aabb(draw, draw.mesh.get_aabb())

func projected_aabb(draw: Node3D, box: AABB) -> Rect2:
	var rect := Rect2(player.camera.unproject_position(draw.to_global(box.position)), Vector2.ZERO)
	for i in 8:
		var point := box.position + box.size * Vector3(float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))
		rect = rect.expand(player.camera.unproject_position(draw.to_global(point)))
	return rect

func touch_pass() -> void:
	var controls := player.get_parent().get_node_or_null("TouchControls") as TouchControls
	var created := controls == null
	if created:
		controls = TouchControls.new(); add_child(controls)
		controls.enable_companion_actions()
		controls.companion_action_requested.connect(carrier.request_correspondence)
	var was_enabled := controls.enabled
	var was_touch := player.touch_input
	controls.set_enabled(true); player.touch_input = true
	carrier.reading = false
	await frames(3)
	await touch_wire(controls)
	check(carrier.reading, "real touchscreen WIRE request recalls companion")
	await wait_for(func(): return carrier.motion.steady_for_input() and not carrier.device.teletype.printing)
	await touch_wire(controls)
	check(await wait_for(func(): return carrier.session.typing), "real touchscreen WIRE request deploys native text entry")
	await touch_wire(controls)
	check(not carrier.session.typing and carrier.session.draft == "help" and player.text_input_owner == null, "touchscreen cancellation keeps draft and returns focus")
	controls.set_enabled(was_enabled); player.touch_input = was_touch
	if created: controls.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await frames(3)

func touch_wire(controls: TouchControls) -> void:
	for button: Dictionary in controls._buttons:
		if button.action != "companion": continue
		for pressed in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 4; event.position = button.centre; event.pressed = pressed
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			await frames(3)
		return

func joy(button: JoyButton, observe_character := "") -> bool:
	var observed := false
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button; event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		for tick in 3:
			await frames(1)
			if not observe_character.is_empty(): observed = observed or physical_key_down(observe_character)
	return observed

func select_all() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_A; event.physical_keycode = KEY_A; event.ctrl_pressed = true; event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)

func wait_for(predicate: Callable, seconds := 18.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		if predicate.call(): return true
		await get_tree().process_frame
	return false

func frames(count: int) -> void:
	for index in count: await get_tree().process_frame

func key(code: Key, unicode := 0, observe_character := "") -> bool:
	if code == KEY_ENTER and is_instance_valid(carrier) and carrier.session != null:
		accept_trace.append({"ticks":Time.get_ticks_msec(), "available":carrier.session.available(), "reading":carrier.reading,
			"printing":carrier.device.teletype.printing, "opening":carrier.session.opening, "typing":carrier.session.typing,
			"protected":player.protected_input_active(), "mouse_mode":Input.mouse_mode, "focus":str(get_viewport().gui_get_focus_owner())})
		if accept_trace.size() > 64: accept_trace.pop_front()
		FileAccess.open(directory.path_join("accept_trace.json"), FileAccess.WRITE).store_string(JSON.stringify(accept_trace, "\t"))
	var observed := false
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.unicode = unicode if pressed else 0; event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		for tick in 2:
			await frames(1)
			if not observe_character.is_empty(): observed = observed or physical_key_down(observe_character)
	return observed

func type_text(text: String) -> void:
	for character in text:
		await key(character.to_upper().unicode_at(0), character.unicode_at(0))

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(filename))

func finish() -> void:
	if finished: return
	finished = true
	RealityState.persistence_enabled = false
	var failed := checks.filter(func(record: Dictionary): return not record.passed)
	FileAccess.open(directory.path_join("session.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "checks":checks, "failures":failed}, "\t"))
	get_tree().quit(0 if failed.is_empty() else 1)
