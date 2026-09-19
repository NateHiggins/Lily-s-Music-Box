extends Node3D
## Exercise the actual F1 entry and exit in the assembled building.

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
	menu._body.visible = true
	var prior_camera := get_viewport().get_camera_3d()
	var prior_process: bool = building.player.is_processing()
	var prior_physics: bool = building.player.is_physics_processing()
	var button: Button = _find_button(menu, "Dream ecology")
	_check(button != null, "Dream ecology control is present")
	if button == null:
		get_tree().quit(1)
		return
	button.pressed.emit()
	var exhibit: DreamEcologyWarehouse = building.warehouse._ecology
	_check(exhibit != null and exhibit.active, "real button opens the living exhibit")
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
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.physical_keycode = KEY_F1
	key.pressed = true
	get_viewport().push_input(key,true)
	for i in 2: await get_tree().process_frame
	key.pressed = false
	get_viewport().push_input(key,true)
	_check(not exhibit.active and exhibit.simulation_paused and menu.visible and menu._body.visible,
		"F1 leaves inspection and restores the expanded menu")
	_check(building.player.is_processing() == prior_process and building.player.is_physics_processing() == prior_physics
		and get_viewport().get_camera_3d() == prior_camera, "exit restores prior camera and player process state")
	button.pressed.emit()
	_check(building.warehouse._ecology == exhibit and exhibit.controllers.size() == 2,
		"reopening reuses the same exhibit and batches")
	building.warehouse.close_ecology()
	building.queue_free()
	for i in 6: await get_tree().process_frame
	print("[ECOLOGY ENTRY] %d/%d passed" % [checks-failures,checks])
	get_tree().quit(0 if failures == 0 else 1)

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
