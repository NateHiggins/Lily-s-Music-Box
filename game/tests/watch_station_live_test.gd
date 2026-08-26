extends Node
## SR7-J — the box hangs on the real route and obstructs nothing.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/WatchStationLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## The focused test proves the apparatus. This one proves the three claims
## only the real building can settle:
##
##   * the box is genuinely ON the way from the lift to Mina's Vantry point,
##     at a height a standing player reads, and clear of both the door it
##     stands beside and the wall it hangs on;
##   * it obstructs nothing -- no body a resident could walk into, no
##     navigation edge cut, no acoustic node added, no light;
##   * marking it moves no job, no case, no schedule and no save, and the
##     round to 2A is exactly as walkable with the box never touched.

var failures := 0
var checks := 0

## The route, in building coordinates, all read from production.
const STATION_X := -5.33
const STATION_Y := -3.10
const CORRIDOR_WALL_X := -5.33
## `F02_DOOR_02`, 2A's entry, on the same wall.
const DOOR_2A_Y := -2.11
const DOOR_HALF := 0.48
## The Vantry point the opening report sends the player to.
const VANTRY_2A := Vector2(-9.20, -3.04)
## `LiftSheave`, where the player arrives on the floor.
const LIFT = Vector2(4.86, -4.73)


func _ready() -> void:
	RealityState.persistence_enabled = false
	var root: Node = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var box: Node = root.find_child("F02_WATCH_STATION_01", true, false)
	_check(box != null, "the production second floor owns a watch station")
	if box == null:
		_finish()
		return

	# --- it is on the route -------------------------------------------------
	var at: Vector3 = (box as Node3D).global_position
	var by := -at.z
	print("[STATION LIVE] global b(%.2f, %.2f, %.2f)" % [at.x, by, at.y])
	_check(absf(at.x - STATION_X) < 0.02 and absf(by - STATION_Y) < 0.02,
			"it hangs at the authored station on the corridor's west wall")
	_check(absf(at.x - CORRIDOR_WALL_X) < 0.02,
			"which is the real F02_CORRIDOR wall face, not a wall of its own")
	# F02's floor is at z 3.2; a standing eye is about 1.6 above it. The case
	# is 0.32 tall, so its legend sits between 1.42 and 1.74 above the boards.
	var above_floor := at.y - 3.2
	_check(above_floor > 1.30 and above_floor < 1.55,
			"at a standing reading height (%.2f above the F02 floor)"
					% above_floor)
	_check((box as Node3D).global_transform.basis.z.normalized().x > 0.9,
			"and its face is turned into the corridor, not into the flat")

	# ON THE WAY IN, not past the door. The lift is south-east, 2A's entry is
	# north of the box on the same wall, and the flat is west beyond it.
	var door: Node = root.find_child("F02_DOOR_02", true, false)
	_check(door != null and str(door.get("leaf_state")) != "",
			"2A's entry door F02_DOOR_02 is a real production door")
	_check(by < DOOR_2A_Y, "the box is passed BEFORE 2A's door, walking north")
	_check(absf(by - DOOR_2A_Y) > DOOR_HALF + 0.30,
			"and stands clear of that door's opening (%.2f m of wall between)"
					% (absf(by - DOOR_2A_Y) - DOOR_HALF))
	# The walk really does come this way: the lift is south of the box and the
	# Vantry point is west beyond the door, so the box is between them.
	_check(LIFT.y < by and VANTRY_2A.x < STATION_X,
			"the lift lands south of it and the Vantry point lies beyond it")
	var vantry: Node = root.get("vantry_points")
	var pts: Dictionary = vantry.get("points")
	var point: Dictionary = pts.get("F02_A_MAIN_VANTRY_POINT", {})
	_check(not point.is_empty() and str(point.get("unit")) == "2A",
			"and the opening report's Vantry point is the 2A one, in 2A")

	# --- it obstructs nothing -----------------------------------------------
	var bodies: Array = (box as Node3D).find_children("*",
			"CollisionObject3D", true, false)
	_check(bodies.size() == 1 and bodies[0] is Area3D
			and not (bodies[0] is StaticBody3D),
			"its only body is an Area: it reports overlaps and stops nobody")
	_check((box as Node3D).find_children("*", "Light3D", true,
			false).is_empty(),
			"the apparatus owns no light of its own")
	# Nothing of it reaches far enough into the corridor to be in the way. The
	# corridor runs x -5.33..5.33, so a case standing 0.13 off the wall leaves
	# the whole ring walkable.
	var reach := 0.0
	for vis in (box as Node3D).find_children("*", "VisualInstance3D", true,
			false):
		var vi := vis as VisualInstance3D
		var ab := vi.global_transform * vi.get_aabb()
		reach = maxf(reach, ab.position.x + ab.size.x - CORRIDOR_WALL_X)
	_check(reach < 0.20,
			"and it projects only %.3f m into the corridor" % reach)
	_check(not AcousticGraphData.nodes.has("F02_WATCH_STATION_01")
			and not AcousticGraphData.nodes.has("F02_STATION_2A_LANDING"),
			"it adds no acoustic node of its own")

	# --- the network --------------------------------------------------------
	var net: Node = root.find_child("WatchStationNetwork", true, false)
	# SR7-M put a second box on this line, at the boiler. What matters to THIS
	# test is that the line carries the landing station and that every box on
	# it is one the building actually authored -- not that there is only one.
	var adopted: Array = net.call("station_ids") if net != null else []
	var unauthored: Array[String] = []
	for id in adopted:
		if not WatchStationProp.STATIONS.has(str(id)):
			unauthored.append(str(id))
	_check(net != null and "F02_STATION_2A_LANDING" in adopted
			and unauthored.is_empty()
			and int(net.call("station_count")) == adopted.size(),
			"the production network carries this station, and only authored "
					+ "ones (%s)" % ", ".join(adopted))
	_check(int(net.call("mark_count")) == 0,
			"and at boot nothing has been marked")

	# --- what must not move -------------------------------------------------
	var wo: Node = root.get("work_orders")
	var jobs_before := JSON.stringify(
			RealityState.data.get("maintenance_jobs", {}))
	var cases_before := JSON.stringify(RealityState.data.get("cases", {}))
	var save_before := JSON.stringify(RealityState.data)
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
	var doors_before: Dictionary = {}
	for leaf in root.find_children("F02_DOOR_*", "", true, false):
		doors_before[str(leaf.name)] = str(leaf.get("leaf_state"))

	# SR7-L: the production box will not run its wheel with the tour key on
	# its hook in the lobby. Take it first -- this is now what walking a round
	# actually costs, and the gate itself is proved in `TourKeyLiveTest`.
	var key_guard: Node = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	_check(key_guard != null and key_guard.call("take_key"),
			"the production tour key comes off its hook for the round")

	# --- work the real box --------------------------------------------------
	var heard: Array[Dictionary] = []
	box.connect("station_marked",
			func(_id: String, r: Dictionary) -> void: heard.append(r))
	var found: Dictionary = box.call("maintenance_snapshot")
	_check(str(box.call("control_prompt", "station")).contains("STATION 2"),
			"the shut box names itself in its own prompt, readable in passing")
	_check(box.call("interact_control", "station", null)
			and box.get("door_open") == true,
			"one press opens the real box")
	_check(box.call("interact_control", "station", null)
			and heard.size() == 1 and int(box.get("marks")) == 1,
			"the next press turns the crank and makes ONE mark")
	var record: Dictionary = heard[0]
	_check(str(record.station_id) == "F02_STATION_2A_LANDING"
			and int(record.station_number) == 2
			and str(record.serves) == "2A",
			"the fact names this station, its number and the flat it serves")
	# THE HOUR IS THE HOUSE'S. Read from the same day/night owner the sky and
	# the watchman's detector use -- not a clock of its own.
	var director: Node = root.get("day_night_director")
	_check(director != null
			and absf(float(record.at_minute)
					- float(director.call("_minute_now"))) < 0.001,
			"and its hour is the house clock's, to the minute (%.0f)"
					% float(record.at_minute))
	_check(int(net.call("mark_count")) == 1
			and net.call("has_mark", "F02_STATION_2A_LANDING"),
			"the production network holds exactly that one mark")
	# The latch spring took the door home when the wheel ran.
	_check(box.get("door_open") == false and box.get("drop_fallen") == true,
			"the box shut itself and its drop is down")

	# REPEATED, ON THE REAL BOX.
	box.call("interact_control", "station", null)
	box.call("interact_control", "station", null)
	_check(int(box.get("marks")) == 1 and heard.size() == 1
			and int(net.call("mark_count")) == 1,
			"working it again cannot duplicate the mark")

	# --- nothing moved ------------------------------------------------------
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
	var save_moved: Array[String] = []
	for key in RealityState.data.keys():
		if JSON.stringify(RealityState.data[key]) 				!= JSON.stringify(before_keys.get(key)):
			save_moved.append(str(key))
	for key in before_keys.keys():
		if not RealityState.data.has(key) and str(key) not in save_moved:
			save_moved.append(str(key))
	_check(save_moved.is_empty() or save_moved == ["first_shift"],
			"the only save key that save_moved is the first-shift owner's (%s)"
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
	_check(AcousticGraphData.nodes.size() == graph_before,
			"the acoustic graph is unchanged (%d nodes)" % graph_before)
	_check(schedule == null or int((schedule.get("_dispatched")
			as Dictionary).size()) == dispatched_before,
			"the resident schedules are untouched (%d dispatched)"
					% dispatched_before)
	var moved: Array[String] = []
	for leaf_name in doors_before.keys():
		var leaf: Node = root.find_child(str(leaf_name), true, false)
		if leaf != null and str(leaf.get("leaf_state")) != doors_before[leaf_name]:
			moved.append(str(leaf_name))
	_check(moved.is_empty(),
			"and not one F02 door changed state (%s)" % ", ".join(moved))

	# --- abort --------------------------------------------------------------
	box.call("restore_maintenance_snapshot", found)
	_check(box.get("door_open") == false and box.get("drop_fallen") == false
			and int(box.get("marks")) == 0 and not box.call("balking"),
			"ABORT puts the real box back exactly as it was found")

	# --- MISSING THE MARK BLOCKS NOTHING ------------------------------------
	# The strongest form of this: the route to 2A is a real production door
	# and a real production Vantry point, and neither of them has ever heard
	# of this box.
	_check(str(door.get("leaf_state")) != "locked",
			"2A's entry is not locked, marked or unmarked")
	_check(not box.has_method("required")
			and not box.has_method("blocks_route"),
			"nothing about the box declares itself required")
	# AND THE LINE ABORT DOES NOT CROSS. Restoring the apparatus puts the iron
	# back; it does NOT reach into a listener and retract a fact already
	# published. The network still holds the mark it was handed, and that is
	# right: a box that could un-say what it said would be a worse instrument
	# than one that cannot, and the prop has no business editing a consumer.
	_check(int(net.call("mark_count")) == 1
			and net.call("has_mark", "F02_STATION_2A_LANDING"),
			"and the network keeps the fact it was handed -- abort restores "
					+ "the apparatus, it does not un-say what was said")
	var wo_open: bool = wo != null
	_check(wo_open and str(wo.call("job_stage", "vantry_chirp_2a"))
			== "missing",
			"and the opening report is exactly where it was: unissued")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [station live ok] ", label)
	else:
		failures += 1
		printerr("  [STATION LIVE FAIL] ", label)


func _finish() -> void:
	print("WATCH STATION LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
