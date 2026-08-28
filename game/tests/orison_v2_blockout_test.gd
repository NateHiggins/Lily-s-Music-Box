extends Node

const LAYOUT_PATH := "res://data/orison_v2_blockout.json"
const SCENE_PATH := "res://scenes/building/orison_v2_blockout.tscn"
const F01_REVIEW_PATH := "res://scenes/building/orison_v2_f01_review.tscn"
const F02_REVIEW_PATH := "res://scenes/building/orison_v2_f02_review.tscn"
const F04_REVIEW_PATH := "res://scenes/building/orison_v2_f04_review.tscn"

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
	_check(layout.levels.size() == 4, "first slice declares F01 through F04 transfer levels")
	_check(layout.spaces.size() == 38, "38 programmed blockout spaces")
	_check(layout.doors.size() == 16, "sixteen complete route/service/privacy leaves")
	_check(layout.openings.size() == 11, "eleven leafless circulation openings")
	_check(layout.windows.size() == 15, "fifteen exterior-valid daylight openings")
	_check(layout.envelopes.size() == 45, "forty-five fixed-use and clearance reservations")
	_check(layout.platforms.size() == 20, "twenty explicit core landing platforms")
	_check(layout.lift_landings.size() == 8, "eight passenger/service lift landings")
	_check(layout.stairs.size() == 6, "public and service U-stairs span three storeys")
	_check(layout.anchors.size() == 31, "thirty-one named gameplay/review anchors")
	_check(layout.capsule_stations.size() == 11, "eleven declared F04 capsule stations")
	_check(_f04_rooms_do_not_overlap(layout), "F04 apartment rooms do not overlap")
	_check(_f04_shared_partitions_owned_once(layout),
			"every F04 shared partition has exactly one wall owner")
	_check(_windows_are_exterior(layout), "every window lies on a declared exterior wall")
	_check(_f04_doors_valid(layout), "F04 leaves have boundary, handedness and swing records")
	_check(_f04_clearances_valid(layout),
			"F04 turning, work, bedside and door-swing clearances do not conflict")
	for stair: Dictionary in layout.stairs:
		_check(str(stair.kind) == "u", "U-stair record: " + str(stair.id))
		_check(int(stair.risers_per_flight) == 10 and is_equal_approx(float(stair.rise), 0.16),
				"twenty uniform 160 mm risers: " + str(stair.id))
		_check(float(stair.tread) >= 0.275, "tread is at least 275 mm: " + str(stair.id))
		_check(float(stair.width) >= 1.05, "stair clear width is at least 1.05 m: " + str(stair.id))
		_check(float(stair.guard_height) >= 0.91, "guard is at least 0.91 m: " + str(stair.id))
		_check(float(layout.dimensions.floor_to_floor)
				- float(stair.rise) * 6.0 >= 2.2,
				"conservative 2.20 m headroom at crossover: " + str(stair.id))
	_check(_route_exists(layout, "F01_STREET_APRON", "F01_PUBLIC_CORE"),
			"street connects through vestibule/lobby to public core")
	_check(_route_exists(layout, "F01_REAR_APRON", "F01_PUBLIC_CORE"),
			"rear service route connects to public core without private rooms")
	_check(_route_avoids_private(layout, "F01_REAR_APRON", "F01_SERVICE_CORE"),
			"rear service route reaches its core without private space")
	_check(_route_exists(layout, "F02_LANDING", "F02_A_MAIN"),
			"F02 landing reaches Mina's main/work room")
	_check(_route_exists(layout, "F02_LANDING", "F02_A_BATH"),
			"F02 landing reaches 2A bath through the private distributor")
	_check(_route_exists(layout, "F02_LANDING", "F02_A_BED"),
			"F02 landing reaches 2A bedroom through the private distributor")
	_check(_route_exists(layout, "F04_LANDING", "F04_B_ALCOVE"),
			"F04 landing reaches the 4B sleeping alcove")
	_check(_route_exists(layout, "F04_LANDING", "F04_B_BATH"),
			"F04 landing reaches the 4B bath")
	_check(_route_exists(layout, "F04_LANDING", "F04_B_CLOSET"),
			"F04 landing reaches the 4B closet")
	_check(_route_avoids_space(layout, "F04_LANDING", "F04_B_ALCOVE", "F04_B_BATH"),
			"sleeping route does not pass through the bathroom")
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
				"F02_A_MONITOR_01",
				"LobbyServiceDumbwaiter"]:
			_check(root.get_node_or_null(ident) != null, "anchor/door resolves: " + ident)
		for ident in ["F01_DOOR_06", "F02_DOOR_02", "F04_DOOR_03",
				"F01_WATCH_MAIL_DOOR", "F01_MAIL_PACKAGE_DOOR",
				"F01_WATCH_CORE_DOOR", "F01_PACKAGE_COMMON_DOOR",
				"F01_REAR_SERVICE_DOOR", "F01_SERVICE_CORE_DOOR",
				"F02_A_HALL_DOOR", "F02_A_BATH_DOOR", "F02_A_BED_DOOR",
				"F04_B_HALL_DOOR", "F04_B_BATH_DOOR", "F04_B_CLOSET_DOOR"]:
			var hinge := root.get_node("%s/Hinge" % ident) as Node3D
			_check(hinge != null and absf(hinge.rotation.y) > 1.5,
					"route leaf has a complete open hinge: " + ident)
			_check(root.get_node_or_null("%s/Latch" % ident) is Marker3D,
					"route leaf has an explicit latch: " + ident)
		for ident in ["F01_LOBBY_WINDOW_W", "F01_LOBBY_WINDOW_E",
				"F01_COMMON_WINDOW_S", "F01_COMMON_WINDOW_N",
				"F02_A_MAIN_WINDOW_W_S", "F02_A_MAIN_WINDOW_W_N",
				"F02_A_KITCHEN_WINDOW_W", "F02_A_BED_WINDOW_W",
				"F02_A_BED_WINDOW_N", "F04_B_MAIN_WINDOW_W_S",
				"F04_B_MAIN_WINDOW_W_N", "F04_B_KITCHEN_WINDOW_W",
				"F04_B_BATH_WINDOW_E", "F04_B_ALCOVE_WINDOW_W",
				"F04_B_ALCOVE_WINDOW_N"]:
			_check(root.get_node_or_null(ident) != null, "window resolves: " + ident)
		for ident in ["F01_PRIMARY_ROUTE_ENVELOPE", "F01_CORE_DECISION_ENVELOPE",
				"F01_SERVICE_ROUTE_ENVELOPE", "F01_PASSENGER_LIFT_RESERVATION",
				"F02_LANDING_DECISION_ENVELOPE", "F02_WEST_HALL_ROUTE",
				"F02_A_ENTRY_CLEARANCE", "F02_A_CAPTION_WORK_ZONE",
				"F02_A_PRIVATE_HALL_ROUTE", "F02_A_BED_ROUTE",
				"F04_B_VESTIBULE_TURN", "F04_B_MAIN_CLEAR_FLOOR",
				"F04_B_WORK_ZONE", "F04_B_TERMINAL_STANCE",
				"F04_B_KITCHEN_AISLE", "F04_B_PRIVATE_ROUTE",
				"F04_B_ALCOVE_ROUTE", "F04_B_BEDSIDE_RETURN_CLEARANCE"]:
			_check(root.get_node_or_null(ident) != null, "use envelope resolves: " + ident)
		_check((root.get_node("F02_A_MAIN_VANTRY_POINT") as Node3D).global_position
				.is_equal_approx(Vector3(-10.1, 4.45, 1.4)), "2A Vantry transform derives from schema")
		_check((root.get_node("F04_B_BED") as Node3D).global_position
				.is_equal_approx(Vector3(-13.1, 10.15, 8.9)), "4B bed transform derives from schema")
		_check((root.get_node("F04_B_MONITOR_01") as Node3D).global_position
				.is_equal_approx(Vector3(-9.05, 10.35, 1.25)),
				"4B terminal transform derives from schema")
		_check((root.get_node("F04_B_MONITOR_STANCE") as Node3D).global_position
				.is_equal_approx(Vector3(-9.9, 9.6, 1.25)),
				"4B terminal stance remains exact")
		var bedside := root.get_node("F04_B_BEDSIDE_RETURN") as Node3D
		_check(bedside.global_position.is_equal_approx(Vector3(-11.95, 9.6, 8.9))
				and is_equal_approx(bedside.rotation.y, -PI * 0.5),
				"4B bedside return remains exact and faces west")
		_check(root.get_node_or_null("WEST_WET_STACK") != null,
				"wet stack is continuous geometry")
		_check(root.get_node_or_null("SERVICE_LIFT_SHAFT") != null,
				"service lift is continuous geometry")
		_check(root.get_node_or_null("PASSENGER_LIFT_SHAFT") != null,
				"passenger lift is continuous reserved geometry")
		for ident in ["PRIMARY_F01_F02", "PRIMARY_F02_F03", "PRIMARY_F03_F04",
				"SERVICE_F01_F02", "SERVICE_F02_F03", "SERVICE_F03_F04"]:
			_check(root.get_node_or_null("%s/HalfLanding" % ident) != null,
					"half landing resolves: " + ident)
			_check(root.get_node_or_null("%s/HalfLandingGuard" % ident) != null,
					"landing guard resolves: " + ident)
		for ident in ["F01_PASSENGER_LIFT_LANDING", "F02_PASSENGER_LIFT_LANDING",
				"F03_PASSENGER_LIFT_LANDING", "F04_PASSENGER_LIFT_LANDING",
				"F01_SERVICE_LIFT_LANDING", "F02_SERVICE_LIFT_LANDING",
				"F03_SERVICE_LIFT_LANDING", "F04_SERVICE_LIFT_LANDING"]:
			_check(root.get_node_or_null("%s/Clearance" % ident) != null,
					"lift landing clearance resolves: " + ident)
		await get_tree().physics_frame
		for sample: Vector3 in [Vector3(0.0, 0.85, -14.25),
				Vector3(0.0, 0.85, -10.45), Vector3(0.0, 0.85, -7.0),
				Vector3(2.1, 0.85, -3.85), Vector3(5.4, 0.85, 0.0),
				Vector3(6.85, 0.85, 0.0), Vector3(8.3, 0.85, 0.0),
				Vector3(8.9, 0.85, 5.0), Vector3(8.9, 0.85, 10.0)]:
			_check(_capsule_clear(root, sample), "0.66 m body clear at " + str(sample))
		for sample: Vector3 in [Vector3(-1.5, 4.05, 0.0),
				Vector3(-4.6, 4.05, 0.0), Vector3(-6.2, 4.05, 0.0),
				Vector3(-8.2, 4.05, 0.0), Vector3(-9.2, 4.05, 1.4),
				Vector3(-9.6, 4.05, 4.0), Vector3(-8.4, 4.05, 4.6),
				Vector3(-10.7, 4.05, 7.1)]:
			_check(_capsule_clear(root, sample), "F02 0.66 m body clear at " + str(sample))
		for station: Dictionary in layout.capsule_stations:
			var p: Array = station.position
			var station_sample := Vector3(float(p[0]), float(p[1]) + 9.6, float(p[2]))
			_check(_capsule_clear(root, station_sample),
					"F04 0.66 m body clear at " + str(station.id))
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
	var f02_review := load(F02_REVIEW_PATH) as PackedScene
	_check(f02_review != null, "F02 controller review scene loads explicitly")
	if f02_review != null:
		var f02_review_root := f02_review.instantiate()
		var f02_player := f02_review_root.get_node_or_null("Player") as CharacterBody3D
		_check(f02_player != null and f02_player.position.is_equal_approx(
				Vector3(-1.5, 4.05, 0.0)), "F02 review starts at the landing decision point")
		_check(f02_review_root.get_node_or_null("Player/Head/Camera3D") is Camera3D,
				"F02 review retains the 1.41 m player head")
		f02_review_root.queue_free()
	var f04_review := load(F04_REVIEW_PATH) as PackedScene
	_check(f04_review != null, "F04 controller review scene loads explicitly")
	if f04_review != null:
		var f04_review_root := f04_review.instantiate()
		var f04_player := f04_review_root.get_node_or_null("Player") as CharacterBody3D
		_check(f04_player != null and f04_player.position.is_equal_approx(
				Vector3(-1.5, 10.45, 0.0)), "F04 review starts at the landing decision point")
		_check(f04_review_root.get_node_or_null("Player/Head/Camera3D") is Camera3D,
				"F04 review retains the 1.41 m player head")
		if f04_player != null:
			f04_player.set_physics_process(false)
			add_child(f04_review_root)
			await get_tree().physics_frame
			f04_player.position.y = 9.6
			_check(await _controller_traverse(f04_player, [
					Vector3(-4.6, 9.6, 0.0), Vector3(-5.25, 9.6, 0.0),
					Vector3(-6.45, 9.6, -0.55), Vector3(-8.4, 9.6, -0.4),
					Vector3(-9.9, 9.6, 1.25), Vector3(-10.05, 9.6, 3.8),
					Vector3(-9.85, 9.6, 5.8), Vector3(-9.8, 9.6, 6.75),
					Vector3(-11.1, 9.6, 7.25), Vector3(-11.95, 9.6, 8.9)]),
					"collision-bearing controller continuously traverses landing to bedside return")
		f04_review_root.queue_free()
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

func _route_avoids_space(layout: Dictionary, start: String, goal: String,
		forbidden: String) -> bool:
	var graph := _route_graph(layout)
	var queue: Array[String] = [start]
	var seen := {start: true, forbidden: true}
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == goal:
			return true
		for next: String in graph.get(here, []):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return false

func _f04_rooms_do_not_overlap(layout: Dictionary) -> bool:
	var rooms: Array[Dictionary] = []
	for space: Dictionary in layout.spaces:
		if str(space.id).begins_with("F04_B_"):
			rooms.append(space)
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			if _rect_overlap_area(rooms[i].rect, rooms[j].rect) > 0.0001:
				return false
	return true

func _f04_shared_partitions_owned_once(layout: Dictionary) -> bool:
	var rooms: Array[Dictionary] = []
	for space: Dictionary in layout.spaces:
		if str(space.id).begins_with("F04_B_"):
			rooms.append(space)
	var shared_count := 0
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var shared := _shared_boundary(rooms[i].rect, rooms[j].rect)
			if shared.is_empty():
				continue
			shared_count += 1
			var owners := int(_side_enabled(rooms[i], str(shared.a))) \
					+ int(_side_enabled(rooms[j], str(shared.b)))
			if owners != 1:
				return false
	return shared_count >= 10

func _windows_are_exterior(layout: Dictionary) -> bool:
	var spaces := {}
	for space: Dictionary in layout.spaces:
		spaces[str(space.id)] = space
	for window: Dictionary in layout.windows:
		if not spaces.has(str(window.space)):
			return false
		var space: Dictionary = spaces[str(window.space)]
		var rect: Array = space.rect
		var side := ""
		if str(window.axis) == "x":
			if is_equal_approx(float(window.center[1]), float(rect[1])):
				side = "south"
			elif is_equal_approx(float(window.center[1]), float(rect[3])):
				side = "north"
		else:
			if is_equal_approx(float(window.center[0]), float(rect[0])):
				side = "west"
			elif is_equal_approx(float(window.center[0]), float(rect[2])):
				side = "east"
		if side.is_empty() or not side in space.get("exterior_sides", []):
			return false
	return true

func _f04_doors_valid(layout: Dictionary) -> bool:
	var spaces := {}
	var swing_envelopes := {}
	for space: Dictionary in layout.spaces:
		spaces[str(space.id)] = space
	for envelope: Dictionary in layout.envelopes:
		if envelope.has("door"):
			swing_envelopes[str(envelope.door)] = true
	var count := 0
	for door: Dictionary in layout.doors:
		if str(door.level) != "F04":
			continue
		count += 1
		if not str(door.hinge) in ["left", "right"] or str(door.swing).is_empty():
			return false
		if not swing_envelopes.has(str(door.id)):
			return false
		for room_id: Variant in door.connects:
			if not spaces.has(str(room_id)):
				return false
			var rect: Array = spaces[str(room_id)].rect
			var on_boundary := is_equal_approx(float(door.center[0]), float(rect[0])) \
					or is_equal_approx(float(door.center[0]), float(rect[2])) \
					or is_equal_approx(float(door.center[1]), float(rect[1])) \
					or is_equal_approx(float(door.center[1]), float(rect[3]))
			if not on_boundary:
				return false
	var entry: Dictionary = layout.doors.filter(func(d: Dictionary) -> bool:
		return str(d.id) == "F04_DOOR_03")[0]
	return count == 4 and str(entry.hinge) == "left" \
			and str(entry.swing) == "north_wall" and is_equal_approx(float(entry.width), 0.91)

func _f04_clearances_valid(layout: Dictionary) -> bool:
	var envelopes := {}
	var fixed_use: Array[Dictionary] = []
	var swings: Array[Dictionary] = []
	for envelope: Dictionary in layout.envelopes:
		envelopes[str(envelope.id)] = envelope
		if str(envelope.level) != "F04":
			continue
		if envelope.has("door"):
			swings.append(envelope)
		elif str(envelope.get("class", "")) != "clearance" \
				and str(envelope.id) != "F04_B_WORK_ZONE":
			fixed_use.append(envelope)
	for swing: Dictionary in swings:
		for fixed: Dictionary in fixed_use:
			if _rect_overlap_area(swing.rect, fixed.rect) > 0.0001:
				return false
	var main_clear: Array = envelopes.F04_B_MAIN_CLEAR_FLOOR.rect
	for fixed: Dictionary in fixed_use:
		if _rect_overlap_area(main_clear, fixed.rect) > 0.0001:
			return false
	return is_equal_approx(_rect_area(envelopes.F04_B_VESTIBULE_TURN.rect), 2.25) \
			and is_equal_approx(_rect_area(envelopes.F04_B_MAIN_CLEAR_FLOOR.rect), 12.0) \
			and is_equal_approx(_rect_area(envelopes.F04_B_TERMINAL_STANCE.rect), 1.08) \
			and is_equal_approx(_rect_area(envelopes.F04_B_BEDSIDE_RETURN_CLEARANCE.rect), 1.08)

func _rect_overlap_area(a: Array, b: Array) -> float:
	return maxf(0.0, minf(float(a[2]), float(b[2])) - maxf(float(a[0]), float(b[0]))) \
			* maxf(0.0, minf(float(a[3]), float(b[3])) - maxf(float(a[1]), float(b[1])))

func _rect_area(rect: Array) -> float:
	return (float(rect[2]) - float(rect[0])) * (float(rect[3]) - float(rect[1]))

func _side_enabled(space: Dictionary, side: String) -> bool:
	return side in space.get("wall_sides", ["south", "north", "west", "east"])

func _shared_boundary(a: Array, b: Array) -> Dictionary:
	var z_overlap := minf(float(a[3]), float(b[3])) - maxf(float(a[1]), float(b[1]))
	if z_overlap > 0.001 and is_equal_approx(float(a[2]), float(b[0])):
		return {"a": "east", "b": "west"}
	if z_overlap > 0.001 and is_equal_approx(float(a[0]), float(b[2])):
		return {"a": "west", "b": "east"}
	var x_overlap := minf(float(a[2]), float(b[2])) - maxf(float(a[0]), float(b[0]))
	if x_overlap > 0.001 and is_equal_approx(float(a[3]), float(b[1])):
		return {"a": "north", "b": "south"}
	if x_overlap > 0.001 and is_equal_approx(float(a[1]), float(b[3])):
		return {"a": "south", "b": "north"}
	return {}

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

func _controller_traverse(player: CharacterBody3D, waypoints: Array) -> bool:
	for target: Vector3 in waypoints:
		var frames := 0
		while Vector2(player.position.x - target.x, player.position.z - target.z).length() > 0.10:
			var offset := target - player.position
			offset.y = 0.0
			player.velocity = offset.normalized() * 2.4
			player.velocity.y = -0.1 if player.is_on_floor() else -18.0 / 60.0
			player.move_and_slide()
			await get_tree().physics_frame
			frames += 1
			if frames > 240:
				return false
	return true

func _finish() -> void:
	print("ORISON V2 BLOCKOUT TEST: %s" % (
			"PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)
