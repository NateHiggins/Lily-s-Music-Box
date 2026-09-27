extends "res://tests/orison_v2_floor_surface_test.gd"
## Verify the mounted Blender assembly against actual car walls and clearance.
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
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var cabin := lift._cabin
	check(lift._cab_handrails.size()==7,"original three grips and four brackets retained as references")
	for old: MeshInstance3D in lift._cab_handrails: check(not old.visible,"old primitive handrail hidden")
	var assembly := lift._cab_rail_visual
	check(assembly!=null and assembly.get_parent()==cabin,"fabricated rails move with production car")
	var mounts := 0
	var grips := 0
	for part in assembly.get_children():
		if not part is MeshInstance3D: continue
		check(part.mesh is ArrayMesh,"fabricated geometry imported from Blender")
		var bounds: AABB = part.transform*part.get_aabb()
		if str(part.name).begins_with("Grip"):
			grips+=1
			check(absf(bounds.get_center().y-.92)<.0001,"grip retains its installed height")
			check(bounds.position.y>.898 and bounds.end.y<.942,"grip section remains within its original envelope")
		if not str(part.name).begins_with("WallFlange"): continue
		var at: Vector3 = bounds.get_center()
		var inward: Vector3 = Vector3.BACK if at.z< -1.05 else Vector3.LEFT*signf(at.x)
		var back: Vector3 = at-inward*.002
		check(bounds.position.y>.9 and bounds.end.y<.94,"flange fits bare wall course without overlapping oak trim")
		var ray := PhysicsRayQueryParameters3D.create(cabin.to_global(back+inward*.025),cabin.to_global(back-inward*.025),1,[world.player.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==cabin,"support meets actual car wall collider")
		if not hit.is_empty(): check(hit.position.distance_to(cabin.to_global(back))<.001,"flange rear flush within one millimetre")
		mounts+=1
	check(grips==3 and mounts==6,"all three grips have two wall supports")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=85
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.omni_range=3; fill.light_energy=.22
	for station in ["rear", "support"]:
		camera.fov=85 if station=="rear" else 65
		camera.global_position=cabin.to_global(Vector3(0,1.25,.65) if station=="rear" else Vector3(.32,.78,-.70))
		camera.look_at(cabin.to_global(Vector3(0,.92,-1.002) if station=="rear" else Vector3(.55,.92,-1.060)))
		fill.global_position=camera.global_position
		await shot("handrail_"+station)
	print("LIFT HANDRAILS: grips=%d wall_contact_probes=%d failures=%d" % [grips,mounts,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
