class_name MaintenanceActivityPanel
extends CanvasLayer
## A narrow in-world service strip for ultra-short physical interactions.
##
## The world remains visible and the mechanism supplies the motion. This layer
## only names the hand action, shows its travel and routes input through the
## shared activity director. It is not a separate game board.

const STEP_DELTA := 0.055

var _player: Node
var _mechanism: Node
var _activity_id := ""
var _director: MaintenanceActivityDirector
var _snapshot: Dictionary = {}
var _value := 0.5
var _holding := false
var _hold_started_msec := 0
var _closing := false

var _title: Label
var _cue: Label
var _feedback: Label
var _fill: ColorRect
var _marker: ColorRect
var _track: Control


func open(player: Node, mechanism: Node, activity_id: String,
		accessibility: Dictionary = {}) -> bool:
	if mechanism == null or activity_id.is_empty():
		return false
	_player = player
	add_to_group("attention_maintenance")
	_mechanism = mechanism
	_activity_id = activity_id
	_snapshot = (mechanism.call("maintenance_snapshot") as Dictionary) \
			if mechanism.has_method("maintenance_snapshot") else {}
	layer = 11
	_build()
	_director = MaintenanceActivityDirector.new()
	add_child(_director)
	_director.activity_started.connect(_on_activity_started)
	_director.step_changed.connect(_on_step_changed)
	_director.input_rejected.connect(_on_input_rejected)
	_director.activity_completed.connect(_on_completed)
	_director.activity_aborted.connect(_on_aborted)
	if not _director.begin(activity_id, accessibility):
		queue_free()
		return false
	if _player and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true


func attention_active() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _build() -> void:
	var bottom := PanelContainer.new()
	bottom.anchor_left = 0.16
	bottom.anchor_right = 0.84
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -178.0
	bottom.offset_bottom = -24.0
	bottom.add_theme_stylebox_override("panel", TelegramStyle.paper_panel(0.94))
	add_child(bottom)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	bottom.add_child(stack)
	_title = Label.new()
	TelegramStyle.apply(_title, 16, true, TelegramStyle.CARBON)
	stack.add_child(_title)
	_cue = Label.new()
	_cue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TelegramStyle.apply(_cue, 17, false, TelegramStyle.CARBON)
	stack.add_child(_cue)
	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 24)
	stack.add_child(_track)
	var bed := ColorRect.new()
	bed.color = Color(0.12, 0.10, 0.075, 0.30)
	bed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_track.add_child(bed)
	_fill = ColorRect.new()
	_fill.color = TelegramStyle.SERVICE_TEAL
	_fill.anchor_bottom = 1.0
	_track.add_child(_fill)
	_marker = ColorRect.new()
	_marker.color = TelegramStyle.OLD_RED
	_marker.anchor_bottom = 1.0
	_marker.offset_left = -2.0
	_marker.offset_right = 2.0
	_track.add_child(_marker)
	_feedback = Label.new()
	TelegramStyle.apply(_feedback, 13, false, TelegramStyle.CARBON_SOFT)
	stack.add_child(_feedback)


func _process(_delta: float) -> void:
	if not _holding or _closing or _director == null \
			or _director.active_run == null:
		return
	if _mechanism == null or not _mechanism.has_method(
			"preview_maintenance_hold"):
		return
	var step := _director.active_run.current_step()
	var required := maxf(0.01, float(step.get("hold_min_seconds", 0.01)))
	var held := float(Time.get_ticks_msec() - _hold_started_msec) / 1000.0
	_mechanism.call("preview_maintenance_hold", step,
			clampf(held / required, 0.0, 1.0), _value)


func _unhandled_input(event: InputEvent) -> void:
	if _closing or _director == null or _director.active_run == null:
		return
	if _fresh_action_press(event, &"ui_cancel"):
		_director.abort()
		get_viewport().set_input_as_handled()
		return
	if _fresh_action_press(event, &"activity_adjust_left"):
		_adjust(-STEP_DELTA)
		get_viewport().set_input_as_handled()
		return
	if _fresh_action_press(event, &"activity_adjust_right"):
		_adjust(STEP_DELTA)
		get_viewport().set_input_as_handled()
		return
	if _fresh_action_press(event, &"activity_commit"):
		_handle_commit_key(true)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released(&"activity_commit"):
		_handle_commit_key(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_adjust(motion.relative.x * 0.0025)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust(STEP_DELTA)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust(-STEP_DELTA)


func _fresh_action_press(event: InputEvent, action: StringName) -> bool:
	return event.is_action_pressed(action) \
			and not (event is InputEventKey and (event as InputEventKey).echo)


func _handle_commit_key(pressed: bool) -> void:
	var step := _director.active_run.current_step()
	if str(step.get("verb", "")) == "hold_release":
		if pressed and not _holding:
			_holding = true
			_hold_started_msec = Time.get_ticks_msec()
			_feedback.text = "HOLD — feel for the release"
		elif not pressed and _holding:
			_holding = false
			var held := float(Time.get_ticks_msec() - _hold_started_msec) / 1000.0
			_director.submit("hold_release", _value, held)
	else:
		if pressed:
			_director.submit(str(step.get("verb", "")), _value)


func _adjust(delta: float) -> void:
	_value = clampf(_value + delta, 0.0, 1.0)
	_refresh_track()
	if _mechanism and _mechanism.has_method("preview_maintenance_step"):
		_mechanism.call("preview_maintenance_step",
				_director.active_run.current_step(), _value)


func _on_activity_started(_id: String, step: Dictionary) -> void:
	_show_step(step)


func _on_step_changed(_id: String, _index: int, step: Dictionary) -> void:
	_show_step(step)


func _show_step(step: Dictionary) -> void:
	_holding = false
	_value = 0.5
	var profile := _director.active_run.profile
	_title.text = "%s  ·  %d/%d" % [str(profile.get("title", "SERVICE")),
			_director.active_run.step_index + 1,
			(profile.get("steps", []) as Array).size()]
	_cue.text = str(step.get("cue", ""))
	_feedback.text = control_hint(_current_input_family())
	_refresh_track()
	if str(step.get("verb", "")) != "hold_release" and _mechanism \
			and _mechanism.has_method("preview_maintenance_step"):
		_mechanism.call("preview_maintenance_step", step, _value)


## The player already owns input-family detection for world prompts. Read that
## presentation state; the repair panel does not invent a second device owner.
func _current_input_family() -> StringName:
	if _player and _player.has_method("_current_prompt_family"):
		return _player.call("_current_prompt_family") as StringName
	return &"keyboard"


static func control_hint(input_family: StringName) -> String:
	if input_family == &"controller":
		return "D-pad left/right to work it  ·  A to commit  ·  B to leave"
	return "A/D, arrows or mouse to work it  ·  E/Space to commit  ·  ESC to leave"


func _refresh_track() -> void:
	if _fill == null or _marker == null:
		return
	_fill.anchor_right = _value
	_fill.offset_right = 0.0
	var step := _director.active_run.current_step() \
			if _director and _director.active_run else {}
	_marker.anchor_left = float(step.get("target", 0.5))
	_marker.anchor_right = float(step.get("target", 0.5))


func _on_input_rejected(_id: String, reason: String, _step: Dictionary) -> void:
	_feedback.text = {
		"wrong_verb": "That is not the part in your hand.",
		"outside_detent": "No seat. Work it until the mechanism answers.",
		"released_early": "It has not given yet. Hold through the resistance.",
	}.get(reason, "The mechanism refuses the attempt.")


func _on_completed(_id: String, result: Dictionary) -> void:
	_closing = true
	if _mechanism and _mechanism.has_method("apply_maintenance_result"):
		_mechanism.call("apply_maintenance_result", result)
	_title.text = "SERVICE HOLDS"
	_cue.text = str(result.get("note", ""))
	_feedback.text = str(result.get("quality", "fair")).to_upper()
	await get_tree().create_timer(0.85, false).timeout
	_close(false)


func _on_aborted(_id: String) -> void:
	_close(true)


func _close(restore: bool) -> void:
	if restore and _mechanism and _mechanism.has_method(
			"restore_maintenance_snapshot"):
		_mechanism.call("restore_maintenance_snapshot", _snapshot)
	if _player and "call_locked" in _player:
		_player.call_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _mechanism and _mechanism.has_method("maintenance_panel_closed"):
		_mechanism.call("maintenance_panel_closed")
	queue_free()
