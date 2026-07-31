class_name CaseDialoguePanel
extends CanvasLayer
## Lightweight choice dialogue for reality-maintenance conversations.

var _panel: PanelContainer
var _speaker: Label
var _line: Label
var _choices: VBoxContainer
var _player: PlayerController
var _previous_mouse := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 11
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.position = Vector2(-360, -270)
	_panel.custom_minimum_size = Vector2(720, 220)
	add_child(_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	_panel.add_child(stack)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 17)
	_speaker.modulate = Color(0.62, 0.90, 0.80)
	stack.add_child(_speaker)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 16)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.y = 68
	stack.add_child(_line)
	_choices = VBoxContainer.new()
	stack.add_child(_choices)
	_panel.visible = false


func present(speaker_name: String, words: String, options: Array) -> void:
	for old in _choices.get_children():
		old.queue_free()
	_speaker.text = speaker_name
	_line.text = words
	for option in options:
		var button := Button.new()
		button.text = option.text
		button.add_theme_font_size_override("font_size", 14)
		var action: Callable = option.action
		button.pressed.connect(func():
			close()
			if action.is_valid():
				action.call())
		_choices.add_child(button)
	_panel.visible = true
	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = get_tree().get_first_node_in_group(
			"player_controller") as PlayerController
	if _player:
		_player.call_locked = true


func close() -> void:
	_panel.visible = false
	if _player:
		_player.call_locked = false
	Input.mouse_mode = _previous_mouse
