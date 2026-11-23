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
const AccessibilityCopyText := preload("res://scripts/ui/accessibility_copy.gd")

var player: Node
var panel: PanelContainer
var center: CenterContainer
var captions: CheckBox
var onset_warning: CheckBox
var reduce_roll: CheckBox
var reduce_flashing: CheckBox
var look_sensitivity: HSlider
var controller_look_sensitivity: HSlider
var controller_look_deadzone: HSlider
var controller_look_curve: HSlider
var controller_invert_y: CheckBox
var apply_button: Button
var _case_button: Button
var _case_view: CanvasLayer
var _case_active := false
var sliders: Dictionary = {}
var is_open := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _focus_before: WeakRef


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_fit_panel)


func bind_player(owner: Node) -> void:
	player = owner


func bind_case(view: CanvasLayer) -> void:
	_case_view = view
	_case_view.connect(&"closed", _return_from_case)


func _open_case() -> void:
	if not is_open or not is_instance_valid(_case_view) or not _case_view.call("open_from_pause"):
		return
	_case_active = true
	center.hide()
	_host_debug_controls(false)


func _return_from_case() -> void:
	if not _case_active:
		return
	_case_active = false
	center.show()
	_host_debug_controls(true)
	_case_button.grab_focus()


func can_open() -> bool:
	return not is_open and not get_tree().paused and is_instance_valid(player) \
			and not bool(player.get("call_locked")) \
			and not is_instance_valid(player.get("seated_interaction"))


func open() -> bool:
	if not can_open():
		return false
	_load_controls()
	_fit_panel()
	_mouse_before = Input.mouse_mode
	_focus_before = weakref(get_viewport().gui_get_focus_owner())
	_case_button.visible = is_instance_valid(_case_view)
	_case_button.disabled = _case_button.visible and not _case_view.call("can_open_from_pause")
	is_open = true
	_host_debug_controls(true)
	center.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var policy := get_node_or_null("/root/AudioPolicy")
	if policy and policy.has_method("request_mix"):
		policy.call("request_mix", &"pause_services", &"paused")
	get_tree().paused = true
	apply_button.grab_focus()
	return true


func close(save := false) -> void:
	if not is_open or _case_active:
		return
	if save:
		_store_controls()
	else:
		# Preview is deliberately reversible. Leaving without saving must restore
		# the persisted/user baseline, including whatever mix state is active.
		GameBoot.apply_audio_settings()
	# GUI handling leaves controller A visible to the polled world action.
	if is_instance_valid(player) and Input.is_action_just_pressed("interact"):
		player.call("retire_interact_press")
	center.hide()
	_host_debug_controls(false)
	_release_pause()
	Input.mouse_mode = _mouse_before
	var previous := _focus_before.get_ref() as Control if _focus_before else null
	if is_instance_valid(previous) and previous.is_visible_in_tree():
		previous.grab_focus()
	_focus_before = null


func _exit_tree() -> void:
	if is_open:
		GameBoot.apply_audio_settings()
		_release_pause()


func _release_pause() -> void:
	is_open = false
	var policy := get_node_or_null("/root/AudioPolicy")
	if policy and policy.has_method("release_mix"):
		policy.call("release_mix", &"pause_services")
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open and not _case_active and (event.is_action_pressed("ui_cancel")
			or event.is_action_pressed("pause_services")):
		close(false)
		get_viewport().set_input_as_handled()


func _fit_panel() -> void:
	center.size = get_viewport().get_visible_rect().size
	var available := center.size - Vector2(32, 32)
	panel.custom_minimum_size = available.clamp(Vector2.ZERO, Vector2(540, 600))


func _build() -> void:
	center = CenterContainer.new()
	center.name = "ServicesCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	center.hide()
	add_child(center)
	panel = PanelContainer.new()
	panel.name = "InGameBuildingServices"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.029, 0.034, 0.975)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.50, 0.38, 0.22, 0.78)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.name = "ServicesScroll"
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
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
	captions.text = AccessibilityCopyText.SOUND_CAPTIONS_LABEL
	captions.tooltip_text = AccessibilityCopyText.SOUND_CAPTIONS_HELP
	box.add_child(captions)
	onset_warning = CheckBox.new()
	onset_warning.name = "AlwaysWarnBeforeSleep"
	onset_warning.text = AccessibilityCopyText.SLEEP_WARNING_LABEL
	onset_warning.tooltip_text = AccessibilityCopyText.SLEEP_WARNING_HELP
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
	box.add_child(_label("CONTROLLER LOOK SENSITIVITY", 11, Color("9c998e")))
	controller_look_sensitivity = HSlider.new()
	controller_look_sensitivity.name = "ControllerLookSensitivity"
	controller_look_sensitivity.min_value = 0.25
	controller_look_sensitivity.max_value = 2.0
	controller_look_sensitivity.step = 0.05
	box.add_child(controller_look_sensitivity)
	controller_invert_y = CheckBox.new()
	controller_invert_y.name = "ControllerInvertY"
	controller_invert_y.text = "INVERT CONTROLLER LOOK Y"
	box.add_child(controller_invert_y)
	box.add_child(_label("CONTROLLER DEAD ZONE", 11, Color("9c998e")))
	controller_look_deadzone = HSlider.new()
	controller_look_deadzone.name = "ControllerLookDeadzone"
	controller_look_deadzone.min_value = 0.05
	controller_look_deadzone.max_value = 0.40
	controller_look_deadzone.step = 0.01
	box.add_child(controller_look_deadzone)
	box.add_child(_label("CONTROLLER RESPONSE CURVE", 11, Color("9c998e")))
	controller_look_curve = HSlider.new()
	controller_look_curve.name = "ControllerLookCurve"
	controller_look_curve.min_value = 1.0
	controller_look_curve.max_value = 3.0
	controller_look_curve.step = 0.05
	box.add_child(controller_look_curve)

	var footer := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		footer.add_theme_constant_override("margin_" + side, 12)
	layout.add_child(footer)
	var actions := VBoxContainer.new()
	footer.add_child(actions)
	_case_button = Button.new()
	_case_button.name = "OpenValise"
	_case_button.text = "OPEN VALISE"
	_case_button.hide()
	_case_button.pressed.connect(_open_case)
	actions.add_child(_case_button)
	apply_button = Button.new()
	apply_button.name = "ApplyAndReturn"
	apply_button.text = "APPLY AND RETURN TO THE NIGHT"
	apply_button.pressed.connect(func(): close(true))
	actions.add_child(apply_button)
	var resume := Button.new()
	resume.name = "ReturnWithoutSaving"
	resume.text = "RETURN WITHOUT SAVING"
	resume.pressed.connect(func(): close(false))
	actions.add_child(resume)
	# The pinned engine has no pad default for ui_accept. Scope confirmation
	# to the focused pause control without changing the world's action map.
	var confirm_events: Array[InputEvent] = []
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventJoypadButton:
			confirm_events.append(event)
	var controller_confirm := Shortcut.new()
	controller_confirm.events = confirm_events
	for button: BaseButton in [captions, onset_warning, reduce_roll, reduce_flashing,
			controller_invert_y, _case_button, apply_button, resume]:
		button.shortcut = controller_confirm
		button.shortcut_context = button
		button.shortcut_in_tooltip = false
	if GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG:
		_connect_focus_cycle(box, resume)


func _connect_focus_cycle(box: VBoxContainer, resume: Button) -> void:
	var controls: Array[Control] = []
	for child in box.get_children():
		var control := child as Control
		if control.focus_mode == Control.FOCUS_ALL:
			controls.append(control)
	controls.append(_case_button)
	controls.append(apply_button)
	controls.append(resume)
	for index in controls.size():
		var control := controls[index]
		var next := control.get_path_to(controls[(index + 1) % controls.size()])
		var previous := control.get_path_to(controls[index - 1])
		control.focus_next = next
		control.focus_previous = previous
		control.focus_neighbor_bottom = next
		control.focus_neighbor_top = previous


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
	controller_look_sensitivity.value = float(GameBoot.settings.get(
			"controller_look_sensitivity", 1.0))
	controller_invert_y.button_pressed = bool(GameBoot.settings.get(
			"controller_invert_y", false))
	controller_look_deadzone.value = float(GameBoot.settings.get(
			"controller_look_deadzone", 0.18))
	controller_look_curve.value = float(GameBoot.settings.get(
			"controller_look_curve", 1.65))


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
	GameBoot.settings.controller_look_sensitivity = \
			controller_look_sensitivity.value
	GameBoot.settings.controller_invert_y = controller_invert_y.button_pressed
	GameBoot.settings.controller_look_deadzone = controller_look_deadzone.value
	GameBoot.settings.controller_look_curve = controller_look_curve.value
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


## In a debug launch the controls the panel owns are the reason to pause at
## all, so Building Services unfolds them over its own surface and folds
## them away again on close. Play launches never see them.
func _host_debug_controls(active: bool) -> void:
	if GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG:
		return
	var panel := _find_debug_panel(get_tree().current_scene)
	if panel != null:
		panel.show_in_pause(active)


func _find_debug_panel(node: Node) -> BuildingDebug:
	if node == null:
		return null
	if node is BuildingDebug:
		return node
	for child in node.get_children():
		var found := _find_debug_panel(child)
		if found != null:
			return found
	return null
