extends "res://tests/orison_v2_lift_joinery_test.gd"
## Final batched knuckles remain coaxial through both production swing directions.
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
	var installed: Array[DoorProp]=[]
	for node in world.adapter.root.find_children("*","Node3D",true,false):
		if node is DoorProp and not node.hinge_meshes.is_empty(): installed.append(node)
	check(installed.size()==105,"all 105 supported doors have fabricated hinges")
	var contacts := 0
	var poses := 0
	for fraction in [0.0,.5,1.0]:
		for door: DoorProp in installed: door._body.rotation.y=door.motion_target_angle(true)*fraction
		await get_tree().physics_frame
		await get_tree().physics_frame
		for door: DoorProp in installed:
			check(absf(door._body.rotation.y-door.motion_target_angle(true)*fraction)<.001,"actual animatable body reaches sampled pose")
			for y in [.26,door.height*.5,door.height-.26]:
				var fixed_axis: Vector3=door._fixed.to_global(Vector3(0,y,-door._hinge_offset))
				var moving_axis: Vector3=door._body.to_global(Vector3(0,y,0))
				check(fixed_axis.distance_to(moving_axis)<.0001,"fixed pin and moving knuckles remain coaxial")
				if fraction==0:
					var fixed_distance := _batched_distance(door._fixed,Vector3(-.004,y-.04,-door._hinge_offset-.10),Vector3.BACK)
					var moving_distance := _batched_distance(door._body,Vector3(-.004,y+.02,-.10),Vector3.BACK)
					var expected := .1-sqrt(.008*.008-.004*.004)
					check(absf(fixed_distance-expected)<.0002,"actual fixed barrel mesh lies on physical hinge axis")
					check(absf(moving_distance-expected)<.0002,"actual moving barrel mesh lies on physical hinge axis")
					contacts+=1
			poses+=1
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=55
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.omni_range=1; fill.light_energy=.12
	var captured: Dictionary={}
	for door: DoorProp in installed:
		if captured.has(door.swing_out): continue
		var target := Vector3(0,door.height*.5,-door._hinge_offset)
		camera.global_position=door.to_global(target+Vector3(.18,.015,0))
		camera.look_at(door.to_global(target))
		fill.global_position=camera.global_position
		await shot("hinge_"+("outward" if door.swing_out else "inward"))
		captured[door.swing_out]=true
	check(captured.size()==2,"both hinge faces rendered")
	print("DOOR HINGES: assemblies=%d body_poses=%d failures=%d" % [contacts,poses,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _batched_distance(root: Node3D,origin: Vector3,direction: Vector3) -> float:
	var nearest := INF
	for part in root.get_children():
		if part is MeshInstance3D:
			nearest=minf(nearest,_mesh_distance(part.mesh.get_faces(),part.transform.affine_inverse()*origin,part.basis.inverse()*direction))
	return nearest
