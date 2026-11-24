extends "res://tests/orison_v2_vertical_route_test.gd"
## Walk at each shut leaf and work it by click (RUL-018), from both sides.
const DOORS := ["F01_WATCH_MAIL_DOOR", "F01_MAIL_PACKAGE_DOOR", "F01_PACKAGE_COMMON_DOOR"]

func _route() -> void:
	route_label = "PUBLIC DOORS"
	for identity in DOORS:
		var anchor := world.adapter.resolve(identity) as Node3D
		var door := anchor.get_node_or_null(identity+"_Leaf") as DoorProp
		if door==null:
			_fail(identity+" missing production leaf")
			return
		if anchor.has_node("Hinge"):
			_fail(identity+" retains placeholder collision")
			return
		for side in [-1.0,1.0]:
			# The watch desk stands opposite this threshold: its legal landing
			# is half a metre deep before the route turns alongside the desk.
			var near_distance := .50 if identity==DOORS[0] and side>0 else 1.1
			var far_distance := .50 if identity==DOORS[0] and side<0 else 1.1
			# Placement starts this independent door fixture; crossing itself
			# must use the production controller, gravity and collision mask.
			player.global_position=anchor.to_global(Vector3(0,.02,side*near_distance))
			player.velocity=Vector3.ZERO
			await get_tree().physics_frame
			await get_tree().physics_frame
			var target: Vector3=world.adapter.root.to_local(anchor.to_global(Vector3(0,0,-side*far_distance)))
			# Drive into the shut door (RUL-018). Walking at a public door either
			# meets its closed body or the passage guide swings it open and leads
			# the player through. Either way nobody crosses a leaf still shut.
			var contacted := false
			var crossed_shut := false
			var crossed := false
			for frame in 150:
				player.face_world_point(anchor.to_global(Vector3(0,1.6,-side)))
				Input.action_press("move_forward")
				await get_tree().physics_frame
				for index in player.get_slide_collision_count():
					if player.get_slide_collision(index).get_collider()==door._body: contacted=true
				if anchor.to_local(player.global_position).z*side<=0:
					crossed = true
					if absf(door._body.rotation.y)<.35: crossed_shut = true
					break
			Input.action_release("move_forward")
			for frame in 180:
				await get_tree().physics_frame
				if not door._moving and not door._key_turning: break
			var guided: bool = crossed and door.open
			var held: bool = contacted and not crossed and not door.open
			if crossed_shut or not (guided or held):
				print("PUBLIC DOORS BLOCK DIAGNOSTIC ",identity," side=",side," contacted=",contacted," crossed=",crossed,
						" crossed_shut=",crossed_shut," local=",anchor.to_local(player.global_position)," leaf_open=",door.open)
				_fail(identity+" walking at the shut leaf neither met it nor was guided through it")
				return
			# Back off before the moving leaf swings toward the operator; a guided
			# crossing walks back through the open door and shuts it by click.
			if not await _walk(world.adapter.root.to_local(anchor.to_global(Vector3(0,0,side*near_distance)))): return
			if door.open and not await _use(door,false): return
			if not await _use(door,true): return
			await _capture(identity+"_open_"+str(side))
			if not await _walk(target): return
			if not await _use(door,false): return
			await _capture(identity+"_closed_"+str(side))
	# Now join the same rooms without repositioning between door fixtures.
	var first := world.adapter.resolve(DOORS[0]) as Node3D
	player.global_position=first.to_global(Vector3(0,.02,.50))
	player.velocity=Vector3.ZERO
	for index in DOORS.size():
		var anchor := world.adapter.resolve(DOORS[index]) as Node3D
		var door := anchor.get_node(DOORS[index]+"_Leaf") as DoorProp
		var side := -1.0 if index==1 else 1.0
		var distance := .50 if index==0 else 1.1
		if index>0:
			if not await _walk(world.adapter.root.to_local(anchor.to_global(Vector3(0,0,side*distance)))): return
		if not await _use(door,true): return
		if not await _walk(world.adapter.root.to_local(anchor.to_global(Vector3(0,0,-side*1.1)))): return
		if not await _use(door,false): return
	await _capture("continuous_reading_room_arrival")

func _use(door: DoorProp, want_open: bool) -> bool:
	# A narrow landing allows a lateral operating stance beside the latch.
	# Keep the original crossing targets, but stand outside the leaf sweep
	# while pulling it; walk back only after it reaches its physical stop.
	var approach := player.global_position
	var local_approach := door.to_local(approach)
	var toward_swing: bool=local_approach.z*door.motion_target_angle(true)<0
	var sidestep: bool=toward_swing and Vector2(local_approach.x,local_approach.z).length()<door.width+player._capsule.radius+.10
	print("PUBLIC HAND APPROACH ",door.name," local=",local_approach," open_goal=",door.motion_target_angle(true)," sidestep=",sidestep)
	if sidestep:
		var operator := door.to_global(Vector3(door.width+.40,local_approach.y,signf(local_approach.z)*.75))
		var standing := PhysicsShapeQueryParameters3D.new()
		standing.shape=player._capsule;standing.transform=player.global_transform*player._shape.transform
		standing.transform.origin+=operator-player.global_position+Vector3.UP*.02
		standing.collision_mask=player.collision_mask;standing.exclude=[player.get_rid()]
		var occupied: Array=world.get_world_3d().direct_space_state.intersect_shape(standing,4)
		if not occupied.is_empty():
			_fail(str(door.name)+" operator stance is occupied: "+str(occupied))
			return false
		if not await _walk(world.adapter.root.to_local(operator)): return false
	# RUL-018: a deliberate click opens or shuts a full-size leaf; it swings to
	# its stop through the production tween and solid sweep, with no grip held.
	# Walking up to the stance may already have let the passage guide swing it;
	# let the leaf settle, and if it already stands as wanted, click it the
	# other way first so the click is still what takes it there.
	for frame in 180:
		await get_tree().physics_frame
		if not door._moving and not door._key_turning: break
	if door.open==want_open and not await _click_leaf(door,not want_open): return false
	return await _click_leaf(door,want_open,approach if sidestep else Vector3.INF)

func _click_leaf(door: DoorProp, want_open: bool, return_to := Vector3.INF) -> bool:
	var aim: Vector3=door._body.to_global(Vector3(door.width*.5,1.1,0))
	player.face_world_point(aim)
	await get_tree().physics_frame
	player.camera.look_at(aim)
	await get_tree().physics_frame
	player.camera.look_at(aim)
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position-player.camera.global_basis.z*2.1)
	ray.collide_with_areas=true;ray.exclude=[player.get_rid()]
	var node := world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") as Node
	var matched := false
	while node!=null:
		if node==door: matched=true
		node=node.get_parent()
	if not matched or player._grab.active():
		_fail(str(door.name)+" actual click ray does not reach the leaf")
		return false
	var hand := preload("res://tests/heating_hand_driver.gd").new()
	hand.player=player;add_child(hand)
	# The primary click reaches the world only through a captured pointer.
	player.set_mouse_released(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var hit_before := world.get_world_3d().direct_space_state.intersect_ray(ray)
	var finder: Dictionary = player._grab.find_target()
	hand.click()
	var after_click := "moving=%s open=%s gripped=%s key_turning=%s save_blocked=%s finder=%s" % [door._moving, door.open,
			door._hand_gripped, door._key_turning, RealityState.save_write_blocked, str(finder.keys())]
	for frame in 180:
		await get_tree().physics_frame
		if not door._moving and not door._key_turning: break
	hand.free()
	var goal: float=door.motion_target_angle(want_open)
	var settled: bool=door.open==want_open and not player._grab.active() and absf(door._body.rotation.y-goal)<.01
	if want_open: settled=settled and door.is_ready_for_passage()
	if not settled:
		_fail(str(door.name)+" click did not take the leaf to its stop; want_open="+str(want_open)+" open="+str(door.open)+" angle="+str(door._body.rotation.y)+" goal="+str(goal)
				+" leaf_state="+str(door.leaf_state)+" passage_allowed="+str(door.passage_allowed())+" swing_clear="+str(door.motion_clear(want_open))
				+" player_local="+str(door.to_local(player.global_position))
				+" after_click="+after_click+" captured="+str(player.pointer_captured())+" ray_hit="+str((hit_before.get("collider") as Node).get_path() if hit_before.get("collider") is Node else ""))
		return false
	await _capture(str(door.name)+("_opened_by_click" if want_open else "_closed_by_click"))
	if return_to!=Vector3.INF and not await _walk(world.adapter.root.to_local(return_to)): return false
	return true

func _capture(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))


## Record a failure and say it, so the log carries the reason.
func _fail(reason: String) -> void:
	print("PUBLIC DOORS FAIL: ", reason)
	failures.append(reason)
