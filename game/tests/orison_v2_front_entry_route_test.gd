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
	var contact:=false
	player.face_world_point(door._body.to_global(Vector3(door.width*.5,1.1,door._hinge_offset)))
	Input.action_press("move_forward")
	for frame in 45:
		await get_tree().physics_frame
		for i in player.get_slide_collision_count():
			if player.get_slide_collision(i).get_collider()==door._body:contact=true
	Input.action_release("move_forward")
	if not _require(contact,"closed native landmark blocks the ordinary controller"):return
	if not await _walk(Vector3(0,0,-10.3)):return
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
	if not await _use(door,door._body.to_global(Vector3(door.width*.5,1.1,door._hinge_offset)),"locked_rattle"):return
	if not _require(not door.open and not door._moving,"locked entrance refuses ordinary E motion"):return
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
	if not _require(not player.noclip and player.collision_mask==1 and player.is_physics_processing(),"round trip retains live gravity and collision"):return
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
	if not await _use(door,door._body.to_global(Vector3(door.width*.5,1.1,door._hinge_offset)),label):return false
	if not await _wait_for_door(door):return false
	return _require(door.open==want_open,"landmark E motion settles: "+label)
func _turn_key() -> bool:
	await get_tree().physics_frame;player._update_prompt()
	if not _require(player._prompt.text.contains("[K]"),"existing keyboard key prompt reaches the landmark"):return false
	var event:=InputEventKey.new();event.keycode=KEY_K;event.physical_keycode=KEY_K;event.pressed=true
	Input.parse_input_event(event);await get_tree().process_frame;await get_tree().process_frame
	event.pressed=false;Input.parse_input_event(event);await get_tree().process_frame
	return true
