class_name PocketPaperPanel
extends CanvasLayer
## One paper drawn from the case, held up to read: a letter as the box delivered it,
## a comic's cover, or one of Lily's strips, a picture with its lettering drawn in. It is the hand's: the next click lets it go back into the pocket
## (RUL-013), and ESC or the case key does the same. The case keeps the pointer
## and the player's lock; this panel only shows the sheet.

const TYPE := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const TYPE_BOLD := preload("res://assets/fonts/courier_prime/CourierPrime-Bold.ttf")
const INK := Color(0.12, 0.10, 0.08)
const INK_SOFT := Color(0.36, 0.32, 0.27)
const PAPER := Color(0.91, 0.87, 0.77)
const SHEET_WIDTH := 620.0
const STRIP_WIDTH := 1180.0

var entry: Dictionary = {}
var sheet: PanelContainer
var _on_close: Callable = Callable()
var _closed := false


## As NewspaperPanel.fit_scale: as much of the screen as the sheet can use, its text growing with it.
static func fit_scale(screen: Vector2) -> float:
	return clampf(minf(screen.x / 1280.0, screen.y / 860.0), 0.8, 2.0)


func open(paper: Dictionary, on_close := Callable()) -> void:
	entry = paper
	_on_close = on_close
	layer = 41
	var k := fit_scale(get_viewport().get_visible_rect().size)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	sheet = PanelContainer.new()
	sheet.name = "Sheet"
	var screen := get_viewport().get_visible_rect().size
	var width := SHEET_WIDTH * k
	var picture: Texture2D = null
	if str(paper.get("image", "")) != "":
		picture = load(str(paper.image)) as Texture2D
		# A strip is three panels side by side: the sheet takes most of the screen's width for it.
		width = minf(screen.x * 0.9, STRIP_WIDTH * k)
	sheet.custom_minimum_size = Vector2(width, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color(0.55, 0.49, 0.40)
	style.set_border_width_all(1)
	style.content_margin_left = 44 * k
	style.content_margin_right = 44 * k
	style.content_margin_top = 36 * k
	style.content_margin_bottom = 40 * k
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	sheet.add_theme_stylebox_override("panel", style)
	centre.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	sheet.add_child(column)
	column.add_child(_line(str(paper.get("heading", "BOX 4B — LETTER")), TYPE, int(14 * k), INK_SOFT, k, width))
	column.add_child(_line(str(paper.get("title", "")), TYPE_BOLD, int(22 * k), INK, k, width))
	if picture != null:
		var art := TextureRect.new()
		art.name = "Strip"
		art.texture = picture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var shown := width - 88 * k
		art.custom_minimum_size = Vector2(shown, shown * picture.get_height() / float(picture.get_width()))
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(art)
	if str(paper.get("body", "")) != "":
		column.add_child(_line(str(paper.get("body", "")), TYPE, int(18 * k), INK, k, width))


func _line(text: String, font: Font, size: int, color: Color, k := 1.0, width := SHEET_WIDTH) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width - 88 * k, 0)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed("carried_case") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventKey:
		get_viewport().set_input_as_handled()


func close() -> void:
	if _closed:
		return
	_closed = true
	if _on_close.is_valid():
		_on_close.call()
	queue_free()
