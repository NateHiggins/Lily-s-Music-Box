class_name TelegramStyle
extends RefCounted
## One material and typographic grammar for service information. Gameplay
## systems supply facts; this class supplies only paper, ink and hierarchy.

const PAPER: Texture2D = preload(
		"res://assets/ui/telegram/telegram_paper_stock_v1.png")
const BODY_FONT: Font = preload(
		"res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const BOLD_FONT: Font = preload(
		"res://assets/fonts/courier_prime/CourierPrime-Bold.ttf")

const PAPER_IVORY := Color("e8d6ad")
const CARBON := Color("211c18")
const CARBON_SOFT := Color("4e463b")
const SERVICE_TEAL := Color("477f78")
const ORDER_AMBER := Color("a95f24")
const OLD_RED := Color("813a31")


## Fit an authored heading onto a narrow physical slip WITHOUT stopping
## mid-word or on punctuation. A hard `.left(16)` turned
## "WORK ORDER 001 — THE CHIRP" into "WORK ORDER 001 —", which trails off
## on a dangling em-dash and reads as a rendering fault rather than as a
## short strip of paper. Truncation is right — the slip really is that
## narrow — but a slip stops at a word, so this backs up to the last
## boundary and drops any separator left hanging at the end.
##
## The owner ruled 2026-08-16: trim to the word boundary rather than
## reducing the slip to its work-order number, because the number alone
## loses the one thing the player is scanning the slip for.
const SLIP_SEPARATORS := "-–—/:;,.·|"


static func fit_slip(text: String, limit := 16) -> String:
	var clean := text.strip_edges()
	if clean.length() <= limit:
		return _trim_separator(clean)
	var cut := clean.substr(0, limit)
	var space := cut.rfind(" ")
	# No boundary at all inside the limit means one long word: a hard cut
	# is then the only honest option, and it does not dangle a separator.
	if space > 0:
		cut = cut.substr(0, space)
	return _trim_separator(cut)


static func _trim_separator(text: String) -> String:
	var out := text.strip_edges()
	while out.length() > 0 and SLIP_SEPARATORS.contains(out.right(1)):
		out = out.substr(0, out.length() - 1).strip_edges()
	return out


static func paper_panel(alpha := 1.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PAPER
	style.texture_margin_left = 16.0
	style.texture_margin_top = 16.0
	style.texture_margin_right = 16.0
	style.texture_margin_bottom = 16.0
	style.content_margin_left = 22.0
	style.content_margin_top = 18.0
	style.content_margin_right = 22.0
	style.content_margin_bottom = 18.0
	style.modulate_color = Color(1.0, 1.0, 1.0, alpha)
	return style


static func ink_tag() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.052, 0.043, 0.90)
	style.border_color = Color(0.54, 0.45, 0.29, 0.82)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 13.0
	style.content_margin_top = 7.0
	style.content_margin_right = 13.0
	style.content_margin_bottom = 7.0
	return style


static func stamp_tag() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.27, 0.48, 0.45, 0.10)
	style.border_color = Color(0.27, 0.48, 0.45, 0.88)
	style.set_border_width_all(2)
	style.content_margin_left = 7.0
	style.content_margin_top = 3.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 3.0
	return style


static func apply(label: Label, size: int, bold := false,
		color := CARBON) -> void:
	label.add_theme_font_override("font", BOLD_FONT if bold else BODY_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.18, 0.12,
			0.07, 0.12))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


static func apply_world(label: Label3D, bold := false) -> void:
	label.font = BOLD_FONT if bold else BODY_FONT
