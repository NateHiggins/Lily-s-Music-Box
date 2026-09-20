extends Node3D
## The backtick key releases the pointer during play, and a click does not
## take it back. Silent recapture on any mouse button is what made every
## free pointer last exactly until you tried to use it.

var checks := 0
var failures := 0
var _old_launch_mode: int
var _old_persistence := true


func _ready() -> void:
	print("[RELEASE MOUSE] START")
	_watchdog()
	_old_launch_mode = GameBoot.launch_mode
	_old_persistence = RealityState.persistence_enabled
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	call_deferred("_run")


func _run() -> void:
	var building: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(building)
	await get_tree().create_timer(1.5).timeout
	var player = building.player
	_check("the key is bound", InputMap.has_action("release_mouse"))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.mouse_released = false

	await _key(KEY_QUOTELEFT)
	_check("the key releases the pointer",
			Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.mouse_released)

	var yaw_before: float = player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(240, 0)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	_check("a released pointer no longer turns the player",
			is_equal_approx(player.rotation.y, yaw_before))

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(900, 500)
	click.pressed = true
	get_viewport().push_input(click, true)
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	_check("clicking does not silently recapture it",
			Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.mouse_released)

	await _key(KEY_QUOTELEFT)
	_check("the key takes the pointer back",
			Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player.mouse_released)

	var yaw_now: float = player.rotation.y
	motion = InputEventMouseMotion.new()
	motion.relative = Vector2(240, 0)
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	_check("look works again once it is captured",
			not is_equal_approx(player.rotation.y, yaw_now))
	_finish()


func _key(code: int) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	get_viewport().push_input(k, true)
	k.pressed = false
	get_viewport().push_input(k, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _check(label: String, condition: bool) -> void:
	checks += 1
	if condition:
		print("[RELEASE MOUSE] PASS %s" % label)
	else:
		failures += 1
		printerr("[RELEASE MOUSE] FAIL %s" % label)


func _watchdog() -> void:
	await get_tree().create_timer(90.0).timeout
	printerr("[RELEASE MOUSE] FAIL watchdog: the run never finished")
	get_tree().quit(1)


func _finish() -> void:
	GameBoot.launch_mode = _old_launch_mode
	RealityState.persistence_enabled = _old_persistence
	print("[RELEASE MOUSE] %d/%d passed" % [checks - failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
