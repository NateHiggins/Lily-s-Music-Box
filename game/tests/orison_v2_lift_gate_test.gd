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
	await validate_in_world(world)
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var old_camera_pose := world.player.camera.transform
	var old_player_pose := world.player.global_transform
	var old_fov: float = world.player.camera.fov
	var lift := world.elevator as OrisonElevator
	var original_open: float=lift._doors[lift.current].t
	var visual := lift._gate.get_node("ArticulatedGate")
	for child in lift._gate.get_children():
		if child is MeshInstance3D: check(not child.visible,"primitive gate bars are not double-rendered")
	var expected := {"DrilledLink":42,"CrossPin_n4_p4":14,"CrossPin_n10_p10":7,
		"BottomPin_p4":1,"BottomRoller":8,"BottomPin_n4_p4":6,"BottomPin_n4":1,
		"JointPin_n4_p10":2,"JointPin_n10_n4_p4_p10":12,"JointPin_n10_p4":2,
		"TopFollowerPin_n4":1,"UpperGuideTrolley":8,"TopRoller":8,
		"TopFollowerPin_n4_p4":6,"TopFollowerPin_p4":1,"FixedRailsAndMounts":1}
	check(visual.batches.size()==16,"all sixteen manufactured variants installed")
	var instances := 0
	for key: String in expected:
		check(visual.batches.has(key),"required variant " + key)
		var batch: MultiMeshInstance3D = visual.batches[key]
		check(batch.multimesh.instance_count==int(expected[key]),"exact native stock count " + key)
		instances += batch.multimesh.instance_count
		var material: Material = batch.material_override
		check(material is ShaderMaterial and int(material.get_shader_parameter("uv_mode"))==0,
			"finished catalogue brass samples manufactured metre charts " + key)
	check(instances==120,"complete120-stock assembly without obsolete upper carrier pins")
	check(visual.find_children("*","CollisionObject3D",true,false).is_empty(),"visual replacement adds no independent barrier")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current()
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.light_energy=.15; fill.omni_range=3
	var sample_count := 0
	for open_t in [0.0,.1,.2,.3,.4,.5,.6,.7,.8,.9,1.0,.45,.8,.2,0.0]:
		lift._set_door_t(lift.current,open_t)
		lift._drive_cab_hardware()
		await get_tree().process_frame
		await get_tree().process_frame
		var parent_basis: Basis = lift._cabin.global_basis.inverse()*visual.global_basis
		check(parent_basis.get_scale().is_equal_approx(Vector3.ONE),"owner squash is canceled for manufactured metal thickness")
		for index in 42:
			var pose: Transform3D = visual.batches.DrilledLink.multimesh.get_instance_transform(index)
			check(absf(pose.basis.y.length()-1)<.0001,"actual-metre link basis stays rigid throughout folding")
			check(absf(pose.basis.x.length()-1)<.0001 and absf(pose.basis.z.length()-1)<.0001,"link width and thickness are not squeezed")
			check(absf(pose.basis.determinant()-1)<.0001,"hinged link basis preserves proper handedness")
			for end in [-visual.LINK_LENGTH*.5,visual.LINK_LENGTH*.5]:
				var endpoint := pose*Vector3(0,end,0)
				var found := false
				for key: String in expected:
					if not "Pin" in key: continue
					var batch: MultiMeshInstance3D = visual.batches[key]
					for joint in batch.multimesh.instance_count:
						var at: Vector3 = batch.multimesh.get_instance_transform(joint).origin
						if Vector2(endpoint.x,endpoint.y).distance_to(Vector2(at.x,at.y))<.0001:
							var token := ("n" if endpoint.z<0 else "p") + str(roundi(absf(endpoint.z)*1000.0))
							found = found or key.split("_").has(token)
				check(found,"each link endpoint remains on a physical pivot")
			sample_count+=1
		for key: String in expected:
			var batch: MultiMeshInstance3D = visual.batches[key]
			for index in batch.multimesh.instance_count:
				var pose: Transform3D = batch.multimesh.get_instance_transform(index)
				check(pose.basis.get_scale().is_equal_approx(Vector3.ONE) and absf(pose.basis.determinant()-1)<.0001,
					"manufactured pins, rollers, trolleys and rails retain rigid dimensions " + key)
				for corner in 8:
					var at: Vector3 = lift._cabin.to_local(batch.to_global(pose*batch.multimesh.mesh.get_aabb().get_endpoint(corner)))
					check(at.z<.985,"all gate metal stays behind the closed landing-leaf rear face")
		camera.global_position = lift._cabin.to_global(Vector3(.12,1.25,-.30))
		camera.look_at(lift._cabin.to_global(Vector3(0,1.2,.95)))
		fill.global_position=camera.global_position
		if open_t in [0.0,.5,1.0]: await shot("car_gate_"+str(int(open_t*100)))
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
	world.player.global_transform=old_player_pose
	world.player.camera.transform=old_camera_pose
	world.player.camera.fov=old_fov
	world.player.camera.make_current()
	world.mirror_renderer._main_camera=world.player.camera
	camera.free()
	fill.free()
	lift._set_door_t(lift.current,original_open)
	lift._drive_cab_hardware()
	return {"checks":batch_checks,"failures":failures}
