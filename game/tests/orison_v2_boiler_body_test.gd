extends "res://tests/orison_v2_lift_joinery_test.gd"
## Actual static triangles and collision must leave the service throats open.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.set_physics_process(false)
	var boiler := world.adapter.resolve("B1_BOILER_01") as BoilerProp
	boiler.set_fire_door_open(true,0)
	boiler.set_ash_door_open(true,0)
	await get_tree().physics_frame
	var faces := PackedVector3Array()
	var batches := 0
	for mesh: MeshInstance3D in boiler._carcass.find_children("*","MeshInstance3D",true,false):
		var transform := boiler.global_transform.affine_inverse()*mesh.global_transform
		for vertex in mesh.mesh.get_faces(): faces.append(transform*vertex)
		batches+=1
	var probes := 0
	for y in [.40,.46,1.02,1.11]:
		for x in [-.17,.02,.17]:
			var origin := Vector3(x,y,-.95)
			var distance := _mesh_distance(faces,origin,Vector3.BACK)
			check(distance>.78 and distance<.87,"open service throat has a recessed solid back, not a front card")
			var ray := PhysicsRayQueryParameters3D.create(boiler.to_global(origin),boiler.to_global(origin+Vector3.BACK*1.1),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(hit.get("collider")==boiler.get_node("BoilerCollision"),"cavity back retains physical boiler ownership")
			if not hit.is_empty(): check(absf(distance-origin.distance_to(boiler.to_local(hit.position)))<.001,"cavity collision meets the actual imported back wall")
			probes+=1
	# The old broad collision was only 0.32 m from this same origin and
	# blocked the entire mouth. The new measured depth must reject that box.
	var old_box := BoxMesh.new()
	old_box.size=Vector3(boiler.W+.16,boiler.BARREL_TOP,boiler.D+.24)
	var old_faces := old_box.get_faces()
	for i in old_faces.size(): old_faces[i].y+=boiler.BARREL_TOP*.5
	check(_mesh_distance(old_faces,Vector3(0,1.11,-.95),Vector3.BACK)<.4,"probe reproduces the former solid-envelope obstruction")
	# The previously protruding grate occupied the closed leaf. Its new
	# front edge is wholly behind the original plate's rear face.
	for x in [-.228,-.152,-.076,0,.076,.152,.228]:
		var distance := _mesh_distance(faces,Vector3(x,.861,-.8),Vector3.BACK)
		check(distance>.25,"internal grate no longer projects through firing door")
	var fire_faces := boiler._firebed_mesh.mesh.get_faces()
	var coal_bounds := boiler._firebed_mesh.mesh.get_aabb()
	check(coal_bounds.position.z>-.47 and coal_bounds.end.z<-.17,"dynamic coal bed rests inside the fabricated grate")
	check(fire_faces.size()>36,"coal bed has shaped lumps instead of the former six-sided slab")
	check(not fire_faces.is_empty() and boiler._fire_material!=null,"existing animated heat surface stays independent")
	boiler.set_fire_door_open(false,0)
	boiler.set_ash_door_open(false,0)
	await get_tree().physics_frame
	for record in [[1.04,boiler._fire_door],[.43,boiler._ash_door]]:
		var ray := PhysicsRayQueryParameters3D.create(boiler.to_global(Vector3(0,record[0],-.95)),boiler.to_global(Vector3(0,record[0],-.1)),1,[world.player.get_rid()])
		check(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")==record[1].get_node("LeafCollision"),"closed moving plate seals its own open throat")
	boiler.set_fire_door_open(true,0); boiler.set_ash_door_open(true,0)
	world.player.global_position=boiler.to_global(Vector3(.1,.02,-2.0))
	world.player.camera.look_at(boiler.to_global(Vector3(0,1,-.3)))
	world.player.set_lamp_enabled(true)
	await get_tree().create_timer(2).timeout
	await shot("open_boiler_player_height")
	for layer in world.player.carried_device.get_children():
		if layer is CanvasLayer: layer.hide()
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=55
	camera.global_position=boiler.to_global(Vector3(.65,1.3,-1.55))
	camera.look_at(boiler.to_global(Vector3(0,.99,-.25)))
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.global_position=camera.global_position
	fill.light_energy=.25; fill.omni_range=3
	await shot("recessed_firebox_and_grate")
	camera.global_position=boiler.to_global(Vector3(.45,.57,-1.35))
	camera.look_at(boiler.to_global(Vector3(0,.43,-.25)))
	fill.global_position=camera.global_position
	await shot("ash_tray_and_seated_lining")
	print("BOILER BODY: cavity_contacts=%d static_batches=%d static_triangles=%d failures=%d" % [probes,batches,faces.size()/3,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
