extends "res://tests/orison_v2_floor_surface_test.gd"
## Installed gate fabrication, articulation and separation from landing leaves.
## The existing elevator route suite supplies ordinary passenger collision.
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Gate inspection requires a windowed MultiMesh renderer")
		get_tree().quit(2); return
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lift := world.elevator as OrisonElevator
	if lift==null or world.player==null:
		check(false,"production lift initialized")
		world.free(); get_tree().quit(1); return
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var visual := lift._gate.get_node("ArticulatedGate")
	for child in lift._gate.get_children():
		if child is MeshInstance3D: check(not child.visible,"primitive gate bars are not double-rendered")
	check(visual.links.multimesh.instance_count==50 and visual.pivots.multimesh.instance_count==61,"complete lattice and sliding carriers installed")
	check(visual.tracks.multimesh.instance_count==2,"fixed upper and lower tracks installed")
	check(visual.find_children("*","CollisionObject3D",true,false).is_empty(),"visual replacement adds no independent barrier")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current()
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.light_energy=.15; fill.omni_range=3
	var sample_count := 0
	for open_t in [0.0,.5,1.0]:
		lift._set_door_t(lift.current,open_t)
		lift._drive_cab_hardware()
		await get_tree().process_frame
		await get_tree().process_frame
		var parent_basis: Basis = lift._cabin.global_basis.inverse()*visual.global_basis
		check(parent_basis.get_scale().is_equal_approx(Vector3.ONE),"owner squash is canceled for manufactured metal thickness")
		for index in 42:
			var pose: Transform3D = visual.links.multimesh.get_instance_transform(index)
			check(absf(pose.basis.y.length()-visual.LINK_LENGTH)<.0001,"hinged link length stays fixed throughout folding")
			check(absf(pose.basis.x.length()-1)<.0001 and absf(pose.basis.z.length()-1)<.0001,"link width and thickness are not squeezed")
			for end in [-.5,.5]:
				var endpoint := pose*Vector3(0,end,0)
				var found := false
				for joint in 61:
					var at: Vector3 = visual.pivots.multimesh.get_instance_transform(joint).origin
					if Vector2(endpoint.x,endpoint.y).distance_to(Vector2(at.x,at.y))<.0001: found=true; break
				check(found,"each link endpoint remains on a physical pivot")
			for corner in 8:
				var at: Vector3 = lift._cabin.to_local(visual.links.to_global(pose*visual.links.multimesh.mesh.get_aabb().get_endpoint(corner)))
				check(at.z<.985,"gate metal stays behind the closed landing-leaf rear face")
			sample_count+=1
		for index in 61:
			var pose: Transform3D = visual.pivots.multimesh.get_instance_transform(index)
			check(pose.basis.get_scale().is_equal_approx(Vector3.ONE),"pivot pins retain real dimensions")
		camera.global_position = lift._cabin.to_global(Vector3(.12,1.25,-.30))
		camera.look_at(lift._cabin.to_global(Vector3(0,1.2,.95)))
		fill.global_position=camera.global_position
		await shot("car_gate_"+str(int(open_t*100)))
	# Hall view must show the landing steel in front of the closed car gate.
	lift._set_door_t(lift.current,0)
	lift._drive_cab_hardware()
	await get_tree().process_frame
	camera.fov=100
	var y := float(lift.stops[lift.current])
	camera.global_position=lift.to_global(Vector3(0,y+1.2,1.9))
	camera.look_at(lift.to_global(Vector3(0,y+1.2,OrisonElevator.FRONT_Z)))
	fill.global_position=camera.global_position; fill.light_energy=.35
	await shot("landing_gate_separation")
	print("LIFT GATE: articulation_samples=%d failures=%d" % [sample_count,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
