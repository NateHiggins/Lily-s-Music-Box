extends "res://tests/orison_v2_lift_joinery_test.gd"
## Model fit, moving-part ownership and physical service faces on all roof fans.
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
	world.add_child(camera); camera.make_current(); camera.fov=60
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.omni_range=3; fill.light_energy=.5
	var count := 0
	var actuations := 0
	for anchor in world.adapter.root.find_children("*","Node3D",true,false):
		if not anchor is ExhaustFanProp: continue
		var fan = anchor
		if not "fabricated" in fan: continue
		count+=1
		check(not fan.get_node("StaticCarcass").visible,"primitive housing hidden")
		var rotor := fan._rotor.get_node("Rotor") as MeshInstance3D
		var shutter := fan._louver.get_node("Shutter") as MeshInstance3D
		check(rotor.mesh is ArrayMesh and shutter.mesh is ArrayMesh,"Blender moving parts mounted on production pivots")
		var paint := fan.fabricated.get_node("Paint") as MeshInstance3D
		var iron := fan.fabricated.get_node("Iron") as MeshInstance3D
		check(is_finite(_mesh_distance(iron.mesh.get_faces(),Vector3(.305,.42,-.6),Vector3.BACK)),"belt inspection face has a real guard cover")
		check(not is_finite(_mesh_distance(paint.mesh.get_faces(),Vector3(0,.84,-.6),Vector3.BACK)),"rain hood leaves an actual discharge gap")
		check(is_finite(_mesh_distance(paint.mesh.get_faces(),Vector3(.0001,1.1,.0001),Vector3.DOWN)),"rain hood centre is closed")
		check(_mesh_distance(paint.mesh.get_faces(),Vector3(.26,.70,.26),Vector3.DOWN)<.08,"square-to-round apron closes housing corner")
		var ray := PhysicsRayQueryParameters3D.create(fan.to_global(Vector3(0,.08,-.6)),fan.to_global(Vector3(0,.08,0)),1)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==fan.get_node("PlantCollision"),"original physical curb remains installed")
		if not hit.is_empty(): check(absf(fan.to_local(hit.position).z+.36)<.001,"fabricated curb matches actual collision front")
		fan.set_running(true,true)
		var before: Basis=fan._rotor.basis
		await get_tree().create_timer(.12).timeout
		check(not fan._rotor.basis.is_equal_approx(before),"automatic owner rotates imported blades")
		check(absf(fan._louver.rotation.x-deg_to_rad(-24))<.001,"running state opens imported gravity shutter")
		fan.set_running(false,true)
		check(is_zero_approx(fan._louver.rotation.x),"stopped state closes shutter")
		actuations+=1
		check("SERVICE ISOLATION REQUIRED" in str(fan.service_wire_card().condition),"guard refusal retained")
		camera.global_position=fan.to_global(Vector3(1.15,.95,-1.35))
		camera.look_at(fan.to_global(Vector3(0,.48,0)))
		fill.global_position=camera.global_position
		await shot("roof_ventilator_"+str(fan.riser))
		if count==1:
			camera.global_position=fan.to_global(paint.get_aabb().end+paint.get_aabb().size)
			camera.look_at(fan.to_global(paint.get_aabb().get_center()))
			fill.global_position=camera.global_position
			await shot("roof_ventilator_reverse")
	check(count==4 and actuations==4,"all four variant machines tested")
	print("ROOF VENTILATORS: machines=%d actuations=%d failures=%d" % [count,actuations,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
