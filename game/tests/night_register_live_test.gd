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

## SR7-I. The two authored reports, and the two owners that issue them.
const JOB_2A := "vantry_chirp_2a"
const JOB_2B := "lena_radiator_round_2b"


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
	var job_id := JOB_2A
	_check(wo != null
			and (board.get("PRESENTABLE_JOBS") as Array) == [JOB_2A, JOB_2B],
			"the board's authored order is the opening report, then Lena's")
	# AT BOOT NEITHER IS ISSUED, so the board presents nothing at all -- the
	# empty spindle is the honest state of a building with no open work.
	_check(str(board.call("presented_job_id")) == ""
			and str(board.call("first_open_job")) == ""
			and not board.call("slip_available")
			and str(board.call("slip_number")) == "",
			"at boot neither report exists, so the spindle is empty")
	_check(wo.call("job_stage", JOB_2A) == "missing"
			and wo.call("job_stage", JOB_2B) == "missing",
			"and the production spine agrees: both reports are missing")
	# THE CENTRAL NEGATIVE, ON THE REAL SPINE.
	var jobs_before: int = RealityState.data.get("maintenance_jobs", {}).size()
	board.call("take_slip")
	_check(wo.call("job_stage", JOB_2A) == "missing"
			and RealityState.data.get("maintenance_jobs", {}).size()
					== jobs_before,
			"touching the empty spindle issues nothing into the real spine")

	# THE TWO ISSUING OWNERS, both present in production and neither of them
	# this board. `CoreLoopDirector.offer_opening_report()` issues 001 and
	# `ServiceRoundDirector.answer_incoming_call()` issues 002; the register
	# is handed a real report and never manufactures one.
	var round_owner: Node = root.get("service_round")
	var loop_owner: Node = root.find_child("CoreLoopDirector", true, false)
	_check(round_owner != null and str(round_owner.get("JOB_ID")) == JOB_2B,
			"the service round is the owner that issues Lena's 002")
	_check(loop_owner != null
			and loop_owner.has_method("offer_opening_report")
			and str(loop_owner.get("JOB_ID")) == JOB_2A,
			"the core loop owns the opening report 001 and its offer seam")

	# WHO MOVES MINA'S CASE. Armed before the spine is touched and before the
	# board is touched at all, so the next two checks can say plainly that the
	# register is not the answer.
	var early_cases: Array[String] = []
	RealityCases.case_changed.connect(
			func(id: String, _s: Dictionary) -> void:
				early_cases.append(str(id)))

	# Issued through the spine's own public call, exactly as its owner makes
	# it. This test does not call the owner's seam; that is Codex's to wire.
	wo.call("issue_job", JOB_2A, "reported")
	# THE ATTRIBUTION, MEASURED IN TWO STEPS. Issuing 001 moves no case by
	# itself; the case moves when the job's STAGE moves. Step one, here:
	_check(early_cases.is_empty(),
			"issuing 001 moves no case on its own (%s)"
					% ", ".join(early_cases))
	_check(str(board.call("presented_job_id")) == JOB_2A
			and board.call("slip_available")
			and str(board.call("slip_text")).contains("THE CHIRP"),
			"once 001 is issued it is the paper on the real spindle")
	_check(str(board.call("slip_number")) == "WORK ORDER 001"
			and str(board.call("slip_unit")) == "UNIT 2A"
			and str(board.call("slip_symptom")).contains("line-test tone"),
			"and the paper identifies itself: number, unit and symptom")

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
	# STEP TWO, AND THE WHOLE ATTRIBUTION. Mina's case moves now -- on the
	# ACKNOWLEDGEMENT, because `CoreLoopDirector` owns 001's case boundary and
	# watches its stages. The register's only means of moving a stage is
	# `acknowledge_job`, the same public call the job's own owner makes, and
	# the register holds no `RealityCases` reference at all (asserted from its
	# source in the focused proof).
	#
	# SR7-H's live proof asserted "no case signal was published"; that held
	# only because 002's case has no owner watching its stages. The honest
	# invariant is not that the world stays still -- production's owners must
	# be allowed to work -- but that THIS BOARD is never the one that moved a
	# case, and that nothing moved which the presented report did not declare.
	_check(early_cases.is_empty(),
			"and STILL no case has moved after the board acknowledged it (%s)"
					% ", ".join(early_cases))
	_check(RealityState.data.get("maintenance_jobs", {}).size()
					== jobs_before + 1,
			"exactly one job record exists, the one the spine issued")

	# --- SR7-H: THE WORDS, ON THE PRODUCTION BOARD --------------------------
	var outcomes: Array = board.get("OUTCOMES")
	_check(outcomes == FirstShiftDirector.FILING_OUTCOMES,
			"the board's four conclusions ARE the first-shift director's, "
			+ "verbatim -- one vocabulary, no translation table")
	_check(board.get("index_detent") == 0
			and str(board.call("selected_outcome")) == "",
			"the production index is standing on the blank, as found")

	# NOT DERIVED. Take the real job all the way to `repaired` through its own
	# owner and the index must not have moved.
	wo.call("diagnose_job", job_id)
	# 001 declares a required part, so its road to `repairable` runs through
	# `awaiting_part`. The data decides which road, not this test.
	if (wo.get("job_library") as RefCounted).call("requires_part", job_id):
		wo.call("mark_job_awaiting_part", job_id)
	wo.call("mark_job_repairable", job_id)
	wo.call("record_job_repair", job_id,
			{"quality": "good", "note": "vent freed and clocked"})
	_check(str(wo.call("job_stage", job_id)) == "repaired",
			"the production spine reached `repaired` under its own power")
	# THE ATTRIBUTION LANDS HERE. Mina's case moves when the SPINE reaches
	# `repaired` -- `CoreLoopDirector` owns 001's case boundary and watches
	# its stages -- and this test drove those stages itself, through
	# `WorkOrders`, with the board untouched. No board action moved a case.
	#
	# SR7-H's live proof asserted "no case signal was published at all"; that
	# held only because 002's case has no owner watching its stages. The
	# honest invariant is not that the world stays still -- production's
	# owners must be allowed to work -- but that this BOARD is never what
	# moved a case, and nothing moves that a presented report did not declare.
	_check(not early_cases.is_empty()
			and str(early_cases[0]) == "mina_caption_crisis",
			"the case moved only when the SPINE reached repaired (%s)"
					% ", ".join(early_cases))
	_check(board.get("index_detent") == 0
			and str(board.call("selected_outcome")) == "",
			"AND THE INDEX HAS NOT MOVED. No job stage picks a conclusion.")

	# THE THREE REFUSALS, on the real apparatus.
	board.call("take_key", plant)
	board.call("select_outcome", str(outcomes[0]))
	_check(not board.call("sign_register")
			and board.call("balking") == true,
			"REFUSAL: it will not sign while a key is still off the board")
	board.call("return_key", plant)
	_check(board.get("slip_taken") == true
			and not board.call("sign_register"),
			"REFUSAL: it will not sign while the report is in your hand")
	board.call("replace_slip")
	board.call("select_outcome", "")
	_check(not board.call("outcome_selected")
			and not board.call("sign_register"),
			"REFUSAL: it will not sign with the index on the blank")
	_check(not RealityState.data.has(str(board.get("STATE_KEY"))),
			"and three refusals later the save is still untouched")

	# THE CLAIM THE APPARATUS DOES NOT CHECK. The job is `repaired`; the
	# register files "disturbance persists" without argument, because it
	# records what the player will put their name to and verifies nothing.
	board.call("select_outcome", "disturbance_persists")
	var signed: Array[Dictionary] = []
	board.connect("register_signed",
			func(r: Dictionary) -> void: signed.append(r))
	_check(board.call("ready_to_file") and board.call("sign_register")
			and signed.size() == 1,
			"signing the book writes one line and reports EXACTLY once")
	_check(str(signed[0].filing) == "disturbance_persists"
			and str(signed[0].job_stage) == "repaired",
			"a REPAIRED job is filed as 'disturbance persists', unchallenged")
	_check(str(wo.call("job_stage", job_id)) == "repaired",
			"and the spine is neither corrected nor advanced by the claim")
	_check(not board.call("sign_register")
			and board.get("signed_lines") == 1,
			"REFUSAL: signing again is idempotent -- no second line")
	_check((RealityState.data.get(str(board.get("STATE_KEY")), {})
			.get("lines", []) as Array).size() == 1,
			"and that one line is the register's whole footprint in the save")

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
	# NO DUPLICATE CASE STATE, and no case this board had any business in.
	# The register never activates, advances or reads a case for permission --
	# the focused test proves it holds no `RealityCases` reference at all --
	# so every case that moved here belongs to a report the board presented
	# and was moved by that case's own owner.
	var declared: Array[String] = []
	for job in (board.get("PRESENTABLE_JOBS") as Array):
		var spec: Dictionary = (wo.get("job_library") as RefCounted).call(
				"job", str(job))
		declared.append(str(spec.get("case_id", "")))
	var strays: Array[String] = []
	for event in case_events:
		var moved := str(event).split(":")[1]
		if moved not in declared and moved not in strays:
			strays.append(moved)
	_check(strays.is_empty(),
			"every case that moved is a presented report's own declared case "
					+ "(strays: %s)" % ", ".join(strays))
	var cases_now: Dictionary = RealityState.data.get("cases", {})
	var touched: Array[String] = []
	for case_id in cases_now.keys():
		if JSON.stringify(cases_now[case_id]) \
				!= JSON.stringify(JSON.parse_string(case_before).get(
						case_id, {})):
			touched.append(str(case_id))
	_check(touched.size() <= 1 and (touched.is_empty()
			or str(touched[0]) in declared),
			"and at most the one declared case differs in the table (%s)"
					% ", ".join(touched))
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
			false).size() == 5,
			"and five collision bodies, one per literal service point")
	# SR7-I ON THE REAL SPINE: 002 issued mid-round cannot take the paper out
	# of the player's hands, and picks up only once the board is idle again.
	_check(str(wo.call("job_stage", job_id)) != "closed",
			"NO WORKORDER WAS CLOSED OR SKIPPED by filing a conclusion")
	_check(str(board.call("presented_job_id")) == JOB_2A
			and not board.call("engaged"),
			"the signed round left the board idle, still showing 001")
	wo.call("issue_job", JOB_2B, "reported")
	_check(str(board.call("presented_job_id")) == JOB_2A,
			"002 issued does not displace 001, which is still open")
	wo.call("close_job", JOB_2A)
	_check(str(wo.call("job_stage", JOB_2A)) == "closed"
			and str(board.call("presented_job_id")) == JOB_2B
			and str(board.call("slip_number")) == "WORK ORDER 002"
			and str(board.call("slip_unit")) == "UNIT 2B",
			"and once 001 closes, the real board presents 002 instead")
	_check(str((RealityState.data.get(str(board.get("STATE_KEY")), {})
			.get("lines", []) as Array)[0].job_id) == JOB_2A,
			"while the line already signed still reads 001, its own job")
	_check(RealityState.data.get("maintenance_jobs", {}).size()
					== jobs_before + 2,
			"and exactly the two records the spine itself issued exist")
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
