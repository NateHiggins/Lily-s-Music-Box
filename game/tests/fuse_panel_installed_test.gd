extends "res://tests/fuse_panel_hand_test.gd"
## Real basement input and disk reconstruction. This is not a walked room route.
const Selector := preload("res://scripts/building/building_root_selector.gd")

func _digest(root: String) -> String:
	var output: Array=[]
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0 or output.is_empty(): return ""
	return str(output[0]).strip_edges()

func _text_hash(path: String) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_string(path).replace("\r\n","\n").to_utf8_buffer())
	return hash.finish().hex_encode()

func _run() -> void:
	var started := Time.get_ticks_msec()
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var initial_inputs := _digest(root)
	var prior_path := RealityState.save_path
	var prior_persistence := RealityState.persistence_enabled
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,750)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	Selector.reset_for_tests("v2")
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty(): out="user://fuse_installed_proof"
	DirAccess.make_dir_recursive_absolute(out)
	var packed := load(Selector.scene_path()) as PackedScene
	var world := packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"production V2 starts with physical fuse assembly")
	if world.startup_failed: get_tree().quit(1);return
	player=world.player
	panel=world.adapter.resolve("B1_FUSE_PANEL")
	player.global_position=world.adapter.root.to_global(Vector3(7.6,-3.18,-4.9))
	player.velocity=Vector3.ZERO
	player.carried_device.set_capture_hidden(true)
	player.camera.make_current()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	await get_tree().physics_frame
	var body_position := player.global_position
	await _repair_by_hand(false)
	check(player.global_position.distance_to(body_position)<.03 and not player.noclip,"repair retains actual standing player and room collision")
	var household: Node=get_tree().get_first_node_in_group("v2_household_state")
	check(household!=null and household._service_completed.get("B1_FUSE_PANEL",false),"retained household authority records physical service completion")
	# Leave genuine partial hand positions before saving. The historical service
	# completion and the present electrical condition are deliberately distinct.
	await aim(panel._handle.to_global(Vector3(0,.03,0)))
	click();check(await turn_to(.8),"main left partially open by real input before save");click()
	await aim(panel._handle.to_global(Vector3(0,.03,0)))
	click()
	var inspect := InputEventKey.new()
	inspect.keycode=KEY_SPACE;inspect.physical_keycode=KEY_SPACE;inspect.pressed=true
	player._unhandled_input(inspect)
	check(await acquire_fuse(2),"installed replacement reacquired for partial-state disk proof")
	check(await turn_to(TAU*.7),"real replacement left partly threaded before save")
	click();player.end_inspection()
	var expected := panel.mechanism_snapshot()
	check(panel.main_open and panel.plug_out and not panel.panel_safe,"partial unscrewing revokes present conductor protection")
	household.capture_now()
	check(household.errors.is_empty(),"new physical schema is accepted by existing household save owner")
	var save_path := "user://tests/fuse_physical_%s.json"%Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	RealityState.save_path=save_path;RealityState.persistence_enabled=true
	check(RealityState.save_game(),"physical fuse positions written to actual save file")
	var retired: WeakRef=weakref(panel)
	var retired_hand: WeakRef=weakref(panel._hand_controls)
	var retired_plugs: WeakRef=weakref(panel._hand_controls.plugs)
	world.shutdown_for_tests();world.free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(retired.get_ref()==null,"old installed electrical owner retired")
	check(retired_hand.get_ref()==null and retired_plugs.get_ref()==null,"old physical controllers retire with their electrical owner")
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	world=packed.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed,"fresh production root accepts disk-loaded fuse schema")
	panel=world.adapter.resolve("B1_FUSE_PANEL")
	check(panel!=null and panel.valid_mechanism(expected),"fresh world resolves same panel and valid saved physical identities")
	if panel!=null:
		var actual := panel.mechanism_snapshot()
		check(is_equal_approx(actual.main,expected.main) and is_equal_approx(actual.door,expected.door),"fresh root retains partial cabinet and main travel")
		for i in 4:
			check(actual.plugs.items[i].station==expected.plugs.items[i].station and is_equal_approx(actual.plugs.items[i].turn,expected.plugs.items[i].turn),"fresh root retains distinct fuse %d and thread travel"%i)
			for key: String in ["position","rotation"]:
				var same := true
				for j in actual.plugs.items[i][key].size():
					if not is_equal_approx(actual.plugs.items[i][key][j],expected.plugs.items[i][key][j]): same=false
				check(same,"fresh root retains fuse %d %s"%[i,key])
		check(panel.main_open and panel.plug_out and not panel.panel_safe and panel.fitted_rating==15,"loaded historical completion does not falsely certify a partly removed fuse")
	retired_hand=weakref(panel._hand_controls);retired_plugs=weakref(panel._hand_controls.plugs)
	world.shutdown_for_tests();world.free()
	packed=null;household=null
	await get_tree().process_frame
	await get_tree().process_frame
	check(retired_hand.get_ref()==null and retired_plugs.get_ref()==null,"reconstructed controllers also retire without retention")
	RealityState.save_path=prior_path;RealityState.persistence_enabled=prior_persistence
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	check(not initial_inputs.is_empty() and _digest(root)==initial_inputs,"runtime inputs unchanged during input and reconstruction proof")
	var failed := checks.filter(func(row): return not row.ok).size()
	var source: String=get_script().resource_path
	var head: Array=[]
	OS.execute("git",["-C",root,"rev-parse","HEAD"],head)
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Installed B1 fuse cabinet: actual primary clicks, mouse travel and depth wheel, fixed inspection camera, guarded repair, partial-state disk save, destroy and fresh V2 reconstruction. One initial standing placement; no continuous room-route or visual acceptance claim.",
		"execution":{"completed":true,"exit_code":0 if failed==0 else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+source.trim_prefix("res://"),"test_sha256":_text_hash(source),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":initial_inputs,
			"test_dependencies":{"game/tests/fuse_panel_hand_test.gd":_text_hash("res://tests/fuse_panel_hand_test.gd")}},
		"contracts":{"physical_interaction":{"executed":true,"status":"PASS" if failed==0 else "FAIL","identities":["B1_FUSE_PANEL"]},"save_reconstruction":{"executed":true,"status":"PASS" if failed==0 else "FAIL"}},
		"checks":checks,"failures":failed}
	FileAccess.open(out.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	print("INSTALLED FUSE PHYSICAL: ","PASS" if failed==0 else "FAIL","; ",checks.size()," checks; ",failed," failures")
	get_tree().quit(0 if failed==0 else 1)
