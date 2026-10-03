extends "res://tests/orison_v2_public_doors_test.gd"
## Continuous rear door -> existing street -> front threshold -> rear return.
func _init() -> void:
	route_label = "V2 SERVICE ALLEY"

func _prepare_player_start() -> void:
	player.global_position = world.adapter.root.to_global(Vector3(8.9,.02,8.0))
	player.velocity = Vector3.ZERO

func _route() -> void:
	var anchor := world.adapter.resolve("F01_REAR_SERVICE_DOOR") as Node3D
	var door := anchor.get_node("F01_REAR_SERVICE_DOOR_Leaf") as DoorProp
	# A real closed-leaf contact precedes the opening and continuous walk.
	var contacted := false
	for frame in 45:
		player.face_world_point(anchor.to_global(Vector3(0,1.2,1)))
		Input.action_press("move_forward")
		await get_tree().physics_frame
		for i in player.get_slide_collision_count():
			if player.get_slide_collision(i).get_collider()==door._body:contacted=true
	Input.action_release("move_forward")
	if not contacted:failures.append("rear closed leaf did not block")
	if not await _walk(Vector3(8.9,0,8.0)):return
	if not await _use(door,true):return
	var outward := [Vector3(8.9,0,10.7),Vector3(8.9,0,13),Vector3(16.8,0,13),
		Vector3(16.8,0,8),Vector3(16.8,0,2),Vector3(16.8,0,-5),
		Vector3(16.8,0,-10.8),Vector3(16.8,0,-13.8)]
	for point: Vector3 in outward:
		if not await _walk(point):return
		await _view("out_"+str(trace.size()),point+Vector3(0,1.3,-3))
	# Registered world coordinates must join the already playable sidewalk.
	for point in [Vector3(-12,0,2.5),Vector3(-4,0,2.5),Vector3(0,0,2.5),Vector3(0,0,.65)]:
		if not await _walk(world.adapter.root.to_local(point)):return
	await _view("front_arrival",world.adapter.root.to_local(Vector3(0,1.4,0)))
	for point in [Vector3(0,0,2.5),Vector3(-4,0,2.5),Vector3(-12,0,2.5)]:
		if not await _walk(world.adapter.root.to_local(point)):return
	outward.reverse()
	for point: Vector3 in outward:
		if not await _walk(point):return
		await _view("return_"+str(trace.size()),Vector3(8.9,1.3,9.25) if point.z>10 else point+Vector3(0,1.3,3))
	if not await _use(door,false):return
	if not await _use(door,true):return
	if not await _walk(Vector3(8.9,0,8.0)):return
	if not await _use(door,false):return
	# Several former void locations now support the real collision surface.
	for point in [Vector3(8.9,0,10),Vector3(8.9,0,13),Vector3(12,0,13),Vector3(16.8,0,13),Vector3(16.8,0,3),Vector3(16.8,0,-5),Vector3(16.8,0,-11.6)]:
		var query := PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(point+Vector3.UP),world.adapter.root.to_global(point-Vector3.UP))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or absf((hit.position as Vector3).y)>.01:failures.append("alley ground missing at "+str(point))
	# The formerly open 200 mm bands must be closed by the core walls,
	# including above the ground-floor rear view and all stacked storeys.
	for floor_index in 6:
		var y := float(floor_index)*3.2+3.1
		for pair in [[Vector3(14,y,8),Vector3(12.8,y,8)],[Vector3(11,y,11),Vector3(11,y,9.8)]]:
			var query := PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(pair[0]),world.adapter.root.to_global(pair[1]))
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():failures.append("service-core storey gap at "+str(pair[0]))

func _view(label: String, local_target: Vector3) -> void:
	player.camera.look_at(world.adapter.root.to_global(local_target))
	await get_tree().create_timer(.2).timeout
	await _capture(label)
	var overlays: Array[CanvasLayer] = []
	for layer in player.find_children("*","CanvasLayer",true,false):
		if layer.visible:
			overlays.append(layer)
			layer.hide()
	await _capture(label+"_inspection")
	for layer in overlays:layer.show()
