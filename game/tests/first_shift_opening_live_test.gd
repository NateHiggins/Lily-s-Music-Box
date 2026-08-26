extends Node
## Production proof for the complete opening ritual: clock in, see Mina's
## authored paper, take it, return and sign the factual record, clock out.

const JOB := "vantry_chirp_2a"
const CASE := "mina_caption_crisis"

var fails := 0


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["opening live ok" if ok else "OPENING LIVE FAIL", label])
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
	_check(detector != null and register != null,
			"the production lobby owns both physical halves of the opening station")
	_check(root.work_orders.job_stage(JOB) == "missing"
			and register.call("presented_job_id") == "",
			"before clock-in neither coordinator nor register manufactures a report")
	_check(root.first_shift_director.begin_first_shift(),
			"the production first-shift owner commits the arrival")
	var cases_before := var_to_bytes(RealityState.data.cases)
	_check(detector.call("interact_control", "detector", root.player),
			"the player clocks in through the production detector")
	_check(root.work_orders.job_stage(JOB) == "issued"
			and str(root.work_orders.job_state(JOB).origin) == "reported"
			and RealityState.data.maintenance_jobs.size() == 1,
			"clock-in asks CoreLoopDirector to offer exactly one existing authored job")
	_check(var_to_bytes(RealityState.data.cases) == cases_before
			and str(RealityState.data.current_case_id) == "",
			"offering the paper activates no case")
	_check(register.call("presented_job_id") == JOB
			and register.call("slip_available"),
			"SR7-I presents Mina's issued paper on the real spindle")
	_check(register.call("take_slip"),
			"the player takes that physical report")
	_check(root.work_orders.job_stage(JOB) == "acknowledged"
			and str(RealityState.data.current_case_id) == CASE
			and str(RealityState.case_state(CASE).stage) == "active",
			"taking the paper acknowledges its job and activates only its declared case")
	var station_network: Node = root.find_child("WatchStationNetwork", true, false)
	var mark := {"station_id": "F02_STATION_2A_LANDING", "station_number": 2,
			"serves": "F02 2A", "at_minute": 181.0, "sequence": 1}
	if station_network != null:
		station_network.station_marked.emit("F02_STATION_2A_LANDING", mark)
	_check(station_network != null
			and root.first_shift_director.has_station_mark(
					"F02_STATION_2A_LANDING"),
			"the first-shift owner observes the network's neutral station fact")
	station_network.station_marked.emit("F02_STATION_2A_LANDING", mark)
	_check(root.first_shift_director.station_marks().size() == 1,
			"the same station sequence cannot duplicate optional evidence")
	_check(not root.first_shift_director.clock_in()
			and RealityState.data.maintenance_jobs.size() == 1,
			"the committed clock-in cannot replay or duplicate the report")

	# Field gameplay owns how these legal public stages are earned. This live
	# proof advances the real owner directly so it can test the station's return
	# half without duplicating ChirpHunt and shop-service coverage here.
	_check(root.work_orders.diagnose_job(JOB)
			and root.work_orders.mark_job_awaiting_part(JOB)
			and root.work_orders.mark_job_repairable(JOB)
			and root.work_orders.record_job_repair(JOB, {
				"quality": "good", "note": "production ritual proof"}),
			"the existing WorkOrders owner reaches repaired through legal stages")
	_check(register.call("replace_slip")
			and register.call("select_outcome", "disturbance_persists")
			and register.call("sign_register"),
			"the player returns Mina's paper, chooses a factual conclusion and signs")
	var lines: Array = RealityState.data.get("night_register", {}).get("lines", [])
	_check(lines.size() == 1 and str(lines[0].job_id) == JOB
			and str(lines[0].filing) == "disturbance_persists"
			and root.first_shift_director.ritual_phase()
					== FirstShiftDirector.PHASE_FILED,
			"the neutral receipt carries Mina's job and prepares physical clock-out")
	_check(root.work_orders.job_stage(JOB) == "repaired",
			"filing does not close the WorkOrder behind CoreLoopDirector")
	_check(detector.call("control_prompt", "detector").contains("Clock out")
			and detector.call("interact_control", "detector", root.player)
			and root.first_shift_director.ritual_phase()
					== FirstShiftDirector.PHASE_COMPLETE,
			"the player removes the paper and completes the production first shift")

	print("[FIRST SHIFT OPENING LIVE] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
