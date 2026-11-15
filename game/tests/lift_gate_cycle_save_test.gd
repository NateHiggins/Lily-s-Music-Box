extends Node3D
## Real installed cycle and isolated disk reconstruction; not an NPC ride.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const Route := preload("res://tests/orison_v2_elevator_route_test.gd")
var world: OrisonV2RuntimeRoot
var driver: Node
var failures: Array[String] = []
var checks := 0
var contracts: Dictionary = {}
var details: Dictionary = {"cycles":[], "interlock_scope":"Current V2 has no registered landing apparatus; checks cover actual moving/remote door refusal and closed departure."}
var output := ""
var started := 0
var logger: Logger
var inputs: Dictionary
var prior: Dictionary
var prior_files: Dictionary
var monitor_cycle := false
var states: Dictionary = {}
var seen_busy: Dictionary = {}
var cycle_trace: Array = []

func _ready() -> void: _run.call_deferred()

func ck(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); print("LIFT CYCLE FAIL: ",label)
	return ok

func _contract(id: String, before: int) -> void:
	contracts[id] = {"executed":true,"status":"PASS" if before==failures.size() else "FAIL"}

func _sources() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime: Array = []; var physical: Array = []; var closure: Array = []
	ck(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime)==0,"runtime source digest")
	ck(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical)==0,"physical source digest")
	var code := "import sys,json;from pathlib import Path;sys.path.insert(0,sys.argv[1]+'/tools');from v2_surface_evidence import test_dependency_paths,file_hash;r=Path(sys.argv[1]).resolve();print(json.dumps({p.relative_to(r).as_posix():file_hash(p) for p in test_dependency_paths(r,{r/'game/tests/LiftGateCycleSaveTest.tscn'})},sort_keys=True))"
	ck(OS.execute("python",["-c",code,root],closure)==0,"transitive test source digest")
	return {"runtime_inputs_sha256":str(runtime[0]).strip_edges() if runtime.size() else "", "physical_inputs_sha256":str(physical[0]).strip_edges() if physical.size() else "", "dependencies":JSON.parse_string(str(closure[0])) if closure.size() else {},"test_path":"game/tests/lift_gate_cycle_save_test.gd","test_sha256":FileAccess.get_sha256(get_script().resource_path),"test_scene_path":"game/tests/LiftGateCycleSaveTest.tscn","test_scene_sha256":FileAccess.get_sha256(scene_file_path)}

func _files() -> Dictionary:
	var result := {}
	for suffix: String in ["", ".bak", ".tmp", ".transaction"]:
		var path: String = str(prior.path)+suffix
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"
	return result

func _world() -> bool:
	world = Runtime.instantiate(); add_child(world)
	await get_tree().physics_frame; await get_tree().physics_frame
	return ck(not world.startup_failed and world.player!=null and world.elevator!=null,"actual production world starts")

func _native() -> Dictionary:
	var lift := world.elevator
	var gate := lift._gate.get_node_or_null("ArticulatedGate")
	if not ck(gate!=null,"native gate installed"): return {}
	var rows := {}; var count := 0
	for key: String in gate.COUNTS:
		var node: MultiMeshInstance3D = gate.batches.get(key)
		if not ck(node!=null and node.multimesh!=null and node.multimesh.instance_count==int(gate.COUNTS[key]),"native variant count "+key): continue
		count += node.multimesh.instance_count
		var transforms := []
		for i in node.multimesh.instance_count: transforms.append(node.multimesh.get_instance_transform(i))
		rows[key] = transforms
	ck(rows.size()==16 and count==120,"all16 variants and120 rigid instances reconstructed")
	var contact := lift._cabin.get_node_or_null("NativeGateThreshold") as CollisionShape3D
	ck(contact!=null and contact.shape is ConcavePolygonShape3D and not contact.disabled,"exact native lower stock contact retained")
	ck(is_equal_approx(lift.test_travel_scale,1.0),"ordinary unscaled lift speed")
	return {"rows":rows,"contact_faces":contact.shape.get_faces() if contact!=null else [],"span":lift._gate.scale.x,"current":lift.current,"fraction":lift.landing_door_open_fraction(lift.current)}

func _run() -> void:
	output=OS.get_environment("SHOT_DIR")
	var profile := OS.get_environment("LIFT_CYCLE_ISOLATED_APPDATA").replace("\\","/").simplify_path()
	if not profile.begins_with("C:/ov/reports/lift_gate_intake_20261115/cycle_") or OS.get_user_data_dir().replace("\\","/").simplify_path()!=profile.path_join("PleaseRemainOnTheLine") or output.is_empty() or FileAccess.file_exists(output.path_join("runtime_contract.json")) or DisplayServer.get_name()=="headless":
		push_error("Lift cycle needs fresh private output and process-start isolated APPDATA");get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(output);started=Time.get_ticks_msec()
	logger=preload("res://tests/guide_bell_error_capture.gd").new();OS.add_logger(logger)
	prior={"data":RealityState.data,"text":JSON.stringify(RealityState.data),"path":RealityState.save_path,"persistent":RealityState.persistence_enabled,"mouse":Input.mouse_mode,"mode":GameBoot.launch_mode,"frozen":CampaignTime._frozen_for_tests}
	prior_files=_files();inputs=_sources()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	RealityState.save_path="user://lift_cycle_qualification.json"
	ck(not FileAccess.file_exists(RealityState.save_path),"fresh dedicated save destination")
	CampaignTime.set_frozen_for_tests(true);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	ck(CampaignClock.new().configure_date(1929,6,14,21*60),"actual seeded campaign clock")
	if not failures.is_empty() or not await _world(): await _finish();return
	var original_native := _native()
	var before := failures.size()
	driver=Route.new();driver.externally_managed=true;driver.world=world;driver.player=world.player;add_child(driver)
	# One declared initial in-cabin stance; input selects both destinations.
	world.player.global_position=world.elevator._cabin.to_global(Vector3(0,.14,0))
	world.player.velocity=Vector3.ZERO;world.player.mouse_released=false;world.player.call_locked=false
	world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in 12: await get_tree().physics_frame
	for destination: String in ["F02","F01"]:
		if not await _ride(destination): break
	ck(driver.failures.is_empty(),"existing actual input driver has no failures")
	_contract("live_cycle_and_refusals",before)
	driver.free();driver=null
	before=failures.size()
	# Save away from home; the existing save owner must not replay a dispatch.
	ck(world.elevator.npc_request("F02"),"ordinary owner accepts final park call; not NPC access proof")
	var deadline:=Time.get_ticks_msec()+30000
	while world.elevator.moving and Time.get_ticks_msec()<deadline: await get_tree().physics_frame
	ck(world.elevator.is_ready_at("F02"),"actual owner parks at nondefault landing before save")
	ck(RealityState.save_game(),"actual RealityState writes validated disk snapshot")
	ck(FileAccess.file_exists(RealityState.save_path),"actual save file exists")
	details.saved_sha256=FileAccess.get_sha256(RealityState.save_path)
	world.shutdown_for_tests();world.free();world=null
	await get_tree().process_frame
	RealityState.load_game()
	ck(str(RealityState.load_status().status)=="loaded" and not RealityState.save_write_blocked,"real disk loader accepts snapshot")
	if await _world():
		await get_tree().process_frame;await get_tree().process_frame
		var rebuilt := _native()
		ck(rebuilt==original_native,"native variants, transforms, lower contact and home-open pose match fresh original")
		ck(world.elevator.current=="F01" and not world.elevator.moving and world.elevator.state==OrisonElevator.S.IDLE,"disk reconstruction never replays nondefault parked dispatch")
	_contract("disk_native_reconstruction",before)
	if failures.is_empty():
		var probe:=preload("res://tests/lift_gate_cost_probe.gd").new();add_child(probe)
		details.cost=await probe.run(world,ck);probe.free()
	await _finish()

func _ride(destination: String) -> bool:
	var lift:=world.elevator
	var button: Area3D
	for child: Node in lift._cabin.get_children():
		if child is Area3D and str(child.get_meta("cabin_floor",""))==destination:button=child
	if not ck(button!=null,"actual cabin destination control "+destination): return false
	states={};seen_busy={};cycle_trace=[];monitor_cycle=true
	var accepted: bool=await driver._use(button,button.global_position,"cycle_"+destination)
	if not ck(accepted,"mapped input selects "+destination):monitor_cycle=false;return false
	var deadline:=Time.get_ticks_msec()+30000
	while lift.moving and Time.get_ticks_msec()<deadline:await get_tree().physics_frame
	monitor_cycle=false
	ck(lift.is_ready_at(destination),"ordinary closing/travel/opening completes "+destination)
	for state: int in [OrisonElevator.S.CLOSING,OrisonElevator.S.MOVING,OrisonElevator.S.OPENING]:ck(states.has(state),"actual cycle observes state "+str(state))
	ck(not cycle_trace.is_empty(),"actual cycle trace recorded")
	var feet: Vector3=lift._cabin.to_local(world.player.global_position)
	ck(absf(feet.y-.132)<.08 and absf(feet.x)<.5 and absf(feet.z)<.7 and world.player.is_on_floor() and not world.player.noclip,"ordinary platform carries grounded capsule")
	details.cycles.append({"destination":destination,"states":states,"trace":cycle_trace.duplicate(),"feet":feet})
	return failures.is_empty()

func _physics_process(_delta: float) -> void:
	if not monitor_cycle or not is_instance_valid(world):return
	var lift:=world.elevator;var state:int=lift.state
	if state==OrisonElevator.S.IDLE:return
	states[state]=true
	if not seen_busy.has(state):
		seen_busy[state]=true
		var pending:String=lift._pending
		ck(not lift.npc_request("B1"),"busy autonomous request refused in state "+str(state))
		lift.travel_to("B1")
		ck(lift._pending==pending,"busy request never reverses or replaces active destination")
		ck(not lift.set_landing_door_for_service(lift.current,1.0),"moving owner refuses service-door override")
		cycle_trace.append({"state":state,"pending":pending,"y":lift._cabin.position.y,"fraction":lift.landing_door_open_fraction(lift.current)})
	if state==OrisonElevator.S.MOVING:
		if lift.landing_door_open_fraction(lift.current)>.00001:
			ck(false,"departure landing must be closed throughout vertical travel");monitor_cycle=false

func _finish() -> void:
	monitor_cycle=false;Input.action_release("interact");Input.action_release("move_forward")
	var before:=failures.size()
	if is_instance_valid(driver):driver.free()
	if is_instance_valid(world):world.shutdown_for_tests();world.free();world=null
	await get_tree().process_frame
	RealityState.flush_background_saves();RealityState.persistence_enabled=false
	RealityState.data=prior.data;RealityState.save_path=prior.path
	RealityState.persistence_enabled=prior.persistent
	GameBoot.launch_mode=prior.mode;CampaignTime.set_frozen_for_tests(prior.frozen);Input.mouse_mode=prior.mouse
	ck(is_same(RealityState.data,prior.data) and JSON.stringify(RealityState.data)==prior.text,"original campaign identity/content restored")
	ck(_files()==prior_files,"original default save/backup/transaction files unchanged")
	ck(_sources()==inputs,"all runtime/physical/transitive test sources unchanged")
	var errors:Array=logger.errors.duplicate();OS.remove_logger(logger)
	ck(errors.is_empty(),"engine errors empty")
	_contract("custody_cleanup",before)
	contracts.npc_passenger={"executed":false,"status":"NOT_RUN","reason":"No current V2 NPC elevator consumer"}
	contracts.live_reversal={"executed":false,"status":"NOT_RUN","reason":"Existing public owner refuses busy requests; no reversal operation"}
	contracts.registered_apparatus_interlock={"executed":false,"status":"NOT_RUN","reason":"No installed V2 landing apparatus"}
	var passed:=failures.is_empty()
	var result:Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":true,"selector":"v2","suite":"LiftGateCycleSaveTest","status":"PASS" if passed else "FAIL","scope":"One initial cabin stance, real-input F01-F02-F01 platform rides and state/refusal checks; actual isolated disk save/world retirement/rebuild; same-world diagnostic render comparison. No NPC access, reversal, full seven-stop route or artistic acceptance.","execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},"source":inputs,"contracts":contracts,"checks":checks,"failures":failures,"engine_errors":errors,"details":details}
	var file:=FileAccess.open(output.path_join("runtime_contract.json"),FileAccess.WRITE)
	if file==null:get_tree().quit(2);return
	file.store_string(JSON.stringify(result,"\t"));file.flush();get_tree().quit(0 if passed and file.get_error()==OK else 1)
