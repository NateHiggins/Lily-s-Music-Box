extends "res://tests/v2_commit_cause_world.gd"
## INERT same-route diagnostics; no runtime qualification or human acceptance.
var route_jobs: Array=[]
var route_status: Dictionary={}
var overlap: Dictionary={}
var old_background_profile:=false
var sync_control:=OS.get_environment("V2_BACKGROUND_SYNC_CONTROL")=="1"

func _play_route() -> void:
	world.household_state.background_persistence=not sync_control
	old_background_profile=RealityState.background_save_profiling
	RealityState.background_save_profiling=true
	RealityState.background_save_records.clear()
	await super._play_route()
	RealityState.background_save_profiling=old_background_profile

func _save_reload(wanted: Dictionary) -> void:
	profile_active=false
	RealityState.flush_background_saves()
	route_jobs=RealityState.background_save_records.duplicate(true)
	route_status=RealityState.background_save_status()
	var workers: Array=[]
	for row: Dictionary in route_jobs:
		if row.stage=="completed":workers.append(row)
	if not sync_control:
		_check(not workers.is_empty() and workers.all(func(row):return row.result.ok and not row.result.worker_main_thread),"actual route saves verify successfully on worker threads")
	_check(route_status.pending==0,"actual route autosaves settle before explicit save/rebuild")
	if OS.get_environment("V2_BACKGROUND_ROUTE_ONLY")=="1":
		work_probe.write(OS.get_environment("SHOT_DIR").path_join("work_trace.json"))
		_write_profile("route_only_no_rebuild")
		_write_jobs()
		return
	# Stress probe is outside timed gameplay. A large detached payload ensures
	# a live transaction spans real player mouse input; it is not typical save size.
	var key:="v2_background_probe_payload"
	var had:=RealityState.data.has(key)
	var previous: Variant=RealityState.data.get(key)
	RealityState.data[key]="input overlap ".repeat(230000)
	RealityState.commit_background()
	var before: bool=RealityState._save_queue._thread!=null and RealityState._save_queue._thread.is_alive()
	var body_pose: Transform3D=player.transform
	var eye_pose: Transform3D=player.camera.transform
	var old_basis: Basis=player.camera.global_basis
	var event:=InputEventMouseMotion.new();event.relative=Vector2(8,0)
	var started:=Time.get_ticks_usec()
	player._unhandled_input(event)
	var elapsed:=Time.get_ticks_usec()-started
	var after: bool=RealityState._save_queue._thread!=null and RealityState._save_queue._thread.is_alive()
	var moved: bool=not old_basis.is_equal_approx(player.camera.global_basis)
	overlap={"worker_alive_before":before,"worker_alive_after":after,"camera_turned":moved,"input_usec":elapsed,"mouse_mode":Input.mouse_mode,"payload_bytes":str(RealityState.data[key]).length()}
	_check(before and after and moved,"actual mouse look turns the camera while a large verified save worker is alive")
	player.transform=body_pose;player.camera.transform=eye_pose
	if had:RealityState.data[key]=previous
	else:RealityState.data.erase(key)
	RealityState.flush_background_saves()
	RealityState.commit()
	await super._save_reload(wanted)
	_check(RealityState.background_save_status().pending==0,"world reconstruction leaves no detached save writer")
	_write_jobs()

func _write_jobs() -> void:
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("background_jobs.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Same timed route; optional untimed large-payload mouse-overlap control. Main-thread serialization remains. Route-only controls do not rebuild. No runtime_contract or human acceptance.","synchronous_control":sync_control,"route_jobs":route_jobs,"route_status":route_status,"untimed_overlap":overlap,"final_status":RealityState.background_save_status()},"\t"))
