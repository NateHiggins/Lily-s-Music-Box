extends Node
## SR7-E — the panel stands in the real electrical room and changes nothing else.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/MaintenanceFuseLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## The audit that preceded SR7-E found that the Orison ALREADY OWNS an
## electrical plant, and that is the whole constraint on this work:
##
##   * `B1_ELECTRICAL`, rect [5.51, -9.65, 13.65, -1.0], a real generated room;
##   * `b1_panel0/1/2`, three baked cabinets on its east wall at x 13.30..13.44,
##     standing 0.9 to 1.9 above the basement floor, with `b1_econduit`
##     running the same wall;
##   * `B1_ELECTRICAL_HUB` at [10.0, -5.0, -2.4], the largest node in the
##     acoustic/possession graph, carrying the building's electrical spine;
##   * `SwitchSystem`, whose own header calls the switch "the only thing that
##     changes room power", and `LightFixtureProp.powered` beneath it.
##
## So this file proves three things. That the apparatus stands ON the existing
## cabinet rather than beside a second invented one. That the electrical graph
## it sits inside is untouched. And that servicing it moves not one lamp.

var failures := 0
var checks := 0

## The baked cabinet this apparatus is the working face of, in building coords.
const CABINET_X := 13.30
const CABINET_Y0 := -7.20
const CABINET_Y1 := -6.40
const B1_Z := -2.8
const CABINET_LOCAL_Z0 := 0.90
## The generated electrical room.
const ROOM := [5.51, -9.65, 13.65, -1.0]


func _ready() -> void:
	var scene := load("res://scenes/building/orison_root.tscn") as PackedScene
	var root: Node = scene.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var panel: Node = root.find_child("B1_HOUSE_PANEL", true, false)
	_check(panel != null, "the production basement owns a house panelboard")
	if panel == null:
		_finish()
		return

	# --- it stands on the cabinet that was already there --------------------
	var at: Vector3 = (panel as Node3D).global_position
	var bx := at.x
	var by := -at.z
	var bz := at.y
	print("[FUSE LIVE] global b(%.2f, %.2f, %.2f)" % [bx, by, bz])
	_check(absf(bx - CABINET_X) < 0.02,
			"it is on the baked cabinet's front plane (b x %.2f)" % bx)
	_check(by > CABINET_Y0 and by < CABINET_Y1,
			"within that cabinet's own width (b y %.2f)" % by)
	_check(absf(bz - (B1_Z + CABINET_LOCAL_Z0)) < 0.02,
			"at the cabinet's own height above the basement floor (b z %.2f)"
					% bz)
	_check(bx >= ROOM[0] and bx <= ROOM[2] and by >= ROOM[1] and by <= ROOM[3],
			"and inside B1_ELECTRICAL, the room production already had")
	_check(panel.get_parent() != null
			and str(panel.get_parent().name) == "B1",
			"parented to the B1 floor node")
	# Authored facing local +Z; the room lies west of the cabinet.
	var facing: Vector3 = (panel as Node3D).global_transform.basis.z.normalized()
	_check(facing.x < -0.9,
			"its face is turned into the room (z -> %.2f)" % facing.x)

	# --- the electrical graph is real and untouched -------------------------
	_check(AcousticGraphData.nodes.has("B1_ELECTRICAL_HUB"),
			"the electrical hub this room is named for exists in the graph")
	var hub_before: int = (AcousticGraphData.neighbors("B1_ELECTRICAL_HUB")
			as Array).size()
	var nodes_before: int = AcousticGraphData.nodes.size()
	_check(hub_before > 0,
			"and it carries the building's spine (%d neighbours)" % hub_before)
	# This apparatus is deliberately NOT on the graph. It is a hand-placed
	# service face, not a new electrical node, and adding one would have meant
	# a generator re-bake and an edge nobody asked for.
	_check(not AcousticGraphData.nodes.has("B1_HOUSE_PANEL"),
			"the apparatus adds no node of its own to the electrical graph")

	# --- reach and the authored activity ------------------------------------
	_check(panel.get_node_or_null("PanelReach") is PropControlArea
			and str(panel.call("control_prompt", "panel")).contains("panel"),
			"the panel is a ray-reachable service point")
	_check(panel.call("interact_control", "panel", null)
			and panel.get("_service_panel") != null,
			"that reach opens the shared activity system")
	var service: Node = panel.get("_service_panel")
	var run: MaintenanceActivityRun = service.get("_director").active_run
	_check(str(run.activity_id) == "fuse_panel_rating_service"
			and str(run.profile.get("historical_source", "")).contains("2,147,221"),
			"and the activity it opens is the authored panel, by name")

	# --- NO CROSS-SYSTEM MUTATION -------------------------------------------
	# The switch system is the only thing allowed to change room power, and the
	# lamps are the only things that hold it. Both are counted before and after.
	var switch_system: Node = root.get("switch_system")
	var switches_before: int = int(switch_system.get("switches")) \
			if switch_system != null else -1
	var fixtures: Array = get_tree().get_nodes_in_group("light_fixtures")
	var powered_before := 0
	for fixture in fixtures:
		if fixture.get("powered") == true:
			powered_before += 1
	_check(switch_system != null and switches_before > 0 and fixtures.size() > 0,
			"the switch system and its fixtures are live to be left alone (%d switches, %d fixtures)"
					% [switches_before, fixtures.size()])
	var toggles: Array = []
	if switch_system != null and switch_system.has_signal("room_toggled"):
		switch_system.room_toggled.connect(
				func(room_id: String, _on: bool) -> void: toggles.append(room_id))

	# --- work the whole chain on the production apparatus -------------------
	var seen: Array[Dictionary] = []
	panel.connect("maintenance_completed",
			func(r: Dictionary) -> void: seen.append(r))
	_check(panel.call("over_fused") == true and panel.call("panel_live") == true,
			"the production panel is found over-fused and live")
	var steps: Array = run.profile.get("steps", [])
	var moved := true
	for step in steps:
		var record := step as Dictionary
		panel.call("preview_maintenance_step", record, float(record.target))
		if str(record.id) == "pull_the_main":
			_check(panel.call("panel_live") == false,
					"opening the main kills the production panel")
		if str(record.id) == "match_the_wire":
			_check(panel.call("over_fused") == false,
					"and the fitted plug now matches the conductor")
		if str(record.verb) == "hold_release":
			moved = moved and service.get("_director").submit(
					"hold_release", float(record.target),
					float(record.hold_min_seconds) + 0.4)
		else:
			moved = moved and service.get("_director").submit(
					str(record.verb), float(record.target))
	_check(moved, "every authored verb lands on the production apparatus")
	_check(seen.size() == 1 and panel.get("panel_safe") == true
			and panel.call("protects_conductor") == true,
			"the final commit alone records the panel safe and reports once")

	# --- nothing else moved -------------------------------------------------
	var powered_after := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered_after += 1
	_check(powered_after == powered_before,
			"not one lamp changed power (%d before, %d after)"
					% [powered_before, powered_after])
	_check(toggles.is_empty(),
			"and the switch system published no room toggle (%s)"
					% ", ".join(toggles))
	_check(switch_system == null
			or int(switch_system.get("switches")) == switches_before,
			"the switch count is unchanged")
	_check(AcousticGraphData.nodes.size() == nodes_before
			and (AcousticGraphData.neighbors("B1_ELECTRICAL_HUB")
					as Array).size() == hub_before,
			"the electrical graph is bit-for-bit what it was")

	var patch: Dictionary = seen[0].get("mechanism_patch", {}) if seen.size() == 1 \
			else {}
	var leaked: Array[String] = []
	for key in patch.keys():
		if str(key) not in ["fitted_rating", "main_open", "plug_out",
				"panel_safe"]:
			leaked.append(str(key))
	_check(leaked.is_empty(),
			"the result patches the apparatus and nothing else (%s)"
					% ", ".join(leaked))
	_check(not seen[0].has("job_id") and not seen[0].has("case_id"),
			"it closes no job and advances no case")
	_check((panel as Node3D).find_children("*", "Light3D", true, false).is_empty(),
			"the apparatus owns no light of its own")
	_check((panel as Node3D).find_children("*", "CollisionObject3D", true,
			false).size() == 1,
			"and exactly one collision body, its own reach")

	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [live fuse ok] ", label)
	else:
		failures += 1
		printerr("  [LIVE FUSE FAIL] ", label)


func _finish() -> void:
	print("MAINTENANCE FUSE LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
