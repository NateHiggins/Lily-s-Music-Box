extends Node
## Lily's first-floor ruling (v1r_first_floor_layout_20261111) in the V2 world:
## the mail bank and the porter's board stand in the lobby, the telephone board
## and its operator's things in common room B, each against a wall with clear
## floor in front, and the residents' mail walk ends at the bank. With SHOT_DIR
## and a window it takes review captures (not runtime proof).

var _fails := 0
var _checks := 0
var world: Node3D
var _feet := Vector3.ZERO
var _look := Vector3.ZERO
var _pinned := false


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _settle(node: Node) -> void:
	var began := Time.get_ticks_msec()
	var quiet := 0
	while (quiet < 60 or not node.can_process()) and Time.get_ticks_msec() - began < 90000:
		var before := Time.get_ticks_msec()
		await get_tree().process_frame
		quiet = quiet + 1 if Time.get_ticks_msec() - before < 250 else 0


func _process(_delta: float) -> void:
	if not _pinned or world == null or not is_instance_valid(world.player):
		return
	world.player.global_position = _feet
	world.player.camera.look_at(_look)
	var companion: Variant = world.get("service_set_carrier")
	if companion is Node3D:
		(companion as Node3D).visible = false


func _snap(label: String, feet: Vector3, look: Vector3) -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	_feet = feet
	_look = look
	_pinned = true
	for index in 60:
		await get_tree().process_frame
	for index in 8:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	print("FIRST FLOOR SHOT: ", label)
	_pinned = false


func _ray(from: Vector3, to: Vector3, ignore: Node3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var excluded: Array[RID] = []
	for body: Node in ignore.find_children("*", "CollisionObject3D", true, false) + ([ignore] if ignore is CollisionObject3D else []):
		excluded.append((body as CollisionObject3D).get_rid())
	query.exclude = excluded
	return world.get_world_3d().direct_space_state.intersect_ray(query)


func _ready() -> void:
	process_priority = 1000
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	world = (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts with the first floor redistributed (so every resident's route still composes)")
	if world.startup_failed:
		_finish()
		return
	await _settle(world.temporal_loop)
	await get_tree().physics_frame
	world.player.set_physics_process(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/first_floor_layout.json"))
	var rooms := {"LobbyMailBank": "F01_LOBBY", "LobbyPorterBoard": "F01_LOBBY", "F01_HOUSE_TELEPHONE_BOARD": "F01_COMMON_B",
			"F01_operator_stool": "F01_COMMON_B", "F01_headset_hook": "F01_COMMON_B", "F01_cord_pile": "F01_COMMON_B"}
	_check((table.moves as Array).size() == rooms.size(), "the table moves six things")
	for move: Dictionary in table.moves:
		var identity := str(move.id)
		var thing := world.adapter.resolve(identity) as Node3D
		_check(thing != null, identity + " is in the building")
		if thing == null:
			continue
		var place: Array = move.position
		var here: Vector3 = world.adapter.root.to_local(thing.global_position)
		_check(Vector2(here.x, here.z).distance_to(Vector2(float(place[0]), float(place[2]))) < 0.02,
				"%s stands where the table puts it (%s)" % [identity, str(here)])
		_check(world.room_at_world(thing.global_position + Vector3.UP * 0.3) == str(rooms[identity]),
				"%s is in %s (%s)" % [identity, str(rooms[identity]), world.room_at_world(thing.global_position + Vector3.UP * 0.3)])
	# The three fittings: a wall close behind, clear floor in front.
	for identity: String in ["LobbyMailBank", "LobbyPorterBoard", "F01_HOUSE_TELEPHONE_BOARD"]:
		var thing := world.adapter.resolve(identity) as Node3D
		var out: Vector3 = -thing.global_basis.z if identity != "LobbyMailBank" else -thing.global_basis.z
		# Find which way is the room: the side with more clear air.
		var chest := thing.global_position
		chest.y = world.adapter.root.to_global(Vector3.ZERO).y + 1.3
		var ahead := _ray(chest, chest + thing.global_basis.z * 1.2, thing)
		var behind := _ray(chest, chest - thing.global_basis.z * 1.2, thing)
		var clear_ahead := 1.2 if ahead.is_empty() else chest.distance_to(ahead.position)
		var clear_behind := 1.2 if behind.is_empty() else chest.distance_to(behind.position)
		_check(minf(clear_ahead, clear_behind) < 0.4, "%s has a wall close on one side (%.2f, %.2f)" % [identity, clear_ahead, clear_behind])
		_check(maxf(clear_ahead, clear_behind) > 0.85, "%s has clear floor on the other (%.2f, %.2f)" % [identity, clear_ahead, clear_behind])
	# The chute goes with the bank.
	var bank := world.adapter.resolve("LobbyMailBank") as Node3D
	var chute := world.find_child("LobbyMailChute", true, false) as Node3D
	_check(chute != null and world.room_at_world(chute.global_position + Vector3.UP * 0.5) == "F01_LOBBY"
			and chute.global_position.distance_to(bank.global_position) < 1.3, "the mail chute stands beside the bank in the lobby")
	# The residents walk to it.
	var mina: Node = world.get("mina_routine")
	_check(mina != null and world.room_at_world((mina.graph.get_point_position(mina.identities.mail) as Vector3) + Vector3.UP * 0.3) == "F01_LOBBY",
			"Mina's mail walk ends in the lobby")
	_check(not (mina.graph.get_id_path(mina.identities.stair_bottom, mina.identities.mail) as PackedInt64Array).is_empty(),
			"and there is a way to it from the foot of the stair")
	# The watch room keeps the watchman's instruments and nothing else of these.
	for identity: String in ["F01_WATCHMAN_DETECTOR", "F01_NIGHT_REGISTER", "F01_SIGNAL_REGISTER", "F01_TOUR_KEY_GUARD"]:
		var thing := world.adapter.resolve(identity) as Node3D
		_check(thing != null and world.room_at_world(thing.global_position + Vector3.UP * 0.2) == "F01_WATCH", identity + " stays in the watch room")

	var floor_y: float = world.adapter.root.to_global(Vector3.ZERO).y
	var board := world.adapter.resolve("LobbyPorterBoard") as Node3D
	var phones := world.adapter.resolve("F01_HOUSE_TELEPHONE_BOARD") as Node3D
	await _snap("lobby_mail_bank", Vector3(bank.global_position.x - 3.2, floor_y, bank.global_position.z + 0.6), bank.global_position + Vector3.UP * 1.2)
	await _snap("lobby_porter_board", Vector3(board.global_position.x + 0.4, floor_y, board.global_position.z - 2.6), board.global_position)
	await _snap("lobby_whole", world.adapter.root.to_global(Vector3(-3.8, 0.0, -8.4)), world.adapter.root.to_global(Vector3(3.0, 1.3, -5.5)))
	await _snap("house_office_telephone", Vector3(phones.global_position.x - 2.8, floor_y, phones.global_position.z + 0.5), phones.global_position)
	await _snap("old_mail_room", world.adapter.root.to_global(Vector3(-6.2, 0.0, -1.0)), world.adapter.root.to_global(Vector3(-9.0, 1.2, -1.3)))
	_finish()


func _finish() -> void:
	print("[V2 FIRST FLOOR] RESULT: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	await get_tree().process_frame
	if world != null:
		world.shutdown_for_tests()
		remove_child(world)
		world.free()
	get_tree().quit(0 if _fails == 0 else 1)
