extends Node
## SR7-G — the register hangs in the real lobby and owns nothing around it.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/NightRegisterLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## The focused test proves the board against a stand-in. This one proves the
## four claims that only the real building can settle:
##
##   * the spine it reads is the production `WorkOrders`, and taking a report
##     off the spindle acknowledges the job that already exists rather than
##     minting a second one;
##   * the doors its two keys are tagged for are the REAL doors, and their
##     lock states are production's — five service closets locked, 2B's entry
##     not — and touching the keys changes neither;
##   * `RealityCases` is not touched at all;
##   * everything else in the building and in the save comes out the far side
##     bit-for-bit what it was, apart from the one small record the register
##     is allowed to write.

var failures := 0
var checks := 0

## The station, in building coordinates. The register shares the watchman's
## wall and mounting line, immediately south of the detector.
const WALL_X := 5.24
const REGISTER_Y := -2.27
const DETECTOR_Y := -1.50
const CASE_HALF_WIDTH := 0.31
const DOOR_1D_NORTH_EDGE := -2.86


func _ready() -> void:
	RealityState.persistence_enabled = false
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var root: Node = scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var board: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	_check(board != null, "the production lobby owns a night register")
	if board == null:
		_finish()
		return
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)

	# --- the watchman station is two objects on one wall --------------------
	var at: Vector3 = (board as Node3D).global_position
	var by := -at.z
	print("[REGISTER LIVE] global b(%.2f, %.2f, %.2f)" % [at.x, by, at.y])
	_check(absf(at.x - WALL_X) < 0.02 and absf(by - REGISTER_Y) < 0.02,
			"it hangs on the lobby east wall at the authored station")
	_check(at.y > 1.395,
			"clear above the 1.355 bullnose bead, like the detector (b z %.2f)"
					% at.y)
	_check(by - CASE_HALF_WIDTH > DOOR_1D_NORTH_EDGE,
			"the whole case is inside the run, clear of the 1D door opening")
	_check(detector != null
			and by + CASE_HALF_WIDTH < DETECTOR_Y - 0.18,
			"and stands clear of the watchman's detector, not overlapping it")
	_check((board as Node3D).global_transform.basis.z.normalized().x < -0.9,
			"its face is turned into the lobby")

	# --- it reads the PRODUCTION spine --------------------------------------
	var wo: Node = root.get("work_orders")
	var job_id: String = str(board.get("JOB_ID"))
	_check(wo != null and board.call("job_stage") == wo.call("job_stage",
			job_id),
			"the board reads the production WorkOrders, not a copy of it")
	_check(wo.call("job_stage", job_id) == "missing"
			and not board.call("slip_available"),
			"at boot the job does not exist, so the spindle is empty")
	# THE CENTRAL NEGATIVE, ON THE REAL SPINE.
	var jobs_before: int = RealityState.data.get("maintenance_jobs", {}).size()
	board.call("take_slip")
	_check(wo.call("job_stage", job_id) == "missing"
			and RealityState.data.get("maintenance_jobs", {}).size()
					== jobs_before,
			"touching the empty spindle issues nothing into the real spine")

	# `ServiceRoundDirector.answer_incoming_call()` is the sole issuing owner
	# and this is the exact call it makes. The board is handed a real report
	# by its real owner rather than inventing one.
	var round_owner: Node = root.get("service_round")
	_check(round_owner != null
			and str(round_owner.get("JOB_ID")) == job_id,
			"the service round is the owner that issues this job")
	wo.call("issue_job", job_id, "reported")
	_check(board.call("slip_available")
			and str(board.call("slip_text")).contains("BORROWED BREATH"),
			"once issued, the real report is on the spindle and readable")

	# --- what must not move -------------------------------------------------
	var switch_system: Node = root.get("switch_system")
	var switches_before: int = int(switch_system.get("switches")) \
			if switch_system != null else -1
	var powered_before := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_before += 1
	var toggles: Array = []
	if switch_system != null:
		switch_system.room_toggled.connect(
				func(room_id: String, _on: bool) -> void: toggles.append(room_id))
	var vantry: Node = root.get("vantry_points")
	var vantry_before: int = int(vantry.call("cached_point_ids").size()) \
			if vantry != null else -1
	var graph_before: int = AcousticGraphData.nodes.size()
	var schedule: Node = root.get_node_or_null("ScheduleDirector")
	var dispatched_before: int = int((schedule.get("_dispatched")
			as Dictionary).size()) if schedule != null else -1
	var case_events: Array[String] = []
	RealityCases.case_changed.connect(
			func(id: String, _s: Dictionary) -> void:
				case_events.append("changed:" + id))
	RealityCases.case_resolved.connect(
			func(id: String, _s: Dictionary) -> void:
				case_events.append("resolved:" + id))
	var case_before := JSON.stringify(RealityState.data.get("cases", {}))
	var dream_before := JSON.stringify({
		"dream": RealityState.data.get("dream", {}),
		"dreams_had": RealityState.data.get("dreams_had", 0),
		"dream_seed": RealityState.data.get("dream_seed", ""),
	})

	# --- the real doors -----------------------------------------------------
	var plant := str(board.get("PLANT_HOOK"))
	var flat := str(board.get("APARTMENT_HOOK"))
	var door_before: Dictionary = {}
	for hook in [flat, plant]:
		for door_id in (board.call("tagged_doors", hook) as Array):
			var door: Node = root.find_child(str(door_id), true, false)
			_check(door != null, "the tagged door %s is a real production door"
					% str(door_id))
			if door != null:
				door_before[str(door_id)] = str(door.get("leaf_state"))
	# THE MEASURED DISTINCTION. Two keys, one column on the board, and two
	# completely different kinds of permission underneath.
	_check(board.call("locked_count", plant) == 5
			and board.call("tagged_door_count", plant) == 5,
			"the plant key's five service closets are all really locked")
	_check(board.call("locked_count", flat) == 0
			and board.call("tagged_door_count", flat) == 1,
			"and 2B's entry, which the other key is for, is not locked at all")

	# --- route order, on the real board -------------------------------------
	var found: Dictionary = board.call("maintenance_snapshot")
	_check(board.call("take_key", plant)
			and board.call("take_slip")
			and board.call("take_key", flat),
			"plant key first, then the report, then the apartment key")
	_check(board.get("slip_taken") == true
			and board.call("keys_out_count") == 2,
			"the board carries the report and both keys at once")
	_check(str(board.call("hook_reads", plant)) == "check 7"
			and str(board.call("hook_reads", flat)) == "check 14",
			"and both hooks read their numbered checks, never simply empty")

	# --- the keys changed no lock -------------------------------------------
	var drifted: Array[String] = []
	for door_id in door_before.keys():
		var door: Node = root.find_child(str(door_id), true, false)
		if door != null and str(door.get("leaf_state")) != door_before[door_id]:
			drifted.append(str(door_id))
	_check(drifted.is_empty() and door_before.size() == 6,
			"with both keys off the board, not one real lock has moved (%s)"
					% ", ".join(drifted))

	# --- abort --------------------------------------------------------------
	board.call("take_key", plant)   # refused; leaves a pose standing
	_check(board.call("balking") == true,
			"a refusal is live on the real board when the abort is taken")
	board.call("restore_maintenance_snapshot", found)
	var after: Dictionary = board.call("maintenance_snapshot")
	var lost: Array[String] = []
	for key in found.keys():
		if str(after.get(key)) != str(found.get(key)):
			lost.append(str(key))
	_check(lost.is_empty() and board.call("keys_out_count") == 0
			and board.get("slip_taken") == false,
			"ABORT puts both keys back on their hooks and the report back (%s)"
					% ", ".join(lost))
	_check(board.call("balking") == false and not RealityState.data.has(
			str(board.get("STATE_KEY"))),
			"and the aborted session wrote nothing at all")

	# --- the one publication ------------------------------------------------
	board.call("take_slip")
	_check(wo.call("job_stage", job_id) == "acknowledged",
			"taking the report acknowledges the job that already existed")
	_check(RealityState.data.get("maintenance_jobs", {}).size()
					== jobs_before + 1,
			"exactly one job record exists, the one the spine issued")
	board.call("take_key", plant)
	var signed: Array[Dictionary] = []
	board.connect("register_signed",
			func(r: Dictionary) -> void: signed.append(r))
	_check(board.call("sign_register") and signed.size() == 1,
			"signing the book writes one line and reports once")
	_check((RealityState.data.get(str(board.get("STATE_KEY")), {})
			.get("lines", []) as Array).size() == 1,
			"and that line is the register's whole footprint in the save")

	# --- nothing else moved -------------------------------------------------
	var powered_after := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_after += 1
	_check(powered_after == powered_before,
			"not one lamp changed power (%d before, %d after)"
					% [powered_before, powered_after])
	_check(toggles.is_empty() and (switch_system == null
			or int(switch_system.get("switches")) == switches_before),
			"the switch system published nothing and still holds %d plates"
					% switches_before)
	_check(vantry == null
			or int(vantry.call("cached_point_ids").size()) == vantry_before,
			"the vantry station table is untouched (%d points)" % vantry_before)
	_check(AcousticGraphData.nodes.size() == graph_before
			and not AcousticGraphData.nodes.has("F01_NIGHT_REGISTER"),
			"the acoustic graph is unchanged (%d nodes) and gains none"
					% graph_before)
	_check(schedule == null or int((schedule.get("_dispatched")
			as Dictionary).size()) == dispatched_before,
			"the resident schedules are untouched (%d dispatched)"
					% dispatched_before)
	# NO DUPLICATE CASE STATE. The register never activates, advances or reads
	# a case for permission; `RealityCases` is `ServiceRoundDirector`'s and
	# `mina_case_gameplay`'s business, not the board's.
	_check(case_events.is_empty(),
			"no case signal was published by anything on this board (%s)"
					% ", ".join(case_events))
	_check(JSON.stringify(RealityState.data.get("cases", {})) == case_before,
			"and the whole case table is byte-for-byte what it was")
	_check(JSON.stringify({
			"dream": RealityState.data.get("dream", {}),
			"dreams_had": RealityState.data.get("dreams_had", 0),
			"dream_seed": RealityState.data.get("dream_seed", ""),
		}) == dream_before,
			"the Dream block is byte-for-byte what it was")

	_check((board as Node3D).find_children("*", "Light3D", true,
			false).is_empty(),
			"the apparatus owns no light of its own")
	_check((board as Node3D).find_children("*", "CollisionObject3D", true,
			false).size() == 4,
			"and four collision bodies, one per literal service point")
	var clocks := 0
	for child in root.get_children():
		if child is ClockProp:
			clocks += 1
	_check(clocks == 2, "the building still has exactly two clocks")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [register live ok] ", label)
	else:
		failures += 1
		printerr("  [REGISTER LIVE FAIL] ", label)


func _finish() -> void:
	print("NIGHT REGISTER LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
