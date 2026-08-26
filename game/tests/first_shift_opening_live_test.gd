extends Node
## Production proof for the new game's first three physical facts:
## clock in, see Mina's authored paper, take that exact report.

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
	_check(not root.first_shift_director.clock_in()
			and RealityState.data.maintenance_jobs.size() == 1,
			"the committed clock-in cannot replay or duplicate the report")

	print("[FIRST SHIFT OPENING LIVE] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
