extends Node
## SR7-N — the hose station on the real riser, in the real stair core.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/FireLineLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## What only production can settle:
##
##   * that the cabinet hangs on the riser this building already draws, at the
##     coupling it already draws, at a rack height the code would accept above
##     the real landing, on a real wall with no opening behind it;
##   * that the whole chain works on the production instance, and that the full
##     rack of hose behind real wired glass buys none of it;
##   * that nothing else in the building moves -- no work order, no case, no
##     save key, no door leaf, no lamp, no watch station, no tour key;
##   * that it is optional in the only sense that matters: everything the
##     opening round needs is exactly as reachable with this cabinet never
##     touched.

const CabinetScript := preload("res://scripts/props/fire_line_cabinet_prop.gd")

var failures := 0
var checks := 0

## Measured from `orison_detail_pass.gd` and `building_layout.json`.
## The riser the building already batches, on every floor, beside the stair
## core -- and the coupling on it that this apparatus takes off from.
const RISER := Vector2(3.02, -3.02)
const RISER_RADIUS := 0.055
const RISER_COUPLING_Z := 1.55
## The stair core's east wall is at x 3.25, 0.18 thick, so its inner face is
## 3.16. Its two window openings start at y -1.45.
const EAST_WALL_FACE := 3.16
const FIRST_WINDOW_Y := -1.45
## Every floor carries a solid landing across the south strip of the well.
const LANDING := Rect2(-3.16, -3.16, 6.32, 1.70)
## C26-1403.0: five to six and one-half feet above the landing.
const RACK_MIN := 1.524
const RACK_MAX := 1.981
## The batched south-face infrastructure this cabinet had to keep clear of.
const PANEL_SPAN := Vector2(2.52, 2.94)

var root: Node
var cabinet: Node


func _ready() -> void:
	RealityState.persistence_enabled = false
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	cabinet = root.find_child("F01_FIRE_LINE_STAIR", true, false)
	_check(cabinet != null, "production owns a standpipe hose station")
	if cabinet == null:
		_finish()
		return

	# --- where it hangs, and whether it is honest ---------------------------
	var at: Vector3 = (cabinet as Node3D).global_position
	var by := -at.z
	print("[FIRE LIVE] cabinet b(%.2f, %.2f, %.2f)" % [at.x, by, at.y])
	_check(absf(at.x - EAST_WALL_FACE) < 0.02,
			"on the stair core's east wall face (x %.3f)" % at.x)
	_check(by > LANDING.position.y and by < LANDING.position.y + LANDING.size.y,
			"over the solid south landing, not over the open well (y %.2f)"
					% by)
	_check(by < FIRST_WINDOW_Y - 0.30,
			"clear of the east wall's first window opening")
	var rack_h: float = at.y + CabinetScript.RACK_LOCAL_Y
	_check(rack_h > RACK_MIN and rack_h < RACK_MAX,
			"the rack sits %.3f m up: inside C26-1403.0's five-to-six-and-a-"
					% rack_h + "half-foot band")
	# It takes off from the riser the building already had. The take-off boss
	# is drawn at local (0.540, 0.350, 0.098); in building terms that is:
	var boss := Vector2(at.x - 0.098, by - 0.540)
	var boss_h := at.y + 0.350
	print("[FIRE LIVE] take-off b(%.3f, %.3f, %.3f)"
			% [boss.x, boss.y, boss_h])
	_check(boss.distance_to(RISER) < RISER_RADIUS,
			"the take-off is INSIDE the drawn riser (%.3f m from its axis, "
					% boss.distance_to(RISER) + "radius %.3f)" % RISER_RADIUS)
	_check(absf(boss_h - RISER_COUPLING_Z) < 0.01,
			"and level with the riser's own brass coupling at z+1.55")
	# And it stays off the batched south face, which was already full: the
	# electrical panel runs x 2.52..2.94 on y -3.10 and the riser is jammed
	# into the corner behind it. The cabinet is 0.62 wide, so its south cheek
	# stands at y -2.93 -- 0.23 clear of the south wall face, and its whole
	# footprint is north of everything that run occupies.
	_check(by - 0.31 > -3.16,
			"its south cheek clears the south wall face by %.3f m"
					% (by - 0.31 + 3.16))
	# And the branch can actually be seen crossing: the gap between the
	# cabinet's south cheek and the riser's west face is the whole reason the
	# cabinet is at -2.48 and not tucked against the corner.
	var gap := absf(by - 0.31 - (RISER.y + RISER_RADIUS))
	_check(gap > 0.12,
			"%.3f m of the branch runs in the open between riser and cabinet"
					% gap)
	_check(at.x - 0.22 > PANEL_SPAN.y - 0.001,
			"and its front face at x %.2f stands proud of the batched panel "
					% (at.x - 0.22) + "run, on a different wall entirely")
	_check(cabinet.get_parent() != null
			and str(cabinet.get_parent().name).begins_with("F01"),
			"and it is a child of F01, placed from the detail pass")

	# --- the baseline nothing may move --------------------------------------
	var save_before := JSON.stringify(RealityState.data)
	var jobs_before := JSON.stringify(
			RealityState.data.get("maintenance_jobs", {}))
	var cases_before := JSON.stringify(RealityState.data.get("cases", {}))
	var order_events: Array[String] = []
	var job_events: Array[String] = []
	var case_events: Array[String] = []
	var order_sink := func(id: String, _o: Dictionary) -> void:
		order_events.append(str(id))
	var job_sink := func(id: String, _s: Dictionary) -> void:
		job_events.append(str(id))
	var stage_sink := func(id: String, _f: String, _t: String) -> void:
		job_events.append(str(id))
	var case_sink := func(id: String, _s: Dictionary) -> void:
		case_events.append(str(id))
	# The production job spine, which is a node on the building root and not
	# an autoload: the only WorkOrders there is.
	var work_orders: Node = root.get("work_orders")
	_check(work_orders != null, "the production job spine is in the tree")
	if work_orders != null:
		work_orders.connect("order_issued", order_sink)
		work_orders.connect("order_activated", order_sink)
		work_orders.connect("order_closed", order_sink)
		work_orders.connect("job_issued", job_sink)
		work_orders.connect("job_stage_changed", stage_sink)
	RealityCases.case_changed.connect(case_sink)
	var open_work_before: bool = bool(work_orders.call("has_open_work")) \
			if work_orders != null else false
	var serialized_before: Dictionary = work_orders.call("serialize_jobs") \
			if work_orders != null else {}
	var jobs_count_before: int = serialized_before.size()
	var doors_before: Dictionary = {}
	for leaf in root.find_children("*_DOOR_*", "", true, false):
		if leaf.get("leaf_state") != null:
			doors_before[str(leaf.name)] = str(leaf.get("leaf_state"))
	_check(doors_before.size() > 40,
			"%d real door leaves are watched" % doors_before.size())
	var powered_before := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_before += 1
	var net: Node = root.find_child("WatchStationNetwork", true, false)
	var guard: Node = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	var marks_before: int = int(net.call("mark_count")) if net != null \
			and net.has_method("mark_count") else -1
	var key_before: bool = bool(guard.call("key_carried")) if guard != null \
			else false

	# --- the found state, on the production instance ------------------------
	var found: Dictionary = cabinet.call("maintenance_snapshot")
	_check(not bool(cabinet.get("door_open")), "found shut")
	_check(bool(cabinet.call("hose_present")),
			"found with fifty feet of linen on the rack")
	_check(not bool(cabinet.call("line_made_up")),
			"and found with no line")
	_check((cabinet.call("line_faults") as Array).size() == 3,
			"three of the four joints are wrong")

	# --- the glass is not an inspection -------------------------------------
	_check(not bool(cabinet.call("sign_tag")),
			"a shut cabinet cannot be certified")
	for verb in ["break_joint", "seat_gasket", "couple_nozzle", "shut_nozzle",
			"refold_hose"]:
		_check(not bool(cabinet.call(verb)),
				"%s refuses through the wired glass" % verb)

	# --- the chain, on the real cabinet -------------------------------------
	_check(bool(cabinet.call("open_door")), "the door swings")
	_check(not bool(cabinet.call("seat_gasket")),
			"the pocket cannot be reached through a made-up joint")
	_check(bool(cabinet.call("refold_hose")),
			"the linen can be re-racked on a different fold")
	_check(not bool(cabinet.call("line_made_up")),
			"and a fresh fold makes no line at all")
	_check(not bool(cabinet.call("sign_tag")),
			"nor does it buy a signature")
	_check(bool(cabinet.call("break_joint")), "the joint breaks")
	_check(bool(cabinet.get("gasket_seen")), "and the pocket is seen: empty")
	_check(bool(cabinet.call("seat_gasket")), "the gasket goes in")
	_check(bool(cabinet.call("make_up_coupling")), "the joint goes back up")
	_check(not bool(cabinet.call("line_made_up")),
			"still no line: the far end is open")
	_check(bool(cabinet.call("couple_nozzle")), "the play-pipe couples")
	_check(bool(cabinet.call("shut_nozzle")), "its control valve shuts")
	_check(bool(cabinet.call("line_made_up")), "NOW there is a line")
	var published: Array = []
	var line_sink := func(record: Dictionary) -> void:
		published.append(record)
	cabinet.connect("line_inspected", line_sink)
	_check(bool(cabinet.call("sign_tag")), "and the tag signs")
	_check(published.size() == 1, "one neutral fact was published")
	_check(bool(published[0].get("hose_racked"))
			and bool(published[0].get("line_made_up")),
			"the record says the hose was there AND that the line is made")

	# --- the valve is not a verb --------------------------------------------
	_check(not bool(cabinet.call("try_open_valve")),
			"the outlet valve refuses, with the line made and the tag signed")

	# --- nothing else in the building moved ---------------------------------
	_check(order_events.is_empty() and job_events.is_empty(),
			"NO work order was issued, activated, advanced or closed (%s)"
					% ", ".join(order_events + job_events))
	_check(JSON.stringify(RealityState.data.get("maintenance_jobs", {}))
					== jobs_before,
			"the job book in the save is byte-for-byte what it was")
	if work_orders != null:
		var serialized_after: Dictionary = work_orders.call("serialize_jobs")
		_check(JSON.stringify(serialized_after)
						== JSON.stringify(serialized_before),
				"the live job spine is byte-for-byte what it was (%d jobs)"
						% jobs_count_before)
		_check(bool(work_orders.call("has_open_work")) == open_work_before,
				"has_open_work() is unchanged, so nothing here became work")
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
	_check(save_moved.is_empty(),
			"NOT ONE save key moved (%s)" % ", ".join(save_moved))
	var doors_moved: Array[String] = []
	for leaf in root.find_children("*_DOOR_*", "", true, false):
		if leaf.get("leaf_state") != null \
				and doors_before.get(str(leaf.name), "") \
						!= str(leaf.get("leaf_state")):
			doors_moved.append(str(leaf.name))
	_check(doors_moved.is_empty(),
			"not one door leaf moved (%s)" % ", ".join(doors_moved))
	var powered_after := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_after += 1
	_check(powered_after == powered_before,
			"not one lamp changed power (%d)" % powered_before)

	# --- and it is not on the watch round -----------------------------------
	_check(net != null, "the watch line is still in the building")
	if net != null:
		var marks_after: int = int(net.call("mark_count")) \
				if net.has_method("mark_count") else -1
		_check(marks_after == marks_before,
				"the watch line recorded nothing (%d)" % marks_after)
		var carried: Array = net.call("station_ids")
		_check(str(cabinet.get("station_id")) not in carried,
				"the hose cabinet is not on the watch line (%s)"
						% ", ".join(PackedStringArray(carried)))
		_check(carried.size() == 2,
				"which still carries exactly the two authored boxes")
	if guard != null:
		_check(bool(guard.call("key_carried")) == key_before,
				"the tour key never left its hook for this")
	_check(root.find_child("F01_NIGHT_REGISTER", true, false) != null,
			"the night register is untouched and still standing")

	# --- abort ---------------------------------------------------------------
	cabinet.call("restore_maintenance_snapshot", found)
	for key in found.keys():
		_check(cabinet.get(key) == found[key],
				"abort restores %s on the production cabinet" % key)
	_check(not bool(cabinet.call("line_made_up")),
			"abort puts the whole fault back")
	_check(published.size() == 1,
			"and cannot retract the fact already published")
	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [fire live ok] ", label)
	else:
		failures += 1
		printerr("  [FIRE LIVE FAIL] ", label)


func _finish() -> void:
	print("FIRE LINE LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
