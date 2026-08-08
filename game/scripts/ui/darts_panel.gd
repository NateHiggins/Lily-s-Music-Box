class_name DartsPanel
extends CanvasLayer
## THE RAINBOW ROUND, on the Harukiya's board.
##
## A question is read out and the answer is always a colour. Everybody
## throws at the colour they believe. Land on it and you score; land on
## a treble of it and you score more; land on somebody else's colour and
## you have told the room what you thought the answer was.
##
## THE AIM IS A HAND, NOT A CURSOR. The reticle is never still — a slow
## wander, a breath under it, a tremor on top, the same model the torch
## uses. Holding the click steadies it over about a second and then it
## creeps back out past two, because an arm held out starts to shake. So
## knowing the answer is only half of it.
##
## The board geometry (ring radii) is DartsGame's; the colours, the deck
## and the scoring are TriviaDarts'. Nothing in this file decides what a
## throw is worth.

const VIEW_R := 300.0
const GREEN := Color(0.42, 0.94, 0.58)
const DIM := Color(0.24, 0.52, 0.34)
const IVORY := Color(0.92, 0.94, 0.90)
const WIRE := Color(0.78, 0.72, 0.52)

## The seven, as the eye reads them. Indigo has to sit visibly between
## blue and violet or the board looks like it has six slices and a
## mistake.
const SLICE := {
	"red": Color("c0392b"), "orange": Color("d97b1f"),
	"yellow": Color("d8b429"), "green": Color("3f8f4a"),
	"blue": Color("2f6fb5"), "indigo": Color("3b3f8f"),
	"violet": Color("7a4a9e"),
}

enum Step { ASK, THROWN, REVEAL }

var trivia := TriviaDarts.new()
var step: int = Step.ASK
var aim := Vector2.ZERO
var holding := false
var hold_t := 0.0

var _player: Node
var _prop: Node
var _face: Control
var _sheet: VBoxContainer
var _ask: Label
var _status: Label
var _t := 0.0
var _steady := 0.0
var _landed: Array = []
var _flash := 0.0
var _npc_wait := 0.0
var _rng := RandomNumberGenerator.new()


func open(player: Node, prop: Node, opponent := "Cam") -> void:
	_player = player
	_prop = prop
	layer = 12
	_rng.randomize()
	trivia.load_deck()
	trivia.start([{"name": "you"}, {"name": opponent, "npc": true}])
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

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 64)
	top.add_theme_constant_override("margin_right", 64)
	top.add_theme_constant_override("margin_top", 40)
	add_child(top)
	_ask = Label.new()
	_ask.add_theme_color_override("font_color", IVORY)
	_ask.add_theme_font_size_override("font_size", 24)
	_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_ask)

	var right := MarginContainer.new()
	_side_anchors(right, 0.66)
	right.add_theme_constant_override("margin_right", 56)
	right.add_theme_constant_override("margin_top", 150)
	add_child(right)
	_sheet = VBoxContainer.new()
	_sheet.add_theme_constant_override("separation", 6)
	right.add_child(_sheet)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -52
	_status.offset_left = 64
	_status.add_theme_color_override("font_color", DIM)
	_status.add_theme_font_size_override("font_size", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_refresh()


func _refresh() -> void:
	for c in _sheet.get_children():
		c.queue_free()
	var r := Label.new()
	r.text = "ROUND %d" % trivia.round_no
	r.add_theme_color_override("font_color", DIM)
	r.add_theme_font_size_override("font_size", 14)
	_sheet.add_child(r)
	for i in trivia.players.size():
		var p: Dictionary = trivia.players[i]
		var l := Label.new()
		l.text = "%s   %d" % [str(p["name"]), int(p["score"])]
		l.add_theme_color_override("font_color", IVORY)
		l.add_theme_font_size_override("font_size", 26)
		_sheet.add_child(l)
		if trivia.thrown.has(i):
			var t: Dictionary = trivia.thrown[i]
			var s := Label.new()
			s.text = "   %s %s  %s" % [str(t["ring"]), str(t["colour"]),
					"+%d" % int(t["points"]) if int(t["points"]) > 0
					else "—"]
			s.add_theme_color_override("font_color",
					SLICE.get(str(t["colour"]), DIM))
			s.add_theme_font_size_override("font_size", 15)
			_sheet.add_child(s)

	_ask.text = str(trivia.card.get("q", ""))
	match step:
		Step.REVEAL:
			var want := str(trivia.card.get("a", ""))
			var kind := str(trivia.card.get("kind", "plain"))
			var b := trivia.bonus_for(kind)
			_status.text = "%s.  %s%s   ·   ENTER for the next one" % [
					want.to_upper(), str(trivia.card.get("why", "")),
					"   (+%d, %s)" % [b, str(trivia.kinds.get(kind, {})
							.get("blurb", ""))] if b > 0 else ""]
		Step.THROWN:
			_status.text = "%s is throwing..." % _npc_name()
		_:
			_status.text = ("throw at the colour you think it is  —  "
					+ "HOLD click to steady, RELEASE to throw")


func _npc_name() -> String:
	for p in trivia.players:
		if bool(p.get("npc", false)):
			return str(p["name"])
	return "they"


func _can_throw() -> bool:
	return step == Step.ASK and not trivia.thrown.has(0)


func _centre() -> Vector2:
	var s := get_viewport().get_visible_rect().size
	return Vector2(s.x * 0.36, s.y * 0.54)


func _scale() -> float:
	var s := get_viewport().get_visible_rect().size
	return minf(s.x * 0.30, s.y * 0.40) / VIEW_R


func _px(mm: Vector2) -> Vector2:
	return _centre() + Vector2(mm.x, -mm.y) * _scale()


func _draw_board() -> void:
	var c := _centre()
	var k := _scale()
	_face.draw_circle(c, VIEW_R * k, Color(0.09, 0.08, 0.07))
	# SEVEN SLICES. The first straddles the top, so a dart at twelve
	# o'clock is never ambiguous about which slice it is in.
	var cols: Array = trivia.colours
	var n: int = maxi(1, cols.size())
	var span := 360.0 / float(n)
	for i in n:
		var a0 := deg_to_rad(-span * 0.5 + i * span)
		var a1 := a0 + deg_to_rad(span)
		var base: Color = SLICE.get(str(cols[i]), Color(0.5, 0.5, 0.5))
		_wedge(c, a0, a1, DartsGame.R_OUTER_BULL * k,
				DartsGame.R_DOUBLE_OUT * k, base.darkened(0.34))
		# The rings are the SAME colour, brighter: a treble is still the
		# colour you wanted, just worth more of it.
		_wedge(c, a0, a1, DartsGame.R_TREBLE_IN * k,
				DartsGame.R_TREBLE_OUT * k, base)
		_wedge(c, a0, a1, DartsGame.R_DOUBLE_IN * k,
				DartsGame.R_DOUBLE_OUT * k, base.lightened(0.14))
	for i in n:
		var a := deg_to_rad(-span * 0.5 + i * span)
		var dir := Vector2(sin(a), -cos(a))
		_face.draw_line(c + dir * DartsGame.R_OUTER_BULL * k,
				c + dir * DartsGame.R_DOUBLE_OUT * k, WIRE, 1.0)
	for rr in [DartsGame.R_TREBLE_IN, DartsGame.R_TREBLE_OUT,
			DartsGame.R_DOUBLE_IN, DartsGame.R_DOUBLE_OUT]:
		_face.draw_arc(c, rr * k, 0.0, TAU, 64, WIRE, 1.0)
	# Wild, so it is drawn as none of them and all of them.
	_face.draw_circle(c, DartsGame.R_OUTER_BULL * k,
			Color(0.92, 0.92, 0.88))
	_face.draw_circle(c, DartsGame.R_INNER_BULL * k,
			Color(0.20, 0.20, 0.22))

	for d in _landed:
		var p: Vector2 = _px(d)
		_face.draw_line(p + Vector2(5, -13), p, IVORY, 2.0)
		_face.draw_circle(p, 2.5, Color(0.95, 0.85, 0.45))

	if _can_throw():
		var p2 := _px(aim)
		var spread := _spread() * _scale()
		_face.draw_arc(p2, maxf(6.0, spread), 0.0, TAU, 28,
				Color(GREEN.r, GREEN.g, GREEN.b, 0.55), 1.0)
		_face.draw_line(p2 - Vector2(9, 0), p2 + Vector2(9, 0), GREEN, 1.0)
		_face.draw_line(p2 - Vector2(0, 9), p2 + Vector2(0, 9), GREEN, 1.0)
	if _flash > 0.0:
		_face.draw_circle(c, VIEW_R * k, Color(1, 1, 1, _flash * 0.12))


func _wedge(c: Vector2, a0: float, a1: float, r0: float, r1: float,
		col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 8
	for i in steps + 1:
		var a: float = a0 + (a1 - a0) * float(i) / steps
		pts.append(c + Vector2(sin(a), -cos(a)) * r1)
	for i in range(steps, -1, -1):
		var a: float = a0 + (a1 - a0) * float(i) / steps
		pts.append(c + Vector2(sin(a), -cos(a)) * r0)
	_face.draw_colored_polygon(pts, col)


func _spread() -> float:
	return lerpf(52.0, 13.0, _steady)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 3.0)
	if step == Step.THROWN:
		# The opponent takes a beat, then throws at whatever it believes.
		_npc_wait += delta
		if _npc_wait > 1.2:
			_npc_wait = 0.0
			_npc_throw()
		_face.queue_redraw()
		return
	if not _can_throw():
		_face.queue_redraw()
		return
	if holding:
		hold_t += delta
		_steady = clampf(hold_t / 1.05, 0.0, 1.0)
		if hold_t > 2.1:
			_steady = maxf(0.0, _steady - (hold_t - 2.1) * 0.55)
	else:
		hold_t = 0.0
		_steady = move_toward(_steady, 0.0, delta * 1.6)
	var live: float = 1.0 - _steady * 0.72
	var wander := Vector2(sin(_t * 0.53) * 44.0 + sin(_t * 0.31) * 27.0,
			cos(_t * 0.47) * 40.0 + sin(_t * 0.23) * 23.0)
	var breath := Vector2(sin(_t * 1.15) * 7.0, cos(_t * 1.02) * 9.0)
	var tremor := Vector2(sin(_t * 13.7) + sin(_t * 19.3) * 0.6,
			cos(_t * 15.1) + sin(_t * 21.7) * 0.5) * 4.0
	aim = (wander + breath + tremor) * live
	_face.queue_redraw()


func _throw() -> void:
	var s := _spread()
	var at := aim + Vector2(randfn(0.0, s * 0.45), randfn(0.0, s * 0.45))
	_landed.append(at)
	trivia.throw_for(0, at.x, at.y)
	_flash = 1.0
	_steady = 0.0
	hold_t = 0.0
	step = Step.THROWN
	_npc_wait = 0.0
	_refresh()


func _npc_throw() -> void:
	var pick := trivia.npc_pick(0.62)
	var target := trivia.aim_point(pick, 132.0)
	# Its hand is no better than yours.
	var at := target + Vector2(randfn(0.0, 26.0), randfn(0.0, 26.0))
	_landed.append(at)
	trivia.throw_for(1, at.x, at.y)
	step = Step.REVEAL
	_flash = 1.0
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		if (k == KEY_ENTER or k == KEY_KP_ENTER) and step == Step.REVEAL:
			trivia.deal()
			_landed = []
			step = Step.ASK
			_refresh()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT:
		if not _can_throw():
			return
		if event.pressed:
			holding = true
		else:
			holding = false
			_throw()
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
