extends Node
## K2-C — one immediate verb, in the real building, from a fresh campaign.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/FirstStepLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## NOBODY IS TELEPORTED. The player is left exactly where `begin_first_shift`
## puts them and every interaction goes through the seams a hand reaches:
## `interact_control`, `take_slip`, `take_key`, `return_key`.
##
## The audit measurement is re-asserted first, so the justification cannot
## quietly stop being true — and then the thing that matters most for this
## increment is proved four ways: THE ORDER IS FREE.

const JOB := "vantry_chirp_2a"
const CASE := "mina_caption_crisis"
const STATION := "F02_STATION_2A_LANDING"
## The pose the paper comes off the spindle at.
const ACCEPTANCE_POSE := [4.84, -2.27, 1.62]

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
	var register: Node3D = root.find_child("F01_NIGHT_REGISTER", true,
			false) as Node3D
	var guard: Node = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	var station2: Node3D = root.find_child("F02_WATCH_STATION_01", true,
			false) as Node3D

	# --- the ambiguity, still measurable ------------------------------------
	var pose := GameBoot.b2g(ACCEPTANCE_POSE)
	var facing: Vector3 = register.global_position - pose
	facing.y = 0.0
	var space := player.get_world_3d().direct_space_state
	for row in [["the tour key", guard, 45.0], ["STATION 2", station2, 90.0]]:
		var n: Node3D = row[1] as Node3D
		var to: Vector3 = n.global_position - pose
		var flat := Vector3(to.x, 0.0, to.z)
		var yaw := absf(rad_to_deg(facing.normalized().signed_angle_to(
				flat.normalized(), Vector3.UP)))
		_check(yaw > float(row[2]),
				"FROM THE ACCEPTANCE POSE %s is %.1f deg off axis — outside a "
						% [row[0], yaw] + "70 deg frustum's +-35")
	var playing := 0
	for n in root.find_children("*", "AudioStreamPlayer3D", true, false):
		if (n as AudioStreamPlayer3D).playing:
			playing += 1
	_check(playing > 100,
			"and %d emitters are already playing, which is what \"find it by "
					% playing + "ear\" was competing with")

	# --- the card ------------------------------------------------------------
	_check(bool(director.call("begin_first_shift")), "the arrival commits")
	var where := player.global_position
	_check(bool(detector.call("interact_control", "detector", player)),
			"the player clocks in")
	_check(bool(register.call("take_slip")), "and takes the report")
	var card := str(tracker._objective.text)
	print("  [card] %s" % card)
	_check(card.begins_with("Unit 2A, one floor up."),
			"THE CARD LEADS WITH ONE THING A HAND CAN ACT ON: where")
	_check(card.contains("Follow the chirp"),
			"the job's own words survive, unedited, straight after it")
	_check(card.contains("TOUR KEY") and card.contains("STATION 2"),
			"and both optional things are still named")
	for imperative in ["Before you leave", "take the TOUR KEY", "work STATION"]:
		_check(not card.contains(imperative),
				"but neither is ordered any more: no \"%s\"" % imperative)

	# --- THE ORDER IS FREE ---------------------------------------------------
	_check(orders.call("job_stage", JOB) == "acknowledged"
			and str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"the job is working and the case is active RIGHT NOW")
	_check(not bool(director.call("tour_key_carried")),
			"with NO tour key carried — the chirp may lawfully be pursued first")
	_check(not bool(director.call("has_station_mark", STATION)),
			"and NO station mark — STATION 2 may lawfully be ignored")
	# Take the key second, and nothing objects or changes.
	var before_key := var_to_bytes(RealityState.data)
	_check(bool(guard.call("take_key")), "the key may also be taken, second")
	_check(bool(director.call("tour_key_carried")), "custody is recorded")
	_check(orders.call("job_stage", JOB) == "acknowledged"
			and str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"and NEITHER the job nor the case moved for it")
	_check(str(tracker._objective.text).begins_with("Unit 2A, one floor up."),
			"the first step is unchanged by carrying a key")
	_check(not str(tracker._objective.text).contains("TOUR KEY"),
			"and its clause retires, because it is in the pocket")
	# Give it back WITHOUT ever marking the station.
	_check(bool(guard.call("return_key")), "and it may be returned")
	_check(not bool(director.call("tour_key_carried")), "custody released")
	_check(not bool(director.call("has_station_mark", STATION)),
			"WITH NO STATION MARK EVER MADE — the round was never a gate")
	_check(orders.call("job_stage", JOB) == "acknowledged",
			"and the job is exactly where it was")
	_check(var_to_bytes(RealityState.data) == before_key,
			"custody is session state: taking and returning the key wrote "
					+ "NOTHING to the save")

	# --- the key opens no door ----------------------------------------------
	guard.call("take_key")
	var locked := 0
	var unlocked_by_key := 0
	for leaf in root.find_children("*_DOOR_*", "", true, false):
		if leaf.get("leaf_state") == null:
			continue
		if str(leaf.get("leaf_state")) == "locked":
			locked += 1
			if leaf.has_method("interact"):
				leaf.call("interact", player)
				if str(leaf.get("leaf_state")) != "locked":
					unlocked_by_key += 1
	_check(unlocked_by_key == 0,
			"THE TOUR KEY OPENS NO DOOR: %d locked leaves, %d opened by "
					% [locked, unlocked_by_key] + "carrying it")
	guard.call("return_key")

	# --- no duplicates, and idempotence -------------------------------------
	for i in 3:
		detector.call("interact_control", "detector", player)
		register.call("take_slip")
		guard.call("take_key")
		guard.call("return_key")
	_check((orders.call("serialize_jobs") as Dictionary).size() == 1,
			"after a dozen repeat presses: ONE work order (%d)"
					% (orders.call("serialize_jobs") as Dictionary).size())
	_check(str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"one case, still active")
	_check(not bool(director.call("has_station_mark", STATION)),
			"no station mark manufactured")
	_check(director.call("ritual_phase") == "report_accepted",
			"and the phase is where its owner put it")
	_check(str(tracker._objective.text).begins_with("Unit 2A, one floor up."),
			"the card is idempotent too")

	# --- the optional mark, when it IS made, is still not permission ---------
	var marked := bool(director.call("observe_central_signal", 2, 1))
	_check(marked, "working STATION 2 records a mark through its own owner")
	_check(orders.call("job_stage", JOB) == "acknowledged"
			and str(RealityState.case_state(CASE).get("stage", "")) == "active",
			"AND THE JOB AND CASE DO NOT MOVE FOR IT — evidence, never permission")

	# --- save/resume ---------------------------------------------------------
	var saved := var_to_bytes(RealityState.data)
	var card_now := str(tracker._objective.text)
	tracker.call("clear")
	director.call("present_resume")
	_check(str(tracker._objective.text) == card_now,
			"a resume reconstructs the SAME next practical intention")
	_check(var_to_bytes(RealityState.data) == saved, "RESUME COMMITS NOTHING")
	_check(player.global_position.distance_to(where) < 0.001,
			"and moves nobody")
	_check(not RealityState.data.has("first_step")
			and not RealityState.data.has("route_hint"),
			"K2-C wrote no save key of its own")
	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [first step live ok] ", label)
	else:
		failures += 1
		printerr("  [FIRST STEP LIVE FAIL] ", label)


func _finish() -> void:
	print("FIRST STEP LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
