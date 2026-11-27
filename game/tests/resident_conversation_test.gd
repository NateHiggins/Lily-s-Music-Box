extends Node
## The threshold conversations, driven without a mouse: trees load and
## validate; a knock reaches whoever is home; the entry climbs with trust;
## `requires` hides a reply until the knowledge flag exists; `evidence` hides a
## reply until the player stands in the flat; a node's own flag is granted on
## arrival; flags and trust live on RealityState; no case is ever activated.

var _fails := 0
var _unit := ""
var _home := true


class StubDevice extends Node:
	var powered := true
	var printed: Array = []
	func radio_is_powered() -> bool:
		return powered
	func print_telegram_card(card: Variant) -> bool:
		printed.append(card)
		return true


class StubPlayer extends Node:
	var carried_device: Node


func _check(label: String, ok: bool) -> void:
	print("RESIDENT CONVERSATION: ", label, " = ", ok)
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	await _run()
	await _check_reply_layout()
	await _check_speaker_framing()
	print("RESIDENT CONVERSATION TEST: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check_delivery_validation(director: ResidentConversations) -> void:
	var validator := ResidentConversations.new()
	for mystery: bool in [false, true]:
		var book: Dictionary = director.mystery if mystery else director.trees
		var tree: Dictionary = book["adela_voss"].duplicate(true)
		var validate := Callable(validator, "_valid_mystery" if mystery else "_valid_tree")
		var id := "av_o54" if mystery else "ad_int_beat"
		var node: Dictionary = tree.nodes[id]
		tree.meta["delivery"] = "ignored metadata"
		for field: Variant in [null, "spoken", "silent", "silnt", false]:
			if field == null:
				node.erase("delivery")
			else:
				node["delivery"] = field
			validator.errors.clear()
			var accepted := bool(validate.call(tree, "fixture"))
			var expected: bool = field == null or field in ["spoken", "silent"]
			_check("node delivery %s in %s" % [str(field), id], accepted == expected
					and (accepted or validator.errors.has("fixture: node %s delivery must be spoken or silent" % id)))
	validator.free()


func _run() -> void:
	var panel := CaseDialoguePanel.new()
	add_child(panel)
	var director := ResidentConversations.new()
	add_child(director)
	director.setup(panel, func(): return _unit, func(_id): return _home)
	await get_tree().process_frame

	_check("every authored tree loads without an error",
			director.errors.is_empty() and director.resident_ids() == [
				"adela_voss", "cal_dwyer", "cam_ortiz", "evelyn_marsh", "iris_bell", "jonah_price", "juno_kells",
				"lena_ortiz", "lily", "mae_kessler", "malcolm_reed", "nadia_quell", "noel_price", "omar_bell",
				"peter_wren", "rhea_sato", "sacha_reed", "stacy", "teresa_vale", "transient_guests"])
	if not director.errors.is_empty():
		for line in director.errors:
			print("  tree error: ", line)
	_check_delivery_validation(director)
	_check("trees are keyed by resident", director.has_tree("peter_wren")
			and director.has_tree("transient_guests") and not director.has_tree("mina_vale"))
	_check("doors know their tenants", director.residents_in("4C") == ["cam_ortiz", "noel_price"]
			and director.unit_of("peter_wren") == "4A")

	# --- the knock -----------------------------------------------------------
	_home = false
	var nobody: Dictionary = director.knock("4A")
	_check("a knock on an empty flat files a slip and opens nothing",
			str(nobody.get("body", "")).contains("NO ANSWER") and not panel.attention_active())
	_check("the first unanswered knock is the handheld note about hours",
			str(nobody.get("body", "")).contains("THEY KEEP HOURS") and str(nobody.get("title", "")) == "UNIT 4A"
			and RealityState.has_knowledge("note:first_knock_unanswered"))
	var again: Dictionary = director.knock("4A")
	_check("the second unanswered knock is the plain slip",
			str(again.get("body", "")).contains("NO ANSWER") and not str(again.get("body", "")).contains("HOURS"))
	for note_id in director.notes:
		var widest := 0
		for line in str(director.field_note(note_id, "4A").body).split("\n"):
			widest = maxi(widest, line.length())
		_check("note %s fits the printer's thirty columns" % note_id, widest <= 30)
	var required_notes := ["first_conversation", "first_knock_unanswered", "uniform_wants_mending", "uniform_wants_washing"]
	_check("all four field notes loaded", required_notes.all(func(id: String) -> bool: return director.notes.has(id))
			and director.notes.size() == required_notes.size())
	_home = true
	_check("a knock on an occupied flat opens the conversation",
			director.knock("4A").is_empty() and panel.attention_active()
			and panel.current_node_id == "pw_open")
	_check("the case stays unseen: no door activates a case",
			str(RealityState.case_state("peter_form_corridor").get("stage", "unseen")) == "unseen"
			and RealityState.data.current_case_id == "")
	var offered: Array = panel.offered_labels()
	_check("an evidence reply is withheld outside the flat",
			not _has(offered, "[the staging table]") and _has(offered, "Say nothing."))
	panel.close()
	panel.current_node_id = ""

	# --- evidence inside the flat, and a node flag on arrival -------------------
	_unit = "4A"
	_check("a second knock opens again at first contact",
			director.knock("4A").is_empty() and panel.current_node_id == "pw_open")
	offered = panel.offered_labels()
	_check("the evidence reply appears when the player stands in 4A",
			_has(offered, "[the staging table]"))
	_check("a fresh conversation starts with its entrance fade", is_zero_approx(panel._panel.modulate.a))
	var events: Array[String] = []
	var on_show := func(id: String): events.append(id)
	var on_end := func(): events.append("ended")
	panel.node_shown.connect(on_show)
	panel.tree_ended.connect(on_end)
	var line := panel.displayed_line()
	_unit = ""
	var stale_evidence := panel._choices.get_child(_index(offered, "[the staging table]")) as Button
	stale_evidence.pressed.emit()
	_check("leaving Peter's flat rejects the stale button without replaying the node",
			panel.attention_active() and panel.current_node_id == "pw_open" and panel.displayed_line() == line
			and events.is_empty() and not _has(panel.offered_labels(), "[the staging table]")
			and _has(panel.offered_labels(), "Say nothing.") and RealityState.resident_trust("peter_wren") == 0)
	stale_evidence.pressed.emit()
	_check("the detached button cannot answer the refreshed menu", events.is_empty())
	_check("rejecting the stale reply leaves Peter at two visits",
			RealityState.conversation_visits("peter_wren") == 2)
	panel.node_shown.disconnect(on_show)
	panel.tree_ended.disconnect(on_end)
	panel.close()
	panel.current_node_id = ""
	_unit = "4A"
	_check("reopening the flat for the evidence reply records the third visit",
			director.knock("4A").is_empty() and panel.current_node_id == "pw_open"
			and RealityState.conversation_visits("peter_wren") == 3)
	offered = panel.offered_labels()
	panel.choose(_index(offered, "[the staging table]"))
	_check("the table leads to the stations", panel.current_node_id == "pw_table")
	_check("the evidence reply is readable on its first frame", is_equal_approx(panel._panel.modulate.a, 1.0))
	await get_tree().process_frame
	_check("the entrance tween cannot dim the reply again", is_equal_approx(panel._panel.modulate.a, 1.0))
	panel.choose(_index(panel.offered_labels(), "'The other matter.'"))
	panel.choose(_index(panel.offered_labels(), "What was the filing?"))
	_check("reaching the appeal grants the node's own flag",
			panel.current_node_id == "pw_spring" and RealityState.has_knowledge("peter_gap_found"))
	offered = panel.offered_labels()
	_check("a reply that requires Mina's four seconds is hidden until known",
			not _has(offered, "Someone in this building has a gap like that."))
	panel.choose(_index(offered, "An irregularity in the record. A gap?"))
	_check("an inference reply earns trust", panel.current_node_id == "pw_gap"
			and RealityState.resident_trust("peter_wren") == 1)
	offered = panel.offered_labels()
	_check("the cross-flat reply is still hidden in 4A's own tree",
			not _has(offered, "Someone in this building has a gap like that."))
	RealityState.grant_knowledge("mina_four_seconds")
	panel.choose(_index(offered, "Show me the fault."))
	_check("knowledge granted elsewhere unlocks nothing retroactively on a node already shown",
			panel.current_node_id == "pw_corridor")
	panel.close()
	panel.current_node_id = ""

	# --- trust moves the entry; the integration beat happens once ---------------
	RealityState.add_resident_trust("peter_wren", 2)
	_check("three trust opens real talk", director.entry_for("peter_wren") == "real_talk")
	RealityState.add_resident_trust("peter_wren", 3)
	_check("six trust offers the integration beat", director.entry_for("peter_wren") == "integration")
	_check("the integration entry starts at its node",
			director.start("peter_wren") and panel.current_node_id == "pw_int_open")
	panel.close()
	panel.current_node_id = ""
	_check("after integration the resident is resolved for good",
			director.entry_for("peter_wren") == "resolved"
			and RealityState.has_knowledge("peter_wren:integration"))

	# --- the first conversation's handheld note -------------------------------------
	var stub_player := StubPlayer.new()
	var stub_device := StubDevice.new()
	stub_player.carried_device = stub_device
	add_child(stub_player)
	add_child(stub_device)
	stub_device.powered = false
	_check("a dead set prints nothing and the note stays pending",
			not director.file_note("first_conversation", stub_player)
			and director.note_pending("first_conversation") and stub_device.printed.is_empty())
	stub_device.powered = true
	_check("a powered set prints the note once",
			director.file_note("first_conversation", stub_player)
			and stub_device.printed.size() == 1
			and str(stub_device.printed[0].get("body", "")).contains("NOUGHT IS ALSO AN ANSWER")
			and not director.file_note("first_conversation", stub_player)
			and stub_device.printed.size() == 1)
	_check("ending a conversation files it through the knock's player",
			not director.note_pending("first_conversation"))

	# --- the campaign remembers --------------------------------------------------
	var snapshot: Dictionary = RealityState.data.duplicate(true)
	_check("knowledge, trust and visits are in the saved campaign document",
			"peter_gap_found" in snapshot.knowledge_flags
			and int(snapshot.resident_trust.peter_wren) == 6
			and int(snapshot.conversation_visits.peter_wren) == 4)
	_check("the saved shape still validates", RealityState._validate_document(snapshot).ok)

	# --- a soured first contact falls back -------------------------------------------
	RealityState.add_resident_trust("cal_dwyer", -1)
	RealityState.record_conversation_visit("cal_dwyer")
	_check("a resident spoken to and distrusted falls back", director.entry_for("cal_dwyer") == "fallback")

	# --- two residents behind one door alternate ----------------------------------------
	_unit = ""
	_check("the first knock on 4C reaches whoever has been spoken to least",
			director.knock("4C").is_empty() and panel.current_node_id in ["co_open", "np_open"])
	var first := panel.current_node_id
	panel.close()
	panel.current_node_id = ""
	director.knock("4C")
	_check("the second knock on 4C reaches the other tenant",
			panel.current_node_id != first and panel.current_node_id in ["co_open", "np_open"])
	panel.close()

	# --- Stacy's second cup is poured once, and stays poured across a reload ----------
	RealityState.add_resident_trust("stacy", 3)
	_check("Stacy's quiet route offers the cup the first time", _stacy_quiet_route(director, panel) == "st_rt_cup"
			and RealityState.has_knowledge("st_second_cup"))
	_check("the second time the glasses are dried without the cup",
			_stacy_quiet_route(director, panel) == "st_rt_quiet")
	var original_save: String = RealityState.save_path
	RealityState.save_path = "user://tests/stacy_cup_%d.json" % OS.get_process_id()
	RealityState.persistence_enabled = true
	_check("the poured cup is saved", RealityState.save_game())
	RealityState.load_game()
	RealityState.persistence_enabled = false
	RealityState.save_path = original_save
	_check("after a reload the cup is still not offered", RealityState.has_knowledge("st_second_cup")
			and _stacy_quiet_route(director, panel) == "st_rt_quiet")

	# --- dated opinions: the news grafted onto the tree ------------------------------
	RealityState.reset_campaign_for_tests()
	var saved_opinions: Dictionary = director.opinions.duplicate(true)
	director.opinions["peter_wren"] = {"resident_id": "peter_wren", "hook": "You've seen the paper.",
			"hook_line": "Which part?", "opinions": [
		{"id": "pw_op_t1", "from": "1928-11-10", "until": "1928-11-20", "topic": "The count.",
			"line": "A count is a form with arithmetic in it.",
			"choices": [{"label": "You'd have counted it once.", "reply": "Once, and signed.", "trust": 1}],
			"silence_reply": "Quite."},
		{"id": "pw_op_t2", "from": "1928-11-15", "until": "1928-11-30", "topic": "The clerk.",
			"line": "The clerk swore. Swearing is a form.", "choices": [{"label": "Go on.", "reply": "I shall not."}]},
		{"id": "pw_op_t3", "from": "1928-11-18", "until": "1928-11-30", "topic": "The seal.",
			"requires": ["op:pw_op_t1"], "line": "Sealed, like a decision.",
			"choices": [{"label": "Like yours.", "reply": "Like mine.", "trust": 1}]}]}
	_check("an opinion is live only inside its window",
			director.active_opinions("peter_wren", "1928-11-10").size() == 1
			and director.active_opinions("peter_wren", "1928-12-01").is_empty()
			and director.active_opinions("peter_wren", "").is_empty())
	var plain: Dictionary = director.trees["peter_wren"]
	var one := director.with_opinions("peter_wren", plain, "1928-11-10")
	var entry_node: Dictionary = one.nodes[one.entries.first_stable]
	_check("one live opinion: the entry gains the hook straight to it",
			entry_node.choices.any(func(c): return c.label == "You've seen the paper." and c.goto == "op:pw_op_t1")
			and one.nodes.has("op:pw_op_t1") and one.nodes["op:pw_op_t1"].flag == "op:pw_op_t1"
			and not plain.nodes.has("op:pw_op_t1"))
	_check("the grafted reply answers and returns to the door",
			one.nodes["op:pw_op_t1:r0"].line == "Once, and signed."
			and one.nodes["op:pw_op_t1:r0"].choices[0].goto == one.entries.first_stable
			and one.nodes["op:pw_op_t1"].silence_goto == "op:pw_op_t1:s")
	var two := director.with_opinions("peter_wren", plain, "1928-11-16")
	_check("two live opinions: the hook opens a menu of topics",
			two.nodes.has(ResidentConversations.OPINION_MENU)
			and two.nodes[ResidentConversations.OPINION_MENU].choices.size() == 2
			and two.nodes[two.entries.real_talk].choices.any(func(c): return c.goto == ResidentConversations.OPINION_MENU))
	_check("a later opinion waits for the earlier one to be heard",
			not director.active_opinions("peter_wren", "1928-11-19").any(func(o): return o.id == "pw_op_t3"))
	_unit = ""
	director.start("peter_wren")
	var seen_hook := _index(panel.offered_labels(), "You've seen the paper.")
	_check("the live tree offers the hook at the door (campaign date permitting)",
			director.today() == "" or seen_hook >= 0)
	panel.close()
	panel.current_node_id = ""
	RealityState.grant_knowledge("op:pw_op_t1")
	var later := director.active_opinions("peter_wren", "1928-11-19")
	_check("heard opinions do not return, and the one that built on it opens",
			not later.any(func(o): return o.id == "pw_op_t1") and later.any(func(o): return o.id == "pw_op_t3"))
	_check("an opinions record without a hook is refused",
			not director._valid_opinions({"opinions": []}, "test")
			and not director._valid_opinions({"hook": "x", "opinions": [{"id": "a", "from": "1929-01-02",
				"until": "1929-01-01", "topic": "t", "line": "l"}]}, "test"))
	director.opinions = saved_opinions
	director.errors.clear()

	# --- the presentation -----------------------------------------------------------------
	panel.present("TEST", "A line.", [{"text": "One", "action": Callable()},
			{"text": "Two", "action": Callable(), "silent": true}])
	await get_tree().process_frame
	_check("replies are numbered plain lines, silence set apart",
			panel.offered_labels() == ["One", "Two"] and panel._choices.get_child(1).text.begins_with("0   "))
	_check("the panel lowers the scrim, never a box over the view",
			panel._scrim.anchor_top > 0.5 and panel._line.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and panel._line.get_theme_font_size("font_size") >= 20)
	var quiet_key := InputEventKey.new()
	quiet_key.keycode = KEY_0
	quiet_key.pressed = true
	panel._unhandled_input(quiet_key)
	_check("zero closes a silent leave option even when it has no callback", not panel.attention_active())
	panel.present("TEST", "A spoken choice only.", [{"text": "Reply.", "action": Callable()}])
	panel.choose_silence()
	_check("an unavailable silent reply leaves the current prompt open", panel.attention_active())
	panel.close()


func _check_reply_layout() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var panel := CaseDialoguePanel.new()
	viewport.add_child(panel)
	panel.present("PETER WREN", "Before you touch anything. Is there a form for what you are about to do? There is usually a form. I would feel better if we had the form first.", [
		{"text": "There's a work order. That's the form.", "action": Callable()},
		{"text": "What happens if we start without it?", "action": Callable()},
		{"text": "Is that returned post?", "action": Callable()},
		{"text": "The weather at your window.", "action": Callable()},
		{"text": "Need anything from the shops?", "action": Callable()},
		{"text": "Say nothing.", "action": Callable(), "silent": true},
	])
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		viewport.size = size
		for frame in 3:
			await get_tree().process_frame
		var visible := viewport.get_visible_rect()
		var last_reply := panel._choices.get_child(5) as Button
		_check("sixth reply at %s retains the bottom margin" % size,
				last_reply.get_global_rect().end.y <= visible.end.y - 34.0)
		_check("dialogue at %s sits below the centre" % size,
				panel._column.get_global_rect().position.y > visible.get_center().y)
	await _check_long_replies(viewport, panel)
	panel.close()
	viewport.queue_free()


## The same bar line and dated topics seen stacked in the installed Adela proof.
## Presentation-only fixture: availability remains the conversation owner's job.
func _check_long_replies(viewport: SubViewport, panel: CaseDialoguePanel) -> void:
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/adela_voss.json"))
	var mystery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/mystery/adela_voss.json"))
	var line: Dictionary = book.nodes.ad_singing
	var labels: Array[String] = [str(line.choices[0].label)]
	for thread: Dictionary in mystery.threads:
		labels.append(str(thread.topic))
		if labels.size() == 14: break
	labels.append("Say nothing.")
	var chosen: Array[String] = []
	var options := []
	for label: String in labels:
		options.append({"text": label, "action": func(): chosen.append(label), "silent": label == "Say nothing."})
	for size: Vector2i in [Vector2i(960, 540), Vector2i(640, 360)]:
		viewport.size = size
		panel.present("ADELA", str(line.line), options)
		for frame in 5: await get_tree().process_frame
		var rect := panel._reply_scroll.get_global_rect()
		var speaker := panel._speaker.get_global_rect()
		var words := panel._line.get_global_rect()
		_check("long replies keep speaker and line visible at %s" % size, speaker.position.y >= size.y * .48
				and words.end.y <= rect.position.y and words.end.x <= size.x and rect.end.y <= size.y)
		_check("all authored labels are available at %s" % size, panel.offered_labels() == labels
				and panel._reply_scroll.get_v_scroll_bar().visible and panel._reply_scroll.scroll_vertical == 0)
		_check("shortcut labels match the available number keys at %s" % size,
				panel._choices.get_child(8).text.begins_with("9   ")
				and panel._choices.get_child(9).text == "   " + labels[9]
				and panel._choices.get_child(-1).text == "0   " + labels.back())
		var move := InputEventMouseMotion.new()
		move.position = rect.get_center()
		viewport.push_input(move, true)
		var wheel := InputEventMouseButton.new()
		wheel.position = move.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		viewport.push_input(wheel, true)
		await get_tree().process_frame
		_check("wheel scrolls the replies at %s" % size, panel._reply_scroll.scroll_vertical > 0)
		var all_reached := true
		for index in range(1, labels.size()):
			# Alternate the default keyboard and controller down bindings.
			var input: InputEvent
			if index % 2:
				var key := InputEventKey.new()
				key.keycode = KEY_DOWN
				key.pressed = true
				input = key
			else:
				var pad := InputEventJoypadButton.new()
				pad.button_index = JOY_BUTTON_DPAD_DOWN
				pad.pressed = true
				input = pad
			viewport.push_input(input, true)
			input.set("pressed", false)
			viewport.push_input(input, true)
			await get_tree().process_frame
			var row := panel._choices.get_child(index) as Button
			var bounds := row.get_global_rect()
			all_reached = all_reached and viewport.gui_get_focus_owner() == row \
					and bounds.position.y >= rect.position.y - 1 and bounds.end.y <= rect.end.y + 1
		_check("directional focus reveals every row including silence at %s" % size, all_reached
				and panel._speaker.get_global_rect() == speaker and panel._line.get_global_rect() == words)
		var accept := InputEventKey.new()
		accept.keycode = KEY_ENTER
		accept.pressed = true
		viewport.push_input(accept, true)
		accept.pressed = false
		viewport.push_input(accept, true)
		_check("focused last reply activates at %s" % size, not chosen.is_empty() and chosen.back() == labels.back()
				and not panel.attention_active())
		chosen.clear()
		for digit: int in [KEY_1, KEY_9, KEY_0]:
			panel.present("ADELA", str(line.line), options)
			var shortcut := InputEventKey.new()
			shortcut.keycode = digit
			shortcut.pressed = true
			viewport.push_input(shortcut, true)
			_check("shortcut %s preserves its authored reply at %s" % [digit, size], not chosen.is_empty()
					and chosen.back() == labels[-1 if digit == KEY_0 else digit - KEY_1])
			chosen.clear()


static func _has(labels: Array, text: String) -> bool:
	for label in labels:
		if str(label).contains(text):
			return true
	return false


## Real talk with Stacy, silent at the open, then drying glasses. Returns where it lands.
func _stacy_quiet_route(director: ResidentConversations, panel: CaseDialoguePanel) -> String:
	if not director.start("stacy") or panel.current_node_id != "st_rt_open":
		return "no real talk: " + panel.current_node_id
	panel.choose_silence()
	var labels: Array = panel.offered_labels()
	var dry := _index(labels, "[Dry glasses.]")
	if panel.current_node_id != "st_rt_sil" or dry < 0 			or labels.filter(func(label): return str(label).contains("[Dry glasses.]")).size() != 1:
		return "no single dry choice: " + panel.current_node_id
	panel.choose(dry)
	var landed := panel.current_node_id
	panel.close()
	panel.current_node_id = ""
	return landed


static func _index(labels: Array, text: String) -> int:
	for i in labels.size():
		if str(labels[i]).contains(text):
			return i
	return -1

class LensPlayer extends PlayerController:
	func _ready() -> void:
		camera = Camera3D.new()
		add_child(camera)
		camera.make_current()
		add_to_group("player_controller")
		set_physics_process(false)
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)


class LensResident extends Node3D:
	var resident_id := "stacy"

	func _ready() -> void:
		add_to_group("animated_residents")
		var skeleton := Skeleton3D.new()
		skeleton.add_bone("Head")
		add_child(skeleton)


func _check_speaker_framing() -> void:
	var previous_mouse := Input.mouse_mode
	var player := LensPlayer.new()
	add_child(player)
	player.camera.fov = 76.0
	var player_pose := player.global_transform
	var eye_pose := player.camera.transform
	var actor := LensResident.new()
	actor.position = Vector3(0.0, 0.0, -2.1)
	add_child(actor)
	var panel := CaseDialoguePanel.new()
	add_child(panel)
	var director := ResidentConversations.new()
	add_child(director)
	director.setup(panel)
	_check("ordinary Stacy dialogue opens", director.start("stacy"))
	for tick in 8:
		await get_tree().physics_frame
	_check("the ordinary authored speaker uses the same bounded lens", player.camera.fov < 76.0)
	# A replacement panel can take ownership before the former conversation
	# ends. An anonymous intercom announcement carries no physical face.
	panel.run_tree({"meta": {"speaker_default": "STACY"}, "nodes": {
		"announcement": {"speaker": "INTERCOM", "line": "Stand by."}
	}}, "announcement", Callable(), Callable(), {"framing_resident": "stacy"})
	for tick in 4:
		await get_tree().physics_frame
	_check("another voice restores the lens without stealing the replacement panel",
			is_equal_approx(player.camera.fov, 76.0) and panel.attention_active() and player.call_locked)
	director.cancel_for_transition()
	_check("old conversation cancellation leaves replacement input ownership intact", player.call_locked)
	panel.close()
	_check("replacement closes to the mouse mode owned before the exchange", Input.mouse_mode == previous_mouse)
	var lines := [{"speaker": "stacy", "text": "Here."}, {"speaker": "stacy", "text": "Still here."},
			{"speaker": "lily", "text": "Across the room."}]
	_check("loop performance opens on the speaking resident", director.start_performance_sequence("stacy", lines, player))
	for tick in 12:
		await get_tree().physics_frame
	_check("a visible speaker gets a bounded push from the caller's original lens",
			player.camera.fov >= 69.0 and player.camera.fov < 76.0)
	_check("framing preserves the player's camera, aim, position and existing dialogue lock",
			player.camera.is_current() and player.call_locked and player.global_transform == player_pose
			and player.camera.transform == eye_pose)
	var held_lens := player.camera.fov
	panel.choose(0)
	_check("the next line from the same body keeps the caller's lens between frames",
			panel.current_node_id == "loop_business_1" and is_equal_approx(player.camera.fov, held_lens))
	await get_tree().physics_frame
	_check("the retained shot continues smoothly", player.camera.fov <= held_lens)
	panel.choose(0)
	_check("an absent second speaker immediately restores the original shot",
			panel.current_node_id == "loop_business_2" and is_equal_approx(player.camera.fov, 76.0))
	director.cancel_for_transition()
	_check("transition restores ordinary player input", not player.call_locked)
	for scripted: bool in [false, true]:
		var opened := director.start_performance_sequence("stacy", lines, player) if scripted else director.start("stacy")
		_check("resident owns the panel before the service prompt", opened)
		var before := RealityState.data.duplicate(true)
		var answered := [false]
		panel.present("SERVICE", "One moment.", [{"text": "Ready.", "action": func(): answered[0] = true}])
		_check("standalone prompt immediately releases the resident and clears her former node",
				director._active_resident.is_empty() and not director.performance_active() and panel.current_node_id.is_empty())
		director.cancel_for_transition()
		_check("former conversation leaves the service prompt, input and campaign intact",
				panel.attention_active() and player.call_locked and panel.offered_labels() == ["Ready."] and before == RealityState.data)
		panel.choose(0)
		_check("the service prompt receives its own reply and releases input", answered[0] and not player.call_locked)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	wall.add_child(shape)
	wall.position.z = -1.0
	add_child(wall)
	await get_tree().physics_frame
	_check("occluded exchange still opens", director.start_performance_sequence("stacy", lines, player))
	for tick in 4:
		await get_tree().physics_frame
	_check("a wall between player and eyes keeps the original lens", is_equal_approx(player.camera.fov, 76.0))
	director.cancel_for_transition()
	wall.free()
	await get_tree().physics_frame
	director.start_performance_sequence("stacy", lines, player)
	for tick in 4:
		await get_tree().physics_frame
	_check("speaker lens engaged before protected input changes hands", player.camera.fov < 76.0)
	player.call_locked = true
	for tick in 2:
		await get_tree().physics_frame
	_check("successor input restores the entry shot while the old panel remains visible",
			panel.attention_active() and player.call_locked and is_equal_approx(player.camera.fov, 76.0))
	director.cancel_for_transition()
	_check("retiring the speaker leaves the new input owner in control", player.call_locked)
	player.call_locked = false
	director.start_performance_sequence("stacy", lines, player)
	for tick in 4:
		await get_tree().physics_frame
	player.camera.fov = 52.0
	director.cancel_for_transition()
	_check("a succeeding lens owner keeps its own setting", is_equal_approx(player.camera.fov, 52.0))
	director.free()
	panel.free()
	actor.free()
	player.free()
	Input.mouse_mode = previous_mouse
