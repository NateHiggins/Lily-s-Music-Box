extends "res://tests/orison_v2_4b_door_route_test.gd"
## Retained 2C home and the actual installed frame, using ordinary player input.
func _init() -> void:
	route_label="C REAR WING APARTMENT ROUTE"
func _prepare_player_start() -> void:
	_require(world.adapter.root.get_node_or_null("RearWingCSupport")!=null,"production C rear-wing frame is installed")
	super._prepare_player_start()
func _route() -> void:
	world.mina_routine.set_process(false)
	player.global_position=world.adapter.root.to_global(Vector3(-.85,3.22,3.0));player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	var steps: Array=[
		{"open":"F02_C_ENTRY_DOOR"},
		{"walk":[-.85,4.75]},{"walk":[-.85,5.7]},{"walk":[-.85,6.85]},
		{"walk":[-4,6.85]},{"walk":[-4,5.65]},{"walk":[-4.7,5.65]},{"walk":[-3.05,5.65]},
		{"walk":[-4,5.65]},{"walk":[-4,6.85]},{"walk":[-.85,6.85]},{"walk":[-.85,7.1]},
		{"walk":[2.1,7.1]},{"open":"F02_C_PRIVATE_HALL_BATH_DOOR"},
		{"walk":[2.1,5.7]},{"walk":[2.1,5.1]},{"walk":[2.1,7.1]},
		{"close":"F02_C_PRIVATE_HALL_BATH_DOOR"},{"open":"F02_C_PRIVATE_HALL_BED1_DOOR"},
		{"walk":[2.1,8.7]},{"walk":[2.5,9.0]},{"walk":[2.1,8.7]},{"walk":[2.1,7.1]},
		{"close":"F02_C_PRIVATE_HALL_BED1_DOOR"},
		{"walk":[5.4,7.1]},{"open":"F02_C_PRIVATE_HALL_KITCHEN_DOOR"},
		{"walk":[5.4,5.6]},{"walk":[5.4,4.7]},{"walk":[5.4,7.1]},
		{"close":"F02_C_PRIVATE_HALL_KITCHEN_DOOR"},{"open":"F02_C_PRIVATE_HALL_BED2_DOOR"},
		{"walk":[5.4,8.7]},{"walk":[5.8,9.0]},{"walk":[5.4,8.7]},{"walk":[5.4,7.1]},
		{"close":"F02_C_PRIVATE_HALL_BED2_DOOR"},
		{"walk":[-.85,7.1]},{"walk":[-.85,6.85]},{"walk":[-.85,5.7]},
		{"walk":[-.85,4.75]},{"walk":[-.85,3.0]},{"close":"F02_C_ENTRY_DOOR"}]
	for step: Dictionary in steps:
		if step.has("walk"):
			if not await _walk(Vector3(step.walk[0],3.2,step.walk[1])):return
		elif step.has("open"):
			if not await _open_door(str(step.open)):return
		else:
			if not await _close_door(str(step.close)):return
	var door:=_leaf("F02_C_ENTRY_DOOR")
	var ray:=PhysicsRayQueryParameters3D.create(door.to_global(Vector3(door.width*.5,1.1,-.6)),door.to_global(Vector3(door.width*.5,1.1,.6)),1)
	ray.exclude=[player.get_rid()]
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	_require(hit.get("collider")==door.get_node("HingedLeaf"),"closed 2C entry restores the physical barrier")
	_require(not player.noclip and player.collision_mask==1 and player.is_physics_processing(),"ordinary collision retained through all seven 2C rooms")
