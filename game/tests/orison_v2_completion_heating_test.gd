extends "res://tests/orison_v2_roof_route_test.gd"
## Initial room placements, followed by ordinary movement, solid-body contact
## and the player's interaction ray. The room traversal suite covers access.

func _init() -> void:
	route_label = "COMPLETION HEATING"

func _prepare_player_start() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(2.3,.02,-3.5))
	player.velocity = Vector3.ZERO

func _route() -> void:
	for unit: String in ["1A","1D","2C","3D","4C","4D"]:
		var identity := "F0"+unit[0]+"_"+unit[1]+"_RADIATOR_01"
		var radiator := world.adapter.resolve(identity) as RadiatorProp
		if not _require(radiator != null and radiator._balance == world.heat_balance,
				"one production heat supply: "+unit): return
		var floor_at := radiator.global_position-Vector3.UP*.75
		var front := -radiator.global_basis.z
		player.global_position = floor_at+front*1.6+Vector3.UP*.02
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		if not await _walk_world(floor_at+front*.95): return
		var valve := radiator.get_node("TurnValveSurface") as Area3D
		if not await _use(valve,valve.global_position,unit+"_close_supply"): return
		if not _require(radiator.supply_position < .02,
				"ordinary E closes supply: "+unit): return
		if not await _use(valve,valve.global_position,unit+"_open_supply"): return
		if not _require(radiator.supply_position > .98,
				"ordinary E restores supply: "+unit): return
		await _roof_capture(unit+"_radiator",world.adapter.root.to_local(radiator.global_position))
		player.rotation.y = atan2(front.x,front.z)
		player.camera.rotation = Vector3.ZERO
		Input.action_press("move_forward")
		await get_tree().create_timer(.75).timeout
		Input.action_release("move_forward")
		await get_tree().physics_frame
		var clearance := (player.global_position-floor_at).dot(front)
		if not _require(clearance > .25 and clearance < .6 and player.is_on_floor(),
				"solid radiator stops actual capsule: "+unit+" "+str(clearance)): return
		if not await _walk_world(floor_at+front*.95): return
	_require(not player.noclip and player.collision_mask == 1,"heating route keeps real collision")
