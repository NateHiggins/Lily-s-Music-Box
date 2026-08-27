extends Node
## The hero repair surface accepts semantic actions, not device keycodes.

class FakePlayer:
	extends PlayerController
	var primary_uses := 0

	func use_primary_interaction() -> void:
		primary_uses += 1

class FakeMechanism:
	extends Node
	var restored := false
	var closed := false
	var preview_count := 0

	func maintenance_snapshot() -> Dictionary:
		return {"witness": 17}

	func preview_maintenance_step(_step: Dictionary, _value: float) -> void:
		preview_count += 1

	func restore_maintenance_snapshot(snapshot: Dictionary) -> void:
		restored = snapshot == {"witness": 17}

	func maintenance_panel_closed() -> void:
		closed = true

var failures := 0


func _ready() -> void:
	_prove_registered_keyboard_events()
	await _prove_semantic_panel_route()
	print("MAINTENANCE PANEL INPUT TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _prove_registered_keyboard_events() -> void:
	for action in [&"activity_adjust_left", &"activity_adjust_right",
			&"activity_commit"]:
		_check(InputMap.has_action(action), "%s is registered" % action)
	_check(_physical_keys(&"activity_adjust_left") == [KEY_A, KEY_LEFT],
			"left work accepts A and Left through one action")
	_check(_physical_keys(&"activity_adjust_right") == [KEY_D, KEY_RIGHT],
			"right work accepts D and Right through one action")
	_check(_physical_keys(&"activity_commit") == [KEY_SPACE, KEY_E],
			"commit accepts E and Space through its own action")
	var source := FileAccess.get_file_as_string(
			"res://scripts/ui/maintenance_activity_panel.gd")
	_check(not source.contains("KEY_"),
			"the maintenance panel compares no raw keycode")
	_check(not source.contains("is_action_pressed(&\"interact\")"),
			"the panel consumes activity_commit, never the interact action")
	_check(MaintenanceActivityPanel.control_hint(&"controller") ==
			"D-pad left/right to work it  ·  A to commit  ·  B to leave",
			"the controller is told only controls present on its pad")
	_check(MaintenanceActivityPanel.control_hint(&"keyboard").contains(
			"E/Space to commit"),
			"the keyboard keeps its own repair legend")


func _prove_semantic_panel_route() -> void:
	var player := FakePlayer.new()
	var mechanism := FakeMechanism.new()
	var panel := MaintenanceActivityPanel.new()
	add_child(player)
	add_child(mechanism)
	add_child(panel)
	player._prompt_input_family = &"controller"
	_check(panel.open(player, mechanism, "radiator_vent_service"),
			"the production activity opens")
	_check(player.call_locked, "opening the panel owns the player's call")
	_check(panel._feedback.text == MaintenanceActivityPanel.control_hint(
			&"controller"), "the open panel follows the player's input family")
	var start_value: float = panel._value
	panel._unhandled_input(_action(&"activity_adjust_left", true))
	_check(is_equal_approx(panel._value, start_value - panel.STEP_DELTA),
			"semantic left action works the mechanism")
	panel._unhandled_input(_action(&"activity_adjust_right", true))
	_check(is_equal_approx(panel._value, start_value),
			"semantic right action reverses the travel")
	panel._value = 0.0
	# The controller's A button names both actions. PlayerController polls
	# interact even though the panel receives an activity_commit event; the
	# modal call lock must keep those meanings from firing together.
	Input.action_press(&"interact")
	player._process(0.016)
	panel._unhandled_input(_action(&"activity_commit", true))
	Input.action_release(&"interact")
	_check(panel._director.active_run.step_index == 1,
			"semantic commit advances the authored operation")
	_check(player.primary_uses == 0,
			"controller A commits without double-firing world interaction")
	panel._unhandled_input(_action(&"activity_commit", true))
	_check(panel._holding, "semantic commit press begins a hold-release verb")
	panel._hold_started_msec = Time.get_ticks_msec() - 1500
	panel._unhandled_input(_action(&"activity_commit", false))
	_check(panel._director.active_run.step_index == 2 and not panel._holding,
			"semantic commit release completes a sufficient hold")
	panel._unhandled_input(_action(&"ui_cancel", true))
	_check(mechanism.restored and mechanism.closed,
			"semantic cancel restores and closes the apparatus")
	_check(not player.call_locked, "semantic cancel returns the player's call")
	await get_tree().process_frame


func _action(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


func _physical_keys(action: StringName) -> Array:
	var keys := []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	keys.sort()
	return keys


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		failures += 1
		push_error("  FAIL  %s" % label)
