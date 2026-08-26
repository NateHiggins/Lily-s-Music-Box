extends Node
## The lift board is operable without a pointer and compares no keycodes.

class FakePlayer:
	extends Node
	var call_locked := false

class FakeProp:
	extends Node
	var closed := false
	func panel_closed() -> void:
		closed = true

var failures := 0


func _ready() -> void:
	var player := FakePlayer.new()
	var prop := FakeProp.new()
	var panel := OtisPanel.new()
	add_child(player)
	add_child(prop)
	add_child(panel)
	panel.open(player, prop)
	await get_tree().process_frame
	_check(panel._view.has_focus(), "the shaft owns focus when opened")
	_check(player.call_locked, "the lift board owns the player's call")
	var initial: int = panel._hover
	panel._on_input(_action(&"ui_up"))
	_check(panel._hover == mini(initial + 1, panel.game.floors.size() - 1),
			"ui_up selects the next physical landing")
	panel._on_input(_action(&"ui_down"))
	_check(panel._hover == initial,
			"ui_down returns to the lower physical landing")
	var selected: int = panel._hover
	panel._on_input(_action(&"ui_accept"))
	_check(panel.game.target == selected,
			"ui_accept sends the car to the selected landing")
	var source := FileAccess.get_file_as_string("res://scripts/ui/otis_panel.gd")
	_check(not source.contains("KEY_"), "the lift board compares no raw keycode")
	panel._unhandled_input(_action(&"ui_cancel"))
	_check(not player.call_locked and prop.closed,
			"ui_cancel closes the board and returns control")
	print("OTIS PANEL INPUT TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  %s" % label)
	else:
		failures += 1
		push_error("  FAIL  %s" % label)
