extends Node3D
## Focused actual-input threshold diagnostic; other obligations remain NOT_RUN.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Walker := preload("res://tests/orison_v2_first_slice_contract_test.gd")
var world: OrisonV2RuntimeRoot
var walk
var failures: Array[String]=[]
var checks := 0
var samples: Array=[]
var leg := ""
var rail_top := -INF
var rail_z := 0.0
var prior_data: Dictionary
var prior_hash := ""
var prior_mode: int
var prior_mouse: int
var prior_frozen: bool
var preview := false
var logger
var inputs: Dictionary={}
var directory := ""
var started := 0
var extra_results: Dictionary={}
var passenger_executed := false

func ck(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:failures.append(label)
	return ok
func _ready() -> void: run.call_deferred()
func source_inputs() -> Dictionary:
	var root:=ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/").get_base_dir()
	var runtime: Array=[];var physical: Array=[];var head: Array=[]
	ck(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime)==0,"runtime digest")
	ck(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical)==0,"physical digest")
	ck(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"head binding")
	var dependencies: Dictionary={}
	for path: String in ["res://tests/orison_v2_first_slice_contract_test.gd","res://tests/guide_bell_error_capture.gd","res://tests/orison_v2_lift_gate_test.gd"]:
		ck(FileAccess.file_exists(path),"dependency exists "+path);dependencies[path]=FileAccess.get_sha256(path)
	return {"dependencies":dependencies,"test_path":"game/"+get_script().resource_path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"test_scene_path":"game/"+scene_file_path.trim_prefix("res://"),"test_scene_sha256":FileAccess.get_sha256(scene_file_path),"repository_head":str(head[0]).strip_edges() if head.size() else "","runtime_inputs_sha256":str(runtime[0]).strip_edges() if runtime.size() else "","physical_inputs_sha256":str(physical[0]).strip_edges() if physical.size() else ""}
func run() -> void:
	var profile:=OS.get_environment("LIFT_GATE_ISOLATED_APPDATA").replace("\\","/").simplify_path()
	var actual:=OS.get_user_data_dir().replace("\\","/").simplify_path()
	if not profile.begins_with("C:/ov/reports/lift_gate_intake_20261115/passenger_") or actual!=profile.path_join("PleaseRemainOnTheLine"):
		push_error("Lift gate passenger requires dedicated process-start APPDATA");get_tree().quit(2);return
	if DisplayServer.get_name()=="headless":get_tree().quit(2);return
	started=Time.get_ticks_msec();directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty():get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	prior_data=RealityState.data;prior_hash=JSON.stringify(prior_data).sha256_text();prior_mode=GameBoot.launch_mode;prior_mouse=Input.mouse_mode;prior_frozen=CampaignTime._frozen_for_tests
	logger=preload("res://tests/guide_bell_error_capture.gd").new();OS.add_logger(logger)
	inputs=source_inputs()
	preview=RealityState.begin_preview_campaign(self)
	if not ck(preview,"exclusive nonpersistent preview"):await finish();return
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC;CampaignTime.set_frozen_for_tests(true)
	var clock:=CampaignClock.new()
	if not ck(clock.configure_date(1929,6,14,1260),"actual preview date"):await finish();return
	world=Runtime.instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if not ck(not world.startup_failed and world.player!=null and world.elevator!=null,"actual production owners"):await finish();return
	walk=Walker.new();walk.service_bench_only=true;add_child(walk)
	var lift: OrisonElevator=world.elevator
	if not ck(lift.npc_request("F01"),"owner accepts F01 call"):await finish();return
	var deadline:=Time.get_ticks_msec()+60000
	while not lift.is_ready_at("F01") and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	if not ck(lift.is_ready_at("F01"),"owner opens F01 landing"):await finish();return
	var gate: Node3D=lift._gate.get_node("ArticulatedGate")
	var rails: MultiMeshInstance3D=gate.batches.FixedRailsAndMounts
	# Actual bottom stock only; upper rail cannot masquerade as threshold height.
	var zsum:=0.0;var count:=0
	for face: Vector3 in rails.multimesh.mesh.get_faces():
		var point: Vector3=lift._cabin.to_local(rails.to_global(rails.multimesh.get_instance_transform(0)*face))
		if point.y>.15 and point.y<.30:
			rail_top=maxf(rail_top,point.y);zsum+=point.z;count+=1
	if not ck(count>0 and is_finite(rail_top),"actual lower raised rail vertices measured, excluding footpads"):await finish();return
	ck(absf(rail_top-.194)<.0001,"loaded lower rail top matches reviewed native stock .194m")
	rail_z=zsum/float(count)
	# The sole explicit fixture placement; all threshold traversal follows input.
	world.player.global_position=lift.to_global(Vector3(0,float(lift.stops.F01)+.03,1.85))
	world.player.velocity=Vector3.ZERO;world.player.set_physics_process(true)
	for frame in 12:await get_tree().physics_frame
	passenger_executed=true
	for row: Array in [["in",.15],["out",1.85]]:
		leg=str(row[0])
		var ok: bool=await walk._walk_service_player(world.player,lift,Vector3(0,float(lift.stops.F01),float(row[1])))
		world.player.set_physics_process(true);leg=""
		ck(ok,"actual directional threshold "+str(row[0]))
		if not ok:break
	for direction: String in ["in","out"]:
		var crossing:=0
		for row: Dictionary in samples:
			if row.leg==direction and absf(float(row.cabin_feet.z)-rail_z)<.04:
				crossing+=1
				ck(float(row.cabin_feet.y)>=rail_top-.002,"feet clear visible bottom rail "+direction)
		ck(crossing>0,"actual centre crosses rail plane "+direction)
	ck(lift.is_ready_at("F01"),"lift remains owner-ready through crossing")
	ck(not lift.set_landing_door_for_service("F02",1.0),"remote landing interlock service request refused")
	extra_results=await _extra_checks(world)
	await finish()
func _extra_checks(_world: OrisonV2RuntimeRoot) -> Dictionary:
	await get_tree().process_frame
	return {}

func _physics_process(_delta: float) -> void:
	if leg.is_empty() or world==null:return
	var player: PlayerController=world.player
	samples.append({"leg":leg,"world_feet":player.global_position,"cabin_feet":world.elevator._cabin.to_local(player.global_position),"on_floor":player.is_on_floor(),"mask":player.collision_mask,"noclip":player.noclip,"floor_normal":player.get_floor_normal(),"t":Time.get_ticks_usec()})
func finish() -> void:
	Input.action_release("move_forward");leg=""
	var travel: Array=[]
	if is_instance_valid(walk):travel=walk.service_travel.duplicate(true);failures.append_array(walk.failures);walk.free()
	if is_instance_valid(world):world.shutdown_for_tests();world.free();world=null
	await get_tree().process_frame
	if preview:ck(RealityState.end_preview_campaign(self) and is_same(RealityState.data,prior_data),"original campaign identity restored");preview=false
	ck(JSON.stringify(prior_data).sha256_text()==prior_hash,"original campaign bytes unchanged")
	CampaignTime.set_frozen_for_tests(prior_frozen);GameBoot.launch_mode=prior_mode
	Input.mouse_mode=prior_mouse
	ck(Input.mouse_mode==prior_mouse,"mouse mode restored")
	ck(inputs==source_inputs(),"source custody unchanged")
	var errors: Array=logger.errors.duplicate();OS.remove_logger(logger)
	var passed: bool=failures.is_empty() and errors.is_empty()
	var result: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"source":inputs,"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},"contracts":{"f01_player_threshold":{"executed":passenger_executed,"status":"PASS" if passed else "FAIL"},"npc_passenger":{"executed":false,"status":"NOT_RUN"},"travel_reversal":{"executed":false,"status":"NOT_RUN"},"disk_save":{"executed":false,"status":"NOT_RUN"}},"checks":checks,"scope":"One initial F01 stance; actual input crossing both ways and native rail height test. Preview custody only; no7stop travel,NPC,live reversal,disk save or performance qualification.","foot_convention":"PlayerController _shape.position.y=_capsule.height/2, global_position is physical capsule bottom; no inferred foot offset","extra_checks":extra_results,"rail_top_cabin_m":rail_top,"rail_z_cabin_m":rail_z,"samples":samples,"service_travel":travel,"failures":failures,"engine_errors":errors}
	var file:=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file==null:get_tree().quit(2);return
	file.store_string(JSON.stringify(result,"\t"));file.flush()
	get_tree().quit(0 if passed and file.get_error()==OK else 1)
