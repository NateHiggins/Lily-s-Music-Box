class_name PauseServices
extends CanvasLayer
## In-game access to the persistent audio settings. This surface owns no
## settings: GameBoot remains the single persistence/apply authority.

const LEVELS := [
	["MASTER", "master_volume"],
	["GAMEPLAY / CLUES", "gameplay_volume"],
	["VOICE / TELEPHONE", "voice_volume"],
	["WORLD / WEATHER", "world_volume"],
	["MUSIC", "music_volume"],
	["INTERFACE", "ui_volume"],
]

var player: Node
var panel: PanelContainer
var captions: CheckBox
var onset_warning: CheckBox
var reduce_roll: CheckBox
var reduce_flashing: CheckBox
var look_sensitivity: HSlider
var sliders: Dictionary = {}
var is_open := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func bind_player(owner: Node) -> void:
	player = owner


func can_open() -> bool:
	return not is_open and is_instance_valid(player) \
			and not bool(player.get("call_locked")) \
			and not is_instance_valid(player.get("seated_interaction"))


func open() -> bool:
	if not can_open():
		return false
	_load_controls()
	_mouse_before = Input.mouse_mode
	is_open = true
	panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var policy := get_node_or_null("/root/AudioPolicy")
	if policy and policy.has_method("request_mix"):
		policy.call("request_mix", &"pause_services", &"paused")
	get_tree().paused = true
	return true


func close(save := false) -> void:
	if not is_open:
		return
	if save:
		_store_controls()
	else:
		# Preview is deliberately reversible. Leaving without saving must restore
		# the persisted/user baseline, including whatever mix state is active.
		GameBoot.apply_audio_settings()
	get_tree().paused = false
	var policy := get_node_or_null("/root/AudioPolicy")
	if policy and policy.has_method("release_mix"):
		policy.call("release_mix", &"pause_services")
	panel.visible = false
	is_open = false
	Input.mouse_mode = _mouse_before


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close(false)
		get_viewport().set_input_as_handled()


func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "InGameBuildingServices"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-270, -300)
	panel.custom_minimum_size = Vector2(540, 600)
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.029, 0.034, 0.975)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.50, 0.38, 0.22, 0.78)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	box.add_child(_label("BUILDING SERVICES", 25, Color("dccda8")))
	box.add_child(_label("THE NIGHT IS HELD. SOUND CHANGES APPLY AT ONCE.", 11,
			Color("918d82")))
	box.add_child(HSeparator.new())
	for record in LEVELS:
		var words: String = record[0]
		var key: String = record[1]
		box.add_child(_label(words, 11, Color("9c998e")))
		var slider := HSlider.new()
		slider.name = key.to_pascal_case()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value_changed.connect(_preview.bind(key))
		box.add_child(slider)
		sliders[key] = slider
	captions = CheckBox.new()
	captions.name = "GameplaySoundCaptions"
	captions.text = "CAPTION GAMEPLAY AND DREAM SOUND CUES"
	captions.tooltip_text = "Names semantic cues and direction without revealing distance or hidden ownership."
	box.add_child(captions)
	onset_warning = CheckBox.new()
	onset_warning.name = "AlwaysWarnBeforeSleep"
	onset_warning.text = "ALWAYS GIVE THE GRADUAL SLEEP WARNING"
	onset_warning.tooltip_text = \
			"Uses the legible gradual warning for every sleep onset."
	box.add_child(onset_warning)
	reduce_roll = CheckBox.new()
	reduce_roll.name = "ReduceCameraRoll"
	reduce_roll.text = "REDUCE CAMERA ROLL"
	reduce_roll.tooltip_text = \
			"Keeps traffic impacts and altered gravity physical without rolling the view."
	box.add_child(reduce_roll)
	reduce_flashing = CheckBox.new()
	reduce_flashing.name = "ReduceFlashing"
	reduce_flashing.text = "SUPPRESS LIGHTNING FLASHES"
	reduce_flashing.tooltip_text = \
			"Weather remains truthful, but lightning no longer flashes the sky or street."
	box.add_child(reduce_flashing)
	box.add_child(_label("LOOK SENSITIVITY", 11, Color("9c998e")))
	look_sensitivity = HSlider.new()
	look_sensitivity.name = "LookSensitivity"
	look_sensitivity.min_value = 0.25
	look_sensitivity.max_value = 2.0
	look_sensitivity.step = 0.05
	box.add_child(look_sensitivity)
	var apply := Button.new()
	apply.name = "ApplyAndReturn"
	apply.text = "APPLY AND RETURN TO THE NIGHT"
	apply.pressed.connect(func(): close(true))
	box.add_child(apply)
	var resume := Button.new()
	resume.name = "ReturnWithoutSaving"
	resume.text = "RETURN WITHOUT SAVING"
	resume.pressed.connect(func(): close(false))
	box.add_child(resume)


func _load_controls() -> void:
	for record in LEVELS:
		var key: String = record[1]
		sliders[key].set_value_no_signal(float(GameBoot.settings.get(key, 1.0)))
	captions.button_pressed = bool(GameBoot.settings.get(
			"gameplay_sound_captions", false)) or bool(GameBoot.settings.get(
			"dream_directional_captions", false))
	onset_warning.button_pressed = bool(GameBoot.settings.get(
			"always_warn_before_sleep", false))
	reduce_roll.button_pressed = bool(GameBoot.settings.get(
			"reduce_camera_roll", false))
	reduce_flashing.button_pressed = bool(GameBoot.settings.get(
			"reduce_flashing", false))
	look_sensitivity.value = float(GameBoot.settings.get("look_sensitivity", 1.0))


func _preview(value: float, key: String) -> void:
	var bus_names := {
		"master_volume":"Master", "gameplay_volume":"Gameplay",
		"voice_volume":"Voice", "world_volume":"World",
		"music_volume":"Music", "ui_volume":"UI",
	}
	var bus := AudioServer.get_bus_index(bus_names[key])
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, value)))


func _store_controls() -> void:
	for key in sliders:
		GameBoot.settings[key] = sliders[key].value
	GameBoot.settings.gameplay_sound_captions = captions.button_pressed
	GameBoot.settings.dream_directional_captions = captions.button_pressed
	GameBoot.settings.always_warn_before_sleep = onset_warning.button_pressed
	GameBoot.settings.reduce_camera_roll = reduce_roll.button_pressed
	GameBoot.settings.reduce_flashing = reduce_flashing.button_pressed
	GameBoot.settings.look_sensitivity = look_sensitivity.value
	GameBoot.save_settings()
	var policy := get_node_or_null("/root/AudioPolicy")
	if policy:
		var caption_layer = policy.get("_caption_layer")
		if caption_layer and caption_layer.has_method("refresh_setting"):
			caption_layer.call("refresh_setting")
	var dream_layer := get_tree().root.find_child("DreamCaptionLayer", true, false)
	if dream_layer and dream_layer.has_method("refresh_setting"):
		dream_layer.call("refresh_setting")


func _label(copy: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = copy
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result
