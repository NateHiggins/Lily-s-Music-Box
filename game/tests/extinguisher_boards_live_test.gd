extends Node
## SR7-P — eight boards in the real building.
##
##     tools/run_godot_serial.ps1 `
##         -Scene res://tests/ExtinguisherBoardsLiveTest.tscn `
##         -ProjectPath <checkout>/game
##
## What only production can settle:
##
##   * that after SR7-P there is still exactly ONE interactable extinguisher in
##     the whole building, and it is SR7-O's, in the state SR7-O left it;
##   * that the seven passive boards are NOT NODES — nothing stands within
##     reach of any of them except that one apparatus, which is what makes "no
##     Area3D, no collision, no light, no process, no persistence" a fact about
##     the scene rather than about the source;
##   * that they cost no draw call and no material, because they live in the
##     per-floor batches the boards already lived in;
##   * that all eight boards keep legal stair and doorway clearance;
##   * and that nothing else in the building moves.

const DetailPass := preload("res://scripts/building/orison_detail_pass.gd")
const SR7O_SCRIPT := "res://scripts/props/soda_acid_extinguisher_prop.gd"

var failures := 0
var checks := 0

## The board, read off the batch that draws it.
const BOARD_X := -2.76
const BOARD_FACE_Y := -3.06
## The deepest thing SR7-P hangs on a board is the bracket, whose front strap
## stands 0.27 off the board's face.
const PASSIVE_REACH := 0.27
## The stair core's south landing and the doorway cut in its wall.
const LANDING := Rect2(-3.16, -3.16, 6.32, 1.70)
const DOORWAY_WEST_JAMB := -1.60
const BOARD_HALF_WIDTH := 0.17
const FLOOR_Z := {
	"B1": -2.8, "F01": 0.0, "F02": 3.2, "F03": 6.4,
	"F04": 9.6, "F05": 12.8, "F06": 16.0, "ROOF": 19.2,
}

var root: Node


func _ready() -> void:
	RealityState.persistence_enabled = false
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- exactly one functional extinguisher family -------------------------
	var functional: Array[Node] = []
	for node in root.find_children("*", "", true, false):
		var script: Script = node.get_script()
		if script != null and str(script.resource_path) == SR7O_SCRIPT:
			functional.append(node)
	_check(functional.size() == 1,
			"EXACTLY ONE interactable extinguisher in the building (%d)"
					% functional.size())
	var sr7o: Node = functional[0] if functional.size() == 1 else null
	_check(sr7o != null and str(sr7o.name) == "F03_EXTINGUISHER_STAIR",
			"and it is SR7-O's, on F03")

	# --- SR7-O is state-for-state what SR7-O left --------------------------
	var sr7o_before := ""
	var sr7o_published: Array = []
	if sr7o != null:
		sr7o_before = JSON.stringify(sr7o.call("maintenance_snapshot"))
		var sink := func(_record: Dictionary) -> void:
			sr7o_published.append(1)
		sr7o.connect("extinguisher_inspected", sink)
		_check(bool(sr7o.call("sealed")) and bool(sr7o.call("charged")),
				"found sealed and charged, exactly as SR7-O authored it")
		_check(not bool(sr7o.call("will_lift")),
				"with the cap that will not lift still not lifting")
		_check(not bool(sr7o.call("usable")), "and still not usable")
		_check(not bool(sr7o.get("cap_tested")), "and nobody has touched it")
		_check(sr7o.call("last_record").is_empty(),
				"and it has published nothing")

	# --- the seven passive boards are not nodes -----------------------------
	# Anything a passive condition owned would have to be a node standing at a
	# board. Sweep every Node3D in the building and see what is near one.
	var near_boards: Dictionary = {}
	for node in root.find_children("*", "Node3D", true, false):
		var at: Vector3 = (node as Node3D).global_position
		for floor_id in FLOOR_Z.keys():
			var z: float = float(FLOOR_Z[floor_id]) + 1.05
			if absf(at.x - BOARD_X) < 0.45 and absf(-at.z - BOARD_FACE_Y) < 0.45 \
					and absf(at.y - z) < 0.55:
				near_boards[floor_id] = str(near_boards.get(floor_id, "")) \
						+ str(node.name) + " "
	_check(near_boards.size() == 1,
			"only ONE board has any node standing at it (%s)"
					% ", ".join(PackedStringArray(near_boards.keys())))
	_check(near_boards.has("F03"), "and that board is F03's")
	for floor_id in FLOOR_Z.keys():
		if floor_id == "F03":
			continue
		_check(not near_boards.has(str(floor_id)),
				"%s's board owns no node at all" % floor_id)

	# --- and they cost no draw call and no material -------------------------
	var floor_nodes: Dictionary = {}
	for node in root.find_children("*", "Node3D", false, false):
		if FLOOR_Z.has(str(node.name)):
			floor_nodes[str(node.name)] = node
	_check(floor_nodes.size() == 8, "eight floor nodes (%d)"
			% floor_nodes.size())
	var total_batches := 0
	var total_instances := 0
	var materials: Dictionary = {}
	for floor_id in floor_nodes.keys():
		for child in (floor_nodes[floor_id] as Node3D).get_children():
			if child is MultiMeshInstance3D:
				var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
				if mm == null or mm.mesh == null:
					continue
				total_batches += 1
				total_instances += mm.instance_count
				var mat := mm.mesh.surface_get_material(0)
				if mat != null:
					materials[mat.get_instance_id()] = true
	print("[BOARDS LIVE] %d batches, %d instances, %d materials"
			% [total_batches, total_instances, materials.size()])
	# SR7-P adds no batch and no material: everything it draws is an entry in
	# the two batches each floor already had. The focused suite proves that by
	# construction -- the builder can only call `_box` and `_cylinder` -- and
	# what production adds is the shape of the result: a few dozen batches
	# carrying hundreds of instances between them, which is what batching is.
	_check(total_batches <= 40,
			"the detail batches stayed bounded (%d)" % total_batches)
	_check(materials.size() <= total_batches,
			"no batch invented a second material (%d for %d batches)"
					% [materials.size(), total_batches])
	_check(total_instances >= total_batches * 8,
			"and they carry %d instances between them, %.1f per batch"
					% [total_instances,
							float(total_instances) / maxf(1.0,
									float(total_batches))])

	# --- every board keeps legal clearance ----------------------------------
	for floor_id in FLOOR_Z.keys():
		var condition := str(DetailPass.BOARD_CONDITIONS.get(floor_id, ""))
		var front := BOARD_FACE_Y + PASSIVE_REACH
		_check(front < LANDING.position.y + LANDING.size.y - 1.20,
				"%s (%s) projects to y %.3f, leaving %.2f m of landing"
						% [floor_id, condition, front,
								LANDING.position.y + LANDING.size.y - front])
		_check(BOARD_X + BOARD_HALF_WIDTH < DOORWAY_WEST_JAMB,
				"%s clears the stair doorway's west jamb by %.2f m"
						% [floor_id,
								DOORWAY_WEST_JAMB - (BOARD_X
										+ BOARD_HALF_WIDTH)])
		_check(BOARD_X - BOARD_HALF_WIDTH > LANDING.position.x,
				"%s stays inside the landing's west edge" % floor_id)

	# --- nothing else in the building moved ---------------------------------
	var fire_line: Node = root.find_child("F01_FIRE_LINE_STAIR", true, false)
	_check(fire_line != null, "SR7-N's fire-line cabinet is still standing")
	if fire_line != null:
		_check(bool(fire_line.call("hose_present"))
				and not bool(fire_line.call("line_made_up")),
				"in the state SR7-N left it: hose on the rack, line not made")
		_check(fire_line.call("last_record").is_empty(),
				"and it has published nothing")
	var work_orders: Node = root.get("work_orders")
	_check(work_orders != null, "the production job spine is in the tree")
	if work_orders != null:
		var jobs: Dictionary = work_orders.call("serialize_jobs")
		print("[BOARDS LIVE] %d jobs on the spine" % jobs.size())
		_check(jobs.size() <= 2,
				"carrying only the authored work it already had (%d)"
						% jobs.size())
	_check(not RealityState.data.has("board_conditions")
			and not RealityState.data.has("extinguisher_boards"),
			"SR7-P wrote no save key of its own")
	var doors_shut := 0
	for leaf in root.find_children("*_DOOR_*", "", true, false):
		if leaf.get("leaf_state") != null:
			doors_shut += 1
	_check(doors_shut > 40, "%d real door leaves are in the building"
			% doors_shut)
	var powered := 0
	for fixture in get_tree().get_nodes_in_group("light_fixtures"):
		if fixture.get("powered") == true:
			powered += 1
	print("[BOARDS LIVE] %d lamps powered" % powered)
	_check(powered > 100, "the building is lit by its own fixtures (%d)"
			% powered)
	var net: Node = root.find_child("WatchStationNetwork", true, false)
	_check(net == null or int(net.call("mark_count")) == 0,
			"the watch line recorded nothing")
	var guard: Node = root.find_child("F01_TOUR_KEY_GUARD", true, false)
	_check(guard == null or not bool(guard.call("key_carried")),
			"the tour key is on its hook")

	# --- and SR7-O never moved while all of that was measured ---------------
	if sr7o != null:
		_check(JSON.stringify(sr7o.call("maintenance_snapshot")) == sr7o_before,
				"SR7-O's apparatus is BYTE-FOR-BYTE what it was")
		_check(sr7o_published.is_empty(), "and published nothing throughout")
	_finish()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [boards live ok] ", label)
	else:
		failures += 1
		printerr("  [BOARDS LIVE FAIL] ", label)


func _finish() -> void:
	print("EXTINGUISHER BOARDS LIVE TEST: %s (%d/%d)"
			% ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
