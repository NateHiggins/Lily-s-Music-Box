extends Node
## SR7-M focused proof: two boxes do not make a route.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/WatchPairTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE THESIS. Two numbered indications prove two boxes were worked. They do
## not prove who carried the key, which path was walked, or that the building
## was inspected.
##
## The measurable form of that: the board records IDENTITY (which number) and
## ARRIVAL (which sequence), and those are different axes. Work 1 then 2, or 2
## then 1, and the delivered set is identical while the order differs — so the
## sequence is a fact about the wire, never a claim about a walk.

const StationScript := preload("res://scripts/props/watch_station_prop.gd")
const NetworkScript := preload("res://scripts/building/watch_station_network.gd")
const RegisterScript := preload("res://scripts/props/watch_register_prop.gd")
const GuardScript := preload("res://scripts/props/tour_key_guard_prop.gd")

var failures := 0
var checks := 0

var network: WatchStationNetwork
var guard: TourKeyGuardProp
var board: WatchRegisterProp
var boiler: WatchStationProp
var landing: WatchStationProp
var facts: Array[Dictionary] = []
var shown: Array[Dictionary] = []


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()

	_the_pair()
	_either_order()
	_one_cannot_satisfy_the_other()
	_no_key()
	_the_open_line()
	_abort()
	_not_a_route()

	print("WATCH PAIR TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)


## One line, one key, one board, two boxes.
func _wire_up() -> void:
	for old in [network, guard, board, boiler, landing]:
		if old != null:
			old.queue_free()
	network = NetworkScript.new() as WatchStationNetwork
	add_child(network)
	guard = GuardScript.new() as TourKeyGuardProp
	guard.prop_type = "tour_key_guard"
	add_child(guard)
	board = RegisterScript.new() as WatchRegisterProp
	board.prop_type = "signal_register"
	add_child(board)
	boiler = _station("B1_STATION_BOILER")
	landing = _station("F02_STATION_2A_LANDING")
	network.attach_key_guard(guard)
	network.attach_receiver(board)
	network.register(boiler)
	network.register(landing)
	facts.clear()
	shown.clear()
	network.station_marked.connect(
			func(_i: String, r: Dictionary) -> void: facts.append(r))
	board.signal_displayed.connect(
			func(n: int, seq: int) -> void:
				shown.append({"number": n, "sequence": seq}))


func _station(id: String) -> WatchStationProp:
	var box := StationScript.new() as WatchStationProp
	box.prop_type = "watch_station"
	box.station_id = id
	add_child(box)
	return box


## Work a box the way a hand does.
func _work(box: WatchStationProp) -> bool:
	box.open_door()
	return box.turn_crank()


# --- two boxes, two numbers --------------------------------------------------

func _the_pair() -> void:
	_wire_up()
	_check("the building authors exactly two stations",
			WatchStationProp.STATIONS.size() == 2
			and WatchStationProp.STATIONS.has("B1_STATION_BOILER")
			and WatchStationProp.STATIONS.has("F02_STATION_2A_LANDING"))
	_check("with distinct numbers, and STATION 1 is the boiler",
			boiler.station_number() == 1 and landing.station_number() == 2
			and boiler.legend() == "STATION 1"
			and landing.legend() == "STATION 2"
			and str(boiler.spec().get("serves")) == "boiler")
	# THE CODED WHEEL IS CUT WITH THE NUMBER, so a box can only ever transmit
	# the one station it is -- one tooth against two.
	var boiler_teeth := boiler.find_children("WheelTooth*", "MeshInstance3D",
			true, false).size()
	var landing_teeth := landing.find_children("WheelTooth*", "MeshInstance3D",
			true, false).size()
	_check("their coded wheels differ in the metal (%d tooth vs %d)"
					% [boiler_teeth, landing_teeth],
			boiler_teeth == 1 and landing_teeth == 2
			and boiler_teeth != landing_teeth)
	_check("both are the SAME family, not a second kind of apparatus",
			boiler.get_script() == landing.get_script())
	_check("the network adopted both and the board has a shutter for each",
			network.station_count() == 2
			and boiler.station_number() in WatchRegisterProp.SHUTTER_NUMBERS
			and landing.station_number() in WatchRegisterProp.SHUTTER_NUMBERS)
	_check("and at rest nothing is marked, carried or shown",
			network.mark_count() == 0 and board.indication_count() == 0
			and not guard.key_carried())


# --- EITHER ORDER ------------------------------------------------------------

func _either_order() -> void:
	# Boiler first, then the landing.
	_wire_up()
	guard.take_key()
	_check("STATION 1 FIRST: the boiler marks",
			_work(boiler) and boiler.marked() and network.delivered_count() == 1)
	_check("then STATION 2: the landing marks",
			_work(landing) and landing.marked()
			and network.delivered_count() == 2)
	var up_numbers: Array[int] = []
	var up_sequence: Array[int] = []
	for s in shown:
		up_numbers.append(int(s.number))
		up_sequence.append(int(s.sequence))
	_check("the board shows both drops down and counted twice",
			board.shows(1) and board.shows(2) and board.signals_taken == 2
			and board.indication_count() == 2)

	# The landing first, then the boiler.
	_wire_up()
	guard.take_key()
	_check("STATION 2 FIRST: the landing marks",
			_work(landing) and network.delivered_count() == 1)
	_check("then STATION 1: the boiler marks",
			_work(boiler) and network.delivered_count() == 2)
	var down_numbers: Array[int] = []
	var down_sequence: Array[int] = []
	for s in shown:
		down_numbers.append(int(s.number))
		down_sequence.append(int(s.sequence))
	_check("the board again shows both drops down and counted twice",
			board.shows(1) and board.shows(2) and board.signals_taken == 2)

	# THE MEASUREMENT THAT IS THE WHOLE INCREMENT.
	up_numbers.sort()
	down_numbers.sort()
	_check("BOTH ORDERS DELIVER THE SAME TWO INDICATIONS (%s vs %s)"
					% [str(up_numbers), str(down_numbers)],
			up_numbers == down_numbers and up_numbers == [1, 2])
	_check("and the SEQUENCE is arrival order, which is not the same fact "
					+ "(1 then 2 gave %s; 2 then 1 gave %s)"
					% [str(up_sequence), str(down_sequence)],
			up_sequence == [1, 2] and down_sequence == [1, 2]
			and int(shown[0].number) == 2)
	# The board has no field for a route, because it has no way to know one.
	for forbidden in ["route", "path", "order_walked", "tour", "complete",
			"who"]:
		_check("the indication says nothing about `%s`" % forbidden,
				not board.last_indication().has(forbidden))
	_check("nor does the network offer a route, a next station or completion",
			not network.has_method("next_station")
			and not network.has_method("route")
			and not network.has_method("complete")
			and not network.has_method("required_stations"))


# --- one cannot satisfy the other --------------------------------------------

func _one_cannot_satisfy_the_other() -> void:
	_wire_up()
	guard.take_key()
	_work(boiler)
	_check("with only the boiler worked, only ITS drop is down",
			boiler.marked() and not landing.marked()
			and board.shows(1) and not board.shows(2)
			and network.delivered_count() == 1)
	_check("and the landing is exactly as willing as it ever was",
			not landing.balking() and landing.tour_key_available())
	# PER-STATION LOCKOUT. Working the boiler again is refused by ITS pawl and
	# leaves the landing untouched.
	for i in 3:
		boiler.turn_crank()
	_check("REPEATS on one box add nothing, and do not reach the other",
			boiler.marks == 1 and landing.marks == 0
			and network.delivered_count() == 1
			and board.signals_taken == 1)
	_check("the other box then marks normally, on its own number",
			_work(landing) and board.shows(2)
			and network.delivered_count() == 2
			and board.signals_taken == 2)


# --- no key, and no substitute -----------------------------------------------

func _no_key() -> void:
	_wire_up()
	_check("with the key on its hook, NEITHER station will mark",
			not boiler.tour_key_available()
			and not landing.tour_key_available())
	boiler.open_door()
	landing.open_door()
	_check("REFUSAL at the boiler: empty socket",
			not boiler.turn_crank() and boiler.balking()
			and boiler.marks == 0)
	_check("REFUSAL at the landing: empty socket",
			not landing.turn_crank() and landing.balking()
			and landing.marks == 0)
	_check("and nothing was made, carried or shown",
			facts.is_empty() and network.delivered_count() == 0
			and board.indication_count() == 0)
	# NO SUBSTITUTE. The night register's apartment and plant keys are a
	# different apparatus entirely, and the line asks ONE guard one question.
	var raw := FileAccess.get_file_as_string(
			"res://scripts/building/watch_station_network.gd")
	var code := ""
	for line in raw.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	_check("the line knows nothing of the register's apartment or plant keys",
			not code.contains("APARTMENT_HOOK")
			and not code.contains("PLANT_HOOK")
			and not code.contains("NightRegister"))
	# Counted as a QUOTED method name: the network's own `tour_key_carried`
	# contains the substring, so a bare count measures the wrong thing. Two
	# quoted uses is the whole surface -- the `has_method` guard on adoption
	# and the one `call` that asks.
	_check("and asks exactly one question of exactly one guard (%d uses)"
					% code.count("\"key_carried\""),
			code.count("\"key_carried\"") == 2
			and network.has_method("tour_key_carried")
			and not network.has_method("attach_second_key_guard"))
	# The tour key is the only thing that answers it.
	guard.take_key()
	_check("only the tour key opens the sockets, and it opens BOTH",
			boiler.tour_key_available() and landing.tour_key_available())


# --- the open line, for both -------------------------------------------------

func _the_open_line() -> void:
	_wire_up()
	guard.take_key()
	network.set_line_closed(false)
	_check("the line is cut and the board says so",
			not board.line_closed and board.line_reads() == "LINE OPEN")
	_check("BOTH boxes still mark: their drops are mechanical",
			_work(boiler) and _work(landing)
			and boiler.marked() and landing.marked())
	_check("both facts were made and published (%d)" % network.mark_count(),
			facts.size() == 2 and network.mark_count() == 2)
	_check("BUT THE LOBBY RECEIVED NEITHER (delivered %d, undelivered %d)"
					% [network.delivered_count(), network.undelivered_count()],
			network.delivered_count() == 0
			and network.undelivered_count() == 2
			and board.indication_count() == 0
			and board.signals_taken == 0)
	network.set_line_closed(true)
	_check("and closing the line back-fills neither of them",
			board.indication_count() == 0 and network.delivered_count() == 0)


# --- abort -------------------------------------------------------------------

func _abort() -> void:
	_wire_up()
	guard.take_key()
	var found_boiler: Dictionary = boiler.maintenance_snapshot()
	var found_board: Dictionary = board.maintenance_snapshot()
	_work(boiler)
	_work(landing)
	_check("both boxes worked and both indications are showing",
			network.delivered_count() == 2 and board.indication_count() == 2)
	boiler.restore_maintenance_snapshot(found_boiler)
	board.restore_maintenance_snapshot(found_board)
	_check("ABORT restores the boiler box and the board",
			not boiler.marked() and boiler.marks == 0
			and board.indication_count() == 0 and board.signals_taken == 0)
	# THE LINE ABORT DOES NOT CROSS, with two boxes as with one.
	_check("and CANNOT RETRACT either fact the network was handed",
			network.mark_count() == 2 and network.delivered_count() == 2
			and facts.size() == 2)
	_check("the landing box, which nobody restored, is untouched by it",
			landing.marked() and landing.marks == 1)
	# The key returns after one mark or two, and after none.
	_check("the key hangs back with both marks made",
			guard.return_key() and guard.key_on_hook)
	_wire_up()
	guard.take_key()
	_work(boiler)
	_check("and it hangs back after only ONE",
			guard.return_key() and guard.key_on_hook
			and network.delivered_count() == 1)
	_wire_up()
	guard.take_key()
	_check("and after none at all",
			guard.return_key() and guard.key_on_hook
			and network.mark_count() == 0)


# --- and it is not a route ---------------------------------------------------

func _not_a_route() -> void:
	var sources := {
		"the station": "res://scripts/props/watch_station_prop.gd",
		"the network": "res://scripts/building/watch_station_network.gd",
		"the register": "res://scripts/props/watch_register_prop.gd",
		"the guard": "res://scripts/props/tour_key_guard_prop.gd",
	}
	for label in sources.keys():
		var raw := FileAccess.get_file_as_string(str(sources[label]))
		var code := ""
		for line in raw.split("\n"):
			if not line.strip_edges().begins_with("#"):
				code += line + "\n"
		for forbidden in ["WorkOrders", "RealityCases", "RealityState",
				"FirstShiftDirector", "CoreLoopDirector", "ObjectiveTracker",
				"ScheduleDirector", "AcousticGraphData", "leaf_state",
				"activate_case", "issue_job", "dream"]:
			_check("%s cannot reach `%s`" % [str(label), forbidden],
					not code.contains(forbidden))
		for forbidden in ["required", "must_visit", "checklist", "objective",
				"completion", "all_stations_marked"]:
			_check("%s declares no `%s`" % [str(label), forbidden],
					not code.contains(forbidden))
	# NO SAVE OWNER, with two boxes as with one.
	var save_before := JSON.stringify(RealityState.data)
	_wire_up()
	guard.take_key()
	_work(boiler)
	_work(landing)
	guard.return_key()
	_check("a whole two-station round writes NOTHING to the save",
			JSON.stringify(RealityState.data) == save_before)
	_check("neither box owns a light, and each has one Area reach",
			boiler.find_children("*", "Light3D", true, false).is_empty()
			and landing.find_children("*", "Light3D", true, false).is_empty()
			and boiler.find_children("*", "CollisionObject3D", true,
					false).size() == 1
			and boiler.find_children("*", "CollisionObject3D", true,
					false)[0] is Area3D)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [pair ok] ", label)
	else:
		failures += 1
		printerr("  [PAIR FAIL] ", label)
