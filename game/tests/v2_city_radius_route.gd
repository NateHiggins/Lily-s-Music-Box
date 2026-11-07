extends "res://tests/v2_spatial_access_cohort.gd"
## The eastern endpoint to the real ground-level limit, with an opt-in threshold approach.
const WalkDriver := preload("res://tests/orison_v2_vertical_route_test.gd")
const STANDING_MASK := 1 | preload("res://scripts/building/v2_fire_player_contact.gd").LAYER
const START := Vector3(-280.0, -0.02, -1.65)
const BYPASS_Z := 20.0
const PUBLIC_CORE_START := Vector3(1.925, 0.0, -3.5)
# The outward east arm of the original wide-street tour, including its junction
# at (0, 0, 3). This fixture exercises no west arm, return leg or render timings.
const EAST_APPROACH_WORLD := [
	Vector3(0, 0, 3), Vector3(60, 0, 3), Vector3(140, 0, 3), Vector3(140, 0, -10),
	Vector3(226, 0, -2), Vector3(250, 0, 36), Vector3(252, 0, 38), Vector3(272, 0, 38),
	Vector3(274, 0, 36), Vector3(280, 0, -10),
]
var route: Dictionary = {}
var threshold_mode := false

class RadiusDriver extends WalkDriver:
	var apron: Node3D
	var boundary: Node3D
	var limit: StaticBody3D
	var samples: Array = []
	var phase := ""
	var previous_tick := -1
	var previous_position := Vector3.ZERO
	var max_step_m := 0.0
	var max_radius_m := 0.0
	var missed_ticks := 0
	var unsupported_ticks := 0
	var control_fault_ticks := 0
	var touch_ticks := 0
	var first_touch_radius_m := -1.0
	var physical_recoveries_before := 0
	var entrance_hand: Dictionary = {}
	var approach_floor_owners: Dictionary = {}

	func _ready() -> void:
		process_physics_priority = 100
		super._ready()

	func ground_at(position: Vector3, above: float, below: float, apron_only: bool = true) -> Dictionary:
		var query := PhysicsRayQueryParameters3D.create(
			position + Vector3.UP * above, position - Vector3.UP * below,
			STANDING_MASK, [player.get_rid()])
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		var collider := hit.get("collider") as Node
		if not collider is StaticBody3D or not world.is_ancestor_of(collider):
			return {}
		if apron_only and not apron.is_ancestor_of(collider):
			return {}
		return hit

	func radius_at(position: Vector3) -> float:
		var local := boundary.to_local(position)
		return Vector2(local.x, local.z).length()

	func _physics_process(_delta: float) -> void:
		if phase.is_empty():
			return
		var tick := Engine.get_physics_frames()
		var position := player.global_position
		var distance := radius_at(position)
		if previous_tick >= 0:
			missed_ticks += maxi(0, tick - previous_tick - 1)
			if tick <= previous_tick:
				missed_ticks += 1
			max_step_m = maxf(max_step_m, position.distance_to(previous_position))
		previous_tick = tick
		previous_position = position
		max_radius_m = maxf(max_radius_m, distance)
		var is_approach := phase in ["threshold", "city_approach"]
		var floor := ground_at(position, .16, .22, not is_approach)
		var supported: bool = player.is_on_floor() and not floor.is_empty()
		if not supported:
			unsupported_ticks += 1
		elif is_approach:
			var collider := floor.collider as StaticBody3D
			var path := str(collider.get_path())
			approach_floor_owners[path] = int(approach_floor_owners.get(path, 0)) + 1
		if player.noclip or player.crouched or player.autopilot != Vector3.ZERO 				or player.collision_mask != STANDING_MASK:
			control_fault_ticks += 1
		var touched := false
		for index in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_collider() == limit:
				touched = true
				break
		if touched and phase == "contact":
			touch_ticks += 1
			if first_touch_radius_m < 0.0:
				first_touch_radius_m = distance
		var local: Vector3 = world.adapter.root.to_local(position)
		samples.append([tick, phase, local.x, local.y, local.z, distance, supported,
			touched, Input.is_action_pressed("move_forward")])

	func fixture(from_threshold: bool) -> bool:
		var start: Vector3 = PUBLIC_CORE_START if from_threshold else START
		var position: Vector3 = world.adapter.root.to_global(start)
		var floor := ground_at(position, .25, .25, not from_threshold)
		if floor.is_empty() or (floor.normal as Vector3).dot(Vector3.UP) < .98:
			return false
		var capsule := CapsuleShape3D.new()
		capsule.radius = PlayerController.BODY_RADIUS
		capsule.height = PlayerController.STANDING_HEIGHT
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = STANDING_MASK
		query.margin = 0.0
		query.exclude = [player.get_rid()]
		query.transform = Transform3D(Basis.IDENTITY,
			(floor.position as Vector3) + Vector3.UP * (.03 + capsule.height * .5))
		if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
		player.global_position = (floor.position as Vector3) + Vector3.UP * .03
		player.velocity = Vector3.ZERO
		return true

	func walk_to_station(x: float, z: float, expected_y: float) -> bool:
		var root: Node3D = world.adapter.root
		var hit := ground_at(root.to_global(Vector3(x, expected_y, z)), .25, .25)
		if hit.is_empty() or absf(root.to_local(hit.position).y - expected_y) > .09:
			failures.append("Expected dry apron at %s" % str(Vector3(x, expected_y, z)))
			return false
		var reached := await _walk(root.to_local(hit.position))
		return reached

	func _open_front_entrance(identity: String = "F01_DOOR_06") -> bool:
		var anchor := world.adapter.resolve(identity) as Node3D
		var door: DoorProp = anchor.get_node_or_null(identity + "_Leaf") as DoorProp if anchor != null else null
		if door == null or door.open or door._moving:
			failures.append("Expected the actual closed Orison entrance before hand operation")
			return false
		var closed_angle := door._body.rotation.y
		var operated := await super._open_front_entrance(identity)
		var released: bool = not player._grab.active()
		entrance_hand = {"identity":identity, "closed_before":true, "closed_angle_rad":closed_angle,
			"opened_through_inherited_hand":operated, "open_after":door.open, "released":released,
			"open_angle_rad":door._body.rotation.y}
		if not released:
			failures.append("Orison entrance hand did not release")
		return operated and released

	func walk_from_threshold() -> bool:
		phase = "threshold"
		if not await _leave_front_entrance():
			return false
		phase = "city_approach"
		var root: Node3D = world.adapter.root
		for point: Vector3 in EAST_APPROACH_WORLD:
			var local: Vector3 = root.to_local(point)
			local.y = START.y
			if not await _walk(local):
				return false
		return true

	func observe_walk(radius: float) -> void:
		var center := (world.adapter.root as Node3D).to_local(boundary.global_position)
		var offset := BYPASS_Z - center.z
		if absf(offset) > 60.0:
			failures.append("Radius frame does not align with the eastern apron corridor")
			return
		var contact_x := center.x - sqrt((radius + 2.0) ** 2 - offset ** 2)
		var inner_x := center.x - sqrt((radius - 1.2) ** 2 - offset ** 2)
		var retreat_x := center.x - sqrt((radius - 4.0) ** 2 - offset ** 2)
		phase = "outbound"
		# The real toe wall spans local z=-16..16 at x=-321.4..-319.4.
		# Shift to z=20 before descending the authored east shoulder.
		for point: Vector3 in [
				Vector3(-296.0, -.02, START.z), Vector3(-296.0, -.02, BYPASS_Z),
				Vector3(-310.0, -.02, BYPASS_Z), Vector3(-320.0, -3.50, BYPASS_Z),
				Vector3(-350.0, -3.50, BYPASS_Z), Vector3(-390.0, -3.50, BYPASS_Z),
				Vector3(-430.0, -3.50, BYPASS_Z), Vector3(inner_x, -3.50, BYPASS_Z)]:
			if not await walk_to_station(point.x, point.z, point.y):
				phase = ""
				return
		phase = "contact"
		var target: Vector3 = world.adapter.root.to_global(Vector3(contact_x, -3.50, BYPASS_Z))
		var direction := target - player.global_position
		player.rotation.y = atan2(-direction.x, -direction.z)
		player.camera.rotation = Vector3.ZERO
		Input.action_press("move_forward")
		for tick in Engine.physics_ticks_per_second:
			await get_tree().physics_frame
		Input.action_release("move_forward")
		await get_tree().physics_frame
		phase = "retreat"
		await walk_to_station(retreat_x, BYPASS_Z, -3.50)
		phase = ""

func _run() -> void:
	var scope := OS.get_environment("ORISON_CITY_RADIUS_SCOPE")
	if scope not in ["", "suffix", "threshold"]:
		push_error("Unknown ORISON_CITY_RADIUS_SCOPE: " + scope)
		get_tree().quit(64)
		return
	threshold_mode = scope == "threshold"
	initial_inputs = _inputs()
	bindings = _dependencies()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	_check(CampaignClock.new().configure_date(1928, 10, 15, 12 * 60 + 30), "valid daytime fixture")
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	Selector.reset_for_tests("v2")
	var world := (load(Selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not world.startup_failed and world.player != null, "production-selected V2 composition starts")
	var held := [weakref(world)]
	if failures == 0:
		var driver := RadiusDriver.new()
		held.append(weakref(driver))
		driver.externally_managed = true
		driver.world = world
		driver.player = world.player
		driver.route_label = "V2 CITY EASTERN GROUND LIMIT"
		driver.apron = world.adapter.root.get_node("Ground").find_child("DistantApron", true, false) as Node3D
		driver.boundary = world.get_node_or_null("StreetBoundaries") as Node3D
		if driver.boundary != null:
			driver.limit = driver.boundary.get_node_or_null("TemporaryExteriorLimit") as StaticBody3D
		_check(driver.apron != null and driver.limit != null, "actual terrain and radial wall owners exist")
		add_child(driver)
		if failures == 0:
			await _run_ground_leg(driver)
		driver.free()
	Input.action_release("move_forward")
	world.shutdown_for_tests()
	world.free()
	await get_tree().process_frame
	var retained := 0
	for ref: WeakRef in held:
		if ref.get_ref() != null:
			retained += 1
	_check(retained == 0 and held.size() == 2, "production root and route observer retire")
	var final_inputs := _inputs()
	_check(initial_inputs == final_inputs and bindings == _dependencies(), "production inputs and test closure stay fixed")
	_write_radius_receipt(retained, final_inputs)
	print("V2 CITY EASTERN GROUND LIMIT: ", "PASS" if failures == 0 else "FAIL", "; ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func _run_ground_leg(driver: RadiusDriver) -> void:
	var limit := driver.limit
	var radius := float(limit.get_meta("radius_m", 0.0))
	var layer := limit.collision_layer
	var shape := limit.get_node("RadialWall") as CollisionShape3D
	var shape_rid := shape.shape.get_rid()
	_check(is_equal_approx(radius, 450.0) and (layer & STANDING_MASK) != 0, "original 450 m radial collision is active")
	_check(driver.fixture(threshold_mode), "single public-core start has actual floor and full capsule clearance"
		if threshold_mode else "single historical eastern start has actual floor and full capsule clearance")
	if failures > 0:
		return
	driver.player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for tick in 12:
		await get_tree().physics_frame
	_check(driver.player.is_on_floor() and not driver.player.noclip and not driver.player.crouched
		and is_equal_approx(driver.player._capsule.height, PlayerController.STANDING_HEIGHT)
		and is_equal_approx(driver.player._capsule.radius, PlayerController.BODY_RADIUS)
		and driver.player.collision_mask == STANDING_MASK, "normal full standing controller starts grounded")
	if failures > 0:
		return
	var start_radius := driver.radius_at(driver.player.global_position)
	var start_position: Vector3 = driver.world.adapter.root.to_local(driver.player.global_position)
	var approach_reached := true
	driver.physical_recoveries_before = driver.world.safety_net.recoveries
	if threshold_mode:
		_check(start_radius < 10.0, "settled public-core start is within 10 m of the Orison threshold")
		if failures == 0:
			approach_reached = await driver.walk_from_threshold()
		else:
			approach_reached = false
		_check(approach_reached and not driver.entrance_hand.is_empty(),
			"actual Orison front leaf opens through the player hand and the player walks through")
	var join_radius := driver.radius_at(driver.player.global_position)
	_check(approach_reached and join_radius >= 279.7 and join_radius <= 281.0,
		"walked from the Orison threshold to the historical 280 m corridor station" if threshold_mode
		else "placed at the historical 280 m corridor station")
	if failures == 0:
		await driver.observe_walk(radius)
	driver.phase = ""
	var end_radius := driver.radius_at(driver.player.global_position)
	var recoveries_after := driver.world.safety_net.recoveries
	var expected_waypoints := 9 + (4 + EAST_APPROACH_WORLD.size() if threshold_mode else 0)
	_check(driver.failures.is_empty() and driver.trace.size() == expected_waypoints,
		"continuous entrance, eastern approach, apron and inward retreat complete" if threshold_mode
		else "eight continuous outbound waypoints and inward retreat complete")
	_check(driver.samples.size() >= 1000 and driver.missed_ticks == 0 and driver.max_step_m <= .2,
		"consecutive physics poses exclude repositioning during the route")
	_check(driver.unsupported_ticks == 0 and driver.control_fault_ticks == 0 and recoveries_after == driver.physical_recoveries_before,
		"every sampled pose uses actual world support, full collision, normal control and no rescue" if threshold_mode
		else "every sampled pose uses actual apron support, full collision, normal control and no rescue")
	_check(driver.touch_ticks >= 3 and driver.first_touch_radius_m >= radius - .6
		and driver.max_radius_m <= radius + .01 and driver.max_radius_m >= radius - .6,
		"repeated actual radial-wall contact stops normal movement inside the boundary")
	_check(end_radius < radius - 3.8 and limit.collision_layer == layer and shape.shape.get_rid() == shape_rid,
		"controller retreats from the unchanged physical boundary")
	route = {"initial_placement_only":true,"start_radius_m":start_radius,"end_radius_m":end_radius,
		"maximum_radius_m":driver.max_radius_m,"maximum_tick_step_m":driver.max_step_m,
		"first_contact_radius_m":driver.first_touch_radius_m,"contact_ticks":driver.touch_ticks,
		"missed_ticks":driver.missed_ticks,"unsupported_ticks":driver.unsupported_ticks,
		"control_fault_ticks":driver.control_fault_ticks,"recoveries_before":driver.physical_recoveries_before,
		"recoveries_after":recoveries_after,"boundary_layer":layer,"boundary_path":str(limit.get_path()),
		"trace":driver.trace,"driver_failures":driver.failures,"physics_samples":driver.samples,
		"sample_columns":["physics_frame","phase","local_x","local_y","local_z","horizontal_radius_m",
			"actual_ground_support","actual_boundary_contact","forward_action"]}
	if threshold_mode:
		route["public_core_start_local"] = [start_position.x, start_position.y, start_position.z]
		route["eastern_join_radius_m"] = join_radius
		route["entrance_hand"] = driver.entrance_hand
		route["approach_floor_owners"] = driver.approach_floor_owners

func _write_radius_receipt(retained: int, inputs: Dictionary) -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array = []
	_check(OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head) == 0, "record repository provenance")
	var directory := OS.get_environment("SHOT_DIR")
	_check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory) == OK, "explicit receipt destination")
	if directory.is_empty():
		return
	var file := FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE)
	_check(file != null, "open ground route receipt")
	if file == null:
		return
	var status := "PASS" if failures == 0 else "FAIL"
	var entry: String = "game/" + get_script().resource_path.trim_prefix("res://")
	file.store_string(JSON.stringify({
		"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"One explicit public-core start, actual Orison entrance hand and threshold crossing, historical eastward street route, dry apron to the physical 450 m wall and short retreat. No bridge travel, disk saves, frame-time or artistic claim." if threshold_mode
			else "Single explicit nearby historical 280 m endpoint, dry eastern apron, normal movement to physical 450 m wall and short retreat. No threshold-to-boundary continuity, bridge travel, disk saves, frame-time or artistic claim.",
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false,
			"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":entry,"test_sha256":bindings.get(entry,""),"test_dependencies":bindings,
			"scene_path":scene_file_path,"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "",
			"runtime_inputs_sha256":inputs.runtime,"surface_inputs_sha256":inputs.surface},
		"checks":checks,"failures":failures,
		"contracts":{"east_ground_limit":{"executed":not route.is_empty(),"status":status,"route":route},
			"teardown":{"executed":true,"status":"PASS" if retained==0 else "FAIL","retained_nodes":retained}}
	}, "\t"))
	file.flush()
	if file.get_error() != OK:
		failures += 1
		push_error("Ground route receipt did not flush")
