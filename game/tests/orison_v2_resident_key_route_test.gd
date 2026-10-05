extends "res://tests/orison_v2_golden_repair_route_test.gd"
## One physical permission, source counter, copied spare and actual lock input.
const KEY_SAVE := "user://tests/v2_resident_key_route.json"
var executed_checks: Array[Dictionary] = []
var owned_nodes: Array[WeakRef] = []
var owned_shapes: Array[WeakRef] = []
var door_sources: Array[StringName] = []
var reconstructed := false
var route_completed := false

func _run() -> void:
	var started := Time.get_ticks_msec()
	await super._run()
	var retained_nodes := _retained(owned_nodes)
	var retained_shapes := _retained(owned_shapes)
	var retained_playbacks := 0
	for source_id in door_sources:
		if AudioPolicy.active_voice(source_id) != null: retained_playbacks += 1
	_require(retained_nodes==0 and retained_shapes==0 and retained_playbacks==0,
		"both reconstructed worlds release runtime nodes, new key/door shapes and door voices")
	_write_contract(started,retained_nodes,retained_shapes,retained_playbacks)
	get_tree().quit(0 if failures.is_empty() else 1)

func _require(ok: bool, label: String) -> bool:
	executed_checks.append({"label":label,"ok":ok})
	return super._require(ok,label)

func _track_world() -> void:
	owned_nodes.append(weakref(world))
	for node in world.find_children("*","Node",true,false):
		owned_nodes.append(weakref(node))
		if node is DoorProp:
			door_sources.append(StringName(node.name))
			for shape: CollisionShape3D in node._body.find_children("*","CollisionShape3D",true,false):
				owned_shapes.append(weakref(shape.shape))
		elif node.is_in_group("key_copy_counter"):
			for shape: CollisionShape3D in node.find_children("*","CollisionShape3D",true,false):
				owned_shapes.append(weakref(shape.shape))

func _retained(refs: Array[WeakRef]) -> int:
	var count := 0
	for ref in refs:
		if ref.get_ref() != null: count += 1
	return count

func _init() -> void:
	route_label = "V2 RESIDENT KEY ROUTE"

func _route() -> void:
	_track_world()
	for point in [Vector3(0,0,-10.2),Vector3(0,0,-8.5),Vector3(1.925,0,-6.5),Vector3(1.925,0,-3.5)]:
		if not await _walk(point): return
	if not await _enter_2a(): return
	for point in [Vector3(-10.5,3.2,2.5),Vector3(-13.4,3.2,2.5),Vector3(-13.4,3.2,1.95)]:
		if not await _walk(point): return
	var mina: AnimatedResident = world.mina_routine.actor
	var originals := DoorKeyring.book().originals.duplicate(true) as Dictionary
	if not await _key(mina,mina.global_position+Vector3.UP*1.15,"resident_permission"): return
	if not _require(DoorKeyring.book().permissions.get("2A")=="mina_vale"
			and not DoorKeyring.book().copies.has("2A") and DoorKeyring.book().originals==originals,
			"physical resident authorizes a spare while retaining original"): return
	for point in [Vector3(-13.4,3.2,2.5),Vector3(-10.5,3.2,2.5),Vector3(-9.2,3.2,1.4)]:
		if not await _walk(point): return
	if not await _return_core(): return
	if not await _leave_front_entrance():return
	var outward := [Vector3(0,0,3),Vector3(14,0,3),Vector3(14,0,4.2),Vector3(14,-.1,8),
		Vector3(14,-.1,13.6),Vector3(14,0,15),Vector3(14,0,17.3),Vector3(14,0,20),
		Vector3(14,0,27.5),Vector3(14,0,32)]
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	var passage := world.passage_region
	var door: DoorProp = passage.doors.get("SITE_SHOP_DOOR_KEYS_CUT")
	if not _require(door != null,"existing Keys Cut door retained"): return
	var center := door.to_global(Vector3(door.width*.5,0,0))
	for point in [Vector3(14,0,center.z),Vector3(12.4,0,center.z)]:
		if not await _walk_world(point): return
	if not await _use(door,door.to_global(Vector3(door.width*.5,1.15,0)),"keys_cut_door"): return
	if not await _wait_for_door(door): return
	for point in [Vector3(10.8,0,center.z),Vector3(9.7,0,center.z)]:
		if not await _walk_world(point): return
	if not await _use(door,door._body.to_global(Vector3(door.width*.5,1.15,0)),"keys_cut_close"): return
	if not await _wait_for_door(door): return
	var counter: Node3D = passage._actors.get_node("AuthorizedKeyCopies")
	if not await _walk_world(Vector3(counter.global_position.x,0,center.z-.18)): return
	if not await _use(counter,counter.global_position+Vector3(0,-.09,.85),"key_copy_counter"): return
	if not _require(counter.opened and player.call_locked and counter.panel.visible,"ordinary counter input opens permission menu"): return
	await _screen("key_copy_permission_menu")
	var hours: PassageHoursDirector = counter.hours
	hours.set_process(false)
	hours.apply_for_minute(180)
	await _event(KEY_E)
	if not _require(not DoorKeyring.book().copies.has("2A") and counter.opened,
			"shop closing while menu is open refuses the copy"): return
	hours.apply_for_minute(20*60)
	hours.set_process(true)
	await _event(KEY_E)
	if not _require(DoorKeyring.book().copies.get("2A")=="mina_vale" and DoorKeyring.book().originals==originals,
			"ordinary focused copy input grants one authorized spare"): return
	await _screen("key_copy_made")
	await _event(KEY_ESCAPE)
	if not _require(not counter.opened and not player.call_locked and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,
			"counter close releases movement and restores pointer"): return
	if not _require(not DoorKeyring.make_copy("2A"),"second spare refused"): return
	if not await _walk_world(Vector3(9.7,0,center.z)): return
	if not await _use(door,door._body.to_global(Vector3(door.width*.5,1.15,0)),"keys_cut_exit"): return
	if not await _wait_for_door(door): return
	for point in [Vector3(10.8,0,center.z),Vector3(12.4,0,center.z),Vector3(14,0,center.z)]:
		if not await _walk_world(point): return
	var news: DoorProp = passage.doors.get("SITE_SHOP_DOOR_NEWS_CIGARS")
	if not _require(news != null and news.leaf_state=="closed","actual V2 News Cigars starts unlocked"): return
	var news_center := news.to_global(Vector3(news.width*.5,0,0))
	for point in [Vector3(14,0,news_center.z),Vector3(15.6,0,news_center.z)]:
		if not await _walk_world(point): return
	if not await _key(news,news.to_global(Vector3(news.width*.5,1.1,0)),"news_lock"): return
	if not _require(news.leaf_state=="locked" and not news.open,"actual key input locks News Cigars"): return
	if not await _use(news,news.to_global(Vector3(news.width*.5,1.1,0)),"news_locked_refusal"): return
	if not _require(not news.open,"locked shop refuses normal opening"): return
	if not await _key(news,news.to_global(Vector3(news.width*.5,1.1,0)),"news_unlock"): return
	if not await _use(news,news.to_global(Vector3(news.width*.5,1.1,0)),"news_open"): return
	if not await _wait_for_door(news): return
	for point in [Vector3(17.2,0,news_center.z),Vector3(18.3,0,news_center.z)]:
		if not await _walk_world(point): return
	if not await _use(news,news._body.to_global(Vector3(news.width*.5,1.1,0)),"news_close_inside"): return
	if not await _wait_for_door(news): return
	if not await _key(news,news.to_global(Vector3(news.width*.5,1.1,0)),"news_lock_inside",&"controller"): return
	if not await _key(news,news.to_global(Vector3(news.width*.5,1.1,0)),"news_unlock_inside",&"touch"): return
	if not await _use(news,news._body.to_global(Vector3(news.width*.5,1.1,0)),"news_exit"): return
	if not await _wait_for_door(news): return
	for point in [Vector3(17.2,0,news_center.z),Vector3(15.6,0,news_center.z),Vector3(14,0,news_center.z),Vector3(14,0,32)]:
		if not await _walk_world(point): return
	outward.reverse()
	for point: Vector3 in outward:
		if not await _walk_world(point): return
	for point in [Vector3(0,0,-10.2),Vector3(0,0,-8.5),Vector3(1.925,0,-6.5),Vector3(1.925,0,-3.5)]:
		if not await _walk(point): return
	# Finish at the private threshold. The spare now controls the resident's
	# real leaf, after a continuous return from its actual copying counter.
	for point in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),
		Vector3(3.975,3.2,-3.4),Vector3(-1.75,3.2,-3.4),Vector3(-1.75,3.2,0),Vector3(-3.2,3.2,0),Vector3(-4.65,3.2,0)]:
		if not await _walk(point): return
	var opening := world.adapter.resolve("F02_DOOR_02") as Node3D
	var apartment := opening.get_node("F02_DOOR_02_Leaf") as DoorProp
	if not await _wait_for_door(apartment): return
	if apartment.open:
		if not await _use(apartment,apartment._body.to_global(Vector3(apartment.width*.5,1.1,0)),"apartment_close"): return
		if not await _wait_for_door(apartment): return
	if not await _key(apartment,apartment.to_global(Vector3(apartment.width*.5,1.1,0)),"copied_apartment_lock"): return
	if not _require(apartment.leaf_state=="locked" and DoorKeyring.book().originals==originals,"copied spare controls real private leaf; originals retained"): return
	if not await _key(apartment,apartment.to_global(Vector3(apartment.width*.5,1.1,0)),"copied_apartment_unlock"): return
	if not _require(apartment.leaf_state=="closed","copied spare unlocks same private leaf"): return
	if not await _key(apartment,apartment.to_global(Vector3(apartment.width*.5,1.1,0)),"saved_apartment_lock"): return
	route_completed = true
	await _save_rebuild()

func _save_rebuild() -> void:
	var previous_path := RealityState.save_path
	RealityState.save_path = KEY_SAVE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(KEY_SAVE).get_base_dir())
	for suffix in ["",".bak",".txn",".tmp"]:
		if FileAccess.file_exists(KEY_SAVE+suffix): DirAccess.remove_absolute(KEY_SAVE+suffix)
	RealityState.persistence_enabled = true
	var saved := RealityState.save_game()
	RealityState.persistence_enabled = false
	_require(saved,"actual isolated campaign storage writes copied key and lock")
	var expected := DoorKeyring.book().duplicate(true)
	_track_world()
	world.shutdown_for_tests()
	world.free()
	await get_tree().physics_frame
	RealityState.data = {}
	RealityState.load_game()
	RealityState.save_path = previous_path
	world = Runtime.instantiate()
	add_child(world)
	await get_tree().create_timer(.5).timeout
	_track_world()
	_require(not world.startup_failed,"saved campaign constructs a fresh production world")
	var opening := world.adapter.resolve("F02_DOOR_02") as Node3D
	var leaf := opening.get_node("F02_DOOR_02_Leaf") as DoorProp
	reconstructed = leaf.leaf_state=="locked" and DoorKeyring.player_has_key(leaf)
	for field in ["originals","permissions","copies","locks"]:
		reconstructed = reconstructed and DoorKeyring.book().get(field)==expected[field]
	_require(reconstructed,"fresh actual leaf restores saved lock, original, permission and copied spare")
	for suffix in ["",".bak",".txn",".tmp"]:
		if FileAccess.file_exists(KEY_SAVE+suffix): DirAccess.remove_absolute(KEY_SAVE+suffix)

func _write_contract(started: int, nodes: int, shapes: int, playbacks: int) -> void:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head_output: Array = []
	var digest_output: Array = []
	_require(OS.execute("git",["-C",root,"rev-parse","HEAD"],head_output)==0,"contract records actual repository head")
	_require(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest_output)==0,
		"contract records runtime input digest using existing authority")
	var source_path: String = get_script().resource_path
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(FileAccess.get_file_as_bytes(source_path))
	var passed := failures.is_empty() and route_completed and reconstructed
	var status := "PASS" if passed else "FAIL"
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2",
		"production_runtime":true,"scope":"Resident permission, Keys Cut spare, hinged door locks and isolated save/reconstruction. No broader architecture or ledger completion claim.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,
			"elapsed_s":(Time.get_ticks_msec()-started)/1000.0},
		"source":{"test_path":"game/"+source_path.trim_prefix("res://"),"test_sha256":hash.finish().hex_encode(),
			"repository_head":str(head_output[0]).strip_edges() if not head_output.is_empty() else "",
			"runtime_inputs_sha256":str(digest_output[0]).strip_edges() if not digest_output.is_empty() else ""},
		"contracts":{"production_composition":{"executed":route_completed,"status":status,
			"identities":["mina_vale","SITE_SHOP_DOOR_KEYS_CUT","AuthorizedKeyCopies","SITE_SHOP_DOOR_NEWS_CIGARS","F02_DOOR_02"]},
			"save_reconstruction":{"executed":reconstructed,"status":status},
			"premature_action_denial":{"executed":route_completed,"status":status},
			"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned",
				"retained_nodes":nodes,"retained_resources":shapes,"retained_playbacks":playbacks,
				"resource_scope":"New DoorProp and Keys Cut collision shapes; shared imported caches are outside this owner."}},
		"checks":executed_checks,"waypoints":trace.size(),"failures":failures}
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://../tmp/resident-keys")
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE)
	if not _require(file!=null,"runtime contract output opens"): return
	file.store_string(JSON.stringify(receipt,"\t"))
	file.flush()
	_require(file.get_error()==OK,"runtime contract flushed")
	print("RESIDENT KEY CONTRACT: ",status," waypoints=",trace.size()," checks=",executed_checks.size())

func _key(owner_node: Node3D, target: Vector3, label: String, family := &"keyboard") -> bool:
	player.camera.look_at(target)
	await get_tree().physics_frame
	player._prompt_input_family = family
	var prior_touch := player.touch_input
	player.touch_input = family==&"touch"
	player._update_prompt()
	var carrier := "[D-PAD UP]" if family==&"controller" else "[KEY]" if family==&"touch" else "[K]"
	if not _require(player._prompt.text.contains(carrier),"actual key prompt: "+label): return false
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position,
		player.camera.global_position-player.camera.global_basis.z*2.1,1,[player.get_rid()])
	query.collide_with_areas = true
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	var node: Node = hit.get("collider")
	var matched := false
	while node:
		matched = matched or node==owner_node
		node = node.get_parent()
	if not _require(matched,"real key ray reaches "+label): return false
	var before := owner_node.leaf_state as String if owner_node is DoorProp else ""
	var key_event := InputEventKey.new()
	var joy_event := InputEventJoypadButton.new()
	if family==&"keyboard":
		key_event.keycode = KEY_K
		key_event.physical_keycode = KEY_K
		key_event.pressed = true
		Input.parse_input_event(key_event)
	elif family==&"controller":
		joy_event.button_index = JOY_BUTTON_DPAD_UP
		joy_event.pressed = true
		Input.parse_input_event(joy_event)
	else: Input.action_press("door_key")
	await get_tree().process_frame
	await get_tree().process_frame
	if family==&"keyboard":
		key_event.pressed = false
		Input.parse_input_event(key_event)
	elif family==&"controller":
		joy_event.pressed = false
		Input.parse_input_event(joy_event)
	else: Input.action_release("door_key")
	await _screen(label)
	await get_tree().create_timer(.4).timeout
	player.touch_input = prior_touch
	player._prompt_input_family = &"keyboard"
	if owner_node is DoorProp:
		return _require(owner_node.leaf_state==("closed" if before=="locked" else "locked"),
				family+" input changes actual lock: "+label)
	return true

func _event(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	Input.parse_input_event(event)
	await get_tree().process_frame

func _screen(label: String) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
