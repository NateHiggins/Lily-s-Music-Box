class_name CookbookPanel
extends CanvasLayer
## The house cookbook, read as the whole view (design/ORISON_KITCHENS_2026-10-24.md):
## the contents down the left, one receipt to a page on the right. Each page
## gives whose dish it is and where it comes from, the twist this world puts
## on it, what to buy and where, the method, the washing-up it leaves, the
## tenant's note and the compiler's red pencil. Up and down choose; ESC
## hands the pointer back.

const SERIF := preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
const ITALIC := preload("res://assets/fonts/eb_garamond/EBGaramond-Italic[wght].ttf")
const INK := Color(0.11, 0.10, 0.09)
const INK_SOFT := Color(0.30, 0.28, 0.25)
const RED := Color(0.62, 0.11, 0.09)
const RULE := Color(0.32, 0.29, 0.25)
const MARGIN := 48

var larder: KitchenLarder
var dish_id := ""
var _player: Node
var _on_close: Callable = Callable()
var _page: VBoxContainer
var _contents: ItemList
var _ids: Array[String] = []
var _bold: FontVariation
var _italic: FontVariation


## Opens on the foreword, or on one dish when `dish` names it.
func open(player: Node, source: KitchenLarder, dish := "", on_close := Callable()) -> void:
	_player = player
	larder = source
	_on_close = on_close
	layer = 12
	_bold = FontVariation.new()
	_bold.base_font = SERIF
	_bold.variation_embolden = 0.6
	_italic = FontVariation.new()
	_italic.base_font = ITALIC
	if _page == null:
		_build()
	if _player and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if dish == "":
		_foreword()
	else:
		show_dish(dish)


func _build() -> void:
	var bg := ColorRect.new()
	bg.name = "Dark"
	bg.color = Color(0.05, 0.045, 0.04, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	_contents = ItemList.new()
	_contents.name = "Contents"
	_contents.custom_minimum_size = Vector2(330, 0)
	_contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contents.add_theme_font_override("font", SERIF)
	_contents.add_theme_font_size_override("font_size", 16)
	_contents.item_selected.connect(_on_selected)
	_contents.item_activated.connect(_on_selected)
	row.add_child(_contents)
	_contents.add_item("Foreword")
	_ids.append("")
	for dish: Dictionary in larder.cookbook.dishes:
		_contents.add_item("%s (%s)" % [dish.name, _flat(str(dish.resident))])
		_ids.append(str(dish.id))
	var sheet := PanelContainer.new()
	sheet.name = "Sheet"
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_theme_stylebox_override("panel", TelegramStyle.paper_panel())
	row.add_child(sheet)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	scroll.add_child(margin)
	_page = VBoxContainer.new()
	_page.name = "Page"
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 8)
	margin.add_child(_page)


func _foreword() -> void:
	dish_id = ""
	_clear()
	_contents.select(0)
	var book: Dictionary = larder.cookbook
	_label(str(book.title).to_upper(), 40, INK, _bold, HORIZONTAL_ALIGNMENT_CENTER)
	_label(str(book.subtitle), 19, INK_SOFT, _italic, HORIZONTAL_ALIGNMENT_CENTER)
	_label("Compiled by %s" % book.compiled_by, 15, INK_SOFT, SERIF, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(2)
	_label(str(book.foreword), 18, INK)
	_label("%d receipts, one from every household." % book.dishes.size(), 15, INK_SOFT, _italic)


func show_dish(id: String) -> void:
	var dish: Dictionary = {}
	for candidate: Dictionary in larder.cookbook.dishes:
		if str(candidate.id) == id:
			dish = candidate
	if dish.is_empty():
		_foreword()
		return
	dish_id = id
	_clear()
	_contents.select(_ids.find(id))
	_label(str(dish.name), 32, INK, _bold)
	_label("From %s · %s" % [_flat(str(dish.resident)), dish.origin], 16, INK_SOFT, _italic)
	_label("Serves %d · about %d minutes" % [int(dish.serves), int(dish.minutes)], 15, INK_SOFT)
	_rule(2)
	_label(str(dish.twist), 17, INK, _italic)
	_label("WHAT TO BUY", 15, INK, _bold)
	for row: Array in dish.ingredients:
		var item: Dictionary = larder.groceries.ingredients[str(row[0])]
		_label("    %s, from %s" % [_measure(float(row[1]), str(item.unit), str(item.name)),
				larder.groceries.shops[str(item.shop)].name], 16, INK)
	_label("METHOD", 15, INK, _bold)
	var n := 1
	for line: String in dish.method:
		_label("%d.  %s" % [n, line], 17, INK)
		n += 1
	if int(dish.washing_up) > 0:
		_label("Leaves %d pieces to wash up." % int(dish.washing_up), 15, INK_SOFT, _italic)
	else:
		_label("Leaves nothing to wash up. Nothing is ever unwrapped at the table.", 15, INK_SOFT, _italic)
	_rule(1)
	_label(str(dish.note), 17, INK_SOFT, _italic)
	if dish.get("red_pencil") != null:
		_label(str(dish.red_pencil), 19, RED, _italic, HORIZONTAL_ALIGNMENT_RIGHT)


## "2 cups white haricots", "3 onions", "1 lb beef chuck": counted things
## take no unit, and units that pluralise do past one.
static func _measure(value: float, unit: String, item: String) -> String:
	if unit == "each":
		return "%s %s" % [_amount(value), item]
	var units := unit
	if value > 1.0 and unit not in ["lb", "oz", "tbsp", "tsp"]:
		units = unit + ("es" if unit.ends_with("ch") else "s")
	return "%s %s %s" % [_amount(value), units, item]


static func _amount(value: float) -> String:
	var whole := int(floor(value))
	var part := value - float(whole)
	var fraction := ""
	for pair: Array in [[0.125, "⅛"], [0.25, "¼"], [0.333, "⅓"], [0.5, "½"], [0.667, "⅔"], [0.75, "¾"]]:
		if absf(part - float(pair[0])) < 0.02:
			fraction = str(pair[1])
	if fraction == "":
		return str(whole) if part < 0.02 else "%.1f" % value
	return fraction if whole == 0 else "%d%s" % [whole, fraction]


func _flat(resident: String) -> String:
	var unit := larder.unit_of(resident)
	var who := resident.capitalize()
	if resident == "transient_guests":
		who = "the guests"
	return "%s, %s" % [who, unit] if unit != "" else who


func _clear() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()


func _label(text: String, size: int, color: Color, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = align
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", font if font != null else SERIF)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(label)
	return label


func _rule(height: int) -> void:
	var rule := ColorRect.new()
	rule.color = RULE
	rule.custom_minimum_size = Vector2(0, height)
	_page.add_child(rule)


func _on_selected(index: int) -> void:
	if index <= 0 or index >= _ids.size():
		_foreword()
	else:
		show_dish(_ids[index])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _player and "call_locked" in _player:
		_player.call_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _on_close.is_valid():
		_on_close.call()
	queue_free()
