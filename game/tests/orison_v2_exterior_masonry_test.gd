extends "res://tests/orison_v2_boiler_body_test.gd"
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,12*60)
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var masonry: Node3D=world.adapter.root.get_node("ExteriorMasonry")
	var contacts := 0
	for mesh: MeshInstance3D in masonry.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			check(material!=null and material.albedo_texture!=null,"masonry uses a texture-backed catalogue material")
			var arrays := mesh.mesh.surface_get_arrays(surface)
			check(arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"exported surface has mapped UVs")
		var faces := mesh.mesh.get_faces()
		for index in range(0,faces.size(),150):
			var a: Vector3=faces[index];var b: Vector3=faces[index+1];var c: Vector3=faces[index+2]
			var normal := (c-a).cross(b-a).normalized()
			var center := (a+b+c)/3.0
			var query := PhysicsRayQueryParameters3D.create(mesh.to_global(center+normal*.02),mesh.to_global(center-normal*.02),1,[world.player.get_rid()])
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty(),"fabricated shell surface has physical backing")
			if not hit.is_empty():check(mesh.to_global(center).distance_to(hit.position)<.021,"shell contact follows visible geometry")
			contacts+=1
	check(contacts>50,"distributed shell contact coverage")
	world.player.set_physics_process(false)
	world.player.set_process_unhandled_input(false)
	world.player.set_lamp_enabled(false)
	for layer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var camera := world.player.camera
	camera.make_current()
	var views := [
		["street_front",Vector3(0,1.524,-20),Vector3(0,4,-11.65)],
		["street_left",Vector3(-12,1.524,-17),Vector3(-9,3,-11.65)],
		["street_right",Vector3(12,1.524,-17),Vector3(9,3,-11.65)],
		["alley_side",Vector3(17,1.524,-4),Vector3(15.65,3,-4)],
		["alley_core",Vector3(17,1.524,6),Vector3(13.2,3,6)],
		["rear_entry",Vector3(8.9,1.524,12.9),Vector3(8.9,2,9.25)],
		["upper_front",Vector3(0,15,-22),Vector3(0,12,-6)],
		["upper_rear",Vector3(0,15,20),Vector3(0,12,7)]]
	for view in views:
		world.player.global_position=world.adapter.root.to_global(view[1])-Vector3.UP*world.player.STANDING_EYE
		camera.global_position=world.adapter.root.to_global(view[1])
		camera.look_at(world.adapter.root.to_global(view[2]))
		await get_tree().create_timer(.6).timeout
		await shot(view[0])
	print("EXTERIOR MASONRY: failures=%d" % failures.size())
	world.shutdown_for_tests();world.free();get_tree().quit(0 if failures.is_empty() else 1)

