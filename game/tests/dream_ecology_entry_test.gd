extends Node3D
## Exercise keyboard, pointer, pause and ecology ownership in the real building.

var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	var building: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(building)
	await get_tree().create_timer(1.5).timeout
	var menu: BuildingDebug = _find_menu(building)
	_check(menu != null and building.warehouse != null, "actual DEBUG menu and warehouse exist")
	if menu == null or building.warehouse == null:
		get_tree().quit(1)
		return
	_check(building.warehouse._ecology == null, "ordinary warehouse construction stays lazy")
	var prior_camera := get_viewport().get_camera_3d()
	var prior_process: bool = building.player.is_processing()
	var prior_physics: bool = building.player.is_physics_processing()
	var prior_input: bool = building.player.is_processing_unhandled_input()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_check(not menu._body.visible, "debug starts with a discoverable collapsed header")
	await _key(KEY_F1)
	_check(menu._body.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		and not get_tree().paused, "F1 opens controls with a usable pointer and live world")
	var held_position: Vector3 = building.player.global_position
	var held_yaw: float = building.player.rotation.y
	var held_lamp: bool = building.player.lamp_is_enabled()
	Input.action_press("move_forward")
	Input.action_press("look_right")
	Input.action_press("lamp_toggle")
	for i in 6: await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("look_right")
	Input.action_release("lamp_toggle")
	_check(building.player.global_position.is_equal_approx(held_position)
		and is_equal_approx(building.player.rotation.y, held_yaw)
		and building.player.lamp_is_enabled() == held_lamp,
		"debug controls hold walking, stick look and polled switches")
	await _click_at(Vector2(1180, 600))
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"clicking outside controls does not recapture the pointer")
	await _key(KEY_ESCAPE)
	_check(not menu._body.visible and not get_tree().paused
		and not building.player.pause_services.is_open
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"Escape closes debug and restores capture without opening pause")
	_check(building.player.is_processing() == prior_process
		and building.player.is_physics_processing() == prior_physics
		and building.player.is_processing_unhandled_input() == prior_input,
		"closing debug restores all prior player process flags")
	await _key(KEY_ESCAPE)
	_check(get_tree().paused and building.player.pause_services.is_open,
		"Escape during play still opens ordinary pause services")
	await _key(KEY_F1)
	_check(not menu._body.visible and get_tree().paused,
		"F1 cannot open debug over the pause surface")
	await _key(KEY_ESCAPE)
	_check(not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"Escape closes pause and restores gameplay capture")
	await _key(KEY_F1)
	var go := _find_button(menu, "▸ GO — teleports")
	_check(go != null, "GO section has a mouse-reachable toggle")
	if go == null:
		get_tree().quit(1)
		return
	await _click_control(menu, go)
	var button: Button = _find_button(menu, "Dream ecology")
	_check(button != null, "Dream ecology control is present")
	if button == null:
		get_tree().quit(1)
		return
	await _click_control(menu, button)
	var exhibit: DreamEcologyWarehouse = building.warehouse._ecology
	_check(exhibit != null and exhibit.active, "actual pointer click on Dream ecology opens the living exhibit")
	if exhibit == null:
		get_tree().quit(1)
		return
	_check(not menu.visible and not menu._body.visible, "expanded underlying menu is suspended")
	_check(not building.player.is_processing() and not building.player.is_physics_processing()
		and not building.player.is_processing_unhandled_input(), "inspection suspends player actions, walking and look")
	_check(exhibit.hall_aabb() in building.safety_net.exempt_zones, "actual exhibit volume is registered with safety net")
	for i in 90: await get_tree().physics_frame
	_check(building.player.global_position.distance_to(exhibit.viewing_stand()) < 0.1,
		"player remains at exhibit after ninety composed physics frames")
	_check(get_viewport().get_camera_3d() == exhibit.camera and exhibit.stats().species == 16,
		"inspection camera renders the complete live catalogue")
	var old_distance: float = exhibit._distance
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(1000,400)
	wheel.global_position = wheel.position
	get_viewport().push_input(wheel,true)
	for i in 2: await get_tree().process_frame
	_check(exhibit._distance < old_distance, "wheel outside panel reaches inspection zoom")
	await _key(KEY_F1)
	_check(not exhibit.active and exhibit.simulation_paused and menu.visible and menu._body.visible,
		"F1 leaves inspection and restores the expanded menu")
	_check(not building.player.is_processing() and not building.player.is_physics_processing()
		and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		and get_viewport().get_camera_3d() == prior_camera,
		"exhibit exit restores the menu's pointer and held player state")
	await _click_control(menu, button)
	_check(building.warehouse._ecology == exhibit and exhibit.controllers.size() == 2
		and exhibit.active and not menu.visible and get_viewport().get_camera_3d() == exhibit.camera,
		"reopening reuses the same exhibit and batches")
	await _key(KEY_ESCAPE)
	_check(not exhibit.active and menu._body.visible and not get_tree().paused,
		"Escape exits ecology to its expanded debug controls without pausing")
	var shot_dir := OS.get_environment("SHOT_DIR")
	if not shot_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shot_dir)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("debug_go_pointer.png"))
	await _key(KEY_F1)
	_check(not menu._body.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and building.player.is_processing() == prior_process
		and building.player.is_physics_processing() == prior_physics
		and building.player.is_processing_unhandled_input() == prior_input,
		"F1 after nested inspection restores gameplay and capture")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	building.player.set_physics_process(false)
	await _key(KEY_F1)
	await _key(KEY_ESCAPE)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		and not building.player.is_physics_processing(),
		"debug preserves an already free pointer and pre-disabled physics")
	building.player.set_physics_process(prior_physics)
	building.touch.set_enabled(true)
	building.player.touch_input = true
	await _key(KEY_F1)
	var touch_yaw: float = building.player.rotation.y
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.position = Vector2(1100, 350)
	touch.pressed = true
	get_viewport().push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(1200, 350)
	drag.relative = Vector2(100, 0)
	get_viewport().push_input(drag, true)
	touch.pressed = false
	get_viewport().push_input(touch, true)
	await get_tree().process_frame
	_check(is_equal_approx(building.player.rotation.y, touch_yaw),
		"touch look outside the debug controls cannot turn the player")
	await _key(KEY_F1)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and building.touch.is_processing_unhandled_input(),
		"closing debug restores touch controls with a visible pointer")
	building.touch.set_enabled(false)
	building.player.touch_input = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _key(KEY_F1)
	building.queue_free()
	for i in 6: await get_tree().process_frame
	print("[ECOLOGY ENTRY] %d/%d passed" % [checks-failures,checks])
	get_tree().quit(0 if failures == 0 else 1)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event, true)
	for i in 2: await get_tree().process_frame
	event.pressed = false
	get_viewport().push_input(event, true)
	for i in 2: await get_tree().process_frame

func _click_control(menu: BuildingDebug, control: Control) -> void:
	menu._body.ensure_control_visible(control)
	for i in 3: await get_tree().process_frame
	print("[ECOLOGY ENTRY] click %s visible=%s rect=%s menu=%s scroll=%d" % [
		control.name, control.is_visible_in_tree(), control.get_global_rect(), menu.get_global_rect(), menu._body.scroll_vertical])
	var shot_dir := OS.get_environment("SHOT_DIR")
	if not shot_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(shot_dir)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join("before_click_%d.png" % checks))
	await _click_at(control.get_global_rect().get_center())

func _click_at(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	var hovered := get_viewport().gui_get_hovered_control()
	print("[ECOLOGY ENTRY] hover %s at %s" % [hovered.get_path() if hovered != null else NodePath(), at])
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	event.pressed = false
	get_viewport().push_input(event, true)
	for i in 3: await get_tree().process_frame

func _find_menu(node: Node) -> BuildingDebug:
	if node is BuildingDebug: return node
	for child in node.get_children():
		var result := _find_menu(child)
		if result != null: return result
	return null

func _find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption: return node
	for child in node.get_children():
		var result := _find_button(child,caption)
		if result != null: return result
	return null

func _check(passed: bool, caption: String) -> void:
	checks += 1
	if not passed: failures += 1
	print("[ECOLOGY ENTRY] %s %s" % ["PASS" if passed else "FAIL",caption])
