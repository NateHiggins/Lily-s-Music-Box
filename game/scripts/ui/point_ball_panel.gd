class_name PointBallPanel
extends CanvasLayer
## Point Ball, seen from above the table.
##
## Drag from the cue ball to aim: the direction is where you pull FROM,
## the way a finger works on a phone and a cue works in a hand — you
## draw the stick back. Distance is power. Let go and it runs.
##
## The opponent plays itself. When it is their turn the panel waits a
## beat, lets PointBallAI pick a shot, and rolls it — so you watch them
## play rather than being told what they did, which is most of what
## makes an opponent feel like one.

const CLOTH := Color(0.10, 0.30, 0.22)
const RAIL := Color(0.24, 0.16, 0.10)
const POCKET := Color(0.04, 0.05, 0.05)
const CUE_COL := Color(0.96, 0.95, 0.90)
const BALL_COL := Color(0.86, 0.30, 0.24)
const GREEN := Color(0.42, 0.94, 0.58)
const DIM := Color(0.26, 0.54, 0.36)
const IVORY := Color(0.92, 0.94, 0.90)

var table := PointBall.new()
var aiming := false
var drag_from := Vector2.ZERO
var drag_to := Vector2.ZERO

var _player: Node
var _prop: Node
var _face: Control
var _sheet: VBoxContainer
var _status: Label
var _npc_wait := 0.0
var _rng := RandomNumberGenerator.new()


func open(player: Node, prop: Node, opponent := "Cam") -> void:
	_player = player
	_prop = prop
	layer = 12
	_rng.randomize()
	table.start([{"name": "you"}, {"name": opponent, "npc": true}])
	_build()
	if _player and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.045, 0.035, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_face = Control.new()
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.draw.connect(_draw_table)
	add_child(_face)
	var right := MarginContainer.new()
	_side_anchors(right, 0.73)
	right.add_theme_constant_override("margin_right", 56)
	right.add_theme_constant_override("margin_top", 60)
	add_child(right)
	_sheet = VBoxContainer.new()
	_sheet.add_theme_constant_override("separation", 6)
	right.add_child(_sheet)
	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -50
	_status.offset_left = 56
	_status.add_theme_color_override("font_color", DIM)
	_status.add_theme_font_size_override("font_size", 15)
	add_child(_status)
	_refresh()


func _refresh() -> void:
	for c in _sheet.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = "POINT BALL"
	t.add_theme_color_override("font_color", DIM)
	t.add_theme_font_size_override("font_size", 15)
	_sheet.add_child(t)
	for p in table.players:
		var l := Label.new()
		var mine: bool = p == table.current()
		l.text = "%s%s   %d" % ["> " if mine else "  ",
				str(p["name"]), int(p["score"])]
		l.add_theme_color_override("font_color",
				IVORY if mine else DIM)
		l.add_theme_font_size_override("font_size", 26 if mine else 22)
		_sheet.add_child(l)
	var left := Label.new()
	left.text = "\n%d on the table" % table.object_balls_left()
	left.add_theme_color_override("font_color", DIM)
	left.add_theme_font_size_override("font_size", 15)
	_sheet.add_child(left)
	for line in table.log_lines.slice(maxi(0, table.log_lines.size() - 4)):
		var g := Label.new()
		g.text = str(line)
		g.add_theme_color_override("font_color", DIM)
		g.add_theme_font_size_override("font_size", 13)
		_sheet.add_child(g)

	match table.phase:
		PointBall.Phase.OVER:
			var w: Dictionary = table.leader()
			_status.text = "%s takes it, %d.   ESC to rack them up" % [
					str(w["name"]), int(w["score"])]
		PointBall.Phase.BONUS:
			_status.text = ("BONUS BALL — sink the cue, and every cushion "
					+ "on the way is a point.   ESC to leave it")
		_:
			if bool(table.current().get("npc", false)):
				_status.text = "%s is on." % str(table.current()["name"])
			else:
				_status.text = ("drag back off the cue ball to aim, "
						+ "let go to play it   ·   ESC to leave it")


func _rect() -> Rect2:
	var s := get_viewport().get_visible_rect().size
	var k: float = minf(s.x * 0.56 / PointBall.W, s.y * 0.66 / PointBall.H)
	var size := Vector2(PointBall.W, PointBall.H) * k
	return Rect2(Vector2(s.x * 0.36 - size.x * 0.5,
			s.y * 0.5 - size.y * 0.5), size)


func _px(m: Vector2) -> Vector2:
	var r := _rect()
	return r.position + Vector2(
			(m.x / PointBall.W + 0.5) * r.size.x,
			(0.5 - m.y / PointBall.H) * r.size.y)


func _scale() -> float:
	return _rect().size.x / PointBall.W


func _draw_table() -> void:
	var r := _rect()
	var k := _scale()
	_face.draw_rect(r.grow(26.0), RAIL)
	_face.draw_rect(r, CLOTH)
	for pk in table.pockets:
		_face.draw_circle(_px(pk), PointBall.POCKET_R * k, POCKET)
	for i in table.balls.size():
		var b: Dictionary = table.balls[i]
		if b["in"]:
			continue
		var p := _px(b["p"])
		var rad := PointBall.R * k
		if b["cue"]:
			_face.draw_circle(p, rad, CUE_COL)
		else:
			# Reds and yellows, alternating, because the 8 is gone and
			# nobody is keeping track of numbers any more.
			_face.draw_circle(p, rad, BALL_COL if i % 2 else
					Color(0.90, 0.74, 0.26))
			_face.draw_circle(p - Vector2(rad, rad) * 0.32, rad * 0.30,
					Color(1, 1, 1, 0.5))
	# The aim: a line back from the cue, and a ghost of where it goes.
	if aiming and not table.moving:
		var c := _px(table.cue()["p"])
		var pull := drag_from - drag_to
		if pull.length() > 4.0:
			var dir := pull.normalized()
			_face.draw_line(c, c - dir * minf(pull.length(), 240.0),
					Color(GREEN.r, GREEN.g, GREEN.b, 0.5), 2.0)
			_face.draw_line(c, c + dir * 900.0,
					Color(1, 1, 1, 0.16), 1.0)
			var pw := _power()
			_face.draw_arc(c, PointBall.R * k + 6.0, -PI * 0.5,
					-PI * 0.5 + TAU * pw, 28, GREEN, 3.0)


func _power() -> float:
	return clampf((drag_from - drag_to).length() / 240.0, 0.06, 1.0)


func _process(delta: float) -> void:
	if table.moving:
		table.step(delta)
		if not table.moving:
			_refresh()
		_face.queue_redraw()
		return
	if table.phase == PointBall.Phase.OVER:
		return
	# The opponent's go: a beat to look like thinking, then a shot.
	if bool(table.current().get("npc", false)):
		_npc_wait += delta
		if _npc_wait > 1.1:
			_npc_wait = 0.0
			var shot := PointBallAI.choose(table, "loose", _rng)
			table.shoot(shot["dir"], shot["power"])
			_refresh()
	_face.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		return
	if table.moving or table.phase == PointBall.Phase.OVER:
		return
	if bool(table.current().get("npc", false)):
		return
	if event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT:
		if event.pressed:
			aiming = true
			drag_from = (event as InputEventMouseButton).position
			drag_to = drag_from
		elif aiming:
			aiming = false
			var pull := drag_from - drag_to
			if pull.length() > 8.0:
				# Screen y is down, the table's is up.
				var dir := Vector2(pull.x, -pull.y).normalized()
				table.shoot(dir, _power())
				_refresh()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and aiming:
		drag_to = (event as InputEventMouseMotion).position
		_face.queue_redraw()


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
