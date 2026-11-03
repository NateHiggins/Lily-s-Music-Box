extends "res://tests/orison_v2_vertical_route_test.gd"
## INERT installed-world preview route; no narrative or whole-game acceptance.
var follower: CharacterBody3D
var observations: Dictionary={"evidence_class":"INERT","scope":"Temporary Adela in installed V2, short walked corridor, loaded appearance and stationary same-world presentation-cost observation. Not narrative, save/reload or artistic acceptance."}

func _init() -> void:route_label="ADELA INSTALLED FOLLOW"

func _route() -> void:
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
	get_viewport().get_texture().get_image().save_png(output.path_join("adela_installed_corridor.png"))
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
	var actual:=world.adapter.root.to_local(follower.global_position)
	_verify(actual.y>1.45 and follower.is_on_floor(),"Adela follows up the real stair to its supported half landing")
	observations["stair_player"]=str(player.global_position)
	observations["stair_adela"]=str(follower.global_position)
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
