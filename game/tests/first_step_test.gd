extends Node
## K2-C — one immediate verb, on a bench.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/FirstStepTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE AMBIGUITY THIS ANSWERS, MEASURED BEFORE A LINE WAS WRITTEN. At the
## acceptance pose — b(4.84, -2.27, 1.62), facing the spindle the paper just
## came off — the card read:
##
##     "Follow the chirp to the 2A point and open the grille. Before you leave
##      the lobby, take the TOUR KEY from its hook. It opens no door. On the
##      way, work STATION 2 if you see it. The mark is evidence, not
##      permission."
##
## Three imperatives, and NOT ONE OF THE THINGS THEY NAME WAS IN THE FRAME: the
## tour key at yaw -60.9 degrees, the detector at +62.5, STATION 2 at -175.3 and
## a floor up, the stair at +154.9 and occluded.
##
## Worse, the LEADING verb asked for a sense the building cannot deliver from
## there. The fault fires on a 50-to-95-second random timer from an emitter
## whose `max_distance` is 16 m, a storey up through a slab, into a lobby where
## **141 emitters are already playing**. "Find it by ear" is a good instruction
## beside the grille and a poor one at the desk.
##
## So the card leads with WHERE, which a hand can act on immediately, and the
## two optional clauses drop into the indicative so they stop reading as a
## checklist. The unit and its floor are read off `WorkOrders`' own job spec —
## this is presentation of somebody else's fact, not a second copy of it.

const DirectorScript := preload("res://scripts/game/first_shift_director.gd")
const DIRECTOR_PATH := "res://scripts/game/first_shift_director.gd"

var failures := 0
var checks := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	await get_tree().process_frame
	_the_first_step_is_where()
	_the_texture_is_not_a_checklist()
	_no_waypoint_vocabulary()
	_source_discipline()
	_finish()


func _bench() -> Node:
	var director: Node = DirectorScript.new()
	add_child(director)
	return director


# --- the verb ----------------------------------------------------------------

func _the_first_step_is_where() -> void:
	var director := _bench()
	# Read off the spec, so it is the JOB's fact and works for any job.
	for row in [["2A", "one floor up"], ["3B", "2 floors up"],
			["6C", "5 floors up"], ["1D", "on this floor"]]:
		var step := str(director.call("_first_step", {"unit": row[0]}))
		_check(step.begins_with("Unit %s," % row[0]),
				"unit %s leads the card: \"%s\"" % [row[0], step.strip_edges()])
		_check(step.contains(str(row[1])),
				"and says %s" % row[1])
	# It degrades safely rather than inventing a floor.
	_check(str(director.call("_first_step", {})) == "",
			"a job with no unit gets no first step rather than a guess")
	_check(str(director.call("_first_step", {"unit": "PENTHOUSE"}))
			.contains("on this floor"),
			"and a unit whose name is not a number is not parsed into one")
	director.queue_free()


func _the_texture_is_not_a_checklist() -> void:
	var director := _bench()
	var texture := str(director.call("_round_texture"))
	_check(texture.contains("TOUR KEY") and texture.contains("STATION 2"),
			"the round's texture still names both, so neither is hidden")
	# THE POINT: both are stated in the INDICATIVE. An imperative is an order.
	for imperative in ["Take the", "take the TOUR KEY", "work STATION",
			"Before you leave", "you must", "you should", "go and"]:
		_check(not texture.contains(imperative),
				"and neither is ordered: no \"%s\"" % imperative)
	_check(texture.contains("hangs") and texture.contains("is on the way"),
			"they are things that EXIST and are on the way")
	_check(texture.contains("never permission"),
			"and the mark is still explicitly not permission")
	# Carrying the key retires its clause and leaves the station's alone.
	director.set("_tour_key_carried", true)
	var carried := str(director.call("_round_texture"))
	_check(not carried.contains("TOUR KEY"),
			"a key already in the pocket is not mentioned again")
	_check(carried.contains("STATION 2"),
			"but the optional station is still offered")
	director.queue_free()


func _no_waypoint_vocabulary() -> void:
	var director := _bench()
	var whole := str(director.call("_first_step", {"unit": "2A"})) \
			+ str(director.call("_round_texture"))
	for banned in ["marker", "waypoint", "arrow", "compass", "minimap",
			"highlight", "objective marker", "press ", "hold ", "[e]", "hud"]:
		_check(not whole.to_lower().contains(banned),
				"the card never says `%s`" % banned)
	_check(not whole.contains("→") and not whole.contains("↑"),
			"and draws nothing: this is a sentence, not a pointer")
	director.queue_free()


# --- source discipline -------------------------------------------------------

func _source_discipline() -> void:
	var text := FileAccess.get_file_as_string(DIRECTOR_PATH)
	var start := text.find("func _first_step")
	var stop := text.find("func clock_in")
	_check(start > 0, "the first step is its own small function")
	var body := text.substr(start, maxi(0, stop - start)).to_lower() \
			if stop > start else text.substr(start).to_lower()
	# It must compose a sentence and nothing else. No lifecycle, no persistence,
	# no route, no second owner.
	for word in ["realitystate", "commit(", "activate_case", "acknowledge_job",
			"job_stage", "realitycases", "workorders.", "global_position",
			"randf", "randi", "set_meta", "add_child"]:
		_check(not body.contains(word),
				"and it never touches `%s`" % word)
	# The whole increment adds no state at all.
	_check(not RealityState.data.has("first_step")
			and not RealityState.data.has("route_hint"),
			"K2-C wrote no save key of its own")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [first step ok] ", label)
	else:
		failures += 1
		printerr("  [FIRST STEP FAIL] ", label)


func _finish() -> void:
	print("FIRST STEP TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
