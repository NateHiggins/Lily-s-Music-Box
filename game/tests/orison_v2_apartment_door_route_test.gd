extends "res://tests/orison_v2_4b_door_route_test.gd"
## Two apartments in one continuous route, including Mina's cooking approach.

func _init() -> void:
	route_label = "APARTMENT DOOR BATCH ROUTE"


# Preserve the failed physical state in the run log; never retry or force a leaf.
func _drag_part(owner_node: Node3D, aim: Vector3, goal: float, label: String) -> bool:
	var passed: bool = await super._drag_part(owner_node, aim, goal, label)
	if passed or not owner_node is DoorProp: return passed
	var door := owner_node as DoorProp
	var body := door._body
	var contact := body.to_global(player._grab.contact)
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position, contact)
	ray.collide_with_areas = true
	ray.exclude = [player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	var shape := body.get_child(0) as CollisionShape3D
	var pose := body.transform
	pose.basis = Basis(Vector3.UP, goal)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = door.global_transform * pose * shape.transform
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	query.margin = .001
	var blockers: Array[String] = []
	for overlap: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query, 32):
		blockers.append(str(overlap.collider.get_path()))
	print("APARTMENT_GESTURE_FAILURE ", JSON.stringify({"label":label,"goal":goal,
		"angle":body.rotation.y,"player":str(world.adapter.root.to_local(player.global_position)),
		"contact_scope":"last acquired hand contact; a failed acquisition can retain the previous contact",
		"contact_distance":player.camera.global_position.distance_to(contact),
		"sightline":str(hit.collider.get_path()) if hit.has("collider") else "",
		"goal_blockers":blockers,"call_locked":player.call_locked,
		"mouse_mode":Input.mouse_mode,"motion_revision":door.motion_revision}))
	return passed

func _route() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://tests/data/v2_apartment_door_routes.json"))
	# Keep NPC scheduling out of this player-input fixture. Separate Mina
	# timetable fixtures exercise the resident's own door opening and routing.
	world.mina_routine.set_process(false)
	world.mina_routine.set_physics_process(false)
	player.global_position = world.adapter.root.to_global(Vector3(source.start[0], 3.22, source.start[1]))
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var kitchen_visited := false
	for step: Dictionary in source.steps:
		if step.has("walk"):
			if not await _walk(Vector3(step.walk[0], 3.2, step.walk[1])): return
			if not kitchen_visited and Vector2(step.walk[0],step.walk[1]).is_equal_approx(Vector2(-8.5,0)):
				# The original door loop bypassed the open kitchen entirely.
				# Walk from the living room to the authored sink stance, operate
				# both real valves, and return before resuming the bedroom loop.
				# Pass between the caption tables, then align with the 810 mm
				# kitchen opening at x=-12; the rest of the partition is solid.
				for point in [Vector3(-9.5,3.2,.8),Vector3(-13,3.2,.8),Vector3(-13,3.2,2.5),Vector3(-12,3.2,2.5),Vector3(-12,3.2,4.55),Vector3(-14.7,3.2,4.55)]:
					if not await _walk(point): return
				if not await _use_water_valves("F02_2A_KITCHEN_SINK_01"): return
				for point in [Vector3(-12,3.2,4.55),Vector3(-12,3.2,2.5),Vector3(-13,3.2,2.5),Vector3(-13,3.2,.8),Vector3(-9.5,3.2,.8),Vector3(-8.5,3.2,0)]:
					if not await _walk(point): return
				kitchen_visited = true
		elif step.has("open"):
			if not await _open_door(str(step.open)): return
		else:
			if not await _close_door(str(step.close)): return
			if str(step.close) in ["F02_DOOR_02", "F02_B_ENTRY_DOOR"]:
				var door := _leaf(str(step.close))
				var ray := PhysicsRayQueryParameters3D.create(
						door.to_global(Vector3(door.width*.5, 1.1, -.6)),
						door.to_global(Vector3(door.width*.5, 1.1, .6)), 1)
				ray.exclude = [player.get_rid()]
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				if not _require(hit.get("collider") == door.get_node("HingedLeaf"),
						"closed apartment entry restores its barrier: " + str(step.close)): return
	_require(kitchen_visited,"Mina cooking approach and independent water controls exercised")
	_require(not player.noclip and player.collision_mask == 1 and player.is_physics_processing(),
			"ordinary collision preserved through both apartments: noclip=%s mask=%s physics=%s" % [player.noclip, player.collision_mask, player.is_physics_processing()])
