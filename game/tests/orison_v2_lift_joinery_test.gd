extends "res://tests/orison_v2_floor_surface_test.gd"
## Actual imported triangles, structural wall contact and preserved mounting gaps.
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
	var wood := lift._cab_joinery.find_child("CabJoinery",true,false) as MeshInstance3D
	var paint := lift._cab_joinery.find_child("RearEnamel",true,false) as MeshInstance3D
	check(wood.mesh is ArrayMesh and paint.mesh is ArrayMesh,"Blender wood and enamel batches installed")
	check(lift._cab_panel_visuals.size()==12,"original six double-box panels retained as references")
	for old: MeshInstance3D in lift._cab_panel_visuals: check(not old.visible,"old box panel hidden")
	var faces := wood.mesh.get_faces()
	var paint_faces := paint.mesh.get_faces()
	var stations: Array = []
	for side in [-1.0,1.0]:
		for z in [-1.0,-.42,.22,.90]: stations.append([Vector3(0,.5,z),Vector3.RIGHT*side,faces])
	for x in [-.70,0.0,.70]: stations.append([Vector3(x,.5,0),Vector3.FORWARD,faces])
	for point in [Vector3(-.64,1.52,0),Vector3(.64,1.52,0),Vector3(0,1.045,0),Vector3(0,2.0025,0)]:
		stations.append([point,Vector3.FORWARD,paint_faces])
	var contacts := 0
	for station in stations:
		var origin: Vector3 = station[0]
		var direction: Vector3 = station[1]
		var distance := _mesh_distance(station[2],origin,direction)
		check(is_finite(distance),"previously bare wall station has an actual finish triangle")
		var ray := PhysicsRayQueryParameters3D.create(lift._cabin.to_global(origin),lift._cabin.to_global(origin+direction*1.2),1,[world.player.get_rid()])
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==lift._cabin,"finish has original structural car wall behind it")
		if not hit.is_empty():
			var wall_distance := origin.distance_to(lift._cabin.to_local(hit.position))
			check(distance<wall_distance and wall_distance-distance<=.028,"finish remains within its shallow wall envelope")
		contacts+=1
	for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD]:
		check(not is_finite(_mesh_distance(faces,Vector3(0,.92,0),direction)),"handrail mounting course remains clear")
	for z in [.802,.958]:
		check(not is_finite(_mesh_distance(faces,Vector3(0,.735,z),Vector3.RIGHT)),"real bore clears existing control-panel mounting stem")
		check(is_finite(_mesh_distance(faces,Vector3(0,.735,z+.012),Vector3.RIGHT)),"wood remains beside control mounting bore")
	check(not is_finite(_mesh_distance(paint_faces,Vector3(0,1.52,0),Vector3.FORWARD)),"rear enamel has a real opening around live mirror")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=85
	world.mirror_renderer._main_camera=camera
	camera.global_position=lift._cabin.to_global(Vector3(0,1.45,.70))
	camera.look_at(lift._cab_mirror.mirror_center()+Vector3.DOWN*.52)
	await shot("finished_cab_joinery")
	camera.fov=65
	camera.global_position=lift._cabin.to_global(Vector3(.10,.73,-.30))
	camera.look_at(lift._cabin.to_global(Vector3(.725,.58,-.11)))
	await shot("raised_panel_detail")
	print("LIFT JOINERY: wall_probes=%d control_bores=2 failures=%d" % [contacts,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _mesh_distance(faces: PackedVector3Array, origin: Vector3, direction: Vector3) -> float:
	var nearest := INF
	for i in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
		if hit!=null: nearest=minf(nearest,origin.distance_to(hit))
	return nearest
