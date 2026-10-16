extends "res://tests/night_register_hand_test.gd"
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
const SaveOwner := preload("res://scripts/building/orison_v2_household_state.gd")
var world: OrisonV2RuntimeRoot
var started_ms := 0
var source_before := ""
var worlds_ready := 0
var pointer_exercised := false

func runtime_digest() -> String:
	var output: Array=[]
	var root := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0: return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func write_contract() -> void:
	var after := runtime_digest()
	check(not source_before.is_empty() and after==source_before,"runtime inputs remain unchanged throughout reconstruction")
	var sources := {}
	for path in ["res://tests/patrol_installed_save_test.gd","res://tests/night_register_hand_test.gd","res://tests/watch_station_hand_test.gd"]:
		sources["game/"+path.trim_prefix("res://")]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	var passed := failures==0
	var status := "PASS" if passed else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"installed night-register pointer manipulation, real disk save, atomic filing and two fresh-world reconstructions; no other patrol mechanism acceptance",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started_ms)/1000.0},
		"source":{"test_path":"game/tests/patrol_installed_save_test.gd","test_sha256":sources["game/tests/patrol_installed_save_test.gd"],"runtime_inputs_sha256":after,"test_sources":sources},
		"contracts":{"production_composition":{"executed":worlds_ready>0,"status":status},"direct_manipulation":{"executed":pointer_exercised,"status":status},"save_reconstruction":{"executed":worlds_ready==3,"status":status}},
		"checks":checks,"failures":results.filter(func(row): return not row.ok),"observations":results}
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))

func mount_world() -> bool:
	world=Runtime.instantiate()
	add_child(world)
	check(not world.startup_failed,"installed V2 world constructs")
	if world.startup_failed: return false
	worlds_ready+=1
	player=world.player
	player.set_physics_process(false)
	# Deferred first-shift arrival must finish before the installed stance.
	await get_tree().process_frame
	await get_tree().process_frame
	register=world.adapter.resolve("F01_NIGHT_REGISTER")
	check(register!=null and register._hand_controls!=null,"installed register has native controls")
	if register==null or register._hand_controls==null: return false
	player.global_position=register.to_global(Vector3(.04,-.8,.85))
	player.camera.current=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	await get_tree().physics_frame
	return true

func destroy_world() -> void:
	player.cancel_manipulation()
	world.shutdown_for_tests()
	world.free()
	await get_tree().process_frame
	await get_tree().process_frame

func exercise_installed() -> void:
	if not await mount_world(): return
	check(world.household_state._subjects.get("F01_NIGHT_REGISTER")==register,"household discovers actual installed register")
	check(world.work_orders.issue_job("lena_radiator_round_2b","reported"),"production work orders issue report")
	register._refresh_board()
	pointer_exercised=true
	check(await acquire("slip") and await move_to(.065),"installed report lifts through pointer input")
	click()
	check(await acquire("apartment") and await move_to(.065),"installed key lifts through pointer input")
	click()
	var wanted := register.mechanism_snapshot()
	check(wanted.slip_taken and wanted.keys_out.apartment,"carried report and key recorded")
	check(RealityState.save_game(),"real save writes pending round")
	check(RealityState.data[SaveOwner.KEY].records.F01_NIGHT_REGISTER.value==wanted,"save captures installed pending round")
	await destroy_world()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	check(RealityState.can_continue(),"pending save loads from disk")
	if not await mount_world(): return
	check(register.mechanism_snapshot()==wanted,"fresh world restores report and key custody")
	check(register.job_stage()=="acknowledged" and register.signed_lines==0,"reconstruction preserves acknowledgement without filing")
	check(await acquire("apartment_return") and await move_to(0),"restored key can be physically returned")
	click()
	check(await acquire("slip_return") and await move_to(0),"restored report can be physically returned")
	click()
	check(await acquire("index") and await move_to(.056),"restored round accepts physical conclusion selection")
	click()
	RealityState.persistence_enabled=true
	check(await acquire("pen"),"installed pen grabs for filing")
	await write_stroke()
	# Read immediately, before release can trigger a second household save.
	var on_disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RealityState.save_path))
	check(register.signed_lines==1,"installed writing creates one original signature")
	var saved: Dictionary=on_disk.get(SaveOwner.KEY,{}).get("records",{}).get("F01_NIGHT_REGISTER",{}).get("value",{})
	check(not saved.is_empty() and not saved.round_open and is_equal_approx(saved.index_z,-.06),"signature commit writes closed round and blank selector atomically")
	click()
	RealityState.persistence_enabled=false
	await destroy_world()
	RealityState.reset_campaign_for_tests()
	RealityState.load_game()
	if not await mount_world(): return
	check(register.signed_lines==1 and register._stored_lines().size()==1 and not register.round_open,"fresh signed world retains exactly one closed filing")
	check(register._hand_controls.held.is_empty() and not player._grab.active(),"reconstruction restores no transient grab")
	var out := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	player.camera.global_position=register.to_global(Vector3(.4,.5,.95))
	player.camera.look_at(register.to_global(Vector3(0,.22,.1)))
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join("installed_register.png"))==OK,"installed register capture writes successfully")

func _run() -> void:
	started_ms=Time.get_ticks_msec()
	source_before=runtime_digest()
	var old_path: String=RealityState.save_path
	var test_path := "user://patrol_installed_%d.json"%Time.get_ticks_usec()
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	RealityState.save_path=test_path
	await exercise_installed()
	if is_instance_valid(world): await destroy_world()
	RealityState.persistence_enabled=false
	RealityState.save_path=old_path
	for suffix in ["",".bak",".tmp",".txn"]:
		var path := ProjectSettings.globalize_path(test_path+suffix)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	write_contract()
	print("PATROL INSTALLED SAVE RESULT ",checks," checks ",failures," failures")
	get_tree().quit(1 if failures else 0)
