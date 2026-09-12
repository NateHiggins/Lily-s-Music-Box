extends "res://tests/orison_v2_4b_door_route_test.gd"
## Two apartments in one continuous route. Prepared; no runtime receipt yet.

func _init() -> void:
	route_label = "APARTMENT DOOR BATCH ROUTE"

func _route() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://tests/data/v2_apartment_door_routes.json"))
	# Keep NPC scheduling out of this player-input fixture. Separate Mina
	# timetable fixtures exercise the resident's own door opening and routing.
	world.mina_routine.set_process(false)
	player.global_position = world.adapter.root.to_global(Vector3(source.start[0], 3.22, source.start[1]))
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	for step: Dictionary in source.steps:
		if step.has("walk"):
			if not await _walk(Vector3(step.walk[0], 3.2, step.walk[1])): return
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
	_require(not player.noclip and player.collision_mask == 1 and player.is_physics_processing(),
			"ordinary collision preserved through both apartments")
