extends "res://tests/orison_v2_4b_door_route_test.gd"
## INERT actual-world optical baseline. Same route/settings before and after effects.
var _phase: String='startup_excluded'
var _samples: Array=[]
var _collect:=false
var _previous_usec:=0
var _monitors: Dictionary={}
var _mirror_owner: Node3D
var _flow_samples: Array=[]
var _tap: TapProp
func _init() -> void:route_label='V2 BATHROOM OPTICS PROFILE'
func _process(_delta: float) -> void:
	var now:=Time.get_ticks_usec()
	if _collect and _previous_usec>0:
		var viewport:=get_viewport().get_viewport_rid()
		var mirror_view:=world.mirror_renderer._view.get_viewport_rid()
		var counters: Dictionary={}
		for id: String in _monitors:counters[id]=Performance.get_monitor(_monitors[id])
		counters['mirror_active_unit']=world.mirror_renderer.get_meta('active_unit','')
		_samples.append([_phase,(now-_previous_usec)/1000.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,RenderingServer.viewport_get_measured_render_time_cpu(viewport),RenderingServer.viewport_get_measured_render_time_gpu(viewport),RenderingServer.viewport_get_measured_render_time_cpu(mirror_view),RenderingServer.viewport_get_measured_render_time_gpu(mirror_view),world.passage_region.residency.state,counters])
	_previous_usec=now
func _measure(label: String,look_at: Vector3,seconds: float=8.0) -> void:
	_phase=label;player.camera.look_at(look_at)
	_flow_samples.append({'phase':label,'flow':_tap.get_flow_state(),'weather':world.get_node('WeatherFX')._live_conditions.duplicate(true),'physics_frame':Engine.get_physics_frames()})
	var start:=Time.get_ticks_msec();var frames:=0
	while Time.get_ticks_msec()-start<seconds*1000.0:
		await get_tree().process_frame;frames+=1
func _route() -> void:
	await _profile_route()

func _profile_route() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	RenderingServer.viewport_set_measure_render_time(world.mirror_renderer._view.get_viewport_rid(),true)
	for id: String in ClassDB.class_get_integer_constant_list('Performance'):
		if id.begins_with('PIPELINE_COMPILATIONS_') or id.begins_with('RENDER_') or id.begins_with('OBJECT_'):
			_monitors[id]=ClassDB.class_get_integer_constant('Performance',id)
	var bath_door:=_leaf('F04_B_BATH_DOOR')
	if not _require(bath_door!=null,'retained bathroom door exists'):return
	var stance: Vector3=world.adapter.root.to_global(Vector3(-8.45,9.62,4.35))
	var inside_sign:=signf(bath_door.to_local(stance).z)
	player.global_position=bath_door.to_global(Vector3(bath_door.width*.5,.02,-inside_sign*.60));player.velocity=Vector3.ZERO
	player.profile_physics=true;player._grab.profiling=true
	await get_tree().create_timer(1.5).timeout
	for surface: Node in get_tree().get_nodes_in_group('planar_mirror_surface'):
		var owner_node: Node=surface.get_parent()
		while owner_node!=null and not owner_node.has_method('mirror_surface'):owner_node=owner_node.get_parent()
		if owner_node!=null and str(owner_node.get('unit'))=='4B':_mirror_owner=owner_node;break
	var shower:=world.adapter.resolve('F04_4B_SHOWER_01') as TapProp
	if not _require(shower!=null and _mirror_owner!=null,'actual 4B shower and bathroom mirror exist'):return
	_tap=shower
	_collect=true
	await _played_bathroom(shower,bath_door,inside_sign)
	_collect=false
	var directory:=OS.get_environment('SHOT_DIR');DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join('frames.json'),FileAccess.WRITE).store_string(JSON.stringify({'evidence_class':'INERT','scope':'Actual occupied-world optical/performance diagnostic; no runtime acceptance. Initial fixture placement only; all valve operation uses player input.','resolution':str(get_viewport().get_visible_rect().size),'fov':player.camera.fov,'render_method':RenderingServer.get_current_rendering_method(),'vsync':false,'columns':['phase','wall_ms','process_ms','physics_ms','render_cpu_ms','render_gpu_ms','mirror_cpu_ms','mirror_gpu_ms','residency','engine_monitors'],'samples':_samples,'flow_samples':_flow_samples,'player_physics':player.physics_profile_records,'input_costs':player._grab.profile_records,'failures':failures},'\t'))
func _played_bathroom(shower: TapProp,bath_door: DoorProp,inside_sign: float) -> bool:
	_phase='door_input'
	if not await _drag_part(bath_door,bath_door.to_global(Vector3(bath_door.width-.085,1.0,0)),bath_door.motion_target_angle(true),'bathroom_easy_open'):return false
	_phase='approach_shower_walk'
	if not await _walk(world.adapter.root.to_local(bath_door.to_global(Vector3(bath_door.width*.5,.02,inside_sign*.75)))):return false
	if not await _walk(Vector3(-8.45,9.6,4.35)):return false
	if not await _wet_route(shower):return false
	_require(true,'complete dry/cold/hot/mirror/decay input sequence')
	return _require(not bath_door.open and absf(bath_door._body.rotation.y)<.001,'released room door closes automatically during ordinary use')
func _wet_route(shower: TapProp) -> bool:
	var water_view:=shower.to_global(Vector3(0,1.15,.08))
	if not await _drag_part(shower,shower.to_global(Vector3(0,1.18,-.32)),1.78,'profile_curtain_open'):return false
	await _measure('dry_shower',water_view)
	await _measure('dry_mirror',_mirror_owner.mirror_center())
	_phase='input_cold'
	if not await _drag_part(shower,shower._handles[1].global_position,PI*.5,'profile_cold_on'):return false
	if not _require(float(shower.get_flow_state().temperature)==0.0,'cold phase uses actual cold supply'):return false
	await _measure('cold_shower',water_view)
	_phase='input_hot'
	if not await _drag_part(shower,shower._handles[1].global_position,0.0,'profile_cold_off'):return false
	if not await _drag_part(shower,shower._handles[0].global_position,PI*.5,'profile_hot_on'):return false
	if not _require(float(shower.get_flow_state().temperature)>.1,'hot phase has actual heated water'):return false
	await _measure('hot_developing',water_view,12.0)
	await _measure('hot_mirror',_mirror_owner.mirror_center(),10.0)
	_phase='input_off'
	if not await _drag_part(shower,shower._handles[0].global_position,0.0,'profile_hot_off'):return false
	await _measure('off_mirror_decay',_mirror_owner.mirror_center(),10.0)
	return true
