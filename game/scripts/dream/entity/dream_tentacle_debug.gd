extends CanvasLayer
## The developer panel for the Dream tentacle (DREAM_TENTACLE_DIRECTION
## §25): every visual system on its own switch, and the state on screen.
## Opened with TENTACLE_DEBUG=1 or F8 in play; reads the first live
## tentacle under the encroachment.

var encroachment: Node
var _panel: PanelContainer
var _state: Label
var _checks: Dictionary = {}
var _tentacle: Node = null


func setup(enc: Node) -> void:
	encroachment = enc
	layer = 90
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.visible = OS.get_environment("TENTACLE_DEBUG") == "1"
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "DREAM TENTACLE"
	box.add_child(title)
	_state = Label.new()
	_state.text = "—"
	box.add_child(_state)
	for key in ["breathing", "peristalsis", "vein_pulse", "gold_flow", "gold_emission",
			"eye_tracking", "halos", "suckers", "contact_deformation", "surface_conversion",
			"rim", "phase_slice", "membrane", "lights", "interior", "gray", "show_bones"]:
		var cb := CheckButton.new()
		cb.text = key
		cb.button_pressed = key not in ["gray", "show_bones"]
		cb.toggled.connect(func(on: bool) -> void:
			if _tentacle != null and is_instance_valid(_tentacle):
				_tentacle.set_toggle(key, on))
		box.add_child(cb)
		_checks[key] = cb
	var withdraw := Button.new()
	withdraw.text = "withdraw"
	withdraw.pressed.connect(func() -> void:
		if _tentacle != null and is_instance_valid(_tentacle):
			_tentacle.withdraw())
	box.add_child(withdraw)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		_panel.visible = not _panel.visible


func _process(_delta: float) -> void:
	if not _panel.visible or encroachment == null:
		return
	if _tentacle == null or not is_instance_valid(_tentacle):
		_tentacle = null
		for floor_id in encroachment.tentacles:
			for t in encroachment.tentacles[floor_id]:
				if is_instance_valid(t):
					_tentacle = t
					break
			if _tentacle != null:
				break
	if _tentacle == null:
		_state.text = "no tentacle"
		return
	var c: Dictionary = _tentacle.census()
	_state.text = "%s  grow %.2f  grip %.2f  eye %.2f  suckers %d  target %s" % [
			c.state, c.grow, c.grip, c.eye_open, c.suckers_engaged, c.target]
