extends "res://tests/service_set_hand_test.gd"
## INERT local world-space adapter/input diagnostic; not occupied V2 proof.
var done := false
var old_cap := 0
var input_checks: Array[Dictionary] = []

func check(ok: bool, label: String) -> bool:
	input_checks.append({"name":label, "passed":ok})
	return super.check(ok, label)

func _ready() -> void:
	if not standalone: return
	get_tree().create_timer(130.0).timeout.connect(func():
		if not done: check(false, "world hand diagnostic deadline"); finish())
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	directory = OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(1); return
	DirAccess.make_dir_recursive_absolute(directory)
	old_cap = Engine.max_fps
	Engine.max_fps = 120
	var floor_body := StaticBody3D.new()
	add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(12, .2, 12)
	shape.shape = box; shape.position.y = -.1
	floor_body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = box.size
	visual.mesh = mesh; visual.position = shape.position
	floor_body.add_child(visual)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	add_child(light)
	player = PlayerController.new()
	add_child(player)
	player.set_physics_process(false)
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	carrier = preload("res://scripts/device/companion_world_carrier.gd").new()
	await carrier.setup(player, player.camera, null)
	player.carried_device = carrier
	if not check(bool(carrier.get("world_ready")), "world companion binds its native flight and existing instrument"):
		finish(); return
	check(carrier._pass_view == null and carrier._presentation_layer == null, "world companion adds no private viewport or overlay")
	check(carrier.find_children("*", "PhysicsBody3D", true, false).size() == 1, "one nonblocking sphere replaces per-mesh moving physical bodies")
	check(carrier._hand.occlusion != null and carrier._hand.occlusion.get_child_count() == 1, "fixed stock shares one query-only pick mesh")
	check(carrier._hand.descriptor("lamp").is_empty(), "world reticle and grab share refusal before the device is presented")
	await exercise()
	await _tap_switch(KEY_R)
	check(carrier.radio_is_powered(), "actual radio contact powers face reactions")
	await _tap_switch(KEY_L)
	var native_rig: Node = carrier.get("rig")
	check(player.lamp_is_enabled() and native_rig.reaction_player.current == "lamp_trim", "actual L starts the physical lamp reaction from the original power state")
	for index in 360:
		await get_tree().physics_frame
		if native_rig.reaction_player.current.is_empty(): break
	check(native_rig.reaction_player.current.is_empty(), "real lamp reaction completes without locking input")
	await key(KEY_E)
	check(carrier.reading and native_rig.reaction_player.current == "vaudeville_wink", "actual recall starts a courteous physical wink")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("actual_recall_face.png"))
	await key(KEY_E)
	var lens: MeshInstance3D = carrier.device.teletype.torch_lens
	player._carry_service_light(.016)
	check(player._hand.global_position.distance_to(lens.to_global(lens.mesh.get_aabb().get_center())) < .00001, "real lamp originates at native lens instead of the player's eye")
	check(player.flashlight.get_parent() == player._hand, "original player lamp remains the only light owner")
	finish()

func key(code: Key) -> void:
	if code == KEY_SPACE and carrier.reading and not player.inspecting():
		for index in 240:
			if carrier.can_inspect_controls(): break
			await get_tree().physics_frame
	await super.key(code)
	if code == KEY_E and carrier.reading:
		for index in 240:
			await get_tree().physics_frame
			if carrier.can_inspect_controls(): break
		check(carrier.can_inspect_controls(), "recall settles before actual control inspection")

func aim(part: Node3D) -> bool:
	var points: Array[Vector3] = [part.global_position]
	var draws: Array[Node] = part.find_children("*", "MeshInstance3D", true, false)
	if part is MeshInstance3D: draws.push_front(part)
	for draw: MeshInstance3D in draws:
		if draw.mesh != null: points.append(draw.to_global(draw.mesh.get_aabb().get_center()))
	for point in points:
		if player.camera.is_position_behind(point): continue
		var pixel := player.camera.unproject_position(point)
		for offset in [Vector2.ZERO, Vector2(3,0), Vector2(-3,0), Vector2(0,3), Vector2(0,-3), Vector2(6,0), Vector2(-6,0), Vector2(0,6), Vector2(0,-6)]:
			Input.warp_mouse(pixel + offset)
			await get_tree().physics_frame
			await get_tree().process_frame
			await get_tree().process_frame
			var target: Dictionary = player._grab.find_target()
			if target.get("part") == part: return true
	print("WORLD PICK MISS ", part.name, " hit ", carrier._hand.last_hit)
	return false

func finish() -> void:
	if done: return
	done = true
	Engine.max_fps = old_cap
	super.finish()

func _tap_switch(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		Input.parse_input_event(event)
		await RenderingServer.frame_post_draw
