extends "res://tests/orison_v2_street_crossing_test.gd"
## INERT matched occupied-world weather diagnostic. Does not qualify whole V2.
@export var baseline_mode:=false
var _collect:=false
var _phase:="startup_excluded"
var _previous_usec:=0
var _samples: Array=[]
var _segments: Array[Dictionary]=[]
var _monitors: Dictionary={}
var _walk_index:=0
var _source_before:=""
var _calendar_mode:=false
var _mirage_profile_mode:=false
var _cloud_profile_mode:=false
var _phase_prefix:=""
var _release_doors: Array[DoorProp]=[]

func _ready() -> void:
	# GPU readback and PNG encoding must not contaminate measured route frames.
	capture_street_line=false
	OS.set_environment("WEATHER_SKY_BASELINE","1" if baseline_mode else "0")
	_cloud_profile_mode=OS.get_environment("SKYWATCH_CLOUD_PROFILE")=="1"
	_mirage_profile_mode=OS.get_environment("SKYWATCH_MIRAGE_PROFILE")=="1" or _cloud_profile_mode
	_calendar_mode=OS.get_environment("WEATHER_PROFILE_CALENDAR")=="1" or _mirage_profile_mode
	OS.set_environment("WEATHER_SIMULATE","" if _calendar_mode else "hail_storm")
	OS.set_environment("WEATHER_SEED","1928")
	OS.set_environment("DAYNIGHT_FORCE","" if _mirage_profile_mode else "evening")
	GameBoot.settings.weather_network_enabled=false
	route_label="V2 WEATHER BASELINE" if baseline_mode else "V2 WEATHER INTEGRATED"
	_source_before=_runtime_digest()
	super._ready()

func _runtime_digest() -> String:
	var result: Array=[]
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],result)!=0:return ""
	return str(result[0]).strip_edges() if not result.is_empty() else ""

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_usec()
	if _collect and _previous_usec>0:
		var view:=get_viewport().get_viewport_rid()
		var counters: Dictionary={}
		for key: String in _monitors:counters[key]=Performance.get_monitor(_monitors[key])
		_samples.append([_phase,(now-_previous_usec)/1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(view),
			RenderingServer.viewport_get_measured_render_time_gpu(view),
			world.passage_region.residency.state,counters])
	_previous_usec=now

func _walk(target: Vector3) -> bool:
	_walk_index+=1
	_phase=_phase_prefix+"walk_%02d"%_walk_index
	_segments.append({"phase":_phase,"start_world":str(player.global_position),"target_world":str(world.adapter.root.to_global(target))})
	return await super._walk(target)

func _move_front_entrance(identity: String,want_open: bool) -> bool:
	_phase=_phase_prefix+("door_grab_open" if want_open else "door_grab_close")
	if OS.get_environment("V2_PROFILE_RELEASES")=="1":
		var anchor := world.adapter.resolve(identity) as Node3D
		var door := anchor.get_node(identity+"_Leaf") as DoorProp
		door.profile_release=true
		if not _release_doors.has(door):_release_doors.append(door)
	return await super._move_front_entrance(identity,want_open)

func _release_attribution() -> Dictionary:
	var rows: Array[Dictionary]=[]
	for door: DoorProp in _release_doors:
		if is_instance_valid(door):rows.append({"owner":str(door.get_path()),"samples":door.release_profile_records})
	return {"scope":"Opt-in synchronous stage timings; household callback profiling adds separately recorded probe overhead. No scheduling or persistence change.",
		"doors":rows,"household":world.household_state.profile_records,"commit_causes":world.household_state.profile_causes}

func _route() -> void:
	if OS.get_environment("V2_PROFILE_RELEASES")=="1":world.household_state.profiling=true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for key: String in ClassDB.class_get_integer_constant_list("Performance"):
		if key.begins_with("PIPELINE_COMPILATIONS_") or key.begins_with("RENDER_") or key.begins_with("OBJECT_"):
			_monitors[key]=ClassDB.class_get_integer_constant("Performance",key)
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	var manager: Node=world.get_node("WakingAtmosphere").weather_manager
	if _mirage_profile_mode:
		await _profile_mirage_route(manager)
		return
	var lens_draw_enabled:=OS.get_environment("WEATHER_PROFILE_LENS")!="0"
	if not lens_draw_enabled and world.get_node("WeatherFX").lens!=null:
		world.get_node("WeatherFX").lens.get_parent().hide()
	if not _calendar_mode:
		manager.current=manager.Service.presentation(manager.Service.simulated_snapshot("hail_storm"))
		manager.target=manager.current.duplicate(true);manager.origin=manager.current.duplicate(true)
		manager.elapsed=manager.TRANSITION_SECONDS;manager._publish()
		if manager.extreme_weather!=null:
			manager.extreme_weather.advance(120.0);manager._publish()
	var traffic: Node=world.period_traffic
	traffic.stage([{"id":traffic.data.kinds[0].id,"x":-30.0,"lane_west":false,"speed":4.0},
		{"id":traffic.data.kinds[1].id,"x":30.0,"lane_west":true,"speed":4.0}])
	traffic._rng.seed=1928;traffic._spawn_accum=3.0;traffic.frozen=false
	player.profile_physics=true;player._grab.profiling=true
	await get_tree().create_timer(maxf(3.0,world.passage_region.residency.DORMANCY_GRACE_SECONDS+.2)).timeout
	_collect=true;_previous_usec=0
	await super._route()
	if failures.is_empty():
		if await _leave_front_entrance():
			if await _walk(world.adapter.root.to_local(Vector3(0,0,3))):
				await _turn_and_hold()
	_collect=false
	var output:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output.path_join("weather_frames.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"Matched actual-controller street crossing, front-door grabs and outdoor mouse turning; no full V2 or statistical performance qualification",
		"baseline_mode":baseline_mode,"lens_draw_enabled":lens_draw_enabled,"resolution":str(get_viewport().get_visible_rect().size),"fov":player.camera.fov,
		"renderer":RenderingServer.get_current_rendering_method(),"taa":get_viewport().use_taa,"msaa":get_viewport().msaa_3d,
		"weather":"campaign-calendar" if _calendar_mode else "hail_storm","weather_source":manager.source,"conditions":manager.current.duplicate(true),"atmosphere":manager.atmosphere_state,"daynight_force":"evening","traffic_seed":1928,"traffic_frozen":traffic.frozen,
		"columns":["phase","wall_ms","process_ms","physics_ms","render_cpu_ms","render_gpu_ms","residency","counters"],
		"segments":_segments,"samples":_samples,"input_costs":player._grab.profile_records,
		"player_physics":player.physics_profile_records,"release_attribution":_release_attribution(),"failures":failures},"\t"))
	var source_after:=_runtime_digest()
	if source_after.is_empty() or source_after!=_source_before:failures.append("runtime source changed during played route")
	if trace.size()!=29 or _samples.size()<1000:failures.append("played route or measured sample interval incomplete")
	var status:="PASS" if failures.is_empty() else "FAIL"
	var shader_sources: Dictionary={}
	for path: String in ["queens_weather_sky.gdshader","queens_weather_math.gdshaderinc","sky_spectacle.gdshaderinc"]:
		shader_sources["game/shaders/"+path]=FileAccess.get_file_as_string("res://shaders/"+path).replace("\r\n","\n").sha256_text()
	FileAccess.open(output.path_join("weather_route_contract.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Played occupied V2 street crossing, actual door grab/motion/release and outdoor mouse turns under fixed-evening weather diagnostics. No calendar save/rebuild, whole-V2 coverage, teardown qualification, performance improvement or human acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false},
		"source":{"test_path":"game/tests/v2_weather_route_profile.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"runtime_inputs_sha256":source_after,"shader_sources":shader_sources},
		"contracts":{"production_composition":{"executed":is_instance_valid(world) and not world.startup_failed,"status":status},"continuous_route":{"executed":trace.size()==29,"status":status}},
		"checks":[{"name":"29 real-controller waypoints and bounded measurement","passed":trace.size()==29 and _samples.size()>=1000},{"name":"frozen runtime sources","passed":source_after==_source_before and not source_after.is_empty()}],"failures":failures},"\t"))

func _turn_and_hold() -> void:
	_phase=_phase_prefix+"outdoor_mouse_turn"
	player.set_mouse_released(false)
	for direction: float in [1.0,-1.0]:
		for frame in 120:
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(direction*9.0,0)
			player._unhandled_input(motion)
			await get_tree().physics_frame
	_phase=_phase_prefix+"outdoor_sky_hold"
	if _mirage_profile_mode:
		var facing := Vector3(sin(PI/4.),tan(deg_to_rad(3.5)),-cos(PI/4.))
		player.face_world_point(player.camera.global_position+facing*200.)
	else:player.face_world_point(Vector3(-100,35,9.5))
	await get_tree().create_timer(8.0).timeout

func _profile_mirage_route(manager: Node) -> void:
	var render_sources := _sky_source_bindings()
	var clock := CampaignClock.new();clock.configure_date(1929,5,9,14*60+15)
	if _cloud_profile_mode:clock.configure_date(1929,6,25,18*60)
	manager._calendar_check_left=0.;manager._phenomena_left=0.;manager._publish_left=0.;manager._process(.016)
	manager.origin=manager.target.duplicate(true);manager.elapsed=manager.TRANSITION_SECONDS
	manager._phenomena_left=0.;manager._process(.016);manager._publish();manager.set_process(false)
	var director: Node=world.get_node("WakingAtmosphere").director
	director._apply(clock.minute_of_day())
	var mirage: CompositorEffect=director._mirage
	if mirage==null or (not _cloud_profile_mode and float(manager._spectacle_levels[40])<.9):
		failures.append("authored mirage did not reach production presentation");return
	if _cloud_profile_mode and float(manager.atmosphere_state.get("combined_coverage",0.))<.5:
		failures.append("authored cloud profile did not publish a substantial deck");return
	var traffic: Node=world.period_traffic
	player.profile_physics=true;player._grab.profiling=true
	var output := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	var blocks: Array[Dictionary]=[]
	# Same occupied world, actual controller/door hands, same frozen calendar
	# and route. ABBA retains the cold first traversal separately from warm tails.
	for index in range(4):
		var active := index in [1,2]
		_collect=false;_phase_prefix="%s_%d_%s_"%["cloud" if _cloud_profile_mode else "mirage",index,"on" if active else "off"]
		mirage.enabled=active and not _cloud_profile_mode
		if _cloud_profile_mode:manager.sky.set_shader_parameter("living_fluid_enabled",active)
		_prepare_player_start()
		traffic.stage([{"id":traffic.data.kinds[0].id,"x":-30.,"lane_west":false,"speed":4.},
			{"id":traffic.data.kinds[1].id,"x":30.,"lane_west":true,"speed":4.}])
		traffic._rng.seed=1928;traffic._spawn_accum=3.;traffic.frozen=false
		await get_tree().create_timer(3.).timeout
		var trace_start := trace.size();var frame_start := _samples.size();var dispatch_start: int=mirage.passes
		_previous_usec=0;_collect=true
		await super._route()
		if not failures.is_empty():_collect=false;break
		if not await _leave_front_entrance():_collect=false;break
		if not await _walk(world.adapter.root.to_local(Vector3(0,0,3))):_collect=false;break
		await _turn_and_hold()
		_collect=false
		blocks.append({"id":_phase_prefix,"enabled":active,"first_traversal":index==0,"trace_start":trace_start,"waypoints":trace.size()-trace_start,"frame_start":frame_start,"frame_end":_samples.size(),"dispatches":mirage.passes-dispatch_start,"resident_variance":"NPC animation and physical traffic remain live; campaign time and traffic seeds are held"})
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(_phase_prefix+"street.png"))
		if not _cloud_profile_mode and ((active and mirage.passes==dispatch_start) or (not active and mirage.passes!=dispatch_start)):
			failures.append("mirage dispatch state contradicted paired route block");break
		# Restore the next block's starting door state using the real hand path.
		# Do this outside collection, while the exterior leaf is still reachable.
		if not await _walk(Vector3(0,0,-13.15)):break
		if not await _open_front_entrance():break
		if not await _walk(Vector3(0,0,-10.6)):break
		if not await _close_front_entrance():break
	if not mirage.failed.is_empty():failures.append(mirage.failed)
	var source_after := _runtime_digest()
	if source_after!=_source_before or source_after.is_empty():failures.append("source changed during occupied mirage profile")
	if render_sources!=_sky_source_bindings():failures.append("sky shader or noise stock changed during occupied profile")
	if blocks.size()!=4:failures.append("occupied ABBA profile did not complete all four blocks")
	FileAccess.open(output.path_join("cloud_world_frames.json" if _cloud_profile_mode else "mirage_world_frames.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"ABBA occupied-controller/door/street-turn diagnostic, first traversal retained separately; not whole-V2, river art or statistical performance acceptance",
		"cloud_flow_comparison":_cloud_profile_mode,
		"render_source_sha256":render_sources,
		"source_before":_source_before,"source_after":source_after,"blocks":blocks,"resolution":str(get_viewport().get_visible_rect().size),"msaa":get_viewport().msaa_3d,"taa":get_viewport().use_taa,
		"conditions":manager.current,"calendar":clock.local_datetime(),"weather_source":manager.source,"mirage_parameters":mirage.last_projection_parameters,
		"columns":["phase","wall_ms","process_ms","physics_ms","render_cpu_ms","render_gpu_ms","residency","counters"],"samples":_samples,"segments":_segments,
		"input_costs":player._grab.profile_records,"player_physics":player.physics_profile_records,"release_attribution":_release_attribution(),"failures":failures},"\t"))

func _sky_source_bindings() -> Dictionary:
	var result: Dictionary={}
	for name: String in ["queens_weather_sky.gdshader","queens_weather_math.gdshaderinc","sky_spectacle.gdshaderinc","skywatch_mirage.compute"]:
		result["game/shaders/"+name]=FileAccess.get_file_as_string("res://shaders/"+name).replace("\r\n","\n").sha256_text()
	for name: String in ["perlin_worley_64.rg8","perlin_worley_128.r8","cloud_curl_32.rgb8"]:
		result["game/assets/environment/weather/"+name]=FileAccess.get_sha256("res://assets/environment/weather/"+name)
	return result
