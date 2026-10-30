extends Node
## The mystery threads on the real panel, driven without a mouse: every tree
## loads; dates, hours, flags and holds gate a thread; a topic reaches its root
## on a knock; hearing marks it and flags stay knowledge, with no trust moved;
## every thread can be walked to an end. The companion addendum answers typed
## phrases only when its gates are met, and a witnessed line prints only on
## request. The playtest panel is absent without its variable.

const Conversation = preload("res://scripts/device/companion_conversation.gd")

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("MYSTERY WIRING: ", label, " = ", ok)
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_run()
	print("MYSTERY WIRING TEST: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _labels(panel: CaseDialoguePanel) -> Array:
	return panel.offered_labels()


func _run() -> void:
	var conversations := ResidentConversations.new()
	var panel := CaseDialoguePanel.new()
	conversations.add_child(panel)
	add_child(conversations)
	conversations.setup(panel)
	_check("no load errors", conversations.errors.is_empty())
	if not conversations.errors.is_empty():
		print(conversations.errors)
	_check("23 speakers load", conversations.mystery.size() == 23)
	_check("playtest panel absent without its variable",
			not conversations.get_children().any(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("mystery_playtest.gd")))

	# Gates.
	var thread_ids := func(resident: String, date: String, minute: int) -> Array:
		return conversations.active_threads(resident, date, minute).map(func(t): return t.id)
	_check("a thread waits for its date", "nq_stool" not in thread_ids.call("nadia_quell", "1929-02-01", 720))
	_check("a thread opens on its date", "nq_stool" in thread_ids.call("nadia_quell", "1929-03-10", 720))
	_check("a thread closes after its date", "nq_stool" not in thread_ids.call("nadia_quell", "1929-04-01", 720))
	_check("hours gate", "ev_home" not in thread_ids.call("emil_voss", "1929-07-22", 9 * 60))
	_check("hours open", "ev_home" in thread_ids.call("emil_voss", "1929-07-22", 12 * 60))
	_check("requires hides", "nq_told" not in thread_ids.call("nadia_quell", "1929-08-01", 720))
	RealityState.grant_knowledge("m_tea_seen")
	_check("requires opens", "nq_told" in thread_ids.call("nadia_quell", "1929-08-01", 720))
	RealityState.grant_knowledge("m_mina_log")
	_check("a held thread stays held", thread_ids.call("mina_vale", "1929-08-01", 720).is_empty())
	conversations.playtest_holds = true
	_check("the playtest opens a held thread", "mv_struck" in thread_ids.call("mina_vale", "1929-08-01", 720))
	conversations.playtest_holds = false

	# A real knock carries the topic, and hearing it is remembered.
	conversations.playtest_date = "1929-03-10"
	conversations.playtest_minute = 720
	var trust := RealityState.resident_trust("nadia_quell")
	_check("the door answers", conversations.start("nadia_quell"))
	var labels := _labels(panel)
	var topic := "That stool's short a leg."
	_check("the door tree offers the topic", topic in labels)
	var at := labels.find(topic)
	if at >= 0:
		panel.choose(at)
		_check("the topic reaches its root", panel.current_node_id == "nq_s1")
		_check("hearing is recorded", RealityState.has_knowledge("mt:nq_stool"))
		_check("the speaker is per node", panel._speaker.text == "ADELA")
		_walk(panel)
		_check("the node flag is knowledge", RealityState.has_knowledge("m_seen_stool"))
		_check("threads move no trust", RealityState.resident_trust("nadia_quell") == trust)
		_check("a heard thread does not come back",
				"nq_stool" not in thread_ids.call("nadia_quell", "1929-03-10", 720))

	# Every thread is walkable on the panel, first reply each time.
	conversations.playtest_holds = true
	for resident_id in conversations.mystery:
		for thread in conversations.mystery[resident_id].threads:
			RealityState.data.knowledge_flags.erase("mt:" + str(thread.id))
			for flag in thread.get("requires", []):
				RealityState.grant_knowledge(str(flag))
			conversations.playtest_date = str(thread.from)
			conversations.playtest_minute = conversations._clock_minute(str(thread.hours[0])) \
					if thread.has("hours") else 720
			var opened: bool = conversations.start_mystery(resident_id)
			_check("%s opens" % thread.id, opened)
			if not opened:
				continue
			var menu_at: int = _labels(panel).find(str(thread.topic))
			_check("%s is on the menu" % thread.id, menu_at >= 0)
			if menu_at >= 0:
				panel.choose(menu_at)
				_check("%s walks to an end" % thread.id, _walk(panel))
			else:
				panel.close()
	conversations.playtest_holds = false

	# Companion.
	var talk := Conversation.new()
	_check("companion library loads", talk.errors.is_empty())
	if not talk.errors.is_empty():
		print(talk.errors)
	RealityState.data.knowledge_flags.erase("m_c_n16")
	_check("objections wait for N16", talk.respond("the paper is wrong", {}).line_id != "m_notice_2")
	RealityState.grant_knowledge("m_c_n16")
	_check("objections open after N16", talk.respond("the paper is wrong", {}).line_id == "m_notice_2")
	_check("go on continues the branch", talk.respond("go on", {}).line_id == "m_notice_3")
	_check("the lamp needs a lit subject", talk.respond("hold the lamp lower", {}).line_id != "m_lamp_1")
	_check("the lamp answers when lit", talk.respond("hold the lamp lower",
			{"lamp_on":true, "visible":[{"id":"1", "name":"plate", "observation":"x"}]}).line_id == "m_lamp_1")
	RealityState.grant_knowledge("m_drama_disc")
	_check("exhaust answers once", talk.respond("four minutes", {}).line_id == "m_four")
	_check("exhaust is spent", talk.respond("four minutes", {}).line_id != "m_four")
	RealityState.grant_knowledge("m_seen_stool")
	talk.memory.seen["m_joke_3"] = true
	_check("a past date closes the last joke", talk.respond("any last jokes",
			{"now_iso":"1929-11-09T23:00"}).line_id != "m_joke_last")
	_check("the last joke is open before it", talk.respond("any last jokes",
			{"now_iso":"1929-11-09T21:00"}).line_id == "m_joke_last")
	_check("a witnessed line prints on request", talk.event("m_notice_1").get("line_id", "") == "m_notice_1")
	_check("and only once", talk.event("m_notice_1").is_empty())
	var fresh := Conversation.new()
	_check("nothing typed reaches a witnessed line",
			fresh.mystery_typed.values().all(func(records): return records.all(func(r): return r.surface == "typed")))
	_check("the live library is intact", fresh.lines.has("activation") and fresh.respond("are you alive", {}).line_id != "")


## Take the first reply on each node until the conversation ends. False if it loops.
func _walk(panel: CaseDialoguePanel) -> bool:
	var steps := 0
	while panel.current_node_id != "" and steps < 200:
		panel.choose(0)
		steps += 1
	return steps < 200
