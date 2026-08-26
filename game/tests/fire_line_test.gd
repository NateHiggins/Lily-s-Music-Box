extends Node
## SR7-N focused proof: a hose is not water.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/FireLineTest.tscn `
##         -ProjectPath <checkout>/game
##
## The arithmetic this suite exists to hold down:
##
##     line_made_up() = gasket_seated AND coupling_made_up
##                  AND nozzle_coupled AND nozzle_shut
##
## and `hose_racked` is not in it, in the source, in the record, or in any
## reachable path. Everything else here is that one sentence, checked from a
## different side.

const CabinetScript := preload("res://scripts/props/fire_line_cabinet_prop.gd")

var passed := 0
var failed := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	_the_four_terms()
	_the_hose_is_not_a_term()
	_as_found()
	_you_cannot_certify_a_joint_you_have_not_opened()
	_the_glass_is_not_an_inspection()
	_refusals_are_different_photographs()
	_the_valve_is_not_a_verb()
	_the_fold_is_honest_work_and_makes_no_line()
	_order_is_the_iron_and_not_a_script()
	_abort()
	_it_owns_nothing_else()
	print("[FIRE LINE TEST] PASS %d/%d" % [passed, passed + failed])
	if failed > 0:
		print("[FIRE LINE TEST] FAIL %d" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("[FIRE LINE TEST] FAILED: %s" % label)


func _cabinet() -> Node:
	var cabinet: Node = CabinetScript.new()
	cabinet.name = "FireLineUnderTest"
	add_child(cabinet)
	return cabinet


func _drop(cabinet: Node) -> void:
	cabinet.queue_free()


## Work the whole chain from as-found to signed, in the one order the iron
## allows, and hand back the cabinet still standing.
func _make_the_line(cabinet: Node) -> void:
	cabinet.call("open_door")
	cabinet.call("break_joint")
	cabinet.call("seat_gasket")
	cabinet.call("make_up_coupling")
	cabinet.call("couple_nozzle")
	cabinet.call("shut_nozzle")


# --- the four terms ----------------------------------------------------------

func _the_four_terms() -> void:
	var cabinet := _cabinet()
	var terms: Array = CabinetScript.LINE_TERMS
	_check("there are exactly four line terms", terms.size() == 4)
	for term in ["gasket_seated", "coupling_made_up", "nozzle_coupled",
			"nozzle_shut"]:
		_check("%s is a line term" % term, term in terms)
	_make_the_line(cabinet)
	_check("all four true makes a line", bool(cabinet.call("line_made_up")))
	# Each term alone is enough to break it. Four independent falsifications,
	# because a conjunction claimed and not checked is a conjunction that
	# quietly became an OR.
	for term in terms:
		var before: bool = bool(cabinet.get(term))
		cabinet.set(term, false)
		_check("%s alone breaks the line" % term,
				not bool(cabinet.call("line_made_up")))
		_check("%s alone is the only fault named" % term,
				cabinet.call("line_faults") == [term])
		cabinet.set(term, before)
	_check("restoring every term restores the line",
			bool(cabinet.call("line_made_up")))
	_drop(cabinet)


func _the_hose_is_not_a_term() -> void:
	var cabinet := _cabinet()
	_check("hose_racked is not a line term",
			"hose_racked" not in CabinetScript.LINE_TERMS)
	_check("as found, the hose is present", bool(cabinet.call("hose_present")))
	_check("as found, there is no line",
			not bool(cabinet.call("line_made_up")))
	_make_the_line(cabinet)
	var with_hose: bool = bool(cabinet.call("line_made_up"))
	# Take the hose away entirely and the arithmetic does not move. This is the
	# thesis stated as an experiment rather than as a sentence.
	cabinet.set("hose_racked", false)
	_check("removing the hose does not change line_made_up",
			bool(cabinet.call("line_made_up")) == with_hose)
	_check("...and the line is still made up",
			bool(cabinet.call("line_made_up")))
	_check("but the hose is now absent",
			not bool(cabinet.call("hose_present")))
	cabinet.set("hose_racked", true)
	# And the source is checked, not merely the behaviour: the predicate must
	# not learn about the hose later.
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/fire_line_cabinet_prop.gd")
	var body := source.substr(source.find("func line_made_up"))
	body = body.substr(0, body.find("func hose_present"))
	_check("line_made_up's body never mentions the hose",
			not body.contains("hose"))
	_drop(cabinet)


func _as_found() -> void:
	var cabinet := _cabinet()
	# Three faults, one of them invisible, and a full rack in front of them.
	_check("as found: shut", not bool(cabinet.get("door_open")))
	_check("as found: hose racked", bool(cabinet.get("hose_racked")))
	_check("as found: folds set", not bool(cabinet.get("folds_fresh")))
	_check("as found: coupling made up", bool(cabinet.get("coupling_made_up")))
	_check("as found: NO GASKET", not bool(cabinet.get("gasket_seated")))
	_check("as found: nobody has looked", not bool(cabinet.get("gasket_seen")))
	_check("as found: play-pipe uncoupled",
			not bool(cabinet.get("nozzle_coupled")))
	_check("as found: its control valve open",
			not bool(cabinet.get("nozzle_shut")))
	_check("as found: tag blank",
			str(cabinet.call("tag_reads")) == CabinetScript.TAG_BLANK)
	_check("as found: exactly three of four joints wrong",
			(cabinet.call("line_faults") as Array).size() == 3)
	# The apparatus has to answer a player looking straight at it, or the
	# interaction inventory never counts it and the cabinet is scenery.
	_check("it answers a look", cabinet.has_method("interact_prompt")
			and not str(cabinet.call("interact_prompt")).is_empty())
	_check("and the look is the door",
			str(cabinet.call("interact_prompt"))
					== str(cabinet.call("control_prompt", "door")))
	_check("as found: the made-up coupling is NOT one of them",
			"coupling_made_up" not in cabinet.call("line_faults"))
	_drop(cabinet)


# --- what may be published ---------------------------------------------------

func _you_cannot_certify_a_joint_you_have_not_opened() -> void:
	var cabinet := _cabinet()
	cabinet.call("open_door")
	# Force every term true WITHOUT breaking the joint: the state a careless
	# inspection would leave, and the one thing the tag must still refuse.
	for term in CabinetScript.LINE_TERMS:
		cabinet.set(term, true)
	_check("the line reads made up", bool(cabinet.call("line_made_up")))
	_check("but nobody has seen the pocket",
			not bool(cabinet.get("gasket_seen")))
	_check("so it is not certifiable", not bool(cabinet.call("certifiable")))
	_check("and signing is refused", not bool(cabinet.call("sign_tag")))
	_check("the tag is still blank",
			str(cabinet.call("tag_reads")) == CabinetScript.TAG_BLANK)
	_check("no record was published", cabinet.call("last_record").is_empty())
	cabinet.call("break_joint")
	cabinet.call("make_up_coupling")
	_check("having looked, it is certifiable",
			bool(cabinet.call("certifiable")))
	_check("and it signs", bool(cabinet.call("sign_tag")))
	_drop(cabinet)


func _the_glass_is_not_an_inspection() -> void:
	var cabinet := _cabinet()
	# The whole line made good, and the door shut over it.
	_make_the_line(cabinet)
	cabinet.call("close_door")
	_check("shut: the line is still made up",
			bool(cabinet.call("line_made_up")))
	_check("shut: not certifiable", not bool(cabinet.call("certifiable")))
	_check("shut: signing refused", not bool(cabinet.call("sign_tag")))
	_check("shut: the tag itself is what refuses",
			str(cabinet.call("balk_focus")) == "tag")
	# And nothing inside can be worked through the glass.
	for verb in ["break_joint", "seat_gasket", "make_up_coupling",
			"couple_nozzle", "shut_nozzle", "refold_hose"]:
		_check("shut: %s refused" % verb, not bool(cabinet.call(verb)))
		_check("shut: %s blames the door" % verb,
				str(cabinet.call("balk_focus")) == "door")
	cabinet.call("open_door")
	_check("open: it signs", bool(cabinet.call("sign_tag")))
	_drop(cabinet)


func _refusals_are_different_photographs() -> void:
	var cabinet := _cabinet()
	cabinet.call("open_door")
	# The tag refuses for four different reasons and points at four different
	# pieces of iron. A refusal that always looks the same teaches nothing.
	var seen: Dictionary = {}
	cabinet.call("sign_tag")
	seen[str(cabinet.call("balk_focus"))] = true
	cabinet.call("break_joint")
	cabinet.call("sign_tag")
	seen[str(cabinet.call("balk_focus"))] = true
	cabinet.call("seat_gasket")
	cabinet.call("sign_tag")
	seen[str(cabinet.call("balk_focus"))] = true
	cabinet.call("make_up_coupling")
	cabinet.call("sign_tag")
	seen[str(cabinet.call("balk_focus"))] = true
	cabinet.call("couple_nozzle")
	cabinet.call("sign_tag")
	seen[str(cabinet.call("balk_focus"))] = true
	_check("four faults, four different refusal poses", seen.size() == 4)
	for focus in ["joint", "gasket", "nozzle", "lever"]:
		_check("a refusal aimed at the %s" % focus, seen.has(focus))
	cabinet.call("shut_nozzle")
	_check("and then it signs", bool(cabinet.call("sign_tag")))
	_check("signing twice is refused", not bool(cabinet.call("sign_tag")))
	_check("the second refusal is the tag's own",
			str(cabinet.call("balk_focus")) == "tag")
	_drop(cabinet)


func _the_valve_is_not_a_verb() -> void:
	var cabinet := _cabinet()
	_make_the_line(cabinet)
	_check("the valve refuses shut", not bool(cabinet.call("try_open_valve")))
	_check("the refusal is the wheel",
			str(cabinet.call("balk_focus")) == "valve")
	_check("it refuses with the door open too",
			not bool(cabinet.call("try_open_valve")))
	_check("a made-up line does not unlock it",
			not bool(cabinet.call("try_open_valve")))
	cabinet.call("sign_tag")
	_check("nor does a signed tag", not bool(cabinet.call("try_open_valve")))
	# There is no way in, in the source either.
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/fire_line_cabinet_prop.gd")
	for word in ["valve_open", "water_on", "flowing", "pressure_at",
			"open_the_valve"]:
		_check("no %s anywhere on the apparatus" % word,
				not source.contains(word))
	_drop(cabinet)


func _the_fold_is_honest_work_and_makes_no_line() -> void:
	var cabinet := _cabinet()
	cabinet.call("open_door")
	var before: bool = bool(cabinet.call("line_made_up"))
	var faults_before: Array = cabinet.call("line_faults")
	_check("refolding is permitted work", bool(cabinet.call("refold_hose")))
	_check("the folds are fresh", bool(cabinet.get("folds_fresh")))
	_check("and the line is exactly where it was",
			bool(cabinet.call("line_made_up")) == before)
	_check("and not one fault was cured",
			cabinet.call("line_faults") == faults_before)
	_check("refolding twice is refused", not bool(cabinet.call("refold_hose")))
	_check("that refusal is the folds",
			str(cabinet.call("balk_focus")) == "folds")
	# Nor does a fresh fold buy a signature.
	_check("fresh folds do not certify",
			not bool(cabinet.call("certifiable")))
	_check("fresh folds do not sign", not bool(cabinet.call("sign_tag")))
	_drop(cabinet)


func _order_is_the_iron_and_not_a_script() -> void:
	var cabinet := _cabinet()
	cabinet.call("open_door")
	# The one ordering rule, and it is mechanical: you cannot reach a pocket
	# through a made-up joint.
	_check("gasket refused through a made-up joint",
			not bool(cabinet.call("seat_gasket")))
	_check("the refusal is the gasket",
			str(cabinet.call("balk_focus")) == "gasket")
	_check("break the joint first", bool(cabinet.call("break_joint")))
	_check("now the gasket goes in", bool(cabinet.call("seat_gasket")))
	# Everything else is free order: nozzle work before or after the joint.
	var other := _cabinet()
	other.call("open_door")
	_check("free order: nozzle first", bool(other.call("couple_nozzle")))
	_check("free order: lever next", bool(other.call("shut_nozzle")))
	_check("free order: joint last", bool(other.call("break_joint")))
	_check("free order: gasket", bool(other.call("seat_gasket")))
	_check("free order: made up", bool(other.call("make_up_coupling")))
	_check("free order signs the same tag", bool(other.call("sign_tag")))
	_check("and the same record",
			bool(other.call("last_record").get("line_made_up", false)))
	# And a coupling WILL go up over an empty pocket, because that is exactly
	# how this one was found. A refusal here would hide the fault it teaches.
	var third := _cabinet()
	third.call("open_door")
	third.call("break_joint")
	_check("the joint goes up with no gasket in it",
			bool(third.call("make_up_coupling")))
	_check("and it is not a line",
			not bool(third.call("line_made_up")))
	_drop(cabinet)
	_drop(other)
	_drop(third)


func _abort() -> void:
	var cabinet := _cabinet()
	var found: Dictionary = cabinet.call("maintenance_snapshot")
	_make_the_line(cabinet)
	cabinet.call("refold_hose")
	var published: Array = []
	var sink := func(record: Dictionary) -> void:
		published.append(record)
	cabinet.connect("line_inspected", sink)
	_check("the tag signs", bool(cabinet.call("sign_tag")))
	_check("one fact was published", published.size() == 1)
	cabinet.call("restore_maintenance_snapshot", found)
	for key in found.keys():
		_check("abort restores %s" % key,
				cabinet.get(key) == found[key])
	_check("abort puts the fault back",
			not bool(cabinet.call("line_made_up")))
	_check("abort re-blinds the joint", not bool(cabinet.get("gasket_seen")))
	_check("abort clears the balk", not bool(cabinet.call("balking")))
	_check("abort cannot retract what was published",
			published.size() == 1)
	_check("the snapshot names every owned fact", found.size() == 10)
	_drop(cabinet)


# --- it owns nothing else ----------------------------------------------------

func _it_owns_nothing_else() -> void:
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/fire_line_cabinet_prop.gd")
	# No lifecycle, no case, no save, no route, no checklist. This apparatus is
	# a cabinet on a wall and it stays one.
	for owner_name in ["WorkOrders", "RealityCases", "RealityState",
			"MaintenanceInventory", "FirstShiftDirector", "CoreLoopDirector",
			"ObjectiveTracker", "ScheduleDirector", "SwitchSystem",
			"WatchStationNetwork", "issue_job", "close_job", "acknowledge_job",
			"activate_case", "leaf_state", "dream"]:
		_check("the cabinet never reaches %s" % owner_name,
				not source.contains(owner_name))
	for word in ["required", "must_visit", "checklist", "objective",
			"completion", "quest", "waypoint", "onboarding"]:
		_check("the cabinet declares no %s" % word, not source.contains(word))
	# The record says what it knows and no more.
	var cabinet := _cabinet()
	_make_the_line(cabinet)
	cabinet.call("sign_tag")
	var record: Dictionary = cabinet.call("last_record")
	_check("the record has exactly the authored fields",
			record.keys().size() == CabinetScript.RECORD_FIELDS.size())
	for field in CabinetScript.RECORD_FIELDS:
		_check("the record carries %s" % field, record.has(field))
	for absent in ["who", "by", "watchman", "case_id", "job_id", "order_id",
			"route", "complete", "pressure", "water", "gallons"]:
		_check("the record does not claim %s" % absent, not record.has(absent))
	# It writes down that the hose was there, and that the hose was not the
	# reason. Both halves in one line of a record.
	_check("the record records the hose", bool(record.get("hose_racked")))
	_check("the record records the line", bool(record.get("line_made_up")))
	_drop(cabinet)
