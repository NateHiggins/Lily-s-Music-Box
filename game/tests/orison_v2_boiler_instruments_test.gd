extends "res://tests/orison_v2_boiler_body_test.gd"
## Fitted instrument connections and moving handle clearance in production.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.set_physics_process(false)
	for layer in world.player.carried_device.get_children():
		if layer is CanvasLayer:layer.hide()
	var boiler := world.adapter.resolve("B1_BOILER_01") as BoilerProp
	var camera := Camera3D.new()
	world.add_child(camera);camera.make_current();camera.fov=50
	camera.global_position=boiler.to_global(Vector3(.9,1.13,-1.2))
	camera.look_at(boiler.to_global(Vector3(.50,1.08,-.58)))
	var fill := OmniLight3D.new()
	world.add_child(fill);fill.global_position=camera.global_position;fill.light_energy=.3;fill.omni_range=2
	for value in [1.0,0.0]:
		boiler._set_column_cocks(value)
		for cock: Node3D in boiler._column_cocks:
			var rear := -INF
			for mesh: MeshInstance3D in cock.find_children("*","MeshInstance3D",true,false):
				for vertex in mesh.mesh.get_faces():rear=maxf(rear,boiler.to_local(mesh.to_global(vertex)).z)
			check(rear<-.620,"open and closed handles clear the tube and guards")
		await get_tree().create_timer(.3).timeout
		await shot("water_glass_"+("open" if value>0 else "closed"))
	camera.global_position=boiler.to_global(Vector3(.61,1.51,-.72))
	camera.look_at(boiler.to_global(Vector3(.31,1.48,-.55)));fill.global_position=camera.global_position
	await get_tree().create_timer(.3).timeout
	await shot("gauge_mount")
	var faces := PackedVector3Array()
	for mesh: MeshInstance3D in boiler._carcass.find_children("*","MeshInstance3D",true,false):
		for vertex in mesh.mesh.get_faces():faces.append(boiler.to_local(mesh.to_global(vertex)))
	var report: Array=[]
	for point in [Vector3(.57,.82,-.547),Vector3(.57,1.34,-.547),Vector3(.42,1.48,-.5442),Vector3(.57,.72,-.60)]:
		var query := PhysicsRayQueryParameters3D.create(boiler.to_global(point),boiler.to_global(point+Vector3.LEFT*.2),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		var distance := _mesh_distance(faces,point,Vector3.LEFT)
		check(hit.get("collider")==boiler.get_node("BoilerCollision") and distance<.2,"each formerly empty joint has a connected instrument fitting")
		if not hit.is_empty():check(absf(distance-point.distance_to(boiler.to_local(hit.position)))<.001,"mount collision meets the actual fitted triangles")
		report.append({"origin":[point.x,point.y,point.z],"solid_found":not hit.is_empty()})
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("mounts.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	world.shutdown_for_tests();world.free()
	print("BOILER INSTRUMENTS: four fitted contacts, four moving-handle poses; failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
