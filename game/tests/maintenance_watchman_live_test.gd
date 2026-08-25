extends Node
## SR7-F — the detector hangs in the real lobby and moves nothing around it.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/MaintenanceWatchmanLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## The audit that preceded SR7-F found NO watchman, patrol, guard, key station
## or security round anywhere in the game — only planning prose and a dead
## `route` key in `resident_schedules.json` that `schedule_director.gd` never
## reads. So the apparatus is new, and the whole risk is that it disturbs one
## of the systems it stands among.
##
## This file proves four things:
##   * it hangs on the real F01 east wall in the clear run north of the
##     dumbwaiter and south of the 1D door;
##   * it READS the house clock and agrees with the owner the sky uses;
##   * it is not one of the building's two clocks and does not join their
##     census, their marker network or their work order;
##   * servicing it moves no schedule, no switch, no light, no job and no
##     vantry point.

var failures := 0
var checks := 0

## The clear run this apparatus was placed into, in building coordinates.
## The east wall's service end is full -- mail bank, post tray, chute, porter
## board and dumbwaiter run from y -8.56 to -4.48 -- and its two door openings
## are at -3.77..-2.86 and -0.13..0.78. That leaves exactly one stretch of
## unbroken panelling on this wall, and the case is in the middle of it.
const WALL_X := 5.24
const DETECTOR_Y := -1.50
const CASE_HALF_WIDTH := 0.17
const DOOR_1D_NORTH_EDGE := -2.86
const DOOR_1C_SOUTH_EDGE := -0.13
const DUMBWAITER_NORTH_EDGE := -4.48


func _ready() -> void:
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var root: Node = scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var det: Node = root.find_child("F01_WATCHMAN_DETECTOR", true, false)
	_check(det != null, "the production lobby owns a watchman's detector")
	if det == null:
		_finish()
		return

	# --- it hangs in the clear run ------------------------------------------
	var at: Vector3 = (det as Node3D).global_position
	var bx := at.x
	var by := -at.z
	print("[WATCHMAN LIVE] global b(%.2f, %.2f, %.2f)" % [bx, by, at.y])
	_check(absf(bx - WALL_X) < 0.02,
			"it is on the lobby east wall face (b x %.2f)" % bx)
	_check(absf(by - DETECTOR_Y) < 0.02,
			"at the authored station (b y %.2f)" % by)
	_check(by - CASE_HALF_WIDTH > DOOR_1D_NORTH_EDGE
			and by + CASE_HALF_WIDTH < DOOR_1C_SOUTH_EDGE,
			"the whole case is inside the run between the two entry doors")
	_check(by - CASE_HALF_WIDTH - DUMBWAITER_NORTH_EDGE > 1.0,
			"and well clear of the packed service end of the wall (%.2f m)"
				% (by - CASE_HALF_WIDTH - DUMBWAITER_NORTH_EDGE))
	# It hangs ABOVE the lobby dado: `build_orison.py` caps the panelling at
	# 1.32 and its bullnose bead stands proud of the plaster, so a case hung
	# lower has the chair rail running through its glass.
	_check(at.y > 1.40 and at.y < 1.80,
			"hung clear above the dado cap at a reading height (b z %.2f)"
					% at.y)
	_check(at.y > 1.395,
			"the bottom of the case clears the 1.355 bullnose bead")
	_check(det.get_parent() != null
			and str(det.get_parent().name).contains("F01"),
			"parented to F01, the lobby the player starts in")
	_check(str(det.name).begins_with("F01_"),
			"named to the floor-prefix convention the presentation audit uses")
	var facing: Vector3 = (det as Node3D).global_transform.basis.z.normalized()
	_check(facing.x < -0.9,
			"its face is turned into the lobby (z -> %.2f)" % facing.x)

	# WHAT LIGHTS IT. The apparatus owns no lamp, so the sheet it is
	# photographed on has to be lit by fixtures the lobby already had. This
	# prints them rather than asserting a count: the lighting is production's
	# and may legitimately change.
	var near: Array[String] = []
	for light in root.find_children("*", "Light3D", true, false):
		var l := light as Light3D
		var d := l.global_position.distance_to((det as Node3D).global_position)
		if d < 3.0:
			var lb := l.global_position
			near.append("%s @ b(%.2f, %.2f, %.2f) %.2fm"
				% [l.name, lb.x, -lb.z, lb.y, d])
	print("[WATCHMAN LIVE] lobby fixtures within 3 m: ", ", ".join(near))

	# --- it reads the house clock and agrees with it ------------------------
	var director: Node = root.get("day_night_director")
	_check(director != null, "the production day/night owner is present")
	if director != null and director.has_method("_minute_now"):
		var house: float = float(director.call("_minute_now"))
		var expected := fposmod(house / 1440.0
				+ float(det.get("FRESH_DIAL_OFFSET")), 1.0) \
				if det.get("FRESH_DIAL_OFFSET") != null else -1.0
		_check(absf(float(det.call("correct_datum")) - expected) < 0.0005,
				"the detector's datum is derived from the SAME clock the sky uses (house %.0f min)"
						% house)

	# --- it is not one of the building's two clocks -------------------------
	# `walk_test` prices exactly two ClockProps and exactly two `wall_clock`
	# markers. This apparatus must join neither census.
	var clocks: Array = []
	for child in root.get_children():
		if child is ClockProp:
			clocks.append(str(child.name))
	_check(clocks.size() == 2,
			"the building still has exactly two clocks (%s)"
					% ", ".join(clocks))
	_check(not clocks.has("F01_WATCHMAN_DETECTOR"),
			"and the detector is not one of them")
	_check(not (det is ClockProp),
			"it is a distinct class, not a second ClockProp")
	# The one prop in the game that closes a work order is `ClockProp`. This
	# apparatus must hold no reference to the spine at all.
	_check(det.get("work_orders") == null,
			"it holds no WorkOrders reference, unlike the winding clock")

	# --- reach and the authored activity ------------------------------------
	_check(det.get_node_or_null("DetectorReach") is PropControlArea
			and str(det.call("control_prompt", "detector")).contains("dial"),
			"the detector is a ray-reachable service point")
	_check(det.call("interact_control", "detector", null)
			and det.get("_service_panel") != null,
			"that reach opens the shared activity system")
	var service: Node = det.get("_service_panel")
	var run: MaintenanceActivityRun = service.get("_director").active_run
	_check(str(run.activity_id) == "watchman_detector_dial"
			and str(run.profile.get("historical_source", "")).contains("676,764"),
			"and the activity it opens is the authored detector, by name")

	# --- NOTHING ELSE MAY MOVE ----------------------------------------------
	var switch_system: Node = root.get("switch_system")
	var switches_before: int = int(switch_system.get("switches")) \
			if switch_system != null else -1
	var powered_before := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_before += 1
	var toggles: Array = []
	if switch_system != null and switch_system.has_signal("room_toggled"):
		switch_system.room_toggled.connect(
				func(room_id: String, _on: bool) -> void: toggles.append(room_id))
	var vantry: Node = root.get("vantry_points")
	var vantry_before: int = int(vantry.call("cached_point_ids").size()) \
			if vantry != null else -1
	var vantry_active_before: String = str(vantry.get("active_point_id")) \
			if vantry != null else ""
	var orders: Node = root.get("work_orders")
	var clock_order_before: String = str(orders.call("status",
			ClockProp.ORDER_ID)) if orders != null else ""
	# ScheduleDirector is a named child, not a root property. Under DAYNIGHT=0
	# it goes inert by design; either way it must come out the far side with
	# the same switch, the same book and the same dispatch table.
	var schedule: Node = root.get_node_or_null("ScheduleDirector")
	var schedule_enabled_before: Variant = schedule.get("enabled") \
			if schedule != null else null
	var schedule_book_before: int = int((schedule.get("data") as Dictionary)
			.get("residents", {}).size()) if schedule != null else -1
	var dispatched_before: int = int((schedule.get("_dispatched")
			as Dictionary).size()) if schedule != null else -1
	var graph_nodes_before: int = AcousticGraphData.nodes.size()
	# RealityState.data is BOTH the save file and the Dream's own memory:
	# `dream_seed`, `dreams_had` and the `dream` block all live in it. One
	# stringify therefore prices persistence and Dream state together.
	var reality_before := JSON.stringify(RealityState.data)
	var reality_events: Array[String] = []
	RealityState.state_changed.connect(
			func() -> void: reality_events.append("state_changed"))
	RealityState.waking_residue_applied.connect(
			func(id: String, _f: Dictionary) -> void:
				reality_events.append("residue:" + id))
	RealityCases.case_changed.connect(
			func(id: String, _s: Dictionary) -> void:
				reality_events.append("case:" + id))
	RealityCases.case_resolved.connect(
			func(id: String, _s: Dictionary) -> void:
				reality_events.append("resolved:" + id))
	var save_exists_before := FileAccess.file_exists(RealityState.save_path)
	var save_stamp_before: int = FileAccess.get_modified_time(
			RealityState.save_path) if save_exists_before else -1

	# --- work the whole chain on the production apparatus -------------------
	var seen: Array[Dictionary] = []
	det.connect("maintenance_completed",
			func(r: Dictionary) -> void: seen.append(r))
	_check(det.get("movement_running") == true
			and det.get("dial_seated") == false,
			"the production detector is found running but unseated")

	# --- PREVIEW AND ABORT, ON THE PRODUCTION APPARATUS ---------------------
	# The panel's abort path is `restore_maintenance_snapshot` over the
	# snapshot it took when it opened. Working the detector and then aborting
	# has to leave the real lobby prop bit-for-bit as it was found -- including
	# after a REFUSAL, which is the case most likely to leave something behind.
	var found: Dictionary = det.call("maintenance_snapshot")
	det.call("preview_maintenance_step", {"id": "stop_the_movement"}, 0.0)
	det.call("preview_maintenance_step", {"id": "seat_the_dial"}, 0.44)
	det.call("preview_maintenance_step", {"id": "set_the_datum"},
			float(det.call("correct_datum")))
	# The movement has to be started again before a round can be proved: you
	# stop it to change the paper and you cannot prove a paper that is not
	# moving. That is the fault, and it is also the workflow.
	det.call("preview_maintenance_step", {"id": "stop_the_movement"}, 1.0)
	det.call("preview_maintenance_step", {"id": "prove_the_round"}, 0.83)
	_check(det.get("dial_seated") == true and det.get("datum_set") == true
			and det.call("marks_prove_movement") == true,
			"a preview moves the whole apparatus, marks and all")
	_check(det.get("detector_honest") == false,
			"and no amount of previewing publishes the detector honest")
	det.call("preview_maintenance_step", {"id": "seat_the_dial"}, 0.44)
	_check(det.call("balking") == true,
			"a refusal is live on the apparatus when the abort is taken")
	det.call("restore_maintenance_snapshot", found)
	var after: Dictionary = det.call("maintenance_snapshot")
	var drifted: Array[String] = []
	for key in found.keys():
		if typeof(found[key]) == TYPE_FLOAT:
			if absf(float(after.get(key, 0.0)) - float(found[key])) > 0.000001:
				drifted.append(str(key))
		elif after.get(key) != found[key]:
			drifted.append(str(key))
	_check(drifted.is_empty() and after.size() == found.size(),
			"abort restores every fact the apparatus had, exactly (%s)"
				% ", ".join(drifted))
	_check(det.call("balking") == false,
			"and it clears the refusal it was holding")
	_check(seen.is_empty(),
			"the whole preview-and-abort published nothing at all")
	var steps: Array = run.profile.get("steps", [])
	var moved := true
	for step in steps:
		var record := step as Dictionary
		var value := float(record.target)
		if str(record.id) == "set_the_datum":
			# The datum is whatever the house hour makes it, not an authored
			# number: this is the binding, exercised.
			value = float(det.call("correct_datum"))
		if str(record.id) == "prove_the_round":
			det.set("movement_running", true)
		det.call("preview_maintenance_step", record, value)
		if str(record.id) == "seat_the_dial":
			_check(det.get("dial_seated") == true,
					"the dial seats on its drive pin with the movement stopped")
		if str(record.verb) == "hold_release":
			moved = moved and service.get("_director").submit(
					"hold_release", float(record.target),
					float(record.hold_min_seconds) + 0.4)
		else:
			moved = moved and service.get("_director").submit(
					str(record.verb), float(record.target))
	_check(moved, "every authored verb lands on the production apparatus")
	_check(seen.size() == 1 and det.get("detector_honest") == true
			and det.call("record_is_honest") == true,
			"the final commit alone records the detector honest and reports once")
	_check(det.call("dial_turns") == true,
			"and the paper is finally being carried round")

	# --- nothing else moved -------------------------------------------------
	var powered_after := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_after += 1
	_check(powered_after == powered_before,
			"not one lamp changed power (%d before, %d after)"
					% [powered_before, powered_after])
	_check(toggles.is_empty(), "the switch system published no room toggle")
	_check(switch_system == null
			or int(switch_system.get("switches")) == switches_before,
			"the switch count is unchanged (%d)" % switches_before)
	_check(vantry == null
			or (int(vantry.call("cached_point_ids").size()) == vantry_before
					and str(vantry.get("active_point_id")) == vantry_active_before),
			"the vantry station table is untouched (%d points)" % vantry_before)
	_check(orders == null
			or str(orders.call("status", ClockProp.ORDER_ID))
					== clock_order_before,
			"the winding clock's work order is untouched (%s)"
					% clock_order_before)
	_check(schedule != null, "the resident schedule director is present")
	_check(schedule == null or (schedule.get("enabled") == schedule_enabled_before
			and int((schedule.get("data") as Dictionary)
				.get("residents", {}).size()) == schedule_book_before
			and int((schedule.get("_dispatched") as Dictionary).size())
				== dispatched_before),
			"the resident schedules are untouched (%d residents, %d dispatched)"
				% [schedule_book_before, dispatched_before])
	_check(AcousticGraphData.nodes.size() == graph_nodes_before,
			"the acoustic graph is unchanged (%d nodes)" % graph_nodes_before)
	_check(not AcousticGraphData.nodes.has("F01_WATCHMAN_DETECTOR"),
			"and the detector adds no node of its own")

	var patch: Dictionary = seen[0].get("mechanism_patch", {}) if seen.size() == 1 \
			else {}
	var leaked: Array[String] = []
	for key in patch.keys():
		if str(key) not in ["dial_seated", "movement_running", "datum_set",
				"detector_honest"]:
			leaked.append(str(key))
	_check(leaked.is_empty(),
			"the result patches the apparatus and nothing else (%s)"
					% ", ".join(leaked))
	_check(not seen[0].has("job_id") and not seen[0].has("case_id"),
			"it closes no job and advances no case")
	_check(JSON.stringify(RealityState.data) == reality_before,
			"the persisted state is byte-for-byte what it was, dream block included")
	_check(reality_events.is_empty(),
			"and no reality, residue or case signal was published (%s)"
				% ", ".join(reality_events))
	var save_exists_after := FileAccess.file_exists(RealityState.save_path)
	_check(save_exists_after == save_exists_before and (not save_exists_after
			or FileAccess.get_modified_time(RealityState.save_path)
				== save_stamp_before),
			"and nothing was written to the save file (present: %s)"
				% str(save_exists_before))
	_check((det as Node3D).find_children("*", "Light3D", true, false).is_empty(),
			"the apparatus owns no light of its own")
	_check((det as Node3D).find_children("*", "CollisionObject3D", true,
			false).size() == 1,
			"and exactly one collision body, its own reach")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [live watchman ok] ", label)
	else:
		failures += 1
		printerr("  [LIVE WATCHMAN FAIL] ", label)


func _finish() -> void:
	print("MAINTENANCE WATCHMAN LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
