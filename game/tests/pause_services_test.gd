extends Node3D

var player: PlayerController
var menu: PauseServices
var behind_clicks := 0
var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	RealityState.persistence_enabled = false
	var tree := get_tree()
	var window := tree.root
	window.size = Vector2i(800, 600)

	var behind := Button.new()
	behind.text = "World test target"
	behind.position = Vector2(8, 10)
	behind.process_mode = Node.PROCESS_MODE_ALWAYS
	behind.pressed.connect(func(): behind_clicks += 1)
	add_child(behind)
	player = PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector3(.4, 0, -1.7)
	player.camera.current = true
	player.set_beam_mask_enabled(false)
	menu = player.pause_services as PauseServices
	var cabinet := DoorProp.new()
	cabinet.door_kind = "cabinet"
	cabinet.width = .55
	cabinet.height = .72
	cabinet.position.y = .74
	add_child(cabinet)
	await tree.physics_frame
	await tree.physics_frame

	behind.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_push_joy(JOY_BUTTON_START)
	await tree.process_frame
	await tree.process_frame
	_check("Start opens the installed player's pause", tree.paused and menu.is_open)
	var policy := AudioPolicy
	_check("Pause owns its audio request", policy.mix_snapshot().requests.has(&"pause_services"))
	_check("Opening gives focus to Apply", menu.apply_button.has_focus())
	var ahead := behind.get_global_rect().get_center()
	_check("Background click is outside the pause panel", not menu.panel.get_global_rect().has_point(ahead))
	_click(ahead)
	_check("Background click is absorbed while paused", behind_clicks == 0)
	var visible := Rect2(Vector2.ZERO, window.get_visible_rect().size)
	var resume := menu.find_child("ReturnWithoutSaving", true, false) as Button
	_check("Both actions fit at 800 by 600", visible.encloses(menu.panel.get_global_rect())
			and visible.encloses(menu.apply_button.get_global_rect())
			and visible.encloses(resume.get_global_rect()))
	var scroll := menu.find_child("ServicesScroll", true, false) as ScrollContainer
	_check("Both actions are outside the focus-following scroller", scroll.follow_focus
			and not scroll.is_ancestor_of(resume) and not scroll.is_ancestor_of(menu.apply_button))
	_push_joy(JOY_BUTTON_DPAD_DOWN)
	_check("Controller direction moves focus to Return", resume.has_focus())
	_push_joy(JOY_BUTTON_DPAD_UP)
	_check("Controller direction moves focus back to Apply", menu.apply_button.has_focus())
	var initial_captions := menu.captions.button_pressed
	menu.captions.grab_focus()
	_push_joy(JOY_BUTTON_A)
	_check("Controller confirm toggles only the focused option",
			menu.is_open and menu.captions.button_pressed != initial_captions)
	_push_joy(JOY_BUTTON_A)
	menu.apply_button.grab_focus()
	var focus_stays := true
	for i in 24:
		_push_key(KEY_TAB)
		var focus := window.gui_get_focus_owner()
		focus_stays = focus_stays and focus != null and menu.panel.is_ancestor_of(focus)
	_check("Tab remains in the modal through wraparound", focus_stays)
	var photo_dir := OS.get_environment("SHOT_DIR")
	if not photo_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_check("Rendered pause proof saved", window.get_texture().get_image().save_png(
				photo_dir.path_join("PauseServices800.png")) == OK)

	var master := AudioServer.get_bus_index("Master")
	var saved: float = GameBoot.settings.master_volume
	var preview := 0.32 if saved > .6 else .73
	menu.sliders.master_volume.value = preview
	_check("Pause previews volume", absf(AudioServer.get_bus_volume_db(master) - linear_to_db(preview)) < .01)
	_push_joy(JOY_BUTTON_START)
	_check("Start closes pause and restores focus", not menu.is_open and not tree.paused and behind.has_focus())
	_check("Cancel restores committed volume and clears pause mix",
			is_equal_approx(GameBoot.settings.master_volume, saved)
			and absf(AudioServer.get_bus_volume_db(master) - GameBoot.audio_bus_db("Master")) < .01
			and not policy.mix_snapshot().requests.has(&"pause_services"))
	if menu.is_open:
		menu.close()
	_click(ahead)
	_check("Background click works after Resume", behind_clicks == 1)

	tree.paused = true
	_check("Pause refuses an existing external pause", not menu.open() and tree.paused)
	tree.paused = false
	player.call_locked = true
	_push_key(KEY_ESCAPE)
	_check("Pause does not evict a protected call", player.call_locked and not tree.paused)
	player.call_locked = false
	player.seated_interaction = cabinet
	_push_joy(JOY_BUTTON_START)
	_check("Pause preserves a seated owner's input and pointer",
			player.seated_interaction == cabinet and not tree.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	player.seated_interaction = null

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.camera.look_at(cabinet._body.to_global(Vector3(cabinet.width * .5, cabinet.height * .5, 0)))
	_click(visible.get_center())
	_check("Primary mouse acquires the installed cabinet leaf", player._grab.active()
			and player._grab.target.part == cabinet._body)
	_push_key(KEY_ESCAPE)
	_check("Escape pauses without releasing the physical hand", tree.paused and player._grab.active())
	menu.sliders.master_volume.value = preview
	# A real GUI event activates Apply. push_input alone does not update
	# Input's global polled action, so feed that side of the same press too.
	Input.action_press("interact")
	_push_joy(JOY_BUTTON_A)
	await tree.process_frame
	await tree.process_frame
	_check("Controller Apply resumes and preserves the held leaf", not tree.paused
			and not menu.is_open and player._grab.active() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	var persisted := ConfigFile.new()
	_check("Apply commits through GameBoot", persisted.load(GameBoot.SETTINGS_PATH) == OK
			and is_equal_approx(float(persisted.get_value("display", "master_volume", -1.0)), preview))
	Input.action_release("interact")
	if menu.is_open:
		menu.close()
	await tree.process_frame
	Input.action_press("interact")
	await tree.process_frame
	await tree.process_frame
	Input.action_release("interact")
	_check("A fresh Interact still releases the real leaf", not player._grab.active())
	GameBoot.settings.master_volume = saved
	GameBoot.save_settings()

	_push_key(KEY_ESCAPE)
	_push_joy(JOY_BUTTON_B)
	_check("Controller Back cancels keyboard-opened pause", not menu.is_open and not tree.paused)
	if menu.is_open:
		menu.close()
	_push_joy(JOY_BUTTON_START)
	menu.sliders.master_volume.value = preview
	menu.free()
	_check("Removing paused UI releases time, mix and preview", not tree.paused
			and not policy.mix_snapshot().requests.has(&"pause_services")
			and absf(AudioServer.get_bus_volume_db(master) - GameBoot.audio_bus_db("Master")) < .01)
	print("PAUSE SERVICES TOTAL checks=%d failures=%d" % [checks, failures.size()])
	tree.quit(0 if failures.is_empty() else 1)


func _push_joy(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		get_tree().root.push_input(event, true)


func _push_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		get_tree().root.push_input(event, true)


func _click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = pressed
		get_tree().root.push_input(event, true)


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("PAUSE CHECK: ", label, " = ", ok)
	if not ok:
		failures.append(label)
