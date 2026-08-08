class_name BookshelfPanel
extends CanvasLayer
## Tidying somebody's shelf.
##
## THE SCHEME IS NOT PRINTED ANYWHERE UNTIL YOU HAVE FOUND IT. The shelf
## shows you the books and tells you only that it wants tidying; what
## the order IS has to be read off the spines, or worked out from what
## you know about whoever lives here. The archivist's is Dewey. The
## gallerist's is a gradient. Get it right and the shelf says so.
##
## Click a spine to take it down, click a gap to put it back there. Each
## book shows its own card while you hold it — the note about the copy,
## which is where the building keeps most of its private history.

const IVORY := Color(0.92, 0.94, 0.90)
const PAPER := Color(0.86, 0.83, 0.74)
const OAK := Color(0.34, 0.23, 0.13)
const GREEN := Color(0.42, 0.94, 0.58)
const AMBER := Color(0.90, 0.72, 0.32)
const DIM := Color(0.46, 0.43, 0.39)

var shelf: ShelfSort
var guessed := false             # has the player asked what the order is

var _player: Node
var _prop: Node
var _view: Control
var _card: VBoxContainer
var _side: VBoxContainer
var _status: Label
var _hover := -1


func open(player: Node, prop: Node) -> void:
	_player = player
	_prop = prop
	shelf = prop.sorter
	layer = 12
	_build()
	if _player and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.05, 0.04, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.draw.connect(_draw_shelf)
	_view.gui_input.connect(_on_input)
	add_child(_view)

	var left := MarginContainer.new()
	_side_anchors(left, 0.0, 0.30)
	left.add_theme_constant_override("margin_left", 56)
	left.add_theme_constant_override("margin_top", 96)
	add_child(left)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 6)
	left.add_child(_card)

	var right := MarginContainer.new()
	_side_anchors(right, 0.72)
	right.add_theme_constant_override("margin_right", 56)
	right.add_theme_constant_override("margin_top", 96)
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


func _line(into: VBoxContainer, text: String, size := 15,
		col := DIM) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(310, 0)
	into.add_child(l)


func _refresh() -> void:
	for c in _card.get_children():
		c.queue_free()
	for c in _side.get_children():
		c.queue_free()

	# The book in your hand, or the one under the pointer.
	var show := shelf.held if shelf.held >= 0 else _hover
	if show >= 0 and show < shelf.order.size():
		var b: Dictionary = shelf.book(str(shelf.order[show]))
		_line(_card, "IN YOUR HAND" if shelf.held >= 0 else "", 13, DIM)
		_line(_card, str(b.get("title", "")), 25, IVORY)
		_line(_card, str(b.get("author", "")), 17, PAPER)
		_line(_card, "", 6)
		_line(_card, "%s  ·  %s  ·  %d mm  ·  %d"
				% [str(b.get("subject", "")), str(b.get("dewey", "")),
				int(b.get("height", 0)), int(b.get("year", 0))], 14, DIM)
		_line(_card, "", 8)
		_line(_card, str(b.get("note", "")), 16, PAPER)

	var sh := shelf.shelf_of(shelf.owner_name)
	_line(_side, str(sh.get("unit", "")) + "   " + shelf.owner_name,
			20, IVORY)
	_line(_side, "", 8)
	var right := shelf.rightness()
	_line(_side, "in order   %d%%" % int(round(right * 100.0)), 17,
			GREEN if shelf.is_tidy() else AMBER)
	_line(_side, "moves      %d" % shelf.moves, 15)
	_line(_side, "", 10)
	if guessed:
		_line(_side, shelf.label_of(shelf.scheme).to_upper(), 15, AMBER)
		_line(_side, shelf.note_of(shelf.scheme), 14, PAPER)
	else:
		_line(_side, "TAB — what order is this?", 14, DIM)

	if shelf.is_tidy():
		_status.text = ("that is how %s keeps them.   ESC to leave it"
				% shelf.owner_name.split(" ")[0])
	elif shelf.held >= 0:
		_status.text = "click a gap to put it back   ·   ESC to leave it"
	else:
		_status.text = ("click a spine to take it down   ·   "
				+ "TAB to work out the order   ·   ESC to leave it")
	_view.queue_redraw()


func _shelf_rect() -> Rect2:
	var s := get_viewport().get_visible_rect().size
	return Rect2(Vector2(s.x * 0.34, s.y * 0.36),
			Vector2(minf(s.x * 0.34, 460.0), 260.0))


func _spine_rect(i: int) -> Rect2:
	var r := _shelf_rect()
	var n: int = maxi(1, shelf.order.size())
	var w := r.size.x / float(n)
	var b: Dictionary = shelf.book(str(shelf.order[i]))
	var h: float = clampf(float(b.get("height", 200)) / 300.0, 0.4, 1.0) \
			* (r.size.y - 24.0)
	return Rect2(Vector2(r.position.x + i * w,
			r.position.y + r.size.y - 18.0 - h),
			Vector2(w - 4.0, h))


func _draw_shelf() -> void:
	var f := ThemeDB.fallback_font
	var r := _shelf_rect()
	# The board, and the case around it.
	_view.draw_rect(Rect2(r.position + Vector2(-16, -30),
			r.size + Vector2(32, 62)), OAK.darkened(0.45))
	_view.draw_rect(Rect2(r.position + Vector2(-16, r.size.y - 18),
			Vector2(r.size.x + 32, 18)), OAK)
	for i in shelf.order.size():
		var b: Dictionary = shelf.book(str(shelf.order[i]))
		var sr := _spine_rect(i)
		if i == shelf.held:
			# The gap. Drawn as the empty board it is.
			_view.draw_rect(sr, Color(0.10, 0.08, 0.06))
			_view.draw_rect(sr, OAK, false, 1.0)
			continue
		var col := Color.from_hsv(float(b.get("hue", 0)) / 360.0, 0.44,
				0.56)
		if i == _hover:
			col = col.lightened(0.18)
		_view.draw_rect(sr, col)
		_view.draw_rect(sr, col.darkened(0.4), false, 1.0)
		# Two bands and a title down the spine, which is all a spine is.
		_view.draw_rect(Rect2(sr.position + Vector2(2, sr.size.y * 0.16),
				Vector2(sr.size.x - 4, 2)), col.darkened(0.45))
		_view.draw_rect(Rect2(sr.position + Vector2(2, sr.size.y * 0.80),
				Vector2(sr.size.x - 4, 2)), col.darkened(0.45))
		var t := str(b.get("title", ""))
		var short := t.substr(0, mini(t.length(), 18))
		_view.draw_set_transform(sr.position
				+ Vector2(sr.size.x * 0.5 + 5, sr.size.y - 12),
				-PI * 0.5, Vector2.ONE)
		_view.draw_string(f, Vector2.ZERO, short,
				HORIZONTAL_ALIGNMENT_LEFT, sr.size.y - 22, 11,
				Color(0.94, 0.92, 0.86, 0.86))
		_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p := (event as InputEventMouseMotion).position
		var was := _hover
		_hover = -1
		for i in shelf.order.size():
			if _spine_rect(i).has_point(p):
				_hover = i
		# The whole shelf board is a target when you are holding one, so
		# a gap can be aimed at rather than hunted for.
		if _hover != was:
			_refresh()
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index \
			== MOUSE_BUTTON_LEFT:
		if _hover < 0:
			return
		shelf.touch(_hover)
		if _prop and _prop.has_method("rebuild_books"):
			_prop.rebuild_books()
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif k == KEY_TAB:
		guessed = true
		_refresh()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _player and "call_locked" in _player:
		_player.call_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _prop and _prop.has_method("panel_closed"):
		_prop.panel_closed()
	queue_free()


## A column down one side of the screen. PRESET_RIGHT_WIDE anchors both
## edges to 1.0 and yields a container zero pixels wide.
func _side_anchors(c: Control, from: float, to := 1.0) -> void:
	c.anchor_left = from
	c.anchor_right = to
	c.anchor_top = 0.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = 0.0
	c.offset_bottom = 0.0
