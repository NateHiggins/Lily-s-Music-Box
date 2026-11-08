extends "res://tests/v2_spatial_access_cohort.gd"
## The eastern street to the real limit of the walkable city, with an opt-in
## threshold approach. Since Lily's ruling barrier_distance (2026-11-07) that
## limit is the city edge mist: walking east, she passes out at 200 m from the
## front door and wakes at the 4B bedside, never reaching the 205 m backstop
## wall (whose geometry OrisonV2SpatialOwnershipTest proves).
const WalkDriver := preload("res://tests/orison_v2_vertical_route_test.gd")
const STANDING_MASK := 1 | preload("res://scripts/building/v2_fire_player_contact.gd").LAYER
const START := Vector3(-280.0, -0.02, -1.65) # Only its ground height is used now.
const Mist := preload("res://scripts/building/orison_v2_city_edge_mist.gd")
const PUBLIC_CORE_START := Vector3(1.925, 0.0, -3.5)
# The outward east arm of the original wide-street tour, up to its junction at
# (140, 0, -10). The edge leg then heads for the tour's next station (226, 0, -2)
# and the mist takes her about 200 m out, near x=200.
const EAST_APPROACH_WORLD := [
	Vector3(0, 0, 3), Vector3(60, 0, 3), Vector3(140, 0, 3), Vector3(140, 0, -10),
]
const EDGE_HEADING_WORLD := Vector3(226, 0, -2)
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
	# The graded street has kerbs (the street ends at a 0.15 m kerb about 148 m
	# out). The controller's own step-up lifts her over each and she settles for
	# a few ticks. Each short airborne spell is a kerb spell, recorded with its
	# rise and drop; a spell longer than KERB_SPELL_TICKS is lost support.
	const KERB_SPELL_TICKS := 30
	var kerb_steps := 0
	var kerb_settle_ticks := 0
	var max_rise_m := 0.0
	var max_drop_m := 0.0
	var spell_ticks := 0
	var spell_top := 0.0
	var control_fault_ticks := 0
	var touch_ticks := 0
	var mist: OrisonV2CityEdgeMist
	var took_radius_m := -1.0
	var mist_never_fell := true
	var prior_mist := -1.0
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
			max_step_m = maxf(max_step_m, Vector2(position.x - previous_position.x,
				position.z - previous_position.z).length())
			max_rise_m = maxf(max_rise_m, position.y - previous_position.y)
		previous_tick = tick
		previous_position = position
		max_radius_m = maxf(max_radius_m, distance)
		var floor := ground_at(position, .16, .22, false)
		var supported: bool = player.is_on_floor() and not floor.is_empty()
		if not supported and spell_ticks < KERB_SPELL_TICKS:
			if spell_ticks == 0:
				kerb_steps += 1
				spell_top = position.y
			spell_top = maxf(spell_top, position.y)
			spell_ticks += 1
			kerb_settle_ticks += 1
		elif not supported:
			unsupported_ticks += 1
		else:
			if spell_ticks > 0:
				max_drop_m = maxf(max_drop_m, spell_top - position.y)
			spell_ticks = 0
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
		if touched:
			touch_ticks += 1
		if mist != null and phase == "edge":
			if mist.mist() + .0001 < prior_mist and distance > Mist.MIST_START_M:
				mist_never_fell = false
			prior_mist = mist.mist()
		var local: Vector3 = world.adapter.root.to_local(position)
		samples.append([tick, phase, local.x, local.y, local.z, distance, supported,
			touched, Input.is_action_pressed("move_forward")])

	func fixture(from_threshold: bool) -> bool:
		var start: Vector3 = PUBLIC_CORE_START
		if not from_threshold:
			start = world.adapter.root.to_local(EAST_APPROACH_WORLD.back())
			start.y = START.y
		var position: Vector3 = world.adapter.root.to_global(start)
		var floor := ground_at(position, .25, .25, false)
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

	## Normal forward input toward the tour's next station until the mist takes
	## her. Sampling stops at the pass-out: the bedside move is the mist's, not
	## a route step.
	func walk_to_edge() -> void:
		phase = "edge"
		var target: Vector3 = EDGE_HEADING_WORLD
		for tick in Engine.physics_ticks_per_second * 40:
			if mist.phase() != "clear":
				took_radius_m = radius_at(player.global_position)
				break
			var direction := target - player.global_position
			direction.y = 0.0
			player.rotation.y = atan2(-direction.x, -direction.z)
			player.camera.rotation = Vector3.ZERO
			Input.action_press("move_forward")
			await get_tree().physics_frame
		phase = ""
		Input.action_release("move_forward")

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
			driver.mist = driver.boundary.get_node_or_null("CityEdgeMist") as OrisonV2CityEdgeMist
		_check(driver.apron != null and driver.limit != null and driver.mist != null, "actual terrain, edge mist and backstop wall owners exist")
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
	var wall_m := float(limit.get_meta("radius_m", 0.0))
	_check(is_equal_approx(Mist.PASS_OUT_M, 200.0) and wall_m > Mist.PASS_OUT_M and wall_m <= Mist.PASS_OUT_M + 10.0
		and (limit.collision_layer & STANDING_MASK) != 0, "the 200 m edge mist stands inside its physical backstop wall")
	_check(driver.fixture(threshold_mode), "single public-core start has actual floor and full capsule clearance"
		if threshold_mode else "single eastern street start at the tour junction has actual floor and full capsule clearance")
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
	var loop_before: Dictionary = driver.world.core_loop.loop_state()
	if threshold_mode:
		_check(start_radius < 10.0, "settled public-core start is within 10 m of the Orison threshold")
		if failures == 0:
			approach_reached = await driver.walk_from_threshold()
		else:
			approach_reached = false
		_check(approach_reached and not driver.entrance_hand.is_empty(),
			"actual Orison front leaf opens through the player hand and the player walks through")
	var join_radius := driver.radius_at(driver.player.global_position)
	_check(approach_reached and join_radius >= 139.0 and join_radius <= 142.0,
		"walked from the Orison threshold to the eastern tour junction" if threshold_mode
		else "placed at the eastern tour junction")
	if failures == 0:
		await driver.walk_to_edge()
	var recoveries_after := driver.world.safety_net.recoveries
	_check(driver.took_radius_m >= Mist.PASS_OUT_M and driver.took_radius_m < Mist.PASS_OUT_M + 1.0,
		"walking east with normal input, the mist takes her at the 200 m ring")
	_check(driver.mist_never_fell, "the mist thickens steadily along the street")
	_check(driver.touch_ticks == 0 and driver.max_radius_m < wall_m, "she never reaches the backstop wall")
	_check(driver.failures.is_empty() and driver.trace.size() == (4 + EAST_APPROACH_WORLD.size() if threshold_mode else 0),
		"continuous entrance and eastern street approach complete" if threshold_mode else "no route step precedes the edge leg")
	_check(driver.samples.size() >= 600 and driver.missed_ticks == 0 and driver.max_step_m <= .2,
		"consecutive physics poses exclude horizontal repositioning before the pass-out")
	_check(driver.unsupported_ticks == 0 and driver.control_fault_ticks == 0 and recoveries_after == driver.physical_recoveries_before,
		"every sampled pose uses actual world support, full collision, normal control and no rescue")
	_check(driver.kerb_steps <= 8 and driver.max_rise_m <= .35 and driver.max_drop_m <= .5,
		"the only airborne poses are short kerb spells: under 0.35 m up and 0.5 m down")
	var waking := 0
	while driver.mist.phase() != "clear" and waking < Engine.physics_ticks_per_second * 15:
		await get_tree().physics_frame
		waking += 1
	var bedside: Dictionary = driver.world.core_loop.resolve_return_anchor()
	var at_bed := INF
	if not bedside.is_empty():
		at_bed = Vector2(driver.player.global_position.x - bedside.position.x,
			driver.player.global_position.z - bedside.position.z).length()
	_check(driver.mist.phase() == "clear" and driver.mist.last_wake_ok() and at_bed < .25 and not driver.player.call_locked,
		"she wakes standing free at the 4B bedside")
	_check(driver.world.core_loop.loop_state() == loop_before, "the pass-out writes no campaign loop state")
	route = {"initial_placement_only":true,"start_radius_m":start_radius,"join_radius_m":join_radius,
		"pass_out_radius_m":driver.took_radius_m,"backstop_wall_m":wall_m,
		"maximum_radius_m":driver.max_radius_m,"maximum_tick_step_m":driver.max_step_m,
		"wall_contact_ticks":driver.touch_ticks,"kerb_steps":driver.kerb_steps,
		"kerb_settle_ticks":driver.kerb_settle_ticks,"maximum_kerb_rise_m":driver.max_rise_m,"maximum_kerb_drop_m":driver.max_drop_m,"missed_ticks":driver.missed_ticks,"unsupported_ticks":driver.unsupported_ticks,
		"control_fault_ticks":driver.control_fault_ticks,"recoveries_before":driver.physical_recoveries_before,
		"recoveries_after":recoveries_after,"bedside_distance_m":at_bed,
		"trace":driver.trace,"driver_failures":driver.failures,"physics_samples":driver.samples,
		"floor_owners":driver.approach_floor_owners,
		"sample_columns":["physics_frame","phase","local_x","local_y","local_z","horizontal_radius_m",
			"actual_ground_support","actual_boundary_contact","forward_action"]}
	if threshold_mode:
		route["public_core_start_local"] = [start_position.x, start_position.y, start_position.z]
		route["entrance_hand"] = driver.entrance_hand

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
		"scope":"One explicit public-core start, actual Orison entrance hand and threshold crossing, eastward street route to the tour junction, normal walking east until the city edge mist takes her at 200 m, and the 4B bedside wake. No bridge travel, disk saves, frame-time or artistic claim." if threshold_mode
			else "Single explicit placement at the eastern tour junction (about 140 m), normal walking east until the city edge mist takes her at 200 m, and the 4B bedside wake. No threshold continuity, bridge travel, disk saves, frame-time or artistic claim.",
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
