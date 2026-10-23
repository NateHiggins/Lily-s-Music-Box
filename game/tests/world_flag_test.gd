extends Node
## The six world flags of design/ORISON_DIALOGUE_DRAFTS_2026-10-22.md
## section 3, granted by the building rather than by a conversation, driven
## headless: Mina's tree reaching her blank or resolved beat, the minutes
## spread opened wide enough to read, the lift refusing the sixth, Omar's
## blackout node, a Vale seen on the hour the Vales miss each other, and a
## dead letter for the tenant who left 3C. Then the replies that needed them
## become offerable through the same `requires` check the director uses.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("WORLD FLAG: ", label, " = ", ok)
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	await _run()
	print("WORLD FLAG TEST: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	# --- Mina: the four seconds ---------------------------------------------
	_check("an ordinary Mina node teaches nothing",
			not MinaCaseGameplay.grant_node_knowledge("fs_open")
			and not RealityState.has_knowledge("mina_four_seconds"))
	_check("reaching rt_blank grants the four seconds",
			MinaCaseGameplay.grant_node_knowledge("rt_blank")
			and RealityState.has_knowledge("mina_four_seconds"))
	_check("res_open grants the same flag and reports nothing new",
			not MinaCaseGameplay.grant_node_knowledge("res_open"))
	var mina_tree: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(MinaCaseGameplay.DIALOGUE_TREE_PATH))
	var mina_nodes: Dictionary = mina_tree.get("nodes", {})
	_check("both granting nodes exist in her canon tree",
			mina_nodes.has("rt_blank") and mina_nodes.has("res_open"))

	# --- the readable library: the association minutes -------------------------
	var book: GDScript = load("res://scripts/props/v2_readable_book.gd")
	_check("a book barely cracked teaches nothing",
			not book.note_spread_read("minutes", 0.3)
			and not RealityState.has_knowledge("minutes_read"))
	_check("another title opened wide teaches nothing",
			not book.note_spread_read("wiring", 2.0))
	_check("the minutes opened wide are read",
			book.note_spread_read("minutes", 1.2) and RealityState.has_knowledge("minutes_read"))
	var spreads: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/orison_v2/book_spreads.json"))
	_check("the minutes spread is authored under that title",
			_spread_titles(spreads).has("minutes"))

	# --- the lift: it will not hear the sixth -----------------------------------
	var car := Otis.new()
	_check("the car's data loads", car.load_data() and not car.quirk("deaf").is_empty())
	car.start(7)
	_check("the deaf quirk is in play on an ordinary shift", car.has_quirk("deaf"))
	var deaf_floor := int(car.quirk("deaf").get("floor", -1))
	_check("the deaf floor is the sixth", deaf_floor == 6 and car.top() >= 6)
	var heard_first := car.call_to(deaf_floor)
	_check("the first call to the sixth is not heard, and that is the lesson",
			not heard_first and RealityState.has_knowledge("otis_sixth_deaf"))
	_check("the second call is taken", car.call_to(deaf_floor))

	# --- Omar's blackout: the station went quiet ---------------------------------
	var panel := CaseDialoguePanel.new()
	add_child(panel)
	var director := ResidentConversations.new()
	add_child(director)
	director.setup(panel, func(): return "", func(_id): return true)
	await get_tree().process_frame
	_check("the trees still validate with a flags list", director.errors.is_empty())
	var omar: Dictionary = director.trees.get("omar_bell", {})
	var blackout: Dictionary = omar.get("nodes", {}).get("ob_blackout", {})
	_check("the blackout node names both flags",
			str(blackout.get("flag", "")) == "omar_dead_air"
			and blackout.get("flags", []) == ["station_went_quiet"])
	var granted: Array = []
	panel.run_tree(omar, "ob_blackout",
			func(flag: String, _trust: int): granted.append(flag), Callable(),
			{"on_node_flag": func(flag: String): granted.append(flag)})
	_check("arriving at the blackout grants both, in order",
			granted == ["omar_dead_air", "station_went_quiet"])
	panel.close()
	panel.current_node_id = ""
	_check("a flags list that is not a list is refused at load",
			not director._valid_tree(_tree_with_flags("not a list"), "test")
			and not director._valid_tree(_tree_with_flags([""]), "test")
			and director._valid_tree(_tree_with_flags(["a", "b"]), "test"))

	# --- the Vales' hours -----------------------------------------------------------
	var schedule := ScheduleDirector.new()
	add_child(schedule)
	schedule.setup(null, {})
	var teresa_out := schedule.directive_for("teresa_vale",
			schedule.resolve("teresa_vale", "mon", 1325.0, 0, false))
	var mina_run := schedule.directive_for("mina_vale",
			schedule.resolve("mina_vale", "mon", 1415.0, 0, false))
	var mina_sunday := schedule.directive_for("mina_vale",
			schedule.resolve("mina_vale", "sun", 1415.0, 0, false))
	var omar_evening := schedule.directive_for("omar_bell",
			schedule.resolve("omar_bell", "tue", 1290.0, 0, false))
	_check("Teresa leaving at 22:20 carries the knowledge",
			str(teresa_out.get("key", "")) == "lobby"
			and str(teresa_out.get("knowledge", "")) == "vales_hours_do_not_overlap")
	_check("Mina's late run carries the knowledge",
			str(mina_run.get("key", "")) == "bodega"
			and str(mina_run.get("knowledge", "")) == "vales_hours_do_not_overlap")
	_check("the skipped Sunday run and other residents carry none",
			not mina_sunday.has("knowledge") and not omar_evening.has("knowledge"))
	var routines := ResidentRoutines.new()
	routines.schedules["mina_vale"] = mina_run
	routines.schedules["omar_bell"] = omar_evening
	_check("seeing Mina from across the lobby is not close enough",
			not routines._witness("mina_vale", routines.WITNESS_RADIUS + 1.0)
			and not RealityState.has_knowledge("vales_hours_do_not_overlap"))
	_check("passing Omar on an ordinary evening teaches nothing",
			not routines._witness("omar_bell", 1.0))
	_check("passing Mina on her late run teaches the Vales' hours",
			routines._witness("mina_vale", 2.5)
			and RealityState.has_knowledge("vales_hours_do_not_overlap"))
	routines.free()

	# --- the dead-letter tray: a Vantry lived in 3C -------------------------------------
	var tray := DeadLetters.new()
	_check("the deck loads", tray.load_deck())
	_check("a tenant still here teaches nothing", not tray.note_gone("Teresa Vale"))
	_check("the letter for H. Vantry teaches 3C",
			tray.note_gone("H. Vantry") and RealityState.has_knowledge("vantry_in_3c"))
	var filed_vantry := false
	for seed in range(1, 40):
		tray.start(seed)
		while not tray.done():
			var letter := tray.current()
			if str(letter.get("to", "")) == "H. Vantry":
				RealityState.reset_campaign_for_tests()
				tray.file_into(DeadLetters.DEAD)
				filed_vantry = RealityState.has_knowledge("vantry_in_3c")
				break
			tray.file_into(str(letter.get("answer", "")))
		if filed_vantry:
			break
	_check("filing the Vantry letter in play grants the flag", filed_vantry)

	# --- the replies that needed them -------------------------------------------------
	RealityState.reset_campaign_for_tests()
	var peter: Dictionary = director.trees.get("peter_wren", {})
	var mina_link := _choice_requiring(peter, "mina_four_seconds")
	_check("Peter's cross-flat reply is hidden before the four seconds",
			not mina_link.is_empty() and not director._available("peter_wren", mina_link))
	MinaCaseGameplay.grant_node_knowledge("rt_blank")
	_check("and offered after them", director._available("peter_wren", mina_link))
	for pair in [["cal_dwyer", "station_went_quiet"], ["noel_price", "minutes_read"],
			["jonah_price", "minutes_read"], ["transient_guests", "otis_sixth_deaf"],
			["teresa_vale", "vales_hours_do_not_overlap"], ["mae_kessler", "vantry_in_3c"],
			["omar_bell", "vantry_in_3c"]]:
		var choice := _choice_requiring(director.trees.get(pair[0], {}), pair[1])
		_check("%s still asks for %s" % [pair[0], pair[1]], not choice.is_empty())


static func _spread_titles(spreads: Dictionary) -> Array:
	# The spread stock keys titles at the top level or under "spreads".
	if spreads.has("spreads") and spreads.spreads is Dictionary:
		return spreads.spreads.keys()
	return spreads.keys()


static func _tree_with_flags(flags: Variant) -> Dictionary:
	var node := {"line": "A line.", "flags": flags}
	return {"meta": {"speaker_default": "T", "voice_prefix": "t_", "voice_status": "none",
			"notes": "test"},
		"entries": {"first_stable": "n", "real_talk": "n", "integration": "n",
			"resolved": "n", "fallback": "n"},
		"nodes": {"n": node}}


static func _choice_requiring(tree: Dictionary, flag: String) -> Dictionary:
	for node_id in tree.get("nodes", {}):
		for choice in tree.nodes[node_id].get("choices", []):
			if flag in choice.get("requires", []):
				return choice
	return {}
