extends Node
## Evidence stills for the phone torch and the de-glowed cast (not
## shipped). Boots the real building, stands the player in a corridor
## with a resident a few steps ahead, and captures the same frame with
## the torch off and on. Run with the rendering executable, not
## --headless:  SHOT_DIR=<abs> godot --path game res://tests/PhoneLightShots.tscn

var _dir := ""


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	var root: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run(root)


func _run(root: Node3D) -> void:
	await get_tree().create_timer(1.2).timeout
	# A borrowed actor keeps their home floor as parent; streaming would
	# cull them with it no matter where they stand.
	root.show_all_floors = true
	if root.sanity:
		root.sanity.stand_down()
		root.sanity.enabled = false
	if root.fourth_wall:
		root.fourth_wall.force_finish()
	var player: PlayerController = root.player
	player.global_position = Vector3(4.3, 3.35, 0.0)
	player.velocity = Vector3.ZERO
	player.autopilot = Vector3.ZERO
	# Freeze the building's direction so the borrowed actor holds the
	# mark instead of wandering off between frames.
	if root.get("resident_routines") != null:
		root.resident_routines.process_mode = Node.PROCESS_MODE_DISABLED
	# Borrow a resident and stand them in the beam line. Prefer one who
	# is actually onstage — a rider mid-lift is invisible and stays so.
	var resident: Node3D = null
	for candidate in get_tree().get_nodes_in_group("animated_residents"):
		if resident == null:
			resident = candidate
		if candidate.visible:
			resident = candidate
			break
	if resident:
		resident.set("externally_driven", true)
		resident.visible = true
		resident.global_position = player.global_position \
				+ Vector3(0.0, 0.0, -2.4)
		resident.global_position.y = player.global_position.y
		resident.look_at(player.global_position, Vector3.UP)
		resident.set("_home", resident.position)
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.make_current()
	await get_tree().process_frame
	await _snap("phone_light_off.png")
	player.flashlight.visible = true
	player._light_mask.visible = true
	# Let the hand chase settle and shadows land.
	await get_tree().create_timer(0.5).timeout
	await _snap("phone_light_on.png")
	get_tree().quit(0)


func _snap(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_dir.path_join(file_name))
	print("[SHOT] ", _dir.path_join(file_name))
