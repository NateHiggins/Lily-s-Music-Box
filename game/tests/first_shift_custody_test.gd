extends Node
## Focused order-independence contract for first-shift tour-key custody.
## Custody may happen before or after the report and Station 2 remains optional;
## the only hard rule is that a carried building key cannot leave at clock-out.

const JOB := "vantry_chirp_2a"
const WatchmanScript := preload("res://scripts/props/watchman_clock_prop.gd")

var fails := 0


func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["custody ok" if ok else "CUSTODY FAIL", label])
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

	RealityState.data.intro_complete = true
	_check(director.clock_in() and orders.issue_job(JOB, "reported"),
			"the test enters the real clocked-in and issued states")
	director.observe_tour_key_taken(3)
	_check(director.tour_key_carried() and director.accept_report(JOB),
			"custody may begin before the player takes the report")
	_check(not tracker._objective.text.contains("take the TOUR KEY")
			and tracker._objective.text.contains("STATION 2")
			and tracker._objective.text.contains("if you see it"),
			"the objective recognizes custody while keeping the station optional")

	director.observe_tour_key_returned()
	_check(not director.tour_key_carried()
			and tracker._objective.text.contains("take the TOUR KEY"),
			"returning an unused key restores the optional custody instruction")
	_check(director.station_marks().is_empty(),
			"returning the key manufactures no station evidence")

	_check(orders.diagnose_job(JOB)
			and orders.mark_job_awaiting_part(JOB)
			and orders.mark_job_repairable(JOB)
			and orders.record_job_repair(JOB, {
				"quality": "good", "note": "custody order proof"})
			and director.return_to_station()
			and director.file_outcome("disturbance_persists"),
			"the player may repair and file without optional station evidence")

	director.observe_tour_key_taken(3)
	_check(detector.control_prompt("detector").contains("Return the tour key")
			and not director.clock_out(),
			"taking the key after filing reopens custody and blocks clock-out")
	director.observe_tour_key_returned()
	_check(detector.control_prompt("detector").contains("Clock out")
			and detector.interact_control("detector", null)
			and director.ritual_phase() == FirstShiftDirector.PHASE_COMPLETE,
			"returning custody restores the physical clock-out")
	_check(director.station_marks().is_empty()
			and orders.job_stage(JOB) == "repaired",
			"completion invents neither a patrol mark nor a lifecycle transition")

	print("[FIRST SHIFT CUSTODY] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
