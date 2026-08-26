extends Node
## K2-A — the first minute in the real building, from a fresh campaign, through
## the seams a player's hands actually reach.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/FirstMinuteLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE AUDIT FINDING, ASSERTED RATHER THAN REMEMBERED. This suite re-measures
## in production the thing that justified the change: from the entrance hall
## the watchman's detector cannot be seen, and the first clear sight of it on
## the walk from the door to the desk arrives barely ahead of the player's own
## prompt ray. That measurement is a test, so it cannot quietly stop being true.
##
## And then the whole opening, proved not to have moved: one work order, one
## case transition, idempotent hands, an optional round that stays optional, a
## resume that explains without moving anyone, and refusals that commit nothing.

const JOB := "vantry_chirp_2a"
const CASE := "mina_caption_crisis"
## The detector's face, 0.30 m proud of the wall it is screwed to.
const DETECTOR_FACE := [4.94, -1.50, 1.44]
## A standing eye, just inside the front door.
const DOORWAY := [-0.46, -9.30, 1.62]

var failures := 0
var checks := 0
var root: Node
var player: PlayerController


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	player = root.get("player") as PlayerController

	var director: Node = root.get("first_shift_director")
	var orders: Node = root.get("work_orders")
	var tracker: Node = root.get("objective_tracker")
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	var plate: Node3D = root.find_child("ServiceSpineDirection", true,
			false) as Node3D

	# --- the ambiguity, still measurable ------------------------------------
	var space := player.get_world_3d().direct_space_state
	var face := GameBoot.b2g(DETECTOR_FACE)
	var eye := GameBoot.b2g(DOORWAY)
	var q := PhysicsRayQueryParameters3D.create(eye, face)
	q.exclude = [player.get_rid()]
	_check(not space.intersect_ray(q).is_empty(),
			"FROM JUST INSIDE THE FRONT DOOR THE DETECTOR CANNOT BE SEEN — "
					+ "the ambiguity this increment exists for")
	var first_sight := -1.0
	for i in range(41):
		var t := float(i) / 40.0
		var e := GameBoot.b2g([lerpf(-0.46, 4.30, t), lerpf(-9.60, -2.20, t),
				1.62])
		var r := PhysicsRayQueryParameters3D.create(e, face)
		r.exclude = [player.get_rid()]
		if space.intersect_ray(r).is_empty():
			first_sight = e.distance_to(face)
			break
	_check(first_sight > 0.0 and first_sight < 3.2,
			"and on the walk to the desk it only appears at %.2f m, against a "
					% first_sight + "2.10 m prompt ray")

	# --- the two cues that answer it ----------------------------------------
	_check(plate != null, "THE SPINE PLATE IS IN THE PRODUCTION LOBBY")
	if plate != null:
		var p := plate.global_position
		var pb := Vector3(p.x, -p.z, p.y)
		var s := PhysicsRayQueryParameters3D.create(eye, GameBoot.b2g(
				[pb.x, pb.y, pb.z]))
		s.exclude = [player.get_rid()]
		_check(space.intersect_ray(s).is_empty(),
				"and it IS visible from the doorway, %.2f m ahead"
						% eye.distance_to(plate.global_position))
		_check(pb.y < -6.5 and pb.x > 2.0 and pb.x < 3.6,
				"hung on the measured pier at b(%.2f, %.2f, %.2f)"
						% [pb.x, pb.y, pb.z])
	_check(detector != null and bool(detector.call("beating")),
			"THE CLOCK IS BEATING, because its movement is running")
	_check(detector != null and bool(detector.get("movement_running")),
			"and it is running because SR7-F left it running, not because the "
					+ "opening wanted a hint")

	# --- nothing is manufactured before a hand moves ------------------------
	_check(orders.call("job_stage", JOB) == "missing"
			and register.call("presented_job_id") == "",
			"before clock-in neither coordinator nor register invents a report")
	_check(str(RealityState.case_state(CASE).get("stage", "unseen")) == "unseen",
			"and no case has been touched")
	_check(bool(director.call("begin_first_shift")), "the arrival commits")

	# --- REFUSAL: the spindle is empty until the clock says otherwise -------
	var committed := var_to_bytes(RealityState.data)
	_check(str(register.call("control_prompt", "slip")).contains("empty"),
			"THE PREMATURE ACTION IS REFUSED IN THE BUILDING'S OWN WORDS: "
					+ "\"%s\"" % register.call("control_prompt", "slip"))
	_check(not bool(register.call("take_slip")),
			"and the paper cannot be taken")
	_check(var_to_bytes(RealityState.data) == committed,
			"A REFUSAL COMMITS NOTHING — the save is byte-for-byte unchanged")
	_check(orders.call("job_stage", JOB) == "missing",
			"and still no work order exists")

	# --- clock in, once, and again ------------------------------------------
	_check(bool(detector.call("interact_control", "detector", player)),
			"the player clocks in through the production detector")
	_check(director.call("ritual_phase") == "clocked_in", "the shift is open")
	_check(orders.call("job_stage", JOB) == "issued",
			"exactly one authored job is offered")
	var jobs_after_first: int = (orders.call("serialize_jobs") as Dictionary).size()
	_check(jobs_after_first == 1, "ONE work order on the spine (%d)"
			% jobs_after_first)
	var cases_after_offer := var_to_bytes(RealityState.data.cases)
	_check(str(RealityState.case_state(CASE).get("stage", "unseen")) == "unseen",
			"offering the paper still activates no case")
	# IDEMPOTENCE. A second punch is a punch on an open shift, not a second one.
	_check(not bool(director.call("clock_in")),
			"clocking in twice is refused by the one opening owner")
	detector.call("interact_control", "detector", player)
	detector.call("interact_control", "detector", player)
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"and three more presses make NO duplicate work order (%d)"
					% (orders.call("serialize_jobs") as Dictionary).size())
	_check(director.call("ritual_phase") == "clocked_in",
			"and do not move the phase")

	# --- take the paper, once, and again ------------------------------------
	_check(bool(register.call("slip_available")),
			"the physical slip is on the spindle now")
	_check(str(register.call("control_prompt", "slip")).contains("Take"),
			"and the prompt has changed to \"%s\""
					% register.call("control_prompt", "slip"))
	_check(bool(register.call("take_slip")), "the player takes it")
	_check(director.call("ritual_phase") == "report_accepted",
			"the paper begins the case")
	_check(str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"exactly one case activates, and it is the paper's own")
	_check(var_to_bytes(RealityState.data.cases) != cases_after_offer,
			"the case moved only when the paper did")
	var case_bytes := var_to_bytes(RealityState.data.cases)
	register.call("take_slip")
	register.call("take_slip")
	_check(var_to_bytes(RealityState.data.cases) == case_bytes,
			"TAKING IT AGAIN CAUSES NO SECOND CASE TRANSITION")
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"and no second work order (%d)"
					% (orders.call("serialize_jobs") as Dictionary).size())
	_check(not bool(director.call("accept_report", JOB)),
			"and the opening owner refuses to accept the same report twice")

	# --- the optional round stays optional ----------------------------------
	var objective := str(tracker._objective.text)
	_check(objective.contains("STATION 2") and objective.contains("if you see"),
			"the watch station is OFFERED, not demanded: \"%s\"" % objective)
	_check(not bool(director.call("has_station_mark",
			"F02_STATION_2A_LANDING")),
			"no mark has been made")
	_check(director.call("ritual_phase") == "report_accepted",
			"and the shift is already at its working phase WITHOUT one — the "
					+ "optional order is genuinely optional")
	_check(orders.call("job_stage", JOB) == "acknowledged",
			"the job is acknowledged with no station mark against it")

	# --- resume explains, and never moves anyone ----------------------------
	var saved := var_to_bytes(RealityState.data)
	var where := player.global_position
	tracker.call("clear")
	director.call("present_resume")
	_check(str(tracker._title.text) != "",
			"a resume reconstructs the heading: \"%s\"" % tracker._title.text)
	_check(str(tracker._objective.text) == objective,
			"and the SAME next intention it had before the save")
	_check(var_to_bytes(RealityState.data) == saved,
			"RESUME COMMITS NOTHING")
	_check(player.global_position.distance_to(where) < 0.001,
			"and moves nobody")
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"still one work order after the resume")

	# --- and the beat is still only the movement ----------------------------
	_check(bool(detector.call("beating")), "the clock is still beating")
	detector.set("movement_running", false)
	_check(not bool(detector.call("beating")),
			"STOP THE MOVEMENT AND THE LOBBY GOES SILENT — in production too")
	_check(director.call("ritual_phase") == "report_accepted"
			and (orders.call("serialize_jobs") as Dictionary).size() == 1,
			"and stopping the clock changes no owner's state at all")
	detector.set("movement_running", true)
	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [first minute live ok] ", label)
	else:
		failures += 1
		printerr("  [FIRST MINUTE LIVE FAIL] ", label)


func _finish() -> void:
	print("FIRST MINUTE LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
