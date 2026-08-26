extends Node
## SR7-K focused proof: the station makes it, the wire carries it, the board
## shows it — and those are three different claims.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/WatchRegisterTest.tscn `
##         -ProjectPath <checkout>/game
##
## The one this file exists for: AN OPEN LINE LEAVES THE STATION TRUTHFUL AND
## THE LOBBY IGNORANT. The box's drop is mechanical and falls anyway; the
## board's shutter needs current and does not.

const StationScript := preload("res://scripts/props/watch_station_prop.gd")
const NetworkScript := preload("res://scripts/building/watch_station_network.gd")
const RegisterScript := preload("res://scripts/props/watch_register_prop.gd")

var failures := 0
var checks := 0

var station: WatchStationProp
var network: WatchStationNetwork
var board: WatchRegisterProp
var facts: Array[Dictionary] = []
var shown: Array[Dictionary] = []


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()

	_the_board()
	_one_signal()
	_the_repeat()
	_the_open_line()
	_no_receiver()
	_the_reset()
	_abort()
	_ownership()

	print("WATCH REGISTER TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)


## A whole line: station, wire, board.
func _wire_up() -> void:
	if station != null:
		station.queue_free()
	if network != null:
		network.queue_free()
	if board != null:
		board.queue_free()
	network = NetworkScript.new() as WatchStationNetwork
	add_child(network)
	board = RegisterScript.new() as WatchRegisterProp
	board.prop_type = "signal_register"
	add_child(board)
	station = StationScript.new() as WatchStationProp
	station.prop_type = "watch_station"
	station.station_id = "F02_STATION_2A_LANDING"
	add_child(station)
	network.attach_receiver(board)
	network.register(station)
	facts.clear()
	shown.clear()
	network.station_marked.connect(
			func(_id: String, r: Dictionary) -> void: facts.append(r))
	board.signal_displayed.connect(
			func(n: int, seq: int) -> void:
				shown.append({"number": n, "sequence": seq}))


## Work the box the way a hand does.
func _mark() -> bool:
	station.open_door()
	return station.turn_crank()


# --- the instrument ----------------------------------------------------------

func _the_board() -> void:
	_wire_up()
	_check("the board has four numbered shutter positions, not one lamp",
			WatchRegisterProp.SHUTTER_NUMBERS == [1, 2, 3, 4]
			and board.find_child("Shutter2", true, false) != null)
	# A CLOSED-CIRCUIT LINE rests closed, so that a break is an abnormal
	# condition the board can show rather than silence you cannot read.
	_check("as found: line closed, every shutter up, counter at nought",
			board.line_closed and board.line_reads() == "LINE CLOSED"
			and board.indication_count() == 0 and board.signals_taken == 0)
	_check("and the network agrees the line is closed",
			network.line_closed and network.has_receiver()
			and network.station_count() == 1)
	_check("the board carries a reset lever and a line test key",
			board.get_node_or_null("Reach_reset") is PropControlArea
			and board.get_node_or_null("Reach_line") is PropControlArea)
	# IT IS A DIFFERENT INSTRUMENT FROM THE OTHER TWO. Not a console.
	_check("it is not the detector and not the night register",
			not board.has_method("sign_register")
			and not board.has_method("take_slip")
			and not board.has_method("dial_turns")
			and not board.has_method("turn_crank"))


# --- one signal, one indication ----------------------------------------------

func _one_signal() -> void:
	_wire_up()
	_check("before the round: nothing made, nothing carried, nothing shown",
			network.mark_count() == 0 and network.delivered_count() == 0
			and board.indication_count() == 0)
	_check("STATION 2 WORKED ONCE makes exactly one fact",
			_mark() and facts.size() == 1 and network.mark_count() == 1)
	_check("the wire carried exactly that one, and nothing else",
			network.delivered_count() == 1
			and network.undelivered_count() == 0)
	# THE AGREEMENT. Station and board name the same number and the same order.
	_check("and the board shows exactly ONE indication",
			shown.size() == 1 and board.indication_count() == 1)
	_check("STATION AND BOARD AGREE on the number (%d / %d)"
					% [station.station_number(),
							int(board.last_indication().station_number)],
			board.shows(station.station_number())
			and int(board.last_indication().station_number)
					== station.station_number()
			and int(shown[0].number) == station.station_number())
	_check("and on the sequence (%d / %d)"
					% [int(facts[0].sequence),
							int(board.last_indication().sequence)],
			int(board.last_indication().sequence) == int(facts[0].sequence)
			and board.signals_taken == 1)
	_check("the shutter for 2 is down and the other three are still up",
			board.shows(2) and not board.shows(1) and not board.shows(3)
			and not board.shows(4))
	var pivot := board.find_child("Shutter2", true, false) as Node3D
	var up := board.find_child("Shutter1", true, false) as Node3D
	# A gravity drop travels in a straight line and stays flush: the fallen
	# one is LOWER than the parked ones, and no part of the rank ever tilts
	# out of the board.
	_check("which is visible as brass, not only as a boolean (%.3f vs %.3f)"
					% [pivot.position.y, up.position.y],
			pivot.position.y < up.position.y - 0.05
			and absf(pivot.rotation.x) < 0.0001
			and absf(up.rotation.x) < 0.0001)
	# AND WHAT THE INDICATION IS NOT. No time, no person: neither came down
	# the wire, and a board that displayed either would be inventing it.
	var extra: Array[String] = []
	for key in board.last_indication().keys():
		if str(key) not in WatchRegisterProp.INDICATION_FIELDS:
			extra.append(str(key))
	_check("the indication is number and order ONLY (%s)" % ", ".join(extra),
			extra.is_empty())
	for forbidden in ["at_minute", "time", "who", "watchman", "player"]:
		_check("the board displays nothing about `%s`" % forbidden,
				not board.last_indication().has(forbidden))


# --- a repeat cannot make a second mark --------------------------------------

func _the_repeat() -> void:
	for i in 4:
		station.turn_crank()
	_check("four more cranks make no fact, no delivery and no indication",
			facts.size() == 1 and network.mark_count() == 1
			and network.delivered_count() == 1
			and board.indication_count() == 1 and board.signals_taken == 1)
	# And the board refuses one directly too, so the guarantee does not rest
	# only on the station's pawl.
	_check("and the board itself refuses a second signal at a fallen shutter",
			not board.receive_signal({"station_number": 2, "sequence": 9})
			and board.balking() and board.signals_taken == 1)
	_check("a number this board has no shutter for is refused, not invented",
			not board.receive_signal({"station_number": 7, "sequence": 1})
			and board.indication_count() == 1)


# --- THE OPEN LINE -----------------------------------------------------------

func _the_open_line() -> void:
	_wire_up()
	_check("the line opens, and both ends of it know",
			network.set_line_closed(false) and not network.line_closed
			and not board.line_closed
			and board.line_reads() == "LINE OPEN")
	var relay := board.find_child("LineRelay", true, false) as Node3D
	var pulled: float = relay.position.z
	_check("the relay armature has stood off its coil (%.3f)" % pulled,
			pulled < 0.058)
	_check("and the pilot has changed plate, not just legend",
			(board.find_child("PilotOpen", true, false) as MeshInstance3D).visible
			and not (board.find_child("PilotClosed", true, false)
					as MeshInstance3D).visible)

	# THE WHOLE POINT OF THE INCREMENT.
	_check("with the wire cut, the crank still turns and the box still marks",
			_mark() and station.marked() and station.marks == 1)
	_check("THE LOCAL DROP IS TRUTHFUL: it fell, mechanically, as it should",
			station.marked())
	_check("the fact was still made and still published (%d)"
					% network.mark_count(),
			facts.size() == 1 and network.mark_count() == 1)
	_check("BUT THE WIRE CARRIED NOTHING (delivered %d, undelivered %d)"
					% [network.delivered_count(), network.undelivered_count()],
			network.delivered_count() == 0
			and network.undelivered_count() == 1)
	_check("and the lobby board shows nothing at all",
			board.indication_count() == 0 and board.signals_taken == 0
			and shown.is_empty() and not board.shows(2))
	# A SHUTTER STILL UP PROVES NOTHING, and this is the sentence the whole
	# apparatus exists to make true: it cannot be told apart from nobody
	# having gone.
	_check("a shutter still up is indistinguishable from nobody having gone",
			not board.shows(2) and not board.balking())

	# Close the line again: the board does NOT catch up. A wire is not a
	# buffer, and a board that invented the signals it missed would be worse
	# than one that missed them.
	network.set_line_closed(true)
	_check("closing the line again does not back-fill what it missed",
			board.indication_count() == 0 and network.delivered_count() == 0
			and network.mark_count() == 1)
	_check("and the pilot reads closed again", board.line_closed
			and board.line_reads() == "LINE CLOSED")


# --- no receiver at all ------------------------------------------------------

func _no_receiver() -> void:
	var lone := NetworkScript.new() as WatchStationNetwork
	add_child(lone)
	var box := StationScript.new() as WatchStationProp
	box.prop_type = "watch_station"
	box.station_id = "F02_STATION_2A_LANDING"
	add_child(box)
	lone.register(box)
	_check("a line with no board on it is a legal building",
			not lone.has_receiver() and lone.receiver() == null)
	box.open_door()
	_check("LOSS OF THE RECEIVER: the box still works and still publishes",
			box.turn_crank() and box.marked() and lone.mark_count() == 1)
	_check("and nothing was delivered, because there was nowhere to deliver",
			lone.delivered_count() == 0 and lone.undelivered_count() == 1)
	_check("one board per line: a second is refused",
			lone.attach_receiver(board) and not lone.attach_receiver(board))
	lone.queue_free()
	box.queue_free()


# --- reset -------------------------------------------------------------------

func _the_reset() -> void:
	_wire_up()
	_mark()
	_check("a signal is showing before the lever is thrown",
			board.shows(2) and board.signals_taken == 1)
	var lever := board.find_child("ResetLever", true, false) as Node3D
	_check("the lever restores the shutters",
			board.reset_shutters() and not board.shows(2)
			and board.indication_count() == 0)
	# THE COUNTER DOES NOT GO BACK. A board can be tidied; the number of
	# signals it has taken is not a thing anybody gets to tidy away.
	_check("but the counter does NOT go back (%d)" % board.signals_taken,
			board.signals_taken == 1)
	_check("REFUSAL: a clear board has nothing to restore",
			not board.reset_shutters() and board.balking()
			and absf(lever.rotation.x) > 0.2)
	board.restore_maintenance_snapshot(board.maintenance_snapshot())
	_check("and the lever comes back to rest when the refusal clears",
			not board.balking() and absf(lever.rotation.x) < 0.0001)
	# THE FACT SURVIVES THE TIDYING. This is the same boundary SR7-J drew.
	_check("RESETTING THE BOARD CANNOT RETRACT THE FACT",
			network.mark_count() == 1 and network.delivered_count() == 1
			and facts.size() == 1)


# --- abort -------------------------------------------------------------------

func _abort() -> void:
	_wire_up()
	var found: Dictionary = board.maintenance_snapshot()
	_mark()
	board.receive_signal({"station_number": 2, "sequence": 2})   # refused
	_check("a session took a signal and is holding a refusal",
			board.shows(2) and board.signals_taken == 1 and board.balking())
	board.restore_maintenance_snapshot(found)
	_check("ABORT puts the shutters, the counter and the line back",
			not board.shows(2) and board.signals_taken == 0
			and board.line_closed and not board.balking())
	var after: Dictionary = board.maintenance_snapshot()
	var drift: Array[String] = []
	for key in found.keys():
		if str(after.get(key)) != str(found.get(key)):
			drift.append(str(key))
	_check("and every fact the board had is restored (%s)"
					% ", ".join(drift),
			drift.is_empty() and after.size() == found.size())
	var pivot := board.find_child("Shutter2", true, false) as Node3D
	_check("the brass itself is parked again, not just the booleans",
			absf(pivot.position.y - WatchRegisterProp.SHUTTER_REST_Y) < 0.0001)
	# AND THE LINE ABORT DOES NOT CROSS, on this instrument too.
	_check("ABORT CANNOT RETRACT THE ALREADY-EMITTED FACT",
			network.mark_count() == 1 and network.delivered_count() == 1
			and facts.size() == 1 and station.marked())


# --- what none of the three owns ---------------------------------------------

func _ownership() -> void:
	var sources := {
		"the register": "res://scripts/props/watch_register_prop.gd",
		"the network": "res://scripts/building/watch_station_network.gd",
		"the station": "res://scripts/props/watch_station_prop.gd",
	}
	for label in sources.keys():
		var raw := FileAccess.get_file_as_string(str(sources[label]))
		var code := ""
		for line in raw.split("\n"):
			if not line.strip_edges().begins_with("#"):
				code += line + "\n"
		for forbidden in ["WorkOrders", "RealityCases", "RealityState",
				"ObjectiveTracker", "ScheduleDirector", "AcousticGraphData",
				"FirstShiftDirector", "CoreLoopDirector", "activate_case",
				"issue_job", "acknowledge_job", "dream"]:
			_check("%s cannot reach `%s`" % [str(label), forbidden],
					not code.contains(forbidden))
	# NO SAVE OWNER anywhere on the line.
	var save_before := JSON.stringify(RealityState.data)
	_wire_up()
	_mark()
	board.reset_shutters()
	network.set_line_closed(false)
	network.set_line_closed(true)
	_check("a whole signalled round writes NOTHING to the save",
			JSON.stringify(RealityState.data) == save_before)
	# NO LIGHT, and reaches only.
	_check("the board owns no light of its own",
			board.find_children("*", "Light3D", true, false).is_empty())
	var bodies := board.find_children("*", "CollisionObject3D", true, false)
	_check("and two collision objects, both Areas that obstruct nothing",
			bodies.size() == 2 and bodies[0] is Area3D and bodies[1] is Area3D
			and not (bodies[0] is StaticBody3D))


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [register ok] ", label)
	else:
		failures += 1
		printerr("  [REGISTER FAIL] ", label)
