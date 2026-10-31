class_name NewspaperAd
extends RefCounted
## Sets one advertisement in its period style. Copy, firm identity and contact
## lines are data; every word is live text, and the only pictures are ink cuts.

const INK := Color(0.11, 0.098, 0.086)
const PAPER := Color(0.91, 0.88, 0.80)
const COUPON_NODE := "Coupon"
const STYLES := ["bill", "card", "coupon", "notice", "testimonial", "deco", "reason", "trade", "black", "typed", "banner"]
const FACE := {
	"caslon": preload("res://assets/fonts/librecaslontext/LibreCaslonText[wght].ttf"),
	"bodoni": preload("res://assets/fonts/librebodoni/LibreBodoni[wght].ttf"),
	"bodoni_italic": preload("res://assets/fonts/librebodoni/LibreBodoni-Italic[wght].ttf"),
	"old": preload("res://assets/fonts/oldstandardtt/OldStandard-Regular.ttf"),
	"old_bold": preload("res://assets/fonts/oldstandardtt/OldStandard-Bold.ttf"),
	"old_italic": preload("res://assets/fonts/oldstandardtt/OldStandard-Italic.ttf"),
	"goudy": preload("res://assets/fonts/goudybookletter1911/GoudyBookletter1911.ttf"),
	"jost": preload("res://assets/fonts/jost/Jost[wght].ttf"),
	"deco": preload("res://assets/fonts/limelight/Limelight-Regular.ttf"),
	"fat": preload("res://assets/fonts/abrilfatface/AbrilFatface-Regular.ttf"),
	"script": preload("res://assets/fonts/pinyonscript/PinyonScript-Regular.ttf"),
	"black": preload("res://assets/fonts/unifrakturcook/UnifrakturCook-Bold.ttf"),
	"typed": preload("res://assets/fonts/specialelite/SpecialElite-Regular.ttf"),
}


## Builds the advertisement. `firm` is its entry in the advertising book.
static func has_style(style: String) -> bool:
	return style in STYLES


static func build(ad: Dictionary, firm: Dictionary) -> Control:
	var setter := NewspaperAd.new()
	setter._ad = ad
	setter._firm = firm
	return setter.call("_set_%s" % str(ad.style))


var _ad: Dictionary
var _firm: Dictionary


# --- the styles ----------------------------------------------------------------

## A store bill: big head, a priced list with leaders, the name large at the foot.
func _set_bill() -> Control:
	var box := _frame(_ornament_border())
	_text(box, str(_ad.headline), "old_bold", 21, HORIZONTAL_ALIGNMENT_CENTER)
	_cut(box)
	_text(box, str(_ad.body), "old", 14, HORIZONTAL_ALIGNMENT_LEFT)
	_price_list(box)
	_slogan(box)
	_signature(box, "bodoni", 25)
	return box.get_parent().get_parent()


## A card: a line in engraver's script, rules round the name, telephone and street.
func _set_card() -> Control:
	var box := _frame(_rule_border(2))
	_text(box, str(_ad.headline), "script", 30, HORIZONTAL_ALIGNMENT_LEFT)
	_cut(box)
	_text(box, str(_ad.body), "goudy", 15, HORIZONTAL_ALIGNMENT_LEFT)
	_spring(box)
	_rule(box, 2)
	_text(box, str(_firm.name), "caslon", 21, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(box, 1)
	_text(box, str(_firm.id_line), "goudy", 12, HORIZONTAL_ALIGNMENT_CENTER)
	var line := HBoxContainer.new()
	box.add_child(line)
	_text(line, str(_firm.telephone), "old_italic", 14, HORIZONTAL_ALIGNMENT_LEFT, true)
	_text(line, str(_firm.address), "old_italic", 14, HORIZONTAL_ALIGNMENT_RIGHT, true)
	return box.get_parent().get_parent()


## Mail order: a picture, a shouted offer, and a coupon to cut out along the dashes.
func _set_coupon() -> Control:
	var box := _frame(_rule_border(1))
	_text(box, str(_ad.headline).to_upper(), "fat", 22, HORIZONTAL_ALIGNMENT_CENTER)
	_cut(box)
	_text(box, str(_ad.body), "old", 14, HORIZONTAL_ALIGNMENT_LEFT)
	if _ad.has("offer"):
		_text(box, str(_ad.offer).to_upper(), "old_bold", 15, HORIZONTAL_ALIGNMENT_CENTER)
	_spring(box)
	var coupon := PanelContainer.new()
	coupon.name = COUPON_NODE
	coupon.add_theme_stylebox_override("panel", _dashed())
	box.add_child(coupon)
	# An order's coupon can be torn off once; after that this copy has a hole too.
	if _ad.has("order"):
		coupon.set_meta("order", str(_ad.order))
		coupon.visible = not MailOrders.torn(str(_ad.order))
	var slip := VBoxContainer.new()
	slip.add_theme_constant_override("separation", 3)
	coupon.add_child(slip)
	_text(slip, str(_firm.name), "old_bold", 14, HORIZONTAL_ALIGNMENT_LEFT)
	_text(slip, "%s.  %s" % [str(_firm.address), _telephone_line()], "old", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_text(slip, str(_firm.id_line), "old_italic", 12, HORIZONTAL_ALIGNMENT_LEFT)
	_text(slip, "Name ______________________", "typed", 12, HORIZONTAL_ALIGNMENT_LEFT)
	_text(slip, "Address ___________________", "typed", 12, HORIZONTAL_ALIGNMENT_LEFT)
	return box.get_parent().get_parent()


## A public notice: heavy rule, plain statement, signed by the corporation.
func _set_notice() -> Control:
	var box := _frame(_rule_border(4))
	_text(box, "NOTICE", "bodoni", 13, HORIZONTAL_ALIGNMENT_CENTER)
	_text(box, str(_ad.headline).to_upper(), "bodoni", 20, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(box, 1)
	_cut(box)
	_text(box, str(_ad.body), "caslon", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_spring(box)
	_rule(box, 1)
	_mark_line(box, "bodoni", 15)
	_text(box, "%s.  Tel. %s" % [str(_firm.address), str(_firm.telephone)], "caslon", 12, HORIZONTAL_ALIGNMENT_CENTER)
	return box.get_parent().get_parent()


## A testimonial: the figure over the customer's own words, signed and placed.
func _set_testimonial() -> Control:
	var box := _frame(_ornament_border())
	_text(box, "“%s”" % str(_ad.headline), "bodoni_italic", 20, HORIZONTAL_ALIGNMENT_CENTER)
	_cut(box)
	_text(box, str(_ad.body), "bodoni_italic", 14, HORIZONTAL_ALIGNMENT_LEFT)
	_text(box, "—%s" % str(_ad.signed), "old", 13, HORIZONTAL_ALIGNMENT_RIGHT)
	_spring(box)
	_rule(box, 1)
	_mark_line(box, "old_bold", 16)
	_contact_lines(box, "old", 12)
	return box.get_parent().get_parent()


## Moderne: a black band reversed out, a sans-serif text, the name letterspaced.
func _set_deco() -> Control:
	var box := _frame(_rule_border(1))
	var band := PanelContainer.new()
	var ink := StyleBoxFlat.new()
	ink.bg_color = INK
	ink.set_content_margin_all(8)
	band.add_theme_stylebox_override("panel", ink)
	box.add_child(band)
	var head := _text(band, str(_ad.headline), "deco", 21, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_theme_color_override("font_color", PAPER)
	_cut(box)
	_text(box, str(_ad.body), "jost", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_spring(box)
	_stripes(box)
	var spaced := FontVariation.new()
	spaced.base_font = FACE["jost"]
	spaced.spacing_glyph = 5
	spaced.spacing_space = 8
	_text(box, str(_firm.name).to_upper(), "jost", 12, HORIZONTAL_ALIGNMENT_CENTER) 			.add_theme_font_override("font", spaced)
	_contact_lines(box, "jost", 11)
	return box.get_parent().get_parent()


## Reason-why: a fat question, a long sober argument, the price, and the mark.
func _set_reason() -> Control:
	var box := _frame(_rule_border(2))
	_text(box, str(_ad.headline), "fat", 23, HORIZONTAL_ALIGNMENT_LEFT)
	_cut(box)
	_text(box, str(_ad.body), "old", 14, HORIZONTAL_ALIGNMENT_LEFT)
	if _ad.has("offer"):
		_text(box, str(_ad.offer), "fat", 16, HORIZONTAL_ALIGNMENT_CENTER)
	_spring(box)
	_slogan(box)
	_mark_line(box, "old_bold", 17)
	_contact_lines(box, "old", 12)
	return box.get_parent().get_parent()


## A tradesman's card: small, centred, the mark above and the telephone below.
func _set_trade() -> Control:
	var box := _frame(_rule_border(1))
	_mark(box, true)
	_cut(box)
	_text(box, str(_firm.name), "goudy", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_text(box, str(_firm.id_line), "goudy", 11, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(box, 1)
	_text(box, str(_ad.headline), "old_bold", 15, HORIZONTAL_ALIGNMENT_CENTER)
	_text(box, str(_ad.body), "goudy", 13, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(box, 1)
	_contact_lines(box, "goudy", 12)
	return box.get_parent().get_parent()


## The dignified notice: a mourning rule and a blackletter name.
func _set_black() -> Control:
	var box := _frame(_rule_border(6))
	_text(box, str(_firm.name), "black", 26, HORIZONTAL_ALIGNMENT_CENTER)
	_text(box, str(_firm.id_line), "caslon", 11, HORIZONTAL_ALIGNMENT_CENTER)
	_rule(box, 1)
	_cut(box)
	_text(box, str(_ad.headline), "bodoni_italic", 18, HORIZONTAL_ALIGNMENT_CENTER)
	_text(box, str(_ad.body), "caslon", 13, HORIZONTAL_ALIGNMENT_CENTER)
	_spring(box)
	_contact_lines(box, "caslon", 12)
	return box.get_parent().get_parent()


## A typed letter from the firm, reproduced as a line block.
func _set_typed() -> Control:
	var box := _frame(_rule_border(1))
	_text(box, str(_ad.headline), "typed", 16, HORIZONTAL_ALIGNMENT_LEFT)
	_cut(box)
	_text(box, "Dear Sir:", "typed", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_text(box, str(_ad.body), "typed", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_spring(box)
	_text(box, "Yours truly,", "typed", 13, HORIZONTAL_ALIGNMENT_LEFT)
	_text(box, str(_firm.name), "script", 24, HORIZONTAL_ALIGNMENT_LEFT)
	_text(box, str(_firm.id_line), "typed", 11, HORIZONTAL_ALIGNMENT_LEFT)
	_contact_lines(box, "typed", 11, HORIZONTAL_ALIGNMENT_LEFT)
	return box.get_parent().get_parent()


## The full-width banner: picture, argument, and the firm's own panel.
func _set_banner() -> Control:
	var box := _frame(_ornament_border())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	var picture := _cut(row)
	if picture:
		picture.custom_minimum_size = Vector2(300, 174)
		picture.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_text(words, str(_ad.headline), "fat", 30, HORIZONTAL_ALIGNMENT_LEFT)
	_text(words, str(_ad.body), "old", 15, HORIZONTAL_ALIGNMENT_LEFT)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(230, 0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(card)
	_mark(card, true)
	_text(card, str(_firm.name), "bodoni", 19, HORIZONTAL_ALIGNMENT_CENTER)
	_text(card, str(_firm.id_line), "old_italic", 12, HORIZONTAL_ALIGNMENT_CENTER)
	_contact_lines(card, "old", 13)
	return box.get_parent().get_parent()


# --- the parts -----------------------------------------------------------------

## Returns the column to set into; the caller returns its frame.
func _frame(border: StyleBox) -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.name = "Ad"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", border)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 4)
	frame.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	return box


func _rule_border(width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = INK
	style.set_border_width_all(width)
	style.set_content_margin_all(6 + width)
	return style


## A woven printer's border: a double rule with an ink pattern tiled between.
func _ornament_border() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/ui/newspaper/ad_border.png")
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_texture_margin(side, 12)
		style.set_content_margin(side, 16)
	style.draw_center = false
	return style


func _dashed() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = INK
	style.set_border_width_all(1)
	style.set_content_margin_all(7)
	return style


func _text(into: Control, text: String, face: String, size: int, align: HorizontalAlignment,
		fill := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = align
	label.add_theme_font_override("font", FACE[face])
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	label.add_theme_constant_override("line_spacing", -1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if fill or align != HORIZONTAL_ALIGNMENT_LEFT else Control.SIZE_FILL
	into.add_child(label)
	return label


func _cut(into: Control) -> TextureRect:
	if str(_ad.get("image", "")) == "":
		return null
	var cut := TextureRect.new()
	cut.name = "Cut"
	cut.texture = load(str(_ad.image))
	cut.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cut.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cut.custom_minimum_size = Vector2(0, 250 if str(_ad.size) == "T" else 190)
	# A tall slot is sized by its neighbours; the picture takes up the slack.
	if str(_ad.size) == "T":
		cut.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cut.size_flags_stretch_ratio = 8.0
	into.add_child(cut)
	return cut


func _rule(into: Control, height: int) -> void:
	var rule := ColorRect.new()
	rule.color = INK
	rule.custom_minimum_size = Vector2(0, height)
	into.add_child(rule)


func _stripes(into: Control) -> void:
	for height in [3, 2, 1]:
		_rule(into, height)


func _spring(into: Control) -> void:
	var spring := Control.new()
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	into.add_child(spring)


func _slogan(into: Control) -> void:
	if str(_firm.slogan) != "":
		_text(into, "“%s”" % str(_firm.slogan).to_upper(), "old", 11, HORIZONTAL_ALIGNMENT_CENTER)


func _price_list(into: Control) -> void:
	for item: Array in _ad.get("items", []):
		var row := HBoxContainer.new()
		into.add_child(row)
		_text(row, str(item[0]), "old", 14, HORIZONTAL_ALIGNMENT_LEFT, true)
		if str(item[1]) != "":
			_text(row, str(item[1]), "fat", 17, HORIZONTAL_ALIGNMENT_RIGHT)


## The name large at the foot, then the identity and the address, as a store signs.
func _signature(into: Control, face: String, size: int) -> void:
	_rule(into, 2)
	_mark_line(into, face, size)
	_contact_lines(into, "old", 12)


func _mark_line(into: Control, face: String, size: int) -> void:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 8)
	into.add_child(line)
	_mark(line, false)
	var name_label := _text(line, str(_firm.name), face, size, HORIZONTAL_ALIGNMENT_CENTER, true)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _contact_lines(into: Control, face: String, size: int, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if not (str(_ad.style) in ["trade", "black", "typed", "banner", "deco"]):
		_text(into, str(_firm.id_line), face, size - 1, align)
	_text(into, str(_firm.address), face, size, align)
	var call_line := _telephone_line()
	if str(_firm.hours) != "":
		call_line += ".  %s" % str(_firm.hours)
	_text(into, call_line, face, size, align)


func _telephone_line() -> String:
	var line := str(_firm.telephone)
	return "Tel. %s" % line if line.split(" ")[-1].is_valid_int() else line


## The firm's mark: its initials in a ruled device, as a registered mark would run.
func _mark(into: Control, large: bool) -> void:
	if str(_firm.mark) == "":
		return
	var side := 46 if large else 34
	var mark := NewspaperAdMark.new()
	mark.name = "Mark"
	mark.initials = str(_firm.mark)
	mark.shape = str(_firm.mark_shape)
	mark.custom_minimum_size = Vector2(side, side)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	into.add_child(mark)
