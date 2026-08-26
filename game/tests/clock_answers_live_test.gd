extends Node
## K2-B — the clock answering, in the real building, from a fresh campaign.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/ClockAnswersLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## NOBODY IS TELEPORTED HERE. The player is left exactly where
## `begin_first_shift` puts them, on the kerb, and every interaction below goes
## through `interact_control` / `take_slip` — the same calls the player's own
## 2.10 m ray makes when a hand presses E. No owner state is written directly.
##
## The audit measurement is re-asserted first, so the justification for this
## increment cannot quietly stop being true.

const JOB := "vantry_chirp_2a"
const CASE := "mina_caption_crisis"
## The nearest standing place whose own prompt ray still lands on DetectorReach.
const INTERACTION_POSE := [4.84, -1.50, 1.62]

var failures := 0
var checks := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	var player: PlayerController = root.get("player") as PlayerController
	var director: Node = root.get("first_shift_director")
	var orders: Node = root.get("work_orders")
	var tracker: Node = root.get("objective_tracker")
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	var key: Node3D = detector.get_node("StationKey") as Node3D
	var head: Node3D = detector.get_node("PunchHead") as Node3D
	var mark: Node3D = detector.get_node("PaperPivot/ShiftPunch") as Node3D
	var slip: Node3D = register.get_node("ReportSlip") as Node3D
	var spike: Node3D = register.get_node("ReportSpindle") as Node3D

	# --- the ambiguity, still measurable ------------------------------------
	var eye := GameBoot.b2g(INTERACTION_POSE)
	var to: Vector3 = slip.global_position - eye
	var fwd := (detector as Node3D).global_position - eye
	fwd.y = 0.0
	var flat := Vector3(to.x, 0.0, to.z)
	var yaw := rad_to_deg(fwd.angle_to(flat))
	_check(yaw > 45.0,
			"FROM THE POSE A HAND CLOCKS IN AT, the report stands %.1f deg off "
					% yaw + "axis — outside a 70 deg frustum's +-35")
	_check(to.length() < 1.0, "and only %.2f m away, which is the whole "
			% to.length() + "problem: near, invisible, and where the change is")

	# --- as found ------------------------------------------------------------
	var key_rest := key.rotation.z
	var head_rest := head.position.z
	var slip_rest := slip.position.y
	var spike_rest := spike.rotation.z
	_check(not bool(detector.call("key_turning")), "AS FOUND nothing is turning")
	_check(not bool(detector.call("shift_punched")) and not mark.visible,
			"and the sheet carries no shift punch")
	_check(orders.call("job_stage", JOB) == "missing",
			"and no work order exists")
	_check(str(RealityState.case_state(CASE).get("stage", "unseen")) == "unseen",
			"and no case has been touched")
	_check(bool(director.call("begin_first_shift")), "the arrival commits")
	var where := player.global_position

	# --- REFUSAL: nothing to take yet ---------------------------------------
	var committed := var_to_bytes(RealityState.data)
	_check(not bool(register.call("take_slip")),
			"the paper cannot be taken before the clock says so")
	_check(var_to_bytes(RealityState.data) == committed,
			"and that refusal commits nothing")
	_check(not bool(detector.call("key_turning")),
			"nor does it turn the key at the clock")

	# --- the press -----------------------------------------------------------
	_check(bool(detector.call("interact_control", "detector", player)),
			"the player clocks in through the production detector")
	_check(bool(detector.call("key_turning")),
			"AND THE CLOCK ANSWERS WHERE THE HAND IS: the key is turning")
	detector.call("_process", 0.27)
	_check(absf(key.rotation.z - key_rest) > 1.0,
			"%.2f rad of key at the peak of the throw"
					% absf(key.rotation.z - key_rest))
	_check(absf(head.position.z - head_rest) > 0.02,
			"and the plunger %.0f mm down on the sheet"
					% (absf(head.position.z - head_rest) * 1000.0))
	_check(bool(detector.call("shift_punched")) and mark.visible,
			"THE PUNCH IS ON THE SHEET")
	_check(not bool(detector.get("dial_seated")),
			"and the dial is still off its pin, so that mark is in the wrong "
					+ "place for the hour — SR7-F's fault, written by the "
					+ "player's own hand")

	# --- and the paper ARRIVES, a foot to the right -------------------------
	_check(bool(register.call("slip_landing")),
			"THE REPORT IS LANDING, not appearing")
	register.call("_process", 0.30)
	_check(absf(slip.position.y - slip_rest) > 0.01,
			"the sheet is %.0f mm up the spike mid-fall"
					% (absf(slip.position.y - slip_rest) * 1000.0))
	_check(absf(spike.rotation.z - spike_rest) > 0.05,
			"and the spindle has nodded %.2f rad under it"
					% absf(spike.rotation.z - spike_rest))
	register.call("_process", 1.0)
	detector.call("_process", 1.0)
	_check(not bool(register.call("slip_landing"))
			and not bool(detector.call("key_turning")),
			"both answers finish")
	_check(absf(slip.position.y - slip_rest) < 0.001
			and absf(spike.rotation.z - spike_rest) < 0.001
			and absf(key.rotation.z - key_rest) < 0.001
			and absf(head.position.z - head_rest) < 0.001,
			"and every part settles exactly where it belongs")
	_check(bool(register.call("slip_available")) and slip.visible,
			"the report is on the spindle and discoverable")

	# --- exactly one of everything ------------------------------------------
	_check(orders.call("job_stage", JOB) == "issued", "one authored job issued")
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"ONE work order on the spine")
	_check(str(RealityState.case_state(CASE).get("stage", "unseen")) == "unseen",
			"and still no case: the paper has not been lifted")
	# IDEMPOTENCE at the clock.
	for i in 4:
		detector.call("interact_control", "detector", player)
	_check(not bool(detector.call("key_turning")),
			"FOUR MORE PRESSES DO NOT REPLAY THE ANSWER")
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"and make no duplicate work order (%d)"
					% (orders.call("serialize_jobs") as Dictionary).size())
	_check(director.call("ritual_phase") == "clocked_in", "nor move the phase")

	# --- the paper in hand ---------------------------------------------------
	_check(bool(register.call("take_slip")), "the player takes the report")
	_check(str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"exactly one case activates, and it is the paper's own")
	var case_bytes := var_to_bytes(RealityState.data.cases)
	register.call("take_slip")
	register.call("take_slip")
	_check(var_to_bytes(RealityState.data.cases) == case_bytes,
			"TAKING IT AGAIN CAUSES NO SECOND CASE TRANSITION")
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"and no second work order")
	_check(bool(detector.call("shift_punched")) and mark.visible,
			"and the punch is still on the sheet, because the shift is still open")

	# --- the optional round stays optional ----------------------------------
	var objective := str(tracker._objective.text)
	# K2-C reworded this clause from "work STATION 2 if you see it" into the
	# indicative. The assertion now tests the PROPERTY the check was always
	# about — the station is named and never ordered — rather than the exact
	# sentence, so a future rewording cannot break it for the wrong reason.
	_check(objective.contains("STATION 2")
			and not objective.contains("work STATION")
			and not objective.contains("Before you leave"),
			"the watch station is OFFERED, not demanded")
	_check(not bool(director.call("has_station_mark",
			"F02_STATION_2A_LANDING")),
			"no mark has been made, and the shift is already working")
	_check(orders.call("job_stage", JOB) == "acknowledged",
			"the job is acknowledged with no station mark against it")

	# --- save/resume ---------------------------------------------------------
	var saved := var_to_bytes(RealityState.data)
	tracker.call("clear")
	director.call("present_resume")
	_check(str(tracker._objective.text) == objective,
			"a resume reconstructs the SAME next practical intention")
	_check(var_to_bytes(RealityState.data) == saved, "RESUME COMMITS NOTHING")
	_check(player.global_position.distance_to(where) < 0.001,
			"and moves nobody")
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"still one work order after the resume")
	_check(bool(detector.call("shift_punched")),
			"and the punch comes back for free, because it was never stored — "
					+ "the phase came back with the save and the sheet is drawn "
					+ "from it")
	_check(not RealityState.data.has("shift_punch")
			and not RealityState.data.has("slip_landing")
			and not RealityState.data.has("key_turn"),
			"K2-B wrote no save key of its own")
	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [clock live ok] ", label)
	else:
		failures += 1
		printerr("  [CLOCK LIVE FAIL] ", label)


func _finish() -> void:
	print("CLOCK ANSWERS LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
