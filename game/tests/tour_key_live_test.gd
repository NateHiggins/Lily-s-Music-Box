extends Node
## SR7-L — the key hangs in the real lane and the real box asks for it.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/TourKeyLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## What only production can settle:
##
##   * the guard hangs in measured clear wall between the signal register and
##     the night register, on its own board, with its own check number;
##   * the real F02 box refuses with the real key on its hook, and works with
##     it carried — one drop, one delivery, one indication;
##   * the key opens no real door in the building;
##   * and the whole round leaves jobs, cases, doors and the save alone.

var failures := 0
var checks := 0

## The lane, in building coordinates, measured.
const WALL_X := 5.24
const GUARD_Y := -2.99
const SIGNAL_REGISTER_NORTH := -3.35
const NIGHT_REGISTER_SHELF_SOUTH := -2.63
const GUARD_HALF := 0.08


func _ready() -> void:
	RealityState.persistence_enabled = false
	var root: Node = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var guard: Node = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	var box: Node = root.find_child("F02_WATCH_STATION_01", true, false)
	var net: Node = root.find_child("WatchStationNetwork", true, false)
	var board: Node = root.find_child("F01_SIGNAL_REGISTER", true, false)
	_check(guard != null and box != null and net != null and board != null,
			"production owns a guard, a station, a network and a register")
	if guard == null or box == null or net == null or board == null:
		_finish()
		return

	# --- the lane -----------------------------------------------------------
	var at: Vector3 = (guard as Node3D).global_position
	var by := -at.z
	print("[TOUR KEY LIVE] global b(%.2f, %.2f, %.2f)" % [at.x, by, at.y])
	_check(absf(at.x - WALL_X) < 0.02 and absf(by - GUARD_Y) < 0.02,
			"the guard hangs on the lobby east wall at the authored station")
	_check(by - GUARD_HALF > SIGNAL_REGISTER_NORTH
			and by + GUARD_HALF < NIGHT_REGISTER_SHELF_SOUTH,
			"in the clear run between the signal register and the register")
	_check(absf(by - GUARD_HALF - SIGNAL_REGISTER_NORTH) > 0.2
			and absf(NIGHT_REGISTER_SHELF_SOUTH - (by + GUARD_HALF)) > 0.2,
			"with clear plaster on each side of it")
	_check(at.y > 1.395 and at.y < 1.55,
			"at the lane's reading height (%.2f)" % at.y)
	_check((guard as Node3D).global_transform.basis.z.normalized().x < -0.9,
			"and its face is turned into the lobby")

	# MECHANICALLY SEPARATE FROM THE NIGHT REGISTER. A different node, a
	# different board, a different check.
	var night: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	_check(night != null and guard != night
			and not (guard as Node3D).is_ancestor_of(night)
			and not (night as Node3D).is_ancestor_of(guard),
			"the guard is its own apparatus, not a hook on the night register")
	var night_checks: Dictionary = night.get("CHECK_NUMBERS")
	var guard_check: int = int(guard.get("CHECK_NUMBER"))
	_check(guard_check not in night_checks.values(),
			"and its check number %d is not one of the register's %s"
					% [guard_check, str(night_checks.values())])

	# --- the wire knows where to ask ----------------------------------------
	_check(net.call("has_key_guard") and net.call("key_guard") == guard,
			"the production network's key guard is this one")
	_check(not net.call("tour_key_carried")
			and guard.get("key_on_hook") == true,
			"and at boot the key is on its hook")
	_check(not box.call("tour_key_available"),
			"so the real box reports no key at its socket")

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
	var doors_before: Dictionary = {}
	for leaf in root.find_children("*_DOOR_*", "", true, false):
		if leaf.get("leaf_state") != null:
			doors_before[str(leaf.name)] = str(leaf.get("leaf_state"))
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

	# --- THE REAL BOX REFUSES WITH THE REAL KEY ON ITS HOOK -----------------
	var found_guard: Dictionary = guard.call("maintenance_snapshot")
	box.call("interact_control", "station", null)   # opens the door
	_check(box.get("door_open") == true, "the real box opens")
	_check(not box.call("interact_control", "station", null)
			and box.call("balking")
			and int(box.get("marks")) == 0
			and box.get("drop_fallen") == false,
			"REFUSAL: the real crank will not run with an empty socket")
	_check(int(net.call("mark_count")) == 0
			and int(board.call("indication_count")) == 0,
			"nothing was made, carried or shown")

	# --- TAKE THE REAL KEY --------------------------------------------------
	var taken: Array[int] = []
	guard.connect("tour_key_taken", func(n: int) -> void: taken.append(n))
	_check(guard.call("interact_control", "tour_key", null)
			and guard.get("key_on_hook") == false
			and taken == [guard_check],
			"the key comes off its hook and the check goes on")
	_check(str(guard.call("hook_reads")) == "check %d" % guard_check
			and net.call("tour_key_carried")
			and box.call("tour_key_available"),
			"and two floors up the box now knows the key is out")

	# --- ONE MARK, END TO END ------------------------------------------------
	box.call("restore_maintenance_snapshot", box.call("maintenance_snapshot"))
	box.call("interact_control", "station", null)   # opens
	_check(box.call("interact_control", "station", null)
			and box.get("drop_fallen") == true
			and int(box.get("marks")) == 1,
			"with the key carried, the real box marks")
	_check(int(net.call("mark_count")) == 1
			and int(net.call("delivered_count")) == 1
			and int(board.call("indication_count")) == 1
			and board.call("shows", int(box.call("station_number"))),
			"exactly one local drop and one central indication")
	# REPEAT CRANK with the key still carried: the pawl, not the socket.
	box.call("interact_control", "station", null)
	box.call("interact_control", "station", null)
	_check(int(box.get("marks")) == 1 and int(net.call("mark_count")) == 1
			and int(board.get("signals_taken")) == 1,
			"a repeated crank makes no second anything")

	# --- IT OPENED NO DOOR ---------------------------------------------------
	var moved_doors: Array[String] = []
	for leaf_name in doors_before.keys():
		var leaf: Node = root.find_child(str(leaf_name), true, false)
		if leaf != null and str(leaf.get("leaf_state")) \
				!= doors_before[leaf_name]:
			moved_doors.append(str(leaf_name))
	_check(moved_doors.is_empty() and doors_before.size() > 20,
			"with the key carried and used, not one of %d real doors moved (%s)"
					% [doors_before.size(), ", ".join(moved_doors)])
	var closet: Node = root.find_child("F02_DOOR_04", true, false)
	var entry: Node = root.find_child("F02_DOOR_03", true, false)
	_check(closet != null and str(closet.get("leaf_state")) == "locked",
			"the service closet is still locked, tour key or no tour key")
	_check(entry != null and str(entry.get("leaf_state")) != "locked",
			"and 2B's entry is exactly as it was")

	# --- RETURN IT -----------------------------------------------------------
	_check(guard.call("interact_control", "tour_key", null)
			and guard.get("key_on_hook") == true,
			"the key hangs back and the hook is restored")
	_check(not box.call("tour_key_available"),
			"and the box asks for it again")
	_check(int(net.call("mark_count")) == 1
			and int(board.call("indication_count")) == 1,
			"returning it retracts nothing that already happened")
	_check(not guard.call("interact_control", "tour_key", null)
			or guard.get("key_on_hook") == false,
			"and the hook is a hook: it holds one key, not two")

	# --- nothing else moved --------------------------------------------------
	_check(JSON.stringify(RealityState.data.get("maintenance_jobs", {}))
					== jobs_before,
			"NO WORKORDER was created, advanced or closed")
	_check(JSON.stringify(RealityState.data.get("cases", {})) == cases_before
			and case_events.is_empty(),
			"no case moved and no case signal was published (%s)"
					% ", ".join(case_events))
	# The only consumer production has wired is the first-shift director, and
	# it acts on the station's published fact, not on anything of the guard's.
	var before_keys: Dictionary = JSON.parse_string(save_before)
	var save_moved: Array[String] = []
	for key in RealityState.data.keys():
		if JSON.stringify(RealityState.data[key]) \
				!= JSON.stringify(before_keys.get(key)):
			save_moved.append(str(key))
	_check(save_moved.is_empty() or save_moved == ["first_shift"],
			"the only save key that moved is the first-shift owner's (%s)"
					% ", ".join(save_moved))
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
			and not AcousticGraphData.nodes.has("F01_TOUR_KEY_GUARD"),
			"the acoustic graph is unchanged (%d) and gains no node"
					% graph_before)
	_check(schedule == null or int((schedule.get("_dispatched")
			as Dictionary).size()) == dispatched_before,
			"the resident schedules are untouched")
	_check((guard as Node3D).find_children("*", "Light3D", true,
			false).is_empty(),
			"the guard owns no light of its own")
	var bodies: Array = (guard as Node3D).find_children("*",
			"CollisionObject3D", true, false)
	_check(bodies.size() == 1 and bodies[0] is Area3D,
			"and one Area reach, which obstructs nothing in the lane")
	var reach := 0.0
	for vis in (guard as Node3D).find_children("*", "VisualInstance3D", true,
			false):
		var vi := vis as VisualInstance3D
		var ab := vi.global_transform * vi.get_aabb()
		reach = maxf(reach, WALL_X - ab.position.x)
	_check(reach < 0.16, "it projects only %.3f m into the lobby" % reach)

	# --- abort ---------------------------------------------------------------
	guard.call("take_key")
	guard.call("restore_maintenance_snapshot", found_guard)
	_check(guard.get("key_on_hook") == true and not guard.call("balking"),
			"ABORT hangs the real key back exactly as it was found")
	_check(int(net.call("mark_count")) == 1
			and int(net.call("delivered_count")) == 1
			and int(board.call("indication_count")) == 1,
			"and CANNOT RETRACT the mark the round already made")
	_check(wo != null and str(wo.call("job_stage", "vantry_chirp_2a"))
			== "missing",
			"the opening report is exactly where it was: unissued")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [tour key live ok] ", label)
	else:
		failures += 1
		printerr("  [TOUR KEY LIVE FAIL] ", label)


func _finish() -> void:
	print("TOUR KEY LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
