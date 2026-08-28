extends Node

const LAYOUT_PATH := "res://data/orison_v2_blockout.json"
const SCENE_PATH := "res://scenes/building/orison_v2_blockout.tscn"
const F01_REVIEW_PATH := "res://scenes/building/orison_v2_f01_review.tscn"

var failures := 0

func _ready() -> void:
	var production_hash_before := FileAccess.get_sha256("res://data/building_layout.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_check(parsed is Dictionary, "v2 layout parses")
	if not parsed is Dictionary:
		_finish()
		return
	var layout: Dictionary = parsed
	_check(not bool(layout.get("production_default", true)), "v2 is development-only")
	_check(layout.get("layout_id", "") == "orison_v2_h_plan_blockout_01",
			"accepted H-plan identity is stable")
	_check(layout.levels.size() == 3, "first slice declares F01, F02 and F04")
	_check(layout.spaces.size() == 34, "34 programmed blockout spaces")
	_check(layout.doors.size() == 10, "ten complete route/service leaves")
	_check(layout.openings.size() == 3, "three leafless circulation openings")
	_check(layout.windows.size() == 4, "four F01 daylight openings")
	_check(layout.envelopes.size() == 10, "ten fixed-use and clearance reservations")
	_check(layout.anchors.size() == 16, "sixteen named gameplay/review anchors")
	_check(_route_exists(layout, "F01_STREET_APRON", "F01_PUBLIC_CORE"),
			"street connects through vestibule/lobby to public core")
	_check(_route_exists(layout, "F01_REAR_APRON", "F01_PUBLIC_CORE"),
			"rear service route connects to public core without private rooms")
	_check(_route_avoids_private(layout, "F01_REAR_APRON", "F01_SERVICE_CORE"),
			"rear service route reaches its core without private space")
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "v2 scene loads independently")
	if packed != null:
		var root := packed.instantiate()
		add_child(root)
		await get_tree().process_frame
		_check(root.failures.is_empty(), "schema validation passes")
		_check(root.is_in_group("orison_v2_blockout"), "explicit v2 selector group")
		for ident in ["F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03",
				"F02_A_MAIN_VANTRY_POINT", "F04_B_MONITOR_01", "F04_B_BED",
				"LobbyMailBank", "LobbyPorterBoard", "F01_HOUSE_TELEPHONE_BOARD",
				"LobbyServiceDumbwaiter"]:
			_check(root.get_node_or_null(ident) != null, "anchor/door resolves: " + ident)
		for ident in ["F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03",
				"F01_WATCH_MAIL_DOOR", "F01_MAIL_PACKAGE_DOOR",
				"F01_WATCH_CORE_DOOR", "F01_PACKAGE_COMMON_DOOR",
				"F01_REAR_SERVICE_DOOR", "F01_SERVICE_CORE_DOOR"]:
			var hinge := root.get_node("%s/Hinge" % ident) as Node3D
			_check(hinge != null and absf(hinge.rotation.y) > 1.5,
					"route leaf has a complete open hinge: " + ident)
		for ident in ["F01_LOBBY_WINDOW_W", "F01_LOBBY_WINDOW_E",
				"F01_COMMON_WINDOW_S", "F01_COMMON_WINDOW_N"]:
			_check(root.get_node_or_null(ident) != null, "window resolves: " + ident)
		for ident in ["F01_PRIMARY_ROUTE_ENVELOPE", "F01_CORE_DECISION_ENVELOPE",
				"F01_SERVICE_ROUTE_ENVELOPE", "F01_PASSENGER_LIFT_RESERVATION"]:
			_check(root.get_node_or_null(ident) != null, "use envelope resolves: " + ident)
		_check((root.get_node("F02_A_MAIN_VANTRY_POINT") as Node3D).global_position
				.is_equal_approx(Vector3(-10.1, 4.45, 1.4)), "2A Vantry transform derives from schema")
		_check((root.get_node("F04_B_BED") as Node3D).global_position
				.is_equal_approx(Vector3(-13.1, 10.15, 8.9)), "4B bed transform derives from schema")
		_check(root.get_node_or_null("WEST_WET_STACK") != null,
				"wet stack is continuous geometry")
		_check(root.get_node_or_null("SERVICE_LIFT_SHAFT") != null,
				"service lift is continuous geometry")
		await get_tree().physics_frame
		for sample: Vector3 in [Vector3(0.0, 0.85, -14.25),
				Vector3(0.0, 0.85, -10.45), Vector3(0.0, 0.85, -7.0),
				Vector3(2.1, 0.85, -3.85), Vector3(5.4, 0.85, 0.0),
				Vector3(6.85, 0.85, 0.0), Vector3(8.3, 0.85, 0.0),
				Vector3(8.9, 0.85, 5.0), Vector3(8.9, 0.85, 10.0)]:
			_check(_capsule_clear(root, sample), "0.66 m body clear at " + str(sample))
		root.queue_free()
	var review := load(F01_REVIEW_PATH) as PackedScene
	_check(review != null, "F01 controller review scene loads explicitly")
	if review != null:
		var review_root := review.instantiate()
		_check(review_root.get_node_or_null("Player") is CharacterBody3D,
				"review uses a collision-bearing player body")
		_check(review_root.get_node_or_null("Player/Head/Camera3D") is Camera3D,
				"review camera uses the 1.41 m player head")
		review_root.queue_free()
	_check(FileAccess.get_sha256("res://data/building_layout.json") == production_hash_before,
			"production layout remains byte-stable")
	_finish()

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)

func _route_exists(layout: Dictionary, start: String, goal: String) -> bool:
	var graph := _route_graph(layout)
	var queue: Array[String] = [start]
	var seen := {start: true}
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == goal:
			return true
		for next: String in graph.get(here, []):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return false

func _route_avoids_private(layout: Dictionary, start: String, goal: String) -> bool:
	var classes := {}
	for space: Dictionary in layout.spaces:
		classes[str(space.id)] = str(space.get("class", ""))
	var graph := _route_graph(layout)
	var queue: Array[String] = [start]
	var seen := {start: true}
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == goal:
			return true
		for next: String in graph.get(here, []):
			if classes.get(next, "") == "private" or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return false

func _route_graph(layout: Dictionary) -> Dictionary:
	var graph := {}
	for table in ["doors", "openings"]:
		for record: Dictionary in layout.get(table, []):
			var connects: Array = record.get("connects", [])
			if connects.size() != 2:
				continue
			var a := str(connects[0])
			var b := str(connects[1])
			if not graph.has(a):
				graph[a] = []
			if not graph.has(b):
				graph[b] = []
			graph[a].append(b)
			graph[b].append(a)
	return graph

func _capsule_clear(root: Node3D, at: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.524
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return root.get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()

func _finish() -> void:
	print("ORISON V2 BLOCKOUT TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)
