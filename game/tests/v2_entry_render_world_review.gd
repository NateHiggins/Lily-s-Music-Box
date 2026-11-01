extends Node3D
## Actual production player/menu and validated disk reconstruction. This does
## not qualify passage arrival deadlines, direct manipulation or performance.
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")
var world: OrisonV2RuntimeRoot
var checks := 0
var failures: Array[String] = []
var observations: Array = []
var source_before := ""
var started := 0
var worlds_ready := 0
var _pause_seen := false
var _pause_probe_done := false
var _shutdown_seen := false

func check(ok: bool, label: String) -> bool:
	checks += 1
	observations.append({"ok":ok,"label":label})
	if not ok:failures.append(label);push_error("ENTRY WORLD: "+label)
	return ok

func _digest() -> String:
	var output: Array = []
	var root := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0:return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _mount() -> bool:
	world = Runtime.instantiate()
	# The orchestration must observe pause; the production world must not
	# inherit its ALWAYS process mode.
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	while not world.startup_failed and world.startup_ms<=0.:
		await get_tree().process_frame
	if not check(not world.startup_failed and world.player!=null,"actual production world completes startup"):return false
	worlds_ready += 1
	world.player.camera.make_current()
	world.player.set_mouse_released(false)
	check(world.entry_render_preparation.get("completed",false) and world.entry_render_preparation.get("render_calls",0)==10,"startup executes ten production-owned draws")
	check(world._entry_render_job==null and world.player.text_input_owner==null,"completed startup retains no preparation or input lease")
	return true

func _pause_during_job() -> void:
	await get_tree().process_frame
	var event := InputEventAction.new()
	event.action = "pause_services";event.pressed = true
	Input.parse_input_event(event);Input.flush_buffered_events()
	await get_tree().create_timer(.06,true).timeout
	_pause_seen = get_tree().paused and world.player.pause_services.is_open
	check(_pause_seen,"actual controller opens actual pause menu during preparation")
	world.player.pause_services.close(false)
	var release := InputEventAction.new()
	release.action = "pause_services";release.pressed = false
	Input.parse_input_event(release);Input.flush_buffered_events()
	_pause_probe_done = true

func _shutdown_during_job() -> void:
	await get_tree().process_frame
	world.shutdown_for_tests()
	_shutdown_seen = true

func _exercise() -> void:
	if not await _mount():return
	var player := world.player
	var pose := player.camera.global_transform
	var items := var_to_bytes(RealityState.data.maintenance_items)
	call_deferred("_pause_during_job")
	var result: Dictionary = await world._prepare_entry_rendering("review_pause")
	while not _pause_probe_done:await get_tree().process_frame
	check(not result.completed and result.reason=="player_interrupted" and not player.call_locked,"Pause cancels only the preparation lease")
	check(not get_tree().paused and not player.pause_services.is_open and player.camera.global_transform.is_equal_approx(pose),"resume preserves the actual camera Node pose")
	var foreign := Node.new();add_child(foreign)
	check(player.acquire_text_input(foreign),"existing controller grants foreign input lease")
	result = await world._prepare_entry_rendering("review_foreign")
	check(not result.completed and result.render_calls==0 and player.text_input_owner==foreign,"production callback preserves foreign input owner")
	player.release_text_input(foreign);foreign.free()
	player.call_locked = true
	result = await world._prepare_entry_rendering("review_protected")
	check(not result.completed and player.protected_input_active(),"protected conversation lock survives skipped preparation")
	player.call_locked = false
	player.set_mouse_released(true)
	result = await world._prepare_entry_rendering("review_pointer")
	check(not result.completed and player.mouse_released and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"released pointer stays released")
	player.set_mouse_released(false)
	check(RealityState.save_game(),"validated campaign owner writes actual sandbox save")
	var disk := FileAccess.get_file_as_bytes(RealityState.save_path)
	check(not disk.is_empty() and not FileAccess.get_file_as_string(RealityState.save_path).contains("entry_render_preparation"),"transient preparation observations are absent from disk")
	var first := weakref(world)
	call_deferred("_shutdown_during_job")
	result = await world._prepare_entry_rendering("review_shutdown")
	check(_shutdown_seen and not result.completed and result.reason=="world_shutdown" and player.text_input_owner==null,"actual world shutdown cancels and releases its pending lease")
	world.free();world = null
	await get_tree().process_frame
	check(first.get_ref()==null,"old production world is destroyed")
	RealityState.reset_campaign_for_tests();RealityState.load_game()
	check(RealityState.can_continue(),"validated campaign owner reloads the sandbox")
	if not await _mount():return
	check(world.entry_render_preparation.trigger=="startup" and not world._entry_render_shutdown,"fresh world creates a fresh startup job without stale shutdown state")
	check(var_to_bytes(RealityState.data.maintenance_items)==items,"inventory survives actual disk reconstruction")
	check(FileAccess.get_file_as_bytes(RealityState.save_path)==disk,"reload and rendering preparation do not rewrite saved bytes")

func _run() -> void:
	started = Time.get_ticks_msec();source_before = _digest()
	var old_path: String = RealityState.save_path
	var original := FileAccess.get_file_as_bytes(old_path) if FileAccess.file_exists(old_path) else PackedByteArray()
	var original_exists := FileAccess.file_exists(old_path)
	var test_path := "user://entry_render_world_%d.json"%Time.get_ticks_usec()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests();RealityState.save_path = test_path
	CampaignTime.set_frozen_for_tests(true)
	check(CampaignClock.new().configure_date(1928,11,10,720),"existing campaign clock supplies the frozen test date")
	await _exercise()
	get_tree().paused = false
	if is_instance_valid(world):world.shutdown_for_tests();world.free();world=null
	await get_tree().process_frame
	RealityState.persistence_enabled = false;RealityState.save_path = old_path
	check(FileAccess.file_exists(old_path)==original_exists and (not original_exists or FileAccess.get_file_as_bytes(old_path)==original),"real player save remains untouched")
	for suffix in ["",".bak",".tmp",".txn"]:
		var path := ProjectSettings.globalize_path(test_path+suffix)
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	var after := _digest()
	check(not source_before.is_empty() and source_before==after,"production runtime inputs stay frozen")
	var passed := failures.is_empty()
	var status := "PASS" if passed else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Actual loading callback with production player input, pause menu, protected/foreign leases, shutdown and sandbox save/reload into a second world. No passage approach/deadline, manipulation, surface, optical, artistic or performance acceptance.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
		"source":{"test_path":"game/tests/v2_entry_render_world_review.gd","test_sha256":FileAccess.get_file_as_string("res://tests/v2_entry_render_world_review.gd").replace("\r\n","\n").sha256_text(),"runtime_inputs_sha256":after},
		"contracts":{"production_composition":{"executed":worlds_ready>0,"status":status},"save_reconstruction":{"executed":worlds_ready==2,"status":status}},"checks":checks,"failures":failures,"observations":observations}
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t")+"\n")
	print("ENTRY WORLD REVIEW: %s; %d checks; %d failures"%[status,checks,failures.size()])
	get_tree().quit(0 if passed else 1)
