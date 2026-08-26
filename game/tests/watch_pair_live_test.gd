extends Node
## SR7-M — two real boxes, three floors apart, one key and one board.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/WatchPairLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## What only production can settle:
##
##   * the boiler box hangs on the real coal bunker's wall, between the boiler
##     and the coal and under the room's only light, in a room that contrasts
##     with the F02 landing in every way that matters;
##   * both real boxes work off the one real tour key, in either order, and
##     deliver the same two indications;
##   * an open real line drops both locals and delivers neither;
##   * not one real door leaf moves, and the key comes back after one mark,
##     two marks, or none.

var failures := 0
var checks := 0

## Measured from production. B1's floor is at z -2.8.
## The box hangs on the COAL BUNKER's north wall, between the boiler and the
## coal, under the boiler room's only light.
const BOILER_X := 12.00
const BOILER_WALL_Y := 2.70
const BOILER_PROP := Vector2(9.05, 1.55)
const COAL_BUNKER := Rect2(11.3, 0.3, 2.35, 2.4)
const BOILER_BULB := Vector2(9.58, 4.38)
const LANDING := Vector2(-5.33, -3.10)

var root: Node
var net: Node
var guard: Node
var board: Node
var boiler: Node
var landing: Node


func _ready() -> void:
	RealityState.persistence_enabled = false
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	boiler = root.find_child("B1_WATCH_STATION_01", true, false)
	landing = root.find_child("F02_WATCH_STATION_01", true, false)
	net = root.find_child("WatchStationNetwork", true, false)
	guard = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	board = root.find_child("F01_SIGNAL_REGISTER", true, false)
	_check(boiler != null and landing != null and net != null
			and guard != null and board != null,
			"production owns two stations, a key, a line and a register")
	if boiler == null or landing == null or net == null or guard == null \
			or board == null:
		_finish()
		return

	# --- where the second box hangs, and why --------------------------------
	var at: Vector3 = (boiler as Node3D).global_position
	var by := -at.z
	print("[PAIR LIVE] boiler station b(%.2f, %.2f, %.2f)"
			% [at.x, by, at.y])
	_check(absf(at.x - BOILER_X) < 0.02 and absf(by - BOILER_WALL_Y) < 0.02,
			"it hangs on the coal bunker's north wall at the authored station")
	_check(at.x > COAL_BUNKER.position.x
			and at.x < COAL_BUNKER.position.x + COAL_BUNKER.size.x
			and absf(by - (COAL_BUNKER.position.y + COAL_BUNKER.size.y)) < 0.02,
			"which is a real wall of the real B1_COAL bunker")
	_check(absf(at.y - (-2.8 + 1.42)) < 0.02,
			"at the lane's own reading height above the B1 floor (%.2f)" % at.y)
	# BOTH FIRE RISKS, AND ENOUGH LIGHT TO READ BY.
	var plant: Node = root.find_child("B1_BOILER_01", true, false)
	_check(plant != null, "the real boiler is in the room")
	if plant is Node3D:
		var p: Vector3 = (plant as Node3D).global_position
		var to_boiler := Vector2(at.x, by).distance_to(Vector2(p.x, -p.z))
		# BOTH FIRE RISKS FROM ONE STANDING POSITION: the boiler in front of
		# the box, the coal behind the wall it hangs on. That is the whole
		# reason an insurer wanted a man in this room.
		_check(to_boiler > 1.5 and to_boiler < 4.5,
				"%.2f m from the boiler, with the coal behind the wall"
						% to_boiler)
		# AND IT IS THE ONLY LIT WALL. The room has exactly one fixture; the
		# first placement, on the boiler's own axis, was 5.3 m from it with
		# the boiler in the way and photographed as a black rectangle.
		var to_bulb := Vector2(at.x, by).distance_to(BOILER_BULB)
		_check(to_bulb < 3.0,
				"and %.2f m from the room's only cage bulb, so it can be read"
						% to_bulb)
	_check((boiler as Node3D).global_transform.basis.z.normalized().z < -0.9,
			"its face is turned north, into the boiler room")

	# IT CONTRASTS WITH STATION 2. Different floor, different kind of room,
	# and far enough apart that neither is a second look at the same place.
	var far: Vector3 = (landing as Node3D).global_position
	_check(absf(far.y - at.y) > 5.0,
			"the two boxes are %.1f m apart vertically: basement and second"
					% absf(far.y - at.y))
	_check(int(boiler.call("station_number")) == 1
			and int(landing.call("station_number")) == 2
			and str(boiler.call("legend")) == "STATION 1",
			"and they carry distinct numbers, boiler 1 and landing 2")
	_check(int(net.call("station_count")) == 2,
			"the production line has adopted exactly the two of them")

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

	# --- NO KEY: NEITHER BOX MARKS ------------------------------------------
	_check(not boiler.call("tour_key_available")
			and not landing.call("tour_key_available"),
			"with the real key on its hook, neither real box will mark")
	boiler.call("interact_control", "station", null)
	_check(not boiler.call("interact_control", "station", null)
			and int(boiler.get("marks")) == 0,
			"REFUSAL at the real boiler box: empty socket")
	boiler.call("restore_maintenance_snapshot",
			boiler.call("maintenance_snapshot"))

	# --- ORDER ONE: BOILER THEN LANDING -------------------------------------
	_check(guard.call("take_key"), "the real tour key comes off its hook")
	var first_numbers := _work_both(boiler, landing)
	_check(first_numbers == [1, 2],
			"BOILER FIRST: the line delivered %s" % str(first_numbers))
	_check(int(net.call("delivered_count")) == 2
			and board.call("shows", 1) and board.call("shows", 2)
			and int(board.get("signals_taken")) == 2,
			"both indications are on the real lobby board")
	var seq_first: Array[int] = []
	for record in (net.call("delivered") as Array):
		seq_first.append(int(record.station_number))
	_check(seq_first == [1, 2],
			"and arrival order was boiler then landing (%s)" % str(seq_first))

	# --- ORDER TWO: LANDING THEN BOILER -------------------------------------
	_reset_line()
	var second_numbers := _work_both(landing, boiler)
	_check(second_numbers == [1, 2],
			"LANDING FIRST: the line delivered the SAME two (%s)"
					% str(second_numbers))
	var seq_second: Array[int] = []
	for record in (net.call("delivered") as Array):
		seq_second.append(int(record.station_number))
	_check(seq_second == [2, 1],
			"but arrival order was landing then boiler (%s)" % str(seq_second))
	# THE INCREMENT, IN ONE ASSERTION.
	_check(first_numbers == second_numbers and seq_first != seq_second,
			"TWO ORDERS, SAME TWO INDICATIONS, DIFFERENT ARRIVAL: the board "
					+ "records which boxes and when they reached it, and "
					+ "never which way anybody walked")

	# --- REPEATS -------------------------------------------------------------
	for i in 2:
		boiler.call("interact_control", "station", null)
		landing.call("interact_control", "station", null)
	_check(int(net.call("delivered_count")) == 2
			and int(board.get("signals_taken")) == 2
			and int(boiler.get("marks")) == 1
			and int(landing.get("marks")) == 1,
			"repeats at either box duplicate nothing")

	# --- THE OPEN LINE, FOR BOTH --------------------------------------------
	_reset_line()
	net.call("set_line_closed", false)
	var marks_before: int = int(net.call("mark_count"))
	boiler.call("interact_control", "station", null)
	boiler.call("interact_control", "station", null)
	landing.call("interact_control", "station", null)
	landing.call("interact_control", "station", null)
	_check(boiler.get("drop_fallen") == true
			and landing.get("drop_fallen") == true,
			"OPEN LINE: both real local drops fell, mechanically")
	_check(int(net.call("mark_count")) == marks_before + 2,
			"both facts were still made and published")
	_check(int(net.call("delivered_count")) == 0
			and int(board.call("indication_count")) == 0,
			"and the lobby received NEITHER (delivered %d)"
					% int(net.call("delivered_count")))
	net.call("set_line_closed", true)
	_check(int(board.call("indication_count")) == 0,
			"closing the line back-fills neither")

	# --- NOT ONE DOOR MOVED --------------------------------------------------
	var moved: Array[String] = []
	for leaf_name in doors_before.keys():
		var leaf: Node = root.find_child(str(leaf_name), true, false)
		if leaf != null and str(leaf.get("leaf_state")) != doors_before[leaf_name]:
			moved.append(str(leaf_name))
	_check(moved.is_empty() and doors_before.size() > 20,
			"across every round above, not one of %d real doors moved (%s)"
					% [doors_before.size(), ", ".join(moved)])
	var closet: Node = root.find_child("F02_DOOR_04", true, false)
	_check(closet != null and str(closet.get("leaf_state")) == "locked",
			"the service closet is still locked")
	var boiler_door: Node = root.find_child("B1_DOOR_06", true, false)
	var coal_door: Node = root.find_child("B1_DOOR_07", true, false)
	_check(boiler_door != null and coal_door != null
			and str(boiler_door.get("leaf_state"))
					== doors_before.get("B1_DOOR_06")
			and str(coal_door.get("leaf_state"))
					== doors_before.get("B1_DOOR_07"),
			"and the boiler and coal doors are exactly as they were")

	# --- THE KEY COMES BACK, AFTER ONE, TWO OR NONE -------------------------
	_check(guard.call("return_key") and guard.get("key_on_hook") == true,
			"the key hangs back with two marks made")
	_reset_line()
	guard.call("take_key")
	boiler.call("interact_control", "station", null)
	boiler.call("interact_control", "station", null)
	_check(int(boiler.get("marks")) == 1
			and guard.call("return_key") and guard.get("key_on_hook") == true,
			"and after only ONE mark")
	guard.call("take_key")
	_check(guard.call("return_key") and guard.get("key_on_hook") == true,
			"and after none at all")

	# --- nothing else moved --------------------------------------------------
	_check(JSON.stringify(RealityState.data.get("maintenance_jobs", {}))
					== jobs_before,
			"NO WORKORDER was created, advanced or closed")
	_check(JSON.stringify(RealityState.data.get("cases", {})) == cases_before
			and case_events.is_empty(),
			"no case moved and no case signal was published (%s)"
					% ", ".join(case_events))
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
			and not AcousticGraphData.nodes.has("B1_WATCH_STATION_01"),
			"the acoustic graph is unchanged (%d) and gains no node"
					% graph_before)
	_check(schedule == null or int((schedule.get("_dispatched")
			as Dictionary).size()) == dispatched_before,
			"the resident schedules are untouched")
	_check((boiler as Node3D).find_children("*", "Light3D", true,
			false).is_empty(),
			"the boiler box owns no light of its own")
	var bodies: Array = (boiler as Node3D).find_children("*",
			"CollisionObject3D", true, false)
	_check(bodies.size() == 1 and bodies[0] is Area3D,
			"and one Area reach, which obstructs nothing in the plant")
	var reach := 0.0
	for vis in (boiler as Node3D).find_children("*", "VisualInstance3D", true,
			false):
		var vi := vis as VisualInstance3D
		var ab := vi.global_transform * vi.get_aabb()
		reach = maxf(reach, -(ab.position.z + ab.size.z) - BOILER_WALL_Y)
	_check(reach < 0.20,
			"it projects only %.3f m into the boiler room" % reach)
	_check(wo != null and str(wo.call("job_stage", "vantry_chirp_2a"))
			== "missing",
			"the opening report is exactly where it was: unissued")

	_finish()


## Work two real boxes in the given order, and report the delivered numbers.
func _work_both(first: Node, second: Node) -> Array[int]:
	for box in [first, second]:
		box.call("interact_control", "station", null)   # opens the door
		box.call("interact_control", "station", null)   # turns the crank
	var numbers: Array[int] = []
	for record in (net.call("delivered") as Array):
		numbers.append(int(record.station_number))
	numbers.sort()
	return numbers


## Put both boxes, the board and the line back for another round. This is the
## apparatus's own reset, not a retraction: the network keeps its facts.
func _reset_line() -> void:
	for box in [boiler, landing]:
		box.call("restore_maintenance_snapshot",
				{"door_open": false, "drop_fallen": false, "marks": 0,
						"last_record": {}})
	board.call("restore_maintenance_snapshot",
			{"line_closed": true, "dropped": [], "signals_taken": 0,
					"last_indication": {}})
	net.call("clear_marks")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [pair live ok] ", label)
	else:
		failures += 1
		printerr("  [PAIR LIVE FAIL] ", label)


func _finish() -> void:
	print("WATCH PAIR LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
