extends "res://tests/v2_spatial_access_cohort.gd"
## Original six-region played contract; requires actual production execution.
const Driver=preload("res://tests/v2_region_access_driver.gd")
var region_claims: Dictionary={}
var route_claims: Dictionary={}
var threshold_claims: Dictionary={}

func _run() -> void:
	groups=PackedStringArray(["exterior_regions"])
	initial_inputs=_inputs();bindings=_dependencies()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	_check(CampaignClock.new().configure_date(1928,10,15,12*60+30),"valid daytime campaign fixture")
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC;Selector.reset_for_tests("v2")
	var world: OrisonV2RuntimeRoot=(load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world);await get_tree().physics_frame;await get_tree().physics_frame
	_check(not world.startup_failed,"production-selected V2 composition starts")
	var driver: Node=Driver.new();driver.externally_managed=true;driver.world=world;driver.player=world.player
	var held: Array[WeakRef]=[weakref(world),weakref(driver)]
	var completed: Array[String]=[]
	if failures==0:
		add_child(driver);world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		driver._prepare_player_start();await get_tree().physics_frame
		await driver._route()
		var observer: Node=driver.observer
		_check(observer!=null,"actual post-controller observer exists")
		if observer!=null:
			held.append(weakref(observer));observer.set_physics_process(false)
			region_claims=observer.claims.duplicate(true)
			legs.append({"name":"exterior_regions","group":"exterior_regions","trace":driver.trace.duplicate(true),
				"samples":observer.samples.duplicate(true),"failures":driver.failures.duplicate(),"initial_placement_only":true})
			observer.free();driver.observer=null
		route_claims=driver.routes.duplicate(true);threshold_claims=driver.threshold_controls.duplicate(true)
		for row: Dictionary in driver.interaction_checks:_check(row.ok,row.label)
		_check(driver.failures.is_empty() and region_claims.size()==6 and route_claims.size()==6,"complete six-region single-placement leg")
		var apron: Dictionary={}
		for room: Dictionary in world.layout.spaces:
			if str(room.id)=="F01_STREET_APRON":apron=room;break
		if not apron.is_empty():
			for step: Dictionary in driver.trace:
				var p: Array=step.actual;var r: Array=apron.rect
				if step.ok and step.on_floor and absf(float(p[1]))<.15 and p[0]>r[0]+.05 and p[0]<r[2]-.05 and p[2]>r[1]+.05 and p[2]<r[3]-.05:
					visited["F01_STREET_APRON"]={"actual":p.duplicate(),"leg":"exterior_regions"};break
		_check(visited.has("F01_STREET_APRON"),"original observed route reaches actual street apron")
		if failures==0:completed.append("exterior_regions")
	driver.free();Input.action_release("move_forward")
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	var retained:=0
	for ref: WeakRef in held:
		if ref.get_ref()!=null:retained+=1
	_check(retained==0 and held.size()==3,"root, driver and observer retire")
	var final_inputs:=_inputs()
	_check(initial_inputs==final_inputs,"production and physical inputs stay fixed")
	_check(bindings==_dependencies(),"complete original test closure stays fixed")
	_write_receipt(retained,held.size(),completed,final_inputs)
	print("V2 REGION ACCESS CONTRACT: ","PASS" if failures==0 else "FAIL"," regions=",region_claims.size()," routes=",route_claims.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

func _write_receipt(retained: int,tracked: int,completed_groups: Array[String],inputs: Dictionary) -> void:
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[]
	_check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository provenance")
	var directory:=OS.get_environment("SHOT_DIR")
	_check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"explicit writable original receipt destination")
	var file:=FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	_check(file!=null,"open original exterior contract")
	if file==null:return
	var status: String="PASS" if failures==0 else "FAIL"
	var entry: String="game/"+get_script().resource_path.trim_prefix("res://")
	var data: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"One declared outside street placement, all six authored public-region routes, observed consecutive physics poses, actual source floor/region capsule witnesses and real bodega front-leaf grab/motion/release. REGION_SHOPS means its authored bodega instance only; no receiving, eleven arcade-shop interiors, cases, inventory, disk saves, acoustic, photoreal, traffic safety or human acceptance.",
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":entry,"test_sha256":bindings.get(entry,""),"test_dependencies":bindings,"scene_path":scene_file_path,
			"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":inputs.runtime,"surface_inputs_sha256":inputs.surface},
		"groups":groups,"completed_groups":completed_groups,"legs":legs,"checks":checks,"failures":failures,
		"contracts":{"production_composition":{"executed":true,"status":status},
			"room_access":{"executed":completed_groups.size()==1,"status":status,"rooms":visited},
			"region_access":{"executed":completed_groups.size()==1,"status":status,"coordinate_frame":"orison_blockout_local",
				"regions":region_claims,"routes":route_claims,"threshold_controls":threshold_claims},
			"teardown":{"executed":true,"status":status,"measurement_scope":"production root, route driver and post-controller observer only","tracked_nodes":tracked,"retained_nodes":retained}}}
	file.store_string(JSON.stringify(data,"\t"));file.flush()
	if file.get_error()!=OK:failures+=1;push_error("Original exterior contract did not flush")
