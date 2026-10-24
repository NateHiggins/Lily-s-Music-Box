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

func _ready() -> void:
	OS.set_environment("WEATHER_SKY_BASELINE","1" if baseline_mode else "0")
	OS.set_environment("WEATHER_SIMULATE","hail_storm")
	OS.set_environment("WEATHER_SEED","1928")
	OS.set_environment("DAYNIGHT_FORCE","evening")
	GameBoot.settings.weather_network_enabled=false
	route_label="V2 WEATHER BASELINE" if baseline_mode else "V2 WEATHER INTEGRATED"
	super._ready()

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
	await get_tree().create_timer(3.0).timeout
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
		"baseline_mode":baseline_mode,"resolution":str(get_viewport().get_visible_rect().size),"fov":player.camera.fov,
		"renderer":RenderingServer.get_current_rendering_method(),"taa":get_viewport().use_taa,"msaa":get_viewport().msaa_3d,
		"weather":"hail_storm","daynight_force":"evening","traffic_seed":1928,"traffic_frozen":traffic.frozen,
		"columns":["phase","wall_ms","script_ms","physics_ms","render_cpu_ms","render_gpu_ms","residency","counters"],
		"segments":_segments,"samples":_samples,"input_costs":player._grab.profile_records,
		"player_physics":player.physics_profile_records,"failures":failures},"\t"))

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
