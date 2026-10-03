extends "res://tests/orison_v2_lift_joinery_test.gd"
## All installed registers: imported open slots and real plenum contact.
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
	world.add_child(camera); camera.make_current(); camera.fov=65
	# Inspection fill exposes folded-sheet geometry on the normally shaded underside.
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.omni_range=1.2; fill.light_energy=.3
	var total := 0
	var openings := 0
	var captured: Dictionary={}
	for stack in world.adapter.root.get_node("VentilationDucts").get_children():
		for identity: String in stack.get_meta("registers"):
			var anchor := world.adapter.resolve(identity) as Node3D
			var grille := anchor.find_child("Grille",true,false) as MeshInstance3D
			check(grille!=null and grille.mesh is ArrayMesh,"installed Blender grille "+identity)
			if grille==null: continue
			var faces := grille.mesh.get_faces()
			for i in 8:
				var gap := Vector3(.013,-.1,-.105+float(i)*.03)
				check(not is_finite(_mesh_distance(faces,gap,Vector3.UP)),"actual open louver slot "+identity)
				openings+=1
			check(is_finite(_mesh_distance(faces,Vector3(.013,-.1,0),Vector3.UP)),"positive control strikes louver sheet")
			for x in [-.17,.17]:
				var at := Vector3(x,-.05,0)
				var ray := PhysicsRayQueryParameters3D.create(anchor.to_global(at),anchor.to_global(at+Vector3.UP*.1),1,[world.player.get_rid()])
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty() and hit.collider==stack,"grille seats beneath its assigned physical plenum")
				if not hit.is_empty(): check(absf(anchor.to_local(hit.position).y)<.001,"plenum underside remains flush with flange rear")
			var bounds: AABB=grille.transform*grille.get_aabb()
			check(bounds.position.y>=-.022 and bounds.end.y<=.0001,"folded grille remains below plenum without penetration")
			if not captured.has(stack.name):
				camera.global_position=anchor.to_global(Vector3(.18,-.55,-.22))
				camera.look_at(anchor.global_position)
				fill.global_position=camera.global_position
				await shot("register_"+str(stack.name))
				captured[stack.name]=true
			total+=1
	check(total==23 and captured.size()==4,"all passive registers and four stacks covered")
	print("VENT REGISTERS: installations=%d open_slots=%d failures=%d" % [total,openings,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
