extends "res://tests/orison_v2_vertical_route_test.gd"
## Exercise click-grab, mouse travel and release, from both sides of each leaf.
const DOORS := ["F01_WATCH_MAIL_DOOR", "F01_MAIL_PACKAGE_DOOR", "F01_PACKAGE_COMMON_DOOR"]

func _route() -> void:
	route_label = "PUBLIC DOORS"
	for identity in DOORS:
		var anchor := world.adapter.resolve(identity) as Node3D
		var door := anchor.get_node_or_null(identity+"_Leaf") as DoorProp
		if door==null:
			failures.append(identity+" missing production leaf")
			return
		if anchor.has_node("Hinge"):
			failures.append(identity+" retains placeholder collision")
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
			# Drive into the shut door and require real contact with its body.
			var contacted := false
			for frame in 45:
				player.face_world_point(anchor.to_global(Vector3(0,1.6,-side)))
				Input.action_press("move_forward")
				await get_tree().physics_frame
				for index in player.get_slide_collision_count():
					if player.get_slide_collision(index).get_collider()==door._body: contacted=true
			Input.action_release("move_forward")
			if not contacted or anchor.to_local(player.global_position).z*side<=0:
				failures.append(identity+" closed leaf did not block traversal")
				return
			# Back off before the moving leaf swings toward the operator.
			if not await _walk(world.adapter.root.to_local(anchor.to_global(Vector3(0,0,side*near_distance)))): return
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
			failures.append(str(door.name)+" operator stance is occupied: "+str(occupied))
			return false
		if not await _walk(world.adapter.root.to_local(operator)): return false
	player.face_world_point(door._body.to_global(Vector3(door.width*.5,door.height*.5,0)))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hand := preload("res://tests/heating_hand_driver.gd").new()
	hand.player=player;add_child(hand)
	hand.click()
	if not player._grab.active() or player._grab.target.get("owner")!=door:
		failures.append(str(door.name)+" actual click did not grab the physical leaf")
		if player._grab.active():hand.click()
		hand.free();return false
	var picked: Dictionary=player._grab.target
	var goal: float=door.motion_target_angle(want_open)
	var moved: bool=await hand.move_to(goal)
	if not moved:
		var shape_node := door._body.get_child(0) as CollisionShape3D
		var pose := door._body.transform
		pose.basis=Basis(Vector3.UP,move_toward(float(picked.read.call()),goal,.025))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=shape_node.shape;query.transform=door.global_transform*pose*shape_node.transform
		query.collision_mask=door._body.collision_mask;query.exclude=[door._body.get_rid()];query.margin=.001
		var blockers: Array=[]
		for hit: Dictionary in world.get_world_3d().direct_space_state.intersect_shape(query,8):blockers.append(str(hit.collider.get_path()))
		print("PUBLIC HAND BLOCKERS ",door.name," player_local=",door.to_local(player.global_position)," angle=",picked.read.call()," blockers=",blockers)
	hand.click()
	await get_tree().physics_frame
	var released: bool=not player._grab.active() and not door._moving
	var settled: bool=absf(float(picked.read.call())-goal)<.002 and door.open==want_open
	var follows: bool=hand.follows_cursor
	hand.free()
	if not moved or not released or not settled or not follows:
		failures.append(str(door.name)+" physical leaf input failed; want_open="+str(want_open)+" moved="+str(moved)+" released="+str(released)+" angle="+str(picked.read.call())+" goal="+str(goal))
		return false
	await _capture(str(door.name)+("_opened_by_hand" if want_open else "_closed_by_hand"))
	if sidestep and not await _walk(world.adapter.root.to_local(approach)): return false
	return true

func _capture(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
