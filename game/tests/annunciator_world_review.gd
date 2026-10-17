extends Node3D
## Installed input and real disk reconstruction. Not the complete repair route.
var failures: Array[String]=[]
var checks := 0
var terminal := false
var out := ""
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func _ready() -> void:
	get_tree().create_timer(450).timeout.connect(func():
		if not terminal:push_error("Installed annunciator review incomplete");get_tree().quit(1))
	_run.call_deferred()

func _world() -> OrisonV2RuntimeRoot:
	var world := preload("res://scenes/building/orison_v2_runtime.tscn").instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.startup_failed and world.player!=null,"production world starts with physical annunciator")
	return world

func _run() -> void:
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var original_path := RealityState.save_path
	RealityState.save_path="user://tests/v2_annunciator_service_%d.json"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var world := await _world()
	if world.startup_failed or world.player==null:_finish(original_path);return
	var player := world.player;player.set_physics_process(false)
	var board := world.adapter.resolve("LobbyPorterBoard") as OtisProp
	check(board!=null and board._native_service!=null,"original installed board owns native physical service")
	if board==null or board._native_service==null:world.free();_finish(original_path);return
	player.global_position=board.to_global(Vector3(0,-1.4,.65));player.velocity=Vector3.ZERO
	player.call_locked=false;player.mouse_released=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var driver := preload("res://tests/radiator_cutover_review.gd").new()
	var input := preload("res://tests/annunciator_input_driver.gd").new(self,board,player,driver,check)
	var events: Array=[];board.maintenance_completed.connect(func(result: Dictionary):events.append(result))
	var stage_before := world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)
	await input.move(board._flag_arms[0],board._native_service.FLAG_HIGH)
	await get_tree().create_timer(.5).timeout
	await input.move(board._contact_bridge,0.0)
	await input.move(board._reset_spindle,PI*.5)
	await get_tree().create_timer(.85).timeout
	check(events.size()==1 and not board.stuck_flag and absf(board.contact_alignment-.63)<.00001,"installed controls complete their actual service")
	check(world.work_orders.job_stage(ServiceRoundDirector.JOB_ID)==stage_before,"board cannot invent or advance an unacknowledged repair job")
	check(world.household_state._subjects.get("LobbyPorterBoard")==board,"production household owner discovers the board")
	check(not world.household_state._blocked,"new native board state does not block household saves")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(board.mechanism_snapshot()))
	check(RealityState.save_game(),"real RealityState storage writes serviced board")
	check(FileAccess.file_exists(RealityState.save_path),"save is actually present on disk")
	FileAccess.open(out.path_join("annunciator_saved_game.json"),FileAccess.WRITE).store_string(FileAccess.get_file_as_string(RealityState.save_path))
	await input.move(board._contact_bridge,.12)
	check(absf(board._contact_bridge.rotation.z-.12)<.00001,"actual later input changes the saved geometry")
	RealityState.load_game()
	await get_tree().physics_frame
	check(absf(board._contact_bridge.rotation.z)<.00001 and not world.household_state._blocked,"disk load adopts old household state into the existing world")
	player.camera.global_position=board.to_global(Vector3(.20,-.05,.65));player.camera.look_at(board.to_global(Vector3(0,0,.045)))
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join("installed_annunciator.png"))==OK,"installed capture written")
	var old_board: WeakRef=weakref(board)
	input=null;driver.free();world.free()
	await get_tree().process_frame
	check(old_board.get_ref()==null,"original board retires with its world")
	RealityState.load_game()
	world=await _world()
	if world.startup_failed or world.player==null:world.free();_finish(original_path);return
	board=world.adapter.resolve("LobbyPorterBoard") as OtisProp
	check(board!=null and not world.household_state._blocked,"rebuilt production world accepts saved board schema")
	if board!=null:
		check(_same_payload(board.mechanism_snapshot(),saved),"disk reconstruction preserves serviced physical board settings across JSON numeric representations")
		check(not board.stuck_flag and absf(board._contact_bridge.rotation.z)<.00001,"reconstructed native parts match their actual service result")
	world.free()
	_finish(original_path)

func _same_payload(a: Variant,b: Variant) -> bool:
	if typeof(a) in [TYPE_INT,TYPE_FLOAT] and typeof(b) in [TYPE_INT,TYPE_FLOAT]:return absf(float(a)-float(b))<.000000000001
	if typeof(a)!=typeof(b):return false
	if a is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not _same_payload(a[key],b[key]):return false
		return true
	if a is Array:
		if a.size()!=b.size():return false
		for index in a.size():
			if not _same_payload(a[index],b[index]):return false
		return true
	return a==b

func _finish(original_path: String) -> void:
	RealityState.save_path=original_path;RealityState.persistence_enabled=false
	FileAccess.open(out.path_join("annunciator_world.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"scope":"Actual installed annunciator gestures and serviced-board disk load/rebuild. No full radiator repair route, broad runtime contract or human acceptance."},"\t"))
	print("ANNUNCIATOR WORLD: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures)
	terminal=true;get_tree().quit(0 if failures.is_empty() else 1)
