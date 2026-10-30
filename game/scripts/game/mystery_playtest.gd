extends CanvasLayer
## The owner's first-draft reader for the mystery dialogue. Exists only when
## ORISON_MYSTERY_PLAYTEST=1. F9 opens it: set the date and time the threads read
## as, hold or drop any flag, and talk to anyone on the real conversation panel
## or print any companion line on the real set. It stands in for the things the
## world does not grant yet (the carriers, the dated visits, the people with no
## door). It writes no save, moves no clock and changes nothing a player sees
## without the variable.

const CARRIERS_PATH := "res://data/mystery/carriers.json"
const OBJECT_COPY_PATH := "res://data/mystery/object_copy.json"
const COMPANION_PATH := "res://data/mystery/companion_mystery.json"
const TOGGLE_KEY := KEY_F9

var conversations: ResidentConversations
var carriers: Dictionary = {}
var object_copy: Array = []
var companion_doc: Dictionary = {}
var _root: PanelContainer
var _date: LineEdit
var _time: LineEdit
var _people: ItemList
var _flags: ItemList
var _lines: ItemList
var _notes: RichTextLabel
var _people_ids: Array = []
var _flag_ids: Array = []
var _line_ids: Array = []
var _mouse_before := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	conversations = get_parent()
	RealityState.persistence_enabled = false
	conversations.playtest_holds = true
	conversations.playtest_date = "1929-07-22"
	conversations.playtest_minute = 12 * 60
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARRIERS_PATH))
	if parsed is Dictionary:
		carriers = parsed.get("carriers", {})
	parsed = JSON.parse_string(FileAccess.get_file_as_string(OBJECT_COPY_PATH))
	if parsed is Dictionary:
		object_copy = parsed.get("copy", [])
	parsed = JSON.parse_string(FileAccess.get_file_as_string(COMPANION_PATH))
	if parsed is Dictionary:
		companion_doc = parsed
	_build()
	_root.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == TOGGLE_KEY:
		_set_open(not _root.visible)
		get_viewport().set_input_as_handled()


func _set_open(value: bool) -> void:
	if value == _root.visible:
		return
	_root.visible = value
	get_tree().paused = value
	if value:
		_mouse_before = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh()
	else:
		Input.mouse_mode = _mouse_before


func _build() -> void:
	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var outer := VBoxContainer.new()
	_root.add_child(outer)
	var bar := HBoxContainer.new()
	outer.add_child(bar)
	bar.add_child(_caption("Date"))
	_date = LineEdit.new()
	_date.text = conversations.playtest_date
	_date.custom_minimum_size.x = 130
	bar.add_child(_date)
	bar.add_child(_caption("Time"))
	_time = LineEdit.new()
	_time.text = "12:00"
	_time.custom_minimum_size.x = 80
	bar.add_child(_time)
	_button(bar, "Apply", _apply)
	_button(bar, "Talk", _talk)
	_button(bar, "Print line", _print_line)
	_button(bar, "Forget mystery flags", _forget)
	_button(bar, "Close (F9)", func(): _set_open(false))
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)
	_people = _column(columns, "People: threads open now")
	_people.item_selected.connect(func(_i): _show_person())
	_flags = _column(columns, "Flags: click to hold or drop")
	_flags.item_selected.connect(_toggle_flag)
	_lines = _column(columns, "Companion lines")
	_lines.item_selected.connect(func(_i): _show_line())
	_notes = RichTextLabel.new()
	_notes.custom_minimum_size.y = 180
	_notes.selection_enabled = true
	outer.add_child(_notes)


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _column(parent: Node, title: String) -> ItemList:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	box.add_child(_caption(title))
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(list)
	return list


func _apply() -> void:
	var date := _date.text.strip_edges()
	var parts := _time.text.strip_edges().split(":")
	if date.length() != 10 or parts.size() != 2:
		_notes.text = "Date is YYYY-MM-DD and time is HH:MM."
		return
	conversations.playtest_date = date
	conversations.playtest_minute = int(parts[0]) * 60 + int(parts[1])
	_refresh()


func _all_flags() -> Array:
	var found := {}
	for flag in carriers:
		found[str(flag)] = true
	for record in conversations.mystery.values():
		for thread in record.threads:
			for flag in thread.get("requires", []):
				found[str(flag)] = true
		for node in record.nodes.values():
			if node.has("flag"):
				found[str(node.flag)] = true
			for flag in node.get("flags", []):
				found[str(flag)] = true
			for choice in node.get("choices", []):
				if choice.has("flag"):
					found[str(choice.flag)] = true
	var names := found.keys()
	names.sort()
	return names


func _refresh() -> void:
	_people.clear()
	_people_ids = conversations.mystery.keys()
	_people_ids.sort()
	for resident_id in _people_ids:
		var open := conversations.active_threads(resident_id, conversations.playtest_date,
				conversations.playtest_minute).size()
		var total: int = conversations.mystery[resident_id].threads.size()
		_people.add_item("%s  %d of %d" % [resident_id, open, total])
	_flags.clear()
	_flag_ids = _all_flags()
	for flag in _flag_ids:
		_flags.add_item(("[x] " if RealityState.has_knowledge(flag) else "[ ] ") + flag)
	_lines.clear()
	_line_ids.clear()
	for record: Dictionary in companion_doc.get("lines", []):
		_line_ids.append(str(record.id))
		_lines.add_item("%s  (%s)" % [record.id, record.surface])
	for item: Dictionary in object_copy:
		_lines.add_item("%s  (object, read only)" % item.id)
		_line_ids.append(str(item.id))


func _show_person() -> void:
	var resident_id: String = _people_ids[_people.get_selected_items()[0]]
	var record: Dictionary = conversations.mystery[resident_id]
	var text := "%s\n[%s, %s] %s\n" % [record.meta.speaker_default, record.meta.status,
			record.meta.voice_status, record.meta.notes]
	for thread in record.threads:
		text += "\n%s  %s to %s  %s  %s  needs %s  hold %s\n    %s" % [thread.id, thread.from,
				thread.until, thread.get("hours", "any hour"), thread.topic,
				thread.get("requires", []), thread.get("hold", "no"), thread.source]
	_notes.text = text


func _toggle_flag(index: int) -> void:
	var flag: String = _flag_ids[index]
	if RealityState.has_knowledge(flag):
		RealityState.data.knowledge_flags.erase(flag)
	else:
		RealityState.grant_knowledge(flag)
	_notes.text = str(carriers.get(flag, flag))
	_refresh()


func _show_line() -> void:
	var id: String = _line_ids[_lines.get_selected_items()[0]]
	for item: Dictionary in object_copy:
		if str(item.id) == id:
			_notes.text = JSON.stringify(item, "  ")
	for record: Dictionary in companion_doc.get("lines", []):
		if str(record.id) != id:
			continue
		var movement := {}
		for candidate: Dictionary in companion_doc.get("movements", []):
			if candidate.id == record.movement:
				movement = candidate
		_notes.text = "%s\n\nType: %s\nWitness: %s\nNeeds: %s  Bank: %s\nNote: %s %s\n%s: %s\nMovement: %s (%s). %s\nHouse rules: %s %s %s" % [
				record.text, record.get("phrases", "printed by a witness"), record.get("witness", "none"),
				record.get("requires", []), record.get("bank", "none"), record.get("note", ""),
				record.get("delay", ""), record.surface, companion_doc.surfaces.get(record.surface, ""),
				movement.get("title", ""), movement.get("span", ""), movement.get("job", ""),
				companion_doc.status, companion_doc.voice, companion_doc.silence_rule]


func _talk() -> void:
	var selected := _people.get_selected_items()
	if selected.is_empty():
		_notes.text = "Pick a person first."
		return
	var resident_id: String = _people_ids[selected[0]]
	_set_open(false)
	if not conversations.start_mystery(resident_id):
		_set_open(true)
		_notes.text = "%s has no thread open on this date and time with these flags." % resident_id


func _print_line() -> void:
	var selected := _lines.get_selected_items()
	if selected.is_empty():
		_notes.text = "Pick a companion line first."
		return
	var session := _session()
	var id: String = _line_ids[selected[0]]
	_set_open(false)
	if session == null or not session.deliver_event(id):
		var state := _set_state(session)
		_set_open(true)
		_notes.text = "%s did not print. %s Each line prints once." % [id, state]


func _set_state(session: Node) -> String:
	if session == null:
		return "No set is carried yet."
	var carrier: Node = session.get_parent()
	return "powered=%s printing=%s arm_busy=%s typing=%s opening=%s available=%s." % [
			carrier.device.radio_powered, carrier.device.teletype.printing, carrier.arm_busy(),
			session.typing, session.opening, session.available()]


func _forget() -> void:
	for flag: String in RealityState.data.get("knowledge_flags", []).duplicate():
		if flag.begins_with(ResidentConversations.MYSTERY_FLAG_PREFIX) \
				or flag.begins_with(ResidentConversations.MYSTERY_HEARD_PREFIX):
			RealityState.data.knowledge_flags.erase(flag)
	_refresh()


func _session() -> Node:
	var player: Node = get_tree().get_first_node_in_group("player_controller")
	if not is_instance_valid(player):
		return null
	var carrier: Variant = player.get("carried_device")
	return carrier.get("session") if is_instance_valid(carrier) else null
