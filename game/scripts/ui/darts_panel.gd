class_name DartsPanel
extends CanvasLayer
## Throwing darts, and the scoreboard beside the board.
##
## THE AIM IS A HAND, NOT A CURSOR. The reticle is never still: a slow
## wander, a breath under it, and a fast tremor on top, exactly the
## model the torch uses — because the difficulty in darts is not finding
## 20, it is releasing at the moment the hand happens to be over it.
## Holding still to steady the throw is the whole skill, so the sway
## SHRINKS while you hold and creeps back if you hold too long, which is
## also true of the arm.
##
## Scoring lives in DartsGame and takes millimetres from the bull, so
## none of the feel below can break the rules.

const BOARD_R := 225.5           # mm, sisal edge
const VIEW_R := 300.0            # mm shown, so the surround is visible
const GREEN := Color(0.42, 0.94, 0.58)
const DIM := Color(0.24, 0.52, 0.34)
const IVORY := Color(0.92, 0.94, 0.90)
const WIRE := Color(0.78, 0.72, 0.52)
const RED := Color("b8342b")
const GRN := Color("2f7a48")
const CREAM := Color("d9cfae")
const BLACK := Color("1a1712")

var game := DartsGame.new()
var aim := Vector2.ZERO          # mm from bull
var holding := false
var hold_t := 0.0

var _player: Node
var _prop: Node
var _face: Control
var _sheet: VBoxContainer
var _status: Label
var _t := 0.0
var _steady := 1.0
var _landed: Array = []          # this turn's darts, in mm
var _flash := 0.0


func open(player: Node, prop: Node) -> void:
	_player = player
	_prop = prop
	layer = 12
	game.reset()
	_build()
	if _player and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.045, 0.035, 0.96)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_face = Control.new()
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.draw.connect(_draw_board)
	add_child(_face)

	var right := MarginContainer.new()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.add_theme_constant_override("margin_right", 60)
	right.add_theme_constant_override("margin_top", 70)
	add_child(right)
	_sheet = VBoxContainer.new()
	_sheet.add_theme_constant_override("separation", 8)
	right.add_child(_sheet)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -54
	_status.offset_left = 60
	_status.add_theme_color_override("font_color", DIM)
	_status.add_theme_font_size_override("font_size", 15)
	add_child(_status)
	_refresh()


func _refresh() -> void:
	for c in _sheet.get_children():
		c.queue_free()
	var head := Label.new()
	head.text = "301"
	head.add_theme_color_override("font_color", DIM)
	head.add_theme_font_size_override("font_size", 15)
	_sheet.add_child(head)
	var big := Label.new()
	big.text = str(game.score)
	big.add_theme_color_override("font_color", IVORY)
	big.add_theme_font_size_override("font_size", 64)
	_sheet.add_child(big)
	var call := Label.new()
	call.text = game.call_out()
	call.add_theme_color_override("font_color", GREEN)
	call.add_theme_font_size_override("font_size", 17)
	_sheet.add_child(call)
	var darts := Label.new()
	darts.text = "darts:  " + "|".repeat(maxi(0, game.darts_left))
	darts.add_theme_color_override("font_color", DIM)
	darts.add_theme_font_size_override("font_size", 16)
	_sheet.add_child(darts)
	var this_turn := ""
	for h in game.turn_hits:
		this_turn += "%s  " % str(h.label)
	if this_turn != "":
		var tl := Label.new()
		tl.text = this_turn + " = %d" % game.turn_total()
		tl.add_theme_color_override("font_color",
				RED if game.turn_hits.size() > 0
				and game.turn_hits[-1].get("bust", false) else DIM)
		tl.add_theme_font_size_override("font_size", 16)
		_sheet.add_child(tl)

	match game.state:
		DartsGame.State.WON:
			_status.text = "game shot, and the leg.   ENTER play again   ·   ESC put them back"
		DartsGame.State.TURN_OVER:
			_status.text = "ENTER for the next three   ·   ESC put them back"
		_:
			_status.text = ("HOLD click to steady, RELEASE to throw"
					+ "   ·   ESC put them back")


func _centre() -> Vector2:
	var s := get_viewport().get_visible_rect().size
	return Vector2(s.x * 0.36, s.y * 0.52)


func _scale() -> float:
	var s := get_viewport().get_visible_rect().size
	return minf(s.x * 0.30, s.y * 0.42) / VIEW_R


## Board to screen.
func _px(mm: Vector2) -> Vector2:
	# Screen y grows downward; the board's does not.
	return _centre() + Vector2(mm.x, -mm.y) * _scale()


func _draw_board() -> void:
	var c := _centre()
	var k := _scale()
	# Surround, then the sisal.
	_face.draw_circle(c, VIEW_R * k, Color(0.09, 0.08, 0.07))
	_face.draw_circle(c, BOARD_R * k, BLACK)
	# Twenty beds. Alternating cream and black, with the doubles and
	# trebles in red and green over them — the arrangement everyone can
	# picture and nobody can name.
	for i in DartsGame.BEDS.size():
		var a0 := deg_to_rad(-9.0 + i * 18.0)
		var a1 := a0 + deg_to_rad(18.0)
		var light := i % 2 == 0
		_wedge(c, a0, a1, DartsGame.R_OUTER_BULL * k,
				DartsGame.R_DOUBLE_OUT * k,
				CREAM if light else BLACK)
		_wedge(c, a0, a1, DartsGame.R_TREBLE_IN * k,
				DartsGame.R_TREBLE_OUT * k, RED if light else GRN)
		_wedge(c, a0, a1, DartsGame.R_DOUBLE_IN * k,
				DartsGame.R_DOUBLE_OUT * k, RED if light else GRN)
	# Wires.
	for i in DartsGame.BEDS.size():
		var a := deg_to_rad(-9.0 + i * 18.0)
		var dir := Vector2(sin(a), -cos(a))
		_face.draw_line(c + dir * DartsGame.R_OUTER_BULL * k,
				c + dir * DartsGame.R_DOUBLE_OUT * k, WIRE, 1.0)
	for r in [DartsGame.R_TREBLE_IN, DartsGame.R_TREBLE_OUT,
			DartsGame.R_DOUBLE_IN, DartsGame.R_DOUBLE_OUT]:
		_face.draw_arc(c, r * k, 0.0, TAU, 64, WIRE, 1.0)
	_face.draw_circle(c, DartsGame.R_OUTER_BULL * k, GRN)
	_face.draw_circle(c, DartsGame.R_INNER_BULL * k, RED)

	# Darts already in the board this turn.
	for d in _landed:
		var p: Vector2 = _px(d)
		_face.draw_line(p + Vector2(5, -13), p, IVORY, 2.0)
		_face.draw_circle(p, 2.5, Color(0.95, 0.85, 0.45))

	# The reticle, only while there are darts to throw.
	if game.state == DartsGame.State.THROWING:
		var p := _px(aim)
		var spread := _spread() * _scale()
		_face.draw_arc(p, maxf(6.0, spread), 0.0, TAU, 28,
				Color(GREEN.r, GREEN.g, GREEN.b, 0.55), 1.0)
		_face.draw_line(p - Vector2(9, 0), p + Vector2(9, 0), GREEN, 1.0)
		_face.draw_line(p - Vector2(0, 9), p + Vector2(0, 9), GREEN, 1.0)
	if _flash > 0.0:
		_face.draw_circle(c, VIEW_R * k,
				Color(1, 1, 1, _flash * 0.12))


func _wedge(c: Vector2, a0: float, a1: float, r0: float, r1: float,
		col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 6
	for i in steps + 1:
		var a: float = a0 + (a1 - a0) * float(i) / steps
		pts.append(c + Vector2(sin(a), -cos(a)) * r1)
	for i in range(steps, -1, -1):
		var a: float = a0 + (a1 - a0) * float(i) / steps
		pts.append(c + Vector2(sin(a), -cos(a)) * r0)
	_face.draw_colored_polygon(pts, col)


## How wide the dart can land off the reticle, in mm. Steadying tightens
## it; holding too long lets it creep back, because an arm held out
## starts to shake.
func _spread() -> float:
	return lerpf(46.0, 11.0, _steady)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	if game.state != DartsGame.State.THROWING:
		_face.queue_redraw()
		return
	if holding:
		hold_t += delta
		# Steadies over about a second, then drifts back out past two.
		_steady = clampf(hold_t / 1.05, 0.0, 1.0)
		if hold_t > 2.1:
			_steady = maxf(0.0, _steady - (hold_t - 2.1) * 0.55)
	else:
		hold_t = 0.0
		_steady = move_toward(_steady, 0.0, delta * 1.6)
	# The hand: a slow wander, a breath, and a tremor, all damped by how
	# steady the player has managed to get.
	var live: float = 1.0 - _steady * 0.72
	var wander := Vector2(sin(_t * 0.53) * 42.0 + sin(_t * 0.31) * 26.0,
			cos(_t * 0.47) * 38.0 + sin(_t * 0.23) * 22.0)
	var breath := Vector2(sin(_t * 1.15) * 7.0, cos(_t * 1.02) * 9.0)
	var tremor := Vector2(sin(_t * 13.7) + sin(_t * 19.3) * 0.6,
			cos(_t * 15.1) + sin(_t * 21.7) * 0.5) * 4.0
	aim = (wander + breath + tremor) * live
	_face.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			if game.state == DartsGame.State.WON:
				game.reset()
				_landed = []
			elif game.state == DartsGame.State.TURN_OVER:
				game.next_turn()
				_landed = []
			_refresh()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT:
		if game.state != DartsGame.State.THROWING:
			return
		if event.pressed:
			holding = true
		else:
			holding = false
			_throw()
		get_viewport().set_input_as_handled()


func _throw() -> void:
	var s := _spread()
	var off := Vector2(randfn(0.0, s * 0.45), randfn(0.0, s * 0.45))
	var at := aim + off
	_landed.append(at)
	var hit := game.throw_at(at.x, at.y)
	_flash = 1.0
	_steady = 0.0
	hold_t = 0.0
	if game.state == DartsGame.State.TURN_OVER \
			or game.state == DartsGame.State.WON:
		pass
	_refresh()


func close() -> void:
	if _player and "call_locked" in _player:
		_player.call_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _prop and _prop.has_method("panel_closed"):
		_prop.panel_closed()
	queue_free()
