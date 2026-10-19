extends "res://tests/v2_spatial_access_cohort.gd"
## Original eight-level circulation proof; no mechanism/save/human grant.
const Driver := preload("res://tests/v2_service_circulation_driver.gd")
var connection_claims: Dictionary={}
var threshold_diagnostics: Array[Dictionary]=[]

func _run() -> void:
	groups=PackedStringArray(["service_circulation"])
	initial_inputs=_inputs();bindings=_dependencies()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	_check(CampaignClock.new().configure_date(1928,10,15,20*60),"valid campaign fixture")
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC;Selector.reset_for_tests("v2")
	var world := (load(Selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world);await get_tree().physics_frame;await get_tree().physics_frame
	_check(not world.startup_failed,"production-selected V2 composition starts")
	var driver: Node=Driver.new()
	driver.externally_managed=true;driver.world=world;driver.player=world.player
	var held: Array[WeakRef]=[weakref(world),weakref(driver)]
	var completed: Array[String]=[]
	if failures==0:
		add_child(driver);world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		driver._prepare_player_start();await get_tree().physics_frame
		await driver._route()
		threshold_diagnostics=driver.threshold_preflight.duplicate(true)
		for row: Dictionary in driver.interaction_checks:_check(row.ok,row.label)
		_check(driver.failures.is_empty() and not driver.trace.is_empty(),"complete basement-to-roof-and-back collision-bearing leg")
		legs.append({"name":"service_circulation","group":"service_circulation","trace":driver.trace.duplicate(true),"failures":driver.failures.duplicate(),"initial_placement_only":true})
		for room: Dictionary in world.layout.spaces:
			var identity:=str(room.id);var floor:=str(room.level)
			if identity not in [floor+"_SERVICE_CORE",floor+"_SERVICE_HALL",floor+"_SERVICE_HALL_SOUTH",floor+"_SERVICE_CROSSING",floor+"_SERVICE_RISER_BYPASS",floor+"_CORE_TO_SERVICE"]:continue
			expected[identity]=true
			var rect: Array=room.rect;var y:=float(world.adapter.root.level_y[floor])
			for step: Dictionary in driver.trace:
				var p: Array=step.actual
				if step.ok and absf(float(p[1])-y)<.15 and p[0]>rect[0]+.05 and p[0]<rect[2]-.05 and p[2]>rect[1]+.05 and p[2]<rect[3]-.05:
					visited[identity]={"actual":p,"leg":"service_circulation"}
		for identity: String in expected:_check(visited.has(identity),"ordinary movement reaches authored service room: "+identity)
		_check(driver.crossings.size()==6,"six actual direct hall/core crossings")
		for crossing: Dictionary in driver.crossings:
			var claim: Dictionary=crossing.duplicate(true)
			claim["leg"]="service_circulation"
			claim["before"]=driver.trace[int(crossing.before_index)].actual
			claim["after"]=driver.trace[int(crossing.after_index)].actual
			connection_claims[str(crossing.id)]=claim
		if failures==0:completed.append("service_circulation")
	driver.free();Input.action_release("move_forward")
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	var retained:=0
	for reference: WeakRef in held:
		if reference.get_ref()!=null:retained+=1
	_check(retained==0,"root and service driver retire")
	var final_inputs:=_inputs()
	_check(initial_inputs==final_inputs,"production and physical inputs stay fixed")
	_check(bindings==_dependencies(),"entry scene and all inherited movement/hand sources stay fixed")
	_write_receipt(retained,held.size(),completed,final_inputs)
	print("V2 SERVICE CIRCULATION CONTRACT: ","PASS" if failures==0 else "FAIL"," rooms=",visited.size()," connections=",connection_claims.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func _write_receipt(retained: int,tracked: int,completed_groups: Array[String],inputs: Dictionary) -> void:
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[]
	_check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository provenance")
	var directory:=OS.get_environment("SHOT_DIR")
	_check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"explicit writable receipt destination")
	var file:=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	_check(file!=null,"open original service circulation contract")
	if file==null:return
	var status: String="PASS" if failures==0 else "FAIL"
	var entry: String="game/"+get_script().resource_path.trim_prefix("res://")
	var data: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"One declared basement placement, all seven service stairs up to the roof and back, both ends of each occupied service hall and six actual direct hall/core thresholds. Only live controller movement after placement; real grab/motion/release on controlled leaves. Room access and recorded edge traversal only; no lift operation, case, save, acoustic, photoreal or human acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":entry,"test_sha256":bindings.get(entry,""),"test_dependencies":bindings,"scene_path":scene_file_path,"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":inputs.runtime,"surface_inputs_sha256":inputs.surface},
		"groups":groups,"completed_groups":completed_groups,"legs":legs,"checks":checks,"failures":failures,
		"diagnostics":{"scope":"INERT remote threshold physics queries; these do not replace played movement or grant acceptance","threshold_stances":threshold_diagnostics},
		"contracts":{"production_composition":{"executed":true,"status":status},"room_access":{"executed":completed_groups.size()==1,"status":status,"rooms":visited},"room_connections":{"executed":completed_groups.size()==1,"status":status,"connections":connection_claims},"teardown":{"executed":true,"status":status,"measurement_scope":"production root and service route driver only","tracked_nodes":tracked,"retained_nodes":retained}}}
	file.store_string(JSON.stringify(data,"\t"));file.flush()
	if file.get_error()!=OK:failures+=1;push_error("Service circulation contract did not flush")
