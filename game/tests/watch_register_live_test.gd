extends Node
## SR7-K — the wire runs from F02 to the lobby, in the real building.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/WatchRegisterLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## Two ends on two floors and one network between them. What only production
## can settle:
##
##   * the board hangs in the lobby watchman's lane, in measured clear wall,
##     NEAR the detector and the night register and mechanically distinct
##     from both;
##   * working the real F02 box lights the real lobby board, once, agreeing on
##     number and sequence;
##   * cutting the real line leaves the real box truthful and the real lobby
##     ignorant;
##   * and none of the three owns a job, a case, a light, a node or a save.

var failures := 0
var checks := 0

## The lobby watchman's lane, in building coordinates, all measured.
const WALL_X := 5.24
const REGISTER_Y := -3.55
const DUMBWAITER_NORTH := -4.48
const NIGHT_REGISTER_SHELF_SOUTH := -2.63
const DETECTOR_Y := -1.50
const CASE_HALF := 0.20


func _ready() -> void:
	RealityState.persistence_enabled = false
	var root: Node = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var board: Node = root.find_child("F01_SIGNAL_REGISTER", true, false)
	var box: Node = root.find_child("F02_WATCH_STATION_01", true, false)
	var net: Node = root.find_child("WatchStationNetwork", true, false)
	_check(board != null and box != null and net != null,
			"production owns a station, a network and a signal register")
	if board == null or box == null or net == null:
		_finish()
		return

	# --- the lobby lane -----------------------------------------------------
	var at: Vector3 = (board as Node3D).global_position
	var by := -at.z
	print("[REGISTER LIVE] global b(%.2f, %.2f, %.2f)" % [at.x, by, at.y])
	_check(absf(at.x - WALL_X) < 0.02 and absf(by - REGISTER_Y) < 0.02,
			"it hangs on the lobby east wall at the authored station")
	_check(by - CASE_HALF > DUMBWAITER_NORTH
			and by + CASE_HALF < NIGHT_REGISTER_SHELF_SOUTH,
			"in the clear run between the dumbwaiter and the night register")
	_check(absf(by - CASE_HALF - DUMBWAITER_NORTH) > 0.5
			and absf(NIGHT_REGISTER_SHELF_SOUTH - (by + CASE_HALF)) > 0.5,
			"with over half a metre of plaster on each side of it")
	_check(at.y > 1.395 and at.y < 1.55,
			"at the same reading height as the rest of the lane (%.2f)" % at.y)
	_check((board as Node3D).global_transform.basis.z.normalized().x < -0.9,
			"and its face is turned into the lobby")

	# THREE INSTRUMENTS, NOT A CONSOLE. Near each other, and each answering
	# exactly one question with its own mechanism.
	var detector: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	var night: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	_check(detector != null and night != null,
			"the detector and the night register are both still here")
	_check(board != detector and board != night
			and not board.has_method("dial_turns")
			and not board.has_method("sign_register")
			and not board.has_method("take_slip"),
			"the receiver is a THIRD instrument, not a merge of the other two")
	_check(absf(-(detector as Node3D).global_position.z - by) < 2.5,
			"it stands within a couple of metres of the detector, in one lane")

	# --- the wire -----------------------------------------------------------
	_check(net.call("has_receiver") and net.call("receiver") == board,
			"the production network's receiver is this board")
	_check(bool(net.get("line_closed")) and board.get("line_closed") == true
			and str(board.call("line_reads")) == "LINE CLOSED",
			"and at boot the line rests CLOSED, as a watchman's line does")
	_check(int(net.call("mark_count")) == 0
			and int(net.call("delivered_count")) == 0
			and int(board.call("indication_count")) == 0,
			"nothing made, nothing carried, nothing shown")

	# --- what must not move -------------------------------------------------
	var wo: Node = root.get("work_orders")
	var save_before := JSON.stringify(RealityState.data)
	var jobs_before := JSON.stringify(
			RealityState.data.get("maintenance_jobs", {}))
	var cases_before := JSON.stringify(RealityState.data.get("cases", {}))
	var case_events: Array[String] = []
	RealityCases.case_changed.connect(
			func(id: String, _s: Dictionary) -> void:
				case_events.append(str(id)))
	var switch_system: Node = root.get("switch_system")
	var switches_before: int = int(switch_system.get("switches")) \
			if switch_system != null else -1
	var powered_before := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_before += 1
	var graph_before: int = AcousticGraphData.nodes.size()
	var schedule: Node = root.get_node_or_null("ScheduleDirector")
	var dispatched_before: int = int((schedule.get("_dispatched")
			as Dictionary).size()) if schedule != null else -1

	# --- ONE SIGNAL, END TO END, IN THE REAL BUILDING -----------------------
	var shown: Array[Dictionary] = []
	board.connect("signal_displayed",
			func(n: int, seq: int) -> void:
				shown.append({"number": n, "sequence": seq}))
	var found: Dictionary = board.call("maintenance_snapshot")
	box.call("interact_control", "station", null)   # opens the box
	_check(box.call("interact_control", "station", null),
			"the real F02 box is worked: door, crank, drop")
	_check(int(net.call("mark_count")) == 1
			and int(net.call("delivered_count")) == 1
			and int(net.call("undelivered_count")) == 0,
			"the real wire carried exactly that one signal")
	_check(shown.size() == 1 and int(board.call("indication_count")) == 1,
			"and the lobby board took exactly ONE indication")
	# THE AGREEMENT, ACROSS TWO FLOORS.
	var record: Dictionary = (net.call("marks") as Array)[0]
	_check(int(board.call("last_indication").station_number)
					== int(record.station_number)
			and board.call("shows", int(record.station_number)),
			"station and board agree on the number (%d)"
					% int(record.station_number))
	_check(int(board.call("last_indication").sequence)
					== int(record.sequence),
			"and on the sequence (%d)" % int(record.sequence))
	_check(int(board.get("signals_taken")) == 1,
			"the counter has stepped once and only once")

	# REPEAT: the box's pawl means there is no second signal to carry.
	box.call("interact_control", "station", null)
	box.call("interact_control", "station", null)
	_check(int(net.call("mark_count")) == 1
			and int(net.call("delivered_count")) == 1
			and int(board.get("signals_taken")) == 1,
			"a repeated crank makes no second mark and no second indication")

	# --- THE OPEN LINE, IN THE REAL BUILDING --------------------------------
	board.call("reset_shutters")
	box.call("reset_station")
	_check(not board.call("shows", 2) and box.get("drop_fallen") == false,
			"both ends are restored for the open-circuit round")
	_check(net.call("set_line_closed", false)
			and str(board.call("line_reads")) == "LINE OPEN",
			"the real line is cut, and the lobby pilot says so")
	var marks_before: int = int(net.call("mark_count"))
	box.call("interact_control", "station", null)
	box.call("interact_control", "station", null)
	_check(box.get("drop_fallen") == true,
			"THE BOX STILL MARKS: its drop is mechanical and fell anyway")
	_check(int(net.call("mark_count")) == marks_before + 1,
			"the fact was still made and still published")
	_check(int(net.call("delivered_count")) == 1
			and int(net.call("undelivered_count")) == 1,
			"but the wire carried nothing (delivered %d, undelivered %d)"
					% [int(net.call("delivered_count")),
							int(net.call("undelivered_count"))])
	_check(int(board.call("indication_count")) == 0
			and int(board.get("signals_taken")) == 1,
			"and the lobby board shows nothing: the shutter is still up")
	net.call("set_line_closed", true)
	_check(int(board.call("indication_count")) == 0,
			"closing the line again does not back-fill the missed signal")

	# --- nothing else moved -------------------------------------------------
	_check(JSON.stringify(RealityState.data.get("maintenance_jobs", {}))
					== jobs_before,
			"NO WORKORDER was created, advanced or closed")
	_check(JSON.stringify(RealityState.data.get("cases", {})) == cases_before
			and case_events.is_empty(),
			"no case moved and no case signal was published (%s)"
					% ", ".join(case_events))
	# WHOSE SAVE KEYS MOVED, named rather than assumed. This apparatus writes
	# nothing -- the focused proof reads its source and finds no `RealityState`
	# at all. Anything that moved here was a CONSUMER acting on the published
	# fact, and `first_shift` is the only consumer production has wired.
	var before_keys: Dictionary = JSON.parse_string(save_before)
	var moved: Array[String] = []
	for key in RealityState.data.keys():
		if JSON.stringify(RealityState.data[key]) 				!= JSON.stringify(before_keys.get(key)):
			moved.append(str(key))
	for key in before_keys.keys():
		if not RealityState.data.has(key) and str(key) not in moved:
			moved.append(str(key))
	_check(moved.is_empty() or moved == ["first_shift"],
			"the only save key that moved is the first-shift owner's (%s)"
					% ", ".join(moved))
	var powered_after := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_after += 1
	_check(powered_after == powered_before,
			"not one lamp changed power (%d)" % powered_before)
	_check(switch_system == null
			or int(switch_system.get("switches")) == switches_before,
			"the switch system is unchanged (%d plates)" % switches_before)
	_check(AcousticGraphData.nodes.size() == graph_before
			and not AcousticGraphData.nodes.has("F01_SIGNAL_REGISTER"),
			"the acoustic graph is unchanged (%d) and gains no node"
					% graph_before)
	_check(schedule == null or int((schedule.get("_dispatched")
			as Dictionary).size()) == dispatched_before,
			"the resident schedules are untouched")
	_check((board as Node3D).find_children("*", "Light3D", true,
			false).is_empty(),
			"the board owns no light of its own")
	var bodies: Array = (board as Node3D).find_children("*",
			"CollisionObject3D", true, false)
	_check(bodies.size() == 2 and bodies[0] is Area3D and bodies[1] is Area3D
			and not (bodies[0] is StaticBody3D),
			"and two Area reaches, which obstruct nothing in the lobby")
	var reach := 0.0
	for vis in (board as Node3D).find_children("*", "VisualInstance3D", true,
			false):
		var vi := vis as VisualInstance3D
		var ab := vi.global_transform * vi.get_aabb()
		reach = maxf(reach, WALL_X - ab.position.x)
	_check(reach < 0.22, "it projects only %.3f m into the lobby" % reach)

	# --- abort --------------------------------------------------------------
	board.call("restore_maintenance_snapshot", found)
	_check(board.get("line_closed") == true
			and int(board.call("indication_count")) == 0
			and int(board.get("signals_taken")) == 0
			and not board.call("balking"),
			"ABORT puts the real board back exactly as it was found")
	# THE LINE ABORT DOES NOT CROSS, on the real network.
	_check(int(net.call("mark_count")) == 2
			and int(net.call("delivered_count")) == 1,
			"and CANNOT RETRACT the facts the network was already handed")
	_check(wo != null and str(wo.call("job_stage", "vantry_chirp_2a"))
			== "missing",
			"the opening report is exactly where it was: unissued")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [register live ok] ", label)
	else:
		failures += 1
		printerr("  [REGISTER LIVE FAIL] ", label)


func _finish() -> void:
	print("WATCH REGISTER LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
