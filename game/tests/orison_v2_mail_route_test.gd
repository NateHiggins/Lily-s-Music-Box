extends "res://tests/orison_v2_connected_exterior_route_test.gd"
func _init() -> void:
	route_label = "V2 MAIL ACCESS"

func _route() -> void:
	for point in [Vector3(0,0,-3),Vector3(0,0,-1.5),Vector3(-1.8,0,-1.5),Vector3(-4,0,-1.35)]:
		if not await _walk(point): return
	var guard: Node3D = world.adapter.resolve("F01_TOUR_KEY_GUARD")
	if not await _use(guard,guard.to_global(Vector3(0,.15,.06)),"tour_key_guard"): return
	_require(guard.key_carried(),"physical tour-key guard yields its actual key")
	if not await _use(guard,guard.to_global(Vector3(0,.15,.06)),"tour_key_return"): return
	_require(not guard.key_carried(),"physical tour-key guard accepts its key back")
	for point in [Vector3(-4.6,0,-1.5),Vector3(-4.9,0,-2.4),Vector3(-6.2,0,-2.4),Vector3(-7.1,0,-2.4)]:
		if not await _walk(point): return
	var mail: Node3D = world.adapter.resolve("LobbyMailBank")
	var stance := mail.global_position-mail.global_basis.z*.9
	stance.y = world.adapter.root.to_global(Vector3.ZERO).y
	if not await _walk_world(stance): return
	# Physical access to the bank uses the full player capsule; individual
	# tenant-box keys/deliveries remain owned by the existing mail mechanism.
	var directory := OS.get_environment("SHOT_DIR")
	player.camera.look_at(mail.global_position+Vector3.UP*1.2)
	if not directory.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("mail_bank.png"))
	for point in [Vector3(-7.1,0,-2.4),Vector3(-6.2,0,-2.4),Vector3(-4.9,0,-2.4),
			Vector3(-4.6,0,-1.5),Vector3(-1.8,0,-1.5),Vector3(0,0,-1.5),Vector3(0,0,-3)]:
		if not await _walk(point): return
