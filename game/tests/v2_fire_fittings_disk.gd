extends "res://tests/v2_fire_hand_bench.gd"
## Real selected production roots and an isolated disk save. Input placements
## are explicit fixtures, never evidence of a traversed route or human acceptance.
const Selector=preload("res://scripts/building/building_root_selector.gd")
var rows: Array[Dictionary]=[]
var retired: Array[WeakRef]=[]
var initial_digest := ""
var directory := ""
var check_results: Array[Dictionary]=[]

func check(ok: bool,label: String) -> bool:
	check_results.append({"ok":ok,"label":label})
	return super.check(ok,label)

func digest() -> String:
	var output: Array=[]
	var root: String=ProjectSettings.globalize_path("res://..").simplify_path()
	var result: int=OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)
	return str(output[0]).strip_edges() if result==0 and not output.is_empty() else ""

func build_world() -> OrisonV2RuntimeRoot:
	Selector.reset_for_tests("v2")
	var world: OrisonV2RuntimeRoot=(load(Selector.scene_path()) as PackedScene).instantiate()
	add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"production-selected V2 root starts for fire fitting disk review")
	return world

func registered(world: OrisonV2RuntimeRoot) -> void:
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	check(native!=null and native.stations.size()==8,"production root installs all eight fire stations")
	if native==null:return
	for identity: String in native.stations:
		var actor: Node3D=native.stations[identity].get_ref()
		check(world.adapter.resolve(identity)==actor and world.household_state._subjects.get(identity)==actor and world.household_state._kinds.get(identity)=="mechanism","actual household owner registers fire mechanism: "+identity)
		retired.append(weakref(actor));retired.append(weakref(actor._gasket_body));retired.append(weakref(actor._spare_gasket))

func place_input_fixture(world: OrisonV2RuntimeRoot,actor: Node3D) -> bool:
	player=world.player
	player.set_physics_process(false);player.velocity=Vector3.ZERO;player.camera.make_current()
	var shape:=CapsuleShape3D.new();shape.radius=PlayerController.BODY_RADIUS;shape.height=PlayerController.STANDING_HEIGHT
	for depth: float in [1.15,.95,1.30,.80]:
		for lateral: float in [-.10,0.,.15,-.25,.30]:
			var feet: Vector3=actor.to_global(Vector3(lateral,-1.175,depth))
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1;query.exclude=[player.get_rid()]
			query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*shape.height*.5)
			if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
			var floor_query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*.03,feet-Vector3.UP*.08,1,[player.get_rid()])
			var support: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(floor_query)
			if support.is_empty() or support.normal.dot(Vector3.UP)<.9:continue
			player.global_position=feet;player.set_lamp_enabled(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
			print("FIRE DISK INPUT FIXTURE: ",actor.name," feet=",feet," support=",support.position)
			await get_tree().physics_frame;await get_tree().physics_frame
			return true
	return false

func retire_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var ref: WeakRef=weakref(world)
	player=null;world.shutdown_for_tests();world.free()
	for frame in range(4):await get_tree().process_frame
	check(ref.get_ref()==null,"production root retires after fire disk cycle")
	var alive: int=0
	for item: WeakRef in retired:
		if item.get_ref()!=null:alive+=1
	check(alive==0,"all tracked fire actors, washer bodies and original draws retire")
	return {"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"tracked_alive":alive}

func _run() -> void:
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(directory)
	initial_digest=digest();check(not initial_digest.is_empty(),"original production input digest is available")
	var previous_path: String=RealityState.save_path
	var save_path: String="user://tests/v2_fire_fittings_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	RealityState.persistence_enabled=false;RealityState.save_path=save_path;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);CampaignClock.new().configure_date(1928,11,10,720)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world: OrisonV2RuntimeRoot=await build_world()
	var expected: Dictionary={}
	if not world.startup_failed:
		registered(world)
		var hand: Node=Hand.PatrolHand.new();world.add_child(hand)
		var actor: Node3D=world.adapter.resolve("F01_FIRE_LINE_STAIR")
		if check(actor!=null and await place_input_fixture(world,actor),"clear supported input placement at fitted station"):
			hand.player=player
			check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual mouse opens composed-world gasket access")
			await exercise_gasket(actor,hand)
		actor=world.adapter.resolve("F02_FIRE_LINE_STAIR")
		if check(actor!=null and await place_input_fixture(world,actor),"clear supported input placement at loose station"):
			hand.player=player
			check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual mouse opens second composed-world cabinet")
			check(await hand.operate(actor._lever.to_global(Vector3(.07,0,0)),-.4,actor),"actual mouse leaves a partial valve setting for disk")
			await aim(actor._tag.to_global(Vector3(0,0,.0035)));click();key(KEY_SPACE)
			check(player.inspecting(),"actual Space inspects second composed-world cabinet")
			check(await inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),actor._maximum("joint")),"actual input unthreads second union for disk")
			check(await carry_union(actor,actor._loose_union.receiving()+Vector3(0,-.025,.060)),"actual input leaves second hose end loose for disk")
			key(KEY_ESCAPE)
		for frame in range(30):await get_tree().physics_frame
		var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
		for identity: String in native.stations:expected[identity]=world.adapter.resolve(identity).mechanism_snapshot().duplicate(true)
		FileAccess.open(directory.path_join("expected_mechanisms.json"),FileAccess.WRITE).store_string(JSON.stringify(expected,"\t"))
		check(expected.F01_FIRE_LINE_STAIR.facts.gasket_seated and expected.F01_FIRE_LINE_STAIR.facts.coupling_made_up,"disk fixture includes the physically fitted washer")
		check(expected.F02_FIRE_LINE_STAIR.loose.active and not expected.F02_FIRE_LINE_STAIR.facts.gasket_seated,"disk fixture includes the physically loose hose end")
		var saved: bool=RealityState.save_game()
		check(saved,"RealityState writes the actual isolated fire fitting save")
		if saved:
			var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path))
			for identity: String in expected:
				var record: Dictionary=document.get("v2_household_controls",{}).get("records",{}).get(identity,{})
				check(record.get("kind")=="mechanism" and JSON.stringify(record.get("value"),"",true)==JSON.stringify(expected[identity],"",true),"real disk preserves complete fire mechanism: "+identity)
			check(DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),directory.path_join("saved_fire_fittings.json"))==OK,"original disk snapshot is retained for review")
	rows.append(await retire_world(world))
	if failures.is_empty():
		RealityState.reset_campaign_for_tests();RealityState.load_game()
		check(RealityState.can_continue(),"fresh campaign state loads the real fire disk save")
		world=await build_world()
		if not world.startup_failed:
			registered(world)
			var actual: Dictionary={}
			for identity: String in expected:
				var actor: Node3D=world.adapter.resolve(identity)
				actual[identity]=actor.mechanism_snapshot()
				check(JSON.stringify(actual[identity],"",true)==JSON.stringify(expected[identity],"",true),"fresh production root restores complete fire mechanism: "+identity)
				check(actor._spare_gasket.get_parent()==actor,"rebuild retains the original gasket draw parent: "+identity)
			FileAccess.open(directory.path_join("rebuilt_mechanisms.json"),FileAccess.WRITE).store_string(JSON.stringify(actual,"\t"))
		rows.append(await retire_world(world))
		check(rows[1].nodes<=rows[0].nodes and rows[1].orphans<=rows[0].orphans,"second fire rebuild causes no retained-node or orphan amplification")
	RealityState.persistence_enabled=false;RealityState.save_path=previous_path
	for suffix: String in ["",".bak",".tmp",".txn"]:
		var absolute: String=ProjectSettings.globalize_path(save_path+suffix)
		if FileAccess.file_exists(absolute):DirAccess.remove_absolute(absolute)
	var final_digest: String=digest();check(initial_digest==final_digest,"original production inputs remain fixed through both disk cycles")
	var closure: Dictionary={}
	for path: String in ["game/tests/v2_fire_fittings_disk.gd","game/tests/v2_fire_hand_bench.gd","game/tests/orison_v2_first_slice_contract_test.gd"]:
		closure[path]=FileAccess.get_sha256("res://"+path.trim_prefix("game/"))
	var status: String="PASS" if failures.is_empty() else "FAIL"
	var receipt: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,"execution":{"completed":true,"exit_code":0 if failures.is_empty() else 1,"timed_out":false},"scope":"Actual composed-world fire fitting manipulation, all eight household registrations, real isolated disk and fresh production rebuild, and tracked-node retirement. Explicit supported input placements; no played route, full fire programme, water-flow, angular rigidbody simulation or human appearance acceptance.","source":{"test_path":"game/tests/v2_fire_fittings_disk.gd","test_sha256":closure["game/tests/v2_fire_fittings_disk.gd"],"runtime_inputs_sha256":initial_digest,"test_closure":closure},"contracts":{"fire_fittings_disk":{"executed":rows.size()==2,"status":status},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","cycles":rows}},"failures":failures}
	receipt["checks"]=check_results.size();receipt["check_results"]=check_results
	FileAccess.open(directory.path_join("fire_fittings_disk_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("V2 FIRE FITTINGS DISK: ",status," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
