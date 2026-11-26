extends Node
## The temporal investigation loop against the real clock, economy ledger and
## validated disk save. No world: this proves the rules and walks the whole
## tree of leads by reporting what the hand would do. The rooms themselves are
## V2LoopStageTest's.
const State := preload("res://scripts/game/prologue_state.gd")
const Loop := preload("res://scripts/game/temporal_loop.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")
const Pocket := preload("res://scripts/game/paper_pocket.gd")
const Conversations := preload("res://scripts/game/resident_conversations.gd")
var failures: Array[String] = []
var checks := 0
var clock: CampaignClock
var loop: Node
var economy: Node
var slips: Array[String] = []
var resets := 0
## -1 until a commit first holds the case; then 1 if the correction had been
## sent by that commit (so a waiting copy is saved with it), 0 if not.
var _case_commit_had_correction := -1
var _receipt_commit_had_knowledge := -1


func _peter_receipt_available(conversations: Node) -> bool:
	return conversations.active_threads("peter_wren", "1929-11-09", 12 * 60).any(
		func(thread: Dictionary) -> bool: return thread.id == "pw_receipt")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])


func _accept_arc_slip(_ledger: Dictionary, text: String) -> bool:
	slips.append("|" + text)
	return true


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


## Give every pinned piece its day and its place.
func file_all() -> void:
	for item_id: String in loop.on_wall():
		loop.file_date(item_id, loop.item_day(item_id))
		loop.file_place(item_id, loop.item_where(item_id))


## Run string between the pieces of every deduction the wall could draw now.
func join_all() -> void:
	file_all()
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


func _check_box_clock() -> void:
	var pace := CampaignPace.new()
	var previous: CampaignPace = loop.pace
	loop.pace = pace
	var before := clock.elapsed_minutes()
	var plan: Dictionary = loop.pace_plan()
	var depart := before - float(loop.loop_minutes()) + 48.0
	check(plan.get("why") == "wait:box:nadia" and is_equal_approx(float(plan.get("until", -1)), depart),
			"holding the kept papers runs the clock only to Nadia's departure")
	check(loop.visit_hint().contains("Miss Quell") and loop.visit_hint().contains("HOME"),
			"the Box hint tells the player how to hear the exchange or leave")
	tick()
	var elapsed := 0.0
	while clock.elapsed_minutes() < depart and elapsed < 75.0:
		clock.advance_seconds(pace.seconds_for(0.1, clock.elapsed_minutes()))
		elapsed += 0.1
		tick()
	check(clock.elapsed_minutes() >= depart and clock.elapsed_minutes() < depart + 0.05
			and loop.pace_plan().is_empty() and not pace.running(),
			"the real pace lands at departure and then returns to ordinary time")
	for second in 90:
		clock.advance_seconds(pace.seconds_for(1.0, clock.elapsed_minutes()))
		tick()
	check(loop.visit_anchor() == "box" and loop.holds("kept_papers") and loop.pace_plan().is_empty()
			and is_equal_approx(clock.elapsed_minutes(), depart + 1.5),
			"ordinary time gives Nadia a full approach without expiring the Box visit")
	RealityState.grant_knowledge("m_mae_answered")
	check(loop.pace_plan().get("why") == "done:box",
			"hearing Nadia restores the normal answered-visit pace")
	RealityState.data.knowledge_flags.erase("m_mae_answered")
	loop.pace = previous


## Exercise the real correspondence receiver and its saved eight-slot queue.
## The test releases one occupied slot per pass; physical printing is covered
## by the companion suite. The final morning remains on its civil deadline.
func _check_last_night_custody() -> void:
	var arc: Dictionary = loop.ledger().arc
	for key: String in ["ending", "told", "asked", "choice"]:
		arc.erase(key)
	var old_outbox: Array = loop.ledger().get("outbox", []).duplicate()
	loop.ledger().erase("outbox")
	var paper := preload("res://scripts/device/companion_session.gd").new()
	paper._restore()
	loop._receive_slip = paper.accept_temporal_slip
	for i in paper.OUTBOX_LIMIT:
		check(paper.accept_temporal_slip(loop.ledger(), "Waiting slip %d" % i), "fill the actual outbox slot %d" % i)
	var full: Array = paper._loop_slips.duplicate()
	var end_time := CampaignClock.calendar_minute_of(1929, 11, 9, 1439.0)
	loop.here = "4B"
	check(loop.go_last_night().ok and clock.rebase_calendar(end_time - 1.0) and not loop._attend_last_night(), "no last-night encounter while away from the roof")
	loop.here = "roof"
	check(clock.rebase_calendar(end_time) and not loop._attend_last_night() and not arc.has("told") and loop.ending() == "" and not arc.has("last_night_paper"), "first reaching the roof at the close earns no ending or paper")
	check(loop.go_last_night().ok and clock.rebase_calendar(end_time - 1.0), "the missed roof can be visited again at 23:58")
	var night: Dictionary = loop.table.arc.last_night
	var expected := [Loop.received_copy(int(night.message_number), str(night.message)), night.answer, night.unfinished, night.epilogues.left]
	check(loop._attend_last_night() and loop._attend_last_night() and loop.awaiting_choice(), "late eligible roof arrival still offers the authored choice with a full printer")
	check(paper._loop_slips == full and arc.get("last_night_paper") == expected.slice(0, 3), "all three refused lines wait in authored order")
	check(clock.rebase_calendar(end_time) and loop._attend_last_night() and loop.ending() == "left" and not loop.awaiting_choice(), "leaving the line at the close commits its ending despite a full printer")
	check(arc.get("last_night_paper") == expected and RealityState.save_game(), "all four pending texts save with the ending")
	RealityState.load_game()
	check(clock.bind_state() and loop.ending() == "left", "Continue retains the recorded ending")
	paper._restore()
	check(paper._loop_slips == full and loop.ledger().arc.get("last_night_paper") == expected, "Continue restores both sides of paper custody")
	for i in expected.size():
		paper._loop_slips.pop_front()
		paper._keep_slips()
		loop._attend_last_night()
		loop._attend_last_night()
		check(paper._loop_slips.size() == full.size() and paper._loop_slips.slice(full.size() - i - 1) == expected.slice(0, i + 1), "one freed slot admits exactly the next ending slip %d" % i)
	check(not loop.ledger().arc.has("last_night_paper") and RealityState.save_game(), "completed transfer leaves no pending source")
	RealityState.load_game()
	check(clock.bind_state(), "Continue after transfer rebinds the civil clock")
	paper._restore()
	paper._loop_slips.pop_front()
	paper._keep_slips()
	loop._attend_last_night()
	check(paper._loop_slips.size() == full.size() - 1 and paper._loop_slips.slice(-4) == expected, "Continue does not replay accepted ending text")
	loop._receive_slip = _accept_arc_slip
	if old_outbox.is_empty(): loop.ledger().erase("outbox")
	else: loop.ledger().outbox = old_outbox
	paper.free()


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
	check(loop.setup(clock, economy, _accept_arc_slip), "the anchors load: every need is another lead's evidence, tiers only climb, none touches the dark")
	loop.slip.connect(func(title: String, body: String) -> void: slips.append(title + "|" + body))
	loop.stage_reset.connect(func() -> void: resets += 1)
	RealityState.state_changed.connect(func() -> void:
		if _receipt_commit_had_knowledge == -1 and loop.holds("kept_papers"):
			_receipt_commit_had_knowledge = int(RealityState.has_knowledge("m_receipt_seen"))
		if _case_commit_had_correction == -1 and "the_case" in (loop.ledger().get("deductions", []) as Array):
			_case_commit_had_correction = 1 if slips.any(func(line: String) -> bool:
					return line.contains("CORRECTION TO THE BOROUGH RECORD")) else 0)
	check(loop.table.clue_anchor.size() == 11 and loop.table.anchors.size() == 13,
			"eleven wall leads and two witnessed leads")

	# S01: before the prologue ends nothing is typed for her; after it, her
	# hands type who she was, the paper answers, and then the case is handed over.
	check(loop.arc_draft() == "" and not loop.awaiting_introduction(), "no answer is typed while the prologue is still running")
	var opening_phase: String = str(RealityState.data.prologue.phase)
	RealityState.data.prologue.phase = "prologue_complete"
	check(loop.awaiting_introduction() and loop.arc_draft() == "Adela Voss. Photo Supplies. Across the street.",
			"after the prologue her hands type her name, trade and street")
	var refused: Dictionary = loop.command("Adela Voss. Photo Supplies. Across the street.")
	check(str(refused.get("text", "")) == "SUBJECT: ADELA VOSS. TRADE: PHOTOGRAPHER."
			and loop.arc_draft() == "Adela Voss. Photo Supplies. Across the street." and not (loop.ledger().get("arc", {}) as Dictionary).has("s01"),
			"a reply the paper has not taken counts for nothing: a refused print leaves her line to be sent again")
	var told: Dictionary = loop.command("Adela Voss. Photo Supplies. Across the street.")
	(told.on_printed as Callable).call()
	check(str(told.get("text", "")) == "SUBJECT: ADELA VOSS. TRADE: PHOTOGRAPHER." and loop.arc_draft() == "Is that enough?",
			"sent again and printed, the paper files her and she asks if it is enough (%s)" % str(told.get("text", "")))
	(refused.on_printed as Callable).call()
	(told.on_printed as Callable).call()
	check(loop.arc_draft() == "Is that enough?", "a stale or repeated acceptance moves nothing")
	var handed: Dictionary = loop.command("leads")
	(handed.on_printed as Callable).call()
	check(str(handed.get("text", "")).begins_with("It is enough to address you correctly.")
			and str(handed.get("text", "")).contains("LEADS") and not loop.awaiting_introduction() and loop.arc_draft() == "",
			"whatever is sent, the second answer comes first and hands over the commands")
	check(str(loop.command("leads").get("text", "")) == loop.leads_text(), "after that the keyboard is the loop's own")
	RealityState.data.prologue.phase = opening_phase
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
	check(str(loop.home_hint()).contains("Take them down"), "the companion says to clear the wall first")

	# The wall. It is an ordinary wall first: her household papers come down before it takes evidence.
	check(not loop.wall_cleared() and str(loop.pin_next().get("code", "")) == "wall" and not loop.pinned("order_slip"), "the wall takes nothing while her own papers are on it")
	var first_cover := str(loop.table.wall_covers[0].id)
	check(not loop.cover_down("no_such_paper") and loop.cover_down(first_cover) and not loop.cover_down(first_cover), "a paper comes down once, and only a real one")
	for cover: Dictionary in loop.table.wall_covers:
		loop.cover_down(str(cover.id))
	check(loop.wall_cleared() and loop.covers_down().size() == (loop.table.wall_covers as Array).size(), "with every paper down the wall is clear")
	check(str(loop.home_hint()).contains("Pin it to the case wall"), "and then the companion says to pin it")
	# Clippings: cut at home from her own papers, each paper once.
	RealityState.data["newspapers_collected"] = ["record:1928-11-10", "speaker:1928-11-12"]
	check(loop.clippings().is_empty() and loop.next_cutting() == "speaker:1928-11-12", "with papers kept, the newest is next under the scissors")
	var cut: Dictionary = loop.cut_clipping()
	check(cut.ok and str(cut.paper) == "speaker:1928-11-12" and loop.clippings() == ["speaker:1928-11-12"], "a cutting is made and kept")
	check(loop.cut_clipping().ok and loop.next_cutting().is_empty() and str(loop.cut_clipping().get("code", "")) == "no_paper", "each paper is cut once, and then there is nothing left to cut")
	(Pocket.book().comics as Array).append("lilith_01")
	check(loop.next_cutting() == "comic:lilith_01" and loop.cut_clipping().ok and loop.next_cutting().is_empty(), "a comic in the case can be cut too")
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
	check(slips.size() == 2 and slips[1].begins_with("ADVICE") and slips[1].contains("has no day"), "and then says the pinned slip wants its day")
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
	check(slips.size() == 1 and slips[0].begins_with("CLOCK|") and slips[0].contains("18:40"),
			"no hint in the first minutes of a visit; the companion says it is running the clock to the hour the room waits on")
	loop.observe("4C")
	check(loop.steps_done() == 0, "being in 4C before he is home is not enough: the room waits on the hour first")
	check(clock.advance_to(clock.elapsed_minutes() + 5.0), "five minutes with the room unworked")
	tick()
	check(slips.size() == 1, "while the clock is being run to that hour it does not hint as well")
	check(str(loop.command("hint").text) == str(loop.table.anchors.friday.steps[0].hint), "asked, it gives the hint for the step itself")
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
	# Filing: a day and a place for each piece.
	check(str(loop.home_hint()).contains("has no day") and not loop.link("order_slip", "route_leaf").ok,
			"pinned pieces must be filed before any string will run between them")
	check(loop.item_day("order_slip") == 215 and loop.days_in_year() == 365, "13 June is day 215 of the year that began on 10 November")
	var wrong_day: Dictionary = loop.file_date("order_slip", 100)
	check(wrong_day.ok and not wrong_day.held and not loop.dated("order_slip"), "set against the wrong part of the year, the tag does not hold")
	check(loop.file_date("order_slip", 219).held and loop.dated("order_slip") and not loop.file_date("order_slip", 215).ok,
			"within a few days of its day, it holds, once")
	check(str(loop.home_hint()).contains("no place"), "then the companion asks for its place")
	var wrong_place: Dictionary = loop.file_place("order_slip", "5B")
	check(wrong_place.ok and not wrong_place.held and not loop.file_place("order_slip", "9Z").ok, "a string to the wrong room falls, and a room not on the map is no room")
	check(loop.file_place("order_slip", "6C").held and loop.filed("order_slip"), "to 6C, where it was found, it holds")
	file_all()
	check(loop.filed("route_leaf") and loop.undated() == "", "the route leaf is filed too")
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
	var conversations := Conversations.new()
	conversations._load_mystery()
	var ewald_choice: Dictionary = conversations.mystery.mr_ewald.nodes.ew_l1.choices[0]
	check(not _peter_receipt_available(conversations) and not conversations._available("mr_ewald", ewald_choice),
		"Peter's receipt topic and Ewald's receipt question are unavailable before pickup")
	for anchor_id: String in order:
		if anchor_id not in loop.unlocked():
			walked = false
			print("  not open when reached: ", anchor_id)
			break
		went = loop.jump(anchor_id)
		work_room()
		check(not RealityState.has_knowledge("m_receipt_seen"), "the receipt remains unknown before the papers are taken")
		var got: Dictionary = loop.take_clue()
		check(RealityState.has_knowledge("m_receipt_seen") == (anchor_id == "box"),
			"only collecting the kept papers teaches the August receipt")
		if anchor_id == "box":
			_check_box_clock()
		var home: Dictionary = loop.go_home()
		var put: Dictionary = loop.pin_next()
		file_all()
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
	check(RealityState.has_knowledge("m_receipt_seen"), "returning home keeps the receipt knowable")
	check(_receipt_commit_had_knowledge == 1, "the same commit saves the kept papers and the receipt knowledge")
	check(_peter_receipt_available(conversations) and conversations._available("mr_ewald", ewald_choice),
		"the receipt opens Peter's topic and Ewald's explicit question")
	# Model an older save containing the papers but missing their knowledge flag.
	RealityState.data.knowledge_flags.erase("m_receipt_seen")
	check(RealityState.save_game(), "a campaign holding the kept papers saves without the old missing flag")
	RealityState.load_game()
	check(RealityState.can_continue() and not RealityState.has_knowledge("m_receipt_seen"),
		"the older save loads and supplies the original papers")
	var restored := Loop.new()
	add_child(restored)
	check(restored.setup(clock, null) and RealityState.has_knowledge("m_receipt_seen"),
		"loading a campaign that already holds the kept papers recovers the receipt")
	check(RealityState.data.knowledge_flags.count("m_receipt_seen") == 1,
		"the receipt knowledge is restored once")
	check(_peter_receipt_available(conversations) and conversations._available("mr_ewald", ewald_choice),
		"the restored papers reopen Peter's topic and Ewald's explicit question")
	restored.free()
	conversations.free()
	check(loop.on_wall().size() == 11 and loop.unlocked().size() == 11 and loop.ledger().deductions.size() == 5 and loop.strings().size() == 6,
			"eleven pieces on the wall, six strings, five deductions (%d, %d, %d)" % [loop.on_wall().size(), loop.strings().size(), loop.ledger().deductions.size()])
	check(loop.spread() == 11 * 5 + 6 * 6 + 5 * 12 and is_equal_approx(loop.spread_fraction(), 1.0), "the finished case is at its full spread (%d)" % loop.spread())
	check("the_case" in loop.ledger().deductions, "the last deduction is the case")
	check(_case_commit_had_correction == 1,
			"the commit that first saves the case already carries its correction (%d)" % _case_commit_had_correction)
	var correction_slip := false
	for sent: String in slips:
		correction_slip = correction_slip or (sent.contains("CORRECTION TO THE BOROUGH RECORD, 21 JULY 1929.")
				and sent.contains("CASE FINDING: MAE KESSLER PUSHED HER."))
	check(correction_slip, "drawing the case prints the correction to the Record's July account")
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

	# The market breaks, and the house feels it.
	loop.aide().quiet = false
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 10, 20, 600.0)) and loop.tip_percent_now() == 100
			and loop.allowance_cents() == 15 and loop.event_on(loop.today()).is_empty(), "on 20 October money is as it was")
	var whole_tip: int = economy.tip("test:before", "mina_vale", 1.0, clock.elapsed_minutes(), false)
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 10, 25, 600.0)) and not loop.event_on(loop.today()).is_empty()
			and not bool(loop.event_on(loop.today()).broken) and loop.tip_percent_now() == 100, "on the 25th the market is falling but nothing has been cut yet")
	loop.aide().drawn_day = int(clock.elapsed_minutes() / 1440.0)
	loop._attend_releases()
	slips.clear()
	tick()
	check(slips.size() == 1 and slips[0].begins_with("THE BREAK|") and slips[0].contains("ticker"), "the companion says the house is uneasy, once")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 10, 30, 600.0)) and loop.tip_percent_now() == 60
			and loop.allowance_cents() == 10, "from the 29th tips are six tenths and the allowance is ten cents")
	var short_tip: int = economy.tip("test:after", "mina_vale", 1.0, clock.elapsed_minutes(), false)
	check(whole_tip > 0 and short_tip == maxi(1, whole_tip * 60 / 100), "a tip for the same job is smaller (%d, then %d)" % [whole_tip, short_tip])
	slips.clear()
	tick()
	check(slips.size() == 1 and slips[0].begins_with("THE BREAK|") and slips[0].contains("cut the allowance"), "the companion says what has been cut")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1928, 11, 12, 600.0)) and loop.tip_percent_now() == 100
			and loop.allowance_cents() == 15, "when the year turns, money is as it was")

	# The pace of time: nobody waits out an hour.
	var pace := CampaignPace.new()
	check(not pace.running() and is_equal_approx(pace.seconds_for(0.5, 100.0), 0.5), "ordinarily a second is a second")
	check(pace.run_to(130.0, 90.0, "test:wait") and pace.running() and not pace.run_to(130.0, 0.5, "test:slow")
			and not pace.run_to(INF, 90.0, "test:never"), "a run needs a real goal and a rate above one")
	var real := 0.0
	var now := 100.0
	var fastest := 1.0
	for frame in 6000:
		if not pace.running():
			break
		var added := pace.seconds_for(1.0 / 60.0, now)
		fastest = maxf(fastest, pace.rate)
		now += added / 60.0
		real += 1.0 / 60.0
	check(not pace.running() and now >= 130.0 - 0.001 and now < 130.05, "thirty minutes are run to and not past (%.3f)" % now)
	check(real < 45.0 and fastest > 60.0 and fastest <= 90.0, "in well under a minute of real time (%.1f s, %.0f times at most)" % [real, fastest])
	check(is_equal_approx(pace.rate, 1.0) and pace.reason.is_empty(), "and time is ordinary again on arrival")
	pace.run_to(5000.0, 500.0, "test:cap")
	for frame in 600:
		pace.seconds_for(1.0 / 60.0, 100.0)
	check(pace.rate <= CampaignPace.MAX_RATE, "no request runs the clock past the ceiling")
	pace.hold("talk")
	check(not pace.running() and is_equal_approx(pace.seconds_for(1.0, 100.0), 1.0), "a hold makes time ordinary while it lasts")
	pace.release("talk")
	check(pace.running(), "and the run resumes when the hold is let go")
	pace.settle()

	# The loop asks for the run. A room that waits on the hour: the Friday errand waits for 18:40.
	loop.pace = pace
	loop.aide().quiet = false
	loop.ledger().bank_cents = 500
	var friday_clue := str(loop.clue_of("friday").id)
	var kept: Dictionary = (loop.ledger().items as Dictionary).duplicate(true)
	(loop.ledger().items as Dictionary).erase(friday_clue)
	check(loop.pace_plan().is_empty(), "at home, with the player just now busy, time is ordinary")
	check(loop.jump("friday").ok and loop.in_visit(), "to the Friday errand again, unanswered for the test")
	var plan: Dictionary = loop.pace_plan()
	check(str(plan.get("why", "")) == "wait:friday:" + str(loop.current_step().id) and is_equal_approx(float(plan.until), clock.elapsed_minutes() + 20.0),
			"the room can only be waited on, so the clock is to run twenty minutes")
	slips.clear()
	real = 0.0
	for frame in 6000:
		clock.advance_seconds(pace.seconds_for(1.0 / 60.0, clock.elapsed_minutes()))
		real += 1.0 / 60.0
		if frame % 60 == 0:
			tick()
			loop.observe("")
		if str(loop.current_step().get("kind", "")) != "after":
			break
	check(str(loop.current_step().get("kind", "")) == "at" and real < 40.0, "the hour comes in %.1f real seconds, not twenty minutes" % real)
	check(loop.loop_minutes() >= 20.0 and loop.loop_minutes() < 21.5, "and is not run past (%.2f minutes into the room)" % loop.loop_minutes())
	check(slips.filter(func(text: String) -> bool: return text.begins_with("CLOCK|")).size() == 1, "the companion says once that it is running the clock")
	check(slips.filter(func(text: String) -> bool: return text.begins_with("HINT|")).is_empty(), "and does not hint through minutes it is running")
	tick()
	check(loop.pace_plan().is_empty() and not pace.running(), "with something to do in the room, time is ordinary")
	check(str(loop.command("wait").text).contains("SOMETHING TO DO"), "WAIT says so")
	# The evidence taken: the rest of the hours are run out and the companion brings the player home.
	work_room()
	check(loop.take_clue().ok and str(loop.pace_plan().get("why", "")) == "done:friday", "with the evidence in hand the clock is to run to the end of the hours")
	check(str(loop.command("steady").text).contains("OWN TIME") and loop.pace_plan().is_empty(), "STEADY holds the clock to its own time")
	tick()
	check(not pace.running(), "and a run in progress stops")
	check(str(loop.command("wait").text).contains("HELD STEADY") and str(loop.command("pace").text).contains("WILL RUN")
			and not loop.pace_plan().is_empty(), "PACE lets it run again")
	real = 0.0
	for frame in 9000:
		clock.advance_seconds(pace.seconds_for(1.0 / 60.0, clock.elapsed_minutes()))
		real += 1.0 / 60.0
		if frame % 60 == 0:
			tick()
		if not loop.in_visit():
			break
	check(not loop.in_visit() and real < 75.0, "the remaining hour and more passes in %.1f real seconds and the player is home" % real)
	check(not pace.running() and loop.holds(friday_clue), "time is ordinary at home and the evidence came too")
	check(loop._idle < 1.0, "coming home is not counted as standing idle")
	loop._idle = 60.0
	check(not loop.carried().is_empty() and loop.pace_plan().is_empty(), "with evidence to pin, the clock does not run off however long the player stands")
	tick()
	check(not pace.running(), "and it does not run")
	loop.ledger().items = kept
	# Idle at home.
	loop._idle = 0.0
	check(loop.pace_plan().is_empty(), "at home, busy, time is ordinary")
	loop._idle = 60.0
	plan = loop.pace_plan()
	check(str(plan.get("why", "")).begins_with("idle:") and float(plan.until) > clock.elapsed_minutes()
			and is_zero_approx(fposmod(float(plan.until), 1440.0)), "left idle, the clock is to run to the next day and no further")
	tick()
	check(pace.running(), "and it runs")
	loop.note_activity()
	check(not pace.running() and loop.pace_plan().is_empty(), "anything the player does stops it at once")
	check(str(loop.command("wait").text).contains("TOMORROW") and pace.running() and str(loop.pace_plan().why).begins_with("asked:"), "WAIT at home runs to the next allowance")
	# Ruling allowance_wait_pace_20261122: with no fare in reach, WAIT runs a game day in four minutes; money unchanged.
	var kept_bank: int = loop.bank_cents()
	var kept_cash := int(economy.book().cash)
	# Every open lead is worked by now, which counts as affordable: nothing to pay for. Reopen one by setting its
	# clue aside, and mark it paid once so its fare is not the free first call.
	var kept_items: Dictionary = (loop.ledger().items as Dictionary).duplicate(true)
	var kept_records: Dictionary = (loop.ledger().anchors as Dictionary).duplicate(true)
	check(loop.lead_affordable(), "with every open lead worked, there is nothing to afford and WAIT keeps the idle rate")
	var reopened := ""
	for anchor_id: String in loop.unlocked():
		if loop._witness_of(anchor_id).is_empty() and loop.answered(anchor_id):
			reopened = anchor_id
			break
	(loop.ledger().items as Dictionary).erase(str(loop.clue_of(reopened).id))
	loop._record(reopened).paid = 1
	var open_fare: int = loop.fare_cents(reopened)
	check(not reopened.is_empty() and not loop.answered(reopened) and open_fare > 0 and reopened in loop.unlocked(),
			"a paid lead is open to test the broke WAIT against (%s, %d cents)" % [reopened, open_fare])
	loop.ledger().bank_cents = 0
	economy.book().cash = open_fare - 1
	check(not loop.lead_affordable() and is_equal_approx(float(loop.pace_plan().get("rate", 0.0)), 360.0)
			and str(loop.pace_plan().why).begins_with("asked:"), "with every fare out of reach, WAIT runs at the broke rate (360)")
	tick()
	check(pace.rate <= CampaignPace.MAX_RATE and is_equal_approx(CampaignPace.MAX_RATE, 360.0), "and the ceiling allows it")
	economy.book().cash = open_fare
	check(loop.lead_affordable() and is_equal_approx(float(loop.pace_plan().get("rate", 0.0)), 60.0),
			"pocket cash that covers a fare is one DEPOSIT away, so WAIT runs at the idle rate")
	loop.ledger().bank_cents = kept_bank
	economy.book().cash = kept_cash
	loop.ledger().items = kept_items
	loop.ledger().anchors = kept_records
	loop.note_activity()
	check(pace.running(), "and a run that was asked for is not stopped by moving about")
	loop.command("steady")
	check(not pace.running(), "STEADY stops it")
	loop.command("pace")
	# A conversation or a call keeps the clock to its own time.
	check(str(loop.command("wait").text).contains("TOMORROW") and pace.running(), "a run is asked for again")
	loop.hold_pace("talk")
	check(not pace.running() and pace.held() and is_equal_approx(pace.seconds_for(1.0, clock.elapsed_minutes()), 1.0), "a conversation holds the clock to its own time")
	loop._idle = 60.0
	loop._process(0.1)
	check(loop._idle < 1.0, "and nobody talking is standing idle")
	slips.clear()
	tick()
	check(not pace.running() and slips.filter(func(text: String) -> bool: return text.begins_with("CLOCK|")).is_empty(), "nothing is said about the clock while it lasts")
	loop.hold_pace("call")
	loop.release_pace("talk")
	check(not pace.running(), "two holds are two: one let go leaves the other")
	loop.release_pace("call")
	check(pace.running() and loop._idle < 1.0, "when the last is let go the run that was asked for goes on")
	loop.command("steady")
	loop.command("pace")

	# A ledger that does not agree with itself is put in order, and evidence is never the price.
	var pieces := (loop.ledger().items as Dictionary).size()
	loop.ledger().bank_cents = 500
	check(loop.jump("tea").ok, "away once more")
	var pocket_before: Variant = (RealityState.data.get("caretaker_economy", {}) as Dictionary).duplicate(true)
	loop.ledger().state = "RESET_LOOP"
	check(loop.mend() == ["state_between"] and loop.state() == "RUN_LOOP", "a save caught between two states is mended")
	loop.ledger().visit.stage = {"done": ["no_such_step"]}
	check(loop.mend() == ["steps"] and loop.steps_done() == 0, "steps the room does not have are forgotten")
	loop.ledger().state = "CHOOSE_NEXT_ACTION"
	check(loop.mend() == ["state_away"] and loop.in_visit(), "a visit that says it is home is known for a visit")
	loop._abandon_visit()
	check(not loop.in_visit() and loop.state() == "CHOOSE_NEXT_ACTION" and (loop.ledger().items as Dictionary).size() == pieces
			and RealityState.data.get("caretaker_economy", {}) == pocket_before, "a visit that cannot end any other way is closed, the borrowed world given back, the evidence kept")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1928, 11, 12, 600.0)), "home for the last checks")
	loop.ledger().visit = {"anchor": "a_lead_since_cut", "loop_started": 0.0, "world": {}}
	loop.ledger().state = "INVESTIGATE"
	check("lost_lead" in loop.mend() and not loop.in_visit() and loop.state() == "CHOOSE_NEXT_ACTION", "a visit to a lead that no longer exists ends at home")
	check(loop.mend().is_empty() and Loop.valid(loop.ledger()), "a ledger in order is left alone")

	# Trying to save her: FRIDAY, an attempt, the snap to 3:02 and the key book.
	check(loop.rescue_open() and str(loop.leads_text()).contains("FRIDAY takes you"), "once Friday's lead is worked, LEADS offers the evening")
	RealityState.grant_knowledge("mt:av_nineteen")
	RealityState.grant_knowledge("mt:co_keep")
	RealityState.grant_knowledge("m_o2_stood_roof")
	var evening: Dictionary = loop.command("friday")
	check(str(evening.get("text", "")).begins_with("19 JULY, SIX O'CLOCK") and loop.today() == "1929-07-19" and loop._minute_of_day() == 18 * 60
			and not RealityState.has_knowledge("mt:av_nineteen") and not RealityState.has_knowledge("mt:co_keep")
			and not RealityState.has_knowledge("m_o2_stood_roof"),
			"FRIDAY sets the present to six o'clock on 19 July, and she will ask for the key again (%s)" % stamp())
	var rescue_at := slips.size()
	loop._attend_rescue()
	check(slips.size() == rescue_at, "through the evening the book waits")
	RealityState.grant_knowledge("m_o2_kept_shop")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 19, 21.0 * 60.0)), "nine o'clock")
	clock.advance_seconds(120.0)
	check(loop.today() == "1929-07-20" and loop._minute_of_day() >= 3 * 60 + 2 and loop._minute_of_day() < 3 * 60 + 4,
			"two minutes on, the record stops at 21:01 and the present is 3:02 on the 20th (%s)" % stamp())
	loop._attend_rescue()
	check(slips.size() == rescue_at + 2 and slips[rescue_at] == "|SATURDAY 20 JULY, 3.02 A.M. THE NEXT RECORDED MOMENT."
			and slips.back() == "|THE KEY BOOK, IN GREASE PENCIL:\nWARNED A.V. AT THE SHOP. SHE AGREED TO STAY. VISIT ENDED AT 21:01. AT 03:02 THE BODY WAS PRESENT.",
			"the key book gains one honest line for the attempt, ending at 21:01 and 3:02")
	check(RealityState.has_knowledge("m_rescue_seen"), "and the companion may now be told about it")
	loop._attend_rescue()
	check(slips.size() == rescue_at + 2, "the evening is written once")
	check(loop.go_friday().ok, "FRIDAY again")
	RealityState.grant_knowledge("m_o2_refused_key")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 25, 720.0)), "and away before nine")
	loop._attend_rescue()
	check(slips.size() == rescue_at + 3 and slips.back() == "|THE KEY BOOK, IN GREASE PENCIL:\nREFUSED A.V. THE ROOF KEY AT 18:05.",
			"left before 21:01, the line says only what was done, and nothing of 3:02")
	RealityState.grant_knowledge("m_key_loan_11")
	RealityState.grant_knowledge("m_key_loan_19")
	check(str(loop.command("book").get("text", "")) == "THE KEY BOOK, IN GREASE PENCIL:\n11 JULY, A.V., ROOF.\n19 JULY, A.V., ROOF, STORM.\n"
			+ "WARNED A.V. AT THE SHOP. SHE AGREED TO STAY. VISIT ENDED AT 21:01. AT 03:02 THE BODY WAS PRESENT.\nREFUSED A.V. THE ROOF KEY AT 18:05.",
			"BOOK reads the loans she signed for and every attempt, in order")
	(RealityState.data.knowledge_flags as Array).erase("m_key_loan_11")
	check(loop.go_friday().ok, "FRIDAY a third time")
	RealityState.grant_knowledge("m_o2_kept_envelope")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 25, 720.0)), "and away again")
	loop._attend_rescue()
	check(slips.size() == rescue_at + 4 and slips.back() == "|THE KEY BOOK, IN GREASE PENCIL:\nKEPT AN ENVELOPE FOR 6C.",
			"keeping Cam's envelope for 6C writes its own honest line")

	# The end: the correction, the last night on the roof, and the choice.
	check(loop.case_closed() and loop.last_night_open() and str(loop.leads_text()).contains("LAST takes you to it"),
			"LEADS offers the last night once the case is closed")
	var night: Dictionary = loop.command("last")
	check(str(night.get("text", "")).begins_with("9 NOVEMBER, HALF PAST NINE") and loop.today() == "1929-11-09"
			and loop._minute_of_day() == 21 * 60 + 30, "LAST sets the present to 9 November, half past nine (%s)" % stamp())
	var said := slips.size()
	loop.here = "4B"
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 23.0 * 60.0 + 41.0)) and not loop._attend_last_night()
			and slips.size() == said, "at 23:41 in 4B the night says nothing")
	loop.here = "roof"
	check(loop._attend_last_night() and slips.size() == said + 2
			and slips[said] == "|RECEIVED COPY 6. SUBJECT RELEASED BUT ONE. BRIDGE CLOSES 24:00. INSTRUMENT TO BE RETIRED. INSTRUMENT, ACKNOWLEDGE."
			and slips[said + 1] == "|I have no service interval for this. I shall keep the line open.",
			"on the roof M6 prints verbatim, then the companion's one answer")
	check(loop.arc_draft() == "" and str(loop.command("leads").get("text", "")).contains("LAST"), "before 23:57 the keyboard is ordinary")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 23.0 * 60.0 + 57.0)) and loop._attend_last_night()
			and slips.back() == "|I WOULD LIKE TO" and loop.arc_draft().begins_with("CROSS OUT"),
			"at 23:57 it writes I WOULD LIKE TO and stops, and her hands can finish it")
	var unprinted: Dictionary = loop.command(loop.arc_draft())
	check(loop.arc_draft().begins_with("CROSS OUT") and str(unprinted.get("text", "")).contains("NIGHT MAN, 4B."),
			"a card the paper has not taken chooses nothing: her line waits on the keyboard")
	var card: Dictionary = loop.command(loop.arc_draft())
	(card.on_printed as Callable).call()
	check(str(card.get("text", "")).contains("NIGHT MAN, 4B.") and str(card.text).ends_with("A.V.") and loop.arc_draft() == ""
			and loop.ending() == "", "sending it prints her correction card; the bridge has not closed yet")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 23.0 * 60.0 + 59.0)) and loop._attend_last_night()
			and loop.ending() == "finished" and str(slips.back()).contains("ENTIRELY HIS OWN") and not loop.last_night_open(),
			"at the close the finished line's morning follows")
	check(str(loop.command("last").get("text", "")) == "THE YEAR IS OVER.", "and the night does not open again")
	for key: String in ["ending", "choice", "told", "asked"]:
		(loop.ledger().arc as Dictionary).erase(key)
	check(loop.go_last_night().ok and clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 23.0 * 60.0 + 45.0))
			and loop._attend_last_night() and clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 23.0 * 60.0 + 57.0))
			and loop._attend_last_night() and clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 23.0 * 60.0 + 59.0))
			and loop._attend_last_night() and loop.ending() == "left" and str(slips.back()).contains("BOX 4B IS EMPTY"),
			"left unfinished, the bridge closes on the empty box")
	_check_last_night_custody()
	loop.here = ""
	# The Tenant's received copies: presence, not the calendar, delivers them.
	var phase_before: String = str(RealityState.data.prologue.phase)
	RealityState.data.prologue.phase = "prologue_complete"
	(loop.ledger().arc as Dictionary).erase("copies")
	loop.here = "lobby"
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 2, 600.0)), "resume a late campaign without copies")
	var late_at := slips.size()
	loop._attend_copies()
	check(slips.size() == late_at and not (loop.ledger().arc as Dictionary).has("copies"),
			"the first copy holds the entire sequence until the player visits 4B")
	loop.here = "4B"
	loop._attend_copies()
	var numbers: Array[int] = []
	for line: String in slips.slice(late_at):
		numbers.append(int(line.trim_prefix("|RECEIVED COPY ").get_slice(".", 0)))
	check(numbers == [1, 2, 3, 4, 5] and loop.ledger().arc.copies == numbers,
			"4B receives the full late sequence in order, exactly once")
	loop.ledger().arc.copies = JSON.parse_string(JSON.stringify(numbers))
	loop._attend_copies()
	check(slips.size() == late_at + 5, "loaded numeric serials do not publish a second sequence")
	slips.resize(late_at)
	(loop.ledger().arc as Dictionary).erase("copies")
	loop.here = "lobby"
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 19, 720.0)), "midday on 19 July")
	var copies_at := slips.size()
	loop._attend_copies()
	check(slips.size() == copies_at, "M1 waits for her first moments in 4B")
	loop.here = "4B"
	loop._attend_copies()
	check(slips.size() == copies_at + 1 and slips.back() == "|RECEIVED COPY 1. CONVEYANCE ACCEPTED. SPAN: UNTIL RELEASED.",
			"in 4B, M1 prints with the Tenant's own count first")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 19, 20.0 * 60.0 + 59.0)), "before the missing hours")
	loop._attend_copies()
	check(slips.size() == copies_at + 1, "M2 stays pending before 03:02")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 7, 20, 3.0 * 60.0 + 2.0)), "3:02 on 20 July")
	loop._attend_copies()
	check(slips.size() == copies_at + 2 and slips.back() == "|RECEIVED COPY 2. 21:01 TO 03:02 NOT HEARD HERE EITHER.",
			"M2 at 3:02, never before")
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 2, 600.0)), "2 November")
	loop._attend_copies()
	loop._attend_copies()
	check(slips.size() == copies_at + 5 and str(slips[copies_at + 2]).begins_with("|RECEIVED COPY 3. INSTRUMENT AT THE ARCADE WINDOW")
			and str(slips[copies_at + 3]).begins_with("|RECEIVED COPY 4.") and str(slips.back()).begins_with("|RECEIVED COPY 5."),
			"first present on 2 November, M3 to M5 print in order, each once")
	RealityState.data.prologue.phase = phase_before
	loop.here = ""
	(loop.ledger().arc as Dictionary).erase("released")
	var before_release := slips.size()
	loop._attend_releases()
	loop._attend_releases()
	check(slips.slice(before_release) == ["|RELEASED: THE NEGATIVES.", "|RELEASED: PLATE 13."],
			"taken evidence releases the negatives and plate once, independently of the telling")
	before_release = slips.size()
	RealityState.grant_knowledge("mt:ev_home")
	loop._attend_releases()
	loop._attend_releases()
	check(slips.slice(before_release) == ["|RELEASED: THE SHOP.", "|RELEASED: EMIL."],
			"Emil taking the prints home releases the shop, then Emil, exactly once")
	before_release = slips.size()
	RealityState.grant_knowledge("m_told_nadia")
	loop._attend_releases()
	loop._attend_releases()
	check(slips.slice(before_release) == ["|RELEASED: NADIA."] and "m_told_nadia" in loop.ledger().arc.released,
			"the telling releases Nadia once and retains the compatible receipt identity")
	RealityState.grant_knowledge("m_key_loan_11")
	loop._attend_releases()
	check(slips.size() == before_release + 2 and slips.back() == "|RELEASED: THE ROOF.", "signing for the roof on 11 July releases the roof")

	# Adela's attachments (design/ORISON_ADELA_ATTACHMENTS_2026-11-22.md): five
	# case residents let go of what she left with them, each with a release print.
	var dreams: Array[String] = []
	var ask_dream := func(profile: String) -> bool:
		dreams.append(profile)
		return true
	loop.bind_release_dreams(ask_dream)
	check(dreams.is_empty(), "binding before any attachment is released asks for no dream")
	before_release = slips.size()
	RealityState.grant_knowledge("m_recorder_limit")
	loop._attend_releases()
	check(slips.size() == before_release and dreams.is_empty(),
			"Omar's bell heard before 19 July has happened releases nothing")
	for attachment: Array in [["m_mina_light", "THE LIGHT IN THE SHOP.", "mina"],
			["m_peter_will_sign", "THE CLAUSE.", "peter"], ["m_heard_self", "THE SONG.", "juno"],
			["m_door_match", "THE BROADCAST.", "cal"]]:
		before_release = slips.size()
		RealityState.grant_knowledge(str(attachment[0]))
		loop._attend_releases()
		loop._attend_releases()
		check(slips.slice(before_release) == ["|RELEASED: " + str(attachment[1])]
				and dreams.back() == str(attachment[2]) + "_release_print" and dreams.count(dreams.back()) == 1,
				"%s releases %s once and asks for %s's release print" % [attachment[0], attachment[1], attachment[2]])
	before_release = slips.size()
	RealityState.grant_knowledge("m_c_n16")
	loop._attend_releases()
	check(slips.slice(before_release) == ["|RELEASED: THE NIGHT OF 19 JULY.", "|RELEASED: THE BELL."]
			and dreams.back() == "omar_release_print", "once the night has happened, the bell is let go after it")
	# S14: Nadia says the name in 6C, and Mae is the last attachment let go.
	before_release = slips.size()
	RealityState.grant_knowledge("m_mae_answered")
	loop._attend_releases()
	loop._attend_releases()
	check(slips.slice(before_release) == ["|RELEASED: MRS. KESSLER."] and dreams.back() == "mae_release_print"
			and dreams.count("mae_release_print") == 1, "Nadia's answer in S14 releases MRS. KESSLER once and asks for Mae's print")
	dreams.clear()
	loop.bind_release_dreams(ask_dream)
	check(dreams == ["mina_release_print", "peter_release_print", "juno_release_print", "cal_release_print", "omar_release_print",
			"mae_release_print"],
			"rebinding asks again for every released print; the dream owner refuses what it already has")

	RealityState.flush_background_saves()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RealityState.save_path))
	RealityState.persistence_enabled = false
	RealityState.save_path = old_path
	RealityState.data = old_data
	RealityState.persistence_enabled = old_persistence
	print("[TEMPORAL LOOP] RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
