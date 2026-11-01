extends RefCounted
## Actual installed geometry, window recesses and retained roof bearings.
## Captures are posed visual review, never walking or occupied-interior proof.
func run(world: OrisonV2RuntimeRoot,suite: Node) -> void:
	var city := world.get_node("CityShells") as Node3D
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_elevations.json"))
	fixture = preload("res://tests/v2_city_context_review.gd").placed_fixture(fixture)
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
		if draw.has_meta("v2_window_source_material"):
			suite.check(preload("res://scripts/building/v2_background_window_material.gd").glazing_is_bound(draw), "optical glazing samples the original catalogue PBR charts")
			source = draw.get_meta("v2_window_source_material")
		var stock := source as StandardMaterial3D
		suite.check(stock!=null and not stock.uv1_triplanar and stock.normal_enabled,"city source consumes authored UVs and enabled normal maps: "+str(draw.name))
		if stock!=null:
			for texture: Texture2D in [stock.albedo_texture,stock.roughness_texture,stock.normal_texture]:
				suite.check(texture!=null and texture.get_image().has_mipmaps(),"city custom PBR has a real loaded mip chain")
	suite.check(parts==fixture.parts.size() and triangles==int(fixture.triangles),"full installed city inventory matches the rebuilt native source")
	# Check the fitted subgrade in its actual production mount as well as the
	# body-side contacts exercised by the controller frontage contract.
	var foundation_source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_foundations_construction.json"))
	suite.check(FileAccess.get_sha256("res://assets/props/city_foundations.glb")==foundation_source.source_native_sha256,"installed city foundations match their fitted native export")
	var foundation_parts: Dictionary={}
	for row: Dictionary in foundation_source.parts: foundation_parts[str(row.id)]=row
	var foundation_root := world.adapter.root.get_node("CityFoundations") as Node3D
	var foundation_count := 0
	for draw: MeshInstance3D in foundation_root.find_children("*","MeshInstance3D",true,false):
		var identity := str(draw.name)
		suite.check(foundation_parts.has(identity),"fitted foundation partition retains its source identity: "+identity)
		if not foundation_parts.has(identity):continue
		var bounds: Array=foundation_parts[identity].bounds
		var expected := AABB(Vector3(bounds[0],bounds[1],bounds[2]),Vector3(bounds[3]-bounds[0],bounds[4]-bounds[1],bounds[5]-bounds[2]))
		var pose: Transform3D=world.adapter.root.global_transform.affine_inverse()*draw.global_transform
		var actual: AABB=pose*draw.get_aabb()
		suite.check(actual.position.distance_to(expected.position)<.0001 and actual.end.distance_to(expected.end)<.0001,"production foundation is at its actual fitted bounds: "+identity)
		var backing := draw.get_node("GroundCollision") as StaticBody3D
		var shape := backing.get_child(0) as CollisionShape3D
		suite.check(shape.shape is ConcavePolygonShape3D and (shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"fitted foundation has identical visible and physical stock: "+identity)
		foundation_count+=1
	suite.check(foundation_count==foundation_parts.size() and foundation_count==1049,"all fitted foundation partitions are checked in the production world")
	var authored_counts: Dictionary = {}
	for window: Dictionary in fixture.window_rows:
		var identity := str(window.building)
		authored_counts[identity] = int(authored_counts.get(identity, 0)) + 1
	suite.check(fixture.buildings.size()==25 and int(fixture.windows)==fixture.window_rows.size(), "city window total equals the complete authored station inventory")
	for building: Dictionary in fixture.buildings:
		suite.check(int(building.windows)>0 and int(building.windows)==int(authored_counts.get(str(building.id), -1)), "each installed city building has its complete authored window roster: " + str(building.id))
	suite.check(authored_counts.size()==fixture.buildings.size(), "no window station refers to an unknown city building")
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
			var height := lerpf(float(building.shaft_bottom),float(building.get("shaft_top",building.setback_height)),fraction)
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
	# Roof transitions replace full-height perimeter walls; probe the physical
	# sloping stock itself rather than accepting only a lower shaft datum.
	for sample: Dictionary in fixture.roof_samples:
		var point: Array=sample.point
		var direction: Array=sample.normal
		var p := city.to_global(Vector3(point[0],point[2],-point[1]))
		var n := city.global_basis*Vector3(direction[0],direction[2],-direction[1])
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+n*.05,p-n*.05,1,exclusions))
		suite.check(not hit.is_empty() and str(bodies.get(hit.collider.get_rid(),"")).begins_with(str(sample.building)+"__") and hit.position.distance_to(p)<.0001 and hit.normal.dot(n)>.99,"installed architectural roof stock retains physical face and normal: "+str(sample.building))
	var contacts := 0
	for asset: String in ["masts","aerials","tanks"]:
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_"+asset+".json"))
		original = preload("res://tests/v2_city_context_review.gd").placed_fixture(original)
		for contact: Dictionary in original.contacts:
			var n := city.global_basis*Vector3(contact.normal[0],contact.normal[2],-contact.normal[1])
			for sample: Array in [contact.point]+contact.footprint:
				var p := city.to_global(Vector3(sample[0],sample[2],-sample[1]))
				var ray := PhysicsRayQueryParameters3D.create(p+n*.03,p-n*.03,1,exclusions)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				suite.check(not hit.is_empty() and bodies.has(hit.collider.get_rid()) and hit.position.distance_to(p)<.0001,"retained city hardware full footprint bears within 100 micrometres: "+str(contact.id)+" "+str(sample))
				contacts+=1
	var sampled: Dictionary={}
	var pane_controls := false
	var pane_checks := 0
	for window: Dictionary in fixture.window_rows:
		var id := str(window.building)+"/"+str(window.side)
		sampled[id]=true
		var a: Array=window.pane_sample
		var p := Vector3(a[0],a[1],a[2])
		var legacy_out: Vector3=[Vector3(0,-1,0),Vector3(1,0,0),Vector3(0,1,0),Vector3(-1,0,0)][int(window.side)]
		var authored_normal: Array=window.get("normal", [legacy_out.x,legacy_out.y,legacy_out.z])
		var out := Vector3(authored_normal[0],authored_normal[1],authored_normal[2])
		suite.check(out.is_normalized(), "city pane uses its authored unit normal: " + id)
		var ray := PhysicsRayQueryParameters3D.create(city.to_global(Vector3(p.x,p.z,-p.y)+Vector3(out.x,0,-out.y)*.1),city.to_global(Vector3(p.x,p.z,-p.y)-Vector3(out.x,0,-out.y)*.3),1,exclusions)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		var expected := city.to_global(Vector3(p.x,p.z,-p.y)-Vector3(out.x,0,-out.y)*float(window.get("pane_depth_m", float(window.recess_m)+.044)))
		var valid_pane := _pane_hit_matches(hit, expected, str(window.building), bodies)
		suite.check(valid_pane,"actual glazed pane is recessed behind masonry and sash: "+id)
		pane_checks += 1
		if valid_pane and not pane_controls and window.has("pane_depth_m"):
			var collider: CollisionObject3D = hit.collider
			var saved_layer := collider.collision_layer
			collider.collision_layer = 0
			var missing := world.get_world_3d().direct_space_state.intersect_ray(ray)
			suite.check(not _pane_hit_matches(missing, expected, str(window.building), bodies), "actual removed pane backing is rejected")
			collider.collision_layer = saved_layer
			var restored := world.get_world_3d().direct_space_state.intersect_ray(ray)
			suite.check(_pane_hit_matches(restored, expected, str(window.building), bodies), "restored actual pane backing is accepted")
			suite.check(not _pane_hit_matches(restored, expected + city.global_basis*Vector3(out.x,0,-out.y)*.01, str(window.building), bodies), "incorrect pane seating by 10mm is rejected")
			pane_controls = true
	suite.check(pane_checks==fixture.window_rows.size() and pane_controls, "every authored pane checked with actual missing-backing and wrong-depth controls")
	print("CITY PANE REVIEW: actual_panes=",pane_checks," controls=",pane_controls)
	suite.check(contacts>=1205 and sampled.size()>=80,"bearing and window probes cover the complete city roster")
	var ground: Node3D = world.adapter.root.get_node("Ground")
	var apron := ground.find_child("DistantApron", true, false) as Node3D
	var apron_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_ground_apron.json"))
	suite.check(apron != null and FileAccess.get_sha256("res://assets/props/city_ground_apron.glb") == apron_source.asset_sha256, "installed distant grade matches the native source")
	suite.check(FileAccess.get_sha256("res://assets/props/orison_ground.glb") == apron_source.retained_ground_sha256, "installed ground matches the source-fitted apron binding")
	var apron_samples := 0
	if apron != null:
		for row: Dictionary in apron_source.boxes:
			var samples: Array = row.exposed_samples
			suite.check(samples.size()==9,"nine exposed grade stations span the source strip: "+str(row.id))
			for sample: Array in samples:
				var local_point:=Vector3(sample[0],sample[1],sample[2])
				var p: Vector3 = world.adapter.root.to_global(local_point)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.03,p-Vector3.UP*.03,1,[world.player.get_rid()]))
				suite.check(not hit.is_empty() and apron.is_ancestor_of(hit.collider) and hit.position.distance_to(p)<.0001, "distant exposed ground has its actual fitted physical top: "+str(row.id))
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
	for identity: String in ["site_nbr_e","site_ne1","site_back_e","site_nw2"]:
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
	# The narrow end fronts the street; the long faces adjoin the other row
	# buildings. Review in the composed world, not just an isolated asset camera.
	var townhouse_bounds: Array=[]
	for building: Dictionary in fixture.buildings:
		if str(building.id)=="site_nw2":townhouse_bounds=building.main_rect
	suite.check(townhouse_bounds.size()==4,"one source townhouse reservation")
	if townhouse_bounds.size()==4:
		var center_x:=float(townhouse_bounds[0]+townhouse_bounds[2])*.5
		var front_z: float=-float(townhouse_bounds[1])
		var target:=city.to_global(Vector3(center_x,5.8,front_z))
		var visible:=false
		for offset_x: float in [0.,-.8,.8]:
			var eye:=city.to_global(Vector3(center_x+offset_x,1.6,front_z+13.))
			var inside:=city.to_global(Vector3(center_x,5.8,front_z-.4))
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,inside,1,[world.player.get_rid()]))
			if hit.is_empty() or not str(bodies.get(hit.collider.get_rid(),"")).begins_with("site_nw2__"):continue
			camera.global_position=eye;camera.look_at(target);visible=true
			await suite.get_tree().create_timer(.6).timeout
			await suite.shot("city_townhouse_street_front")
			await _review_inspection_camera(world,suite,camera.global_transform)
			break
		suite.check(visible,"townhouse street front is genuinely visible with real world blockers retained")
	# The owner opened exterior exploration. Review the actual former closure
	# instead of remounting retired stock just to satisfy its historical capture.
	suite.check(world.get_node_or_null("StreetBoundaries/RetainedStreetEnds") == null,"short street-end limits remain retired in the composed surface review")
	camera.global_position=Vector3(-16,1.41,3)
	camera.look_at(Vector3(-45,1.41,3))
	await suite.get_tree().create_timer(.6).timeout
	await suite.shot("city_open_west_frontage")
	await _review_apartment_batch(world,suite,camera,city,fixture,bodies)
	await preload("res://tests/v2_city_horizon_review.gd").new().run(world,suite,camera)
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
	# Posed construction reviews outside the current walkable street. They do
	# not expand the travel graph or qualify player access to the rail yard.
	for view: Array in [
		["river",Vector3(420,10,10),Vector3(380,-4,0)],
		["canal",Vector3(20,7,-310),Vector3(50,-6,-360)],
		["rail_cut",Vector3(-290,12,60),Vector3(-390,-3.5,0)],
	]:
		camera.global_position=root.to_global(view[1])
		camera.look_at(root.to_global(view[2]))
		await suite.get_tree().create_timer(.6).timeout
		await suite.shot("city_relief_"+str(view[0]))
	suite.check((root.global_basis*Vector3.RIGHT).dot(Vector3.LEFT)>.999 and (root.global_basis*Vector3.BACK).dot(Vector3.FORWARD)>.999,"relief west/north axes match actual installed sky compass")
	camera.global_position = root.to_global(Vector3(140,8,82))
	camera.look_at(root.to_global(Vector3(110,-.02,64)))
	await suite.get_tree().create_timer(.6).timeout
	await suite.shot("city_ground_seam")
	manager.set_process(was_processing)
	if is_instance_valid(prior):prior.make_current()
	camera.free()
	print("CITY ELEVATION REVIEW: parts=%d triangles=%d windows=%d bearing_samples=%d window_stations=%d" % [parts,triangles,int(fixture.windows),contacts,sampled.size()])


func _review_apartment_batch(world: Node,suite: Node,camera: Camera3D,city: Node3D,fixture: Dictionary,bodies: Dictionary) -> void:
	# Source-derived posed views of the actual composition, not new travel access.
	# Keep other buildings and foreground blockers authoritative in every ray.
	var fronts: Dictionary={"site_far_n":0,"site_far_ne":0,"site_far_se":3,
		"site_far_s":2,"site_far_sw":2,"site_far_w":1}
	var atmosphere: Node=world.get_node("WakingAtmosphere")
	var director_processing: bool=atmosphere.director.is_processing()
	var saved_force := OS.get_environment("DAYNIGHT_FORCE")
	var had_force := OS.has_environment("DAYNIGHT_FORCE")
	atmosphere.director.set_process(false)
	var saved_minute: float=world.campaign_clock.minute_of_day()
	var saved_campaign: String=JSON.stringify(RealityState.data.campaign_clock)
	var reviewed:=0
	for building: Dictionary in fixture.buildings:
		var identity:=str(building.id)
		if not fronts.has(identity):continue
		var side: int=fronts[identity]
		var normal: Vector3=[Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT][side]
		normal=city.global_basis*normal
		var bounds: Array=building.main_rect
		var center:=Vector3(float(bounds[0]+bounds[2])*.5,0,-float(bounds[1]+bounds[3])*.5)
		var choices: Array[Dictionary]=[]
		for window: Dictionary in fixture.window_rows:
			if str(window.building)==identity and int(window.side)==side and float(window.center[2])>=7.0 and float(window.center[2])<=12.0:
				choices.append(window)
		choices.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			var first:=Vector3(a.center[0],0,-a.center[1])
			var second:=Vector3(b.center[0],0,-b.center[1])
			return first.distance_squared_to(center)<second.distance_squared_to(center))
		var street_visible:=false
		var roof_target:=Vector3.ZERO
		for window: Dictionary in choices:
			var source: Array=window.center
			var target:=city.to_global(Vector3(source[0],source[2],-source[1]))
			for distance: float in [7.,5.,3.,1.5]:
				var eye:=target+normal*distance
				eye.y=city.global_position.y+1.6
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target-normal*.35,1,[world.player.get_rid()]))
				if hit.is_empty() or not str(bodies.get(hit.collider.get_rid(),"")).begins_with(identity+"__") or hit.position.distance_to(target)>.36:continue
				camera.global_position=eye;camera.look_at(target);street_visible=true;roof_target=target
				# Existing forced-lighting diagnostic bypasses calendar ephemeris.
				# A minute-only _apply otherwise retains the real nighttime sun.
				OS.set_environment("DAYNIGHT_FORCE","12:00")
				atmosphere.director._apply(720.)
				await suite.get_tree().create_timer(.6).timeout
				await suite.shot("city_batch_"+identity+"_street")
				break
			if street_visible:break
		suite.check(street_visible,"apartment street viewpoint retains actual first-hit visibility: "+identity)
		if not street_visible:continue
		var span:=maxf(float(bounds[2]-bounds[0]),float(bounds[3]-bounds[1]))
		var roof_visible:=false
		for factor: float in [.70,.45,.25]:
			var eye:=city.to_global(center)+normal*span*factor
			eye.y=city.global_position.y+float(building.roof_height)+11.
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,roof_target-normal*.35,1,[world.player.get_rid()]))
			if hit.is_empty() or not str(bodies.get(hit.collider.get_rid(),"")).begins_with(identity+"__"):continue
			camera.global_position=eye;camera.look_at(roof_target);roof_visible=true
			for phase: Array in [[720.,"day"],[1050.,"dusk"]]:
				# Presentation diagnostics use the installed director; no calendar
				# seek or NPC/publication/save mutation is asserted by a posed view.
				OS.set_environment("DAYNIGHT_FORCE","12:00" if float(phase[0])==720. else "17:30")
				atmosphere.director._apply(float(phase[0]))
				await suite.get_tree().create_timer(.6).timeout
				await suite.shot("city_batch_"+identity+"_roof_"+str(phase[1]))
			break
		suite.check(roof_visible,"apartment rooftop viewpoint retains composed-world blockers: "+identity)
		reviewed+=1
	if had_force:OS.set_environment("DAYNIGHT_FORCE",saved_force)
	else:OS.unset_environment("DAYNIGHT_FORCE")
	atmosphere.director._apply(saved_minute)
	atmosphere.director.set_process(director_processing)
	suite.check(reviewed==6,"all six individually authored apartment identities receive actual world views")
	suite.check(JSON.stringify(RealityState.data.campaign_clock)==saved_campaign,"posed city lighting never seeks the authoritative campaign calendar")


func _inspection_key(suite: Node,key: Key,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=key;event.physical_keycode=key;event.pressed=pressed
	Input.parse_input_event(event)
	await suite.get_tree().process_frame


func _inspection_tap(suite: Node,key: Key) -> void:
	await _inspection_key(suite,key,true)
	await _inspection_key(suite,key,false)


func _review_inspection_camera(world: OrisonV2RuntimeRoot,suite: Node,street_pose: Transform3D) -> void:
	var shots: ShotCapture=world.shots
	var player: PlayerController=world.player
	var previous:=world.get_viewport().get_camera_3d()
	var mode:=GameBoot.launch_mode
	var mouse:=Input.mouse_mode
	var pose:=player.global_transform
	var physics:=player.is_physics_processing()
	var processing:=player.is_processing()
	var protected:=player.protected_input_active()
	GameBoot.launch_mode=GameBoot.LaunchMode.DEBUG
	player.camera.make_current()
	player.call_locked=true
	await _inspection_tap(suite,KEY_F8)
	suite.check(not is_instance_valid(shots.inspection_camera) and player.protected_input_active(),"free camera refuses protected conversation input")
	player.call_locked=protected
	var text_owner:=Node.new();world.add_child(text_owner)
	var acquired:=player.acquire_text_input(text_owner)
	suite.check(acquired,"camera text-ownership control uses the real input owner")
	await _inspection_tap(suite,KEY_F8)
	suite.check(not is_instance_valid(shots.inspection_camera) and player.text_input_owner==text_owner,"free camera preserves typed input ownership")
	player.release_text_input(text_owner);text_owner.queue_free()
	await _inspection_tap(suite,KEY_F8)
	var camera:=shots.inspection_camera
	suite.check(is_instance_valid(camera),"actual F8 event activates the inspection camera")
	if is_instance_valid(camera):
		suite.check(player.text_input_owner==shots,"inspection owns the existing input lease while flying")
		suite.check(camera.is_current() and world.view_override==camera and world.passage_region.residency.observer==camera
				and world.mirror_renderer._main_camera==camera,"camera drives view, visual residency and mirror observer")
		suite.check(not player.is_processing() and not player.is_physics_processing(),"operator remains parked while the camera flies")
		camera.global_transform=street_pose
		var start:=camera.global_position
		await _inspection_key(suite,KEY_W,true)
		await suite.get_tree().create_timer(.12).timeout
		await _inspection_key(suite,KEY_W,false)
		suite.check(camera.global_position.distance_to(start)>.15 and player.global_transform.is_equal_approx(pose),"actual held movement flies the eye without moving the player")
		var residency: Node=world.passage_region.residency
		var camera_pose:=camera.global_transform
		player.global_position=residency.frame.to_global(residency._prefetch_box.get_center())
		camera.global_position=player.global_position+Vector3.UP*100.
		await suite.get_tree().physics_frame
		await suite.get_tree().physics_frame
		suite.check(residency._wanted,"flying away cannot retire geometry supporting the parked operator")
		player.global_transform=pose;camera.global_transform=camera_pose
		var before_look:=camera.global_basis
		var motion:=InputEventMouseMotion.new();motion.relative=Vector2(24,-12)
		motion.position=world.get_viewport().get_visible_rect().get_center()
		motion.global_position=motion.position
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await RenderingServer.frame_post_draw
		print("INSPECTION LOOK: before=",before_look," after=",camera.global_basis,
				" mouse=",Input.mouse_mode," processing_input=",shots.is_processing_input()," lease=",player.text_input_owner==shots)
		suite.check(not camera.global_basis.is_equal_approx(before_look),"actual mouse motion turns the inspection camera")
		var speed:=shots.inspection_speed
		var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
		Input.parse_input_event(wheel);await suite.get_tree().process_frame
		suite.check(is_equal_approx(shots.inspection_speed,speed*1.5),"wheel adjusts inspection travel speed")
		await _inspection_tap(suite,KEY_QUOTELEFT)
		start=camera.global_position
		await _inspection_key(suite,KEY_W,true)
		await suite.get_tree().create_timer(.08).timeout
		await _inspection_key(suite,KEY_W,false)
		suite.check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and camera.global_position.is_equal_approx(start),"released pointer stops camera movement")
		var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true
		Input.parse_input_event(click);await suite.get_tree().process_frame
		suite.check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"right click recaptures the inspection pointer")
		camera.global_transform=street_pose
		var captured: Array[String]=[]
		var on_capture:=func(stem: String,_aim: String):captured.append(stem)
		shots.captured.connect(on_capture)
		await _inspection_tap(suite,KEY_F)
		for frame in 20:
			if not captured.is_empty():break
			await suite.get_tree().process_frame
		shots.captured.disconnect(on_capture)
		suite.check(captured.size()==1 and FileAccess.file_exists(OS.get_environment("SHOT_DIR").path_join(captured[0]+".png")),"actual F event saves the inspection view with its stand")
		suite.get_tree().paused=true
		await _inspection_tap(suite,KEY_ESCAPE)
		suite.check(not is_instance_valid(shots.inspection_camera) and suite.get_tree().paused,"Escape restores control without resuming a paused world")
		suite.get_tree().paused=false
	suite.check(player.camera.is_current() and player.global_transform.is_equal_approx(pose)
			and player.is_processing()==processing and player.is_physics_processing()==physics,"leaving inspection restores the original player camera, pose and processing")
	suite.check(world.view_override==null and world.passage_region.residency.observer==null
			and world.mirror_renderer._main_camera==player.camera,"inspection presentation owners are restored")
	suite.check(player.text_input_owner==null and player.protected_input_active()==protected,"inspection releases only its own input lease")
	await _inspection_tap(suite,KEY_F8)
	suite.check(is_instance_valid(shots.inspection_camera),"inspection can be resumed after returning control")
	player.call_locked=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await suite.get_tree().process_frame
	await suite.get_tree().process_frame
	suite.check(not is_instance_valid(shots.inspection_camera) and player.protected_input_active()
			and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"incoming protected conversation ends flight without stealing its pointer")
	player.call_locked=protected
	GameBoot.launch_mode=mode;Input.mouse_mode=mouse
	if is_instance_valid(previous):previous.make_current()

static func _pane_hit_matches(hit: Dictionary, expected: Vector3, building: String, bodies: Dictionary) -> bool:
	if hit.is_empty(): return false
	var identity := str(bodies.get(hit.collider.get_rid(), ""))
	return identity.begins_with(building+"__") and identity.ends_with("__mirror_aged") and hit.position.distance_to(expected)<.0001
