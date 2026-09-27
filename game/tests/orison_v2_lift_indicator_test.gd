extends "res://tests/orison_v2_floor_surface_test.gd"
## Ceiling contact, headroom and real-height needle alignment across all stops.
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
	var lift := world.elevator as OrisonElevator
	var indicator: Variant = lift._indicator_visual
	var case_bounds: AABB = indicator.transform*indicator.housing.get_aabb()
	var mounts_bounds: AABB = indicator.transform*indicator.mounts.get_aabb()
	check(case_bounds.end.y<2.24 and case_bounds.position.y>2.0,"entire dial fits below car ceiling and above headroom")
	check(case_bounds.end.z<.934,"housing is in front of the moving gate without overlap")
	check(absf(mounts_bounds.end.y-2.24)<.0001,"ceiling mount geometry meets ceiling plane")
	for x in [-.105,.105]:
		var at: Vector3 = indicator.position+Vector3(x,0,-.006)
		var from := Vector3(at.x,2.20,at.z)
		var to := Vector3(at.x,2.28,at.z)
		var ray := PhysicsRayQueryParameters3D.create(lift._cabin.to_global(from),lift._cabin.to_global(to),1,[world.player.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==lift._cabin,"mount seats against actual car ceiling collider")
		if not hit.is_empty(): check(absf(lift._cabin.to_local(hit.position).y-mounts_bounds.end.y)<.001,"no gap between bracket and physical ceiling")
	check(indicator.labels.size()==lift.stop_order.size(),"every served stop has a runtime label")
	lift.set_physics_process(false)
	var original_y := lift._cabin.position.y
	var samples := 0
	for index in lift.stop_order.size():
		var level: String = lift.stop_order[index]
		var label := indicator.labels[index] as Label3D
		check(label.text==OrisonElevator.PLATE_LEGEND.get(level,level),"floor legend agrees with production destination")
		check(indicator.position.y+label.position.y+.025<2.24,"whole label clears ceiling")
		lift._cabin.position.y=float(lift.stops[level])
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(absf(lift._cabin.position.y-float(lift.stops[level]))<.001,"physics applies requested inspection height")
		lift._drive_cab_hardware()
		var direction := Vector3(label.position.x,label.position.y,0).normalized()
		check((lift._needle.basis*Vector3.UP).dot(direction)>.9999,"needle points to matching stop from actual car height")
		samples+=1
		if index+1<lift.stop_order.size():
			var next_label := indicator.labels[index+1] as Label3D
			lift._cabin.position.y=(float(lift.stops[level])+float(lift.stops[lift.stop_order[index+1]]))*.5
			await get_tree().physics_frame
			await get_tree().physics_frame
			lift._drive_cab_hardware()
			var halfway := (direction+Vector3(next_label.position.x,next_label.position.y,0).normalized()).normalized()
			check((lift._needle.basis*Vector3.UP).dot(halfway)>.9999,"needle interpolates between stops without changing current destination")
			samples+=1
	lift._cabin.position.y=original_y
	await get_tree().physics_frame
	await get_tree().physics_frame
	lift._drive_cab_hardware()
	lift.set_physics_process(true)
	await get_tree().physics_frame
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=65
	camera.global_position=lift._cabin.to_global(Vector3(0,1.70,-.18))
	camera.look_at(lift._cabin.to_global(indicator.position+Vector3(0,.07,-.03)))
	await shot("indicator_from_cab")
	camera.global_position=lift._cabin.to_global(Vector3(.10,2.10,.42))
	camera.look_at(lift._cabin.to_global(indicator.position+Vector3(0,.08,-.03)))
	await shot("indicator_detail")
	print("LIFT INDICATOR: height_samples=%d ceiling_contacts=2 failures=%d" % [samples,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
