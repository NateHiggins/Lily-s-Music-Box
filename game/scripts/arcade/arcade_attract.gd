class_name ArcadeAttract
extends CanvasLayer
## The copy on the screen, and the only place the cabinet speaks.
##
## Everything here comes from the World Bible's `cabinet_language` block, which
## the compiler generates per world and which never touches the semantic scene.
## So this overlay is where the joke actually lands: a dance cabinet cycling
## "60 TRACKS · 4 DIFFICULTIES · NO COMBAT · JUST RHYTHM" over live footage of a
## man clearing a corridor with a sidearm.
##
## Nothing here reads gameplay except the score. It cannot: it is drawn on top of
## a viewport whose contents it has no reference to.

const _LINE_SECONDS := 2.6
const _BLINK := 0.75

var _title: Label
var _sub: Label
var _line: Label
var _coin: Label
var _score_label: Label
var _result: Label

var _lines: PackedStringArray = []
var _index := 0
var _t := 0.0
var _state: int = ArcadeMachine.State.COLD


func configure(cabinet: Dictionary) -> void:
	layer = 1
	var accent := _colour(cabinet.get("marquee_color", "#e8c84a"))
	var ink := Color(0.94, 0.95, 0.96)

	_title = _label(String(cabinet.get("title", "")), 30, accent, Vector2(0, 40))
	_sub = _label(String(cabinet.get("subtitle", "")), 13, ink, Vector2(0, 76))

	_lines = PackedStringArray()
	for entry in (cabinet.get("attract_lines", []) as Array):
		_lines.append(String(entry))
	var tagline := String(cabinet.get("tagline", ""))
	if not tagline.is_empty():
		_lines.append(tagline)
	_line = _label(_lines[0] if not _lines.is_empty() else "", 15, ink, Vector2(0, 250))

	_coin = _label("INSERT COIN", 17, accent, Vector2(0, 288))
	_score_label = _label("", 15, ink, Vector2(0, 8))
	_result = _label("", 34, accent, Vector2(0, 150))
	_result.visible = false


func _label(text: String, size: int, colour: Color, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	# A hard black outline, because this is drawn over a moving 3D image and a
	# marquee that becomes unreadable against a pale wall is a marquee that is
	# not making its claim.
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.position = at
	label.size = Vector2(ArcadeMachine.RES.x, 40)
	add_child(label)
	return label


func set_state(state: int, score: int) -> void:
	_state = state
	_t = 0.0
	var attracting := state == ArcadeMachine.State.ATTRACT
	_title.visible = attracting
	_sub.visible = attracting
	_line.visible = attracting
	_coin.visible = attracting
	_result.visible = state == ArcadeMachine.State.OVER
	_score_label.visible = state != ArcadeMachine.State.ATTRACT
	set_score(score)


func set_score(score: int) -> void:
	_score_label.text = "%07d" % score


func set_result(text: String) -> void:
	_result.text = text


func tick(delta: float) -> void:
	if _state != ArcadeMachine.State.ATTRACT:
		return
	_t += delta
	_coin.modulate.a = 1.0 if fmod(_t, _BLINK * 2.0) < _BLINK else 0.15
	if _lines.is_empty():
		return
	var wanted := int(_t / _LINE_SECONDS) % _lines.size()
	if wanted != _index:
		_index = wanted
		_line.text = _lines[_index]


func _colour(value: Variant) -> Color:
	var text := String(value)
	return Color(text) if text.begins_with("#") else Color(0.91, 0.78, 0.29)
