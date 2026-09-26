extends "res://tests/orison_v2_4b_door_route_test.gd"
## One initial F06 placement. Production input/collision thereafter, including
## both roof doors, both stair flights, deck seams and solid perimeter barriers.

func _init() -> void:
	route_label = "ROOF ROUTE"

func _prepare_player_start() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(2.3, 16.02, -3.5))
	player.velocity = Vector3.ZERO

func _route() -> void:
	for point in [Vector3(2.3,17.6,1.3), Vector3(3.8,17.6,1.3),
			Vector3(3.8,19.2,-3.4), Vector3(1.5,19.2,-3.4),
			Vector3(1.5,19.2,0), Vector3(-1.35,19.2,0)]:
		if not await _walk(point): return
	if not await _open_door("ROOF_PUBLIC_DOOR"): return
	if not await _walk(Vector3(-3.6,19.2,0)): return
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
			Vector3(10.3,19.2,3), Vector3(8.1,19.2,3)]:
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
	for point in [Vector3(7,19.2,-6), Vector3(-4,19.2,-6), Vector3(-3.4,19.2,0)]:
		if not await _walk(point): return
	if not await _open_door("ROOF_PUBLIC_DOOR"): return
	for point in [Vector3(-1.35,19.2,0), Vector3(1.5,19.2,0),
			Vector3(1.5,19.2,-3.4), Vector3(3.8,19.2,-3.4),
			Vector3(3.8,17.6,1.3), Vector3(2.3,17.6,1.3), Vector3(2.3,16,-3.5)]:
		if not await _walk(point): return
	_require(not player.noclip and player.collision_mask == 1, "roof circuit returns to F06 with collision active")

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
