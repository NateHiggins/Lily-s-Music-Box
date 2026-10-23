extends Node
## The threshold conversations, driven without a mouse: trees load and
## validate; a knock reaches whoever is home; the entry climbs with trust;
## `requires` hides a reply until the knowledge flag exists; `evidence` hides a
## reply until the player stands in the flat; a node's own flag is granted on
## arrival; flags and trust live on RealityState; no case is ever activated.

var _fails := 0
var _unit := ""
var _home := true


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
