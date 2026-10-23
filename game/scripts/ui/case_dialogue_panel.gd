class_name CaseDialoguePanel
extends CanvasLayer
## Choice dialogue for conversations with the people of the building.
##
## Two surfaces: present() shows one hand-built prompt; run_tree() walks an
## authored dialogue tree (see data/case01_dialogue.json and
## data/dialogue/*.json) where silence is a first-class option on any node
## that defines silence_goto.
##
## PRESENTATION. The old surface was a grey box in the middle of the lower
## screen. This one is a lower-third: a soft dark scrim that rises from the
## bottom edge, the speaker's name set small in italic, the line in the
## building's serif, and the player's replies as plain numbered lines with
## no button chrome. Nothing crosses the centre of the view; the crosshair
## and whatever the player was looking at stay visible above the words.
## Replies answer to the mouse, to the number keys, and to the programmatic
## drivers at the bottom of this file that the tests use.
##
## DRAFT FIELDS (design/ORISON_DIALOGUE_DRAFTS_2026-10-22.md). A tree runner
## may pass a context with an `available` callable; a choice it refuses is
## not shown. That is how `requires` (a flag earned in another flat),
## `evidence` (a thing in this flat) and `infer` are honoured without this
## panel knowing anything about the building. A node may carry a `flag` of
## its own, granted on arrival with no trust.
##
## It owns no case, job, inventory or save fact. Flags go out through the
## callable the caller handed in.

signal node_shown(node_id: String)
signal tree_ended

const SERIF: Font = preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
const SERIF_ITALIC: Font = preload("res://assets/fonts/eb_garamond/EBGaramond-Italic[wght].ttf")

const INK := Color(0.93, 0.90, 0.82)
const INK_DIM := Color(0.62, 0.60, 0.54)
const SPEAKER := Color(0.56, 0.78, 0.72)
const REPLY := Color(0.84, 0.80, 0.70)
const REPLY_HOVER := Color(0.95, 0.78, 0.43)
const REPLY_EVIDENCE := Color(0.62, 0.82, 0.76)
const REPLY_INFER := Color(0.90, 0.74, 0.50)
const SILENCE := Color(0.52, 0.55, 0.52)
const SCRIM := Color(0.015, 0.016, 0.022)

const COLUMN_WIDTH := 760.0
const LINE_SIZE := 21
const REPLY_SIZE := 17
const SPEAKER_SIZE := 15
const FADE_SECONDS := 0.16

var _panel: Control
var _scrim: TextureRect
var _column: VBoxContainer
var _speaker: Label
var _line: Label
var _choices: VBoxContainer
var _player: PlayerController
var _previous_mouse := Input.MOUSE_MODE_CAPTURED
var _tree: Dictionary = {}
var _on_flag: Callable = Callable()
var _on_action: Callable = Callable()
var _context: Dictionary = {}
var _actions: Array = []
var _silence_action: Callable = Callable()
var _fade: Tween
var current_node_id := ""


func _ready() -> void:
	add_to_group("attention_people")
	layer = 11
	_panel = Control.new()
	_panel.name = "Conversation"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_scrim = TextureRect.new()
	_scrim.name = "Scrim"
	_scrim.texture = _scrim_texture()
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_scrim.anchor_top = 0.58
	_scrim.offset_top = 0.0
	_scrim.offset_bottom = 0.0
	_panel.add_child(_scrim)

	var margin := MarginContainer.new()
	margin.name = "Measure"
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.anchor_top = 0.62
	margin.offset_top = 0.0
	margin.offset_bottom = 0.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_bottom", 34)
	margin.add_theme_constant_override("margin_top", 0)
	_panel.add_child(margin)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.custom_minimum_size = Vector2(0, 0)
	_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_column.size_flags_vertical = Control.SIZE_SHRINK_END
	_column.alignment = BoxContainer.ALIGNMENT_END
	_column.add_theme_constant_override("separation", 6)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_column)

	_speaker = Label.new()
	_speaker.name = "Speaker"
	_speaker.add_theme_font_override("font", SERIF_ITALIC)
	_speaker.add_theme_font_size_override("font_size", SPEAKER_SIZE)
	_speaker.add_theme_color_override("font_color", SPEAKER)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_speaker)

	_line = Label.new()
	_line.name = "Line"
	_line.add_theme_font_override("font", SERIF)
	_line.add_theme_font_size_override("font_size", LINE_SIZE)
	_line.add_theme_color_override("font_color", INK)
	_line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_line.add_theme_constant_override("shadow_offset_x", 1)
	_line.add_theme_constant_override("shadow_offset_y", 1)
	_line.add_theme_constant_override("line_spacing", 3)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_line)

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = Color(SPEAKER, 0.35)
	rule.custom_minimum_size = Vector2(120, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(rule)

	_choices = VBoxContainer.new()
	_choices.name = "Replies"
	_choices.add_theme_constant_override("separation", 2)
	_column.add_child(_choices)
	_panel.visible = false
	_panel.modulate.a = 0.0


## A vertical gradient: nothing at the top edge, a quiet dark at the bottom.
## Drawn once; the TextureRect stretches it across the viewport.
func _scrim_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(SCRIM, 0.0), Color(SCRIM, 0.62),
			Color(SCRIM, 0.86)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 128
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


func attention_active() -> bool:
	return _panel != null and _panel.visible


## One hand-built prompt. `options` are dictionaries with `text` and `action`,
## optionally `silent`, `evidence` or `infer` for presentation.
func present(speaker_name: String, words: String, options: Array) -> void:
	for old in _choices.get_children():
		_choices.remove_child(old)
		old.queue_free()
	_speaker.text = speaker_name
	_speaker.visible = speaker_name.strip_edges() != ""
	_line.text = words
	_actions = []
	_silence_action = Callable()
	var number := 0
	for option in options:
		var action: Callable = option.action
		var silent: bool = bool(option.get("silent", false))
		number += 1
		_actions.append(action)
		if silent:
			_silence_action = action
		var reply := _reply_button(number, str(option.text), silent,
				bool(option.get("evidence", false)), bool(option.get("infer", false)))
		reply.pressed.connect(func():
			close()
			if action.is_valid():
				action.call())
		_choices.add_child(reply)
	_panel.visible = true
	_fade_to(1.0)
	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = get_tree().get_first_node_in_group(
			"player_controller") as PlayerController
	if _player:
		_player.call_locked = true
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Control).grab_focus()


func _reply_button(number: int, text: String, silent: bool, evidence: bool,
		infer: bool) -> Button:
	var button := Button.new()
	button.text = "%d   %s" % [number, text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 28)
	button.add_theme_font_override("font", SERIF_ITALIC if silent else SERIF)
	button.add_theme_font_size_override("font_size", REPLY_SIZE)
	var color := REPLY
	if silent:
		color = SILENCE
	elif evidence:
		color = REPLY_EVIDENCE
	elif infer:
		color = REPLY_INFER
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", REPLY_HOVER)
	button.add_theme_color_override("font_focus_color", REPLY_HOVER)
	button.add_theme_color_override("font_pressed_color", REPLY_HOVER)
	button.add_theme_color_override("font_hover_pressed_color", REPLY_HOVER)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 6
	empty.content_margin_right = 6
	empty.content_margin_top = 3
	empty.content_margin_bottom = 3
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.add_theme_stylebox_override(state, empty)
	return button


func _fade_to(alpha: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	if not is_inside_tree():
		_panel.modulate.a = alpha
		return
	_fade = create_tween()
	_fade.tween_property(_panel, "modulate:a", alpha, FADE_SECONDS)


func close() -> void:
	_panel.visible = false
	_panel.modulate.a = 0.0
	if _fade and _fade.is_valid():
		_fade.kill()
	if _player:
		_player.call_locked = false
	Input.mouse_mode = _previous_mouse


## Number keys answer; the reply with no words answers to 0.
func _unhandled_input(event: InputEvent) -> void:
	if not attention_active() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index := int(key.keycode - KEY_1)
		if index < _actions.size():
			get_viewport().set_input_as_handled()
			choose(index)
	elif key.keycode == KEY_0 and _silence_action.is_valid():
		get_viewport().set_input_as_handled()
		choose_silence()


## --- authored dialogue tree ---------------------------------------------

## `context` may carry:
##   "available": Callable(choice: Dictionary) -> bool
##        a choice it refuses is not offered (requires / evidence)
##   "on_node_flag": Callable(flag: String)
##        a node's own `flag`, granted on arrival; falls back to on_flag(flag, 0)
func run_tree(tree: Dictionary, entry_id: String, on_flag: Callable,
		on_action := Callable(), context := {}) -> void:
	_tree = tree
	_on_flag = on_flag
	_on_action = on_action
	_context = context
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
	var node_flag := str(node.get("flag", ""))
	if node_flag != "":
		var on_node_flag: Callable = _context.get("on_node_flag", Callable())
		if on_node_flag.is_valid():
			on_node_flag.call(node_flag)
		elif _on_flag.is_valid():
			_on_flag.call(node_flag, 0)
	var speaker := str(node.get("speaker",
			_tree.get("meta", {}).get("speaker_default", "")))
	var available: Callable = _context.get("available", Callable())
	var options: Array = []
	for choice in node.get("choices", []):
		if available.is_valid() and not bool(available.call(choice)):
			continue
		options.append({"text": str(choice.label),
				"evidence": choice.has("evidence"),
				"infer": bool(choice.get("infer", false)),
				"action": _advance_action(choice)})
	if node.has("silence_goto"):
		var silence := {"goto": node.silence_goto, "flag": node.get("silence_flag", "")}
		if node.has("silence_trust"):
			silence["trust"] = node.silence_trust
		options.append({"text": "Say nothing.", "silent": true,
				"action": _advance_action(silence)})
	if options.is_empty():
		options.append({"text": "...", "silent": true, "action": _end_tree})
	present(speaker, str(node.line), options)
	node_shown.emit(node_id)


func _advance_action(choice: Dictionary) -> Callable:
	return func():
		# A flag implies one trust unless the reply says otherwise; a reply may
		# also move trust alone, as the inference and comfort replies do.
		var flag := str(choice.get("flag", ""))
		if (flag != "" or choice.has("trust")) and _on_flag.is_valid():
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


## The replies currently offered, in order, for tests and drivers.
func offered_labels() -> Array:
	var labels: Array = []
	for child in _choices.get_children():
		if child is Button:
			labels.append(str(child.text).substr(4))
	return labels
