extends "res://tests/orison_v2_lift_joinery_test.gd"
## Imported fixture clearance, actual ceiling contact and original light ownership.
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
	var assembly := lift._cab_lamp_visual
	check(assembly.get_parent()==lift._cabin,"fixture follows actual moving car")
	check(lift._cab_lamp_parts.size()==17,"old dome and segmented ring retained")
	for old: MeshInstance3D in lift._cab_lamp_parts: check(not old.visible,"primitive lamp hidden")
	var lights := 0
	for child in lift._cabin.get_children():
		if child is OmniLight3D:
			lights+=1
			check(is_equal_approx(child.light_energy,.9) and is_equal_approx(child.omni_range,3),"existing light output preserved")
	check(lights==1,"fixture does not add duplicate lights")
	var bowl := assembly.find_child("OpalBowl",true,false) as MeshInstance3D
	check(bowl.material_override==lift._dome,"opal retains production emission material")
	for part in assembly.get_children():
		if not part is MeshInstance3D: continue
		check(part.mesh is ArrayMesh,"fabricated part uses imported mesh")
		var bounds: AABB=part.transform*part.get_aabb()
		check(bounds.position.y>=2.1279 and bounds.end.y<=2.2401,"fixture clears headroom and ceiling slab")
	var plate := assembly.find_child("CeilingPlate",true,false) as MeshInstance3D
	var probes := 0
	for offset in [Vector3(.15,0,0),Vector3(-.15,0,0),Vector3(0,0,.15),Vector3(0,0,-.15)]:
		var origin: Vector3 = Vector3(0,2.245,.02)+offset
		var distance := _mesh_distance(plate.mesh.get_faces(),origin,Vector3.DOWN)
		check(absf(distance-.005)<.0001,"imported plate rear seats at ceiling surface")
		var start: Vector3 = origin-Vector3.UP*.1
		var ray := PhysicsRayQueryParameters3D.create(lift._cabin.to_global(start),lift._cabin.to_global(origin),1,[world.player.get_rid()])
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==lift._cabin,"fixture mounts to real cab ceiling collider")
		if not hit.is_empty(): check(absf(lift._cabin.to_local(hit.position).y-2.24)<.001,"actual ceiling contact is flush")
		probes+=1
	check(is_finite(_mesh_distance(bowl.mesh.get_faces(),Vector3(.08,2.0,.02),Vector3.UP)),"opal bowl covers actual lower aperture")
	check(is_finite(_mesh_distance(bowl.mesh.get_faces(),Vector3(.0001,2.0,.0201),Vector3.UP)),"closed lathe pole has no central pinhole")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=75
	world.mirror_renderer._main_camera=camera
	var target: Vector3=lift._cabin.to_global(bowl.get_aabb().get_center())
	camera.global_position=target+Vector3(0,-.62,.65)
	camera.look_at(target)
	await shot("ceiling_lamp_fitted")
	camera.global_position=target+Vector3(.29,-.23,.31); camera.fov=60
	camera.look_at(target)
	await shot("ceiling_lamp_detail")
	print("LIFT LAMP: ceiling_contacts=%d original_lights=%d failures=%d" % [probes,lights,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
