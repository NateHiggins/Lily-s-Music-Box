extends Node
## Production proof that a broken watch circuit costs evidence, not progress.
## The F02 box still records its local truth while the lobby receiver and the
## first-shift owner hear nothing; Mina's report can still be repaired, filed
## and followed by a lawful clock-out.

const JOB := "vantry_chirp_2a"

var fails := 0


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["open line live ok" if ok else "OPEN LINE LIVE FAIL", label])
	if not ok:
		fails += 1


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout

	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	var network: Node = root.find_child("WatchStationNetwork", true, false)
	var station: Node = root.find_child("F02_WATCH_STATION_01", true, false)
	var receiver: Node = root.find_child("F01_SIGNAL_REGISTER", true, false)
	var key_guard: Node = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	_check(detector != null and register != null and network != null
			and station != null and receiver != null and key_guard != null,
			"the production building owns the complete opening and watch circuit")

	_check(root.first_shift_director.begin_first_shift()
			and detector.call("interact_control", "detector", root.player)
			and register.call("take_slip"),
			"the player clocks in and takes Mina's existing authored report")
	# K2-C moved this clause into the indicative. The property under test
	# is that the station is named and never ordered.
	_check(root.objective_tracker._objective.text.contains("STATION 2")
			and not root.objective_tracker._objective.text.contains("work STATION"),
			"the report offers the watch station as optional evidence")

	_check(network.call("set_line_closed", false),
			"the production closed circuit can acquire an open-line fault")
	_check(key_guard.call("take_key")
			and station.call("interact_control", "station", root.player)
			and station.call("interact_control", "station", root.player),
			"the player takes the tour key and works F02 despite the break")
	_check(bool(station.get("drop_fallen"))
			and int(network.call("mark_count")) == 1
			and int(network.call("undelivered_count")) == 1,
			"the local drop and network retain the station's truthful mark")
	_check(int(network.call("delivered_count")) == 0
			and int(receiver.call("indication_count")) == 0
			and int(receiver.get("signals_taken")) == 0,
			"an open wire delivers nothing and moves no lobby shutter or counter")
	_check(root.first_shift_director.station_marks().is_empty()
			and root.objective_tracker._objective.text.contains("STATION 2"),
			"first shift trusts the central receiver, so the optional hint remains")

	_check(root.work_orders.diagnose_job(JOB)
			and root.work_orders.mark_job_awaiting_part(JOB)
			and root.work_orders.mark_job_repairable(JOB)
			and root.work_orders.record_job_repair(JOB, {
				"quality": "good", "note": "open-line ritual proof"}),
			"the existing WorkOrders owner reaches repaired through legal stages")
	_check(register.call("replace_slip")
			and register.call("select_outcome", "disturbance_persists")
			and register.call("sign_register"),
			"missing optional evidence cannot block returning and filing the report")
	_check(root.first_shift_director.ritual_phase()
			== FirstShiftDirector.PHASE_FILED
			and root.work_orders.job_stage(JOB) == "repaired",
			"filing advances the ritual without stealing the job lifecycle")
	_check(detector.call("control_prompt", "detector").contains("Return the tour key")
			and not root.first_shift_director.clock_out()
			and key_guard.call("return_key")
			and detector.call("interact_control", "detector", root.player)
			and root.first_shift_director.ritual_phase()
			== FirstShiftDirector.PHASE_COMPLETE,
			"the player returns custody and clocks out with the line still open")
	_check(int(network.call("mark_count")) == 1
			and int(network.call("delivered_count")) == 0
			and root.first_shift_director.station_marks().is_empty(),
			"completion neither invents nor retroactively delivers missing evidence")

	print("[FIRST SHIFT OPEN LINE LIVE] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
