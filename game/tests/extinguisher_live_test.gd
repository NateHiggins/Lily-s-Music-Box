extends Node
## SR7-O — the extinguisher on the board the building already drew.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/ExtinguisherLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## What only production can settle:
##
##   * that this hangs on ONE authored instance of the batched backboard, at
##     its measured face and edge, on the real F03 landing, clear of the real
##     stair doorway and of the real circulation lane;
##   * that the whole inspection works on the production instance, and that the
##     seal, the charge and the correct weight buy none of it;
##   * that SR7-N's fire-line cabinet is a CONTROL and not a foundation: its
##     every owned fact is byte-for-byte what it was and it published nothing;
##   * that nothing else in the building moves at all.

const ExtinguisherScript := preload(
		"res://scripts/props/soda_acid_extinguisher_prop.gd")

var failures := 0
var checks := 0

## Measured off `orison_detail_pass.gd`'s infrastructure loop. The batched red
## box is 0.34 wide by 0.08 deep by 0.70 tall, centred at (-2.76, -3.10) and
## running z+0.70 to z+1.40 on every floor.
const BOARD_X := -2.76
const BOARD_CENTRE_Y := -3.10
const BOARD_DEPTH := 0.08
const BOARD_BOTTOM := 0.70
const BOARD_TOP := 1.40
const BOARD_HALF_WIDTH := 0.17
## The stair core's landing and its doorway, from `building_layout.json`.
const LANDING := Rect2(-3.16, -3.16, 6.32, 1.70)
const DOORWAY_WEST_JAMB := -1.60
## F03's core pendant, the closest any floor's core light comes to this board.
const F03_PENDANT := Vector3(-0.55, -0.88, 7.79)
## SR7-N, six floors down and on the other wall. Touched by nothing here.
const FIRE_LINE := Vector2(3.16, -2.48)

var root: Node
var unit: Node
var fire_line: Node


func _ready() -> void:
	RealityState.persistence_enabled = false
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	unit = root.find_child("F03_EXTINGUISHER_STAIR", true, false)
	_check(unit != null, "production owns a soda-acid extinguisher")
	if unit == null:
		_finish()
		return

	# --- bound to the authored board ----------------------------------------
	var at: Vector3 = (unit as Node3D).global_position
	var by := -at.z
	print("[EXT LIVE] extinguisher b(%.3f, %.3f, %.3f)" % [at.x, by, at.y])
	_check(absf(at.x - BOARD_X) < 0.005,
			"on the board's own centre line, x %.3f" % at.x)
	_check(absf(by - (BOARD_CENTRE_Y + BOARD_DEPTH * 0.5)) < 0.005,
			"at the board's FRONT FACE, y %.3f" % by)
	_check(absf(at.y - (6.4 + BOARD_BOTTOM)) < 0.005,
			"at the board's bottom edge, z %.3f above F03's floor"
					% (at.y - 6.4))
	_check(at.y + 0.80 < 6.4 + BOARD_TOP + 0.12,
			"and the vessel's cap clears the board's top by a cap's height")

	# --- it is a place a man can stand, and it blocks nothing ----------------
	_check(by > LANDING.position.y and by < LANDING.position.y + LANDING.size.y,
			"over the solid south landing of the stair well")
	_check(at.x + BOARD_HALF_WIDTH < DOORWAY_WEST_JAMB,
			"%.3f m clear of the stair doorway's west jamb"
					% (DOORWAY_WEST_JAMB - (at.x + BOARD_HALF_WIDTH)))
	# The vessel is 0.226 across and stands 0.248 proud of the board's face.
	var front := by + 0.248
	_check(front < LANDING.position.y + LANDING.size.y - 1.20,
			"it projects to y %.3f, leaving %.2f m of landing in front of it"
					% [front, LANDING.position.y + LANDING.size.y - front])
	_check(absf(at.y - 6.4) < 1.5 and at.y > 6.4,
			"and it is F03's instance of the board, not another floor's")
	_check(Vector3(at.x, at.y, by).distance_to(
			Vector3(F03_PENDANT.x, F03_PENDANT.z, F03_PENDANT.y)) < 3.6,
			"%.2f m from F03's core pendant, the closest of any floor"
					% Vector3(at.x, at.y, by).distance_to(
							Vector3(F03_PENDANT.x, F03_PENDANT.z,
									F03_PENDANT.y)))
	_check(unit.get_parent() != null
			and str(unit.get_parent().name).begins_with("F03"),
			"a child of F03, placed from the detail pass")

	# --- it costs the frame nothing -----------------------------------------
	var lights := 0
	var bodies := 0
	var areas := 0
	for node in (unit as Node3D).find_children("*", "", true, false):
		if node is Light3D:
			lights += 1
		elif node is StaticBody3D or node is RigidBody3D \
				or node is CharacterBody3D:
			bodies += 1
		elif node is Area3D:
			areas += 1
	_check(lights == 0, "it adds NO realtime light (%d)" % lights)
	_check(bodies == 0, "it adds NO collision body (%d)" % bodies)
	_check(areas == 7, "seven reach areas, which stop nothing (%d)" % areas)

	# --- SR7-N is a control, and this is its baseline -----------------------
	fire_line = root.find_child("F01_FIRE_LINE_STAIR", true, false)
	_check(fire_line != null, "SR7-N's fire-line cabinet is still standing")
	var line_before := ""
	var line_published: Array = []
	if fire_line != null:
		line_before = JSON.stringify(fire_line.call("maintenance_snapshot"))
		var line_sink := func(_record: Dictionary) -> void:
			line_published.append(1)
		fire_line.connect("line_inspected", line_sink)
		var line_at: Vector3 = (fire_line as Node3D).global_position
		_check(absf(line_at.x - FIRE_LINE.x) < 0.02
				and absf(-line_at.z - FIRE_LINE.y) < 0.02,
				"on F01's east wall where SR7-N put it, untouched")
		_check(absf(line_at.y - at.y) > 5.0,
				"%.2f m below this apparatus: two lanes, not one"
						% absf(at.y - line_at.y))

	# --- the baseline nothing else may move ---------------------------------
	var save_before := JSON.stringify(RealityState.data)
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
	var work_orders: Node = root.get("work_orders")
	_check(work_orders != null, "the production job spine is in the tree")
	var open_work_before := false
	var jobs_before := ""
	if work_orders != null:
		work_orders.connect("order_issued", order_sink)
		work_orders.connect("order_activated", order_sink)
		work_orders.connect("order_closed", order_sink)
		work_orders.connect("job_issued", job_sink)
		work_orders.connect("job_stage_changed", stage_sink)
		open_work_before = bool(work_orders.call("has_open_work"))
		jobs_before = JSON.stringify(work_orders.call("serialize_jobs"))
	RealityCases.case_changed.connect(case_sink)
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
	var marks_before: int = int(net.call("mark_count")) if net != null else -1
	var key_before: bool = bool(guard.call("key_carried")) if guard != null \
			else false
	var register: Node = root.find_child("F01_NIGHT_REGISTER", true, false)
	var register_before := JSON.stringify(register.call(
			"maintenance_snapshot")) if register != null else ""

	# --- as found, on the production instance -------------------------------
	var found: Dictionary = unit.call("maintenance_snapshot")
	_check(bool(unit.call("sealed")), "found SEALED")
	_check(bool(unit.call("charged")), "found CHARGED")
	_check(not bool(unit.call("will_lift")), "found with a cap that will not lift")
	_check(not bool(unit.call("usable")), "and therefore NOT USABLE")
	_check(float(unit.call("heft")) == ExtinguisherScript.GROSS_POUNDS,
			"and hefting it gives the full %.0f lb"
					% ExtinguisherScript.GROSS_POUNDS)

	# --- appearance buys nothing --------------------------------------------
	_check(not bool(unit.call("sign_tag")),
			"a sealed, charged, correctly heavy extinguisher will not certify")
	_check(not bool(unit.call("unscrew_cap")),
			"and the cap will not turn under its wire")
	_check(not bool(unit.call("invert")), "and it will not be turned over")

	# --- the inspection, by hand --------------------------------------------
	_check(bool(unit.call("cut_seal")), "the lead-and-wire seal cuts")
	_check(bool(unit.call("unscrew_cap")), "the cap comes off with its cage")
	_check(bool(unit.call("draw_bottle")), "the bottle draws out of the clips")
	_check(not bool(unit.call("try_loose_cap")),
			"THE BOTTLE COMES UP WITH ITS CAP -- the whole diagnosis")
	_check(str(unit.call("balk_focus")) == "loose",
			"and the refusal is aimed at that cap")
	_check(bool(unit.get("cap_tested")), "a hand has now been on it")
	_check(bool(unit.call("free_loose_cap")), "it works free")
	_check(bool(unit.call("will_lift")), "now the cap will lift")
	_check(not bool(unit.call("usable")),
			"still not usable: the bottle is out on the shelf")
	_check(bool(unit.call("seat_bottle")), "the bottle goes back in its clips")
	_check(bool(unit.call("screw_cap")), "the cap goes down")
	_check(bool(unit.call("wire_seal")), "a fresh seal goes through the lugs")
	_check(bool(unit.call("usable")), "NOW it is an extinguisher")
	var published: Array = []
	var sink := func(record: Dictionary) -> void:
		published.append(record)
	unit.connect("extinguisher_inspected", sink)
	_check(bool(unit.call("sign_tag")), "and the tag signs")
	_check(published.size() == 1, "one neutral fact was published")
	_check(bool(published[0].get("sealed"))
			and bool(published[0].get("charged"))
			and bool(published[0].get("usable")),
			"the record says sealed AND charged AND usable, all three")
	_check(float(published[0].get("gross_pounds", 0.0))
			== ExtinguisherScript.GROSS_POUNDS,
			"and carries the same gross it carried when it was dead")
	_check(not bool(unit.call("invert")),
			"a signed tag still does not license turning it over")

	# --- SR7-N never moved ---------------------------------------------------
	if fire_line != null:
		_check(JSON.stringify(fire_line.call("maintenance_snapshot"))
						== line_before,
				"SR7-N's cabinet is BYTE-FOR-BYTE what it was")
		_check(line_published.is_empty(),
				"SR7-N published nothing (%d)" % line_published.size())
		_check(fire_line.call("last_record").is_empty(),
				"and its record is still empty")
		_check(not bool(fire_line.call("line_made_up")),
				"and its line is still not made up")

	# --- nothing else in the building moved ---------------------------------
	_check(order_events.is_empty() and job_events.is_empty(),
			"NO work order was issued, activated, advanced or closed (%s)"
					% ", ".join(order_events + job_events))
	if work_orders != null:
		_check(JSON.stringify(work_orders.call("serialize_jobs")) == jobs_before,
				"the live job spine is byte-for-byte what it was")
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
	if net != null:
		_check(int(net.call("mark_count")) == marks_before,
				"the watch line recorded nothing (%d)" % marks_before)
		_check(str(unit.get("station_id")) not in net.call("station_ids"),
				"and the extinguisher is not on it")
	if guard != null:
		_check(bool(guard.call("key_carried")) == key_before,
				"the tour key never left its hook")
	if register != null:
		_check(JSON.stringify(register.call("maintenance_snapshot"))
						== register_before,
				"the night register is byte-for-byte what it was")

	# --- abort ---------------------------------------------------------------
	unit.call("restore_maintenance_snapshot", found)
	for key in found.keys():
		_check(unit.get(key) == found[key],
				"abort restores %s on the production unit" % key)
	_check(not bool(unit.call("usable")), "abort puts the whole fault back")
	_check(bool(unit.call("sealed")) and bool(unit.call("charged")),
			"and puts back the appearance that hid it")
	_check(published.size() == 1,
			"and cannot retract the fact already published")
	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [ext live ok] ", label)
	else:
		failures += 1
		printerr("  [EXT LIVE FAIL] ", label)


func _finish() -> void:
	print("EXTINGUISHER LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
