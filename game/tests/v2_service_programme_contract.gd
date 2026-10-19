extends "res://tests/v2_spatial_access_cohort.gd"
## Played shared-room programme review; room presence is not system runtime proof.
const Driver=preload("res://tests/v2_service_programme_walk.gd")
const Disk=preload("res://tests/v2_service_mail_disk.gd")
const ROOMS=["F01_MAIL_TELEPHONE","F01_PACKAGE","F01_COMMON_B","B1_LAUNDRY","B1_COAL_ROOM","B1_ELECTRICAL","B1_MAINTENANCE_SHOP","B1_RESIDENT_STORAGE"]

func _run() -> void:
	groups=PackedStringArray(["service_programmes"]);initial_inputs=_inputs();bindings=_dependencies()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();CampaignTime.set_frozen_for_tests(true)
	_check(CampaignClock.new().configure_date(1928,11,10,12*60),"valid opening-day daytime fixture")
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC;Selector.reset_for_tests("v2")
	var world: OrisonV2RuntimeRoot=(load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world);await get_tree().physics_frame;await get_tree().physics_frame
	_check(not world.startup_failed,"production-selected V2 composition starts")
	var driver: Node=Driver.new();driver.externally_managed=true;driver.world=world;driver.player=world.player
	var held: Array[WeakRef]=[weakref(world),weakref(driver)]
	var completed: Array[String]=[]
	if failures==0:
		add_child(driver);world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		world.player.set_lamp_enabled(true)
		driver._prepare_player_start();await get_tree().physics_frame;await get_tree().physics_frame
		await driver._route()
		for row: Dictionary in driver.interaction_checks:_check(row.ok,row.label)
		_check(driver.failures.is_empty() and not driver.trace.is_empty(),"one complete collision-bearing shared programme route")
		legs.append({"name":"service_programmes","group":"service_programmes","trace":driver.trace.duplicate(true),"failures":driver.failures.duplicate(),"initial_placement_only":true})
		for room: Dictionary in world.layout.spaces:
			if str(room.id) not in ROOMS:continue
			var y: float=world.adapter.root.level_y[str(room.level)];var r: Array=room.rect
			for step: Dictionary in driver.trace:
				var p: Array=step.actual
				if step.ok and absf(float(p[1])-y)<.15 and p[0]>r[0]+.05 and p[0]<r[2]-.05 and p[2]>r[1]+.05 and p[2]<r[3]-.05:
					visited[str(room.id)]={"actual":p.duplicate(),"leg":"service_programmes"};break
		for identity: String in ROOMS:_check(visited.has(identity),"actual walk reaches authored programme room: "+identity)
		var directory: String=OS.get_environment("SHOT_DIR")
		if not directory.is_empty():
			var file: FileAccess=FileAccess.open(directory.path_join("standing_views.json"),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(driver.captures,"\t"));file.flush()
		if failures==0:completed.append("service_programmes")
	var expected_mail: Dictionary=driver.mail_expected.duplicate(true)
	var disk: RefCounted=Disk.new()
	var disk_saved: bool=false
	if failures==0:disk_saved=disk.write(self,expected_mail)
	driver.free();Input.action_release("move_forward")
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	var retained: int=0
	for reference: WeakRef in held:
		if reference.get_ref()!=null:retained+=1
	_check(retained==0,"root and programme driver retire")
	if failures==0 and disk_saved:await disk.rebuild(self,expected_mail)
	disk.cleanup()
	var final_inputs: Dictionary=_inputs()
	_check(initial_inputs==final_inputs,"production and surface inputs stay fixed")
	_check(bindings==_dependencies(),"complete original programme test closure stays fixed")
	_write_receipt(retained,held.size(),completed,final_inputs)
	print("V2 SERVICE PROGRAMME CONTRACT: ","PASS" if failures==0 else "FAIL"," rooms=",visited.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)
