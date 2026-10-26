extends Node
const Route=preload("res://scripts/dream/critters/guide_bell_route.gd")
const ErrorCapture=preload("res://tests/guide_bell_error_capture.gd")
var checks: Array[Dictionary]=[]
var failures: Array[String]=[]
var diagnostics: Array[Dictionary]=[]
var directory: String
var started:=Time.get_ticks_msec()
var world: OrisonV2RuntimeRoot
var logger
func _ready() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label})
	if not ok: failures.append(label)
	print("GUIDE WORLD: ",label," = ",ok)
func _run() -> void:
	logger=ErrorCapture.new(); OS.add_logger(logger)
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory="user://guide_bell_world"
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false; RealityState.reset_campaign_for_tests(); RealityCases._ready()
	CampaignTime.set_frozen_for_tests(true)
	RealityState.data.intro_complete=true; RealityState.data.first_shift={"phase":FirstShiftDirector.PHASE_COMPLETE}
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var selector=preload("res://scripts/building/building_root_selector.gd"); selector.reset_for_tests("v2")
	world=(load(selector.scene_path()) as PackedScene).instantiate(); add_child(world)
	for frame in 5: await get_tree().physics_frame
	check(not world.startup_failed,"production V2 starts")
	var director:=world.get_node_or_null("MaintenanceGuideBells")
	check(director!=null,"production installs guide-bell adapter")
	if director==null or world.startup_failed: _finish({}); return
	director.set_physics_process(false)
	var player:=world.player; player.set_physics_process(false); player.call_locked=false; player.mouse_released=false
	player.camera.make_current(); Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var stair_checked:=false
	for stair: Dictionary in world.layout.stairs:
		if str(stair.from)!="F01" or str(stair.to)!="F02" or not str(stair.id).begins_with("PRIMARY"): continue
		var points: Array[Vector3]=Route.stair_points(world.adapter.root,stair)
		var start: Vector3=world.adapter.root.to_global(points[0])+Vector3.UP*.035
		var end: Vector3=world.adapter.root.to_global(points[-1])+Vector3.UP*.035
		var stair_path: PackedVector3Array=director.provider.request(start,end)
		var legs: Array=[]
		if stair_path.size()<4:
			# Name each authored leg's rejection and blocker in the composed world.
			for i in range(points.size()-1):
				var from_point: Vector3=world.adapter.root.to_global(points[i])+Vector3.UP*.035
				var to_point: Vector3=world.adapter.root.to_global(points[i+1])+Vector3.UP*.035
				var okay: bool=director.provider.supported(from_point,to_point)
				legs.append({"leg":i,"local_from":points[i],"local_to":points[i+1],"ok":okay,"failure":director.provider.last_rejection.duplicate()})
			print("GUIDE WORLD STAIR LEGS ",JSON.stringify(legs))
		check(stair_path.size()>=4,"installed primary stair supplies a physically supported inter-floor route")
		diagnostics.append({"stair":stair.id,"points":stair_path,"length":Route.length(stair_path),"legs":legs})
		stair_checked=true; break
	check(stair_checked,"authored primary stair transition inspected")
	check(director.active_task().is_empty(),"no active task yields no assistance")
	RealityState.data.maintenance_jobs={"vantry_chirp_2a":{"stage":"acknowledged"}}
	check(director.active_task().is_empty(),"discovery-by-ear task remains unassisted")
	RealityState.data.maintenance_jobs={"lena_radiator_round_2b":{"stage":"repairable"}}
	check(director.active_task()=="lena_radiator_round_2b","single authored eligible task observed")
	var target:=world.find_child(ServiceRoundDirector.RADIATOR_ID,true,false) as Node3D
	check(target!=null,"maintenance physical target loaded")
	if target==null: _finish({}); return
	var focus: Vector3=target.inspection_view().at
	for offset in [Vector3(.8,0,0),Vector3(-.8,0,0),Vector3(0,0,.8),Vector3(0,0,-.8)]:
		var ground: Dictionary=director.provider.ray(focus+offset+Vector3.UP*.4,focus+offset-Vector3.UP*2.5)
		var diagnostic: Dictionary={"focus":focus,"offset":offset,"ground":not ground.is_empty()}
		if not ground.is_empty():
			var candidate: Vector3=ground.position+Vector3.UP*.035
			var sight: Dictionary=director.provider.ray(candidate+Vector3.UP*.8,focus)
			diagnostic.merge({"candidate":candidate,"support":director.provider.supported(candidate,candidate),"ground_owner":str(ground.collider.get_path()),"sight_owner":"" if sight.is_empty() else str(sight.collider.get_path())})
		diagnostics.append(diagnostic)
	director.task_id="lena_radiator_round_2b"; director.target=target
	# Initial-placement fixtures are explicitly not a claim of played movement.
	# Search existing authored graph stances on this floor, nearest usable first.
	var candidates: Array[Vector3]=[]
	for id in director.provider.graph.get_point_ids():
		var at: Vector3=director.provider.graph.get_point_position(id)
		if absf(at.y-(target.global_position.y-(target as RadiatorProp).installation_drop))<.2 and at.distance_to(target.global_position)<14: candidates.append(at)
	candidates.sort_custom(func(a,b): return a.distance_to(target.global_position)<b.distance_to(target.global_position))
	var attempts:=0
	for at in candidates:
		player.global_position=at; await get_tree().physics_frame
		director._rebuild(); attempts+=1
		diagnostics.append({"stance":at,"supported":director.provider.supported(at,at),"route_length":Route.length(director.path),"bells":director.bells.size()})
		if director.bells.size()>0: break
		if attempts>=80: break
	check(director.bells.size()>0,"installed loaded architecture supports a visible maintenance trail")
	if director.bells.is_empty(): _finish(director.census()); return
	var state_before:=JSON.stringify(world.work_orders.job_state("lena_radiator_round_2b"))
	var original_positions: Array[Vector3]=[]
	var previous:=INF
	for bell in director.bells:
		check(bell.remaining_to_target_m<previous,"strict monotonic route remaining distance")
		previous=bell.remaining_to_target_m; original_positions.append(bell.global_position)
		check(bell.surface.get_ref() is StaticBody3D,"real static attachment owner")
		check(bell.global_position.distance_to(target.global_position)>.5,"repair control kept clear")
	check(director.bells.size()<=8,"trail bounded at eight cells")
	var first: Node3D=director.bells[0]
	player.camera.look_at(first.global_position+Vector3.UP*.35); player.set_lamp_enabled(true)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("01_installed_approach.png"))
	var full: PackedVector3Array=director.path.duplicate()
	for i in range(full.size()-1): check(director.provider.supported(full[i],full[i+1]),"route leg remains collision and support valid")
	var trace: Dictionary=director.census()
	# Progress uses the published route; move the observation fixture along its
	# actual polyline, recording that this is not player-controller travel proof.
	for i in range(1,full.size()):
		player.global_position=full[i]
		director._physics_process(.1)
		await get_tree().create_timer(.5).timeout
		director._physics_process(.1)
	check(JSON.stringify(world.work_orders.job_state("lena_radiator_round_2b"))==state_before,"presentation leaves task authority byte-identical")
	var count: int=director.bells.size()
	RealityState.data.maintenance_jobs={}
	director._physics_process(.1)
	check(director.bells.is_empty() and director.path.is_empty(),"cancellation removes trail and route references")
	trace["after_cancel"]=director.census(); trace["cells_before_cancel"]=count
	_finish(trace)
func _finish(trace: Dictionary) -> void:
	if world!=null: world.shutdown_for_tests(); world.free()
	await get_tree().process_frame
	check(logger.errors.is_empty(),"no engine/script/shader errors in composed world")
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Installed route-query and placement observation fixtures; position fixtures are not played traversal or manipulation proof",
		"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/tests/guide_bell_world_contract.gd","test_sha256":get_script().source_code.replace("\r\n","\n").sha256_text()},
		"contracts":{"installed_guide_bells":{"executed":true,"status":"PASS" if failures.is_empty() else "FAIL"}},
		"checks":checks,"failures":failures,"engine_errors":logger.errors,"trail":trace,"diagnostics":diagnostics}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	OS.remove_logger(logger); get_tree().quit(0 if failures.is_empty() else 1)
