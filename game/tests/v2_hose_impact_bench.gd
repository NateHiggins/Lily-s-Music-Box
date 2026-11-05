extends "res://tests/v2_hose_production_hand_bench.gd"
## INERT authored diagnostic only: no production impact or wetting implementation.
## Reuses production factory/extraction and existing actual water-control programme.
var _impact_actor: Node3D
var _observing:=false
var _capture_pending:=false
var _stage_index: int=-1
var _stage_elapsed:=0.
var _sample_elapsed:=0.
var _fixtures: Array[StaticBody3D]=[]
var _records: Array[Dictionary]=[]
var _phase_frames: Array[Dictionary]=[]
var _query_count:=0
var _inside_query_count:=0
var _stages: Array[String]=["baseline_no_impact","wall","floor","near_occluder","empty_fixture_space"]
const SEGMENTS: int=32

func _run() -> void:
	set_physics_process(false)
	await super._run()
	_observing=false;set_physics_process(false)
	_clear_impact_fixtures()
	check(_phase_frames.size()==_stages.size(),"all bounded observational impact phases completed during actual positive flow")
	var output: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var file:=FileAccess.open(output.path_join("hose_impact_geometry.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"evidence_class":"INERT","kind":"hose_ballistic_impact_diagnostic","records":_records,"frames":_phase_frames,"total_queries":_query_count,"total_inside_aware_queries":_inside_query_count,"complete_phase_count":_phase_frames.size(),"authored_phases":_stages,"failures":failures,
			"scope":"Production factory in isolated fixture; inherited repaired-line precondition, camera physics/collision disabled. Actual extraction/valve/lever input; observational ballistic rays and owned temporary blockers only. No implemented impact/wetting, installed-world, performance, save or artistic acceptance.",
			"moving_nozzle_under_stable_spray":{"executed":false,"reason":"Original water programme holds a fixed inspection owner during stable spray; do not inject competing carry input. Next bounded probe must return through actual inspection handoff, reacquire actual nozzle and move via captured mouse with measured holder follow."}},"\t"));file.close()
	get_tree().quit(0 if failures.is_empty() else 1)

func check(ok: bool,label: String) -> bool:
	var accepted: bool=super.check(ok,label)
	if ok and label=="open lever emits water only through the charged nozzle" and not _observing and _stage_index<0:
		for hose: Node in find_children("*","Node3D",true,false):
			if hose.get_script()!=null and hose.get_script().resource_path=="res://scripts/props/fire_unracked_hose.gd" and hose.get("deployed"):
				_impact_actor=hose.actor;break
		if _impact_actor!=null:
			_observing=true;_next_impact_stage();set_physics_process(true)
	return accepted

func cursor_to(pixel: Vector2) -> bool:
	# Same established detached-SubViewport route: event-owned pointer, production
	# ray/part selection. Never warp Lily's OS pointer or inject a chosen target.
	var viewport:=get_viewport()
	if not viewport is SubViewport:return false
	pixel=pixel.round()
	var motion:=InputEventMouseMotion.new();motion.position=pixel;motion.global_position=pixel
	viewport.push_input(motion,true)
	await get_tree().process_frame
	return viewport.get_mouse_position().distance_to(pixel)<.6

func _release_support_checks(_actor: Node3D,_hose: Node3D,_directory: String) -> void:
	pass # Existing release proof is separate; do not repeat its fixture here.

func _case_gallery(_actor: Node3D,_hose: Node3D,_directory: String) -> void:
	pass # No pressure/receiver staging after the actual water input.

func _physics_process(delta: float) -> void:
	if not _observing or _capture_pending:return
	if not is_instance_valid(_impact_actor):_observing=false;set_physics_process(false);return
	_stage_elapsed+=delta;_sample_elapsed+=delta
	var hose: Node3D=_impact_actor._live_hose
	if hose.water.spray<=.001:
		check(false,"flow remains positive through bounded impact observations")
		_observing=false;set_physics_process(false);return
	if _sample_elapsed>=.1:
		_sample_elapsed=0.
		_records.append(_observe_paths(_stages[_stage_index]))
	if _stage_elapsed>=.25:
		_capture_pending=true
		_capture_impact_stage()

func _muzzle() -> Vector3:return _impact_actor._play_pipe.to_global(Vector3(0,.171,0))

func _trajectory(origin: Vector3,axis: Vector3,speed: float,gravity: Vector3,time: float) -> Vector3:
	return origin+axis*speed*time+gravity*(.5*time*time)

func _observe_paths(phase: String) -> Dictionary:
	var hose: Node3D=_impact_actor._live_hose
	var emitter: GPUParticles3D=hose._spray
	var process: ParticleProcessMaterial=emitter.process_material
	var origin: Vector3=_muzzle()
	var axis: Vector3=emitter.global_basis*process.direction.normalized()
	axis=axis.normalized()
	var started: int=Time.get_ticks_usec()
	var paths: Array[Dictionary]=[]
	for speed: float in [process.initial_velocity_min,(process.initial_velocity_min+process.initial_velocity_max)*.5,process.initial_velocity_max]:
		var points: Array[String]=[var_to_str(origin)]
		var first: Dictionary={}
		var previous: Vector3=origin
		for index in range(1,SEGMENTS+1):
			var time: float=emitter.lifetime*float(index)/SEGMENTS
			var point: Vector3=_trajectory(origin,axis,speed,process.gravity,time)
			# No exclusions: retain the first actual solid, including self stock.
			var query:=PhysicsRayQueryParameters3D.create(previous,point,1)
			var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
			_query_count+=1;points.append(var_to_str(point))
			if not hit.is_empty():
				var collider: Node=hit.get("collider") as Node
				first={"path":str(collider.get_path()) if collider!=null else "","position":var_to_str(hit.get("position")),"normal":var_to_str(hit.get("normal")),"segment":index,"segment_end_time":time,"is_owned_fixture":collider in _fixtures}
				break
			previous=point
		paths.append({"speed_mps":speed,"points":points,"first_hit":first})
	var original_query_usec: int=Time.get_ticks_usec()-started
	var inside_aware: Dictionary=_observe_inside_paths(origin,axis,process,emitter.lifetime)
	return {"phase":phase,"muzzle":var_to_str(origin),"emitter_origin":var_to_str(emitter.global_position),"axis_world":var_to_str(axis),"native_nozzle_y_world":var_to_str(_impact_actor._play_pipe.global_basis.y.normalized()),"gravity":var_to_str(process.gravity),"lifetime_s":emitter.lifetime,"spread_deg":process.spread,"segments_max_per_path":SEGMENTS,"paths":paths,"diagnostic_query_usec":original_query_usec,"inside_aware_companion":inside_aware,"spray":hose.water.spray,"water":hose.water.snapshot(),"lever":_impact_actor._lever_angle,"supply":_impact_actor.hose_supply_opening(),"emitting":emitter.emitting,"stable_fluid_callback_stopped":not hose.is_physics_processing(),"hand_active":player._grab.active(),"inspection":player.inspecting(),"paused":get_tree().paused}

func _next_impact_stage() -> void:
	_clear_impact_fixtures();_stage_index+=1;_stage_elapsed=0.;_sample_elapsed=0.
	if _stage_index>=_stages.size():_observing=false;set_physics_process(false);return
	var emitter: GPUParticles3D=_impact_actor._live_hose._spray
	var process: ParticleProcessMaterial=emitter.process_material
	var origin: Vector3=_muzzle()
	var axis: Vector3=(emitter.global_basis*process.direction.normalized()).normalized()
	var speed: float=(process.initial_velocity_min+process.initial_velocity_max)*.5
	var up: Vector3=Vector3.UP if absf(axis.dot(Vector3.UP))<.95 else Vector3.RIGHT
	var wall_basis:=Basis.looking_at(axis,up)
	match _stages[_stage_index]:
		"wall":_add_impact_box("ImpactWall",_trajectory(origin,axis,speed,process.gravity,.15),wall_basis,Vector3(1.6,1.6,.04))
		"floor":_add_impact_box("ImpactFloor",_trajectory(origin,axis,speed,process.gravity,.50),Basis.IDENTITY,Vector3(1.6,.04,1.6))
		"near_occluder":
			_add_impact_box("FarReceiver",_trajectory(origin,axis,speed,process.gravity,.20),wall_basis,Vector3(1.6,1.6,.04))
			_add_impact_box("NearOccluder",_trajectory(origin,axis,speed,process.gravity,.08),wall_basis,Vector3(1.6,1.6,.04))
	# Baseline/empty remove ONLY this fixture's boxes. Native solids remain.

func _add_impact_box(label: String,at: Vector3,axes: Basis,size: Vector3) -> void:
	var body:=StaticBody3D.new();body.name=label;add_child(body)
	body.global_transform=Transform3D(axes,at)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
	var draw:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;draw.mesh=mesh
	# Diagnostic witness stock only; use an existing UV/PBR catalogue finish.
	draw.material_override=MatLib.get_mat("linen").duplicate();body.add_child(draw)
	_fixtures.append(body)

func _clear_impact_fixtures() -> void:
	for body: StaticBody3D in _fixtures:
		if is_instance_valid(body):body.free()
	_fixtures.clear()

func _capture_impact_stage() -> void:
	await RenderingServer.frame_post_draw
	var phase: String=_stages[_stage_index]
	var output: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var filename: String=phase+".png"
	var saved: Error=get_viewport().get_texture().get_image().save_png(output.path_join(filename))
	check(saved==OK,"observational impact frame saved: "+phase)
	if not _records.is_empty() and _records[-1].phase==phase:
		var nominal: Dictionary=_records[-1].paths[1].first_hit
		var wanted: String={"wall":"ImpactWall","floor":"ImpactFloor","near_occluder":"NearOccluder","empty_fixture_space":""}.get(phase,"unasserted_baseline")
		if wanted!="unasserted_baseline":
			var path: String=nominal.get("path","")
			check(path.is_empty() if wanted.is_empty() else path.get_file()==wanted,"nominal ballistic first solid matches owned "+phase+" control; retained original hit="+path)
	_phase_frames.append({"phase":phase,"file":filename,"visible_rect":var_to_str(get_viewport().get_visible_rect()),"camera":var_to_str(player.camera.global_transform),"note":"Original player camera retained; blocker may be outside framing. This is baseline observation, not splash/wetting implementation."})
	_capture_pending=false
	_next_impact_stage()

# Companion only: the original rays, paths and phase assertions above remain
# authoritative. Uses the proposed wetting owner's flags, not its state/methods.
func _observe_inside_paths(origin: Vector3,axis: Vector3,process: ParticleProcessMaterial,lifetime: float) -> Dictionary:
	var started: int=Time.get_ticks_usec()
	var count:=0
	var paths: Array[Dictionary]=[]
	for speed: float in [process.initial_velocity_min,(process.initial_velocity_min+process.initial_velocity_max)*.5,process.initial_velocity_max]:
		var previous: Vector3=origin
		var points: Array[String]=[var_to_str(origin)]
		var first: Dictionary={}
		var first_segment_started_inside:=false
		for index in range(1,SEGMENTS+1):
			var time: float=lifetime*float(index)/SEGMENTS
			var point: Vector3=_trajectory(origin,axis,speed,process.gravity,time)
			var query:=PhysicsRayQueryParameters3D.create(previous,point,1)
			query.collide_with_bodies=true;query.collide_with_areas=false
			query.hit_from_inside=true;query.hit_back_faces=true
			# No exclusions, collider injection or skipped first hit.
			var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
			count+=1;_inside_query_count+=1;points.append(var_to_str(point))
			if not hit.is_empty():
				var collider: Node=hit.get("collider") as Node
				var normal: Vector3=hit.get("normal",Vector3.INF)
				# Exact zero is the documented inside-hit sentinel, not a grazing
				# threshold. Concave/heightmap origin containment is not reported.
				var segment_started_inside: bool=normal==Vector3.ZERO
				first_segment_started_inside=index==1 and segment_started_inside
				first={"path":str(collider.get_path()) if collider!=null else "","instance_id":collider.get_instance_id() if collider!=null else 0,"rid":str(hit.get("rid",RID())),"shape":hit.get("shape",-1),"face_index":hit.get("face_index",-1),"position":var_to_str(hit.get("position")),"normal":var_to_str(normal),"segment":index,"segment_from":var_to_str(previous),"segment_to":var_to_str(point),"segment_end_time":time,"hit_segment_started_inside":segment_started_inside,"is_owned_fixture":collider in _fixtures}
				break
			previous=point
		paths.append({"speed_mps":speed,"points":points,"first_hit":first,"first_segment_started_inside":first_segment_started_inside})
	return {"paths":paths,"query_count":count,"query_usec":Time.get_ticks_usec()-started,"collision_mask":1,"collide_with_bodies":true,"collide_with_areas":false,"hit_from_inside":true,"hit_back_faces":true,"exclusions":[],"inside_classification":"API-reported exact zero normal; false is no reported inside-origin hit, not universal point containment (concave/heightmap unsupported).","scope":"Independent observational first-solid centreline traces, not GPU collision, wetting, splash, performance or a nozzle-origin defect finding."}
