class_name NewspaperTypesetter
extends RefCounted
## Sets the pages of the two papers on the panel's sheet. The Record is gray and
## stepped under a blackletter nameplate; the Speaker shouts in red under its horn
## and runs whatever picture it can get, faked or not. Every picture is optional:
## a day with none still makes a whole page.

const SERIF := preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
const ITALIC := preload("res://assets/fonts/eb_garamond/EBGaramond-Italic[wght].ttf")
const FAT := preload("res://assets/fonts/abrilfatface/AbrilFatface-Regular.ttf")
const BLACKLETTER := preload("res://assets/fonts/unifrakturcook/UnifrakturCook-Bold.ttf")
const OLD := preload("res://assets/fonts/oldstandardtt/OldStandard-Regular.ttf")
const OLD_BOLD := preload("res://assets/fonts/oldstandardtt/OldStandard-Bold.ttf")
const PRINT_SHADER := preload("res://assets/shaders/newspaper_print.gdshader")
const HORN := "res://assets/ui/newspaper/furniture/speaker_horn.webp"
const INK := Color(0.11, 0.098, 0.086)
const SOFT := Color(0.30, 0.28, 0.25)
const RED := Color(0.58, 0.12, 0.10)
const BROWN := Color(0.18, 0.106, 0.055)
const CREAM := Color(0.886, 0.824, 0.706)
const GUTTER := 12

var catalog: NewspaperCatalog
var page: VBoxContainer
var width := 1000
var paper_id := ""
var date := ""


func _init(source: NewspaperCatalog, into: VBoxContainer, inner_width: int, paper: String, issue_date: String) -> void:
	catalog = source
	page = into
	width = inner_width
	paper_id = paper
	date = issue_date


## --- the fronts --------------------------------------------------------------

func speaker_front(meta: Dictionary, issue: Dictionary) -> void:
	var head := _row(page, 10)
	var motto := _boxed(head, 112)
	_text(motto, str(meta.get("masthead_line", "")).to_upper(), 12, INK, OLD_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 96)
	var words := str(meta.get("name", paper_id)).to_upper().rsplit(" ", true, 1)
	var plate_size := int(clampf(width / 19.0, 34.0, 54.0))
	_text(head, words[0], plate_size, RED, FAT, HORIZONTAL_ALIGNMENT_RIGHT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_print_into(head, {"image": HORN, "treatment": "ink"}, int(width * 0.14), RED)
	_text(head, words[-1], plate_size, RED, FAT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var price := _boxed(head, 112)
	_text(price, "%s EDITION" % str(meta.get("edition", "")).to_upper(), 12, INK, OLD_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 96)
	_text(price, str(meta.get("price", "")), 13, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER, 96)
	_rule(page, 3, RED)
	var line := _row(page, 16)
	_text(line, str(issue.get("ear", "")), 14, SOFT, ITALIC)
	_text(line, catalog.long_date(date), 14, INK, null, HORIZONTAL_ALIGNMENT_RIGHT, 240)
	_rule(page, 1)
	var lead: Dictionary = issue.get("lead", {})
	var picture := catalog.front_picture(paper_id, date)
	var wide := str(picture.get("form", "")) == "wide"
	_banner(page, str(lead.get("headline", "")).to_upper(), FAT, 58 if wide else 46, 2, INK if wide else RED)
	if wide:
		_print_into(page, picture, width)
		_text(page, str(picture.caption), 15, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER)
	_text(page, str(lead.get("deck", "")), 20, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(page, 1)
	if wide:
		_speaker_under_picture(lead, issue)
	else:
		_speaker_three_columns(lead, issue, picture)
	_issue_foot(issue, RED, true)


func _speaker_under_picture(lead: Dictionary, issue: Dictionary) -> void:
	var side := int((width - GUTTER * 2 - 2) / 3.0)
	var row := _row(page, GUTTER)
	var parts := _halves(str(lead.get("body", "")), SERIF, 16, side)
	_text(_column(row, side), parts[0], 16, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL, side)
	_vrule(row)
	_text(_column(row, side), parts[1], 16, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL, side)
	_vrule(row)
	var third := _column(row, side)
	var columns: Array = issue.get("columns", [])
	_speaker_story(third, columns[0], side)
	_rule(page, 1)
	var under := _row(page, GUTTER)
	var half := int((width - GUTTER - 1) / 2.0)
	_speaker_story(_column(under, half), columns[1], half)
	_vrule(under)
	_speaker_story(_column(under, half), columns[2], half)


func _speaker_three_columns(lead: Dictionary, issue: Dictionary, picture: Dictionary) -> void:
	var side := int(width * 0.235)
	var middle := width - side * 2 - GUTTER * 2 - 2
	var row := _row(page, GUTTER)
	var left := _column(row, side, 8)
	_vrule(row)
	var centre := _column(row, middle, 6)
	_vrule(row)
	var right := _column(row, side, 8)
	if picture.is_empty():
		_text(centre, str(lead.get("body", "")), 19, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL, middle)
		_weather_desk(centre, issue, middle)
	else:
		_print_into(centre, picture, middle)
		_text(centre, str(picture.caption), 14, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER, middle)
		_text(right, str(lead.get("body", "")), 16, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL, side)
		_rule(right, 1)
	var columns: Array = issue.get("columns", [])
	for index in columns.size():
		var column: Dictionary = columns[index]
		var into := right if str(column.get("headline", "")).begins_with("The Listening Lady") or (picture.is_empty() and index > 0) else left
		_speaker_story(into, column, side)
		_rule(into, 1)
	if not picture.is_empty():
		_weather_desk(left, issue, side)


## The Listening Lady signs her own column with a drawing of herself at the door.
func _speaker_story(into: Control, column: Dictionary, column_width: int) -> void:
	var head := str(column.get("headline", ""))
	if head.begins_with("The Listening Lady"):
		var plate := catalog.lady_plate(date)
		if not plate.is_empty():
			_print_into(into, {"image": plate, "treatment": "ink"}, mini(column_width, 200))
	_text(into, head.to_upper(), 16, INK, OLD_BOLD, HORIZONTAL_ALIGNMENT_CENTER, column_width)
	_text(into, str(column.get("body", "")), 15, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL, column_width)


func record_front(meta: Dictionary, issue: Dictionary) -> void:
	var head := _row(page, 10)
	var ear := _boxed(head, 150)
	var block := catalog.weather_block(str(issue.get("ear", "")))
	if not block.is_empty():
		_print_into(ear, {"image": block, "treatment": "ink"}, 134)
	_text(ear, str(issue.get("ear", "")), 13, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER, 134)
	var plate := _column(head, 0, 0)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text(plate, str(meta.get("name", paper_id)), int(clampf(width / 13.5, 44.0, 76.0)), INK, BLACKLETTER, HORIZONTAL_ALIGNMENT_CENTER)
	_text(plate, str(meta.get("masthead_line", "")), 15, SOFT, ITALIC, HORIZONTAL_ALIGNMENT_CENTER)
	var price := _boxed(head, 120)
	_text(price, "%s\nEDITION" % str(meta.get("edition", "")).to_upper(), 14, INK, OLD_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 104)
	_text(price, str(meta.get("price", "")), 13, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER, 104)
	_rule(page, 3)
	var line := _row(page, 16)
	_text(line, "VOL. %s" % _roman(int(date.left(4)) - 1898), 13, INK, OLD)
	_text(line, catalog.long_date(date).to_upper(), 13, INK, OLD, HORIZONTAL_ALIGNMENT_CENTER)
	_text(line, str(meta.get("price", "")).to_upper(), 13, INK, OLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_rule(page, 1)
	var picture := catalog.front_picture(paper_id, date)
	var portrait := str(picture.get("form", "")) == "portrait"
	var grid := _row(page, GUTTER)
	var unit := int((width - GUTTER * 3 - 3) / 5.0)
	var lead_width := unit * 2 + GUTTER
	var lead_box := _column(grid, lead_width, 6)
	var lead: Dictionary = issue.get("lead", {})
	_text(lead_box, str(lead.get("headline", "")).to_upper(), 25, INK, OLD_BOLD, HORIZONTAL_ALIGNMENT_CENTER, lead_width)
	_rule(lead_box, 1)
	_text(lead_box, str(lead.get("deck", "")), 17, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER, lead_width)
	_rule(lead_box, 1)
	if portrait:
		_print_into(lead_box, picture, int(lead_width * 0.64))
		_text(lead_box, str(picture.caption), 13, INK, OLD_BOLD, HORIZONTAL_ALIGNMENT_CENTER, lead_width)
	var half := int((lead_width - GUTTER) / 2.0)
	var parts := _halves(str(lead.get("body", "")), SERIF, 15, half)
	var run := _row(lead_box, GUTTER)
	_text(run, parts[0], 15, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL, half)
	_text(run, parts[1], 15, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL, half)
	_vrule(grid)
	var rest_width := width - lead_width - GUTTER - 1
	var rest := _column(grid, rest_width, 8)
	var three := _row(rest, GUTTER)
	var columns: Array = issue.get("columns", [])
	var each := int((rest_width - GUTTER * 2 - 2) / 3.0)
	for index in columns.size():
		if index > 0:
			_vrule(three)
		var box := _column(three, each)
		_text(box, str(columns[index].get("headline", "")).to_upper(), 17, INK, OLD_BOLD, HORIZONTAL_ALIGNMENT_CENTER, each)
		_rule(box, 1)
		_text(box, str(columns[index].get("body", "")), 15, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL, each)
	_rule(rest, 1)
	if not picture.is_empty() and not portrait:
		_print_into(rest, picture, rest_width)
		_text(rest, str(picture.caption), 14, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER, rest_width)
		_rule(rest, 1)
	_weather_desk(rest, issue, rest_width)
	_issue_foot(issue, INK, false)


func _issue_foot(issue: Dictionary, accent: Color, chair_boxed: bool) -> void:
	var editorial: Dictionary = issue.get("editorial", {})
	if not editorial.is_empty() and chair_boxed:
		var chair: Dictionary = catalog.paper(paper_id).get("editorial", {})
		_rule(page, 2, accent)
		_text(page, str(chair.get("title", "Editorial")).to_upper(), 15, accent, OLD_BOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_text(page, str(editorial.get("headline", "")), 24, INK, FAT, HORIZONTAL_ALIGNMENT_CENTER)
		_text(page, str(editorial.get("body", "")), 16, INK, SERIF, HORIZONTAL_ALIGNMENT_FILL)
		_text(page, str(chair.get("byline", "")), 14, SOFT, ITALIC, HORIZONTAL_ALIGNMENT_RIGHT)
	_rule(page, 1)
	_text(page, str(issue.get("wire", "")), 14, SOFT, ITALIC)
	for notice: Dictionary in catalog.sky_notices(date):
		_text(page, str(notice.get("headline", "")).to_upper(), 14, INK, OLD_BOLD)
		_text(page, str(notice.get(paper_id, "")), 14, INK)
	_text(page, "ESC closes the paper", 12, SOFT, ITALIC, HORIZONTAL_ALIGNMENT_RIGHT)


func _weather_desk(into: Control, issue: Dictionary, column_width: int) -> void:
	var weather: Dictionary = issue.get("weather_report", {})
	if weather.is_empty():
		return
	_text(into, "WEATHER DESK / %s E.S.T." % CampaignWeather.print_time(str(weather.get("issued_at", ""))), 13, INK, OLD_BOLD, HORIZONTAL_ALIGNMENT_LEFT, column_width)
	_text(into, str(weather.get("observation", "")), 14, SOFT, ITALIC, HORIZONTAL_ALIGNMENT_LEFT, column_width)
	_text(into, "%s %s" % [weather.get("prediction", ""), weather.get("outlook", "")], 15, INK, SERIF, HORIZONTAL_ALIGNMENT_LEFT, column_width)
	_text(into, "Outlook: %s. Valid %s to %s E.S.T." % [weather.get("confidence", ""),
			CampaignWeather.print_time(str(weather.get("valid_from", ""))),
			CampaignWeather.print_time(str(weather.get("valid_until", "")))], 12, SOFT, ITALIC, HORIZONTAL_ALIGNMENT_LEFT, column_width)
	if str(weather.get("revision", "")) != "":
		_text(into, str(weather.revision), 14, SOFT, ITALIC, HORIZONTAL_ALIGNMENT_LEFT, column_width)
	for dispatch: Dictionary in weather.get("timeline", []):
		if str(dispatch.get("issued_at", "")) == str(weather.get("issued_at", "")):
			continue
		_text(into, "Previous dispatch, %s E.S.T.: %s" % [CampaignWeather.print_time(str(dispatch.get("issued_at", ""))),
				dispatch.get("prediction", "")], 12, SOFT, ITALIC, HORIZONTAL_ALIGNMENT_LEFT, column_width)


## --- the back of the sheet ---------------------------------------------------

## The Speaker's weekly melodrama: three posed stills and a line under each.
func photo_drama(drama: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.name = "PhotoDrama"
	box.add_theme_constant_override("separation", 6)
	page.add_child(box)
	_banner(box, "THE SPEAKER'S PHOTO DRAMA FROM LIFE", FAT, 34, 1, RED)
	_text(box, "%s. %s" % [drama.title, drama.byline], 17, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER)
	var stills: Array = drama.stills
	var each := int((width - GUTTER * (stills.size() - 1)) / float(stills.size()))
	var strip := _row(box, GUTTER)
	for still: Dictionary in stills:
		var frame := _column(strip, each, 4)
		_print_into(frame, {"image": still.image, "treatment": "halftone"}, each)
		_text(frame, str(still.caption), 16, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER, each)
	_text(box, str(drama.next), 13, SOFT, ITALIC, HORIZONTAL_ALIGNMENT_RIGHT)
	_rule(page, 2)


## A line cut with its caption, on the back above the columns.
func feature(cut: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.name = "Feature"
	box.add_theme_constant_override("separation", 4)
	page.add_child(box)
	var wide := int(width * 0.5)
	_print_into(box, cut, wide)
	_text(box, str(cut.caption), 15, INK, ITALIC, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(page, 1)


## A woodcut band between the running head and the columns.
func band(image: String) -> void:
	var cut := _print_into(page, {"image": image, "treatment": "ink"}, width)
	cut.name = "Band"


## --- the Sunday Brown Section ------------------------------------------------

## Pictures and captions, brown ink on cream. One big and a tall one on top, the
## other two beneath them, cut to the height of the row.
func brown_section(meta: Dictionary, section: Dictionary) -> void:
	_text(page, str(meta.get("name", paper_id)).to_upper(), 40, BROWN, FAT, HORIZONTAL_ALIGNMENT_CENTER)
	_text(page, "Sunday Picture Section. %s" % catalog.long_date(date), 16, BROWN, ITALIC, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(page, 2, BROWN)
	var box := VBoxContainer.new()
	box.name = "BrownSection"
	box.add_theme_constant_override("separation", 8)
	page.add_child(box)
	var pictures: Array = section.pictures
	var first_width := int((width - 18) * 0.66)
	var second_width := width - 18 - first_width
	var top := _row(box, 18)
	_gravure(top, pictures[0], first_width)
	_gravure(top, pictures[1], second_width)
	var low := _row(box, 18)
	var third_width := int((width - 18) * 0.5)
	_gravure(low, pictures[2], third_width)
	_gravure(low, pictures[3], width - 18 - third_width)
	_text(page, "ESC closes the paper", 12, BROWN, ITALIC, HORIZONTAL_ALIGNMENT_RIGHT)


func _gravure(into: Control, picture: Dictionary, column_width: int) -> void:
	var box := _column(into, column_width, 4)
	_print_into(box, {"image": picture.image, "treatment": "gravure"}, column_width)
	_text(box, str(picture.caption), 15, BROWN, ITALIC, HORIZONTAL_ALIGNMENT_LEFT, column_width)


## --- pieces -------------------------------------------------------------------

func _print_into(into: Control, picture: Dictionary, shown_width: int, ink := INK) -> TextureRect:
	var texture: Texture2D = load(str(picture.image))
	var cut := TextureRect.new()
	cut.texture = texture
	cut.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cut.stretch_mode = TextureRect.STRETCH_SCALE
	var shown := Vector2(shown_width, roundf(shown_width * float(texture.get_height()) / texture.get_width()))
	cut.custom_minimum_size = shown
	cut.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cut.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink_of := BROWN if str(picture.treatment) == "gravure" else ink
	var look := ShaderMaterial.new()
	look.shader = PRINT_SHADER
	look.set_shader_parameter("mode", {"halftone": 0, "gravure": 1}.get(str(picture.treatment), 2))
	look.set_shader_parameter("ink_color", ink_of)
	look.set_shader_parameter("paper_color", CREAM)
	look.set_shader_parameter("rect_size", shown)
	look.set_shader_parameter("oval", str(picture.get("form", "")) == "portrait")
	cut.material = look
	into.add_child(cut)
	return cut


func _text(into: Control, text: String, size: int, color := INK, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_LEFT, fixed_width := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if fixed_width > 0:
		label.custom_minimum_size.x = fixed_width
	else:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", font if font != null else SERIF)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(label)
	return label


## A headline set as large as will go in the lines allowed.
func _banner(into: Control, text: String, font: Font, largest: int, lines: int, color := INK) -> void:
	var size := largest
	while size > 20:
		var measure := TextParagraph.new()
		measure.width = width
		measure.add_string(text, font, size)
		if measure.get_line_count() <= lines:
			break
		size -= 2
	_text(into, text, size, color, font, HORIZONTAL_ALIGNMENT_CENTER)


## A run of text cut by the line into two equal columns.
func _halves(text: String, font: Font, size: int, column_width: int) -> Array[String]:
	var measure := TextParagraph.new()
	measure.width = column_width
	measure.add_string(text, font, size)
	var count := measure.get_line_count()
	if count < 2:
		return [text, ""]
	var cut := measure.get_line_range(ceili(count / 2.0) - 1).y
	return [text.substr(0, cut).strip_edges(), text.substr(cut).strip_edges()]


func _rule(into: Control, height: int, color := INK) -> void:
	var rule := ColorRect.new()
	rule.color = color
	rule.custom_minimum_size = Vector2(0, height)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(rule)


func _vrule(into: Control) -> void:
	var rule := ColorRect.new()
	rule.color = SOFT
	rule.custom_minimum_size = Vector2(1, 0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(rule)


func _row(into: Control, gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	into.add_child(row)
	return row


func _column(into: Control, column_width := 0, gap := 6) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	if column_width > 0:
		column.custom_minimum_size.x = column_width
	else:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	into.add_child(column)
	return column


func _boxed(into: Control, box_width: int) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = INK
	style.set_border_width_all(2)
	style.set_content_margin_all(7)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = box_width
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	into.add_child(panel)
	return _column(panel, 0, 3)


static func _roman(number: int) -> String:
	var out := ""
	for pair: Array in [[50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while number >= pair[0]:
			out += pair[1]
			number -= pair[0]
	return out
