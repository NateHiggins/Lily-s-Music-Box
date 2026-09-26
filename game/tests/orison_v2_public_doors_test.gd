extends "res://tests/orison_v2_vertical_route_test.gd"
## Exercise real E targeting and moving collision, from both sides of each leaf.
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
	player.face_world_point(door._body.to_global(Vector3(door.width*.5,door.height*.5,0)))
	await get_tree().physics_frame
	player.use_primary_interaction()
	for frame in 90:
		await get_tree().physics_frame
		if not door._moving: break
	if door.open!=want_open or door._moving:
		failures.append(str(door.name)+" real interaction failed; want_open="+str(want_open))
		return false
	player.face_world_point(door._body.to_global(Vector3(door.width*.5,door.height*.5,0)))
	return true

func _capture(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
