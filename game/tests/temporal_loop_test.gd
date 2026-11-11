extends Node
## The temporal investigation loop against the real clock, economy ledger and
## validated disk save. No world: this proves the rules, not the carriers.
const State := preload("res://scripts/game/prologue_state.gd")
const Loop := preload("res://scripts/game/temporal_loop.gd")
const Economy := preload("res://scripts/game/caretaker_economy.gd")
var failures: Array[String] = []
var checks := 0
var clock: CampaignClock
var loop: Node
var economy: Node


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])


func at(year: int, month: int, day: int, hour: int, minute: int) -> bool:
	var now := clock.local_datetime()
	return not now.is_empty() and int(now.year) == year and int(now.month) == month \
			and int(now.day) == day and int(now.hour) == hour and int(now.minute) == minute


func stamp() -> String:
	return clock.datetime_string()


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
	check(at(1929, 7, 20, 3, 2) or at(1929, 7, 20, 3, 3), "time that runs into the dark comes out at 3:02 (%s)" % stamp())
	check(clock.elapsed_minutes() > elapsed + 360.0, "and the player's own time went forward across it, never back")
	check(clock.rebase_calendar(dark - 2.0) and clock.advance_to(clock.elapsed_minutes() + 30.0)
			and not CampaignClock.in_blackout(clock.calendar_minutes()), "a set advance cannot stop inside the dark either (%s)" % stamp())
	check(clock.rebase_calendar(CampaignClock.calendar_minute_of(1929, 11, 9, 1410.0)) and at(1929, 11, 9, 23, 30), "home again for the loop")

	# The loop.
	economy = Economy.new()
	add_child(economy)
	loop = Loop.new()
	add_child(loop)
	check(loop.setup(clock, economy), "the anchors load, and none touches the murder hours")
	check(loop.unlocked() == (["tea"] as Array[String]) and loop.state() == "CHOOSE_NEXT_ACTION", "one opening lead")
	check(loop.fare_cents("tea") == 0, "the first call to the opening lead is on the house")
	check(not loop.jump("friday").ok and not loop.in_visit(), "a lead not yet opened cannot be visited")
	var rent_started: float = float(economy.book().started)
	check(int(economy.book().cash) == 100 and loop.deposit(60).ok and loop.bank_cents() == 60
			and int(economy.book().cash) == 40, "a deposit moves pocket cash to the bank")
	check(not loop.deposit(1000).ok and loop.bank_cents() == 60, "the pocket cannot bank what it does not hold")

	# Out: across the year to 13 June.
	elapsed = clock.elapsed_minutes()
	var went: Dictionary = loop.jump("tea")
	check(went.ok and int(went.fare) == 0 and loop.in_visit() and loop.state() == "RUN_LOOP", "the jump is made")
	check(at(1929, 6, 13, 16, 20) or at(1929, 6, 13, 16, 21), "the calendar reads the anchor's hour (%s)" % stamp())
	check(is_equal_approx(clock.elapsed_minutes(), elapsed), "the jump costs no elapsed time")
	check(not loop.deposit(10).ok and not loop.claim_stipend().ok and not loop.jump("tea").ok,
			"no banking, allowance or second jump while away")
	check(economy.receive("test:odd_job", 500) and int(economy.book().cash) == 540, "money can be earned in the past")
	RealityState.grant_knowledge("mt:mk_tea")
	check(clock.advance_to(clock.elapsed_minutes() + 60.0), "an hour of the visit passes")
	loop.collect()
	check(loop.holds("mt:mk_tea") and loop.state() == "RESOLVE_ANCHOR", "what was heard is in the ledger and the question is answered")

	# Save and reload in the middle of the visit.
	check(RealityState.save_game(), "the validated save accepts a campaign in mid-visit")
	RealityState.data.temporal.bank_cents = 9999
	RealityState.data.temporal.visit = {}
	RealityState.load_game()
	check(clock.bind_state() and loop.in_visit() and loop.visit_anchor() == "tea" and loop.bank_cents() == 60,
			"the reload is still away, at the same anchor, with the same bank")
	check(at(1929, 6, 13, 17, 20) or at(1929, 6, 13, 17, 21), "and at the same minute of 13 June (%s)" % stamp())
	check(is_equal_approx(loop.loop_minutes(), 60.0), "the loop clock reads the hour spent")

	# The hours again, for nothing.
	elapsed = clock.elapsed_minutes()
	var again: Dictionary = loop.reset_loop()
	check(again.ok and int(again.loops) == 1 and (at(1929, 6, 13, 16, 20) or at(1929, 6, 13, 16, 21)), "the hours begin again (%s)" % stamp())
	check(loop.bank_cents() == 60 and is_equal_approx(clock.elapsed_minutes(), elapsed), "a reset costs no fare and no elapsed time")
	check(int(economy.book().cash) == 40, "what was earned there is gone with the run")
	check(loop.holds("mt:mk_tea") and RealityState.has_knowledge("mt:mk_tea"), "what was learned there is kept")

	# Home: across the annual boundary, with the rent clock untouched.
	check(clock.advance_to(clock.elapsed_minutes() + 30.0), "half an hour more")
	var back: Dictionary = loop.go_home()
	check(back.ok and back.resolved and back.opened == (["friday"] as Array[String]) and not loop.in_visit(),
			"home, the question answered and the next lead opened")
	check(at(1928, 11, 10, 1, 0) or at(1928, 11, 10, 1, 1), "the present moved on by the ninety minutes away, over the turn of the year (%s)" % stamp())
	check(is_equal_approx(float(economy.book().started), rent_started) and int(economy.book().rent_paid) == 0
			and int(economy.book().cash) == 40, "the rent ledger never saw the trip")
	check(RealityState.save_game(), "home saves")

	# Fares.
	check(loop.fare_cents("friday") == 54, "the fare to 19 July from 10 November is fixed (%d)" % loop.fare_cents("friday"))
	check(loop.fare_cents("tea") > 0 and loop.fare_cents("tea") < 54, "an answered anchor is a worn groove at part fare (%d)" % loop.fare_cents("tea"))
	went = loop.jump("friday")
	check(went.ok and loop.bank_cents() == 6 and (at(1929, 7, 19, 17, 30) or at(1929, 7, 19, 17, 31)), "the fare leaves the bank with the jump (%s)" % stamp())
	check(not loop._transact("fare:friday:1", -1) and loop.bank_cents() == 6, "the same transaction cannot be booked twice")
	check(clock.advance_to(clock.elapsed_minutes() + 210.5), "the evening runs to its end")
	loop._poll = 5.0
	loop._process(0.1)
	check(loop.in_visit() and (at(1929, 7, 19, 17, 30) or at(1929, 7, 19, 17, 31)) and int(loop.ledger().anchors.friday.loops) == 1,
			"the anchor's hours begin again before the dark is reached (%s)" % stamp())
	back = loop.go_home()
	check(back.ok and not back.resolved and back.opened.is_empty(), "home with nothing answered opens nothing")
	before = (RealityState.data.campaign_clock as Dictionary).duplicate(true)
	went = loop.jump("friday")
	check(not went.ok and str(went.code) == "fare" and not loop.in_visit() and RealityState.data.campaign_clock == before
			and loop.bank_cents() == 6, "a fare the bank cannot meet moves nothing")
	check(loop.claim_stipend().ok and loop.bank_cents() == 21 and not loop.claim_stipend().ok and loop.bank_cents() == 21,
			"the day's allowance is drawn once")

	# The paper.
	var leads: Dictionary = loop.command("leads")
	check(str(leads.get("text", "")).contains("THE RADIATOR IN 6C") and str(leads.text).contains("ANSWERED")
			and str(leads.text).contains("FRIDAY'S ERRAND"), "LEADS lists both leads and marks the answered one")
	check(loop.command("how are you").is_empty(), "ordinary correspondence is not a command")
	check(str(loop.command("jump 9").text).contains("SEE LEADS") and str(loop.command("home").text).contains("ALREADY HOME"),
			"bad commands answer plainly and change nothing")
	check(str(loop.command("deposit 10").text).contains("BANKED") and loop.bank_cents() == 31, "DEPOSIT on paper banks")

	RealityState.flush_background_saves()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RealityState.save_path))
	RealityState.persistence_enabled = false
	RealityState.save_path = old_path
	RealityState.data = old_data
	RealityState.persistence_enabled = old_persistence
	print("[TEMPORAL LOOP] RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
