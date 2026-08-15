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
