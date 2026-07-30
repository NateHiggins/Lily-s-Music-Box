class_name TouchControls
extends CanvasLayer
## Phone controls for a game built around a mouse and a keyboard.
##
## Movement and the action buttons drive the SAME named actions the desktop
## build registers in GameBoot, through Input.action_press/release with a
## strength. That is deliberate: PlayerController keeps reading
## Input.get_vector() and is_action_pressed() and never learns there is a
## touchscreen, so there is exactly one movement code path to keep correct.
## Only looking needs a direct call, because a mouse look has no action to
## borrow.
##
## Everything is drawn rather than textured, so the HUD costs no assets and
## scales to any DPI. Layout is in screen fractions for the same reason.
##
## Multi-touch is tracked by finger index: the stick owns one, the look
## drag owns another, each button owns its own. Walking while looking while
## holding run has to work, and that is three fingers.

signal look_delta(rel: Vector2)

const STICK_RADIUS := 0.11      # of the smaller screen dimension
const STICK_DEAD := 0.14        # fraction of radius ignored
const BUTTON_R := 0.052         # of the smaller screen dimension

## Left column of the screen belongs to the stick; the rest is look, minus
## the button cluster.
const STICK_ZONE := 0.42

var enabled := false

var _screen := Vector2(1280, 720)
var _unit := 720.0
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_finger := -1
var _look_last := Vector2.ZERO
## name -> {"rect": Rect2, "label": String, "action": String,
##          "toggle": bool, "finger": int, "on": bool}
var _buttons: Array = []
var _panel: Control


func _ready() -> void:
	layer = 9        # under the debug panel, over the world
	_panel = Control.new()
	_panel.name = "TouchPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	add_child(_panel)
	get_viewport().size_changed.connect(_layout)
	_layout()
	# A phone has no keyboard; a desktop run keeps its mouse and only shows
	# this when asked for, so the HUD can be checked without a device.
	set_enabled(OS.has_feature("mobile"))


func set_enabled(on: bool) -> void:
	enabled = on
	_panel.visible = on
	if not on:
		_release_all()
	_panel.queue_redraw()


func toggle() -> void:
	set_enabled(not enabled)


func _layout() -> void:
	_screen = Vector2(get_viewport().get_visible_rect().size)
	_unit = minf(_screen.x, _screen.y)
	_panel.size = _screen
	var r := BUTTON_R * _unit
	var gap := r * 2.35
	var right := _screen.x - r * 1.6
	var bottom := _screen.y - r * 1.6
	# Thumb-reachable cluster: interact and jump where the thumb rests,
	# the modal toggles stacked above them.
	# Only RUN latches. It is the one HELD action — the player polls
	# is_action_pressed for it — and pinning a thumb down to jog is
	# miserable. Crouch and the flashlight are toggles the player flips on
	# the press edge, so a plain tap does exactly what tapping the key
	# does; latching those would take two taps to mean one.
	_buttons = [
		_button("E", "interact", Vector2(right, bottom), false),
		_button("JUMP", "jump", Vector2(right - gap, bottom), false),
		_button("RUN", "run", Vector2(right, bottom - gap), true),
		_button("CROUCH", "crouch", Vector2(right - gap, bottom - gap), false),
		_button("LAMP", "flashlight", Vector2(right, bottom - gap * 2.0), false),
	]
	_panel.queue_redraw()


func _button(label: String, action: String, at: Vector2,
		toggle_button: bool) -> Dictionary:
	var r := BUTTON_R * _unit
	return {"label": label, "action": action, "toggle": toggle_button,
			"centre": at, "radius": r, "finger": -1, "on": false}


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
		get_viewport().set_input_as_handled()


func _press(finger: int, at: Vector2) -> void:
	for b in _buttons:
		if at.distance_to(b["centre"]) <= b["radius"] * 1.25:
			b["finger"] = finger
			if b["toggle"]:
				b["on"] = not b["on"]
				# Toggles latch the action down: holding RUN with a thumb
				# on a phone is not something anyone wants to do.
				if b["on"]:
					Input.action_press(b["action"])
				else:
					Input.action_release(b["action"])
			else:
				Input.action_press(b["action"])
			_panel.queue_redraw()
			return
	if at.x < _screen.x * STICK_ZONE and _stick_finger == -1:
		_stick_finger = finger
		# The stick appears under the thumb rather than at a fixed spot, so
		# it never matters exactly where the hand lands.
		_stick_origin = at
		_stick_pos = at
		_panel.queue_redraw()
	elif _look_finger == -1:
		_look_finger = finger
		_look_last = at


func _drag(finger: int, at: Vector2) -> void:
	if finger == _stick_finger:
		_stick_pos = at
		_apply_stick()
		_panel.queue_redraw()
	elif finger == _look_finger:
		# Raw pixel delta: the controller owns look sensitivity, so touch
		# and mouse cannot drift apart into two different feels.
		look_delta.emit(at - _look_last)
		_look_last = at


func _release(finger: int) -> void:
	for b in _buttons:
		if b["finger"] == finger:
			b["finger"] = -1
			if not b["toggle"]:
				Input.action_release(b["action"])
			_panel.queue_redraw()
			return
	if finger == _stick_finger:
		_stick_finger = -1
		_apply_stick_vector(Vector2.ZERO)
		_panel.queue_redraw()
	elif finger == _look_finger:
		_look_finger = -1


func _apply_stick() -> void:
	var radius := STICK_RADIUS * _unit
	var offset := (_stick_pos - _stick_origin).limit_length(radius) / radius
	if offset.length() < STICK_DEAD:
		offset = Vector2.ZERO
	_apply_stick_vector(offset)


## Feed the movement actions so the controller's Input.get_vector() call
## works unchanged. Screen +Y is down, which is forward.
func _apply_stick_vector(v: Vector2) -> void:
	_set_axis("move_right", "move_left", v.x)
	_set_axis("move_back", "move_forward", v.y)


func _set_axis(positive: String, negative: String, amount: float) -> void:
	if amount > 0.0:
		Input.action_release(negative)
		Input.action_press(positive, amount)
	elif amount < 0.0:
		Input.action_release(positive)
		Input.action_press(negative, -amount)
	else:
		Input.action_release(positive)
		Input.action_release(negative)


func _release_all() -> void:
	_apply_stick_vector(Vector2.ZERO)
	for b in _buttons:
		b["finger"] = -1
		if not b["toggle"] or not b["on"]:
			Input.action_release(b["action"])
	_stick_finger = -1
	_look_finger = -1


func _draw_panel() -> void:
	var dim := Color(1, 1, 1, 0.16)
	var lit := Color(1, 1, 1, 0.34)
	var radius := STICK_RADIUS * _unit
	var base := _stick_origin if _stick_finger != -1 \
			else Vector2(_screen.x * 0.17, _screen.y - radius * 1.5)
	_panel.draw_arc(base, radius, 0, TAU, 48, dim, 2.0, true)
	var knob := base
	if _stick_finger != -1:
		knob = base + (_stick_pos - base).limit_length(radius)
	_panel.draw_circle(knob, radius * 0.34, lit)
	for b in _buttons:
		var on: bool = b["on"] or b["finger"] != -1
		_panel.draw_arc(b["centre"], b["radius"], 0, TAU, 32,
				lit if on else dim, 2.0, true)
		if on:
			_panel.draw_circle(b["centre"], b["radius"] * 0.9,
					Color(1, 1, 1, 0.10))
		var font := ThemeDB.fallback_font
		var size := int(b["radius"] * 0.42)
		var text: String = b["label"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				size).x
		_panel.draw_string(font,
				b["centre"] + Vector2(-w * 0.5, size * 0.36), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(1, 1, 1, 0.75 if on else 0.5))
