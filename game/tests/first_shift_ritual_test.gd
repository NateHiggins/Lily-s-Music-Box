extends Node
## Focused contract for the diegetic opening shift. The director coordinates
## desk acts; WorkOrders and RealityCases remain the only lifecycle owners.

const JOB := "lena_radiator_round_2b"
const CASE := "lena_unraveling"
const WatchmanScript := preload("res://scripts/props/watchman_clock_prop.gd")
const RegisterScript := preload("res://scripts/props/night_register_prop.gd")

var fails := 0


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["ritual ok" if ok else "RITUAL FAIL", label])
	if not ok:
		fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityCases._ready()
	var tracker := ObjectiveTracker.new()
	add_child(tracker)
	var orders := WorkOrders.new()
	orders.setup(tracker)
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	add_child(orders)
	var director := FirstShiftDirector.new()
	director.setup(null, tracker, null, orders)
	add_child(director)
	var detector: Variant = WatchmanScript.new()
	detector.bind_first_shift(director)
	add_child(detector)
	var register: Variant = RegisterScript.new()
	register._work_orders = orders
	register.report_taken.connect(director.accept_report)
	add_child(register)

	_check(not director.clock_in(), "cannot clock in before arrival is committed")
	RealityState.data.intro_complete = true
	_check(detector.control_prompt("detector").contains("Clock in"),
			"the production prop offers the first physical ritual")
	_check(detector.interact_control("detector", null),
			"the player clocks into the shift through the detector")
	_check(not detector.dial_seated and not detector.datum_set
			and not detector.detector_honest,
			"routine clock-in cannot counterfeit the detector repair")
	_check(detector.control_prompt("detector").contains("waiting reports")
			and detector.interact_control("detector", null),
			"the open shift points back to reports instead of opening repair UI")
	_check(not director.accept_report(JOB), "the desk cannot invent an unissued report")
	_check(orders.issue_job(JOB, "reported"), "the existing spine issues Lena's report")
	var jobs_before: int = RealityState.data.maintenance_jobs.size()
	_check(register.take_slip(), "taking the physical report acknowledges existing work")
	_check(RealityState.data.maintenance_jobs.size() == jobs_before
			and orders.job_stage(JOB) == "acknowledged",
			"acceptance neither duplicates nor skips the WorkOrders record")
	_check(str(RealityState.data.current_case_id) == CASE
			and str(RealityState.case_state(CASE).stage) == "active",
			"the explicit report action activates the declared existing case")
	_check(not director.accept_report(JOB), "a report cannot be taken twice")
	_check(not director.return_to_station(), "unfinished fieldwork cannot be filed")

	orders.diagnose_job(JOB)
	orders.mark_job_repairable(JOB)
	orders.record_job_repair(JOB, {"quality": "good", "note": "vent clocked"})
	_check(director.return_to_station(), "repaired work permits a return to the register")
	_check(not director.file_outcome("ghost did it"), "the register refuses interpretation as fact")
	_check(director.file_outcome("disturbance_persists"), "the player may record a factual contradiction")
	_check(detector.control_prompt("detector").contains("Clock out"),
			"filing returns the player to the physical clock")
	_check(detector.interact_control("detector", null)
			and director.ritual_phase() == FirstShiftDirector.PHASE_COMPLETE,
			"removing the paper completes the first shift")
	_check(orders.job_stage(JOB) == "repaired",
			"clocking out does not close WorkOrders behind its owner's back")

	print("[FIRST SHIFT RITUAL] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
