extends "res://tests/orison_v2_passage_route_test.gd"
## Two continuous routes cover all eleven retained shop thresholds. Each
## remains below the serial lane ceiling with actual player input and capture.

@export var side := "west"

func _init() -> void:
	route_label = "V2 ARCADE SHOP ROUTE"

func _route() -> void:
	var passage := world.passage_region
	var hours := passage.finish.hours_director
	if not _require(side in ["west", "east"] and passage.cell_nodes.size() == 13
			and passage.doors.size() == 11, "complete retained arcade roster"): return
	if not await _leave_front_entrance():return
	var outward := [Vector3(0,0,3), Vector3(14,0,3), Vector3(14,0,4.2),
		Vector3(14,-.1,8), Vector3(14,-.1,13.6), Vector3(14,0,15),
		Vector3(14,0,17.3), Vector3(14,0,20), Vector3(14,0,27.5), Vector3(14,0,32)]
	for point in outward:
		if not await _walk_world(point): return
	var ids: Array = []
	for identity: String in passage.doors:
		var door: DoorProp = passage.doors[identity]
		if (door.global_position.x < 14) == (side == "west"): ids.append(identity)
	ids.sort_custom(func(a, b): return passage.doors[a].global_position.z < passage.doors[b].global_position.z)
	if not _require(ids.size() == (5 if side == "west" else 6), "source shop distribution " + side): return
	var leaf_ids := {}
	for identity: String in ids:
		var door: DoorProp = passage.doors[identity]
		leaf_ids[identity] = door.get_instance_id()
		if not await _visit_shop(identity, door): return
	# Advance the existing campaign monotonically from 20:00 to 03:00.
	# Reinitializing the clock here would invalidate durable shop cursors.
	if not _require(world.campaign_clock.advance_to(7 * 60)
			and world.shop_simulation.advance_current(), "existing campaign reaches closed hours"): return
	hours.apply_for_minute(ScheduleDirector.minute_now())
	await get_tree().physics_frame
	if not _require(hours.is_after_hours(), "authored night grilles are active"): return
	if not _grilles_clear_leaf_poses(hours, passage.doors): return
	ids.reverse()
	for identity: String in ids:
		var door: DoorProp = passage.doors[identity]
		var centre := door.to_global(Vector3(door.width * .5,0,0))
		if not await _walk_world(Vector3(14,.01,centre.z)): return
		await _clean_capture("night_" + identity, centre + Vector3.UP * 1.4)
		if identity == "SITE_SHOP_DOOR_HARDWARE_PAINT": continue
		var west := centre.x < 14
		var ray := PhysicsRayQueryParameters3D.create(centre + Vector3(1 if west else -1,1.1,0),
			centre + Vector3(-1 if west else 1,1.1,0))
		ray.exclude = [player.get_rid(), door._body.get_rid()]
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		if not _require(not hit.is_empty() and hours.is_ancestor_of(hit.collider),
				"actual closed grille contact " + identity): return
	outward.reverse()
	for point in outward:
		if not await _walk_world(point): return
	for point in [Vector3(0,0,-10.2), Vector3(0,0,-8.5),
			Vector3(1.925,0,-6.5), Vector3(1.925,0,-3.5)]:
		if not await _walk(point): return
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var dormant: Dictionary = passage.residency.snapshot()
	if not _require(dormant.state == "DORMANT" and dormant.unload_cycles >= 2
			and dormant.retired_geometry_roots_alive == 0, "continuous return releases arcade geometry"): return
	for identity: String in ids:
		if not _require(passage.doors[identity].get_instance_id() == leaf_ids[identity]
				and passage.doors[identity].open, "operated leaf survives geometry retirement " + identity): return
	_require(not world.shop_simulation.failed, "shared shop simulation remains valid")

func _grilles_clear_leaf_poses(hours: PassageHoursDirector, roster: Dictionary) -> bool:
	# Query each physical leaf shape through the normal sweep and the
	# source's parked pose. Do not move actors or disable either collider.
	for identity: String in roster:
		var door: DoorProp = roster[identity]
		var shape_node := door._body.get_child(0) as CollisionShape3D
		for angle: float in [0,10,20,30,40,50,60,70,80,90,100,168]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape_node.shape
			query.collision_mask = 1
			query.exclude = [door._body.get_rid(), player.get_rid()]
			var pose := Transform3D(Basis(Vector3.UP, deg_to_rad(-angle if door.swing_out else angle)), door._body.position)
			query.transform = door.global_transform * pose * shape_node.transform
			for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,128):
				if not _require(not hours.is_ancestor_of(hit.collider),
						"grilles clear moving leaf " + identity + " at " + str(angle)): return false
	return true

func _visit_shop(identity: String, door: DoorProp) -> bool:
	var centre := door.to_global(Vector3(door.width * .5,0,0))
	var west := centre.x < 14
	var front := Vector3(12.4 if west else 15.6,.01,centre.z)
	if not await _walk_world(Vector3(14,.01,centre.z)): return false
	if not await _walk_world(front): return false
	# Source-open shops park at 168 degrees. Their public face remains
	# usable; normal opening then gives the ordinary 100-degree inside pose.
	if door.open:
		await _clean_capture("parked_" + identity, door._body.to_global(Vector3(door.width * .5,1.15,0)))
		if not await _use(door, door._body.to_global(Vector3(door.width * .5,1.15,0)), "parked_close_" + identity): return false
		if not await _wait_for_door(door): return false
	if not await _use(door, door.to_global(Vector3(door.width * .5,1.15,0)), "entry_" + identity): return false
	if not await _wait_for_door(door): return false
	if not _require(door.is_ready_for_passage(), "usable source entry " + identity): return false
	if not await _walk_world(Vector3(10.8 if west else 17.2,.01,centre.z)): return false
	# The diner customer aisle ends before its source-sized stool row.
	var inside_x := 9.7 if west else 17.6 if identity == "SITE_SHOP_DOOR_LUNCHEONETTE" else 18.3
	var inside := Vector3(inside_x,.01,centre.z)
	if not await _walk_world(inside): return false
	if not await _use(door, door._body.to_global(Vector3(door.width * .5,1.15,0)), "inside_close_" + identity): return false
	if not await _wait_for_door(door): return false
	if not _require(not door.open, "inside closure " + identity): return false
	if not await _turn_key(door, true, identity): return false
	if not await _turn_key(door, false, identity): return false
	await _clean_capture("inside_" + identity, inside + Vector3(-3 if west else 3,1.3,0))
	if not await _use(door, door.to_global(Vector3(door.width * .5,1.15,0)), "inside_reopen_" + identity): return false
	if not await _wait_for_door(door): return false
	if not await _walk_world(Vector3(10.8 if west else 17.2,.01,centre.z)): return false
	if not await _walk_world(front): return false
	return await _walk_world(Vector3(14,.01,centre.z))

func _turn_key(door: DoorProp, locked: bool, identity: String) -> bool:
	player.camera.look_at(door.to_global(Vector3(door.width * .5,1.1,0)))
	await get_tree().process_frame
	Input.action_press("door_key")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("door_key")
	await get_tree().create_timer(.4).timeout
	return _require(door.leaf_state == ("locked" if locked else "closed"),
			"ordinary key input " + ("locks " if locked else "unlocks ") + identity)

func _clean_capture(identity: String, target: Vector3) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	# Hide only the isolated held-device overlay for this inspection frame.
	# Practical world lighting and the player's physical position stay active.
	var overlays: Array[CanvasLayer] = []
	for child in player.camera.get_children():
		if child is ServiceSetCarrier:
			for layer: CanvasLayer in child.find_children("*", "CanvasLayer", true, false):
				if layer.visible:
					overlays.append(layer)
					layer.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_transform = player.camera.global_transform
	camera.fov = player.camera.fov
	camera.look_at(target)
	camera.make_current()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(identity + "_clean.png"))
	player.camera.make_current()
	camera.queue_free()
	for layer in overlays: layer.show()
