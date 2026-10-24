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
	print("RESIDENT CONVERSATION TEST: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	var panel := CaseDialoguePanel.new()
	add_child(panel)
	var director := ResidentConversations.new()
	add_child(director)
	director.setup(panel, func(): return _unit, func(_id): return _home)
	await get_tree().process_frame

	_check("every authored tree loads without an error",
			director.errors.is_empty() and director.resident_ids().size() == 17)
	if not director.errors.is_empty():
		for line in director.errors:
			print("  tree error: ", line)
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
	_check("both notes loaded", director.notes.has("first_conversation") and director.notes.size() == 2)
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
	panel.choose(_index(offered, "[the staging table]"))
	_check("the table leads to the stations", panel.current_node_id == "pw_table")
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
			and int(snapshot.conversation_visits.peter_wren) == 3)
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
			panel.offered_labels() == ["One", "Two"] and panel._choices.get_child(1).text.begins_with("2"))
	_check("the panel lowers the scrim, never a box over the view",
			panel._scrim.anchor_top > 0.5 and panel._line.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
			and panel._line.get_theme_font_size("font_size") >= 20)
	panel.close()
	_check("closing hands the pointer back", not panel.attention_active())


static func _has(labels: Array, text: String) -> bool:
	for label in labels:
		if str(label).contains(text):
			return true
	return false


static func _index(labels: Array, text: String) -> int:
	for i in labels.size():
		if str(labels[i]).contains(text):
			return i
	return -1
