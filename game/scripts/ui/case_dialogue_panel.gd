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
signal tree_replaced(previous: Dictionary)

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
var _measure: MarginContainer
var _reply_scroll: ScrollContainer
var _choices: VBoxContainer
const SpeakerFraming := preload("res://scripts/ui/resident_speaker_framing.gd")
var _speaker_framing: SpeakerFraming
var _player: PlayerController
var _input_revision := -1
var _previous_mouse := Input.MOUSE_MODE_CAPTURED
var _tree: Dictionary = {}
var _on_flag: Callable = Callable()
var _on_action: Callable = Callable()
var _context: Dictionary = {}
var _actions: Array = []
var _silence_index := -1
var _fade: Tween
var _line_exchange: Dictionary = {}
var _line_delivery := "spoken"
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

	_measure = MarginContainer.new()
	_measure.name = "Measure"
	# The column stays bottom-aligned as the viewport changes.
	_measure.set_anchors_preset(Control.PRESET_FULL_RECT)
	_measure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure.add_theme_constant_override("margin_top", 0)
	_panel.add_child(_measure)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.custom_minimum_size = Vector2(0, 0)
	_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_column.size_flags_vertical = Control.SIZE_SHRINK_END
	_column.alignment = BoxContainer.ALIGNMENT_END
	_column.add_theme_constant_override("separation", 6)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure.add_child(_column)

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

	_reply_scroll = ScrollContainer.new()
	_reply_scroll.name = "ReplyScroll"
	_reply_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_reply_scroll.follow_focus = true
	_column.add_child(_reply_scroll)
	_choices = VBoxContainer.new()
	_choices.name = "Replies"
	_choices.add_theme_constant_override("separation", 2)
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reply_scroll.add_child(_choices)
	get_viewport().size_changed.connect(_fit_measure)
	_line.minimum_size_changed.connect(_fit_replies, CONNECT_DEFERRED)
	_choices.minimum_size_changed.connect(_fit_replies, CONNECT_DEFERRED)
	_reply_scroll.resized.connect(_reveal_reply, CONNECT_DEFERRED)
	_fit_measure()
	_panel.visible = false
	_panel.modulate.a = 0.0


func _fit_measure() -> void:
	var view := get_viewport().get_visible_rect().size
	var side := mini(72, int(view.x * .075))
	var bottom := mini(34, int(view.y * .05))
	var separation := 6
	if view.y <= 400.0:
		side = mini(side, 16)
		bottom = mini(bottom, 6)
		separation = 2
	_column.add_theme_constant_override("separation", separation)
	_measure.add_theme_constant_override("margin_left", side)
	_measure.add_theme_constant_override("margin_right", side)
	_measure.add_theme_constant_override("margin_bottom", bottom)
	_line.custom_minimum_size.x = minf(COLUMN_WIDTH, maxf(1.0, view.x - 2 * side))
	_fit_spoken_line()
	_fit_replies()


func _fit_spoken_line() -> void:
	var view := get_viewport().get_visible_rect().size
	var name_height := _speaker.get_combined_minimum_size().y if _speaker.visible else 0.0
	var gaps := _column.get_theme_constant("separation") * (3 if _speaker.visible else 2)
	# Keep one reachable reply and leave the upper half of the shot for the face.
	var budget := view.y * .51 - name_height - gaps - 35.0 - _measure.get_theme_constant("margin_bottom")
	var size := LINE_SIZE
	var spacing := 3
	while not _line.text.is_empty() and budget >= SERIF.get_height(REPLY_SIZE):
		var height := SERIF.get_multiline_string_size(_line.text, HORIZONTAL_ALIGNMENT_LEFT,
				_line.custom_minimum_size.x, size).y
		var rows := maxi(1, roundi(height / SERIF.get_height(size)))
		if rows == 1 or height + (rows - 1) * spacing <= budget:
			break
		if spacing > 0:
			spacing = 0
		elif size > REPLY_SIZE:
			size -= 1
		elif spacing > -3:
			# The 17 px face has a 22.6 px line box. Keep at least 19.6 px
			# between baselines even for the longest spoken paragraph.
			spacing -= 1
		else:
			break
	_line.add_theme_constant_override("line_spacing", spacing)
	_line.add_theme_font_size_override("font_size", size)


func _fit_replies() -> void:
	# Reserve space for the visible question before giving the rest to replies.
	# Use the wrapped controls' measured height so short lists still fit exactly.
	var name_height := _speaker.get_combined_minimum_size().y if _speaker.visible else 0.0
	var gaps := _column.get_theme_constant("separation") * (3 if _speaker.visible else 2)
	var fixed := name_height + _line.get_combined_minimum_size().y + 1 + gaps
	var available := get_viewport().get_visible_rect().size.y * .49 - fixed - _measure.get_theme_constant("margin_bottom")
	_reply_scroll.custom_minimum_size.y = minf(_choices.get_combined_minimum_size().y, maxf(32.0, available))


func _reveal_reply() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if _panel.visible and focus != null and _choices.is_ancestor_of(focus):
		_reply_scroll.ensure_control_visible(focus)


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
	_replace_tree({})
	_on_flag = Callable()
	_on_action = Callable()
	_context = {}
	_present_line(speaker_name, words, options)


func _replace_tree(incoming: Dictionary) -> void:
	_line_exchange = {}
	var previous := _tree
	var interrupted := not current_node_id.is_empty() and not is_same(previous, incoming)
	_tree = incoming
	current_node_id = ""
	if interrupted:
		tree_replaced.emit(previous)


func _present_line(speaker_name: String, words: String, options: Array, delivery := "spoken") -> void:
	_line_delivery = delivery
	if _speaker_framing != null:
		_speaker_framing.release()
	_speaker.text = speaker_name
	_speaker.visible = speaker_name.strip_edges() != ""
	_line.text = words
	_fit_spoken_line()
	_set_replies(options)
	if not _panel.visible:
		_previous_mouse = Input.mouse_mode
	_panel.visible = true
	_fade_to(1.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = get_tree().get_first_node_in_group(
			"player_controller") as PlayerController
	if _player and not _player.protected_input_active():
		# A text lease can coexist with this panel but blocks background work.
		_player.call_locked = true
		_input_revision = _player.call_lock_revision
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Control).grab_focus()


func _set_replies(options: Array) -> void:
	for old in _choices.get_children():
		_choices.remove_child(old)
		old.queue_free()
	_actions = []
	_silence_index = -1
	var number := 0
	for option in options:
		var silent: bool = bool(option.get("silent", false))
		number += 1
		_actions.append(option)
		if silent:
			_silence_index = _actions.size() - 1
		var reply := _reply_button(number, str(option.text), silent,
				bool(option.get("evidence", false)), bool(option.get("infer", false)))
		reply.pressed.connect(_answer.bind(option))
		_choices.add_child(reply)
	var replies := _choices.get_children()
	for index in replies.size():
		# Explicit neighbours keep clipped rows in directional and tab navigation.
		var row := replies[index] as Button
		var previous := row.get_path_to(replies[posmod(index - 1, replies.size())])
		var following := row.get_path_to(replies[(index + 1) % replies.size()])
		row.focus_neighbor_top = previous
		row.focus_previous = previous
		row.focus_neighbor_bottom = following
		row.focus_next = following
	_reply_scroll.scroll_vertical = 0
	_fit_replies()


func _reply_button(number: int, text: String, silent: bool, evidence: bool,
		infer: bool) -> Button:
	var button := Button.new()
	var shortcut := "0" if silent else str(number) if number <= 9 else ""
	button.text = "%s   %s" % [shortcut, text]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func owns_exclusive_input(player: PlayerController) -> bool:
	return player == _player and is_instance_valid(player) and attention_active() \
			and _input_revision == player.call_lock_revision and player.protected_input_active() \
			and not is_instance_valid(player.text_input_owner) and not is_instance_valid(player.seated_interaction) \
			and not player.mouse_released and not player.inspecting()


func close() -> void:
	_line_exchange = {}
	if _speaker_framing != null:
		_speaker_framing.release()
	_panel.visible = false
	_panel.modulate.a = 0.0
	if _fade and _fade.is_valid():
		_fade.kill()
	if is_instance_valid(_player) and _input_revision == _player.call_lock_revision:
		_player.call_locked = false
	_input_revision = -1
	if not is_instance_valid(_player) or not _player.call_locked:
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
	elif key.keycode == KEY_0 and _silence_index >= 0:
		get_viewport().set_input_as_handled()
		choose_silence()


## --- authored dialogue tree ---------------------------------------------

## `context` may carry:
##   "available": Callable(choice: Dictionary) -> bool
##        a choice it refuses is not offered (requires / evidence)
##   "transaction_for": Callable(choice: Dictionary) -> Callable
##        optional sale that must succeed and owns the selected flag
##   "on_node_flag": Callable(flag: String)
##        a node's own `flag`, granted on arrival; falls back to on_flag(flag, 0)
func run_tree(tree: Dictionary, entry_id: String, on_flag: Callable,
		on_action := Callable(), context := {}) -> void:
	_replace_tree(tree)
	_on_flag = on_flag
	_on_action = on_action
	_context = context
	_show_node(entry_id)


func _show_node(node_id: String, exchange: Dictionary = {}, reply_guard := Callable()) -> void:
	var nodes: Dictionary = _tree.get("nodes", {})
	if not nodes.has(node_id):
		push_warning("case dialogue: missing node '%s'" % node_id)
		close()
		return
	current_node_id = node_id
	var node: Dictionary = nodes[node_id]
	if node.has("action") and _on_action.is_valid():
		_on_action.call(str(node.action))
	var node_flags: Array = []
	if str(node.get("flag", "")) != "":
		node_flags.append(str(node.flag))
	for extra in node.get("flags", []):
		node_flags.append(str(extra))
	for node_flag in node_flags:
		var on_node_flag: Callable = _context.get("on_node_flag", Callable())
		if on_node_flag.is_valid():
			on_node_flag.call(node_flag)
		elif _on_flag.is_valid():
			_on_flag.call(node_flag, 0)
	var default_speaker := str(_tree.get("meta", {}).get("speaker_default", ""))
	var speaker := str(node.get("speaker", default_speaker))
	_line_exchange = exchange
	_present_line(speaker, str(node.line), _node_options(node, reply_guard), str(node.get("delivery", "spoken")))
	var actor := str(node.get("actor", ""))
	# Ordinary, fallback and case trees have one known caller. A different
	# caption or anonymous voice never borrows that person's face.
	if not node.has("actor") and not speaker.is_empty() and speaker == default_speaker:
		actor = str(_context.get("framing_resident", ""))
	if _player != null and not actor.is_empty():
		if _speaker_framing == null:
			_speaker_framing = SpeakerFraming.new()
			add_child(_speaker_framing)
		_speaker_framing.begin(_player, actor, owns_exclusive_input)
	node_shown.emit(node_id)


func _node_options(node: Dictionary, reply_guard: Callable) -> Array:
	var available: Callable = _context.get("available", Callable())
	var transaction_for: Callable = _context.get("transaction_for", Callable())
	var options: Array = []
	for choice in node.get("choices", []):
		if available.is_valid() and not bool(available.call(choice)):
			continue
		var target: Dictionary = _tree.nodes.get(str(choice.get("goto", "")), {})
		var guard: Callable = target.get("reply_guard", reply_guard)
		var transaction := Callable()
		if transaction_for.is_valid():
			transaction = transaction_for.call(choice)
		options.append({"text": str(choice.label),
				"evidence": choice.has("evidence"),
				"infer": bool(choice.get("infer", false)),
				"admit": _admit_reply.bind(choice, guard, transaction, node, reply_guard),
				"action": _advance_action(choice, guard, transaction.is_valid())})
	if node.has("silence_goto"):
		var silence := {"goto": node.silence_goto, "flag": node.get("silence_flag", "")}
		if node.has("silence_trust"):
			silence["trust"] = node.silence_trust
		var target: Dictionary = _tree.nodes.get(str(silence.goto), {})
		var guard: Callable = target.get("reply_guard", reply_guard)
		options.append({"text": "Say nothing.", "silent": true, "admit": guard,
				"action": _advance_action(silence, guard, false)})
	if options.is_empty():
		options.append({"text": "...", "silent": true, "action": _end_tree})
	return options


func _admit_reply(choice: Dictionary, guard: Callable, transaction: Callable,
		node: Dictionary, reply_guard: Callable) -> bool:
	# An expired scene guard owns its cancellation, including releasing the cast.
	if guard.is_valid() and not bool(guard.call()):
		return false
	var available: Callable = _context.get("available", Callable())
	if (available.is_valid() and not bool(available.call(choice))) \
			or (transaction.is_valid() and not bool(transaction.call())):
		# Redraw just the choices. The current speech, node grants and camera lease persist.
		_set_replies(_node_options(node, reply_guard))
		(_choices.get_child(0) as Button).grab_focus()
		return false
	return true


func _advance_action(choice: Dictionary, guard: Callable, transacted: bool) -> Callable:
	var goto_id := str(choice.get("goto", ""))
	return func():
		# A flag implies one trust unless the reply says otherwise; a reply may
		# also move trust alone, as the inference and comfort replies do.
		var flag := str(choice.get("flag", ""))
		if not transacted and (flag != "" or choice.has("trust")) and _on_flag.is_valid():
			_on_flag.call(flag, int(choice.get("trust", 1)))
		if goto_id != "":
			# Only an offered reply can create this callback. Its reaction belongs
			# exclusively to the line that answering it puts on screen.
			var exchange := {}
			if bool(choice.get("infer", false)):
				exchange["inferred"] = true
			if choice.has("evidence"):
				exchange["evidence"] = true
			_show_node(goto_id, exchange, guard)
		else:
			_end_tree()


func _end_tree() -> void:
	_line_exchange = {}
	current_node_id = ""
	tree_ended.emit()


## Programmatic drivers, so tests can walk the tree without a mouse.
func choose(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	_answer(_actions[index])


func choose_silence() -> void:
	if attention_active():
		choose(_silence_index)


func _answer(option: Dictionary) -> void:
	if not attention_active() or not _actions.has(option):
		return
	var admit: Callable = option.get("admit", Callable())
	if admit.is_valid() and not bool(admit.call()):
		return
	var action: Callable = option.action
	var previous_tree := _tree
	var lens := _speaker_framing.reply_lens() if _speaker_framing != null else {}
	close()
	if action.is_valid():
		action.call()
	# The original choice callback sees the released panel/input as before.
	# Rejoin a retained shot before the next frame, only within this same tree.
	if previous_tree.is_empty() or not attention_active() or not is_same(previous_tree, _tree):
		return
	# The reader is already inside this exchange. Keep the next line legible
	# on its first frame, including when the player answers during the fade.
	if _fade and _fade.is_valid():
		_fade.kill()
	_panel.modulate.a = 1.0
	if not lens.is_empty():
		_speaker_framing.continue_reply(lens)


## The replies currently offered, in order, for tests and drivers.
func offered_labels() -> Array:
	var labels: Array = []
	for child in _choices.get_children():
		if child is Button:
			# The shortcut column is empty on rows reached by scrolling.
			var numbered: PackedStringArray = str(child.text).split("   ",true,1)
			labels.append(numbered[1] if numbered.size()==2 else str(child.text))
	return labels


## Read-only presentation snapshot for an actor face; dialogue remains owned here.
func displayed_line() -> Dictionary:
	return {"speaker": _speaker.text if _speaker != null else "",
		"text": _line.text if _line != null else "", "exchange": _line_exchange.duplicate(),
		"delivery": _line_delivery}
