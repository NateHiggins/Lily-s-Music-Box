class_name ArcadePanel
extends CanvasLayer
## Standing at the cabinet.
##
## The picture is the same SubViewport the screen in the world is showing - one
## board, two displays - blown up to something you can actually play on and left
## deliberately chunky. A 480x360 image scaled to a modern screen is what an
## arcade cabinet looks like from two feet away, and softening it would be
## flattering a machine this whole row exists to be rude about.
##
## Input goes to the cabinet and nowhere else: the outer player is locked while
## the panel is up, and the machine's own player reads a control struct this file
## writes rather than the global Input singleton. Walking past a cabinet has
## never moved anything inside one.

const _LOOK_SENSITIVITY := 1.0

var _player: Node
var _prop: Node
var _machine: ArcadeMachine
var _picture: TextureRect
var _hint: Label
var _look := Vector2.ZERO
var _was_captured := false


func open(player: Node, prop: Node) -> void:
	_player = player
	_prop = prop
	_machine = prop.machine
	layer = 12
	if _player and "call_locked" in _player:
		_player.call_locked = true

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.03, 0.94)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	centre.add_child(column)

	var marquee := Label.new()
	marquee.text = String(_prop.cabinet.get("title", ""))
	marquee.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marquee.add_theme_font_size_override("font_size", 26)
	marquee.add_theme_color_override("font_color", _accent())
	column.add_child(marquee)

	_picture = TextureRect.new()
	_picture.texture = _machine.get_texture()
	# Nearest, and an integer-ish size. The point of a 480x360 feed is that it
	# looks like 480x360.
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.custom_minimum_size = ArcadeMachine.RES * 2
	column.add_child(_picture)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	_hint.text = "WASD move · mouse look · click fire · E interact · ESC step away"
	column.add_child(_hint)

	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_machine.set_live(true)
	_machine.begin_play()
	set_process(true)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Accumulated rather than applied: the machine runs on its own physics
		# tick and should see one look delta per frame, not one per event.
		_look += (event as InputEventMouseMotion).relative
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_E:
			_machine.try_interact()
			get_viewport().set_input_as_handled()
			return


func _process(_delta: float) -> void:
	if _machine == null:
		return
	# Read the keys here rather than through actions: Orison's own movement
	# bindings belong to the player standing in the arcade, and a cabinet should
	# not inherit them.
	var move := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_machine.drive(
		move,
		_look * _LOOK_SENSITIVITY,
		Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		Input.is_physical_key_pressed(KEY_SPACE),
		Input.is_physical_key_pressed(KEY_SHIFT)
	)
	_look = Vector2.ZERO


func close() -> void:
	if _machine != null:
		_machine.end_play()
	if _player and "call_locked" in _player:
		_player.call_locked = false
	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED if _was_captured else Input.MOUSE_MODE_VISIBLE
	)
	if _prop and _prop.has_method("panel_closed"):
		_prop.panel_closed()
	queue_free()


func _accent() -> Color:
	var text := String(_prop.cabinet.get("marquee_color", ""))
	return Color(text) if text.begins_with("#") else Color(0.91, 0.78, 0.29)
