extends "res://tests/dumbwaiter_hand_test.gd"
## One standing placement; actual repair, disk save and full world reconstruction.
const Selector := preload("res://scripts/building/building_root_selector.gd")
var retired_nodes: Array[WeakRef] = []
var retired_resources: Array[WeakRef] = []
var retired_playbacks: Array[WeakRef] = []

func digest(root: String) -> String:
	var output: Array=[]
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0 or output.is_empty(): return ""
	return str(output[0]).strip_edges()

func text_hash(path: String) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_string(path).replace("\r\n","\n").to_utf8_buffer())
	return hash.finish().hex_encode()

func _run() -> void:
	var started := Time.get_ticks_msec()
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var inputs := digest(root)
	var prior_path := RealityState.save_path
	var prior_persistence := RealityState.persistence_enabled
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,750)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	Selector.reset_for_tests("v2")
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty(): out="user://dumbwaiter_installed_proof"
	DirAccess.make_dir_recursive_absolute(out)
	var packed := load(Selector.scene_path()) as PackedScene
	var world := packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"production V2 starts with physical dumbwaiter controls")
	if world.startup_failed: get_tree().quit(1);return
	player=world.player;tank=world.adapter.resolve("LobbyServiceDumbwaiter")
	player.global_position=world.adapter.root.to_global(Vector3(8.60,.05,2.8))
	player.velocity=Vector3.ZERO
	player.carried_device.set_capture_hidden(true)
	player.camera.make_current()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	await get_tree().physics_frame
	await exercise()
	var household: Node=get_tree().get_first_node_in_group("v2_household_state")
	check(household!=null and household._kinds.get("LobbyServiceDumbwaiter")=="mechanism" and tank.band_seated,"household authority records physical dumbwaiter repair")
	check(await acquire("brake"),"repaired wheel reacquired for partial save")
	check(await move_to(2.0),"physical wheel left partly turned before save")
	if player._grab.active(): click()
	var expected := tank.mechanism_snapshot()
	household.capture_now()
	check(household.errors.is_empty(),"household accepts new dumbwaiter mechanism schema")
	var save_path := "user://tests/dumbwaiter_physical_%s.json"%Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	RealityState.save_path=save_path;RealityState.persistence_enabled=true
	check(RealityState.save_game(),"dumbwaiter partial positions written to actual save file")
	var retired: WeakRef=weakref(tank)
	var retired_hand: WeakRef=weakref(tank._hand_controls)
	track_retirement(world)
	world.shutdown_for_tests();world.free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(retired.get_ref()==null and retired_hand.get_ref()==null,"old dumbwaiter and physical controller retire")
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests();RealityState.load_game()
	world=packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"fresh world accepts dumbwaiter disk schema")
	tank=world.adapter.resolve("LobbyServiceDumbwaiter")
	check(tank!=null and tank.valid_mechanism(expected),"fresh dumbwaiter resolves saved physical schema")
	if tank!=null:
		var actual := tank.mechanism_snapshot()
		for key: String in expected:
			check(actual[key]==expected[key] if expected[key] is bool else is_equal_approx(float(actual[key]),float(expected[key])),"reconstruction retains "+key)
		check(tank.band_seated,"reconstructed repair retains original completed authority")
	retired_hand=weakref(tank._hand_controls)
	track_retirement(world)
	world.shutdown_for_tests();world.free();packed=null;household=null
	await get_tree().process_frame
	await get_tree().process_frame
	check(retired_hand.get_ref()==null,"reconstructed hand controller retires")
	RealityState.save_path=prior_path;RealityState.persistence_enabled=prior_persistence
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	check(not inputs.is_empty() and digest(root)==inputs,"runtime inputs unchanged during proof")
	var nodes_left := remaining(retired_nodes)
	var resources_left := remaining(retired_resources)
	var playbacks_left := remaining(retired_playbacks)
	check(nodes_left==0 and resources_left==0 and playbacks_left==0,"both worlds release observed nodes, dumbwaiter shapes/controller and audio playbacks")
	var head: Array=[]
	OS.execute("git",["-C",root,"rev-parse","HEAD"],head)
	var source: String=get_script().resource_path
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Installed dumbwaiter: actual click, constrained motion, release and static inspection, guarded repair, partial-state disk save, destroy and fresh V2 reconstruction. One standing placement; no continuous route or human visual acceptance claim.",
		"execution":{"completed":true,"exit_code":0 if failures==0 else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+source.trim_prefix("res://"),"test_sha256":text_hash(source),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":inputs,
			"test_dependencies":{"game/tests/dumbwaiter_hand_test.gd":text_hash("res://tests/dumbwaiter_hand_test.gd")}},
		"contracts":{"production_composition":{"executed":true,"status":"PASS" if failures==0 else "FAIL","identities":["LobbyServiceDumbwaiter"]},
			"premature_action_denial":{"executed":true,"status":"PASS" if failures==0 else "FAIL"},
			"teardown":{"executed":true,"status":"PASS" if failures==0 else "FAIL","measurement_scope":"runtime_owned",
				"retained_nodes":nodes_left,"retained_resources":resources_left,"retained_playbacks":playbacks_left,
				"tracked_nodes":retired_nodes.size(),"tracked_resources":retired_resources.size(),"tracked_playbacks":retired_playbacks.size(),
				"resource_scope":"Unpathed dumbwaiter collision shapes and dumbwaiter hand controllers; shared imported caches excluded."},
			"physical_interaction":{"executed":true,"status":"PASS" if failures==0 else "FAIL","identities":["LobbyServiceDumbwaiter"]},"save_reconstruction":{"executed":true,"status":"PASS" if failures==0 else "FAIL"}},
		"checks":results,"failures":failures}
	FileAccess.open(out.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("INSTALLED DUMBWAITER PHYSICAL: ","PASS" if failures==0 else "FAIL","; ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)

func track_retirement(world: OrisonV2RuntimeRoot) -> void:
	retired_nodes.append(weakref(world))
	for node: Node in world.find_children("*","Node",true,false):
		retired_nodes.append(weakref(node))
		if node is AudioStreamPlayer3D and node.playing:
			var playback: AudioStreamPlayback=node.get_stream_playback()
			if playback!=null: retired_playbacks.append(weakref(playback))
	retired_resources.append(weakref(tank._hand_controls))
	for shape: CollisionShape3D in tank.find_children("*","CollisionShape3D",true,false):
		if shape.shape!=null and shape.shape.resource_path.is_empty(): retired_resources.append(weakref(shape.shape))

func remaining(refs: Array[WeakRef]) -> int:
	var count := 0
	for ref in refs:
		if ref.get_ref()!=null: count+=1
	return count
