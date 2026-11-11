extends Node
## The temporal investigation loop against the real clock, economy ledger and
## validated disk save. No world: this proves the rules and walks the whole
## tree of leads by reporting what the hand would do. The rooms themselves are
## V2LoopStageTest's.
const State := preload("res://scripts/game/prologue_state.gd")
const Loop := preload("res://scripts/game/temporal_loop.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")
const Pocket := preload("res://scripts/game/paper_pocket.gd")
var failures: Array[String] = []
var checks := 0
var clock: CampaignClock
var loop: Node
var economy: Node
var slips: Array[String] = []
var resets := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])


func at(year: int, month: int, day: int, hour: int, minute: int) -> bool:
	var now := clock.local_datetime()
	if now.is_empty() or int(now.year) != year or int(now.month) != month or int(now.day) != day:
		return false
	var of_day := int(now.hour) * 60 + int(now.minute)
	return of_day == hour * 60 + minute or of_day == hour * 60 + minute + 1


func stamp() -> String:
	return clock.datetime_string()


func tick() -> void:
	loop._poll = 5.0
	loop._process(0.1)


## Run string between the pieces of every deduction the wall could draw now.
func join_all() -> void:
	for guard in 6:
		var loose: Dictionary = loop.open_deduction()
		if loose.is_empty():
			return
		for index in range(1, (loose.needs as Array).size()):
			loop.link(str(loose.needs[index - 1]), str(loose.needs[index]))


## Do what the hand would do for every remaining step of the room, in order.
func work_room() -> void:
	for guard in 12:
		var step: Dictionary = loop.current_step()
		if step.is_empty():
			return
		match str(step.kind):
			"at": loop.observe(str(step.unit))
			"after":
				var wait := float(Loop._minute_of(str(step.time))) - clock.minute_of_day()
				if wait > 0.0:
					clock.advance_to(clock.elapsed_minutes() + wait + 0.5)
				loop.observe("")
			"flag":
				RealityState.grant_knowledge(str(step.flag))
				loop.observe("")
			"shift": loop.report_shift(str(step.object))


func _ready() -> void:
	var old_path: String = RealityState.save_path
	var old_persistence: bool = RealityState.persistence_enabled
	var old_data: Dictionary = RealityState.data
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	RealityState.persistence_enabled = false
	RealityState.save_path = "user://tests/temporal_loop_test.json"
	RealityState.start_new_campaign()
	RealityState.persistence_enabled = true
	clock = CampaignClock.new()
	check(clock.configure_date(1928, 11, 10, 1380) and clock.advance_to(5.25), "fixture campaign has run a little")
	check(not clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 6, 13, 980.0)),
			"no dated visit before the prologue has adopted the historical year")
	var opening := State.request_skip(State.initial())
	for index in State.PHASES.size() - 1:
		var phase: String = State.PHASES[index]
		if phase == "companion_crossing":
			opening = State.applied(opening, "companion_materialized")
		if phase == "temporal_command":
			opening = State.with_target(opening, {"utc_unix_seconds": 1856345696, "local_bias_minutes": -300, "local_zone": "Test"})
		if phase == "temporal_synchronization":
			break
		opening = State.advance(opening, State.PHASES[index + 1])
	RealityState.data.prologue = opening
	check(clock.apply_prologue_destination() and clock.loop_calendar_active(), "the prologue hands over the repeating year")

	# The clock: a move of the calendar that leaves the player's own time alone.
	var elapsed := clock.elapsed_minutes()
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 1410.0)) and at(1929, 11, 9, 23, 30),
			"home is set late on the last day of the year (%s)" % stamp())
	check(is_equal_approx(clock.elapsed_minutes(), elapsed), "moving the calendar does not touch elapsed time")
	check(CampaignClock.validate_snapshot(RealityState.data.campaign_clock).ok, "the moved clock is a valid saved clock")

	# The murder hours.
	var dark := CampaignClock.blackout_start_minute()
	check(not CampaignClock.in_blackout(dark - 1.0) and CampaignClock.in_blackout(dark)
			and CampaignClock.in_blackout(CampaignClock.blackout_end_minute() - 1.0)
			and not CampaignClock.in_blackout(CampaignClock.blackout_end_minute()), "the dark runs from 9:01 p.m. to 3:02 a.m. exactly")
	var before: Dictionary = (RealityState.data.campaign_clock as Dictionary).duplicate(true)
	check(not clock.rebase_calendar(dark + 10.0) and not clock.rebase_calendar(dark)
			and not clock.rebase_calendar(CampaignClock.blackout_end_minute() - 0.5)
			and RealityState.data.campaign_clock == before, "no calendar move may land in the murder hours, and a refusal changes nothing")
	check(clock.rebase_calendar(CampaignClock.blackout_end_minute()) and at(1929, 7, 20, 3, 2), "a visit may begin at 3:02 (%s)" % stamp())
	check(clock.rebase_calendar(dark - 2.0), "a visit may stand two minutes before the dark")
	elapsed = clock.elapsed_minutes()
	clock.advance_seconds(180.0)
	check(at(1929, 7, 20, 3, 2), "time that runs into the dark comes out at 3:02 (%s)" % stamp())
	check(clock.elapsed_minutes() > elapsed + 360.0, "and the player's own time went forward across it, never back")
	check(clock.rebase_calendar(dark - 2.0) and clock.advance_to(clock.elapsed_minutes() + 30.0)
			and not CampaignClock.in_blackout(clock.calendar_minutes()), "a set advance cannot stop inside the dark either (%s)" % stamp())
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 1410.0)) and at(1929, 11, 9, 23, 30), "home again for the loop")

	# The table and the tree.
	economy = Economy.new()
	add_child(economy)
	loop = Loop.new()
	add_child(loop)
	check(loop.setup(clock, economy), "the anchors load: every need is another lead's evidence, tiers only climb, none touches the dark")
	loop.slip.connect(func(title: String, body: String) -> void: slips.append(title + "|" + body))
	loop.stage_reset.connect(func() -> void: resets += 1)
	check(loop.table.anchors.size() == 11, "eleven leads (%d)" % loop.table.anchors.size())
	check(str(loop.dressed_for("1929-07-03").occasion) == "Independence Day" and str(loop.dressed_for("1929-07-03").season) == "high summer"
			and str(loop.dressed_for("1929-07-19").occasion) == "" and str(loop.dressed_for("1928-12-24").season) == "winter"
			and str(loop.dressed_for("1929-11-01").occasion) == "Hallowe'en",
			"the year's table says what the house is dressed for on a date")
	check(str(loop.anchor_text("box")).contains("LATE AUTUMN") and str(loop.anchor_text("box")).contains("ARMISTICE")
			and loop.dressing_of("stairs").size() == 4, "each lead carries its season, its occasion and what its rooms show")
	var most_steps := 0
	var climbing := true
	var by_tier := {}
	for anchor_id: String in loop.table.anchors:
		var anchor: Dictionary = loop.table.anchors[anchor_id]
		by_tier[int(anchor.tier)] = maxi(int(by_tier.get(int(anchor.tier), 0)), (anchor.steps as Array).size())
	for tier in range(1, 7):
		climbing = climbing and by_tier.has(tier) and int(by_tier[tier]) >= most_steps
		most_steps = maxi(most_steps, int(by_tier.get(tier, 0)))
	check(climbing and int(by_tier[1]) == 2 and int(by_tier[6]) == 7, "six tiers, and the rooms get longer as they climb (%s)" % str(by_tier))
	check(loop.unlocked() == (["tea"] as Array[String]) and loop.state() == "CHOOSE_NEXT_ACTION", "one lead is open with an empty wall")
	check(loop.fare_cents("tea") == 0, "the first call to the opening lead is on the house")
	check(not loop.jump("friday").ok and not loop.in_visit(), "a lead the wall has not opened cannot be visited")

	# The bank.
	var rent_started: float = float(economy.book().started)
	check(int(economy.book().cash) == 100 and loop.deposit(60).ok and loop.bank_cents() == 60
			and int(economy.book().cash) == 40, "a deposit moves pocket cash to the bank")
	check(not loop.deposit(1000).ok and loop.bank_cents() == 60, "the pocket cannot bank what it does not hold")

	# Out: across the year to 13 June, and the first room.
	elapsed = clock.elapsed_minutes()
	var went: Dictionary = loop.jump("tea")
	check(went.ok and int(went.fare) == 0 and loop.in_visit() and loop.state() == "RUN_LOOP", "the jump is made")
	check(at(1929, 6, 13, 16, 20), "the calendar reads the anchor's hour (%s)" % stamp())
	check(is_equal_approx(clock.elapsed_minutes(), elapsed), "the jump costs no elapsed time")
	check(not loop.deposit(10).ok and not loop.claim_stipend().ok and not loop.jump("tea").ok and not loop.pin_next().ok,
			"no banking, allowance, second jump or pinning while away")
	check(economy.receive("test:odd_job", 500) and int(economy.book().cash) == 540, "money can be earned in the past")
	check(not loop.clue_ready() and not loop.take_clue().ok, "the evidence is not there to take before the room is worked")
	check(loop.report_shift("6C_tea_tray") == "" and loop.steps_done() == 0, "lifting the tray before arriving in 6C does nothing")
	loop.observe("4B")
	check(loop.steps_done() == 0, "standing in the wrong flat is not arriving")
	loop.observe("6C")
	check(loop.steps_done() == 1 and loop.state() == "INVESTIGATE" and str(loop.current_step().object) == "6C_tea_tray", "in 6C, the room waits on the tray")
	check(loop.visit_hint() == str(loop.table.anchors.tea.steps[1].hint), "the hint is for the step the room is waiting on")
	check(loop.report_shift("6C_ledger") == "" and loop.steps_done() == 1, "lifting something else changes nothing in an easy room")
	check(loop.report_shift("6C_tea_tray") == "step" and loop.clue_ready() and loop.state() == "RESOLVE_ANCHOR"
			and slips.any(func(line: String) -> bool: return line.begins_with("THERE|")), "the tray lifted, the order slip is there")
	check(clock.advance_to(clock.elapsed_minutes() + 60.0), "an hour of the visit passes")

	# Save and reload in the middle of the visit, mid-room.
	check(RealityState.save_game(), "the validated save accepts a campaign in mid-visit")
	RealityState.data.temporal.bank_cents = 9999
	RealityState.data.temporal.visit = {}
	RealityState.load_game()
	check(clock.bind_state() and loop.in_visit() and loop.visit_anchor() == "tea" and loop.bank_cents() == 60 and loop.clue_ready(),
			"the reload is still away, in the same room at the same step, with the same bank")
	check(at(1929, 6, 13, 17, 20), "and at the same minute of 13 June (%s)" % stamp())
	check(is_equal_approx(loop.loop_minutes(), 60.0), "the loop clock reads the hour spent")

	# The hours again, for nothing. The room is as it was.
	elapsed = clock.elapsed_minutes()
	resets = 0
	var again: Dictionary = loop.reset_loop()
	check(again.ok and int(again.loops) == 1 and at(1929, 6, 13, 16, 20), "the hours begin again (%s)" % stamp())
	check(loop.steps_done() == 0 and not loop.clue_ready() and resets == 1, "the room is put back and says so")
	check(loop.bank_cents() == 60 and is_equal_approx(clock.elapsed_minutes(), elapsed), "a rerun costs no fare and no elapsed time")
	check(int(economy.book().cash) == 40, "what was earned there is gone with the run")

	# Take the evidence and keep it through a rerun.
	work_room()
	var taken: Dictionary = loop.take_clue()
	check(taken.ok and str(taken.item) == "order_slip" and loop.holds("order_slip") and not loop.pinned("order_slip")
			and loop.answered("tea"), "the order slip is taken")
	check(Pocket.book().evidence.any(func(found: Variant) -> bool: return str(found.id) == "loop:order_slip"), "and filed in the valise")
	check(not loop.take_clue().ok, "it cannot be taken twice")
	check(loop.reset_loop().ok and loop.holds("order_slip"), "it is kept through a rerun")
	work_room()
	check(not loop.clue_ready(), "the room worked again does not give a second copy")

	# Home: across the annual boundary, with the rent clock untouched.
	check(clock.advance_to(clock.elapsed_minutes() + 30.0), "half an hour more")
	var away := clock.elapsed_minutes() - float(loop.ledger().visit.left_at)
	var back: Dictionary = loop.go_home()
	check(back.ok and back.answered and back.carried == (["order_slip"] as Array[String]) and not loop.in_visit(), "home, carrying it")
	check(at(1928, 11, 10, 0, int(away) - 30) or at(1928, 11, 10, 1, int(away) - 90) or at(1928, 11, 10, 2, int(away) - 150),
			"the present moved on by the time away, over the turn of the year (%s, %d min)" % [stamp(), int(away)])
	check(is_equal_approx(float(economy.book().started), rent_started) and int(economy.book().rent_paid) == 0
			and int(economy.book().cash) == 40, "the rent ledger never saw the trip")
	check(loop.unlocked() == (["tea"] as Array[String]), "carried evidence opens nothing until it is on the wall")
	check(str(loop.home_hint()).contains("Pin it to the case wall"), "the companion says to pin it")

	# The wall.
	var pin: Dictionary = loop.pin_next()
	check(pin.ok and str(pin.item) == "order_slip" and loop.pinned("order_slip") and int(loop.ledger().items.order_slip.slot) == 0, "pinned, in the first place on the wall")
	check("friday" in pin.opened and "stairs" in pin.opened and loop.unlocked().size() == 3, "the wall opens two leads (%s)" % str(pin.opened))
	check(not loop.pin_next().ok, "nothing more to pin")
	check(RealityState.save_game(), "home saves")

	# The companion at home, unasked.
	slips.clear()
	tick()
	check(loop.bank_cents() == 75 and slips.size() == 1 and slips[0].begins_with("DRAWN FOR YOU"), "at home the companion draws the day's allowance itself")
	tick()
	check(slips.size() == 2 and slips[1].begins_with("ADVICE") and slips[1].contains("Friday's errand"), "and then says which line is open")
	tick()
	check(slips.size() == 2 and loop.bank_cents() == 75, "once a day, not every second")

	# Fares.
	check(loop.fare_cents("friday") == 54, "the fare to 19 July from 10 November is fixed (%d)" % loop.fare_cents("friday"))
	check(loop.fare_cents("tea") > 0 and loop.fare_cents("tea") < 54, "a worked anchor is a worn groove at part fare (%d)" % loop.fare_cents("tea"))
	went = loop.jump("friday")
	check(went.ok and loop.bank_cents() == 21 and at(1929, 7, 19, 18, 20), "the fare leaves the bank with the jump (%s)" % stamp())
	check(not loop._transact("fare:friday:1", -1) and loop.bank_cents() == 21, "the same transaction cannot be booked twice")

	# The companion away, unasked; a room that waits on the hour.
	slips.clear()
	tick()
	check(slips.is_empty(), "no hint in the first minutes of a visit")
	loop.observe("4C")
	check(loop.steps_done() == 0, "being in 4C before he is home is not enough: the room waits on the hour first")
	check(clock.advance_to(clock.elapsed_minutes() + 5.0), "five minutes with the room unworked")
	tick()
	check(slips.size() == 1 and slips[0] == "HINT|" + str(loop.table.anchors.friday.steps[0].hint), "the companion offers the hint for the step itself")
	check(str(loop.command("quiet").text).contains("keep to myself") and clock.advance_to(clock.elapsed_minutes() + 20.0), "told to be quiet")
	tick()
	check(slips.size() == 1, "it keeps quiet")
	loop.observe("4C")
	check(loop.steps_done() == 2, "after twenty to seven, in 4C: two steps pass at once")
	check(str(loop.command("hints").text).contains("speak up") and clock.advance_to(clock.elapsed_minutes() + 66.0), "told it may speak; the hours are nearly over")
	tick()
	check(slips.size() == 2 and slips[1].begins_with("TIME|"), "it warns before the hours end")
	check(clock.advance_to(clock.elapsed_minutes() + 9.5), "the hours run out with the room unfinished")
	tick()
	check(loop.in_visit() and at(1929, 7, 19, 18, 20) and int(loop.ledger().anchors.friday.loops) == 1 and loop.steps_done() == 0,
			"the hours begin again by themselves, long before the dark (%s)" % stamp())
	work_room()
	check(loop.take_clue().ok and clock.advance_to(clock.elapsed_minutes() + 101.0), "the room worked and the leaf taken; the hours run out")
	slips.clear()
	tick()
	check(not loop.in_visit() and slips.any(func(line: String) -> bool: return line.begins_with("HOME|")),
			"with the evidence in hand the companion brings the player home itself")
	check(not CampaignClock.in_blackout(clock.calendar_minutes()), "and home is not in the dark (%s)" % stamp())
	before = (RealityState.data.campaign_clock as Dictionary).duplicate(true)
	went = loop.jump("stairs")
	check(not went.ok and str(went.code) == "fare" and not loop.in_visit() and RealityState.data.campaign_clock == before
			and loop.bank_cents() == 21, "a fare the bank cannot meet moves nothing")
	# Making sense of it: string between the pieces.
	var spread_before: int = loop.spread()
	check(loop.pin_next().ok and "notebook" not in loop.unlocked() and (loop.ledger().deductions as Array).is_empty(),
			"the route leaf pinned opens nothing by itself: the two pieces have to be joined")
	check(str(loop.home_hint()).contains("wants joining"), "the companion says something wants joining")
	check(not loop.link("order_slip", "order_slip").ok and not loop.link("order_slip", "nurse_note").ok,
			"a string needs two different pieces, both on the wall")
	var string: Dictionary = loop.link("order_slip", "route_leaf")
	check(string.ok and string.held and string.deductions == (["she_asked_first"] as Array[String]) and "notebook" in string.opened,
			"the string from the order slip to the route leaf holds, draws the first deduction and opens the writer upstairs")
	check(not loop.link("route_leaf", "order_slip").ok and loop.strings().size() == 1, "the same two pieces cannot be strung twice")
	check(loop.spread() > spread_before, "the case has spread")

	# The rest of the tree, walked. The bank is filled directly: fares are proved above.
	loop.ledger().bank_cents = 5000
	var order: Array[String] = ["stairs", "notebook", "button", "drain", "drama", "bench", "duplicate", "plate", "box"]
	var walked := true
	for anchor_id: String in order:
		if anchor_id not in loop.unlocked():
			walked = false
			print("  not open when reached: ", anchor_id)
			break
		went = loop.jump(anchor_id)
		work_room()
		var got: Dictionary = loop.take_clue()
		var home: Dictionary = loop.go_home()
		var put: Dictionary = loop.pin_next()
		if anchor_id == "stairs":
			var wrong: Dictionary = loop.link("order_slip", "nurse_note")
			check(wrong.ok and not wrong.held and loop.strings().size() == 1, "a string between two pieces that do not belong falls away")
		if anchor_id == "drain":
			var first: Dictionary = loop.link("nurse_note", "glove_scrap")
			check(first.held and (first.deductions as Array).is_empty() and "bench" not in loop.unlocked(),
					"a deduction of three pieces is not drawn by its first string")
			var second: Dictionary = loop.link("glove_scrap", "button_leaf")
			check(second.held and "the_glove" in second.deductions and "bench" in second.opened, "the second string draws it and opens the bench")
		join_all()
		walked = walked and went.ok and got.ok and home.ok and put.ok and not CampaignClock.in_blackout(clock.calendar_minutes())
		if not walked:
			print("  failed at: ", anchor_id, " ", went, got, home, put)
			break
	check(walked, "every lead opens from the wall in turn and gives up its evidence")
	check(loop.on_wall().size() == 11 and loop.unlocked().size() == 11 and loop.ledger().deductions.size() == 5 and loop.strings().size() == 6,
			"eleven pieces on the wall, six strings, five deductions (%d, %d, %d)" % [loop.on_wall().size(), loop.strings().size(), loop.ledger().deductions.size()])
	check(loop.spread() == 11 * 5 + 6 * 6 + 5 * 12, "the finished case is at its full spread (%d)" % loop.spread())
	check("the_case" in loop.ledger().deductions, "the last deduction is the case")
	check(str(loop.home_hint()).contains("Read the wall"), "the companion has nothing left to send the player to")

	# A strict room worked out of order puts itself back.
	went = loop.jump("drama")
	loop.observe("5B")
	check(loop.report_shift("5B_story_headphones") == "step" and loop.steps_done() == 2, "the twelfth record: first the headphones")
	resets = 0
	check(loop.report_shift("5B_tape_plain") == "fault" and loop.steps_done() == 0 and resets == 1,
			"the unlabelled tape lifted too soon: the room is as it was")
	check(loop.go_home().ok, "home")

	# The paper.
	var leads: Dictionary = loop.command("leads")
	check(str(leads.get("text", "")).contains("THE RADIATOR IN 6C") and str(leads.text).contains("WORKED")
			and str(leads.text).contains("MRS. KESSLER'S BOX"), "LEADS lists the open leads and marks the worked ones")
	check(str(loop.command("wall").text).contains("TERESA VALE'S NOTE") and str(loop.command("wall").text).contains("stands without a confession"),
			"WALL reads the wall and its deductions")
	check(loop.command("how are you").is_empty(), "ordinary correspondence is not a command")
	check(str(loop.command("jump 99").text).contains("SEE LEADS") and str(loop.command("home").text).contains("ALREADY HOME"),
			"bad commands answer plainly and change nothing")
	var banked: int = loop.bank_cents()
	check(str(loop.command("deposit 10").text).contains("BANKED") and loop.bank_cents() == banked + 10, "DEPOSIT on paper banks")
	check(RealityState.save_game(), "the finished wall saves")

	RealityState.flush_background_saves()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RealityState.save_path))
	RealityState.persistence_enabled = false
	RealityState.save_path = old_path
	RealityState.data = old_data
	RealityState.persistence_enabled = old_persistence
	print("[TEMPORAL LOOP] RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
