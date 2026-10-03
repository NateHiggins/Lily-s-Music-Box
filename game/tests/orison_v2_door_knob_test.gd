extends "res://tests/orison_v2_lift_joinery_test.gd"
## Installed hardware after production batching; real leaf collision stays owner.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.set_physics_process(false); world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=55
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.omni_range=1; fill.light_energy=.14
	var doors := 0
	var faces := 0
	var captured: Dictionary={}
	for node in world.adapter.root.find_children("*","Node3D",true,false):
		if not node is DoorProp: continue
		var door := node as DoorProp
		if door.knob_mesh==null: continue
		check(door.knob_mesh is ArrayMesh,"installed source uses Blender hardware")
		check(not is_finite(_mesh_distance(door.knob_mesh.get_faces(),Vector3(.001,-.108,.02),Vector3.FORWARD)),"real keyhole aperture retained")
		check(is_finite(_mesh_distance(door.knob_mesh.get_faces(),Vector3(.01,-.108,.02),Vector3.FORWARD)),"positive control hits metal beside keyhole")
		var half_depth := .026 if door.door_kind=="service" else .022
		for face in [-1.0,1.0]:
			var at := Vector3(door.width-.070,.87,door._hinge_offset+face*(half_depth+.04))
			var direction: Vector3 = Vector3.FORWARD*face
			var nearest := INF
			for part in door._body.get_children():
				if part is MeshInstance3D:
					nearest=minf(nearest,_mesh_distance(part.mesh.get_faces(),part.transform.affine_inverse()*at,part.basis.inverse()*direction))
			check(absf(nearest-.035)<.0002,"backplate is exposed on flat leaf rather than buried in panel moulding")
			if door.door_kind=="service":
				var corner := Vector3(door.width-.104,.862,door._hinge_offset+face*(half_depth+.04))
				var corner_distance := INF
				for part in door._body.get_children():
					if part is MeshInstance3D:
						corner_distance=minf(corner_distance,_mesh_distance(part.mesh.get_faces(),part.transform.affine_inverse()*corner,part.basis.inverse()*direction))
				check(absf(corner_distance-.035)<.0002,"service diagonal clears lower backplate corner")
			var ray := PhysicsRayQueryParameters3D.create(door._body.to_global(at),door._body.to_global(at+direction*.1),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider==door._body,"existing moving collision remains under each backplate")
			faces+=1
		if not captured.has(door.door_kind):
			var target := Vector3(door.width-.085,.955,door._hinge_offset-half_depth)
			camera.global_position=door._body.to_global(target+Vector3(.12,.025,-.32))
			camera.look_at(door._body.to_global(target))
			fill.global_position=camera.global_position
			await shot("knob_"+door.door_kind)
			captured[door.door_kind]=true
		doors+=1
	check(doors==105 and faces==210 and captured.size()==3,"all 105 domestic, entry and service leaves covered")
	print("DOOR KNOBS: doors=%d fitted_faces=%d failures=%d" % [doors,faces,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
