extends Node
## Controller support is a proved route through movement, view, world and UI.

var failures := 0


func _ready() -> void:
	_button(&"interact", JOY_BUTTON_A, "A reaches the world interaction")
	_button(&"jump", JOY_BUTTON_Y, "Y reaches jump")
	_button(&"crouch", JOY_BUTTON_LEFT_STICK, "L3 reaches crouch")
	_button(&"lamp_toggle", JOY_BUTTON_LEFT_SHOULDER, "LB reaches the lamp")
	_button(&"lamp_toggle", JOY_BUTTON_X, "X is the lamp's second home")
	_button(&"radio_toggle", JOY_BUTTON_RIGHT_SHOULDER, "RB reaches the radio")
	_button(&"activity_adjust_left", JOY_BUTTON_DPAD_LEFT,
			"D-pad left works a maintenance mechanism")
	_button(&"activity_adjust_right", JOY_BUTTON_DPAD_RIGHT,
			"D-pad right works a maintenance mechanism")
	_button(&"activity_commit", JOY_BUTTON_A,
			"A commits the modal maintenance action")
	_button(&"ui_cancel", JOY_BUTTON_B, "B cancels modal UI")
	_button(&"ui_cancel", JOY_BUTTON_START, "Menu opens or closes services")
	_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0, "left stick moves left")
	_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0, "left stick moves right")
	_axis(&"move_forward", JOY_AXIS_LEFT_Y, -1.0, "left stick moves forward")
	_axis(&"move_back", JOY_AXIS_LEFT_Y, 1.0, "left stick moves back")
	_axis(&"look_left", JOY_AXIS_RIGHT_X, -1.0, "right stick looks left")
	_axis(&"look_right", JOY_AXIS_RIGHT_X, 1.0, "right stick looks right")
	_axis(&"look_up", JOY_AXIS_RIGHT_Y, -1.0, "right stick looks up")
	_axis(&"look_down", JOY_AXIS_RIGHT_Y, 1.0, "right stick looks down")
	_axis(&"run", JOY_AXIS_TRIGGER_LEFT, 1.0, "LT reaches run")
	var player_source := FileAccess.get_file_as_string(
			"res://scripts/player/player_controller.gd")
	_check(player_source.contains("Input.get_vector(\"look_left\"")
			and player_source.contains("apply_look_rate(stick_look"),
			"right-stick position enters a frame-rate-independent look path")
	_check(PlayerController.resolved_stick_axis(Vector2(0.1, 0.0),
			0.18, 1.65) == Vector2.ZERO,
			"radial drift inside the explicit dead zone is silent")
	var diagonal := PlayerController.resolved_stick_axis(
			Vector2(0.7, 0.7), 0.18, 1.65)
	_check(diagonal.length() <= 1.0 and is_equal_approx(
			diagonal.normalized().x, diagonal.normalized().y),
			"response shaping preserves direction and clamps magnitude")
	print("CONTROLLER INPUT TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _button(action: StringName, button: JoyButton, label: String) -> void:
	var found := false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton \
				and (event as InputEventJoypadButton).button_index == button:
			found = true
	_check(found, label)


func _axis(action: StringName, axis: JoyAxis, value: float, label: String) -> void:
	var found := false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion \
				and (event as InputEventJoypadMotion).axis == axis \
				and is_equal_approx(
						(event as InputEventJoypadMotion).axis_value, value):
			found = true
	_check(found, label)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		failures += 1
		push_error("  FAIL  %s" % label)
