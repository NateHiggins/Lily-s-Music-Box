class_name OrisonTitleScreen
extends Control

const AccessibilityCopyText := preload("res://scripts/ui/accessibility_copy.gd")
## The waking world is allowed grandeur; the dream remains the reveal. One
## rain-soaked hero joins the Orison, STREET and Vantry Arcade through mundane
## work. The untouched waltz opens; its returned reconstruction is the second
## record. Neither is excerpted or looped.

const HERO_ART := preload(
		"res://assets/ui/title/orison_grand_mundane_title_v1.png")
const RETURNED_THEME := preload(
		"res://assets/audio/music/title/clockwork_waltz_escapement_failure.ogg")
const ORIGINAL_THEME := preload(
		"res://assets/audio/music/title/clockwork_waltz_original.ogg")

const TRACK_RETURNED := 0
const TRACK_ORIGINAL := 1
const TRACK_TRIM_DB := [-8.0, -6.5]

var _tracks: Array[AudioStream] = [RETURNED_THEME, ORIGINAL_THEME]
var _track_names := [
	"ESCAPEMENT FAILURE",
	"THE CLOCKWORK WALTZ",
]
var _track_notes := [
	"RETURNED TOO FAST  ·  ×1.414",
	"ORIGINAL SESSION  ·  1928",
]

var _hero_art: TextureRect
var _shade: TextureRect
var _settings_panel: PanelContainer
var _first_menu_button: Button
var _services_button: Button
var _quality: OptionButton
var _fullscreen: CheckBox
var _always_warn: CheckBox
var _sound_captions: CheckBox
var _live_local_weather: CheckBox
var _weather_network_enabled: CheckBox
var _weather_location: LineEdit
var _volume: HSlider
var _gameplay_volume: HSlider
var _voice_volume: HSlider
var _world_volume: HSlider
var _music_volume: HSlider
var _ui_volume: HSlider
var _controller_look_sensitivity: HSlider
var _controller_look_deadzone: HSlider
var _controller_look_curve: HSlider
var _controller_invert_y: CheckBox
var _record_label: Label
var _record_note: Label
var _record_time: Label
var _record_progress: ProgressBar
var _record_button: Button
var _players: Array[AudioStreamPlayer] = []
var _music_fade: Tween
var _elapsed := 0.0
var _contact_left := 0.0
var _next_contact := 9.0
var _current_track := TRACK_ORIGINAL
var _leaving := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_backdrop()
	_build_menu()
	_build_settings()
	_build_music()
	_first_menu_button.grab_focus()
	get_viewport().size_changed.connect(_place_backdrop)
	_place_backdrop()


func _build_backdrop() -> void:
	_hero_art = _art_layer("GrandMundaneWakingWorld", HERO_ART)
	add_child(_hero_art)

	# A horizontal falloff protects the menu without flattening the wet street
	# and illuminated arcade beneath it.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.005, 0.008, 0.012, 0.10),
		Color(0.005, 0.008, 0.012, 0.25),
		Color(0.005, 0.008, 0.012, 0.88),
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 1024
	gradient_texture.height = 4
	gradient_texture.fill_from = Vector2(0.0, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	_shade = TextureRect.new()
	_shade.name = "MenuFalloff"
	_shade.texture = gradient_texture
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

func _art_layer(label: String, texture: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.name = label
	art.texture = texture
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _build_menu() -> void:
	var safe := MarginContainer.new()
	safe.name = "TitleSafeArea"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 54)
	safe.add_theme_constant_override("margin_top", 42)
	safe.add_theme_constant_override("margin_right", 54)
	safe.add_theme_constant_override("margin_bottom", 42)
	add_child(safe)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	safe.add_child(row)

	var panel := PanelContainer.new()
	panel.name = "TitleCard"
	panel.custom_minimum_size = Vector2(430, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.022, 0.028, 0.70)
	panel_style.border_width_left = 1
	panel_style.border_color = Color(0.48, 0.36, 0.19, 0.58)
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", panel_style)
	row.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 9)
	margin.add_child(menu)

	var eyebrow := _label("THE ORISON  ·  NIGHT SERVICE  ·  3:00 A.M.", 12,
			Color(0.59, 0.58, 0.53))
	eyebrow.name = "Eyebrow"
	menu.add_child(eyebrow)
	var title := _label("PLEASE\nREMAIN ON\nTHE LINE", 46,
			Color(0.90, 0.84, 0.70))
	title.name = "GameTitle"
	title.add_theme_font_override("font", _serif_font())
	title.add_theme_constant_override("line_spacing", -7)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	menu.add_child(title)
	var sub := _label("A FIRST-PERSON NIGHT AT THE ORISON", 12,
			Color(0.49, 0.61, 0.65))
	menu.add_child(sub)
	menu.add_child(HSeparator.new())

	var record_head := _label("NOW PLAYING", 10, Color(0.47, 0.43, 0.35))
	menu.add_child(record_head)
	_record_label = _label("", 17, Color(0.88, 0.71, 0.38))
	_record_label.name = "RecordTitle"
	_record_label.add_theme_font_override("font", _serif_font())
	menu.add_child(_record_label)
	_record_note = _label("", 10, Color(0.52, 0.55, 0.54))
	menu.add_child(_record_note)
	_record_progress = ProgressBar.new()
	_record_progress.name = "RecordProgress"
	_record_progress.custom_minimum_size.y = 3
	_record_progress.show_percentage = false
	_record_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.20, 0.19, 0.17, 0.62)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = Color(0.64, 0.43, 0.18, 0.82)
	_record_progress.add_theme_stylebox_override("background", progress_bg)
	_record_progress.add_theme_stylebox_override("fill", progress_fill)
	menu.add_child(_record_progress)
	_record_time = _label("00:00 / 00:00", 10, Color(0.44, 0.44, 0.42))
	_record_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(_record_time)
	_record_button = _add_button(menu, "", _toggle_record, true)
	_record_button.name = "RecordSwitch"
	menu.add_child(HSeparator.new())
	_first_menu_button = _add_button(menu, "BEGIN THE NIGHT", _new_game)
	_add_button(menu, "DEBUG BUILDING", _debug_game)
	_services_button = _add_button(menu, "BUILDING SERVICES", _open_settings)

	var foot := _label(
			"AN ORISON PROPERTY  ·  EST. 1912\nPARTIALLY REOPENED 1928",
			10, Color(0.40, 0.38, 0.34))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu.add_child(foot)


func _build_settings() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "BuildingServices"
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-300, -320)
	_settings_panel.custom_minimum_size = Vector2(600, 640)
	_settings_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.029, 0.034, 0.97)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.50, 0.38, 0.22, 0.72)
	_settings_panel.add_theme_stylebox_override("panel", style)
	add_child(_settings_panel)
	var scroll := ScrollContainer.new()
	scroll.name = "BuildingServicesScroll"
	scroll.custom_minimum_size = Vector2(564, 604)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings_panel.add_child(scroll)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var heading := _label("BUILDING SERVICES", 24,
			Color(0.86, 0.80, 0.66))
	heading.add_theme_font_override("font", _serif_font())
	box.add_child(heading)
	box.add_child(_label("LIGHT AND SHADOW QUALITY", 12,
			Color(0.61, 0.60, 0.55)))
	_quality = OptionButton.new()
	_quality.add_item("Cinematic — maximum (default)", 0)
	_quality.add_item("Balanced — debug-tested", 1)
	_quality.select(int(GameBoot.settings.get("quality", 0)))
	box.add_child(_quality)
	_fullscreen = CheckBox.new()
	_fullscreen.text = "EXCLUSIVE FULLSCREEN"
	_fullscreen.button_pressed = bool(GameBoot.settings.get(
			"fullscreen", false))
	box.add_child(_fullscreen)
	_always_warn = CheckBox.new()
	_always_warn.name = "AlwaysWarnBeforeSleep"
	_always_warn.text = AccessibilityCopyText.SLEEP_WARNING_LABEL
	_always_warn.tooltip_text = AccessibilityCopyText.SLEEP_WARNING_HELP
	_always_warn.button_pressed = bool(GameBoot.settings.get(
			"always_warn_before_sleep", false))
	box.add_child(_always_warn)
	_sound_captions = CheckBox.new()
	_sound_captions.name = "GameplaySoundCaptions"
	_sound_captions.text = AccessibilityCopyText.SOUND_CAPTIONS_LABEL
	_sound_captions.tooltip_text = AccessibilityCopyText.SOUND_CAPTIONS_HELP
	_sound_captions.button_pressed = bool(GameBoot.settings.get(
			"gameplay_sound_captions", false)) or bool(GameBoot.settings.get(
			"dream_directional_captions", false))
	box.add_child(_sound_captions)
	_weather_network_enabled = CheckBox.new()
	_weather_network_enabled.name = "WeatherNetworkEnabled"
	_weather_network_enabled.text = "FETCH LIVE WEATHER FROM OPEN-METEO"
	_weather_network_enabled.tooltip_text = \
			"Makes an internet request and exposes your IP address to Open-Meteo. Off uses the authored Queens weather."
	_weather_network_enabled.button_pressed = bool(GameBoot.settings.get(
			"weather_network_enabled", false))
	box.add_child(_weather_network_enabled)
	_live_local_weather = CheckBox.new()
	_live_local_weather.name = "LiveLocalWeather"
	_live_local_weather.text = "MATCH WEATHER TO MY LOCATION"
	_live_local_weather.tooltip_text = \
			"Opt in by entering a city or postal code. Otherwise the Orison uses Queens, New York."
	_live_local_weather.button_pressed = bool(GameBoot.settings.get(
			"live_local_weather", false))
	box.add_child(_live_local_weather)
	_weather_location = LineEdit.new()
	_weather_location.name = "WeatherLocation"
	_weather_location.placeholder_text = "CITY OR POSTAL CODE  ·  blank uses Queens"
	_weather_location.text = str(GameBoot.settings.get(
			"weather_location_query", ""))
	_live_local_weather.disabled = not _weather_network_enabled.button_pressed
	_weather_location.editable = _weather_network_enabled.button_pressed \
			and _live_local_weather.button_pressed
	_weather_network_enabled.toggled.connect(func(enabled: bool):
		_live_local_weather.disabled = not enabled
		_weather_location.editable = enabled and _live_local_weather.button_pressed)
	_live_local_weather.toggled.connect(func(enabled: bool):
		_weather_location.editable = _weather_network_enabled.button_pressed and enabled)
	box.add_child(_weather_location)
	box.add_child(_label("MASTER VOLUME", 12, Color(0.61, 0.60, 0.55)))
	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.01
	_volume.value = float(GameBoot.settings.get("master_volume", 0.82))
	box.add_child(_volume)
	box.add_child(_label("MIX CATEGORIES", 12, Color(0.61, 0.60, 0.55)))
	var mix := GridContainer.new()
	mix.columns = 2
	mix.add_theme_constant_override("h_separation", 18)
	mix.add_theme_constant_override("v_separation", 6)
	box.add_child(mix)
	_gameplay_volume = _add_volume_control(mix, "GAMEPLAY",
			"gameplay_volume")
	_voice_volume = _add_volume_control(mix, "VOICE / TELEPHONE",
			"voice_volume")
	_world_volume = _add_volume_control(mix, "WORLD / WEATHER", "world_volume")
	_music_volume = _add_volume_control(mix, "MUSIC", "music_volume")
	_ui_volume = _add_volume_control(mix, "INTERFACE", "ui_volume")
	box.add_child(_label("CONTROLLER LOOK", 12, Color(0.61, 0.60, 0.55)))
	var controller_grid := GridContainer.new()
	controller_grid.columns = 2
	controller_grid.add_theme_constant_override("h_separation", 18)
	controller_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(controller_grid)
	_controller_look_sensitivity = _add_controller_slider(controller_grid,
			"SENSITIVITY", "controller_look_sensitivity", 0.25, 2.0, 0.05)
	_controller_look_deadzone = _add_controller_slider(controller_grid,
			"DEAD ZONE", "controller_look_deadzone", 0.05, 0.40, 0.01)
	_controller_look_curve = _add_controller_slider(controller_grid,
			"RESPONSE CURVE", "controller_look_curve", 1.0, 3.0, 0.05)
	_controller_invert_y = CheckBox.new()
	_controller_invert_y.name = "ControllerInvertY"
	_controller_invert_y.text = "INVERT Y"
	_controller_invert_y.button_pressed = bool(GameBoot.settings.get(
			"controller_invert_y", false))
	controller_grid.add_child(_controller_invert_y)
	_add_button(box, "APPLY", _save_settings)
	_add_button(box, "BACK", _close_settings)


func _open_settings() -> void:
	_settings_panel.visible = true
	_quality.grab_focus()


func _close_settings() -> void:
	_settings_panel.visible = false
	_services_button.grab_focus()


func _build_music() -> void:
	for i in _tracks.size():
		var player := AudioStreamPlayer.new()
		player.bus = "Nondiegetic"
		player.name = "TitleRecord%d" % (i + 1)
		player.stream = _tracks[i]
		player.volume_db = -60.0
		player.finished.connect(_on_track_finished.bind(i))
		add_child(player)
		_players.append(player)
	if _volume:
		for slider in [_volume, _gameplay_volume, _voice_volume, _world_volume,
				_music_volume, _ui_volume]:
			slider.value_changed.connect(func(_v): _preview_audio_settings())
	_start_track(TRACK_ORIGINAL, true)


func _add_volume_control(parent: Control, words: String,
		setting_key: String) -> HSlider:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size.x = 245.0
	cell.add_theme_constant_override("separation", 2)
	parent.add_child(cell)
	cell.add_child(_label(words, 10, Color(0.56, 0.55, 0.51)))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(GameBoot.settings.get(setting_key, 1.0))
	cell.add_child(slider)
	return slider


func _add_controller_slider(parent: Control, words: String, setting_key: String,
		minimum: float, maximum: float, increment: float) -> HSlider:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size.x = 245.0
	cell.add_theme_constant_override("separation", 2)
	parent.add_child(cell)
	cell.add_child(_label(words, 10, Color(0.56, 0.55, 0.51)))
	var slider := HSlider.new()
	slider.name = setting_key.to_pascal_case()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = float(GameBoot.settings.get(setting_key, 1.0))
	cell.add_child(slider)
	return slider


func _preview_audio_settings() -> void:
	var levels := {
		"Master":_volume.value, "Gameplay":_gameplay_volume.value,
		"Voice":_voice_volume.value, "World":_world_volume.value,
		"Music":_music_volume.value, "UI":_ui_volume.value,
	}
	for bus_name in levels:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(
					maxf(0.001, float(levels[bus_name]))))


func _start_track(index: int, immediate := false) -> void:
	if index < 0 or index >= _players.size():
		return
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	for player in _players:
		player.stop()
		player.volume_db = -60.0
	_current_track = index
	var player := _players[index]
	if OS.get_environment("TITLE_SCREEN_SILENT") != "1":
		player.play(0.0)
	_music_fade = create_tween()
	_music_fade.tween_property(player, "volume_db", _music_db(index),
			0.01 if immediate else 0.8)
	_set_record_presentation(index)


func _set_record_presentation(index: int) -> void:
	_record_label.text = _track_names[index]
	_record_note.text = _track_notes[index]
	_record_button.text = "PLAY THE ORIGINAL MASTER" \
			if index == TRACK_RETURNED else "HEAR THE RETURN"
	_record_progress.value = 0.0
	var duration := _tracks[index].get_length()
	_record_time.text = "00:00 / %s" % _format_time(duration)


func _toggle_record() -> void:
	_start_track(TRACK_ORIGINAL if _current_track == TRACK_RETURNED \
			else TRACK_RETURNED)


func _on_track_finished(index: int) -> void:
	if _leaving or index != _current_track:
		return
	# The just-finished stream has played its complete file. Alternate instead
	# of setting an import loop, so a patient title-screen listener hears both.
	_start_track(TRACK_ORIGINAL if index == TRACK_RETURNED \
			else TRACK_RETURNED)


func _music_db(index: int) -> float:
	return float(TRACK_TRIM_DB[index])


func _leave(go: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	if _music_fade and _music_fade.is_valid():
		_music_fade.kill()
	var out := create_tween()
	for player in _players:
		out.parallel().tween_property(player, "volume_db", -60.0, 0.7)
	out.tween_callback(go)


func _label(copy: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _serif_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Garamond", "Georgia", "Times New Roman"])
	font.font_weight = 500
	return font


func _add_button(parent: Control, copy: String, callback: Callable,
		quiet := false) -> Button:
	var button := Button.new()
	button.text = copy
	button.custom_minimum_size = Vector2(360, 38 if quiet else 44)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 12 if quiet else 16)
	button.add_theme_color_override("font_color",
			Color(0.56, 0.55, 0.51) if quiet else Color(0.78, 0.75, 0.67))
	button.add_theme_color_override("font_hover_color", Color(0.95, 0.78, 0.43))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _new_game() -> void:
	_leave(func(): GameBoot.begin_game(GameBoot.LaunchMode.CINEMATIC, true))


func _debug_game() -> void:
	_leave(func(): GameBoot.begin_game(GameBoot.LaunchMode.DEBUG, false))


func _save_settings() -> void:
	GameBoot.settings.quality = _quality.selected
	GameBoot.settings.fullscreen = _fullscreen.button_pressed
	GameBoot.settings.always_warn_before_sleep = _always_warn.button_pressed
	GameBoot.settings.gameplay_sound_captions = _sound_captions.button_pressed
	GameBoot.settings.dream_directional_captions = _sound_captions.button_pressed
	GameBoot.settings.weather_network_enabled = \
			_weather_network_enabled.button_pressed
	GameBoot.settings.live_local_weather = _live_local_weather.button_pressed
	GameBoot.settings.weather_location_query = \
			_weather_location.text.strip_edges()
	GameBoot.settings.master_volume = _volume.value
	GameBoot.settings.gameplay_volume = _gameplay_volume.value
	GameBoot.settings.voice_volume = _voice_volume.value
	GameBoot.settings.world_volume = _world_volume.value
	GameBoot.settings.music_volume = _music_volume.value
	GameBoot.settings.ui_volume = _ui_volume.value
	GameBoot.settings.controller_look_sensitivity = \
			_controller_look_sensitivity.value
	GameBoot.settings.controller_look_deadzone = _controller_look_deadzone.value
	GameBoot.settings.controller_look_curve = _controller_look_curve.value
	GameBoot.settings.controller_invert_y = _controller_invert_y.button_pressed
	GameBoot.save_settings()
	_close_settings()


func _place_backdrop() -> void:
	var viewport_size := get_viewport_rect().size
	_hero_art.pivot_offset = viewport_size * 0.5


func _process(delta: float) -> void:
	_elapsed += delta
	_next_contact -= delta
	if _next_contact <= 0.0:
		_contact_left = 0.12
		_next_contact = 8.0 + fmod(_elapsed * 2.73, 11.0)
	_contact_left = maxf(0.0, _contact_left - delta)
	# Slow optical breathing follows neither the beat nor the waltz bar. The
	# single contact cough interrupts it at an irregular interval.
	var zoom := 1.018 + sin(_elapsed * 0.085) * 0.006
	_hero_art.scale = Vector2.ONE * (zoom + (0.002 if _contact_left > 0 else 0.0))
	if _players.is_empty():
		return
	var player := _players[_current_track]
	var duration := _tracks[_current_track].get_length()
	var position := player.get_playback_position() if player.playing else 0.0
	_record_progress.value = 100.0 * clampf(position / maxf(duration, 0.001), 0.0, 1.0)
	_record_time.text = "%s / %s" % [_format_time(position), _format_time(duration)]


func _format_time(seconds: float) -> String:
	var whole := maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [whole / 60, whole % 60]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_panel.visible:
		_close_settings()
