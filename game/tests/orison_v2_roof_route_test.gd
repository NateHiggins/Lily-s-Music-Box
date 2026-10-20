extends "res://tests/orison_v2_4b_door_route_test.gd"
## One initial F06 placement. Production input/collision thereafter, including
## both roof doors, both stair flights, deck seams and solid perimeter barriers.

func _init() -> void:
	route_label = "ROOF ROUTE"

func _prepare_player_start() -> void:
	var carrier := player.carried_device as ServiceSetCarrier
	if _require(carrier != null, "production handheld carrier is available for unobstructed roof review"):
		carrier.set_capture_hidden(true)
	player.global_position = world.adapter.root.to_global(Vector3(1.925, 16.02, -3.5))
	player.velocity = Vector3.ZERO

func _walk(target: Vector3) -> bool:
	# The formed fire case and riser occupy the former nominal corner. Follow
	# the measured standing corridor across the existing solid landing instead
	# of pressing through the cabinet or against the east bulkhead wall.
	if target.is_equal_approx(Vector3(5,19.2,-3.4)):
		var from: Vector3=world.adapter.root.to_local(player.global_position)
		var detour: Array[Vector3]=[Vector3(3.975,19.2,-3.0),Vector3(4.9,19.2,-3.0)]
		if from.z>-2.:detour.reverse()
		for point: Vector3 in detour:
			if not await _walk_fitted_floor(point):return false
		return true
	if target.is_equal_approx(Vector3(5,19.2,2.5)):target.x=4.9
	return await _walk_fitted_floor(target)

func _walk_fitted_floor(target: Vector3) -> bool:
	if target.y>19.15 and target.y<19.25:
		var root: Node3D=world.adapter.root
		var query:=PhysicsRayQueryParameters3D.create(root.to_global(Vector3(target.x,19.7,target.z)),root.to_global(Vector3(target.x,19.,target.z)),1,[player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		var valid_floor:=not hit.is_empty() and "/Floor/Collision" in str(root.get_path_to(hit.collider))
		for platform: Dictionary in world.layout.platforms:
			if absf(float(root.level_y[str(platform.level)])-target.y)<.001 and not hit.is_empty() and hit.collider==root.get_node(str(platform.id)+"/Collision"):valid_floor=true
		if not _require(valid_floor,"retained route has its actual fitted floor at "+str(target)):return false
		target.y=root.to_local(hit.position).y
	return await super._walk(target)

func _route() -> void:
	for point in [Vector3(1.925,17.6,1.3), Vector3(3.975,17.6,1.3),
			Vector3(3.975,19.2,-3.4), Vector3(5.0,19.2,-3.4),
			Vector3(5.0,19.2,2.5), Vector3(-1.35,19.2,2.5), Vector3(-1.35,19.2,0)]:
		if not await _walk(point): return
	if not await _open_door("ROOF_PUBLIC_DOOR"): return
	if not await _walk(Vector3(-3.9,19.2,0)): return
	await _roof_capture("public_bulkhead", Vector3(2,20.5,0))
	if not await _close_door("ROOF_PUBLIC_DOOR"): return
	if not await _walk(Vector3(-14.5,19.2,0)): return
	var outward: Vector3 = world.adapter.root.global_basis * Vector3.LEFT
	player.rotation.y = atan2(-outward.x, -outward.z)
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_forward")
	await get_tree().physics_frame
	var stopped: Vector3 = world.adapter.root.to_local(player.global_position)
	if not _require(stopped.x > -15.3 and stopped.x < -15.0 and absf(stopped.y - 19.2) < .15,
			"live player is stopped by the west parapet above the street"): return
	# Retain the night arrival above, then inspect the full architectural shell
	# under the production morning sky, without adding a test-only fill light.
	if not _require(world.campaign_clock.advance_to(12 * 60)
			and is_equal_approx(world.campaign_clock.minute_of_day(), 8 * 60),
			"campaign advances from 20:00 to the next 08:00"): return
	# The production director samples the campaign clock every eight seconds.
	await get_tree().create_timer(8.1).timeout
	await _roof_capture("roof_morning_west", Vector3(2,20.4,0))
	if not await _service_tank(): return
	for point in [Vector3(-12,19.2,0), Vector3(-12,19.2,-9),
			Vector3(0,19.2,-9), Vector3(14,19.2,-9),
			Vector3(14,19.2,10.8), Vector3(7.5,19.2,10.8),
			Vector3(0,19.2,7), Vector3(-7,19.2,7),
			Vector3(7.5,19.2,7), Vector3(7.5,19.2,3), Vector3(8.0,19.2,3)]:
		if not await _walk(point): return
	await _roof_capture("roof_deck", Vector3(-7,20.2,-4))
	if not await _open_door("ROOF_SERVICE_DOOR"): return
	for point in [Vector3(10.3,19.2,3), Vector3(12.425,19.2,3),
			Vector3(12.425,19.2,5.65), Vector3(12.425,17.6,9.15),
			Vector3(11.075,17.6,9.15), Vector3(11.075,16,4.3),
			Vector3(11.075,17.6,9.15), Vector3(12.425,17.6,9.15),
			Vector3(12.425,19.2,5.65), Vector3(12.425,19.2,3),
			Vector3(10.3,19.2,3), Vector3(7.8,19.2,3)]:
		if not await _walk(point): return
	if not await _close_door("ROOF_SERVICE_DOOR"): return
	# Ray checks include the real collider and height; a visible trim mesh is
	# insufficient protection at the edge of a six-storey roof.
	for identity in ["SOUTH", "NORTH", "WEST", "EAST"]:
		var wall := world.adapter.root.get_node("ROOF_PARAPET_" + identity) as Node3D
		var inward := Vector3.BACK if identity == "SOUTH" else Vector3.FORWARD if identity == "NORTH" else Vector3.RIGHT if identity == "WEST" else Vector3.LEFT
		var at: Vector3 = wall.position
		var ray := PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(at + inward), world.adapter.root.to_global(at - inward), 1)
		ray.exclude = [player.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not _require(hit.get("collider") == wall.get_node("Collision"), "solid roof edge " + identity): return
	for point in [Vector3(7,19.2,-6),Vector3(14.1,19.2,-6),Vector3(14.1,19.2,2.15)]:
		if not await _walk(point): return
	var flue = world.adapter.root.get_node("BoilerFlue")
	await _roof_capture("chimney_termination",flue.chimney_top)
	var mouth := PhysicsRayQueryParameters3D.create(flue.to_global(flue.chimney_top+Vector3.UP*.3),
			flue.to_global(flue.chimney_top-Vector3.UP*.5),1)
	mouth.exclude = [player.get_rid()]
	if not _require(world.get_world_3d().direct_space_state.intersect_ray(mouth).is_empty(),
			"chimney mouth remains open above the structural shaft"): return
	var wall_ray := PhysicsRayQueryParameters3D.create(flue.to_global(flue.chimney_base+Vector3(-1,1,0)),
			flue.to_global(flue.chimney_base+Vector3(1,1,0)),1)
	wall_ray.exclude = [player.get_rid()]
	var chimney_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(wall_ray)
	if not _require(not chimney_hit.is_empty() and chimney_hit.collider.get_parent()==flue,
			"chimney masonry has actual collision"): return
	for point in [Vector3(14.1,19.2,-6),Vector3(7,19.2,-6),Vector3(-4,19.2,-6), Vector3(-3.9,19.2,0)]:
		if not await _walk(point): return
	if not await _open_door("ROOF_PUBLIC_DOOR"): return
	for point in [Vector3(-1.35,19.2,0), Vector3(-1.35,19.2,2.5),
			Vector3(5.0,19.2,2.5), Vector3(5.0,19.2,-3.4), Vector3(3.975,19.2,-3.4),
			Vector3(3.975,17.6,1.3), Vector3(1.925,17.6,1.3), Vector3(1.925,16,-3.5)]:
		if not await _walk(point): return
	_require(not player.noclip and player.collision_mask == 1, "roof circuit returns to F06 with collision active")

func _service_tank() -> bool:
	if not await _walk(Vector3(-12,19.2,0)): return false
	await _roof_capture("tank_and_bulkhead", Vector3(-7,21.2,-4))
	for point in [Vector3(-9.4,19.2,0), Vector3(-9.4,19.2,-3.05)]:
		if not await _walk(point): return false
	var cock := world.adapter.resolve("ROOF_TANK_BALLCOCK") as RoofTankBallcockProp
	if not _require(cock != null and cock.overflow_running(), "roof has the production overflowing ballcock"): return false
	await _roof_capture("tank_approach", Vector3(-8.6,21.1,-5.7))
	var hand := preload("res://tests/roof_tank_hand_test.gd").new()
	hand.batch_mode=true
	hand.player=player
	hand.tank=cock
	add_child(hand)
	await hand.exercise()
	var passed: bool=hand.failures==0
	hand.queue_free()
	if not _require(passed,"installed tank repair uses actual grabbing, motion, release and inspection"): return false
	await _roof_capture("tank_serviced", Vector3(-8.6,21.1,-5.7))
	for point in [Vector3(-11,19.2,-3.05), Vector3(-11,19.2,-4.95)]:
		if not await _walk(point): return false
	var toward: Vector3 = world.adapter.root.global_basis * Vector3.RIGHT
	player.rotation.y = atan2(-toward.x,-toward.z)
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_forward")
	var at: Vector3 = world.adapter.root.to_local(player.global_position)
	if not _require(at.x < -10.0 and at.x > -10.2 and absf(at.y-19.2)<.15,
			"tank support stops the real upright controller: " + str(at)): return false
	var tank := world.adapter.root.get_node("ROOF_TANK_BODY") as Node3D
	# Between the iron bands, so the first hit is the timber body itself.
	var body_ray := PhysicsRayQueryParameters3D.create(tank.to_global(Vector3(-2,.25,0)),tank.to_global(Vector3(2,.25,0)),1)
	if not _require(world.get_world_3d().direct_space_state.intersect_ray(body_ray).get("collider") == tank.get_node("Collision"),
			"raised tank body has matching solid collision"): return false
	for index in 4:
		var leg := world.adapter.root.get_node("ROOF_TANK_LEG_" + str(index)) as Node3D
		var ray := PhysicsRayQueryParameters3D.create(leg.to_global(Vector3(-.5,0,0)),leg.to_global(Vector3(.5,0,0)),1)
		ray.exclude = [player.get_rid()]
		if not _require(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == leg.get_node("Collision"),
				"tank support is solid " + str(index)): return false
	return await _walk(Vector3(-12,19.2,-5.7))

func _roof_capture(label: String, local_target: Vector3) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	player.camera.look_at(world.adapter.root.to_global(local_target))
	# The carried lamp follows the gaze physically; allow it to settle before
	# judging a surface that was behind the previous walking direction.
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
