extends "res://tests/v2_golden_repair_profile.gd"
## INERT repeatable played-world comparison before/after library repairs.
func _init() -> void: route_label="V2 LIBRARY WORLD PROFILE"

func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(1.925,.02,-3.5));player.velocity=Vector3.ZERO

func _play_route() -> void:
	player.profile_physics=true
	if not await _enter_2a(): return
	profile_phase="library_setup_excluded"
	var anchor: Node3D=world.adapter.resolve("F02_2A_BOOKSHELF_01")
	var shelf: Node3D=anchor if anchor.has_method("library_snapshot") else null
	if shelf==null:
		for node: Node in anchor.find_children("*","Node3D",true,false):
			if node.has_method("library_snapshot"): shelf=node;break
	if not _require(shelf!=null,"actual Mina library owner resolves"): return
	var stance: Node3D=world.adapter.resolve("F02_2A_BOOKSHELF_01_STANCE")
	print("LIBRARY WORLD STANCE: ",world.adapter.root.to_local(stance.global_position)," current=",world.adapter.root.to_local(player.global_position)," shelf=",world.adapter.root.to_local(shelf.global_position))
	if not await _walk(world.adapter.root.to_local(stance.global_position)): return
	profile_phase="library_setup_excluded"
	var aim: Vector3=shelf.to_global(Vector3(0,.83,.12))
	player.camera.look_at(aim)
	for frame in 20: await get_tree().process_frame
	profile_phase="library_near_still"
	for frame in 120: await get_tree().process_frame
	profile_phase="library_turning"
	for frame in 48:
		var event:=InputEventMouseMotion.new();event.relative=Vector2(3. if frame<24 else -3.,0)
		player._unhandled_input(event);await get_tree().process_frame
	profile_phase="library_acquire_excluded"
	var selected: Node3D
	for book: Node3D in shelf._books.values():
		var point:=book.to_global(Vector3(-.001,float(book.construction.height)*.65,0))
		if player.camera.global_position.distance_to(point)>2.1: continue
		player.camera.look_at(point)
		await get_tree().physics_frame
		var descriptor: Dictionary=player._grab.find_target()
		if descriptor.get("part")==book and descriptor.get("kind")=="free":selected=book;break
	if not _require(selected!=null,"actual reachable spine is targeted"): return
	profile_phase="library_pickup"
	_click_library()
	if not _require(player._grab.active() and player._grab.target.part==selected,"actual primary picks up book"): return
	for frame in 100: await get_tree().process_frame
	var held_goal: Vector3=player.camera.global_transform*Vector3(.17,-.16,-.48)
	print("LIBRARY HELD ERROR: ",(selected.global_transform*selected.pickup_centre()).distance_to(held_goal)," contact=",selected._last_motion," player=",player.global_position)
	var hit: Variant=selected._last_motion.get("collider")
	if hit is Node: print("LIBRARY HELD CONTACT OWNER: ",hit.get_path())
	profile_phase="library_held_turn"
	for frame in 32:
		var event:=InputEventMouseMotion.new();event.relative=Vector2(2. if frame<16 else -2.,0)
		player._unhandled_input(event);await get_tree().process_frame
	profile_phase="library_enter_inspection"
	var space:=InputEventKey.new();space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=true
	player._unhandled_input(space)
	if not _require(player.inspecting(),"Space enters actual floating inspection"):return
	for frame in 100: await get_tree().process_frame
	profile_phase="library_static_inspection"
	for frame in 120: await get_tree().process_frame
	profile_phase="library_capture_excluded"
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("world_floating_book.png"))
	var data: Dictionary={"evidence_class":"INERT","stock_id":selected.stock_id,"book_count":shelf._books.size(),"shelf_pose":str(shelf.global_transform),"player_pose":str(player.global_transform),"book_pose":str(selected.global_transform),"frozen":selected.freeze,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("library_state.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	player.end_inspection()

func _click_library() -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;player._unhandled_input(event)
