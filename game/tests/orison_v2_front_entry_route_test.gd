extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Closed contact, actual E/K rays, continuous passage and save reconstruction.
const ENTRY_SAVE:="user://tests/v2_front_entry.json"
func _init() -> void:route_label="V2 FRONT ENTRY ROUTE"
func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(0,.02,-10.3));player.velocity=Vector3.ZERO
	world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
func _route() -> void:
	var anchor:=world.adapter.resolve("F01_DOOR_06") as Node3D
	var door:=anchor.get_node("F01_DOOR_06_Leaf") as DoorProp
	if not _require(door is LandmarkEntryDoor and not door.open and door.leaf_state=="closed","landmark starts as a closed physical entrance"):return
	# RUL-018: walking at the shut entrance either meets its body or, for a
	# key holder, lets the passage guide swing it; nobody crosses it shut.
	var contact:=false
	var crossed_shut:=false
	var crossed:=false
	var start_side:=signf(door.to_local(player.global_position).z)
	player.face_world_point(door._body.to_global(Vector3(door.width*.5,1.1,door._hinge_offset)))
	Input.action_press("move_forward")
	for frame in 150:
		await get_tree().physics_frame
		for i in player.get_slide_collision_count():
			if player.get_slide_collision(i).get_collider()==door._body:contact=true
		if signf(door.to_local(player.global_position).z)!=start_side:
			crossed=true
			if absf(door._body.rotation.y)<.35:crossed_shut=true
			break
	Input.action_release("move_forward")
	if not await _wait_for_door(door):return
	print("[FRONT ENTRY] push contact=",contact," crossed=",crossed," crossed_shut=",crossed_shut," open=",door.open)
	if not _require(not crossed_shut and ((contact and not crossed and not door.open) or (crossed and door.open)),
			"the shut landmark is met or opened by the passage guide, never crossed shut"):return
	if not await _walk(Vector3(0,0,-10.3)):return
	if door.open and not await _operate_entry(door,false,"guided_close"):return
	if not await _operate_entry(door,true,"inside_open"):return
	if not await _walk(Vector3(0,0,-13.15)):return
	if not await _operate_entry(door,false,"outside_close"):return
	player.face_world_point(door._body.to_global(Vector3(door.width*.5,1.1,door._hinge_offset)))
	if not await _turn_key():return
	if not await _wait_for_door(door):return
	for frame in 120:
		await get_tree().physics_frame
		if not door._key_turning:break
	if not _require(door.leaf_state=="locked" and DoorKeyring.book().locks.get("F01_DOOR_06",false),"real house-service key input saves the entrance bolt"):return
	# RUL-018: the full-size leaf offers the hand no grip, locked or not (a
	# click is the key holder's passage request). The bolted leaf must give the
	# hand nothing to take and stay shut and locked under the aim.
	player.set_mouse_released(false)
	player.camera.look_at(door._body.to_global(Vector3(door.width*.5,1.1,door._hinge_offset)))
	await get_tree().physics_frame
	var grip: Dictionary=player._grab.find_target()
	for frame in 10: await get_tree().physics_frame
	if not _require(not grip.has("part") and not player._grab.active() and door.leaf_state=="locked"
			and not door.open and not door._moving,"locked entrance offers the hand no grip and stays shut"):return
	door=await _save_rebuild()
	if door==null:return
	player.face_world_point(door._body.to_global(Vector3(door.width*.5,1.1,door._hinge_offset)))
	await get_tree().physics_frame
	if not await _turn_key():return
	for frame in 120:
		await get_tree().physics_frame
		if not door._key_turning:break
	if not _require(door.leaf_state=="closed" and not DoorKeyring.book().locks.get("F01_DOOR_06",true),"same physical house key unlocks the saved entrance"):return
	if not await _operate_entry(door,true,"outside_open"):return
	if not await _walk(Vector3(0,0,-10.3)):return
	if not await _operate_entry(door,false,"inside_close"):return
	# The player's mask is the world layer plus its native contact layers.
	if not _require(not player.noclip and (player.collision_mask&1)==1 and player.is_physics_processing(),"round trip retains live gravity and collision: noclip=%s mask=%s physics=%s"%[player.noclip,player.collision_mask,player.is_physics_processing()]):return
func _save_rebuild() -> DoorProp:
	var previous_path:=RealityState.save_path
	var stance:=player.global_position
	var expected:=DoorKeyring.book().duplicate(true)
	RealityState.save_path=ENTRY_SAVE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ENTRY_SAVE).get_base_dir())
	RealityState.persistence_enabled=true
	var saved:=RealityState.save_game()
	RealityState.persistence_enabled=false
	if not _require(saved,"entrance lock writes through isolated campaign storage"):
		RealityState.save_path=previous_path;return null
	world.shutdown_for_tests();world.free();await get_tree().physics_frame
	RealityState.data={};RealityState.load_game();RealityState.save_path=previous_path
	world=Runtime.instantiate();add_child(world);await get_tree().create_timer(.5).timeout
	if not _require(not world.startup_failed,"saved campaign constructs a fresh production entrance"):return null
	player=world.player;_prepare_player_start();player.global_position=stance
	player.camera.make_current();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	var door:=world.adapter.resolve("F01_DOOR_06").get_node("F01_DOOR_06_Leaf") as DoorProp
	var restored:=door.leaf_state=="locked" and not door.open and DoorKeyring.player_has_key(door)
	for field in ["originals","permissions","copies","locks"]:restored=restored and DoorKeyring.book().get(field)==expected[field]
	for suffix in ["",".bak",".txn",".tmp"]:
		if FileAccess.file_exists(ENTRY_SAVE+suffix):DirAccess.remove_absolute(ENTRY_SAVE+suffix)
	return door if _require(restored,"fresh native leaf restores the saved bolt and existing keys") else null
func _operate_entry(door: DoorProp,want_open: bool,label: String) -> bool:
	# An outswung free edge travels out of arm reach: grab the hinge-side third
	# to close it, without changing the real reach constraint.
	var along: float=door.width*(.5 if want_open else 1.0/3.0)
	if not await _use(door,door._body.to_global(Vector3(along,1.1,door._hinge_offset)),label):
		print("[FRONT ENTRY] after ",label," open=",door.open," angle=",door._body.rotation.y," moving=",door._moving,
				" clear=",door.motion_clear(want_open)," player_local=",door.to_local(player.global_position))
		return false
	if not await _wait_for_door(door):return false
	return _require(door.open==want_open,"landmark E motion settles: "+label)
func _turn_key() -> bool:
	# Under the direct-manipulation ruling (design/DIRECT_MANIPULATION_2026-10-12.md)
	# a grabbable leaf shows the target indicator, not a text prompt. The key is
	# still the keyboard's K at the aimed door; the bolt checks that follow prove it.
	# A full-size leaf offers no grip (RUL-018), so prove the aim with the same
	# ray the key uses: the first ancestor that answers a key is the door.
	await get_tree().physics_frame;player._update_prompt()
	var ray:=PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position-player.camera.global_basis.z*2.1)
	ray.collide_with_areas=true;ray.exclude=[player.get_rid()]
	var node: Node=world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")
	while node!=null and not node.has_method("interact_key"):node=node.get_parent()
	if not _require(node is DoorProp,"the player aims at the landmark leaf"):return false
	var event:=InputEventKey.new();event.keycode=KEY_K;event.physical_keycode=KEY_K;event.pressed=true
	Input.parse_input_event(event);await get_tree().process_frame;await get_tree().process_frame
	event.pressed=false;Input.parse_input_event(event);await get_tree().process_frame
	return true
