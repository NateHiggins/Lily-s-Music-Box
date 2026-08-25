class_name CaseDialoguePanel
extends CanvasLayer
## Lightweight choice dialogue for reality-maintenance conversations.
## Two surfaces: present() shows one hand-built prompt; run_tree() walks an
## authored dialogue tree (see data/case01_dialogue.json) where silence is a
## first-class option on any node that defines silence_goto.

signal node_shown(node_id: String)
signal tree_ended

var _panel: PanelContainer
var _speaker: Label
var _line: Label
var _choices: VBoxContainer
var _player: PlayerController
var _previous_mouse := Input.MOUSE_MODE_CAPTURED
var _tree: Dictionary = {}
var _on_flag: Callable = Callable()
var _on_action: Callable = Callable()
var _actions: Array = []
var _silence_action: Callable = Callable()
var current_node_id := ""


func _ready() -> void:
	add_to_group("attention_people")
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


func attention_active() -> bool:
	return _panel != null and _panel.visible


func present(speaker_name: String, words: String, options: Array) -> void:
	for old in _choices.get_children():
		old.queue_free()
	_speaker.text = speaker_name
	_line.text = words
	_actions = []
	_silence_action = Callable()
	for option in options:
		var button := Button.new()
		button.text = option.text
		button.add_theme_font_size_override("font_size", 14)
		var action: Callable = option.action
		_actions.append(action)
		if option.get("silent", false):
			# The button that says nothing: dimmer, and set apart.
			button.modulate = Color(0.55, 0.60, 0.58)
			_silence_action = action
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


## --- authored dialogue tree ---------------------------------------------

func run_tree(tree: Dictionary, entry_id: String, on_flag: Callable,
		on_action := Callable()) -> void:
	_tree = tree
	_on_flag = on_flag
	_on_action = on_action
	_show_node(entry_id)


func _show_node(node_id: String) -> void:
	var nodes: Dictionary = _tree.get("nodes", {})
	if not nodes.has(node_id):
		push_warning("case dialogue: missing node '%s'" % node_id)
		close()
		return
	current_node_id = node_id
	var node: Dictionary = nodes[node_id]
	if node.has("action") and _on_action.is_valid():
		_on_action.call(str(node.action))
	var speaker := str(node.get("speaker",
			_tree.get("meta", {}).get("speaker_default", "")))
	var options: Array = []
	for choice in node.get("choices", []):
		options.append({"text": str(choice.label),
				"action": _advance_action(choice)})
	if node.has("silence_goto"):
		options.append({"text": "[Say nothing.]", "silent": true,
				"action": _advance_action({
					"goto": node.silence_goto,
					"flag": node.get("silence_flag", ""),
					"trust": node.get("silence_trust", 1)})})
	if options.is_empty():
		options.append({"text": "[...]", "action": _end_tree})
	present(speaker, str(node.line), options)
	node_shown.emit(node_id)


func _advance_action(choice: Dictionary) -> Callable:
	return func():
		var flag := str(choice.get("flag", ""))
		if flag != "" and _on_flag.is_valid():
			_on_flag.call(flag, int(choice.get("trust", 1)))
		var goto_id := str(choice.get("goto", ""))
		if goto_id != "":
			_show_node(goto_id)
		else:
			_end_tree()


func _end_tree() -> void:
	current_node_id = ""
	tree_ended.emit()


## Programmatic drivers, so tests can walk the tree without a mouse.
func choose(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	var action: Callable = _actions[index]
	close()
	if action.is_valid():
		action.call()


func choose_silence() -> void:
	var action := _silence_action
	close()
	if action.is_valid():
		action.call()
