extends "res://tests/orison_v2_golden_repair_route_test.gd"
## Diagnostic timings on the continuous opening, detailed home and repair route.
## Parent route assertions remain authoritative; no receipt or acceptance grant.
var profile_phase: String="startup"
var profile_samples: Array=[]
var profile_active:=false
var previous_usec:=0

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_usec()
	if profile_active and previous_usec>0:
		var viewport:=get_viewport().get_viewport_rid()
		profile_samples.append([profile_phase,(now-previous_usec)/1000.,Performance.get_monitor(Performance.TIME_PROCESS)*1000.,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,RenderingServer.viewport_get_measured_render_time_cpu(viewport),RenderingServer.viewport_get_measured_render_time_gpu(viewport),world.passage_region.residency.state])
	previous_usec=now

func _route() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	profile_active=true
	await super._route()
	profile_active=false
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","kind":"performance_diagnostic","resolution":str(get_viewport().get_visible_rect().size),"vsync":false,"columns":["phase","wall_ms","process_ms","physics_ms","render_cpu_ms","render_gpu_ms","residency"],"samples":profile_samples,"failures":failures},"\t"))

func _walk(target: Vector3) -> bool:
	profile_phase="walk_"+str(target)
	return await super._walk(target)

func _hand_move(owner_node: Node3D,point: Vector3,goal: float,label: String) -> bool:
	profile_phase="grab_"+label
	return await super._hand_move(owner_node,point,goal,label)

func _use(owner_node: Node3D,target: Vector3,label: String) -> bool:
	profile_phase="use_"+label
	return await super._use(owner_node,target,label)
