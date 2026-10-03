extends "res://tests/orison_v2_lift_joinery_test.gd"
## Check the actual moving triangles and physics, not just an angle's sign.
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
	var samples := 0
	for record in [[boiler._fire_door, "fire_door", .66], [boiler._ash_door, "ash_door", .58]]:
		var hinge: Node3D=record[0]
		var control: String=record[1]
		var width: float=record[2]
		var fixed := hinge.position
		var original := hinge.transform
		var triangles := PackedVector3Array()
		for mesh: MeshInstance3D in hinge.find_children("*","MeshInstance3D",true,false):
			var relative := hinge.global_transform.affine_inverse()*mesh.global_transform
			for vertex in mesh.mesh.get_faces(): triangles.append(relative*vertex)
		boiler.interact_control(control,world.player)
		# A SceneTreeTimer may expire in the first expensive production frame
		# before its newly created tween has ticked. Start sampling after that.
		await get_tree().process_frame
		await get_tree().process_frame
		for i in 7:
			await get_tree().create_timer(.1).timeout
			check(hinge.position.is_equal_approx(fixed),"hinge stays seated during opening")
			var edge := boiler.to_local(hinge.to_global(Vector3(width,0,0)))
			check(edge.z<fixed.z-.001,"free edge swings into service aisle, never into firebox")
			for vertex in triangles:
				if vertex.x<.08: continue # hinge barrel and its fixed seating allowance
				check((hinge.transform*vertex).z<fixed.z+.028,"moving casting clears the boiler casing throughout opening")
			samples+=1
		var origin := Vector3(width*.65,.04,-.2)
		var ray := PhysicsRayQueryParameters3D.create(hinge.to_global(origin),hinge.to_global(origin+Vector3.BACK*.4),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(hit.get("collider")==hinge.get_node("LeafCollision"),"open leaf has actual solid collision")
		if not hit.is_empty():
			var visual_distance := _mesh_distance(triangles,origin,Vector3.BACK)
			check(absf(visual_distance-origin.distance_to(hinge.to_local(hit.position)))<.001,"solid leaf meets the rendered plate")
		boiler.interact_control(control,world.player)
		await get_tree().create_timer(.65).timeout
		check(hinge.transform.is_equal_approx(original),"closing returns the plate to its original seat")
		# Immediate restore/debug path must use the same physical swing.
		if control=="fire_door": boiler.set_fire_door_open(true,0)
		else: boiler.set_ash_door_open(true,0)
		check(boiler.to_local(hinge.to_global(Vector3(width,0,0))).z<fixed.z-.5,"immediate opening also clears the casing")
	# Player-height inspection with the real production lamp and carried HUD.
	world.player.global_position=boiler.to_global(Vector3(.4,.02,-2.2))
	world.player.camera.look_at(boiler.to_global(Vector3(0,.92,-.65)))
	world.player.set_lamp_enabled(true)
	await get_tree().create_timer(1).timeout
	await shot("boiler_doors_outward_player")
	var camera := Camera3D.new()
	world.player.carried_device.hide()
	for layer in world.player.carried_device.get_children():
		if layer is CanvasLayer: layer.hide()
	world.add_child(camera); camera.make_current()
	camera.global_position=boiler.to_global(Vector3(-1.0,1.45,-1.8))
	camera.look_at(boiler.to_global(Vector3(-.2,.8,-.7)))
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.global_position=camera.global_position
	fill.light_energy=.3; fill.omni_range=3
	await shot("boiler_doors_outward_detail")
	print("BOILER DOOR SWING: doors=2 animated_samples=%d failures=%d" % [samples,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
