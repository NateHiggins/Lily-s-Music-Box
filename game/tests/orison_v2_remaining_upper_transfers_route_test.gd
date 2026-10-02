extends "res://tests/orison_v2_4b_door_route_test.gd"
## One initial placement; the actual lower-storey A home uses normal input.
func _init() -> void:
	route_label="REMAINING TRANSFERS LOWER A ROUTE"
func _prepare_player_start() -> void:
	_require(world.adapter.root.get_node_or_null("RemainingUpperTransfers")!=null,"production remaining transfers are installed")
	super._prepare_player_start()
func _route() -> void:
	world.mina_routine.set_process(false)
	player.global_position=world.adapter.root.to_global(Vector3(-4.65,6.42,0));player.velocity=Vector3.ZERO
	await get_tree().physics_frame
	var steps: Array=[
		{"open":"F03_DOOR_02"},
		{"walk":[-6.65,0]},{"walk":[-8.3,0]},{"walk":[-10.8,0]},
		{"walk":[-12,0]},{"walk":[-12,2.25]},{"walk":[-12,4.4]},
		{"walk":[-12,2.25]},{"walk":[-10.8,2.25]},{"walk":[-9.6,2.25]},
		{"open":"F03_A_HALL_DOOR"},{"walk":[-9.6,4.0]},{"walk":[-9.6,4.6]},
		{"open":"F03_A_BATH_DOOR"},{"walk":[-7.7,4.6]},{"walk":[-9.6,4.6]},
		{"close":"F03_A_BATH_DOOR"},{"walk":[-9.6,6.4]},{"walk":[-9.6,7.1]},
		{"open":"F03_A_BED_DOOR"},{"walk":[-11.4,7.1]},{"walk":[-12.7,8.0]},
		{"walk":[-11.4,7.1]},{"walk":[-9.6,7.1]},{"close":"F03_A_BED_DOOR"},
		{"walk":[-9.6,6.4]},{"walk":[-9.6,4.6]},{"walk":[-9.6,4.0]},
		{"walk":[-9.6,2.25]},{"close":"F03_A_HALL_DOOR"},
		{"walk":[-10.8,2.25]},{"walk":[-10.8,0]},{"walk":[-8.3,0]},
		{"walk":[-6.65,0]},{"walk":[-4.65,0]},{"close":"F03_DOOR_02"}]
	for step: Dictionary in steps:
		if step.has("walk"):
			if not await _walk(Vector3(step.walk[0],6.4,step.walk[1])):return
		elif step.has("open"):
			if not await _open_door(str(step.open)):return
		else:
			if not await _close_door(str(step.close)):return
	var door:=_leaf("F03_DOOR_02")
	var ray:=PhysicsRayQueryParameters3D.create(door.to_global(Vector3(door.width*.5,1.1,-.6)),door.to_global(Vector3(door.width*.5,1.1,.6)),1,[player.get_rid()])
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	_require(hit.get("collider")==door.get_node("HingedLeaf"),"closed lower-storey A entry restores its barrier")
	_require(not player.noclip and player.collision_mask==1 and player.is_physics_processing(),"ordinary collision retained through all lower A rooms")
