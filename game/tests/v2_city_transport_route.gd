extends "res://tests/v2_city_west_frontage.gd"
## Continuous installed street-to-station access with the actual five-foot body.
## The retained crossing/frontage/door programme runs first in the same world.
var programme_before: Dictionary = {}
var _exploration_samples: Array = []
var _collect_exploration := false
var _previous_exploration_usec := 0
var _route_scope := "full"
# Independent expected AU soil datums, in the registered building frame.
# These are route assertions, not a runtime terrain/movement authority.
const WESTERN_SOIL_PROFILE := [[20.3,-.02],[24.3,-.03],[28.3,-.06],[32.3,-.11],[92.,-1.0055],[140.,-1.7255],[290.,-3.9755],[330.,-4.2],[365.,-4.6],[390.,-4.8],[395.,-8.],[500.,-8.]]

func _ready() -> void:
	_route_scope=OS.get_environment("ORISON_CITY_ROUTE_SCOPE")
	if _route_scope.is_empty():_route_scope="full"
	if _route_scope not in ["full","northwest","opposing","hampton","gaslamps"]:
		push_error("Unknown ORISON_CITY_ROUTE_SCOPE: "+_route_scope)
		get_tree().quit(64)
		return
	super._ready()
	route_label = "V2 CITY NORTHWEST" if _route_scope=="northwest" else "V2 CITY EXTERIOR"
	if _route_scope=="opposing":route_label="V2 CITY OPPOSING"
	if _route_scope=="hampton":route_label="V2 CITY HAMPTON FOOTWAY"
	if _route_scope=="gaslamps":
		route_label="V2 CITY NIGHT GASLAMPS"
		OS.set_environment("DAYNIGHT_FORCE","21:00")

func _process(_delta: float) -> void:
	if not _collect_exploration: return
	var now := Time.get_ticks_usec()
	if _previous_exploration_usec > 0:
		var viewport := get_viewport().get_viewport_rid()
		_exploration_samples.append([(now-_previous_exploration_usec)/1000.,RenderingServer.viewport_get_measured_render_time_cpu(viewport),RenderingServer.viewport_get_measured_render_time_gpu(viewport),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	_previous_exploration_usec = now

func _programme_sources() -> Dictionary:
	var result: Dictionary = {}
	for path: String in ["res://tests/fixtures/orison_city_elevations.json","res://tests/orison_v2_domestic_native_test.gd","res://tests/orison_v2_roof_bulkhead_caps_test.gd","res://tests/orison_v2_surface_inventory.gd"]:
		result[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	var elevation_fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_elevations.json"))
	for relative: String in elevation_fixture.source_bindings:
		if not relative.begins_with("game/") or not relative.ends_with(".png"):continue
		var path: String="res://"+relative.trim_prefix("game/")
		result[path]=FileAccess.get_sha256(path)
		if FileAccess.file_exists(path+".import"):result[path+".import"]=FileAccess.get_file_as_string(path+".import").replace("\r\n","\n").sha256_text()
	for path: String in ["res://assets/props/city_elevations_lod1.glb","res://assets/props/city_elevations_lod1.glb.import","res://tests/fixtures/orison_city_elevations_lod1.json"]:
		result[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text() if path.get_extension() in ["json","import"] else FileAccess.get_sha256(path)
	for path: String in ["res://tests/v2_city_transport_route.gd", "res://tests/v2_city_west_frontage.gd", "res://tests/orison_v2_street_crossing_test.gd", "res://tests/orison_v2_vertical_route_test.gd", "res://tests/orison_v2_first_slice_contract_test.gd", "res://tests/fixtures/orison_city_transport.json", "res://assets/props/city_transport.glb", "res://assets/props/city_transport_lod1.glb", "res://assets/props/orison_ground.glb", "res://assets/props/city_foundations.glb", "res://assets/props/city_elevations.glb"]:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text() if path.get_extension() in ["gd", "json"] else FileAccess.get_sha256(path)
	for path: String in ["res://assets/props/construction_shed.glb","res://assets/props/city_ground_apron.glb","res://assets/props/city_horizon_near.glb","res://assets/props/city_horizon_far.glb"]:
		result[path] = FileAccess.get_sha256(path)
	for path: String in ["res://assets/props/city_streets.glb","res://assets/props/city_streets_lod1.glb","res://tests/fixtures/orison_city_streets.json"]:
		result[path] = FileAccess.get_sha256(path)
	return result

func _run() -> void:
	if _route_scope=="gaslamps":
		await _run_gaslamps()
		return
	if _route_scope=="hampton":
		await _run_hampton()
		return
	if _route_scope=="opposing":
		await _run_opposing()
		return
	if _route_scope=="northwest":
		await _run_northwest()
		return
	programme_before = _programme_sources()
	city_observations["programme_sources"] = programme_before
	city_observations["route_scope"]="full"
	await super._run()

func _run_gaslamps() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"night street evidence directory exists")
	if not failures.is_empty():get_tree().quit(1);return
	source_before=_digest();programme_before=_programme_sources()
	city_observations["programme_sources"]=programme_before
	city_observations["route_scope"]="gaslamps"
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);CampaignClock.new().configure_date(1928,11,10,1260)
	var started:=Time.get_ticks_usec()
	world=Runtime.instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"production city starts for short nighttime frontage/crossing")
	if not world.startup_failed and world.player!=null:
		player=world.player;player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		city_observations["startup_ms"]=(Time.get_ticks_usec()-started)/1000.
		var data:=preload("res://scripts/building/orison_v2_street_lamps.gd").load_table()
		var street: Node3D=world.exterior_cell.instance_node(str(data.street_instance))
		var lamps:=street.get_node("StreetLamps") as Node3D
		var clock:=lamps.get_node("LampClock")
		check(clock.lights.size()==4 and is_equal_approx(float(clock.lit),1.),"all four original lamp pools use actual production night clock")
		var collisions: Array=[]
		for record: Dictionary in data.lamps:
			var post:=lamps.get_node(str(record.id)) as MeshInstance3D
			var at: Array=record.at
			var center:=Vector3(at[0],at[1]+.8,at[2])
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(street.to_global(center+Vector3(.5,0,0)),street.to_global(center-Vector3(.5,0,0)),1,[player.get_rid()]))
			var actual: bool=not hit.is_empty() and hit.collider==post.get_node("Collision")
			if actual:actual=absf(street.to_local(hit.position).x-center.x-.22)<.0001
			check(actual,"unfiltered actual retained post cylinder contact "+str(record.id))
			collisions.append({"lamp":record.id,"hit":str(hit),"radius_m":.22})
		city_observations["actual_post_collision_rays"]=collisions
		var recoveries_before: int=int(world.safety_net.recoveries)
		# B2G converts this independent street-local XY fixture once. Every
		# following leg uses the original production controller and tolerances.
		if await _opposing_start(street,Vector3(-14,-3,0),"retained_orison_sidewalk"):
			var points: Array[Vector3]=[Vector3(-8,0,3),Vector3(12,0,3),Vector3(14,0,3),Vector3(14,0,4.2),Vector3(14,-.1,8),Vector3(14,-.1,13.6),Vector3(14,0,15),Vector3(14,0,18.2)]
			for index in points.size():
				RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
				_previous_exploration_usec=0;_collect_exploration=true
				var reached:=await _walk(world.adapter.root.to_local(street.to_global(points[index])))
				_collect_exploration=false
				RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
				if not reached:break
				if index in [0,1,6,7]:
					var view: Dictionary={0:{"id":"night_west_post","target":Vector3(-9.6,3.86,4.815)},1:{"id":"night_orison_post","target":Vector3(8.1,3.86,4.815)},6:{"id":"night_crossing_signal","target":Vector3(13.3,2.4,3.975)},7:{"id":"night_arcade_post","target":Vector3(-4.2,3.86,13.98)}}[index]
					player.face_world_point(street.to_global(view.target))
					for frame in 6:await RenderingServer.frame_post_draw
					check(get_viewport().get_texture().get_image().save_png(directory.path_join(str(view.id)+".png"))==OK,"actual standing night street capture "+str(view.id))
		check(trace.size()==8,"eight continuous normal-controller legs past Orison lamps and across retained road to arcade")
		check(world.safety_net.recoveries==recoveries_before,"night frontage/crossing uses no safety-net rescue")
		check(not player.noclip and not player.crouched and is_equal_approx(player.STANDING_HEIGHT,1.524),"night frontage uses original standing body")
		city_observations["walking_timing"]={"columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","engine_draws","engine_primitives"],"samples":_exploration_samples,"scope":"Eight walking legs only; nearby fixture,startup,settles and capture writes excluded. No matched old-lamp/world speedup claim."}
	Input.action_release("move_forward");world.shutdown_for_tests();world.free()
	await get_tree().physics_frame
	var source_after:=_digest()
	check(not source_after.is_empty() and source_before==source_after and programme_before==_programme_sources(),"night route production/test sources remain frozen")
	var passed:=failures.is_empty()
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"One explicit nearby actual-floor fixture,then eight normal-controller sidewalk/retained-road crossing legs. Unfiltered four original cylinder contacts,night lamp gating and four standing street views. No close arcade-lamp access,door/shop operations,save,clock progression,whole-city or artistic acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
		"source":{"test_path":"game/tests/v2_city_transport_route.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":source_after},
		"contracts":{"production_composition":{"executed":true,"passed":passed},"night_frontage_crossing":{"executed":not trace.is_empty(),"passed":passed and trace.size()==8,"waypoints":trace.size()},"actual_lamp_collisions":{"executed":city_observations.has("actual_post_collision_rays"),"passed":passed},"world_root_retirement":{"executed":true,"passed":not is_instance_valid(world)}},
		"checks":city_checks,"failures":failures,"trace":trace,"observations":city_observations}
	FileAccess.open(directory.path_join("gaslamp_street_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t")+"\n")
	print("%s: %d checks; %d waypoints; %d failures"%[route_label,city_checks,trace.size(),failures.size()])
	get_tree().quit(0 if passed else 1)

func _run_hampton() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"footway evidence directory exists before startup/captures")
	if not failures.is_empty():get_tree().quit(1);return
	source_before=_digest();programme_before=_programme_sources()
	city_observations["programme_sources"]=programme_before
	city_observations["route_scope"]="hampton"
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);CampaignClock.new().configure_date(1928,11,10,720)
	var started:=Time.get_ticks_usec()
	world=Runtime.instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"production composition starts for connected Hampton public footway")
	if not world.startup_failed and world.player!=null:
		player=world.player;player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var city:=world.get_node("CityShells") as Node3D
		city_observations["startup_ms"]=(Time.get_ticks_usec()-started)/1000.
		city_observations["render_settings"]={"resolution":str(get_viewport().get_visible_rect().size),"msaa":get_viewport().msaa_3d,"taa":get_viewport().use_taa,"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"mesh_lod_threshold":get_viewport().mesh_lod_threshold}
		_check_frontage_surfaces(city,["Street_Hampton_-5_L0","Street_Hampton_-6_L0"],3,"hampton_public_surfaces",true)
		var recoveries_before: int=int(world.safety_net.recoveries)
		if await _opposing_start(city,Vector3(-75.4,20.2,0),"retained_western_sidewalk"):
			var points: Array[Vector3]=[Vector3(-75.4,25.2,-.7365),Vector3(-75.4,26.6,-.7365),Vector3(-93.7,26.6,-1.011),Vector3(-80,26.6,-.8055),Vector3(-80,29.5,0),Vector3(-80,26.6,-.8055),Vector3(-65,26.6,-.5805),Vector3(-75.4,26.6,-.7365),Vector3(-75.4,20.2,-.7365)]
			for index in points.size():
				if not await _city_walk(points[index],true):break
				if index==1:await _station_view("hampton_connected_walk",Vector3(-84,27,1.2))
				if index==4:
					check(absf(city.to_local(player.global_position).y)<.025 and player.is_on_floor(),"normal controller reaches actual level landing,not merely the penultimate tread")
					await _station_view("hampton_stoop_landing",Vector3(-80,30.7,1.6))
				if index==6:await _station_view("hampton_frontage_walk",Vector3(-84,27,.7))
		check(trace.size()==9,"nine continuous normal-controller legs join retained sidewalk,whole frontage and stair ascent/descent")
		check(world.safety_net.recoveries==recoveries_before,"public footway has no safety-net rescue")
		check(not player.noclip and not player.crouched and is_equal_approx(player.STANDING_HEIGHT,1.524),"public footway retains the five-foot standing production body")
		city_observations["walking_timing"]={"columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","engine_draws","engine_primitives"],"samples":_exploration_samples,"scope":"Nine actual walking legs only; initial explicit nearby placement,settles and PNG writes excluded. No matched speedup or whole-city performance claim."}
	Input.action_release("move_forward");world.shutdown_for_tests();world.free()
	await get_tree().physics_frame
	var source_after:=_digest()
	check(not source_after.is_empty() and source_before==source_after and programme_before==_programme_sources(),"public footway production/test/asset sources remain frozen")
	var passed:=failures.is_empty()
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"One explicit nearby retained-sidewalk start followed by nine continuous normal-controller legs through new public paving and level-tread stoop. Actual three new loaded finish partitions inspected. No scenic door operation,new interior,entrance/station/distant/radius/save/full-city/artistic acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
		"source":{"test_path":"game/tests/v2_city_transport_route.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":source_after},
		"contracts":{"production_composition":{"executed":true,"passed":passed},"hampton_connected_walk":{"executed":not trace.is_empty(),"passed":passed and trace.size()==9,"waypoints":trace.size()},"hampton_loaded_surfaces":{"executed":city_observations.has("hampton_public_surfaces"),"passed":passed},"world_root_retirement":{"executed":true,"passed":not is_instance_valid(world)}},
		"checks":city_checks,"failures":failures,"trace":trace,"observations":city_observations}
	FileAccess.open(directory.path_join("hampton_footway_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t")+"\n")
	print("%s: %d checks; %d waypoints; %d failures"%[route_label,city_checks,trace.size(),failures.size()])
	get_tree().quit(0 if passed else 1)

func _opposing_start(city: Node3D,source: Vector3,identity: String) -> bool:
	# Independent local fixture, never a player spawn or a travel shortcut in game.
	var nominal:=city.to_global(GameBoot.b2g([source.x,source.y,0.]))
	var excluded: Array[RID]=[]
	excluded.append(player.get_rid())
	var hit:=city.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(nominal+Vector3.UP*3.,nominal-Vector3.UP*20.,1,excluded))
	var floor_valid: bool=not hit.is_empty() and hit.collider is StaticBody3D and hit.normal.dot(Vector3.UP)>.98 and hit.position.y-nominal.y>=-1.5 and hit.position.y-nominal.y<=.5
	check(floor_valid,"nearby start has actual unfiltered static public floor: "+identity)
	if not floor_valid:return false
	player.global_position=hit.position+Vector3.UP*.03
	player.velocity=Vector3.ZERO
	var samples: Array=[]
	var previous:=Time.get_ticks_usec()
	for frame in 12:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		samples.append((now-previous)/1000.);previous=now
	check(player.is_on_floor() and not player.noclip,"local start settles on actual floor with the production body: "+identity)
	var starts: Array=city_observations.get("local_start_fixtures",[])
	starts.append({"building":identity,"source_xy":[source.x,source.y],"floor_world":str(hit.position),"floor_height_delta":hit.position.y-nominal.y,"floor_owner":str(hit.collider.get_path()),"settle_wall_ms":samples,"scope":"Independent explicit test-only placement; subsequent legs use normal controller input. No continuous access between fixture starts."})
	city_observations["local_start_fixtures"]=starts
	return player.is_on_floor() and not player.noclip

func _run_opposing() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"opposing evidence directory exists before startup/captures")
	if not failures.is_empty():get_tree().quit(1);return
	source_before=_digest();programme_before=_programme_sources()
	city_observations["programme_sources"]=programme_before
	city_observations["route_scope"]="opposing"
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928,11,10,720)
	var started:=Time.get_ticks_usec()
	world=Runtime.instantiate();add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"production composition starts for three selected fronts")
	if not world.startup_failed and world.player!=null:
		player=world.player
		player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var city:=world.get_node("CityShells") as Node3D
		city_observations["startup_ms"]=(Time.get_ticks_usec()-started)/1000.
		city_observations["render_settings"]={"resolution":str(get_viewport().get_visible_rect().size),"msaa":get_viewport().msaa_3d,"taa":get_viewport().use_taa,"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"mesh_lod_threshold":get_viewport().mesh_lod_threshold}
		_check_frontage_surfaces(city,["site_se3","site_sw3","site_far_nw"],32,"opposing_surfaces")
		var recoveries_before: int=int(world.safety_net.recoveries)
		var programmes: Array=[
			{"id":"site_sw3","start":Vector3(-56.8,-26.5,0),"points":[Vector3(-47.8,-26.5,0),Vector3(-55,-26.5,0),Vector3(-55,-13,0),Vector3(-55,-26.5,0)],"target":Vector3(-52.3,-28.32,1.6)},
			{"id":"site_se3","start":Vector3(46,-26.5,0),"points":[Vector3(51.55,-26.5,0),Vector3(57,-26.5,0),Vector3(51.55,-26.5,0),Vector3(46,-26.5,0)],"target":Vector3(51.55,-28.32,1.6)},
			{"id":"site_far_nw","start":Vector3(-92,27,0),"points":[Vector3(-88,27,0),Vector3(-80,27,0),Vector3(-72,27,0),Vector3(-92,27,0)],"target":Vector3(-80,30,8)}]
		var completed:=0
		for programme: Dictionary in programmes:
			if not failures.is_empty():break
			if not await _opposing_start(city,programme.start,str(programme.id)):break
			var first:=trace.size()
			for point: Vector3 in programme.points:
				if not await _city_walk(point):break
				if str(programme.id)=="site_sw3" and point.y==-13.:await _station_view("firehouse_from_opposite_walk",Vector3(-52.3,-28.32,8))
			if not failures.is_empty():break
			check(trace.size()-first==4,"four actual controller legs execute for "+str(programme.id))
			await _station_view(str(programme.id)+"_standing_frontage",programme.target)
			completed+=1
		check(completed==3 and trace.size()==12,"all three independent local programmes and twelve actual controller legs execute")
		check(world.safety_net.recoveries==recoveries_before,"selected fronts have no safety-net rescue")
		check(not player.noclip and not player.crouched and is_equal_approx(player.STANDING_HEIGHT,1.524),"selected fronts retain the five-foot standing production body")
		city_observations["walking_timing"]={"columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","engine_draws","engine_primitives"],"samples":_exploration_samples,"scope":"Only actual selected controller walking; independent placements,settles and PNG captures excluded. No matched before/after speedup or full-city performance claim."}
	Input.action_release("move_forward")
	world.shutdown_for_tests();world.free()
	await get_tree().physics_frame
	var source_after:=_digest()
	check(not source_after.is_empty() and source_before==source_after and programme_before==_programme_sources(),"selected production/test/asset sources remain frozen")
	var passed:=failures.is_empty()
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Three independent floor-validated nearby starts,twelve actual production-controller legs and changed32-body-part surfaces. Includes retained x=-55 crossing roundtrip. No continuous access between starts,entrance/station/distant/radius/save/full-city/artistic acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
		"source":{"test_path":"game/tests/v2_city_transport_route.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":source_after},
		"contracts":{"production_composition":{"executed":true,"passed":passed},"opposing_local_walks":{"executed":not trace.is_empty(),"passed":passed and trace.size()==12,"waypoints":trace.size()},"opposing_loaded_surfaces":{"executed":city_observations.has("opposing_surfaces"),"passed":passed},"world_root_retirement":{"executed":true,"passed":not is_instance_valid(world)}},
		"checks":city_checks,"failures":failures,"trace":trace,"observations":city_observations}
	FileAccess.open(directory.path_join("opposing_frontage_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t")+"\n")
	print("%s: %d checks; %d waypoints; %d failures"%[route_label,city_checks,trace.size(),failures.size()])
	get_tree().quit(0 if passed else 1)

func _run_northwest() -> void:
	# Explicit nearby start fixture for changed-frontage iteration. The default
	# full integration route retains its entrance/station/distant walking legs.
	var directory:=OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"focused evidence directory exists before startup/captures")
	if not failures.is_empty():
		get_tree().quit(1)
		return
	source_before=_digest()
	programme_before=_programme_sources()
	city_observations["programme_sources"]=programme_before
	city_observations["route_scope"]="northwest"
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928,11,10,720)
	var started:=Time.get_ticks_usec()
	world=Runtime.instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"production composition starts for focused frontage route")
	if not world.startup_failed and world.player!=null:
		player=world.player
		var city:=world.get_node("CityShells") as Node3D
		var height:=preload("res://scripts/building/orison_v2_city_streets.gd").surface_height(-55.)
		var fixture:=city.to_global(GameBoot.b2g([-55.,-13.,height]))
		player.global_position=fixture+Vector3.UP*.03
		player.velocity=Vector3.ZERO
		player.camera.make_current()
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var settle: Array=[]
		var previous:=Time.get_ticks_usec()
		for frame in 12:
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			settle.append((now-previous)/1000.);previous=now
		city_observations["start_fixture"]={"source":[-55.,-13.,height],"world":str(fixture),"scope":"One explicit nearby test-only start placement. Every subsequent leg uses production controller input; no continuous entrance/station/distant-route claim."}
		city_observations["startup"]={"composition_and_fixture_settle_ms":(Time.get_ticks_usec()-started)/1000.,"settle_wall_ms":settle,"settle_frames":12}
		city_observations["render_settings"]={"resolution":str(get_viewport().get_visible_rect().size),"msaa":get_viewport().msaa_3d,"taa":get_viewport().use_taa,"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"mesh_lod_threshold":get_viewport().mesh_lod_threshold}
		check(player.is_on_floor() and not player.noclip,"focused fixture settles onto actual public floor")
		_check_northwest_surfaces(city)
		var recoveries_before:=world.safety_net.recoveries
		if failures.is_empty():await _northwest_frontages()
		if failures.is_empty():
			for point: Vector3 in [Vector3(-55,-26.5,0),Vector3(-40,-26.5,0),Vector3(-55,-26.5,0),Vector3(-55,-13,0)]:
				if not await _city_walk(point):break
				if point.x==-40.:await _station_view("northwest_row_from_south_walk",Vector3(-42,-6.2,8))
		check(trace.size()==10,"focused frontage and opposite-walk round trip executes all ten waypoints")
		check(world.safety_net.recoveries==recoveries_before,"focused route has no safety-net travel rescue")
		check(not player.noclip and not player.crouched and is_equal_approx(player.STANDING_HEIGHT,1.524),"focused route retains actual standing production body")
		city_observations["northwest_timing"]={"columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","engine_draws","engine_primitives"],"samples":_exploration_samples,"scope":"Only actual focused controller walking; captures excluded. Live traffic/residents and driver caches uncontrolled. No matched before/after or full-city performance claim."}
	Input.action_release("move_forward")
	world.shutdown_for_tests()
	world.free()
	await get_tree().physics_frame
	var source_after:=_digest()
	check(not source_after.is_empty() and source_before==source_after and programme_before==_programme_sources(),"focused runtime and test/asset sources remain frozen")
	check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"focused route has explicit writable evidence directory")
	if not directory.is_empty():
		var passed:=failures.is_empty()
		var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
			"scope":"Focused production-controller northwest frontage and opposite-sidewalk round trip from an explicit nearby start fixture. No entrance, station, distant street, radius-wall, save, full-city or artistic acceptance.",
			"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
			"source":{"test_path":"game/tests/v2_city_transport_route.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":source_after},
			"contracts":{"production_composition":{"executed":true,"passed":passed},"northwest_frontage_round_trip":{"executed":not trace.is_empty(),"passed":passed and trace.size()==10,"waypoints":trace.size()},"northwest_loaded_surfaces":{"executed":city_observations.has("northwest_surfaces"),"passed":passed},"world_root_retirement":{"executed":true,"passed":not is_instance_valid(world)}},
			"checks":city_checks,"failures":failures,"trace":trace,"observations":city_observations}
		FileAccess.open(directory.path_join("northwest_frontage_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t")+"\n")
	print("%s: %d checks; %d waypoints; %d failures"%[route_label,city_checks,trace.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_northwest_surfaces(city: Node3D) -> void:
	_check_frontage_surfaces(city,["site_nw1","site_nw3","site_nw4"],39,"northwest_surfaces")

func _check_frontage_surfaces(city: Node3D,identities: Array,expected_count: int,observation_key: String,streets: bool=false) -> void:
	var metrics:=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	var inventory:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var parts: Array[String]=[]
	var expected_names: Array[String]=[]
	var authored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/exterior/city_streets.json" if streets else "res://tests/fixtures/orison_city_elevations_lod1.json"))
	if streets:
		for part: String in authored.parts:
			if part.split("__")[0] in identities:expected_names.append(part)
	else:
		for part: Dictionary in authored.parts:
			if str(part.name).split("__")[0] in identities:expected_names.append(str(part.name))
	for draw: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
		if not draw.get_meta("v2_city_streets" if streets else "v2_city_body_lod",false) or str(draw.name).split("__")[0] not in identities:continue
		parts.append(str(draw.name))
		metrics._check_cap_mapping(draw.mesh,true)
		var key: String=str(draw.name).split("__")[-1]
		if streets:
			for finish: Dictionary in authored.finishes:
				if str(finish.alias)==key:key=str(finish.catalog_key);break
		var actual: Material=draw.get_active_material(0)
		check(MatLib.SETS.has(key) and actual!=null,"new frontage has its registered physical finish: "+str(draw.name))
		if actual==null:continue
		# Reuse the existing inventory readers without its whole-world run.
		# Inspect the actual loaded shader/owner finish, not a backing stock.
		var row: Dictionary=inventory._material(actual)
		var primary: Array[String]=[]
		if actual is StandardMaterial3D:
			check(not row.triplanar and row.filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC],"new frontage samples authored charts with mip-capable filtering: "+str(draw.name))
			primary.assign(["albedo_texture","roughness_texture","normal_texture"])
		elif actual is ShaderMaterial:
			check(row.get("uv_mode",-1)==0 and row.get("has_normal_tex",false) and row.get("has_rough_tex",false),"actual frontage shader samples physical UV and custom PBR maps: "+str(draw.name))
			primary.assign(["albedo_tex","rough_tex","normal_tex"])
		else:check(false,"unhandled actual frontage material: "+str(draw.name))
		for name: String in primary:check(row.maps.has(name),"new frontage retains custom primary map: "+name)
		for name: String in row.maps:
			var texture: Dictionary=inventory.texture_rows[row.maps[name]]
			check(texture.mips and int(texture.mip_levels)>0,"new frontage actually loads map mip chains: "+str(row.maps[name]))
			if actual is ShaderMaterial:check(bool(row.mip_filters.get(name,false)),"actual frontage shader sampler has mip-capable filtering: "+name)
	parts.sort();expected_names.sort()
	check(parts==expected_names and parts.size()==expected_count and metrics.failures.is_empty(),"exact nonempty selected body roster retains physical UVs/normals/tangents")
	metrics.free()
	city_observations[observation_key]={"parts":parts,"textures":inventory.texture_rows,"scope":"Explicit selected complete-body parts in the production composition, including appended replacement vertices. Actual owner-finish shaders are inspected. No renewal of unchanged interior/fire/whole-world surfaces."}
	inventory.free()

func _evidence_scope() -> String:
	return "Production controller through open frontage, retained crossing/door hands, native scaffold, both station levels/islands, both new street junctions/sidewalks and a wider street tour. Separate explicit airborne controller fixtures test the450m temporary radius and restored negative control; they are not continuous walking routes. No train service, sleep/bed event, save reconstruction, whole city or artistic acceptance."

func _evidence_file() -> String:
	return "city_exterior_contract.json"

func _city_walk(point: Vector3,literal_height: bool=false) -> bool:
	var city := world.get_node("CityShells") as Node3D
	if is_zero_approx(point.z) and not literal_height:
		point.z = preload("res://scripts/building/orison_v2_city_streets.gd").surface_height(point.x)
	print("CITY STATION WALK: source target ",point)
	var focused: bool=_route_scope in ["northwest","opposing","hampton"]
	if focused:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
		_previous_exploration_usec=0
		_collect_exploration=true
	var reached := await _walk(world.adapter.root.to_local(city.to_global(GameBoot.b2g([point.x, point.y, point.z]))))
	if focused:
		_collect_exploration=false
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
	print("CITY STATION WALK: reached=",reached," actual world=",player.global_position)
	return reached

func _station_view(label: String, target: Vector3) -> void:
	var city := world.get_node("CityShells") as Node3D
	player.face_world_point(city.to_global(GameBoot.b2g([target.x,target.y,target.z])))
	await get_tree().create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty() and get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png")) == OK, "actual standing station capture: " + label)

func _stairs(route: Dictionary, up: bool) -> bool:
	var from: Array = route.from_m
	var to: Array = route.to_m
	var lane := lane_from_route(route)
	var x := float(from[0])
	var y := float(from[1])
	var low := float(from[2])
	var high := float(to[2])
	var count := roundi((high - low) / (2. * float(route.riser_m)))
	var run := count * float(route.tread_m)
	# Land well inside each real landing before reversing direction. The run
	# itself is traversed under continuous controller input, never by teleport.
	var points: Array[Vector3] = [Vector3(x-.5,y,low), Vector3(x+run+.65,y,(low+high)/2.), Vector3(x+run+.65,y+lane,(low+high)/2.), Vector3(x-.5,y+lane,high)]
	if not up: points.reverse()
	for point: Vector3 in points:
		if not await _city_walk(point): return false
	return true

func _route() -> void:
	await super._route()
	if not failures.is_empty(): return
	# This is a third use of the live leaf, whose closer may leave it partly
	# open. Approach the actual hinge-side contact before grabbing again.
	for point: Vector3 in [Vector3(1.925,0,-6.5),Vector3(0,0,-7.65),Vector3(0,0,-10.2),Vector3(0,0,-10.8)]:
		if not await _walk(point): return
	if not await _open_front_entrance(): return
	if not await _walk(Vector3(0,0,-12.2)): return
	# Exercise the newly constructed block before the longer retained station
	# and distant tours, so a new street obstruction fails without spending
	# those unchanged route legs first.
	await _street_block_tour()
	if not failures.is_empty(): return
	# Walk through the actual reopened scaffold, including the former closure.
	for point: Vector3 in [Vector3(0,0,3),Vector3(14,0,3),Vector3(19.5,0,3),Vector3(24,0,3),Vector3(24,0,-4),Vector3(30,0,-4),Vector3(30,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	await _station_view("plaza_approach",Vector3(65,-10,8))
	for point: Vector3 in [Vector3(40,-12.8,0),Vector3(40,8,0),Vector3(31,8,0),Vector3(31.5,4.2,0)]:
		if not await _city_walk(point): return
	await _station_view("public_entry",Vector3(38,5,4))
	var station := world.get_node("CityShells/EasternPlazaStation") as Node3D
	var checked_materials: Dictionary = {}
	for draw: MeshInstance3D in station.find_children("*","MeshInstance3D",true,false):
		var material := draw.material_override as StandardMaterial3D
		check(material != null and not material.uv1_triplanar, "composed station keeps authored maps: " + str(draw.name))
		if material != null and not checked_materials.has(material.get_instance_id()):
			checked_materials[material.get_instance_id()] = true
			for texture: Texture2D in [material.albedo_texture,material.roughness_texture,material.normal_texture]:
				check(texture != null and texture.get_image().has_mipmaps(), "composed station PBR mip chain")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_city_transport.json"))
	var routes: Dictionary = {}
	for row: Dictionary in fixture.stair_routes: routes[str(row.id)] = row
	check(routes.size() == 5, "one public entry and four platform stair connections")
	if not await _stairs(routes.PublicEntry, true): return
	var before := trace.size()
	for island in 2:
		var lower: Dictionary = routes["PlatformStair_0_"+str(island)]
		var upper: Dictionary = routes["PlatformStair_1_"+str(island)]
		var base: Array = lower.from_m
		for point: Vector3 in [Vector3(30.8,5.75,6.2),Vector3(30.8,float(base[1]),6.2)]:
			if not await _city_walk(point): return
		if not await _stairs(lower, true): return
		await _station_view("lower_platform_"+str(island),Vector3(86,float(lower.to_m[1]),float(lower.to_m[2])+1))
		var upper_base: Array = upper.from_m
		var bypass := float(base[1]) - 1.8
		var lower_top := float(lower.to_m[2])
		var upper_top := float(upper.to_m[2])
		for point: Vector3 in [Vector3(31.5,bypass,lower_top),Vector3(50,bypass,lower_top),Vector3(61.5,bypass,lower_top),Vector3(61.5,float(upper_base[1]),lower_top)]:
			if not await _city_walk(point): return
		if not await _stairs(upper, true): return
		await _station_view("upper_platform_"+str(island),Vector3(90,float(upper.to_m[1]),float(upper.to_m[2])+1))
		var end: Array = upper.to_m
		if not await _city_walk(Vector3(55,float(end[1]),upper_top)): return
		if not await _stairs(upper, false): return
		for point: Vector3 in [Vector3(61.5,bypass,lower_top),Vector3(50,bypass,lower_top),Vector3(31.5,bypass,lower_top),Vector3(31.5,float(base[1])+lane_from_route(lower),lower_top)]:
			if not await _city_walk(point): return
		if not await _stairs(lower, false): return
	if not await _city_walk(Vector3(30.8,5.75,6.2)): return
	if not await _stairs(routes.PublicEntry, false): return
	for point: Vector3 in [Vector3(31,8,0),Vector3(40,8,0),Vector3(40,-12.8,0)]:
		if not await _city_walk(point): return
	for point: Vector3 in [Vector3(30,0,3),Vector3(24,0,3),Vector3(19.5,0,3),Vector3(14,0,3),Vector3(0,0,3)]:
		if not await _walk(world.adapter.root.to_local(point)): return
	city_observations["station_route"] = {"completed":true,"platform_connections":4,"waypoints":trace.size()-before}
	await _wide_street_tour()
	if not failures.is_empty(): return
	await _radius_controller_fixtures()
	check(not player.noclip and not player.crouched and is_equal_approx(player.STANDING_HEIGHT,1.524), "actual standing production body remained active")
	check(programme_before == _programme_sources(), "executed route sources and physical station/ground bodies remain frozen")

func lane_from_route(route: Dictionary) -> float:
	return float(route.to_m[1]) - float(route.from_m[1])

func _street_block_tour() -> void:
	var start := trace.size()
	var recoveries_before := world.safety_net.recoveries
	var fronts_reviewed:=false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for point: Vector3 in [Vector3(0,-13,0),Vector3(-55,-13,0),Vector3(-76,-13,0),Vector3(-75.4,24,0),Vector3(-63.8,24,0),Vector3(-63.8,-13,0),Vector3(-55,-13,0),Vector3(0,-13,0),Vector3(40,-13,0),Vector3(64.3,-13,0),Vector3(64.3,24,0),Vector3(74.6,24,0),Vector3(74.6,8,0),Vector3(80,8,0),Vector3(80,-13,0),Vector3(110,-13,0),Vector3(110,-26.5,0),Vector3(80,-26.5,0),Vector3(68.8,-35,0),Vector3(64.3,-35,0),Vector3(64.3,-26.5,0),Vector3(40,-26.5,0),Vector3(20,-26.5,0),Vector3(20,-24.5,0),Vector3(-2,-24.5,0),Vector3(-2,-26.5,0),Vector3(-40,-26.5,0),Vector3(-70,-26.5,0),Vector3(-70,-35,0),Vector3(-75.4,-35,0),Vector3(-75.4,-26.5,0),Vector3(-85,-26.5,0),Vector3(-85,-13,0),Vector3(-55,-13,0),Vector3(0,-13,0)]:
		_previous_exploration_usec = 0
		_collect_exploration = true
		var reached := await _city_walk(point)
		_collect_exploration = false
		if not reached: break
		if point==Vector3(-55,-13,0) and not fronts_reviewed:
			await _northwest_frontages()
			fronts_reviewed=true
			if not failures.is_empty():break
		if point==Vector3(-40,-26.5,0):await _station_view("northwest_row_from_south_walk",Vector3(-42,-6.2,8))
		if point == Vector3(-76,-13,0): await _station_view("street_west_junction",Vector3(-68,-22,1))
		if point == Vector3(64.3,24,0): await _station_view("street_east_narrow_walk",Vector3(66,-13,1))
		if point == Vector3(80,-26.5,0): await _station_view("street_pier_islands",Vector3(73,-27.45,1))
	check(world.safety_net.recoveries == recoveries_before,"new street block walking uses actual floors without rescue")
	city_observations["street_block"] = {"waypoints":trace.size()-start,"samples":_exploration_samples.duplicate(),"scope":"Actual controller through both junctions, north/south street walks, both cross-street ends and east1.62m pinch; unchanged live traffic. Captures excluded from timings. No matched before/after speed claim."}
	_exploration_samples.clear()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)

func _northwest_frontages() -> void:
	var start:=trace.size()
	var recoveries_before:=world.safety_net.recoveries
	# The installed whole row moved8m north. Walk the real public strip in front
	# of the three replacements and retained Hunters Point, with the full body.
	for point: Vector3 in [Vector3(-56.25,-10,0),Vector3(-56.25,-7,0),Vector3(-45.25,-7,0),Vector3(-27,-7,0),Vector3(-27,-13,0),Vector3(-55,-13,0)]:
		if not await _city_walk(point):return
		if point.y==-7.:
			var identity: String="site_nw4" if point.x==-56.25 else "site_nw3" if point.x==-45.25 else "site_nw1"
			await _station_view(identity+"_standing_frontage",Vector3(point.x,-6.2,1.6))
	check(world.safety_net.recoveries==recoveries_before,"commercial frontage uses the real walk without rescue")
	city_observations["northwest_frontage"]={"completed":true,"waypoints":trace.size()-start,"scope":"Standing production controller along three commercial fronts and retained Hunters Point frontage. Passive doors remain closed; no new shop/access authority or artistic acceptance."}

func _wide_street_tour() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var start := trace.size()
	var recoveries_before := world.safety_net.recoveries
	# Physical blocks occupy the old straight sightline at150m. Follow the
	# genuine north street gap around them rather than removing city buildings.
	for point: Vector3 in [Vector3(-30,0,3),Vector3(-80,0,3),Vector3(-140,0,3),Vector3(-140,0,-10),Vector3(-226,0,-2),Vector3(-250,0,36),Vector3(-252,0,38),Vector3(-272,0,38),Vector3(-274,0,36),Vector3(-280,0,-10),Vector3(-274,0,36),Vector3(-272,0,38),Vector3(-252,0,38),Vector3(-250,0,36),Vector3(-226,0,-2),Vector3(-140,0,-10),Vector3(-140,0,3),Vector3(0,0,3),Vector3(60,0,3),Vector3(140,0,3),Vector3(140,0,-10),Vector3(226,0,-2),Vector3(250,0,36),Vector3(252,0,38),Vector3(272,0,38),Vector3(274,0,36),Vector3(280,0,-10),Vector3(274,0,36),Vector3(272,0,38),Vector3(252,0,38),Vector3(250,0,36),Vector3(226,0,-2),Vector3(140,0,-10),Vector3(140,0,3),Vector3(60,0,3),Vector3(0,0,3)]:
		_previous_exploration_usec = 0
		_collect_exploration = true
		print("CITY EXTERIOR TOUR: target ",point)
		var local_target: Vector3 = world.adapter.root.to_local(point)
		local_target.y = _expected_western_soil_height(local_target.x)
		var reached := await _walk(local_target)
		_collect_exploration = false
		if not reached: break
		if point.x in [-280.,280.]:
			player.face_world_point(Vector3(0,8,0))
			await get_tree().create_timer(.25).timeout
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("street_%d.png"%int(point.x))) == OK,"actual wider street view")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
	check(world.safety_net.recoveries == recoveries_before,"wide real-floor walk is not limited by safety-net rescue")
	city_observations["wider_street"] = {"waypoints":trace.size()-start,"columns":["wall_ms","main_render_cpu_ms","main_render_gpu_ms","engine_draws","engine_primitives"],"samples":_exploration_samples,"scope":"Normal controller walking to280m east and west, using existing street gaps around physical blocks. Captures excluded; live NPC/traffic uncontrolled; counters are global and GPU timers cover the main viewport. No matched before/after speed claim."}

func _expected_western_soil_height(x: float) -> float:
	if x <= float(WESTERN_SOIL_PROFILE[0][0]): return -.02
	for i in WESTERN_SOIL_PROFILE.size()-1:
		var a: Array = WESTERN_SOIL_PROFILE[i]
		var b: Array = WESTERN_SOIL_PROFILE[i+1]
		if x <= float(b[0]):
			return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/(float(b[0])-float(a[0])))
	return float(WESTERN_SOIL_PROFILE[-1][1])

func _radius_controller_fixtures() -> void:
	var boundary := world.get_node("StreetBoundaries") as Node3D
	var limit := boundary.get_node("TemporaryExteriorLimit") as StaticBody3D
	var radius := float(limit.get_meta("radius_m"))
	var prior := player.global_transform
	var prior_camera := player.camera.rotation
	var prior_layer := limit.collision_layer
	var recoveries_before := world.safety_net.recoveries
	var results: Array = []
	# Explicit component fixtures above occupied stock. Gravity and the actual
	# standing controller stay active; no floor, noclip or reach exemption is added.
	for angle: float in [0.,.71,PI/2,PI,3*PI/2]:
		var local_direction := Vector3(cos(angle),0,sin(angle))
		var direction := boundary.global_basis*local_direction
		player.global_position = boundary.to_global(local_direction*(radius-1.)+Vector3.UP*150.)
		player.velocity = Vector3.ZERO
		player.face_world_point(player.global_position+direction*10.)
		var touched := false
		var maximum := 0.
		Input.action_press("move_forward")
		for frame in 90:
			await get_tree().physics_frame
			var local := boundary.to_local(player.global_position)
			maximum = maxf(maximum,Vector2(local.x,local.z).length())
			for index in player.get_slide_collision_count(): touched = touched or player.get_slide_collision(index).get_collider() == limit
		Input.action_release("move_forward")
		check(touched and maximum <= radius+.01 and maximum > radius-.6 and not player.noclip,"normal controller cannot cross the distant radial wall")
		results.append({"angle":angle,"maximum_center_distance_m":maximum,"touched_limit":touched})
	limit.collision_layer = 0
	await get_tree().physics_frame
	player.global_position = boundary.to_global(Vector3(radius-1.,150,0))
	player.velocity = Vector3.ZERO
	player.face_world_point(player.global_position+boundary.global_basis.x*10.)
	Input.action_press("move_forward")
	for frame in 90: await get_tree().physics_frame
	Input.action_release("move_forward")
	var outside := boundary.to_local(player.global_position)
	var control_distance := Vector2(outside.x,outside.z).length()
	check(control_distance > radius+1.,"disabling only the temporary wall admits the same controller beyond the limit")
	limit.collision_layer = prior_layer
	player.global_transform = prior
	player.camera.rotation = prior_camera
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(limit.collision_layer == prior_layer,"negative control restores the exact temporary boundary")
	check(world.safety_net.recoveries == recoveries_before,"registered exterior reaches the radius without safety-net travel teleports")
	var zones_before: Array[AABB] = world.safety_net.exempt_zones.duplicate()
	var exterior_zone: AABB = boundary._exterior_ground_zone
	boundary._unregister_exterior_ground()
	check(not world.safety_net.exempt_zones.has(exterior_zone) and world.safety_net.exempt_zones.size() == zones_before.size()-1,"city owner cleanup removes only its safety-net footprint")
	boundary._register_exterior_ground()
	boundary._register_exterior_ground()
	var restored := world.safety_net.exempt_zones.size() == zones_before.size()
	for zone: AABB in zones_before: restored = restored and world.safety_net.exempt_zones.has(zone)
	check(restored,"registration restores original safety exemptions without duplicate ownership")
	city_observations["radius_limit"] = {"radius_m":radius,"fixtures":results,"disabled_control_distance_m":control_distance,"scope":"Explicit airborne controller fixtures at150m, not continuous city walks or roof access. Exact original pose and boundary layer restored."}
