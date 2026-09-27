extends "res://tests/orison_v2_floor_surface_test.gd"
## Installed call-station geometry, mounting contact and button travel.
## The elevator route suite covers ordinary input, passenger rides and recall.
func _run() -> void:
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
	var source := (load("res://assets/props/lift_call_plate.glb") as PackedScene).instantiate()
	var plate_mesh := (source.find_child("CallPlate",true,false) as MeshInstance3D).mesh
	var cap_mesh := (source.find_child("ButtonCap",true,false) as MeshInstance3D).mesh
	source.free()
	var contacts := 0
	var reach_probes := 0
	for level: String in lift.stop_order:
		var controls: Dictionary = lift._landing_controls[level]
		var plate := controls.plate as MeshInstance3D
		var cap := controls.button as MeshInstance3D
		var area := controls.area as Area3D
		check(plate.mesh==plate_mesh and cap.mesh==cap_mesh,"shared Blender plate and independent cap installed")
		check(cap.material_override==lift._buttons[level],"existing request indicator material remains authoritative")
		check(plate.get_child_count()==1 and plate.get_child(0) is MeshInstance3D,"only the two-screw visual batch is added")
		var hardware: AABB = plate.transform*plate.get_aabb()
		var ray := PhysicsRayQueryParameters3D.create(plate.global_position+lift.global_basis*Vector3(0,.05,.12),plate.global_position+lift.global_basis*Vector3(0,.05,-.02),1,[world.player.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider is StaticBody3D and absf(lift.to_local(hit.position).z-hardware.position.z)<.0002,"plate back seats on actual shaft wall")
		contacts+=1
		var query := PhysicsRayQueryParameters3D.create(cap.global_position+lift.global_basis*Vector3(0,.45,.55),cap.global_position,1,[world.player.get_rid()])
		query.collide_with_areas = true
		var reach: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not reach.is_empty() and reach.collider==area,"eye-height ray reaches the existing call area before wall")
		reach_probes+=1
		var shape := area.get_child(0) as CollisionShape3D
		var envelope := AABB(area.position-(shape.shape as BoxShape3D).size*.5,(shape.shape as BoxShape3D).size)
		check(envelope.encloses(hardware),"plate, collar and fixings fit inside existing input envelope")
		check(envelope.encloses(cap.transform*cap.get_aabb()),"raised cap is within the reachable input envelope")
	check(contacts==7 and reach_probes==7,"all passenger call stations are inspected")
	var current: Dictionary = lift._landing_controls[lift.current]
	var cap := current.button as MeshInstance3D
	var rest := cap.position.z
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var fill := OmniLight3D.new()
	world.add_child(fill)
	fill.omni_range = 2; fill.light_energy = .05
	var at := (current.plate as MeshInstance3D).global_position
	camera.global_position = at+lift.global_basis*Vector3(-.07,.04,.27)
	camera.look_at(at+lift.global_basis*Vector3(0,0,.015))
	fill.global_position = camera.global_position
	await shot("call_plate_detail")
	# Drive the real call entry point, then sample the engine Tween at its
	# pressed detent explicitly: shader compilation must not skip this brief
	# pose on a slow first render. Repeat/release below runs on the live clock.
	lift.interact_area(current.area)
	var presentation := lift.get_node("LandingControls")
	var motion := presentation.buttons[lift.current].tween as Tween
	motion.pause()
	motion.custom_step(.09)
	check(absf(cap.position.z-rest+.003)<.0002,"physical button depresses three millimetres")
	await shot("call_plate_pressed")
	lift.interact_area(current.area)
	check(not motion.is_valid(),"repeat press cancels the previous motion")
	await get_tree().create_timer(.4).timeout
	check(absf(cap.position.z-rest)<.0001 and not lift.moving,"rapid repeat returns cap to rest without moving the idle car")
	camera.global_position = at+lift.global_basis*Vector3(-.2,.25,.62)
	camera.look_at(at)
	fill.global_position = camera.global_position
	fill.light_energy = .2
	await shot("call_plate_installed")
	print("LIFT CONTROLS: plates=%d wall_contacts=%d reach_probes=%d failures=%d" % [lift.stop_order.size(),contacts,reach_probes,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
