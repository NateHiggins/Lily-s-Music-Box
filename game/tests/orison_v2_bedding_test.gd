extends "res://tests/orison_v2_space_sweep.gd"
## Imported bedding contacts and installed views; routes run in separate suites.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().create_timer(.5).timeout
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(true)
	for layer in world.player.carried_device.get_children():
		if layer is CanvasLayer:layer.hide()
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_furniture.json"))
	var beds := 0
	var contacts := 0
	var unique_meshes := {}
	for record: Dictionary in source.furniture:
		if record.kind!="bed":continue
		var body := world.adapter.resolve(record.id) as StaticBody3D
		check(body!=null,"bed identity remains its physical owner")
		if body==null:continue
		var w: float=float(record.bounds[1][0])-float(record.bounds[0][0])
		var length: float=float(record.bounds[1][2])-float(record.bounds[0][2])
		var faces := PackedVector3Array()
		var meshes := body.find_children("*","MeshInstance3D",true,false)
		check(meshes.size()==4,"four batched bed roles replace the source surfaces")
		var head_z := 0.0
		var pillow_z := 0.0
		for mesh: MeshInstance3D in meshes:
			unique_meshes[mesh.mesh.get_instance_id()]=true
			var transform := body.global_transform.affine_inverse()*mesh.global_transform
			for v in mesh.mesh.get_faces():
				var local: Vector3=transform*v
				faces.append(local)
				if str(mesh.name).ends_with("Frame") and local.y>.75:head_z+=local.z
				if str(mesh.name).ends_with("Pillows"):pillow_z+=local.z
		check(head_z*pillow_z>0,"pillows sit at the preserved headboard end")
		for origin in [Vector3(0,1.2,.2),Vector3(-.29,1.2,length*.5-.33),Vector3(.29,1.2,length*.5-.33),Vector3(0,1.2,length*.5-.56)]:
			var nearest := INF
			for i in range(0,faces.size(),3):
				var hit: Variant=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
				if hit!=null:nearest=minf(nearest,origin.distance_to(hit))
			var query := PhysicsRayQueryParameters3D.create(body.to_global(origin),body.to_global(origin+Vector3.DOWN*1.25),1,[world.player.get_rid()])
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(hit.get("collider")==body and is_finite(nearest) and absf(nearest-origin.distance_to(body.to_local(hit.get("position",Vector3.ZERO))))<.001,"bedding contact matches visible triangles: "+str(record.id))
			contacts+=1
		var across := PhysicsRayQueryParameters3D.create(body.to_global(Vector3(-w*.5-.1,.75,0)),body.to_global(Vector3(w*.5+.1,.75,0)),1,[world.player.get_rid()])
		check(world.get_world_3d().direct_space_state.intersect_ray(across).get("collider")!=body,"no obsolete box remains above the blanket")
		var captured := false
		var stations: Array[Vector3]=[]
		for x in [-w*.5-.7,w*.5+.7]:
			for z in [.4,-.1]:stations.append(Vector3(x,.03,z))
		for z in [-length*.5-.7,length*.5+.7]:stations.append(Vector3(0,.03,z))
		for station in stations:
			if captured:continue
			var at := body.to_global(station)
			var feet: Vector3=world.adapter.root.to_local(at)
			if not _clear_station(world,feet):continue
			var sight := PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.41,body.to_global(Vector3(0,.45,0)),1,[world.player.get_rid()])
			if world.get_world_3d().direct_space_state.intersect_ray(sight).get("collider")!=body:continue
			world.player.global_position=at
			world.player.face_world_point(body.to_global(Vector3(0,.45,0)))
			await get_tree().create_timer(.4).timeout
			await shot(str(record.id)+"_bedding")
			captured=true
		check(captured,"a clear installed bed inspection stance exists: "+str(record.id))
		beds+=1
	check(beds==14,"all fourteen installed beds reviewed")
	check(unique_meshes.size()==12,"three shared variants with four material batches each")
	print("BEDDING: beds=%d contacts=%d shared_meshes=%d failures=%d" % [beds,contacts,unique_meshes.size(),failures.size()])
	world.shutdown_for_tests();world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
