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

func _ready() -> void:
	OS.set_environment("WEATHER_SKY_BASELINE","1" if baseline_mode else "0")
	_calendar_mode=OS.get_environment("WEATHER_PROFILE_CALENDAR")=="1"
	OS.set_environment("WEATHER_SIMULATE","" if _calendar_mode else "hail_storm")
	OS.set_environment("WEATHER_SEED","1928")
	OS.set_environment("DAYNIGHT_FORCE","evening")
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
	_phase="walk_%02d"%_walk_index
	_segments.append({"phase":_phase,"start_world":str(player.global_position),"target_world":str(world.adapter.root.to_global(target))})
	return await super._walk(target)

func _move_front_entrance(identity: String,want_open: bool) -> bool:
	_phase="door_grab_open" if want_open else "door_grab_close"
	return await super._move_front_entrance(identity,want_open)

func _route() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	for key: String in ClassDB.class_get_integer_constant_list("Performance"):
		if key.begins_with("PIPELINE_COMPILATIONS_") or key.begins_with("RENDER_") or key.begins_with("OBJECT_"):
			_monitors[key]=ClassDB.class_get_integer_constant("Performance",key)
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	var manager: Node=world.get_node("WakingAtmosphere").weather_manager
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
		"player_physics":player.physics_profile_records,"failures":failures},"\t"))
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
	_phase="outdoor_mouse_turn"
	player.set_mouse_released(false)
	for direction: float in [1.0,-1.0]:
		for frame in 120:
			var motion:=InputEventMouseMotion.new();motion.relative=Vector2(direction*9.0,0)
			player._unhandled_input(motion)
			await get_tree().physics_frame
	_phase="outdoor_sky_hold"
	player.face_world_point(Vector3(-100,35,9.5))
	await get_tree().create_timer(8.0).timeout
