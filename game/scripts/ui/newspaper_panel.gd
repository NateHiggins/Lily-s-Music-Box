class_name NewspaperPanel
extends CanvasLayer
## A front page, read as the whole view: masthead, date line, ears, the lead
## in capitals with its deck and body, three columns, the late wire. Opened
## from the news counter or the desk; ESC hands the pointer back.
##
## With a shelf, the left column lists the kept papers newest first; up and
## down move, Enter opens, the page redraws on the right.

const SERIF := preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
const ITALIC := preload("res://assets/fonts/eb_garamond/EBGaramond-Italic[wght].ttf")
const INK := Color(0.11, 0.10, 0.09)
const INK_SOFT := Color(0.30, 0.28, 0.25)
const RED := Color(0.58, 0.12, 0.10)
const PAPER := Color(0.86, 0.83, 0.74)
const RULE := Color(0.32, 0.29, 0.25)
const MARGIN := 48

var catalog: NewspaperCatalog
var paper_id := ""
var date := ""
var _player: Node
var _on_close: Callable = Callable()
var _page: VBoxContainer
var _shelf: ItemList
var _shelf_entries: Array[Dictionary] = []
var _bold: FontVariation
var _italic: FontVariation
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _lock_before := false
var _owns_input := false
var _closed := false


func open(player: Node, source: NewspaperCatalog, paper: String, issue_date: String,
		on_close := Callable()) -> void:
	if not _begin(player, source, on_close): return
	_show(paper, issue_date)


## The desk: every kept paper, newest first, the newest open.
func open_shelf(player: Node, source: NewspaperCatalog, on_close := Callable()) -> void:
	if not _begin(player, source, on_close): return
	_shelf_entries = catalog.collected()
	_shelf.clear()
	for entry in _shelf_entries:
		_shelf.add_item("%s   %s" % [catalog.short_date(entry.date),
				str(catalog.paper(entry.paper).get("name", entry.paper))])
	_shelf.visible = true
	if _shelf_entries.is_empty():
		_empty_shelf()
	else:
		_shelf.select(0)
		_show(_shelf_entries[0].paper, _shelf_entries[0].date)
		_shelf.grab_focus()


func _begin(player: Node, source: NewspaperCatalog, on_close: Callable) -> bool:
	if _closed or (_owns_input and player != _player): return false
	if not _owns_input:
		_mouse_before = Input.mouse_mode
		if is_instance_valid(player) and "call_locked" in player:
			# The public getter also includes a companion text lease. Preserve
			# the protected flag itself, without converting a text lease into it.
			_lock_before = bool(player.call("protected_input_active")) if player.has_method("protected_input_active") else bool(player.call_locked)
		_owns_input = true
	_player = player
	catalog = source
	_on_close = on_close
	layer = 12
	_bold = FontVariation.new()
	_bold.base_font = SERIF
	_bold.variation_embolden = 0.6
	_italic = FontVariation.new()
	_italic.base_font = ITALIC
	if _page == null:
		_build()
	if is_instance_valid(_player) and "call_locked" in _player:
		_player.call_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


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
	_shelf = ItemList.new()
	_shelf.name = "Shelf"
	_shelf.custom_minimum_size = Vector2(300, 0)
	_shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shelf.visible = false
	_shelf.add_theme_font_override("font", SERIF)
	_shelf.add_theme_font_size_override("font_size", 16)
	_shelf.item_selected.connect(_on_shelf_selected)
	_shelf.item_activated.connect(_on_shelf_selected)
	row.add_child(_shelf)
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


func _show(paper: String, issue_date: String) -> void:
	paper_id = paper
	date = issue_date
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	if not catalog.published_now(paper, issue_date):
		_label("This edition has not been published.", 20, INK)
		return
	var meta := catalog.paper(paper)
	var page := catalog.issue(paper, issue_date)
	if page.is_empty():
		_label("No such issue.", 20, INK)
		return
	# The reading surface supplies the exact edition actually shown. Merely
	# owning/looking up an issue grants the companion no reading witness.
	if is_instance_valid(_player) and is_instance_valid(_player.get("carried_device")):
		var carrier: Node = _player.carried_device
		if carrier.get("witness") != null:
			carrier.witness.paper_shown(catalog, paper, issue_date)
	var red: bool = str(meta.get("ink", "black")) == "red"
	# Masthead.
	_label(str(meta.get("name", paper)).to_upper(), 44, RED if red else INK, _bold,
			HORIZONTAL_ALIGNMENT_CENTER)
	_label(str(meta.get("masthead_line", "")), 15, INK_SOFT, _italic, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(2)
	# Date line and ears.
	var ears := HBoxContainer.new()
	_page.add_child(ears)
	var left := _label_into(ears, str(page.get("ear", "")), 14, INK_SOFT, _italic)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var middle := _label_into(ears, "%s   %s edition" % [catalog.long_date(issue_date),
			str(meta.get("edition", ""))], 14, INK, null, HORIZONTAL_ALIGNMENT_CENTER)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := _label_into(ears, "Price %s" % str(meta.get("price", "")), 14, INK_SOFT, null,
			HORIZONTAL_ALIGNMENT_RIGHT)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rule(1)
	var weather: Dictionary = page.get("weather_report",{})
	if not weather.is_empty():
		_label("WEATHER DESK / " + CampaignWeather.print_time(str(weather.get("issued_at",""))) + " E.S.T.",14,INK,_bold)
		_label(str(weather.get("observation","")),14,INK_SOFT,_italic)
		_label(str(weather.get("prediction","")) + " " + str(weather.get("outlook","")),15,INK)
		_label("Outlook: %s. Valid %s to %s E.S.T." % [weather.get("confidence",""),
			CampaignWeather.print_time(str(weather.get("valid_from",""))),
			CampaignWeather.print_time(str(weather.get("valid_until","")))],12,INK_SOFT,_italic)
		if str(weather.get("revision",""))!="": _label(str(weather.revision),14,INK_SOFT,_italic)
		for dispatch: Dictionary in weather.get("timeline",[]):
			if str(dispatch.get("issued_at",""))==str(weather.get("issued_at","")): continue
			_label("Previous dispatch, %s E.S.T.: %s"%[CampaignWeather.print_time(str(dispatch.get("issued_at",""))),
				dispatch.get("prediction","")],12,INK_SOFT,_italic)
		_rule(1)
	# The lead.
	var lead: Dictionary = page.get("lead", {})
	_label(str(lead.get("headline", "")).to_upper(), 34, RED if red else INK, _bold,
			HORIZONTAL_ALIGNMENT_CENTER)
	_label(str(lead.get("deck", "")), 18, INK, _italic, HORIZONTAL_ALIGNMENT_CENTER)
	_label(str(lead.get("body", "")), 17, INK)
	_rule(1)
	# Three columns.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	_page.add_child(columns)
	for column in page.get("columns", []):
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 6)
		columns.add_child(box)
		_label_into(box, str(column.get("headline", "")).to_upper(), 16, INK, _bold)
		_label_into(box, str(column.get("body", "")), 15, INK)
	# The editor's weekly column, boxed under the columns on the days it runs.
	var editorial: Dictionary = page.get("editorial", {})
	if not editorial.is_empty():
		var chair: Dictionary = meta.get("editorial", {})
		_rule(2)
		_label(str(chair.get("title", "Editorial")).to_upper(), 15, RED if red else INK, _bold,
				HORIZONTAL_ALIGNMENT_CENTER)
		_label(str(editorial.get("headline", "")), 22, INK, _bold, HORIZONTAL_ALIGNMENT_CENTER)
		_label(str(editorial.get("body", "")), 16, INK)
		_label(str(chair.get("byline", "")), 14, INK_SOFT, _italic, HORIZONTAL_ALIGNMENT_RIGHT)
	_rule(1)
	_label(str(page.get("wire", "")), 14, INK_SOFT, _italic)
	# The sky yesterday, in this paper's own words.
	for notice: Dictionary in catalog.sky_notices(issue_date):
		_label(str(notice.get("headline", "")).to_upper(), 14, INK, _bold)
		_label(str(notice.get(paper, "")), 14, INK)
	_label("ESC closes the paper", 12, INK_SOFT, _italic, HORIZONTAL_ALIGNMENT_RIGHT)


func _empty_shelf() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_label("Nothing kept yet.", 24, INK, _bold, HORIZONTAL_ALIGNMENT_CENTER)
	_label("The rack at News & Cigars sells both papers for the day and a few days before.",
			15, INK_SOFT, _italic, HORIZONTAL_ALIGNMENT_CENTER)


func _label(text: String, size: int, color: Color, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label_into(_page, text, size, color, font, align)


func _label_into(into: Control, text: String, size: int, color: Color, font: Font = null,
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
	into.add_child(label)
	return label


func _rule(height: int) -> void:
	var rule := ColorRect.new()
	rule.color = RULE
	rule.custom_minimum_size = Vector2(0, height)
	_page.add_child(rule)


func _on_shelf_selected(index: int) -> void:
	if index < 0 or index >= _shelf_entries.size():
		return
	_show(_shelf_entries[index].paper, _shelf_entries[index].date)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if _closed: return
	_closed = true
	_release_input()
	if _on_close.is_valid():
		_on_close.call()
	queue_free()


func _release_input() -> void:
	if not _owns_input: return
	_owns_input = false
	var live_player := is_instance_valid(_player)
	if live_player and _player.is_queued_for_deletion(): return
	if live_player and "call_locked" in _player:
		_player.call_locked = _lock_before
	if get_tree() == null or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE: return
	if live_player and _player.has_method("protected_input_active") and bool(_player.call("protected_input_active")): return
	if live_player and "text_input_owner" in _player and is_instance_valid(_player.get("text_input_owner")): return
	Input.mouse_mode = _mouse_before


func _exit_tree() -> void:
	_release_input()
