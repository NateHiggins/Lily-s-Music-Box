class_name OrisonTitleScreen
extends Control
## The menu is an object in the Orison: the building's original sales pitch,
## still hanging where optimism curdled. UI stays separate from the artwork
## so every word remains readable at any resolution.

const ART := preload("res://assets/ui/title/orison_original_advert_lobby_v1.png")

var _art: TextureRect
var _shade: ColorRect
var _chain: Line2D
var _hand_sheen: ColorRect
var _settings_panel: PanelContainer
var _quality: OptionButton
var _fullscreen: CheckBox
var _volume: HSlider
var _elapsed := 0.0
var _next_knock := 8.0
var _knock_left := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_backdrop()
	_build_menu()
	_build_settings()
	get_viewport().size_changed.connect(_place_uncanny_evidence)
	_place_uncanny_evidence()


func _build_backdrop() -> void:
	_art = TextureRect.new()
	_art.texture = ART
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.005, 0.008, 0.012, 0.12)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

	# A line laid over the photographed pull-chain can disobey gravity by a
	# few pixels. It is deliberately easy to dismiss as parallax.
	_chain = Line2D.new()
	_chain.width = 1.5
	_chain.default_color = Color(0.55, 0.37, 0.16, 0.68)
	add_child(_chain)
	_hand_sheen = ColorRect.new()
	_hand_sheen.color = Color(0.20, 0.13, 0.08, 0.0)
	_hand_sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_sheen)


func _build_menu() -> void:
	var safe := MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 64)
	safe.add_theme_constant_override("margin_top", 58)
	safe.add_theme_constant_override("margin_right", 72)
	safe.add_theme_constant_override("margin_bottom", 54)
	add_child(safe)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	safe.add_child(row)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size = Vector2(380, 0)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 12)
	row.add_child(menu)

	var eyebrow := Label.new()
	eyebrow.text = "AN ORISON PROPERTY  ·  EST. 1926"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.modulate = Color(0.60, 0.57, 0.48)
	menu.add_child(eyebrow)
	var title := Label.new()
	title.text = "REALTY\nMAINTENANCE"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.86, 0.80, 0.66))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	menu.add_child(title)
	var correction := Label.new()
	correction.text = "          I"
	correction.add_theme_font_size_override("font_size", 30)
	correction.add_theme_color_override("font_color", Color(0.60, 0.08, 0.055))
	correction.rotation = -0.09
	correction.position.y = -75
	correction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(correction)
	var shift := Label.new()
	shift.text = "THE ORISON  /  NIGHT SHIFT"
	shift.add_theme_font_size_override("font_size", 15)
	shift.modulate = Color(0.55, 0.63, 0.67)
	menu.add_child(shift)
	menu.add_child(HSeparator.new())
	_add_button(menu, "NEW GAME", _new_game)
	_add_button(menu, "DEBUG MODE", _debug_game)
	_add_button(menu, "SETTINGS", func(): _settings_panel.visible = true)
	var foot := Label.new()
	foot.text = "COME SEE THE ORISON.\nIT'S THE BEGINNING OF THE FUTURE, TODAY."
	foot.add_theme_font_size_override("font_size", 11)
	foot.modulate = Color(0.42, 0.39, 0.34)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(foot)


func _add_button(parent: Control, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.78, 0.75, 0.67))
	button.add_theme_color_override("font_hover_color", Color(0.95, 0.78, 0.43))
	button.pressed.connect(callback)
	parent.add_child(button)


func _build_settings() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-230, -175)
	_settings_panel.custom_minimum_size = Vector2(460, 350)
	_settings_panel.visible = false
	add_child(_settings_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_settings_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var heading := Label.new(); heading.text = "BUILDING SERVICES"
	heading.add_theme_font_size_override("font_size", 24); box.add_child(heading)
	var qlabel := Label.new(); qlabel.text = "LIGHT AND SHADOW QUALITY"; box.add_child(qlabel)
	_quality = OptionButton.new()
	_quality.add_item("Cinematic — maximum (default)", 0)
	_quality.add_item("Balanced — debug-tested", 1)
	_quality.select(int(GameBoot.settings.get("quality", 0)))
	box.add_child(_quality)
	_fullscreen = CheckBox.new(); _fullscreen.text = "EXCLUSIVE FULLSCREEN"
	_fullscreen.button_pressed = bool(GameBoot.settings.get("fullscreen", false))
	box.add_child(_fullscreen)
	var vlabel := Label.new(); vlabel.text = "MASTER VOLUME"; box.add_child(vlabel)
	_volume = HSlider.new(); _volume.min_value = 0.0; _volume.max_value = 1.0
	_volume.step = 0.01; _volume.value = float(GameBoot.settings.get("master_volume", 0.82))
	box.add_child(_volume)
	_add_button(box, "APPLY", _save_settings)
	_add_button(box, "BACK", func(): _settings_panel.visible = false)


func _new_game() -> void:
	GameBoot.begin_game(GameBoot.LaunchMode.CINEMATIC, true)


func _debug_game() -> void:
	GameBoot.begin_game(GameBoot.LaunchMode.DEBUG, false)


func _save_settings() -> void:
	GameBoot.settings.quality = _quality.selected
	GameBoot.settings.fullscreen = _fullscreen.button_pressed
	GameBoot.settings.master_volume = _volume.value
	GameBoot.save_settings()
	_settings_panel.visible = false


func _place_uncanny_evidence() -> void:
	var size := get_viewport_rect().size
	# Coordinates follow the source composition closely enough across cover
	# crops that the additions feel embedded, not like screen-space effects.
	var scale := size.y / 941.0
	var x_crop := (1672.0 * scale - size.x) * 0.5
	var chain_top := Vector2(1044.0 * scale - x_crop, 80.0 * scale)
	_chain.points = PackedVector2Array([chain_top,
		Vector2(1044.0 * scale - x_crop, 465.0 * scale)])
	_hand_sheen.position = Vector2(990.0 * scale - x_crop, 465.0 * scale)
	_hand_sheen.size = Vector2(115, 155) * scale


func _process(delta: float) -> void:
	_elapsed += delta
	_next_knock -= delta
	if _next_knock <= 0.0:
		_knock_left = 0.15
		_next_knock = 7.0 + fmod(_elapsed * 3.73, 9.0)
	_knock_left = maxf(0.0, _knock_left - delta)
	# The chandelier does not flicker rhythmically; one dirty contact coughs.
	_shade.color.a = 0.19 if _knock_left > 0.08 else (0.08 if _knock_left > 0.0 else 0.12)
	var drift := sin(_elapsed * 0.37) * 8.0 + sin(_elapsed * 0.11) * 4.0
	if _chain.points.size() == 2:
		var points := _chain.points
		points[1].x = points[0].x + drift
		_chain.points = points
	# It takes long enough to emerge that most players will doubt the change.
	_hand_sheen.color.a = clampf((sin(_elapsed * 0.085 - 1.2) + 0.25) * 0.07, 0.0, 0.075)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_panel.visible:
		_settings_panel.visible = false
