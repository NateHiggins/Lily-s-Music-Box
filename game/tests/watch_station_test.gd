extends Node
## SR7-J focused proof: a mark says a box was worked, and nothing else.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/WatchStationTest.tscn `
##         -ProjectPath <checkout>/game
##
## The four things this file exists to make true:
##   * one deliberate turn of the crank makes one station/time record;
##   * a second turn is ACKNOWLEDGED and cannot duplicate the mark;
##   * the record names no person, no job and no case, because the iron has no
##     way of knowing any of them;
##   * nothing here can be missed into failure.

const StationScript := preload("res://scripts/props/watch_station_prop.gd")
const NetworkScript := preload("res://scripts/building/watch_station_network.gd")

var failures := 0
var checks := 0

var station: WatchStationProp
var network: WatchStationNetwork
var heard: Array[Dictionary] = []


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_build()

	_the_box()
	_the_mark()
	_the_lockout()
	_the_record()
	_abort()
	_the_network()
	_ownership()

	print("WATCH STATION TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)


func _build() -> void:
	network = NetworkScript.new() as WatchStationNetwork
	add_child(network)
	_fresh_station()


func _fresh_station() -> void:
	if station != null:
		station.queue_free()
	station = StationScript.new() as WatchStationProp
	station.prop_type = "watch_station"
	station.station_id = "F02_STATION_2A_LANDING"
	add_child(station)
	heard.clear()
	station.station_marked.connect(
			func(id: String, r: Dictionary) -> void:
				heard.append({"id": id, "record": r}))


# --- the iron ----------------------------------------------------------------

func _the_box() -> void:
	_check("the authored station table holds this box",
			WatchStationProp.STATIONS.has("F02_STATION_2A_LANDING")
			and station.station_number() == 2
			and station.legend() == "STATION 2"
			and str(station.spec().get("serves")) == "2A")
	# THE DOOR IS SHUT OR OPEN AND NEVER BETWEEN -- Gamewell's latch spring,
	# and the reason a half-closed box is visible from down a corridor.
	_check("as found: door shut, drop up, nothing marked",
			not station.door_open and not station.drop_fallen
			and station.marks == 0 and not station.marked())
	var door := station.find_child("StationDoor", true, false) as Node3D
	var drop := station.find_child("StationDrop", true, false) as Node3D
	_check("the case has a door and a drop that can visibly move",
			door != null and drop != null)
	var shut: float = door.rotation.y
	_check("opening the box swings the leaf and nothing else",
			station.open_door() and station.door_open
			and absf(door.rotation.y - shut) > 0.8
			and not station.drop_fallen and station.marks == 0)
	_check("REFUSAL: an open box cannot be opened again",
			not station.open_door() and station.balking()
			and station.door_open)
	# The refusal above is a HELD pose, and it is holding the leaf off its
	# stop right now -- so it has to be cleared before the leaf's resting
	# angle means anything. That the pose survives until cleared is the point
	# of it; a refusal that evaporated on the next call could not be shot.
	station.restore_maintenance_snapshot(station.maintenance_snapshot())
	_check("and it closes again, with no mark made",
			station.close_door() and not station.door_open
			and absf(door.rotation.y - shut) < 0.0001
			and station.marks == 0)
	# THE CRANK IS BEHIND THE DOOR. A shut box cannot be worked.
	_check("REFUSAL: the crank cannot be turned through a shut door",
			not station.turn_crank() and station.balking()
			and station.marks == 0 and not station.drop_fallen)
	_check("the box has an EMPTY tour-key socket, which is the point",
			station.find_child("TourKeySocket", true, false) != null)
	# The wheel's teeth ARE the station number: a box can transmit only the
	# one station it is.
	var teeth := 0
	for tooth in station.find_children("WheelTooth*", "MeshInstance3D", true,
			false):
		teeth += 1
	_check("the coded wheel is cut with this station's number (%d teeth)"
					% teeth,
			teeth == station.station_number())


func _the_mark() -> void:
	_fresh_station()
	var drop := station.find_child("StationDrop", true, false) as Node3D
	var up: float = drop.rotation.z
	station.open_door()
	_check("ONE deliberate turn of the crank makes ONE record",
			station.turn_crank() and heard.size() == 1
			and station.marks == 1 and station.marked())
	_check("and the drop has fallen, visibly and deterministically (%.2f -> %.2f)"
					% [up, drop.rotation.z],
			absf(drop.rotation.z - up) > 1.0)
	var record: Dictionary = heard[0].record
	_check("the fact names the station, its number and the hour",
			str(heard[0].id) == "F02_STATION_2A_LANDING"
			and str(record.station_id) == "F02_STATION_2A_LANDING"
			and int(record.station_number) == 2
			and float(record.at_minute) >= 0.0
			and int(record.sequence) == 1)
	_check("the pawl rode home when the wheel ran",
			(station.find_child("LockoutPawl", true, false) as Node3D)
					.position.x < 0.020)


func _the_lockout() -> void:
	# REPEATED INTERACTION IS ACKNOWLEDGED AND CANNOT DUPLICATE THE MARK.
	# The transmitter's lock-out pawl is what stopped one man cranking a
	# station twenty times, and it is why the second press is a refusal rather
	# than a second line.
	var crank := station.find_child("StationCrank", true, false) as Node3D
	var rest: float = crank.rotation.z
	station.set_process(false)
	for i in 5:
		_check("REFUSAL %d: the wheel will not run a second time" % (i + 1),
				not station.turn_crank() and station.balking()
				and station.marks == 1 and heard.size() == 1)
	_check("and the refusal MOVES the crank against its pawl (%.2f -> %.2f)"
					% [rest, crank.rotation.z],
			absf(crank.rotation.z - rest) > 0.2)
	_check("the drop stayed down and no second record exists",
			station.marked() and heard.size() == 1
			and network.mark_count() <= 1)
	station.restore_maintenance_snapshot(station.maintenance_snapshot())
	_check("clearing the refusal returns the crank to rest",
			not station.balking()
			and absf(crank.rotation.z - rest) < 0.0001)
	station.set_process(true)
	# Reset is a supervisor's act, and only then will the wheel run again.
	_check("resetting the drop is what makes the box willing again",
			station.reset_station() and not station.marked()
			and station.turn_crank() and heard.size() == 2
			and int(heard[1].record.sequence) == 2)
	_check("REFUSAL: an unfallen drop cannot be reset",
			station.reset_station() and not station.reset_station()
			and station.balking())


func _the_record() -> void:
	_fresh_station()
	station.open_door()
	station.turn_crank()
	var record: Dictionary = heard[0].record
	# IT DOES NOT PROVE WHO. There is no field for a person because a coded
	# wheel has no way of knowing one, and the record is asserted CLOSED so a
	# later hand cannot quietly add one.
	var extra: Array[String] = []
	for key in record.keys():
		if str(key) not in WatchStationProp.RECORD_FIELDS:
			extra.append(str(key))
	_check("the record carries exactly the authored fields (%s)"
					% ", ".join(extra),
			extra.is_empty()
			and record.size() == WatchStationProp.RECORD_FIELDS.size())
	for forbidden in ["who", "watchman", "player", "resident", "resident_id",
			"job_id", "case_id", "objective", "route", "next"]:
		_check("the record says nothing about `%s`" % forbidden,
				not record.has(forbidden))
	_check("the hour it carries is the canonical 03:00 with no clock owner",
			absf(float(record.at_minute) - WatchStationProp.CANONICAL_MINUTE)
					< 0.001)
	# The emitted record is a COPY. A consumer that decides to write "who" on
	# its own sheet cannot write it back onto the apparatus.
	record["who"] = "somebody"
	_check("and the emitted record is a copy: mutating it cannot reach back",
			not station.last_record().has("who"))


func _abort() -> void:
	_fresh_station()
	var found: Dictionary = station.maintenance_snapshot()
	station.open_door()
	station.turn_crank()
	station.turn_crank()   # leaves a refusal standing
	_check("a session opened the box, marked it and is holding a refusal",
			station.marked() and station.marks == 1 and station.balking())
	station.restore_maintenance_snapshot(found)
	_check("ABORT puts the door, the drop and the count back exactly",
			not station.door_open and not station.drop_fallen
			and station.marks == 0 and not station.balking())
	var after: Dictionary = station.maintenance_snapshot()
	var drift: Array[String] = []
	for key in found.keys():
		if str(after.get(key)) != str(found.get(key)):
			drift.append(str(key))
	_check("and every fact the apparatus had is restored (%s)"
					% ", ".join(drift),
			drift.is_empty() and after.size() == found.size())
	var door := station.find_child("StationDoor", true, false) as Node3D
	var drop := station.find_child("StationDrop", true, false) as Node3D
	_check("the iron itself is back where it was, not just the booleans",
			absf(door.rotation.y) < 0.0001 and drop.rotation.z > 1.0)


func _the_network() -> void:
	var net := NetworkScript.new() as WatchStationNetwork
	add_child(net)
	_check("a fresh network holds no stations and no marks",
			net.station_count() == 0 and net.mark_count() == 0
			and net.marked_stations().is_empty())
	_fresh_station()
	_check("it adopts a box once, and refuses a second adoption",
			net.register(station) and not net.register(station)
			and net.station_count() == 1
			and net.station_ids() == ["F02_STATION_2A_LANDING"])
	var relayed: Array[String] = []
	net.station_marked.connect(
			func(id: String, _r: Dictionary) -> void: relayed.append(id))
	_check("before the round, nothing is marked",
			not net.has_mark("F02_STATION_2A_LANDING")
			and net.mark_for("F02_STATION_2A_LANDING").is_empty())
	station.open_door()
	station.turn_crank()
	_check("the mark reaches the network once, and is relayed once",
			net.mark_count() == 1 and relayed == ["F02_STATION_2A_LANDING"]
			and net.has_mark("F02_STATION_2A_LANDING"))
	_check("and the network's copy is the box's record, untouched",
			str(net.mark_for("F02_STATION_2A_LANDING").station_id)
					== "F02_STATION_2A_LANDING"
			and int(net.mark_for("F02_STATION_2A_LANDING").station_number) == 2)
	for i in 4:
		station.turn_crank()
	_check("and four refused cranks add nothing to it",
			net.mark_count() == 1 and relayed.size() == 1)
	# THE ARCHITECTURE. One station today; the table is what makes a second
	# one a line rather than a class.
	_check("the network is a listener with a list, not a route",
			not net.has_method("next_station")
			and not net.has_method("require")
			and not net.has_method("complete"))
	net.queue_free()


# --- what the station is not -------------------------------------------------

func _ownership() -> void:
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/watch_station_prop.gd")
	var code := ""
	for raw in source.split("\n"):
		if not raw.strip_edges().begins_with("#"):
			code += raw + "\n"
	# NO LIFECYCLE OWNER. Read as text, because "there is no such call" is a
	# claim about absence and behaviour cannot prove one.
	for forbidden in ["WorkOrders", "work_orders", "RealityCases",
			"activate_case", "issue_job", "acknowledge_job", "close_job",
			"record_job", "diagnose_job", "RealityState", "ObjectiveTracker",
			"ScheduleDirector", "AcousticGraphData"]:
		_check("the station cannot reach `%s`" % forbidden,
				not code.contains(forbidden))
	var net_source := FileAccess.get_file_as_string(
			"res://scripts/building/watch_station_network.gd")
	# Comments stripped for the same reason as above: the network's own header
	# NAMES the owners it refuses to be, and a grep that counted prose would
	# fail on the documentation of the thing it is checking.
	var net_code := ""
	for raw_line in net_source.split("
"):
		if not raw_line.strip_edges().begins_with("#"):
			net_code += raw_line + "
"
	for forbidden in ["WorkOrders", "RealityCases", "RealityState",
			"AcousticGraphData"]:
		_check("nor can the network reach `%s`" % forbidden,
				not net_code.contains(forbidden))
	# NO SAVE OWNER. Marking a station writes nothing at all.
	var save_before := JSON.stringify(RealityState.data)
	_fresh_station()
	station.open_door()
	station.turn_crank()
	station.close_door()
	_check("a whole marked round writes NOTHING to the save",
			JSON.stringify(RealityState.data) == save_before)
	# NO LIGHT, and ONE body which is an Area3D -- a reach reports overlaps
	# and blocks neither movement nor navigation.
	_check("the apparatus owns no light of its own",
			station.find_children("*", "Light3D", true, false).is_empty())
	var bodies := station.find_children("*", "CollisionObject3D", true, false)
	_check("and exactly one collision object, its reach",
			bodies.size() == 1 and bodies[0] is PropControlArea
			and bodies[0] is Area3D)
	_check("which is an Area, so it obstructs nothing a resident walks through",
			not (bodies[0] is StaticBody3D)
			and not (bodies[0] is CharacterBody3D))
	# NOT A ROUTE REQUIREMENT. Nothing about the box gates anything, and the
	# clearest proof is that its own contract has no notion of being needed.
	for forbidden in ["required", "must_mark", "blocks", "gate", "objective"]:
		_check("the station declares no `%s`" % forbidden,
				not code.contains(forbidden))
	# MISSING THE MARK IS A LEGAL STATE. An untouched box is a shut box: no
	# alarm, no flag, no refusal, and a prompt that still offers itself.
	_fresh_station()
	_check("missing the mark is a legal state: an untouched box is just shut",
			not station.marked() and station.marks == 0
			and not station.balking()
			and station.control_prompt("station").contains("Open"))


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [station ok] ", label)
	else:
		failures += 1
		printerr("  [STATION FAIL] ", label)
