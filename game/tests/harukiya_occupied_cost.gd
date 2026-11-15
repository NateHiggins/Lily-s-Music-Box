extends "res://tests/harukiya_occupied_services_test.gd"
## Current absolute occupied idle cost; no historical comparison or service peak claim.
const NativeWindowSource := "res://tests/harukiya_cost_window.gd"
const WARM_FRAMES := 60
const COST_FRAMES := 180
var timing := false
var cost_rows: Array=[]
var cost_settings: Dictionary={}
var old_cap := 0
var old_vsync := 0
var settings_owned := false

func _ready() -> void:
	if OS.get_environment("ORISON_COST_VIEWPORT_PREFLIGHT") == "1":
		_viewport_preflight.call_deferred()
	else:
		super._ready()

func _viewport_preflight() -> void:
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var size: Vector2 = get_viewport().get_visible_rect().size
	var image: Image = get_viewport().get_texture().get_image()
	var ok: bool = size == Vector2(2560,1440) and image != null and image.get_size() == Vector2i(2560,1440) and get_window().get_flag(Window.FLAG_BORDERLESS)
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK: get_tree().quit(2); return
	var capture_ok: bool = image != null and image.save_png(output.path_join("viewport.png")) == OK
	var file := FileAccess.open(output.path_join("viewport.json"),FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify({"evidence_class":"INERT viewport-only preflight","viewport":size,"image_size":image.get_size() if image != null else Vector2i.ZERO,"borderless":get_window().get_flag(Window.FLAG_BORDERLESS),"status":"PASS" if ok and capture_ok else "FAIL"},"\t"));file.flush()
	print("HARUKIYA COST VIEWPORT PREFLIGHT: ","PASS" if ok and capture_ok else "FAIL")
	get_tree().quit(0 if ok and capture_ok and file.get_error() == OK else 1)

func _required_service_contracts() -> Array:return []

func _physics_process(delta: float) -> void:
	if timing:return # ONLY this diagnostic observer; production nodes remain active.
	super._physics_process(delta)

func _opposition_programme() -> void:
	if not _check(get_viewport().get_visible_rect().size==Vector2(2560,1440),"actual native client viewport2560x1440"):return
	if not _check(get_window().mode==Window.MODE_WINDOWED and get_window().get_flag(Window.FLAG_BORDERLESS),"exact borderless cost client applied"):return
	var route: Node3D=routes.nadia_quell
	world.player.set_mouse_released(false)
	var path: PackedInt64Array=route.graph.get_id_path(int(route.identities.street),int(route.identities.bar_pool_interaction))
	if not _check(not path.is_empty(),"original player connected occupied audience approach"):return
	for point: int in path:
		if not await _walk_player(route.graph.get_point_position(point),str(route.identities.find_key(point))):return
	service_civil=clock.day_info().duplicate(true)
	service_people.clear()
	for id: String in routes:service_people[id]={"owner":routes[id].get_instance_id(),"actor":routes[id].actor.get_instance_id()}
	service_node="pool_interaction"
	# Keep service_active false: its240s action programme is not this measurement.
	# Production clock still uses parent's original frozen Friday21 preview.
	details.services={"legs":[],"games":{},"captures":[],"mass_programme_executed":false}
	old_cap=Engine.max_fps;old_vsync=DisplayServer.window_get_vsync_mode();settings_owned=true
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rid:=get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	cost_settings={"viewport":get_viewport().get_visible_rect().size,"engine":Engine.get_version_info(),"executable":OS.get_executable_path(),"executable_sha256":FileAccess.get_sha256(OS.get_executable_path()),"cpu":OS.get_processor_name(),"processor_count":OS.get_processor_count(),"os":OS.get_name(),"gpu":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"driver":RenderingServer.get_video_adapter_api_version(),"rendering_method":RenderingServer.get_current_rendering_method(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"taa":get_viewport().use_taa,"msaa":get_viewport().msaa_3d,"scale_3d":get_viewport().scaling_3d_scale,"fov":world.player.camera.fov,"civil":service_civil,"minute":clock.minute_of_day(),"shadow_atlas":ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/atlas_size"),"directional_shadow_size":ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size"),"weather_data":RealityState.data.get("weather",{}).duplicate(true),"source_inputs":initial_inputs,"host_load":"not independently measured; exclusive Godot FIFO is not proof of idle OS/GPU host","observer_policy":"per-frame diagnostic collision/trace observer skipped only during warm/sample; production processing unchanged"}
	for station: String in ["pool_interaction","gallery_return"]:
		if station!="pool_interaction":
			service_started=Time.get_ticks_msec();service_active=true
			var reached: bool=await _go_service(station)
			service_active=false
			if not reached:break
		var support: Dictionary=PlayerSupport.inspect(world.bar_region,world.player,world.player.global_position)
		details["cost_support_"+station]=support
		if not _check(bool(support.get("supported",false)),"actual supported cost stance "+station):break
		var initial_yaw: float=world.player.rotation.y
		for heading: int in 4:
			world.player.rotation.y=initial_yaw+float(heading)*PI*.5
			world.player.camera.rotation=Vector3.ZERO
			if not _cohort_valid():break
			var before:=_cohort()
			timing=true
			for frame: int in WARM_FRAMES:await RenderingServer.frame_post_draw
			var row: Dictionary=await _sample_cost(station,heading)
			timing=false
			_check(_cohort_valid() and _cohort()==before,"same active occupied cohort before/after timing")
			row.cohort=before;cost_rows.append(row)
			row.within_blocking_budget=float(row.wall_ms.median)<=33.3
			if not failures.is_empty():break
		if not failures.is_empty():break
	_check(cost_rows.size()==8,"both supported occupied stations measured at four headings")
	for row: Dictionary in cost_rows:_check(bool(row.within_blocking_budget),"occupied1440p median<=33.3ms "+str(row.station)+"/"+str(row.heading))
	_check(_queue_drained() and squeeze_witness.snapshot().active.is_empty(),"occupied cost ends with drained queues and no squeeze")

func _cohort_valid() -> bool:
	if not _check(_all_occupied() and routes.size()==18 and _queue_drained(),"exact original18 remain occupied"):return false
	if not _check(clock.day_info()==service_civil and absf(clock.minute_of_day()-1260.0)<.00001,"original Friday21 clock retained"):return false
	for id: String in service_people:
		var route: Node3D=routes[id]
		if not _check(route.get_instance_id()==int(service_people[id].owner) and route.actor.get_instance_id()==int(service_people[id].actor) and route.is_physics_processing() and route.can_process() and route.actor.is_visible_in_tree(),"actual active cost actor "+id):return false
	for id: String in ["stacy","lily"]:
		var body: Node3D=world.harukiya_counter.cast.actors[id]
		if not _check(body.ready_ok and body.is_visible_in_tree() and body.is_processing() and body.is_in_group("animated_residents") and not body.standing_occupancy().is_empty(),"actual active cost staff "+id):return false
	return _check(world.player.is_physics_processing() and not world.player.noclip,"original active player retained")

func _cohort() -> Dictionary:
	var result: Dictionary={}
	for id: String in routes:
		var route: Node3D=routes[id]
		result[id]={"owner":route.get_instance_id(),"actor":route.actor.get_instance_id(),"position":route.actor.global_position,"place":str(route._bar_route.visit.phase())}
	for id: String in ["stacy","lily"]:
		var body: Node3D=world.harukiya_counter.cast.actors[id]
		result[id]={"actor":body.get_instance_id(),"model":body.model.get_instance_id(),"position":body.global_position,"parts":body.worn_parts(),"column":body.standing_occupancy()}
	return result

func _sample_cost(station: String,heading: int) -> Dictionary:
	var raw: Array=[];var columns: Array=[[],[],[],[],[],[]]
	var rid:=get_viewport().get_viewport_rid();var previous:=Time.get_ticks_usec()
	for frame: int in COST_FRAMES:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		var values: Array=[float(now-previous)/1000.0,RenderingServer.viewport_get_measured_render_time_cpu(rid),RenderingServer.viewport_get_measured_render_time_gpu(rid),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
		previous=now;raw.append(values)
		for i: int in 6:columns[i].append(float(values[i]))
	return {"station":station,"heading":heading,"camera_transform":world.player.camera.global_transform,"warm_frames":WARM_FRAMES,"sample_frames":COST_FRAMES,"columns":["wall_ms","viewport_render_cpu_ms","viewport_render_gpu_ms","draw_calls","primitives","objects"],"samples":raw,"wall_ms":_distribution(columns[0]),"render_cpu_ms":_distribution(columns[1]),"render_gpu_ms":_distribution(columns[2]),"draw_calls":_distribution(columns[3]),"primitives":_distribution(columns[4]),"objects":_distribution(columns[5])}

func _distribution(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"min":values[0],"max":values[-1]}

func _finish() -> void:
	timing=false
	if settings_owned:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
		Engine.max_fps=old_cap;DisplayServer.window_set_vsync_mode(old_vsync)
	await super._finish()

func _decorate_result(result: Dictionary) -> void:
	result.suite="HarukiyaOccupiedCost"
	result.scope="Current absolute occupied idle cost of actual original18+Stacy/Lily/player in composed world at audience pool and gallery stances. No historical delta, mass journey replay, lively peak/service benchmark or artistic acceptance. Diagnostic safety observer suspended during timing; production owners stay active; safety outside timing and cohort before/after only."
	result.contracts.continuous_safety={"executed":false,"status":"NOT_RUN","reason":"Continuous diagnostic observer intentionally absent during timing; transit and boundary checks only."}
	result.fixture.mass_programme_executed=false
	result.fixture.required_contracts=[]
	result.fixture.diagnostic_observer_suspended_during_timing=true
	result.details.cost={"settings":cost_settings,"rows":cost_rows,"blocking_median_ms":33.3,"future_goal_ms":16.6,"future_goal_blocking":false,"baseline":"first current-source absolute measurement, no matched historical comparison"}
