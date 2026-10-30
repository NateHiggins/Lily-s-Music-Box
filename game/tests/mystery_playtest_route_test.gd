extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## The owner's reader in the production V2 root: F9 opens the playtest panel, a
## date and a flag change what is open, Talk reaches the real conversation panel
## for someone with no door, and Print line reaches the real carried set.

const PLAYTEST := preload("res://scripts/game/mystery_playtest.gd")

func _init() -> void:
	route_label = "MYSTERY PLAYTEST ROUTE"
	OS.set_environment(ResidentConversations.PLAYTEST_ENV, "1")

func _prepare_player_start() -> void:
	player.velocity = Vector3.ZERO

func _toggle(reader: CanvasLayer) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F9
	key.pressed = true
	reader._unhandled_key_input(key)

func _route() -> void:
	var conversations: ResidentConversations = world.conversations
	if not _require(conversations != null and conversations.errors.is_empty(),
			"conversations mounted without tree errors"): return
	var reader: CanvasLayer = null
	for child in conversations.get_children():
		if child.get_script() == PLAYTEST:
			reader = child
	if not _require(reader != null, "the variable mounts the reader"): return
	_toggle(reader)
	if not _require(reader._root.visible and get_tree().paused, "F9 opens the reader and pauses"): return
	reader._date.text = "1929-07-22"
	reader._time.text = "12:00"
	reader._apply()
	var person: int = reader._people_ids.find("emil_voss")
	_require(person >= 0 and str(reader._people.get_item_text(person)).contains("1 of 1"),
			"Emil's thread is open on the date and hour set")
	_require(reader._line_ids.has("m_notice_1"), "the companion lines are listed")
	reader._people.select(person)
	reader._show_person()
	await _capture_interaction("mystery_playtest_reader")
	reader._talk()
	var panel: CaseDialoguePanel = conversations.dialogue
	await get_tree().create_timer(0.4).timeout
	_require(not reader._root.visible and not get_tree().paused, "Talk closes the reader and unpauses")
	_require(panel.attention_active() and panel.offered_labels().size() > 0,
			"a person with no door opens on the real panel")
	_require(panel.offered_labels().has("Can I help you with those?"), "with the thread's topic")
	panel.choose(panel.offered_labels().find("Can I help you with those?"))
	await get_tree().create_timer(0.4).timeout
	_require(panel.current_node_id != "" and panel.current_node_id != ResidentConversations.MYSTERY_MENU,
			"the topic reaches the thread")
	await _capture_interaction("mystery_playtest_conversation")
	while panel.current_node_id != "":
		panel.choose(0)
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_require(RealityState.has_knowledge("mt:ev_home"), "the reader's talk marks the thread heard")
	if player.carried_device != null:
		var session: Node = player.carried_device.session
		var waited := 0.0
		while waited < 45.0 and (not session.available() or player.carried_device.device.teletype.printing):
			await get_tree().create_timer(0.5).timeout
			waited += 0.5
		print("[MYSTERY PLAYTEST] set free after ", waited, "s: ", reader._set_state(session))
		_toggle(reader)
		reader._lines.select(reader._line_ids.find("m_notice_1"))
		reader._show_line()
		_require(str(reader._notes.text).contains("Witness:"), "a line shows its gates")
		reader._print_line()
		await get_tree().create_timer(0.4).timeout
		_require(not reader._root.visible, "Print line reaches the real set: " + str(reader._notes.text))
		if reader._root.visible:
			_toggle(reader)
		await _capture_interaction("mystery_playtest_print")
