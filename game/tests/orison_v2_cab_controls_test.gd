extends "res://tests/orison_v2_floor_surface_test.gd"
## Real input-area reach, plate mounting and production-driven button motion.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lift := world.elevator as OrisonElevator
	if lift==null or world.player==null:
		check(false,"production lift initialized"); world.free(); get_tree().quit(1); return
	world.player.set_physics_process(false); world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var plate := lift._cabin_controls.plate as MeshInstance3D
	check(plate.mesh is ArrayMesh,"Blender cab plate installed")
	var bounds: AABB = plate.transform*plate.get_aabb()
	check(bounds.end.z>.983 and bounds.end.z<.995,"board contains existing legends and clears the landing leaves")
	var reaches := 0
	for control: String in lift._cabin_controls.buttons:
		var cap := lift._cabin_controls.buttons[control] as MeshInstance3D
		var area := lift._cabin_controls.areas[control] as Area3D
		check(cap.mesh is ArrayMesh,"independent rounded Blender cap")
		if control!="alarm": check(cap.material_override==lift._cabin_lamps[control],"production request lamp retained")
		var ray := PhysicsRayQueryParameters3D.create(cap.global_position+lift._cabin.global_basis*Vector3(-.5,.035,-.04),cap.global_position,1,[world.player.get_rid()])
		ray.collide_with_areas=true
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==area,"actual ray reaches original control area before wall")
		reaches+=1
	# Lower backplate spacers bridge the exposed wall below the upper enamel field.
	for z in [.802,.958]:
		var ray := PhysicsRayQueryParameters3D.create(lift._cabin.to_global(Vector3(.70,.735,z)),lift._cabin.to_global(Vector3(.77,.735,z)),1,[world.player.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==lift._cabin,"lower panel mounts contact actual car wall")
		if not hit.is_empty(): check(absf(lift._cabin.to_local(hit.position).x-.750)<.001,"lower mounting surface retained")
	var cap := lift._cabin_controls.buttons[lift.current] as MeshInstance3D
	var rest := cap.position.x
	lift.interact_area(lift._cabin_controls.areas[lift.current])
	var presentation := lift.get_node("CabControls")
	var motion := presentation.buttons[lift.current].tween as Tween
	motion.pause(); motion.custom_step(.09)
	check(absf(cap.position.x-rest-.003)<.0002,"button depresses three millimetres through its collar")
	lift.interact_area(lift._cabin_controls.areas[lift.current])
	check(not motion.is_valid(),"repeat press cancels old motion")
	await get_tree().create_timer(.4).timeout
	check(absf(cap.position.x-rest)<.0001 and not lift.moving,"button returns without spurious travel")
	lift._bell.stop()
	lift.interact_area(lift._cabin_controls.areas["alarm"])
	check(lift._bell.playing,"original alarm still rings production bell")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=75
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.omni_range=2; fill.light_energy=.16
	camera.global_position=lift._cabin.to_global(Vector3(.06,1.16,.70))
	camera.look_at(lift._cabin.to_global(Vector3(.716,1.1475,.88)))
	fill.global_position=camera.global_position
	await shot("cab_controls_installed")
	print("CAB CONTROLS: reachable_controls=%d failures=%d" % [reaches,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
