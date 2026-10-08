extends "res://tests/orison_v2_city_sweep.gd"
## Imported bedding contacts and installed views; routes run in separate suites.
var batch_mode := false
var capture_enabled := true
func _ready() -> void:
	if not batch_mode: _run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().create_timer(.5).timeout
	var result: Dictionary = await validate_in_world(world)
	world.shutdown_for_tests();world.free()
	get_tree().quit(0 if result.failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bedding.json"))
	check(FileAccess.get_sha256(str(fixture.asset))==fixture.asset_sha256,"bedding export bound")
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(true)
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/domestic_furniture.json"))
	var templates: Dictionary={}
	for row: Dictionary in source.furniture:templates[row.id]=row
	var completion: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/completion_interiors.json"))
	for row: Dictionary in completion.furniture:
		if templates[row.template].kind!="bed":continue
		var copy: Dictionary=templates[row.template].duplicate(true);copy.id=row.id;source.furniture.append(copy)
	var beds := 0
	var requested := OS.get_environment("ORISON_FABRICATION_ACTORS").split(",",false)
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
		var pillow_low := INF
		var mattress_high := -INF
		for mesh: MeshInstance3D in meshes:
			unique_meshes[mesh.mesh.get_instance_id()]=true
			var transform := body.global_transform.affine_inverse()*mesh.global_transform
			for v in mesh.mesh.get_faces():
				var local: Vector3=transform*v
				faces.append(local)
				if str(mesh.name).ends_with("Frame") and local.y>.75:head_z+=local.z
				if str(mesh.name).ends_with("Pillows"):pillow_z+=local.z
				if str(mesh.name).ends_with("Pillows"):pillow_low=minf(pillow_low,local.y)
				if str(mesh.name).ends_with("Mattress"):mattress_high=maxf(mattress_high,local.y)
		check(head_z*pillow_z>0,"pillows sit at the preserved headboard end")
		# Imported compressed vertices round the native 0.051 mm intrusion to
		# 0.100 mm; include 0.010 mm for that bound's float representation.
		check(absf(pillow_low-mattress_high)<.00011,"compressed pillow undersides meet mattress within 0.11 mm: %s low=%.8f top=%.8f" % [record.id,pillow_low,mattress_high])
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
			if captured and not str(record.id).contains("C_"):continue
			var at := body.to_global(station)
			if not _city_clear_station(world,at):continue
			var sight := PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.41,body.to_global(Vector3(0,.45,0)),1,[world.player.get_rid()])
			if world.get_world_3d().direct_space_state.intersect_ray(sight).get("collider")!=body:continue
			world.player.global_position=at
			world.player.face_world_point(body.to_global(Vector3(0,.45,0)))
			await get_tree().create_timer(.4).timeout
			if capture_enabled and (requested.is_empty() or str(record.id) in requested): await shot(str(record.id)+"_bedding_"+str(stations.find(station)))
			captured=true
		check(captured,"a clear installed bed inspection stance exists: "+str(record.id))
		beds+=1
	check(beds==22,"all original and completion-template installed beds inspected")
	check(unique_meshes.size()==12,"three shared variants with four material batches each")
	print("BEDDING: beds=%d contacts=%d shared_meshes=%d failures=%d" % [beds,contacts,unique_meshes.size(),failures.size()])
	return {"checks":checks,"failures":failures,"beds":beds,"contacts":contacts,"shared_meshes":unique_meshes.size()}
