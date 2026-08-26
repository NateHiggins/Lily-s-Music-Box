class_name OtisPanel
extends CanvasLayer
## The porter's board: the shaft drawn as a shaft.
##
## Eight landings stacked the way they are stacked, the car somewhere
## between them, and whoever is waiting standing on their own floor. You
## choose a landing to send the car. That is the whole interface, because
## the difficulty is never "which button" — it is that the car has four
## things wrong with it and six people want it at once.
##
## The log along the bottom is where the faults confess themselves: the
## car does not hear the sixth, it runs past, somebody takes the stairs.
## A player learns the machine by reading its complaints.

const IVORY := Color(0.92, 0.94, 0.90)
const BRASS := Color(0.74, 0.60, 0.30)
const BRASS_DIM := Color(0.40, 0.33, 0.18)
const GREEN := Color(0.42, 0.94, 0.58)
const RUST := Color(0.80, 0.38, 0.28)
const DIM := Color(0.44, 0.42, 0.38)

var game := Otis.new()

var _player: Node
var _prop: Node
var _view: Control
var _side: VBoxContainer
var _status: Label
var _hover := -1


func open(player: Node, prop: Node) -> void:
	_player = player
	_prop = prop
	layer = 12
	game.load_data()
	game.start()
	_build()
	if _player and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_view.grab_focus()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.045, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.focus_mode = Control.FOCUS_ALL
	_view.draw.connect(_draw_shaft)
	_view.gui_input.connect(_on_input)
	add_child(_view)
	_hover = clampi(int(round(game.at)), 0, game.floors.size() - 1)

	var right := MarginContainer.new()
	_side_anchors(right, 0.66)
	right.add_theme_constant_override("margin_right", 60)
	right.add_theme_constant_override("margin_top", 70)
	add_child(right)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 5)
	right.add_child(_side)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -58
	_status.offset_left = 60
	_status.offset_right = -60
	_status.add_theme_color_override("font_color", DIM)
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_refresh()


func _line(text: String, size := 15, col := DIM) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	_side.add_child(l)


func _refresh() -> void:
	for c in _side.get_children():
		c.queue_free()
	_line("THE CAR", 14, DIM)
	if game.aboard.is_empty():
		_line("empty", 17, DIM)
	for a in game.aboard:
		_line("%s  →  %s" % [str(a["who"]),
				game.label_of(int(a["to"]))], 17, IVORY)
	_line("", 10)
	_line("delivered   %d" % game.delivered, 16, IVORY)
	_line("stairs      %d" % game.gave_up, 16,
			RUST if game.gave_up > 0 else DIM)
	_line("", 6)
	_line("score       %d" % game.score, 22, IVORY)
	_line("", 10)
	var left: float = maxf(0.0, float(game.rules.get(
			"shift_seconds", 180.0)) - game.elapsed)
	_line("%d:%02d left" % [int(left) / 60, int(left) % 60], 16, DIM)
	if not game.running:
		_line("", 8)
		_line("SHIFT OVER", 20, BRASS)

	var tail: Array = game.log_lines.slice(
			maxi(0, game.log_lines.size() - 3))
	_status.text = ("   ·   ".join(PackedStringArray(tail))
			if not tail.is_empty()
			else "choose a landing · arrows / D-pad + accept · ESC to leave")


func _shaft_rect() -> Rect2:
	var s := get_viewport().get_visible_rect().size
	var h: float = minf(s.y * 0.74, 560.0)
	return Rect2(Vector2(s.x * 0.30, s.y * 0.5 - h * 0.5),
			Vector2(220.0, h))


## Landing 0 is at the bottom, the roof at the top — a shaft drawn the
## way a shaft is.
func _floor_y(f: float) -> float:
	var r := _shaft_rect()
	var n := float(game.floors.size())
	return r.position.y + r.size.y * (1.0 - (f + 0.5) / n)


func _landing_rect(i: int) -> Rect2:
	var r := _shaft_rect()
	var h := r.size.y / float(game.floors.size())
	return Rect2(Vector2(r.position.x, _floor_y(float(i)) - h * 0.5),
			Vector2(r.size.x, h - 3.0))


func _draw_shaft() -> void:
	var f := ThemeDB.fallback_font
	var r := _shaft_rect()
	_view.draw_rect(r.grow(10.0), Color(0.09, 0.085, 0.08))
	for i in game.floors.size():
		var lr := _landing_rect(i)
		var lit: bool = i == _hover
		var here: bool = int(round(game.at)) == i
		_view.draw_rect(lr, Color(0.15, 0.14, 0.13) if here
				else Color(0.11, 0.105, 0.10))
		_view.draw_rect(lr, BRASS if lit else BRASS_DIM, false,
				2.0 if lit else 1.0)
		_view.draw_string(f, lr.position + Vector2(10, 22),
				game.label_of(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
				BRASS)
		var nm := str(game.floors[i].get("name", ""))
		if nm != "":
			_view.draw_string(f, lr.position + Vector2(34, 22), nm,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM)
		# Whoever is standing there, and how long they will stand there.
		var x := lr.position.x + 96.0
		for w in game.waiting:
			if int(w["from"]) != i:
				continue
			var frac: float = clampf(float(w["patience"])
					/ maxf(1.0, float(game.rules.get("patience", 26.0))),
					0.0, 1.0)
			_view.draw_rect(Rect2(Vector2(x, lr.position.y + 8),
					Vector2(16, 20)),
					Color(0.86, 0.82, 0.72).lerp(RUST, 1.0 - frac))
			_view.draw_rect(Rect2(Vector2(x, lr.position.y + 30),
					Vector2(16.0 * frac, 3)), GREEN.lerp(RUST, 1.0 - frac))
			_view.draw_string(f, Vector2(x, lr.position.y + 46),
					game.label_of(int(w["to"])),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)
			x += 22.0
			if x > lr.position.x + lr.size.x - 20.0:
				break
	# The car, drawn where it actually is — between landings while it
	# travels, which is the only way the overshoot reads as an overshoot.
	var cy := _floor_y(game.at)
	var car := Rect2(Vector2(r.position.x + 4.0, cy - 20.0),
			Vector2(84.0, 40.0))
	_view.draw_rect(car, Color(0.20, 0.17, 0.11))
	_view.draw_rect(car, BRASS, false, 2.0)
	var shut: float = 1.0 if game.door == Otis.Door.SHUT else 0.25
	var gap := car.size.x * 0.5 * shut
	_view.draw_rect(Rect2(car.position + Vector2(2, 2),
			Vector2(gap - 2, car.size.y - 4)), Color(0.30, 0.25, 0.15))
	_view.draw_rect(Rect2(car.position
			+ Vector2(car.size.x - gap, 2),
			Vector2(gap - 2, car.size.y - 4)), Color(0.30, 0.25, 0.15))
	for j in game.aboard.size():
		_view.draw_rect(Rect2(car.position
				+ Vector2(8 + j * 18, car.size.y - 14),
				Vector2(14, 10)), Color(0.86, 0.82, 0.72))


func _on_input(event: InputEvent) -> void:
	if _fresh_action_press(event, &"ui_up"):
		_select_landing(_hover + 1)
		_view.accept_event()
		return
	if _fresh_action_press(event, &"ui_down"):
		_select_landing(_hover - 1)
		_view.accept_event()
		return
	if _fresh_action_press(event, &"ui_accept") and _hover >= 0:
		game.call_to(_hover)
		_refresh()
		_view.accept_event()
		return
	if event is InputEventMouseMotion:
		var p := (event as InputEventMouseMotion).position
		var was := _hover
		_hover = -1
		for i in game.floors.size():
			if _landing_rect(i).has_point(p):
				_hover = i
		if _hover != was:
			_view.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT and _hover >= 0:
		game.call_to(_hover)
		_refresh()


func _select_landing(index: int) -> void:
	_hover = clampi(index, 0, game.floors.size() - 1)
	_view.queue_redraw()


func _fresh_action_press(event: InputEvent, action: StringName) -> bool:
	return event.is_action_pressed(action) \
			and not (event is InputEventKey and (event as InputEventKey).echo)


func _process(delta: float) -> void:
	if game.running:
		game.tick(delta)
		_refresh()
	_view.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _fresh_action_press(event, &"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _player and "call_locked" in _player:
		_player.call_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _prop and _prop.has_method("panel_closed"):
		_prop.panel_closed()
	queue_free()

## A column down one side of the screen.
##
## Control.PRESET_RIGHT_WIDE anchors BOTH edges to 1.0, which is a
## container zero pixels wide whose children are laid out past the edge
## of the screen — invisible, silent, and identical to a panel that
## simply forgot to add them. Every side panel in the game had it.
func _side_anchors(c: Control, from: float, to := 1.0) -> void:
	c.anchor_left = from
	c.anchor_right = to
	c.anchor_top = 0.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = 0.0
	c.offset_bottom = 0.0
