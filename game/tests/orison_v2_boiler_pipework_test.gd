extends "res://tests/orison_v2_boiler_body_test.gd"
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
	var pipe := world.adapter.root.get_node("BoilerPipework") as Node3D
	var faces := PackedVector3Array()
	var triangles := 0
	for part: MeshInstance3D in pipe.find_children("*","MeshInstance3D",true,false):
		for v in part.mesh.get_faces():faces.append(boiler.to_local(part.to_global(v)))
		triangles+=part.mesh.get_faces().size()/3
	var probes := [[Vector3(.05,2.35,-.25),Vector3.BACK],
		[Vector3(-.94,1.05,.28),Vector3.RIGHT],
		[Vector3(-.30,1.05,1.15),Vector3.FORWARD],
		[Vector3(-.9,.18,.28),Vector3.RIGHT]]
	for p: Vector3 in [Vector3(11,-.55,-.55),Vector3(9.58,-.55,-.44),Vector3(10.9,-.36,-.55)]:
		var direction := Vector3.UP if p.x==11 else Vector3.LEFT if p.x<10 else Vector3.RIGHT
		var start := p-direction*.30
		probes.append([boiler.to_local(world.adapter.root.to_global(start)),boiler.global_basis.inverse()*world.adapter.root.global_basis*direction])
	for probe in probes:
		var point: Vector3=probe[0];var direction: Vector3=probe[1]
		var distance := _mesh_distance(faces,point,direction)
		var query := PhysicsRayQueryParameters3D.create(boiler.to_global(point),boiler.to_global(point+direction*.6),1,[world.player.get_rid()])
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		check(distance<.6 and not hit.is_empty(),"installed pipe fitting has a surface and contact at "+str(point))
		if not hit.is_empty():
			check(pipe.is_ancestor_of(hit.collider),"pipework owns its visible collision")
			check(absf(distance-point.distance_to(boiler.to_local(hit.position)))<.001,"fitting collision matches exported triangles")
	# The discharge stays behind the entire moving damper at each draft setting.
	for value in [0.0,.5,1.0]:
		boiler.set_draft(value)
		var clearance := INF
		for part: MeshInstance3D in boiler._draft_damper.find_children("*","MeshInstance3D",true,false):
			for vertex in part.mesh.get_faces():
				var p := boiler.to_local(part.to_global(vertex))
				clearance=minf(clearance,absf(p.z-.95))
		check(clearance>.025,"moving damper remains clear of discharge leg")
	for layer in world.player.carried_device.get_children():
		if layer is CanvasLayer:layer.hide()
	var camera := Camera3D.new()
	world.add_child(camera);camera.make_current();camera.fov=60
	var fill := OmniLight3D.new()
	world.add_child(fill);fill.light_energy=.3;fill.omni_range=4
	var index := 0
	for pair in [[Vector3(1.4,2.2,-1.3),Vector3(0,1.8,0)],[Vector3(-1.3,1.2,-.1),Vector3(-.65,.7,.25)],[Vector3(.5,2.5,1.8),Vector3(0,1.9,.5)]]:
		camera.global_position=boiler.to_global(pair[0]);camera.look_at(boiler.to_global(pair[1]));fill.global_position=camera.global_position
		await get_tree().create_timer(.3).timeout
		await shot("pipework_"+str(index));index+=1
	camera.global_position=world.adapter.root.to_global(Vector3(10.8,-1.676,-4.3))
	camera.look_at(world.adapter.root.to_global(Vector3(10.8,-.65,-.55)))
	fill.global_position=camera.global_position;fill.omni_range=6
	await get_tree().create_timer(.3).timeout
	await shot("pipework_header_and_hangers")
	fill.queue_free();camera.queue_free()
	world.player.global_position=boiler.to_global(Vector3(.1,.02,-2.0));world.player.camera.make_current()
	world.player.camera.look_at(boiler.to_global(Vector3(0,2,.1)));world.player.set_lamp_enabled(true)
	await get_tree().create_timer(2).timeout
	await shot("pipework_production_lamp")
	print("BOILER PIPEWORK: %d contacts; %d triangles; failures=%d" % [probes.size(),triangles,failures.size()])
	world.shutdown_for_tests();world.free();get_tree().quit(0 if failures.is_empty() else 1)
