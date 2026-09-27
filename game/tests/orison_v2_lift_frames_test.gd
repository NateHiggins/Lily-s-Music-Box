extends "res://tests/orison_v2_floor_surface_test.gd"
## Installed lift joinery inspection: supported reveals and clean head joints.
## Passenger travel and barrier behavior belong to the elevator route suite.
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
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var fill := OmniLight3D.new()
	world.add_child(fill)
	fill.light_energy = .4; fill.omni_range = 4
	var contacts := 0
	var library := (load("res://assets/props/millwork_profile.glb") as PackedScene).instantiate()
	var expected := (library.find_child("LiftReveal",true,false) as MeshInstance3D).mesh
	library.free()
	check(lift.stop_order.size()==7,"all seven landings are inspected")
	for level: String in lift.stop_order:
		var head := lift._landing_frames[level]["head"] as MeshInstance3D
		var head_bounds := head.transform*head.get_aabb()
		for suffix: String in ["west","east","head"]:
			var frame := lift._landing_frames[level][suffix] as MeshInstance3D
			var bounds := frame.transform*frame.get_aabb()
			check(frame.mesh==expected,"landing uses the imported Blender reveal")
			check(frame.get_child_count()==0,"frame adds no collision or input owner")
			check(frame.material_override.metallic>.7,"existing brass material retained")
			check(absf(bounds.position.z-(OrisonElevator.FRONT_Z-.1))<.0001 and absf(bounds.end.z-(OrisonElevator.FRONT_Z+.1))<.0001,"reveal retains its original depth envelope")
			if frame!=head:
				check(absf(bounds.end.y-head_bounds.position.y)<.0001,"upright meets header without overlapping coplanar faces")
				check(absf(bounds.position.y-float(lift.stops[level]))<.0001,"upright rests at the landing floor")
				check(bounds.end.x<=-.455+.0001 or bounds.position.x>=.455-.0001,"full clear opening remains")
			var at := bounds.get_center()
			# Probe the mounting lap over structural wall, not the reveal's
			# unsupported inner edge or the closed sliding panel behind it.
			if frame==head: at.y=bounds.end.y-.025
			else: at.x=signf(at.x)*(maxf(absf(bounds.position.x),absf(bounds.end.x))-.02)
			var ray := PhysicsRayQueryParameters3D.create(lift.to_global(Vector3(at.x,at.y,OrisonElevator.FRONT_Z+.25)),lift.to_global(Vector3(at.x,at.y,OrisonElevator.FRONT_Z-.15)),1,[world.player.get_rid()])
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider is StaticBody3D and absf(lift.to_local(hit.position).z-OrisonElevator.FRONT_Z-.06)<.003,level+suffix+" has actual shaft-wall backing at the hall face")
			contacts+=1
		# Keep the moving-panel ownership check separate from wall-ray evidence.
		# Real input-driven crossing is exercised by the elevator route suite.
		for side: String in ["w","e"]:
			var body := lift._doors[level][side] as AnimatableBody3D
			check(body.get_child(0) is CollisionShape3D,"moving panel retains its collision")
		if level in [lift.stop_order.front(),lift.current,lift.stop_order.back()]:
			# This hall is narrow: a distant camera falls behind its far wall.
			# A wide lens from inside the walkable aisle shows the whole frame.
			camera.fov = 110
			camera.global_position = lift.to_global(Vector3(0,float(lift.stops[level])+1.2,1.9))
			camera.look_at(lift.to_global(Vector3(0,float(lift.stops[level])+1.2,OrisonElevator.FRONT_Z)))
			var view_ray := PhysicsRayQueryParameters3D.create(camera.global_position,lift.to_global(Vector3(0,float(lift.stops[level])+1.2,OrisonElevator.FRONT_Z+.11)),1,[world.player.get_rid()])
			view_ray.hit_from_inside = true
			check(world.get_world_3d().direct_space_state.intersect_ray(view_ray).is_empty(),"inspection camera has a clear hall-side view")
			fill.global_position = camera.global_position
			await shot("landing_"+level)
	# Supplemental close-up of the actual installed joint under neutral fill.
	camera.fov = 75
	var target := lift.to_global(Vector3(.485,float(lift.stops[lift.current])+2.14,1.2))
	camera.global_position = target+lift.global_basis*Vector3(-.14,.07,.55)
	camera.look_at(target); camera.make_current()
	fill.global_position = camera.global_position
	fill.light_energy = .12; fill.omni_range = 2
	await shot("lift_reveal_joint")
	print("LIFT FRAMES: stops=%d wall_contacts=%d failures=%d" % [lift.stop_order.size(),contacts,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
