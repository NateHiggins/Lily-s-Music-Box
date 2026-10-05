extends "res://tests/orison_v2_public_doors_test.gd"
## Both real approaches, moving collision and the existing maintenance key.
func _init() -> void: route_label="INNER VESTIBULE DOOR"

func _route() -> void:
	var anchor:=world.adapter.resolve("F01_INNER_DOOR") as Node3D
	var door:=anchor.get_node_or_null("F01_INNER_DOOR_Leaf") as DoorProp
	if door==null or anchor.has_node("Hinge"):
		failures.append("inner door retains a parked graybox leaf");return
	if not anchor.has_node("DoorCasings") or not anchor.has_node("DoorLinings"):
		failures.append("inner door lacks finished casings and linings");return
	world.service_set_carrier.set_capture_hidden(true)
	var collision:=door._body.get_child(0) as CollisionShape3D
	var swing_sign: float=-1.0 if door.swing_out else 1.0
	for angle in range(0,169,2):
		var pose:=door._body.global_transform
		pose.basis=door.global_basis*Basis(Vector3.UP,deg_to_rad(angle*swing_sign))
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=collision.shape;query.transform=pose*collision.transform
		query.collision_mask=1;query.margin=.0001;query.exclude=[player.get_rid(),door._body.get_rid()]
		if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			failures.append("inner leaf sweep intersects retained fabric at "+str(angle));return
		if angle==90 and anchor.to_local(pose*Vector3(door.width*.5,1.0,0)).z<=0:
			failures.append("inner leaf reverses the source northward swing");return
	for side: float in [-1.0,1.0]:
		player.global_position=anchor.to_global(Vector3(0,.02,side*1.15))
		player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		await get_tree().physics_frame
		var contacted:=false
		for frame in 45:
			player.face_world_point(anchor.to_global(Vector3(0,1.5,-side)))
			Input.action_press("move_forward")
			await get_tree().physics_frame
			for i in player.get_slide_collision_count():
				if player.get_slide_collision(i).get_collider()==door._body:contacted=true
		Input.action_release("move_forward")
		if not contacted or anchor.to_local(player.global_position).z*side<=0:
			failures.append("shut inner leaf does not block its actual approach");return
		if not await _walk(world.adapter.root.to_local(anchor.to_global(Vector3(0,0,side*1.15)))):return
		player.face_world_point(door._body.to_global(Vector3(door.width*.5,1.0,0)))
		await get_tree().physics_frame
		player.use_key_interaction()
		if door.leaf_state!="locked" or door.open:
			failures.append("existing maintenance key cannot lock inner leaf");return
		while door._key_turning:await get_tree().physics_frame
		player.use_primary_interaction()
		if door.open or door._moving:
			failures.append("locked inner leaf accepts opening");return
		player.use_key_interaction()
		if door.leaf_state!="closed":
			failures.append("existing maintenance key cannot unlock inner leaf");return
		while door._key_turning:await get_tree().physics_frame
		if not await _use(door,true):return
		await _capture("inner_open_"+str(side))
		if not await _walk(world.adapter.root.to_local(anchor.to_global(Vector3(0,0,-side*1.15)))):return
		if not await _use(door,false):return
		await _capture("inner_closed_"+str(side))
	if DoorKeyring.identity(door)!="F01_INNER_DOOR" or DoorKeyring.book().locks.get("F01_INNER_DOOR",true):
		failures.append("saved lock does not retain the semantic inner door identity")
	print("INNER DOOR: 85 physical sweep positions, source northward swing, both real approaches and key operations")
