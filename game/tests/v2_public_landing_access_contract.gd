extends "res://tests/v2_spatial_access_cohort.gd"
## One placement, ordinary controller, all occupied public floors and stairs.
const Driver := preload("res://tests/orison_v2_public_landing_walk.gd")
const Footprints := preload("res://scripts/building/orison_v2_space_footprints.gd")

func _run() -> void:
	groups=PackedStringArray(["public_landings"])
	initial_inputs=_inputs();bindings=_dependencies()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	_check(CampaignClock.new().configure_date(1928,10,15,20*60),"valid campaign fixture")
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	Selector.reset_for_tests("v2")
	var world := (load(Selector.scene_path()) as PackedScene).instantiate() as OrisonV2RuntimeRoot
	add_child(world);await get_tree().physics_frame;await get_tree().physics_frame
	_check(not world.startup_failed,"production-selected V2 composition starts")
	var driver: Node=Driver.new()
	driver.externally_managed=true;driver.world=world;driver.player=world.player
	var held: Array[WeakRef]=[weakref(world),weakref(driver),weakref(world.public_landings)]
	var completed: Array[String]=[]
	if failures==0:
		add_child(driver);world.player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		driver._prepare_player_start()
		await driver._route()
		_check(driver.failures.is_empty() and not driver.trace.is_empty(),"one complete collision-bearing six-floor route")
		legs.append({"name":"public_landings","group":"public_landings","trace":driver.trace.duplicate(true),"failures":driver.failures.duplicate(),"initial_placement_only":true})
		var owners: Dictionary=world.public_landings.snapshot()
		_check(owners.size()==6,"six loaded landing owners")
		for space: Dictionary in world.layout.spaces:
			if not space.has("landing_core"):continue
			var identity:=str(space.id);var floor:=str(space.level)
			var owner: Dictionary=owners.get(identity,{})
			_check(owner.get("supports",[]).size()==space.floor_platforms.size() and owner.get("landmarks",[]).size()==space.programme_anchors.size(),"actual physical owners: "+identity)
			_check(owner.get("units",[]).size()==(2 if floor=="F01" else 4),"actual apartment choices: "+identity)
			var sign: Node3D=owner.sign.get_ref()
			_check(sign!=null and sign.get_node("Apartments").text=="  /  ".join(owner.units),"visible unit identities: "+identity)
			var north:=false;var south:=false
			var y:=float(world.adapter.root.level_y[floor])
			for step: Dictionary in driver.trace:
				var point: Array=step.actual
				if not step.ok or absf(float(point[1])-y)>=.15:continue
				if not Footprints.contains_xz(world.layout,space,Vector2(point[0],point[2])):continue
				if point[2]>2.5:north=true;visited[identity]={"actual":point,"leg":"public_landings"}
				if point[2]<-2.1:south=true
			_check(north and south,"real controller reaches both public halves: "+identity)
		_check(visited.size()==6,"all six landing footprints reached without per-floor placement")
		if failures==0:completed.append("public_landings")
	driver.free();Input.action_release("move_forward")
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	var retained:=0
	for reference: WeakRef in held:
		if reference.get_ref()!=null:retained+=1
	_check(retained==0,"root, route driver and landing manager retire")
	var final_inputs:=_inputs()
	_check(initial_inputs==final_inputs,"production and surface inputs stay fixed")
	_check(bindings==_dependencies(),"entry scene and complete driver closure stay fixed")
	_write_receipt(retained,held.size(),completed,final_inputs)
	print("V2 PUBLIC LANDING ACCESS CONTRACT: ","PASS" if failures==0 else "FAIL"," rooms=",visited.size()," failures=",failures)
	get_tree().quit(0 if failures==0 else 1)

