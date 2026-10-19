extends RefCounted
## Actual installed geometry, window recesses and retained roof bearings.
## Captures are posed visual review, never walking or occupied-interior proof.
func run(world: OrisonV2RuntimeRoot,suite: Node) -> void:
	var city := world.get_node("CityShells") as Node3D
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_elevations.json"))
	suite.check(FileAccess.get_sha256("res://assets/props/city_elevations.glb")==fixture.asset_sha256,"city elevation native export matches installed asset")
	var bodies: Dictionary={}
	var parts := 0
	var triangles := 0
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		if not draw.get_meta("retained_city_shell",false):continue
		parts+=1
		var faces := draw.mesh.get_faces()
		triangles+=faces.size()/3
		var body := draw.get_parent().get_node(str(draw.name)+"Collision") as StaticBody3D
		var shape := body.get_child(0) as CollisionShape3D
		var physical := shape.shape as ConcavePolygonShape3D
		suite.check(physical!=null and physical.get_faces()==faces and shape.global_transform.is_equal_approx(draw.global_transform),"city visible faces have identical physical backing: "+str(draw.name))
		bodies[body.get_rid()]=str(draw.name)
		var source: Material=draw.get_meta("v2_city_roof_source",draw.material_override)
		var stock := source as StandardMaterial3D
		suite.check(stock!=null and not stock.uv1_triplanar and stock.normal_enabled,"city source consumes authored UVs and enabled normal maps: "+str(draw.name))
		if stock!=null:
			for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
				suite.check(texture!=null and texture.get_image().has_mipmaps(),"city custom PBR has a real loaded mip chain")
	suite.check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"full installed city inventory matches the rebuilt native source")
	suite.check(fixture.buildings.size()==25 and int(fixture.windows)>2500,"all 25 city buildings have physically built window stock")
	for building: Dictionary in fixture.buildings:
		suite.check(int(building.new_setbacks)<=1,"no repeated ziggurat tiers: "+str(building.id))
	var exclusions: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if not bodies.has(body.get_rid()):exclusions.append(body.get_rid())
	# Probe the actual primary elevations at four heights. A claim in a JSON
	# counter cannot conceal recessed intermediate tiers in the installed mesh.
	for building: Dictionary in fixture.buildings:
		var r: Array=building.main_rect
		for fraction: float in [.12,.36,.64,.88]:
			var height := lerpf(float(building.shaft_bottom),float(building.setback_height),fraction)
			for station: Array in [
				[Vector3(r[0]+.12,height,-r[1]),Vector3(0,0,1)],
				[Vector3(r[2]-.12,height,-r[3]),Vector3(0,0,-1)],
				[Vector3(r[0],height,-r[1]-.12),Vector3(-1,0,0)],
				[Vector3(r[2],height,-r[3]+.12),Vector3(1,0,0)]]:
				var p: Vector3=city.to_global(station[0])
				var n: Vector3=city.global_basis*station[1]
				var ray := PhysicsRayQueryParameters3D.create(p+n*.04,p-n*.04,1,exclusions)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				suite.check(not hit.is_empty() and str(bodies.get(hit.collider.get_rid(),"")).begins_with(str(building.id)+"__") and hit.position.distance_to(p)<.0001,"installed main elevation stays continuous between base and upper setback: "+str(building.id))
	var contacts := 0
	for asset: String in ["masts","aerials","tanks"]:
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_"+asset+".json"))
		for contact: Dictionary in original.contacts:
			var n := city.global_basis*Vector3(contact.normal[0],contact.normal[2],-contact.normal[1])
			for sample: Array in [contact.point]+contact.footprint:
				var p := city.to_global(Vector3(sample[0],sample[2],-sample[1]))
				var ray := PhysicsRayQueryParameters3D.create(p+n*.03,p-n*.03,1,exclusions)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				suite.check(not hit.is_empty() and bodies.has(hit.collider.get_rid()) and hit.position.distance_to(p)<.0001,"retained city hardware full footprint bears within 100 micrometres: "+str(contact.id)+" "+str(sample))
				contacts+=1
	var sampled: Dictionary={}
	for window: Dictionary in fixture.window_rows:
		var id := str(window.building)+"/"+str(window.side)
		if sampled.has(id):continue
		sampled[id]=true
		var a: Array=window.pane_sample
		var p := Vector3(a[0],a[1],a[2])
		var out: Vector3=[Vector3(0,-1,0),Vector3(1,0,0),Vector3(0,1,0),Vector3(-1,0,0)][int(window.side)]
		var ray := PhysicsRayQueryParameters3D.create(city.to_global(Vector3(p.x,p.z,-p.y)+Vector3(out.x,0,-out.y)*.1),city.to_global(Vector3(p.x,p.z,-p.y)-Vector3(out.x,0,-out.y)*.3),1,exclusions)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		var expected := city.to_global(Vector3(p.x,p.z,-p.y)-Vector3(out.x,0,-out.y)*(float(window.recess_m)+.044))
		suite.check(not hit.is_empty() and str(bodies.get(hit.collider.get_rid(),"")).ends_with("__mirror_aged") and hit.position.distance_to(expected)<.0001,"actual glazed pane is recessed behind masonry and sash: "+id)
	suite.check(contacts>=1205 and sampled.size()>=80,"bearing and window probes cover the complete city roster")
	var ground: Node3D = world.adapter.root.get_node("Ground")
	var apron := ground.find_child("DistantApron", true, false) as Node3D
	var apron_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_ground_apron.json"))
	suite.check(apron != null and FileAccess.get_sha256("res://assets/props/city_ground_apron.glb") == apron_source.asset_sha256, "installed distant grade matches the native source")
	suite.check(FileAccess.get_sha256("res://assets/props/orison_ground.glb") == apron_source.retained_ground_sha256, "retained ground and its underground reservations remain byte-identical")
	var apron_samples := 0
	if apron != null:
		for row: Dictionary in apron_source.boxes:
			var bounds: Array = row.bounds
			for x_fraction: float in [.1, .5, .9]:
				for z_fraction: float in [.1, .5, .9]:
					var p: Vector3 = world.adapter.root.to_global(Vector3(lerpf(bounds[0], bounds[3], x_fraction), bounds[4], lerpf(bounds[2], bounds[5], z_fraction)))
					var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.03,p-Vector3.UP*.03,1,[world.player.get_rid()]))
					suite.check(not hit.is_empty() and apron.is_ancestor_of(hit.collider) and hit.position.distance_to(p)<.0001, "distant ground has its actual fitted physical top: "+str(row.id))
					apron_samples += 1
	suite.check(apron_samples == 36, "physical distant grade covers all four source strips")
	var prior := world.get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	camera.fov=70
	world.add_child(camera)
	camera.make_current()
	var atmosphere := world.get_node("WakingAtmosphere")
	var manager: Node=atmosphere.weather_manager
	var was_processing := manager.is_processing()
	manager.set_process(false)
	var original_conditions: Dictionary = manager.current.duplicate(true)
	manager._publish()
	atmosphere.director._apply(world.campaign_clock.minute_of_day())
	for view: Dictionary in fixture.skyline_views_godot:
		var a: Array=view.at
		var b: Array=view.target
		var root: Node3D=world.adapter.root
		camera.global_position=root.to_global(Vector3(a[0],a[1]+1.6,a[2]))
		camera.look_at(root.to_global(Vector3(b[0],b[1],b[2])))
		await suite.get_tree().create_timer(.6).timeout
		await suite.shot("city_"+str(view.id))
	# Select upper windows and verify their actual first-hit sightline; low
	# source windows can be hidden by the real construction canopy.
	for identity: String in ["site_nbr_e","site_ne1","site_back_e"]:
		var found := false
		for window: Dictionary in fixture.window_rows:
			if str(window.building)!=identity or int(window.side)!=0 or float(window.center[2])<8.5:continue
			var a: Array=window.center
			var p := city.to_global(Vector3(a[0],a[2],-a[1]))
			for offset: Vector3 in [Vector3(2,.2,5),Vector3(-2,.2,5),Vector3(0,.6,3),Vector3(1,1.5,2)]:
				var eye := p+city.global_basis*offset
				var ray := PhysicsRayQueryParameters3D.create(eye,p-city.global_basis*Vector3(0,0,.3),1,[world.player.get_rid()])
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				if hit.is_empty() or not str(bodies.get(hit.collider.get_rid(),"")).begins_with(identity+"__") or hit.position.distance_to(p)>.36:continue
				camera.global_position=eye;camera.look_at(p);found=true
				await suite.get_tree().create_timer(.6).timeout
				await suite.shot("city_"+identity+"_window")
				break
			if found:break
		suite.check(found,"city window capture has an actual unobstructed first-hit sightline: "+identity)
	# Presentation-only comparisons in the same composed world and camera.
	# They grant no played exterior access or live-network weather acceptance.
	var root: Node3D = world.adapter.root
	camera.global_position = root.to_global(Vector3(-14,20.8,-7.5))
	camera.look_at(root.to_global(Vector3(-26.5,30,-8)))
	for state: Dictionary in [
		{"id":"dry", "weather_code":0, "relative_humidity":.65,"cloud_total":.12,"cloud_low":.04,"cloud_mid":.03,"cloud_high":.10,"precipitation_intensity":0.0,"rain_intensity":0.0},
		{"id":"storm", "weather_code":63,"relative_humidity":.95,"cloud_total":1.0,"cloud_low":.9,"cloud_mid":.9,"cloud_high":.6,"precipitation_intensity":1.0,"rain_intensity":1.0},
		{"id":"fog", "weather_code":45,"relative_humidity":1.0,"cloud_total":.8,"cloud_low":.8,"cloud_mid":.4,"cloud_high":.2,"precipitation_intensity":0.0,"rain_intensity":0.0},
	]:
		manager.current = state.duplicate(true)
		manager._publish()
		var expected := preload("res://scripts/building/v2_city_day_night_director.gd").city_visibility(state)
		suite.check(is_equal_approx(atmosphere.environment.fog_depth_begin,expected.x) and is_equal_approx(atmosphere.environment.fog_depth_end,expected.y) and is_equal_approx(atmosphere.environment.fog_density,1.0), "same director owns the actual weather visibility: "+str(state.id))
		await suite.get_tree().create_timer(1.0).timeout
		await suite.shot("city_weather_"+str(state.id))
	manager.current = original_conditions
	manager._publish()
	camera.global_position = root.to_global(Vector3(140,8,82))
	camera.look_at(root.to_global(Vector3(110,-.02,64)))
	await suite.get_tree().create_timer(.6).timeout
	await suite.shot("city_ground_seam")
	manager.set_process(was_processing)
	if is_instance_valid(prior):prior.make_current()
	camera.free()
	print("CITY ELEVATION REVIEW: parts=%d triangles=%d windows=%d bearing_samples=%d window_stations=%d" % [parts,triangles,int(fixture.windows),contacts,sampled.size()])
