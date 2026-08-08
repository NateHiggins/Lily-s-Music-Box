class_name DeadLettersPanel
extends CanvasLayer
## Sorting the post, with the bank drawn as the bank actually is.
##
## Four stacks across, six floors down, floor six at the top — the same
## elevation as the wall in the lobby, so the grid you learn here is the
## grid you read there. Click a box to file the letter in your hand.
##
## THE DEAD-LETTER DRAWER sits under the wall on its own, because it is
## not a box: it is the admission that a letter has nowhere to go.

const IVORY := Color(0.92, 0.94, 0.90)
const PAPER := Color(0.86, 0.83, 0.74)
const BRASS := Color(0.72, 0.58, 0.28)
const BRASS_DIM := Color(0.42, 0.34, 0.18)
const GREEN := Color(0.42, 0.94, 0.58)
const RUST := Color(0.78, 0.36, 0.28)
const DIM := Color(0.44, 0.42, 0.38)

var game := DeadLetters.new()
var reveal: Dictionary = {}

var _player: Node
var _prop: Node
var _wall: Control
var _envelope: VBoxContainer
var _side: VBoxContainer
var _status: Label
var _hover := ""


func open(player: Node, prop: Node) -> void:
	_player = player
	_prop = prop
	layer = 12
	game.load_deck()
	game.start()
	_build()
	if _player and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.045, 0.04, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_wall = Control.new()
	_wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wall.mouse_filter = Control.MOUSE_FILTER_PASS
	_wall.draw.connect(_draw_wall)
	_wall.gui_input.connect(_on_wall_input)
	add_child(_wall)

	var left := MarginContainer.new()
	_side_anchors(left, 0.0, 0.30)
	left.add_theme_constant_override("margin_left", 56)
	left.add_theme_constant_override("margin_top", 90)
	add_child(left)
	_envelope = VBoxContainer.new()
	_envelope.add_theme_constant_override("separation", 7)
	left.add_child(_envelope)

	var right := MarginContainer.new()
	_side_anchors(right, 0.74)
	right.add_theme_constant_override("margin_right", 56)
	right.add_theme_constant_override("margin_top", 90)
	add_child(right)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 5)
	right.add_child(_side)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -56
	_status.offset_left = 56
	_status.offset_right = -56
	_status.add_theme_color_override("font_color", DIM)
	_status.add_theme_font_size_override("font_size", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_refresh()


func _refresh() -> void:
	for c in _envelope.get_children():
		c.queue_free()
	for c in _side.get_children():
		c.queue_free()

	if game.done():
		_head(_envelope, "TRAY EMPTY", 26, IVORY)
		_line(_envelope, "%d filed, %d gone astray."
				% [game.filed, game.missed], 17)
		_line(_envelope, "", 10)
		for m in game.misfiled:
			_line(_envelope, "%s went to %s — should have been %s"
					% [str(m["to"]), str(m["went_to"]),
					str(m["belonged"])], 14, RUST)
		_status.text = ("nothing here is undone; a letter in the wrong "
				+ "box is just somewhere else now.   ESC to leave it")
	else:
		var L := game.current()
		_head(_envelope, "IN YOUR HAND", 14, DIM)
		var face := game.face_of(L)
		_line(_envelope, str(face[0]), 30, IVORY)
		_line(_envelope, str(face[1]), 19,
				DIM if str(face[1]) == "(no unit)" else PAPER)
		_line(_envelope, "", 8)
		for i in range(2, face.size()):
			_line(_envelope, "· " + str(face[i]), 16, PAPER)
		_status.text = ("click a box to file it, or the drawer if it "
				+ "has nowhere to go   ·   ESC to leave the tray")

	_head(_side, "TRAY", 14, DIM)
	_line(_side, "%d of %d" % [mini(game.at + 1, game.tray.size()),
			game.tray.size()], 22, IVORY)
	_line(_side, "", 8)
	_line(_side, "filed      %d" % game.filed, 16)
	_line(_side, "astray     %d" % game.missed, 16,
			RUST if game.missed > 0 else DIM)
	_line(_side, "", 8)
	_line(_side, "score      %d" % game.score, 22, IVORY)

	if not reveal.is_empty():
		_line(_side, "", 12)
		_line(_side, "RIGHT" if bool(reveal["right"]) else "ASTRAY", 16,
				GREEN if bool(reveal["right"]) else RUST)
		_line(_side, str(reveal["why"]), 14, PAPER)
	_wall.queue_redraw()


func _head(into: VBoxContainer, text: String, size: int,
		col: Color) -> void:
	_line(into, text, size, col)


func _line(into: VBoxContainer, text: String, size := 15,
		col := DIM) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	into.add_child(l)


## The wall, laid out from the data's own grid — same shape as the
## lobby: A B C D across, floor six down to one.
func _grid() -> Dictionary:
	var s := get_viewport().get_visible_rect().size
	var cols := 4
	var rows := 6
	var w: float = minf(s.x * 0.30, 360.0)
	var cw := w / cols
	var ch: float = minf(cw * 0.62, s.y * 0.72 / rows)
	return {"cols": cols, "rows": rows, "cw": cw, "ch": ch,
		"at": Vector2(s.x * 0.5 - w * 0.5, s.y * 0.5 - ch * rows * 0.5
			- 20.0)}


func _box_rect(i: int) -> Rect2:
	var g := _grid()
	var col: int = i % int(g["cols"])
	var row: int = i / int(g["cols"])
	return Rect2((g["at"] as Vector2)
			+ Vector2(col * float(g["cw"]), row * float(g["ch"])),
			Vector2(float(g["cw"]) - 4.0, float(g["ch"]) - 4.0))


func _drawer_rect() -> Rect2:
	var g := _grid()
	var w := float(g["cw"]) * int(g["cols"])
	return Rect2((g["at"] as Vector2)
			+ Vector2(0.0, float(g["ch"]) * int(g["rows"]) + 16.0),
			Vector2(w - 4.0, 34.0))


func _draw_wall() -> void:
	var f := ThemeDB.fallback_font
	for i in game.boxes.size():
		var b: Dictionary = game.boxes[i]
		var r := _box_rect(i)
		var unit := str(b.get("unit", ""))
		var empty: bool = (b.get("names", []) as Array).is_empty()
		var mine: bool = bool(b.get("player", false))
		var lit: bool = unit == _hover
		_wall.draw_rect(r, Color(0.16, 0.13, 0.09) if empty
				else Color(0.24, 0.19, 0.11))
		_wall.draw_rect(r, BRASS if lit else BRASS_DIM, false,
				2.0 if lit else 1.0)
		# The card slot, and the unit on it.
		_wall.draw_rect(Rect2(r.position + Vector2(5, r.size.y - 17),
				Vector2(r.size.x - 10, 12)),
				Color(0.30, 0.28, 0.24) if empty else PAPER * 0.85)
		_wall.draw_string(f, r.position + Vector2(8, 17), unit,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				BRASS if not empty else BRASS_DIM)
		if mine:
			_wall.draw_string(f, r.position + Vector2(8, 34), "you",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GREEN)
		elif not empty:
			var nm := str((b["names"] as Array)[0]).split(" ")
			_wall.draw_string(f,
					r.position + Vector2(8, r.size.y - 7),
					str(nm[nm.size() - 1]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(0.22, 0.19, 0.15))
	# The drawer.
	var d := _drawer_rect()
	var dlit: bool = _hover == DeadLetters.DEAD
	_wall.draw_rect(d, Color(0.12, 0.10, 0.09))
	_wall.draw_rect(d, RUST if dlit else BRASS_DIM, false,
			2.0 if dlit else 1.0)
	_wall.draw_string(f, d.position + Vector2(10, 23),
			"DEAD LETTERS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			RUST if dlit else BRASS_DIM)


func _on_wall_input(event: InputEvent) -> void:
	if game.done():
		return
	if event is InputEventMouseMotion:
		var p := (event as InputEventMouseMotion).position
		var was := _hover
		_hover = ""
		for i in game.boxes.size():
			if _box_rect(i).has_point(p):
				_hover = str(game.boxes[i].get("unit", ""))
		if _drawer_rect().has_point(p):
			_hover = DeadLetters.DEAD
		if _hover != was:
			_wall.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT:
		if _hover == "":
			return
		reveal = game.file_into(_hover)
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
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
