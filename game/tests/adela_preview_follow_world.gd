extends "res://tests/orison_v2_vertical_route_test.gd"
## Installed-world follow contract plus INERT optical/performance observations.
var follower: CharacterBody3D
var observations: Dictionary={"evidence_class":"INERT","scope":"Temporary Adela in installed V2, short walked corridor, loaded appearance and stationary same-world presentation-cost observation. Not narrative, save/reload or artistic acceptance."}

func _init() -> void:route_label="ADELA INSTALLED FOLLOW"

func _route() -> void:
	var test_hash: String=FileAccess.get_sha256(get_script().resource_path)
	var before: String=_runtime_digest()
	var dependencies: Dictionary={}
	for path: String in ["res://tests/orison_v2_vertical_route_test.gd","res://tests/orison_v2_first_slice_contract_test.gd","res://tests/AdelaPreviewFollowWorld.tscn"]:
		dependencies["game/"+path.trim_prefix("res://")]=FileAccess.get_sha256(path)
	if _verify(before.length()==64,"production source digest is available"):
		await _play_follow_route()
	_verify(_runtime_digest()==before,"production inputs remained fixed during following")
	for path: String in dependencies:
		_verify(dependencies[path]==FileAccess.get_sha256("res://"+path.trim_prefix("game/")),"consumed test dependency remained fixed: "+path)
	_verify(test_hash==FileAccess.get_sha256(get_script().resource_path),"executed follow test source remained fixed")
	var completed: bool=bool(observations.get("completed",false))
	_verify(completed and trace.size()==5,"all five played movement legs completed")
	var passed: bool=completed and failures.is_empty() and trace.size()==5
	var record: Dictionary={"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Supplied Adela preview in the installed V2 root: one initial player placement, three normal-controller corridor legs and two first-stair/landing legs, actor movement, catch-up and capsule support. No NPC schedule, narrative date, save/reload, prologue, whole-game or artistic acceptance. Frame-time arrays are separate observations, not a performance pass.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
		"source":{"test_path":"game/tests/adela_preview_follow_world.gd","test_sha256":test_hash,"scene_path":scene_file_path,"test_dependencies":dependencies,"runtime_inputs_sha256":before},
		"programme":{"completed":completed,"trace":trace,"failures":failures,"observations":"adela_world.json"},
		"contracts":{"temporary_adela_follow":{"executed":completed,"passed":passed}}}
	var output: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var file: FileAccess=FileAccess.open(output.path_join("adela_follow.runtime.json"),FileAccess.WRITE)
	if _verify(file!=null,"follow runtime contract can be written"):
		file.store_string(JSON.stringify(record,"\t"));_verify(file.get_error()==OK,"follow runtime contract is complete");file.close()

func _runtime_digest() -> String:
	var root: String=ProjectSettings.globalize_path("res://..").simplify_path()
	var output: Array=[]
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0 or output.is_empty():return ""
	return str(output[0]).strip_edges()

func _play_follow_route() -> void:
	_verify(get_viewport().get_visible_rect().size==Vector2(3440,1440),"native3440x1440 viewport")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	observations["vsync"]=false;observations["max_fps"]=0
	follower=world.adela_preview_follower
	if not _verify(follower!=null,"runtime mounted the temporary preview"):return
	for frame in 120:
		if follower.spawned:break
		await get_tree().physics_frame
	if not _verify(follower.spawned and follower.visible and follower.model!=null,"supplied Adela is visible on supported installed ground"):return
	var initial:=follower.global_position
	for target in [Vector3(3.975,0,-3.4),Vector3(3.975,0,-2.4),Vector3(1.925,0,-3.5)]:
		if not await _walk(target):return
	for frame in 240:
		if follower.global_position.distance_to(player.global_position)<2.3:break
		await get_tree().physics_frame
	_verify(follower.global_position.distance_to(initial)>.3,"Adela actually moved along the played route")
	_verify(follower.global_position.distance_to(player.global_position)<2.4,"Adela catches up in the installed corridor")
	_verify(follower.is_on_floor(),"installed collision supports her capsule")
	var original:=player.camera.global_transform
	player.camera.look_at(follower.global_position+Vector3.UP*1.)
	for frame in 4:await RenderingServer.frame_post_draw
	var output:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	_verify(get_viewport().get_texture().get_image().save_png(output.path_join("adela_installed_corridor.png"))==OK,"loaded Adela capture is written")
	observations["viewport"]=str(get_viewport().get_visible_rect().size)
	observations["player"]=str(player.global_transform);observations["adela"]=str(follower.global_transform)
	observations["enabled_frames_ms"]=await _sample()
	var previous_process_mode:=follower.process_mode
	follower.process_mode=Node.PROCESS_MODE_DISABLED;follower.visible=false
	observations["hidden_frames_ms"]=await _sample()
	follower.visible=true;follower.process_mode=previous_process_mode
	observations["enabled_return_frames_ms"]=await _sample()
	player.camera.global_transform=original
	# Use the installed first stair, not another flat-room surrogate.
	for target in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3)]:
		if not await _walk(target):return
	for frame in 360:
		if follower.global_position.distance_to(player.global_position)<2.3:break
		await get_tree().physics_frame
	var actual: Vector3=world.adapter.root.to_local(follower.global_position)
	_verify(actual.y>1.45 and follower.is_on_floor(),"Adela follows up the real stair to its supported half landing")
	observations["stair_player"]=str(player.global_position)
	observations["stair_adela"]=str(follower.global_position)
	observations["completed"]=true
	observations["failures"]=failures
	FileAccess.open(output.path_join("adela_world.json"),FileAccess.WRITE).store_string(JSON.stringify(observations,"\t"))

func _verify(ok: bool,label: String) -> bool:
	if not ok:failures.append(label);push_error(route_label+": "+label)
	return ok

func _sample() -> Array:
	for frame in 20:await RenderingServer.frame_post_draw
	var samples: Array=[]
	var previous:=Time.get_ticks_usec()
	for frame in 120:
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.);previous=now
	return samples
