extends Node
## The mystery threads on the real panel, driven without a mouse: every tree
## loads; dates, hours, flags and holds gate a thread; a topic reaches its root
## on a knock; hearing marks it and flags stay knowledge, with no trust moved;
## every thread can be walked to an end. The companion addendum answers typed
## phrases only when its gates are met, and a witnessed line prints only on
## request. The playtest panel is absent without its variable.

const Conversation = preload("res://scripts/device/companion_conversation.gd")
const Economy = preload("res://scripts/game/caretaker_economy.gd")

class WitnessFixture extends Node:
	var nadia_present := true

	func witness_present(resident_id: String) -> bool:
		return nadia_present and resident_id == "nadia_quell"


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


func _check_reply_deadline(owner: ResidentConversations, panel: CaseDialoguePanel) -> void:
	var saved_date := owner.playtest_date
	var saved_minute := owner.playtest_minute
	var topic := "That one's for 6C?"
	for spoken: bool in [false, true]:
		for expiry: String in ["menu", "reply", "next_day", "on_time"]:
			RealityState.reset_campaign_for_tests()
			owner.playtest_date = "1929-07-19"
			owner.playtest_minute = 18 * 60 + 10
			var opened := owner.start_mystery("cam_ortiz", true) if spoken else owner.start("cam_ortiz")
			var at := _labels(panel).find(topic)
			var label := "Cam %s / %s" % ["spoken" if spoken else "knock", expiry]
			_check(label + " offers the topic", opened and at >= 0)
			if not opened or at < 0:
				owner.cancel_for_transition()
				continue
			if expiry == "menu":
				owner.playtest_minute += 1
			panel.choose(at)
			if expiry != "menu":
				var take := _labels(panel).find("Leave it with me.")
				_check(label + " reaches the authored decision", panel.current_node_id == "co_k1" and take >= 0)
				if expiry == "reply":
					owner.playtest_minute += 1
				elif expiry == "next_day":
					owner.playtest_date = "1929-07-20"
				if take >= 0:
					panel.choose(take)
			_check(label + " records hearing only upon reaching Cam's words", RealityState.has_knowledge("mt:co_keep") == (expiry != "menu"))
			_check(label + " grants envelope only on time", RealityState.has_knowledge("m_o2_kept_envelope") == (expiry == "on_time"))
			if expiry == "on_time":
				_check(label + " displays acceptance", panel.current_node_id == "co_k2")
			else:
				_check(label + " releases the expired conversation", not panel.attention_active() and owner._active_resident.is_empty())
			owner.cancel_for_transition()

	RealityState.reset_campaign_for_tests()
	owner.playtest_date = "1929-11-09"
	owner.playtest_minute = 16 * 60
	RealityState.grant_knowledge("m_receipt_seen")
	var witness := WitnessFixture.new()
	add_child(witness)
	witness.add_to_group("loop_performances")
	_check("Mae opens with Nadia present", owner.start_mystery("mae_kessler", true, "mk_box"))
	panel.choose(0)
	_check("Mae speaks before Nadia leaves", panel.current_node_id == "mk_b1")
	witness.nadia_present = false
	panel.choose_silence()
	_check("a silent reply cannot continue without Nadia", not panel.attention_active() and owner._active_resident.is_empty())
	_check("Mae's spoken first line stays heard", RealityState.has_knowledge("mt:mk_box"))
	owner.cancel_for_transition()
	witness.free()
	RealityState.reset_campaign_for_tests()
	owner.playtest_date = saved_date
	owner.playtest_minute = saved_minute


func _run() -> void:
	var conversations := ResidentConversations.new()
	var panel := CaseDialoguePanel.new()
	conversations.add_child(panel)
	add_child(conversations)
	conversations.setup(panel)
	_check("no load errors", conversations.errors.is_empty())
	if not conversations.errors.is_empty():
		print(conversations.errors)
	_check("26 speakers load", conversations.mystery.size() == 26)
	_check("playtest panel absent without its variable",
			not conversations.get_children().any(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("mystery_playtest.gd")))

	_check_reply_deadline(conversations, panel)
	# Gates.
	var thread_ids := func(resident: String, date: String, minute: int) -> Array:
		return conversations.active_threads(resident, date, minute).map(func(t): return t.id)
	_check("a thread waits for its date", "nq_stool" not in thread_ids.call("nadia_quell", "1929-02-01", 720))
	# The first rescue lever: Cam's envelope for 6C can be kept only before he takes it up at ten past six.
	_check("Cam's envelope can be asked for at five past six", "co_keep" in thread_ids.call("cam_ortiz", "1929-07-19", 18 * 60 + 5))
	_check("and not once it has gone up", "co_keep" not in thread_ids.call("cam_ortiz", "1929-07-19", 18 * 60 + 15))
	_check("and on no other Friday", "co_keep" not in thread_ids.call("cam_ortiz", "1929-07-26", 18 * 60 + 5))
	_check("a thread opens on its date", "nq_stool" in thread_ids.call("nadia_quell", "1929-03-10", 720))
	_check("a thread closes after its date", "nq_stool" not in thread_ids.call("nadia_quell", "1929-04-01", 720))
	_check("hours gate", "ev_home" not in thread_ids.call("emil_voss", "1929-07-22", 9 * 60))
	_check("hours open", "ev_home" in thread_ids.call("emil_voss", "1929-07-22", 12 * 60))
	_check("requires hides", "nq_told" not in thread_ids.call("nadia_quell", "1929-08-01", 720))
	# S15 is said to Nadia's body in person on the last night; no unspoken thread opens that way.
	var was_date: String = conversations.playtest_date
	var was_minute: int = conversations.playtest_minute
	RealityState.grant_knowledge("m_nadia_card")
	conversations.playtest_date = "1929-11-09"
	conversations.playtest_minute = 22 * 60
	_check("S15 is open on the last night", "nq_telling" in thread_ids.call("nadia_quell", "1929-11-09", 22 * 60))
	_check("the click knows Nadia has a spoken thread", conversations.has_spoken_thread("nadia_quell"))
	_check("in person, Nadia offers only the spoken thread",
			conversations.start_mystery("nadia_quell", true) and _labels(panel) == ["Give me the pencil."])
	panel.close()
	conversations.playtest_date = "1929-07-22"
	conversations.playtest_minute = 12 * 60
	_check("a thread that is not spoken does not open in person", not conversations.start_mystery("emil_voss", true))
	_check("no spoken thread, so the ambient line keeps the click", not conversations.has_spoken_thread("emil_voss"))
	conversations.playtest_date = was_date
	conversations.playtest_minute = was_minute
	RealityState.data.knowledge_flags.erase("m_nadia_card")
	RealityState.data.knowledge_flags.erase("mt:nq_telling")
	# Stacy's own cases sit beside the main case: dated, chained by sc flags.
	_check("Stacy's first case opens in December", "sc1_coffee" in thread_ids.call("stacy", "1928-12-10", 18 * 60))
	_check("Stacy's second step waits for the first", "sc1_tab" not in thread_ids.call("stacy", "1928-12-28", 18 * 60))
	RealityState.grant_knowledge("sc1_seen")
	_check("Stacy's second step follows the first", "sc1_tab" in thread_ids.call("stacy", "1928-12-28", 18 * 60))
	_check("Lily's first case opens in December", "lf1_gone" in thread_ids.call("lily", "1928-12-20", 18 * 60))
	_check("Lily's appointments are offered on their dates", "lfa_rates" in thread_ids.call("lily", "1928-12-20", 18 * 60))
	# A priced choice: offered only when the cash is there; the ledger takes it once per choosing; no grant on refusal.
	var paid_choice: Dictionary = conversations.mystery["lily"].nodes["lfa_r1"].choices[0]
	_check("the appointment choice names its price", ResidentConversations.price_of(str(paid_choice.flag)) == {"item": "lfa_hour", "cents": 200})
	_check("no ledger, no priced choice", not conversations._available("lily", paid_choice))
	var ledger := Economy.new()
	add_child(ledger)
	var saved_errands: ResidentErrands = conversations.errands
	var priced_errands := ResidentErrands.new()
	priced_errands.economy = ledger
	conversations.errands = priced_errands
	ledger.book().cash = 150
	_check("unaffordable, the choice is not offered", not conversations._available("lily", paid_choice))
	# Silence on the real panel is no way past the price.
	RealityState.data.knowledge_flags.erase("mt:lfa_rates")
	conversations.playtest_date = "1928-12-20"
	conversations.playtest_minute = 18 * 60
	_check("Lily's menu opens for silence", conversations.start_mystery("lily"))
	var rates_at: int = _labels(panel).find("Are you working tonight, Miss Fern?")
	if rates_at >= 0:
		panel.choose(rates_at)
		_check("unaffordable, the panel does not offer the price", "Two dollars. Here." not in _labels(panel))
		panel.choose_silence()
		_check("silence declines the hour", panel.current_node_id == "lfa_r3")
		_check("silence buys nothing and takes nothing", not RealityState.has_knowledge("lfa_hour") and int(ledger.book().cash) == 150)
	else:
		_check("Lily's rates are on the menu", false)
	panel.close()
	conversations._record("lily", str(paid_choice.flag), 1)
	_check("refused, nothing is known and nothing is taken", not RealityState.has_knowledge("lfa_hour") and int(ledger.book().cash) == 150)
	ledger.book().cash = 450
	_check("affordable, the choice is offered", conversations._available("lily", paid_choice))
	var trust_before := RealityState.resident_trust("lily")
	conversations._record("lily", str(paid_choice.flag), 1)
	_check("paid once, the hour is known", RealityState.has_knowledge("lfa_hour") and int(ledger.book().cash) == 250)
	_check("the sale is one bounded row", int(ledger.book().sales["lily/lfa_hour"].count) == 1)
	_check("paying moves no trust", RealityState.resident_trust("lily") == trust_before)
	conversations._record("lily", str(paid_choice.flag), 1)
	_check("each choosing pays once more, never twice", int(ledger.book().cash) == 50 and int(ledger.book().sales["lily/lfa_hour"].count) == 2)
	_check("a malformed price is no price", ResidentConversations.price_of("pay:lfa_hour").cents == 0 and ResidentConversations.price_of("pay::200").cents == 0)
	conversations.errands = saved_errands
	ledger.queue_free()
	_check("no Lily case in the protected weeks", thread_ids.call("lily", "1929-07-19", 18 * 60).filter(func(id): return str(id).begins_with("lf")).is_empty())
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

	_check_silence_gates(conversations, panel)

	# This panel fixture supplies the authored witness for the all-thread walk.
	var witness_fixture := WitnessFixture.new()
	add_child(witness_fixture)
	witness_fixture.add_to_group("loop_performances")
	# Every thread is walkable on the panel, first reply each time.
	conversations.playtest_holds = true
	for resident_id in conversations.mystery:
		for thread in conversations.mystery[resident_id].threads:
			RealityState.data.knowledge_flags.erase("mt:" + str(thread.id))
			for flag in thread.get("requires", []):
				RealityState.grant_knowledge(str(flag))
			for flag in thread.get("requires_any", []):
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

	witness_fixture.free()

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
	_chains(conversations, thread_ids)


## The suspect chains: a thread opens on any one of its clues, nothing opens from
## the wrong date, the paper itself grants its clue, and the companion enters a
## theory without holding one.
func _check_silence_gates(conversations: ResidentConversations, panel: CaseDialoguePanel) -> void:
	var saved_flags: Array = RealityState.data.knowledge_flags.duplicate()
	var saved_date := conversations.playtest_date
	var saved_minute := conversations.playtest_minute
	var cases := [
		{"resident": "cal_dwyer", "thread": "cd_playback", "entry_flag": "m_drama_lead",
			"needs": "m_jonah_page", "grant": "m_door_match", "reply": "That's the line Jonah wrote down."},
		{"resident": "lena_ortiz", "thread": "lo_book", "entry_flag": "",
			"advance": "Anything on the twentieth of July?", "needs": "m_glove_scrap",
			"grant": "m_button_book", "reply": "Pearl?"},
		{"resident": "mr_ewald", "thread": "ew_lease", "entry_flag": "m_lease_read",
			"needs": "m_receipt_seen", "grant": "m_collection_named", "reply": "And if they collected anyway?"},
	]
	for fixture: Dictionary in cases:
		var threads: Array = conversations.mystery[fixture.resident].threads
		var matches := threads.filter(func(thread: Dictionary) -> bool: return thread.id == fixture.thread)
		_check("%s has its real thread" % fixture.resident, matches.size() == 1)
		if matches.size() != 1:
			continue
		var thread: Dictionary = matches[0]
		conversations.playtest_date = str(thread.from)
		conversations.playtest_minute = 12 * 60
		for has_evidence: bool in [false, true]:
			RealityState.data.knowledge_flags = saved_flags.duplicate()
			for flag: String in [str(fixture.needs), str(fixture.grant), "mt:" + str(fixture.thread)]:
				RealityState.data.knowledge_flags.erase(flag)
			RealityState.grant_knowledge(str(fixture.entry_flag))
			if has_evidence:
				RealityState.grant_knowledge(str(fixture.needs))
			var context := "%s with%s the prerequisite" % [fixture.resident, "" if has_evidence else "out"]
			if not _open_silence_fixture(conversations, panel, fixture, thread, context):
				continue
			var reply := _labels(panel).find(fixture.reply)
			_check(context + " offers the question only when earned", (reply >= 0) == has_evidence)
			if has_evidence and reply >= 0:
				panel.choose(reply)
			else:
				panel.choose_silence()
			_check(context + " records evidence only from the earned question",
					RealityState.has_knowledge(str(fixture.grant)) == has_evidence)
			panel.close()
	RealityState.data.knowledge_flags = saved_flags
	conversations.playtest_date = saved_date
	conversations.playtest_minute = saved_minute


func _open_silence_fixture(conversations: ResidentConversations, panel: CaseDialoguePanel,
		fixture: Dictionary, thread: Dictionary, context: String) -> bool:
	var opened := conversations.start_mystery(str(fixture.resident))
	var topic := _labels(panel).find(thread.topic) if opened else -1
	_check(context + " can open the real topic", opened and topic >= 0)
	if topic < 0:
		panel.close()
		return false
	panel.choose(topic)
	if fixture.has("advance"):
		var button := _labels(panel).find(fixture.advance)
		_check(context + " can reach the gated question", button >= 0)
		if button < 0:
			panel.close()
			return false
		panel.choose(button)
	return true


func _chains(conversations: ResidentConversations, thread_ids: Callable) -> void:
	for flag in ["m_noel_door", "m_noel_landing", "m_jonah_page", "m_noel_reports"]:
		RealityState.data.knowledge_flags.erase(flag)
	RealityState.data.knowledge_flags.erase("mt:np_reports")
	_check("the reports wait for a clue", "np_reports" not in thread_ids.call("noel_price", "1929-08-01", 720))
	RealityState.grant_knowledge("m_jonah_page")
	_check("any one clue opens the reports", "np_reports" in thread_ids.call("noel_price", "1929-08-01", 720))
	_check("no report on the evening itself", "np_reports" not in thread_ids.call("noel_price", "1929-07-19", 1080))
	RealityState.data.knowledge_flags.erase("m_c_gloved_lady")
	var catalog := NewspaperCatalog.new()
	add_child(catalog)
	var clock := CampaignClock.new()
	clock.configure_date(1929, 6, 20, 720)
	var witness: Node = preload("res://scripts/device/companion_witness.gd").new()
	witness.paper_shown(catalog, "record", "1929-06-14")
	_check("another day's paper grants nothing", not RealityState.has_knowledge("m_c_gloved_lady"))
	witness.paper_shown(catalog, "record", "1929-06-15")
	_check("reading the paper grants its clue", RealityState.has_knowledge("m_c_gloved_lady"))
	RealityState.data.knowledge_flags.erase("m_c_boxes")
	witness.paper_shown(catalog, "record", "1929-07-27")
	_check("a paper not yet out grants nothing", not RealityState.has_knowledge("m_c_boxes"))
	clock.configure_date(1929, 8, 1, 720)
	witness.paper_shown(catalog, "record", "1929-07-27")
	_check("the Box notice grants its clue", RealityState.has_knowledge("m_c_boxes"))
	witness.free()
	var talk := Conversation.new()
	RealityState.data.knowledge_flags.erase("m_noel_landing")
	_check("no theory before the sighting", talk.respond("it was noel", {}).line_id != "m_theory_noel")
	RealityState.grant_knowledge("m_noel_landing")
	_check("the companion enters the theory", talk.respond("it was noel", {}).line_id == "m_theory_noel")


## Take the first reply on each node until the conversation ends. False if it loops.
func _walk(panel: CaseDialoguePanel) -> bool:
	var steps := 0
	while panel.current_node_id != "" and steps < 200:
		panel.choose(0)
		steps += 1
	return steps < 200
