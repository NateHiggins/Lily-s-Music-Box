extends RefCounted
## Independent short-ray wall census, actual trim bounds, and seasonal captures.
func run(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var shell: Node3D = world.adapter.root
	coverage(shell,world,suite)
	await details(world,suite)
	await captures(world,suite)

func coverage(shell: Node3D, world: Node3D, suite: Node) -> void:
	var missing: Array = []
	var sampled := 0
	var casing_boxes: Array[AABB] = []
	for draw: MultiMeshInstance3D in world.find_children("DoorCasings","MultiMeshInstance3D",true,false):
		for i in draw.multimesh.instance_count:
			casing_boxes.append(draw.global_transform*draw.multimesh.get_instance_transform(i)*draw.multimesh.mesh.get_aabb())
	for draw: MeshInstance3D in world.find_children("FittedWindowJoinery","MeshInstance3D",true,false):
		casing_boxes.append(draw.global_transform*draw.mesh.get_aabb())
	for record: Dictionary in shell.layout.spaces:
		if record.get("open_shell",false): continue
		var room := shell.get_node_or_null(str(record.id)) as Node3D
		if room==null: continue
		var rect: Array = record.rect
		var heights: Array[float] = [.07]
		if str(record.get("class","")) in ["private","public"] or "PUBLIC_CORE" in str(record.id): heights.append(1.65)
		if str(record.get("class",""))=="public" or "PUBLIC_CORE" in str(record.id): heights.append(1.34)
		var floor_y: float = shell.level_y[record.level]
		for side in 4:
			var along_x := side<2
			var low: float = rect[0 if along_x else 1]
			var high: float = rect[2 if along_x else 3]
			var edge: float = rect[[1,3,0,2][side]]
			var inward := Vector3(0,0,1 if side==0 else -1) if along_x else Vector3(1 if side==2 else -1,0,0)
			var count := maxi(1,ceili((high-low)/.25))
			for i in count:
				var at := lerpf(low+.10,high-.10,(float(i)+.5)/count)
				for height: float in heights:
					var boundary := Vector3(at,floor_y+height,edge) if along_x else Vector3(edge,floor_y+height,at)
					var query := PhysicsRayQueryParameters3D.create(shell.to_global(boundary+inward*.20),shell.to_global(boundary-inward*.20),1)
					var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
					if hit.is_empty() or not str(hit.collider.get_parent().name).begins_with("Wall"): continue
					var point: Vector3 = shell.to_local(hit.position)+inward*.005
					sampled+=1
					var at_casing := false
					for box: AABB in casing_boxes:
						if box.grow(.004).has_point(shell.to_global(point)): at_casing=true;break
					if not at_casing and not _contains_trim(room,point,height):
						missing.append({"room":record.id,"height":height,"point":[point.x,point.y,point.z],"wall":str(hit.collider.get_parent().get_path())})
	suite.check(sampled>10000,"independent wall rays cover all closed V2 rooms")
	suite.check(missing.is_empty(),"continuous baseboard/eye rail/panel cap at every sampled actual wall face")
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("millwork-coverage.json"),FileAccess.WRITE).store_string(JSON.stringify({"sampled_wall_faces":sampled,"gaps":missing},"\t"))

func captures(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var atmosphere := world.get_node("WakingAtmosphere")
	var manager: Node = atmosphere.weather_manager
	suite.check(manager!=null and manager.provider._awaiting=="","offline NYC weather owner starts without network requests")
	var camera := Camera3D.new();camera.fov=70;world.add_child(camera);camera.make_current()
	world.player.carried_device.set_capture_hidden(true)
	for child: Node in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	# Clear skyline above the tallest local structure; the world stays loaded.
	camera.global_position=world.player.global_position+Vector3(0,35,0)
	camera.look_at(camera.global_position+Vector3(0,12,-30),Vector3.UP)
	manager.set_process(false)
	for month in [1,4,7,10]:
		world.campaign_clock.configure_date(1928,month,15,750)
		var snapshot := preload("res://scripts/building/WeatherManager.gd").seasonal_snapshot({"month":month})
		var conditions := LiveWeatherService.presentation(snapshot)
		conditions["season_weights"]=preload("res://scripts/building/WeatherManager.gd").season_weights(month)
		atmosphere.director.set_live_conditions(conditions)
		atmosphere.director._apply(750)
		atmosphere.sky_material.set_shader_parameter("season_weights",conditions.season_weights)
		atmosphere.sky_material.set_shader_parameter("humidity",conditions.relative_humidity)
		await suite.get_tree().create_timer(.5).timeout
		await suite.shot("weather_season_%02d" % month)
	for shape in [1,2,3]:
		atmosphere.sky_material.set_shader_parameter("shape_kind",shape)
		atmosphere.sky_material.set_shader_parameter("shape_opacity",1.0)
		atmosphere.sky_material.set_shader_parameter("cloud_coverage",.12)
		camera.look_at(camera.global_position+Vector3(1.6,2.3,-2.6)*20,Vector3.UP)
		await suite.shot("cloud_shape_%d" % shape)
	manager.set_process(true);manager._publish()
	camera.queue_free();world.player.camera.make_current()

func _contains_trim(room: Node3D, point: Vector3, height: float) -> bool:
	var label := "PublicWainscotCap" if is_equal_approx(height,1.34) else "HistoricMillwork"
	var draw := room.get_node_or_null(label) as MultiMeshInstance3D
	if draw==null: return false
	var bounds := draw.multimesh.mesh.get_aabb()
	for i in draw.multimesh.instance_count:
		var box: AABB = draw.multimesh.get_instance_transform(i)*bounds
		if box.grow(.003).has_point(point): return true
	return false

func details(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var camera := Camera3D.new();camera.fov=55;world.add_child(camera);camera.make_current()
	world.player.carried_device.set_capture_hidden(true)
	var fill := OmniLight3D.new();fill.light_energy=.5;fill.omni_range=3;world.add_child(fill)
	for label: String in ["HistoricMillwork","PublicWainscotCap"]:
		var captured := false
		for draw: MultiMeshInstance3D in world.find_children(label,"MultiMeshInstance3D",true,false):
			for i in draw.multimesh.instance_count:
				var t := draw.global_transform*draw.multimesh.get_instance_transform(i)
				if t.basis.x.length()<1.5: continue
				if label=="HistoricMillwork" and t.basis.y.length()<.1: continue
				var at := t.origin
				var eye := at+t.basis.z.normalized()*.85+Vector3.UP*.15
				var blocked := false
				for offset in [-.25,0.0,.25]:
					var query := PhysicsRayQueryParameters3D.create(eye,at+t.basis.x.normalized()*offset,1,[world.player.get_rid()])
					if not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): blocked=true
				if blocked: continue
				camera.global_position=eye;camera.look_at(at);fill.global_position=eye+Vector3.UP*.2
				await suite.shot("continuous_"+label)
				captured=true;break
			if captured: break
		suite.check(captured,"clear production millwork detail: "+label)
	fill.queue_free();camera.queue_free();world.player.camera.make_current()
	var effects: Node=world.get_node("WeatherFX")
	var rect: Array=world.layout.spaces.filter(func(r):return r.id=="F01_LOBBY")[0].rect
	var point := Vector3((rect[0]+rect[2])*.5,world.adapter.root.level_y.F01+1.0,(rect[1]+rect[3])*.5)
	suite.check(effects.covered(world.adapter.root.to_global(point)),"actual lobby ceiling suppresses outdoor weather")
	var roof_y: float=world.adapter.root.level_y.ROOF
	suite.check(effects.exposed(world.adapter.root.to_global(Vector3(point.x,roof_y+10,point.z))),"unobstructed sky above roof permits outdoor weather")
