extends Node
## SR7-Q — the door check in the real building, and the audit finding asserted
## rather than remembered.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/DoorCheckLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## THE FINDING THIS SUITE PINS DOWN. The brief asked for "the Orison's
## stair-enclosure doors", plural. Production has 113 door leaves and EXACTLY
## ONE of them stands on the stair enclosure. Every other stair core in the
## building opens through a cased opening with no leaf in it at all. That is
## measured here, in the built tree, so it stops being a claim in a comment.
##
## What only production can settle:
##
##   * that the stair-enclosure door count is one, and which door it is;
##   * that there is exactly ONE closer in the whole building, hung on the
##     frame of that door and not on its leaf;
##   * that as found it is complete to look at and connected to nothing;
##   * that NOTHING ELSE IN THE BUILDING CLOSES ITSELF — every other leaf is
##     still a leaf a hand has to push;
##   * that it clears SR7-P's roof backboard by the distance the placement
##     comment claims;
##   * that SR7-N, SR7-O and SR7-P are untouched;
##   * and that SR7-Q owns no save key and no work order.

const CLOSER_SCRIPT := "res://scripts/props/door_check_closer_prop.gd"
## The one leaf the audit found, and the numbers it was found at.
const STAIR_DOOR := "ROOF_DOOR_01"
const STAIR_DOOR_B := Vector3(-1.330, -3.250, 19.200)
## SR7-P's roof backboard, whose clearance this must not spend.
const ROOF_BOARD_X := -2.76

var failures := 0
var checks := 0
var root: Node


func _ready() -> void:
	RealityState.persistence_enabled = false
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- the audit finding, in the built tree -------------------------------
	var leaves: Array[Node] = []
	for node in root.find_children("*_DOOR_*", "", true, false):
		if node.get("leaf_state") != null:
			leaves.append(node)
	print("[DOOR CHECK LIVE] %d door leaves in the building" % leaves.size())
	_check(leaves.size() > 100, "the building is hung with %d leaves"
			% leaves.size())
	# The stair core is the well at the middle of the plan. A leaf ON the
	# enclosure stands in its wall; everything else is an apartment, a closet,
	# a service room or the street.
	var on_stair: Array[Node] = []
	for leaf in leaves:
		var at: Vector3 = (leaf as Node3D).global_position
		if absf(at.x) < 3.6 and absf(-at.z) < 3.8:
			on_stair.append(leaf)
	var names := PackedStringArray()
	for leaf in on_stair:
		names.append(str(leaf.name))
	_check(on_stair.size() == 1,
			"EXACTLY ONE of them stands on the stair enclosure: %s"
					% ", ".join(names))
	_check(on_stair.size() == 1 and str(on_stair[0].name) == STAIR_DOOR,
			"and it is %s, at the head of the stair" % STAIR_DOOR)

	var door: Node3D = root.find_child(STAIR_DOOR, true, false) as Node3D
	_check(door != null, "%s is in the tree" % STAIR_DOOR)
	if door == null:
		_finish()
		return
	var at: Vector3 = door.global_position
	var found := Vector3(at.x, -at.z, at.y)
	_check(found.distance_to(STAIR_DOOR_B) < 0.02,
			"standing where the audit measured it: b(%.3f, %.3f, %.3f)"
					% [found.x, found.y, found.z])
	_check(str(door.get("door_kind")) == "service"
			and absf(float(door.get("width")) - 0.96) < 0.01,
			"a 0.96 m service leaf, which is what a check gets hung on")

	# --- exactly one closer, on the frame, not on the leaf ------------------
	var closers: Array[Node] = []
	for node in root.find_children("*", "", true, false):
		var script: Script = node.get_script()
		if script != null and str(script.resource_path) == CLOSER_SCRIPT:
			closers.append(node)
	_check(closers.size() == 1,
			"EXACTLY ONE closer in the whole building (%d)" % closers.size())
	var closer: Node = closers[0] if closers.size() == 1 else null
	if closer == null:
		_finish()
		return
	_check(str(closer.name) == "ROOF_DOOR_CHECK", "named ROOF_DOOR_CHECK")
	_check(closer.get_parent() == door,
			"MOUNTED ON THE DOOR NODE, which is the frame")
	_check(str(closer.get_parent().name) != "HingedLeaf",
			"and NOT on HingedLeaf, which is the leaf")
	_check(closer.call("door") == door,
			"and the leaf authority it answers to is that same door")
	var body: Node3D = door.get_node_or_null("HingedLeaf") as Node3D
	_check(body != null and not body.is_ancestor_of(closer),
			"no part of this apparatus rides the moving body")

	# --- as found ------------------------------------------------------------
	_check(not bool(closer.get("arm_shipped")),
			"AS FOUND the arm is off its spindle")
	_check(float(closer.get("port_turns")) == 0.0,
			"and the regulating screw is home (%s)" % closer.call("port_reads"))
	_check(not bool(closer.call("ready")), "so the closer is NOT ready")
	_check(not bool(closer.call("closes_itself")),
			"and this door DOES NOT CLOSE ITSELF")
	_check(bool(closer.call("shuts_by_hand")),
			"though it shuts by hand like every other leaf in the building")
	_check(not bool(closer.get("arm_seen")), "nobody has looked at it")
	_check(closer.call("last_record").is_empty(), "it has published nothing")
	_check(closer.has_method("interact_prompt")
			and not str(closer.call("interact_prompt")).is_empty(),
			"and it answers a look: \"%s\"" % closer.call("interact_prompt"))
	_check(str(door.get("leaf_state")) == "closed" and not bool(door.get("open")),
			"the leaf itself is shut, and DoorProp still says so")

	# --- nothing else in the building closes itself --------------------------
	var with_closer := 0
	for leaf in leaves:
		for child in leaf.get_children():
			var script: Script = child.get_script()
			if script != null and str(script.resource_path) == CLOSER_SCRIPT:
				with_closer += 1
	_check(with_closer == 1,
			"ONE leaf in the building has a closer on it (%d)" % with_closer)
	_check(leaves.size() - with_closer > 100,
			"the other %d are leaves a hand has to push, and SR7-Q did not "
					% (leaves.size() - with_closer)
					+ "quietly make them otherwise")

	# --- clearance against SR7-P --------------------------------------------
	# The closer's own iron occupies local x 0.13..0.78 east of the hinge.
	var nearest := at.x + 0.13
	_check(absf(nearest - ROOF_BOARD_X) > 1.15,
			"its nearest part stands %.3f m from SR7-P's roof board"
					% absf(nearest - ROOF_BOARD_X))
	var reaches := 0
	for child in closer.get_children():
		if child is Area3D:
			reaches += 1
	_check(reaches == 4, "four places to put a hand (%d)" % reaches)
	for child in closer.get_children():
		if child is Area3D:
			for shape in child.get_children():
				if shape is CollisionShape3D:
					var p: Vector3 = (shape as CollisionShape3D).global_position
					_check(p.y > at.y + 1.4 and p.y < at.y + 2.2,
							"%s sits at head height, %.2f above the sill"
									% [child.name, p.y - at.y])

	# --- nothing else moved --------------------------------------------------
	var fire_line: Node = root.find_child("F01_FIRE_LINE_STAIR", true, false)
	_check(fire_line != null and bool(fire_line.call("hose_present"))
			and not bool(fire_line.call("line_made_up")),
			"SR7-N's cabinet is as SR7-N left it")
	var sr7o: Node = root.find_child("F03_EXTINGUISHER_STAIR", true, false)
	_check(sr7o != null and bool(sr7o.call("sealed"))
			and not bool(sr7o.call("usable")),
			"SR7-O's extinguisher is as SR7-O left it")
	var floor_nodes := 0
	var batches := 0
	for node in root.find_children("*", "Node3D", false, false):
		if str(node.name) in ["B1", "F01", "F02", "F03", "F04", "F05", "F06",
				"ROOF"]:
			floor_nodes += 1
			for child in (node as Node3D).get_children():
				if child is MultiMeshInstance3D:
					batches += 1
	print("[DOOR CHECK LIVE] %d floors, %d detail batches" % [floor_nodes,
			batches])
	_check(floor_nodes == 8, "eight floors (%d)" % floor_nodes)
	_check(batches <= 40, "SR7-P's board batches are untouched (%d)" % batches)
	_check(not RealityState.data.has("door_closer")
			and not RealityState.data.has("closer_state")
			and not RealityState.data.has("stair_door"),
			"SR7-Q wrote no save key of its own")
	var work_orders: Node = root.get("work_orders")
	if work_orders != null:
		var jobs: Dictionary = work_orders.call("serialize_jobs")
		_check(jobs.size() <= 2,
				"and no work order of its own (%d on the spine)" % jobs.size())
	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [door check live ok] ", label)
	else:
		failures += 1
		printerr("  [DOOR CHECK LIVE FAIL] ", label)


func _finish() -> void:
	print("DOOR CHECK LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
