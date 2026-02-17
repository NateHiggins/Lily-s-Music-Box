extends CanvasLayer

signal move_input(vec: Vector2)
signal interact_pressed
signal inspect_pressed
signal emote_pressed
signal tap_move(world_pos: Vector2)

var dragging := false
var drag_origin := Vector2.ZERO

func _ready() -> void:
	%InteractButton.pressed.connect(func(): interact_pressed.emit())
	%InspectButton.pressed.connect(func(): inspect_pressed.emit())
	%EmoteButton.pressed.connect(func(): emote_pressed.emit())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.position, event.pressed)
	elif event is InputEventScreenDrag and dragging:
		var d := event.position - drag_origin
		move_input.emit(d.limit_length(80.0) / 80.0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_touch(event.position, event.pressed)
	elif event is InputEventMouseMotion and dragging:
		var dm := event.position - drag_origin
		move_input.emit(dm.limit_length(80.0) / 80.0)

func _handle_touch(pos: Vector2, pressed: bool) -> void:
	if pos.x < 220:
		dragging = pressed
		drag_origin = pos
		if not dragging:
			move_input.emit(Vector2.ZERO)
	else:
		if pressed:
			tap_move.emit(get_viewport().get_canvas_transform().affine_inverse() * pos)
