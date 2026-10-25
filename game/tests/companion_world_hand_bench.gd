extends "res://tests/service_set_hand_test.gd"
## INERT local world-space adapter/input diagnostic; not occupied V2 proof.
var done := false
var old_cap := 0
var input_checks: Array[Dictionary] = []
var mouse_trace: Array[Dictionary] = []

func check(ok: bool, label: String) -> bool:
	input_checks.append({"name":label, "passed":ok})
	if not ok and is_instance_valid(player) and is_instance_valid(carrier):
		FileAccess.open(directory.path_join("hand_failure_%02d.json" % input_checks.size()), FileAccess.WRITE).store_string(JSON.stringify({
			"label":label, "cursor":str(get_viewport().get_mouse_position()), "enabled":carrier.hand_is_enabled(),
			"active":player._grab.active(), "target":str(player._grab.target.get("part")), "last_hit":str(carrier._hand.last_hit),
			"hand_control":str(carrier.device.teletype.hand_control), "events":mouse_trace}, "\t"))
	return super.check(ok, label)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_trace.append({"ticks":Time.get_ticks_msec(), "event":str(event), "part":str(player._grab.target.get("part")) if is_instance_valid(player) else ""})
		if mouse_trace.size() > 48: mouse_trace.pop_front()

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
	check(carrier.screen_frame.view.world_3d == get_world_3d() and carrier.screen_frame.view_camera.cull_mask == 2, "framed companion shares its single world rig and isolates only the device render layer")
	check(carrier.find_children("*", "PhysicsBody3D", true, false).size() == 1, "one nonblocking presentation body retains world lamp and control identity")
	check(carrier._hand.occlusion != null and carrier._hand.occlusion.get_child_count() == 1, "fixed stock shares one query-only pick mesh")
	check(carrier._hand.descriptor("lamp").is_empty(), "world reticle and grab share refusal before the device is presented")
	await exercise()
	await _tap_switch(KEY_R)
	check(carrier.radio_is_powered(), "actual radio contact powers face reactions")
	var native_rig: Node = carrier.get("rig")
	# Returning from physical controls now folds a real deployed tray. Let the
	# powered printer finish and the face become exposed before asking it to
	# emote; reading/printing intentionally takes priority over an optional cue.
	for index in 900:
		if native_rig.keyboard_open <= .01 and not carrier.device.teletype.printing: break
		await get_tree().physics_frame
	check(native_rig.keyboard_open <= .01 and not carrier.device.teletype.printing, "original powered printer finishes and folded tray exposes the face")
	await _tap_switch(KEY_L)
	# Observe the actual L edge through the original power owner.
	for index in 120:
		if native_rig.reaction_player.current == "lamp_trim": break
		await get_tree().physics_frame
	check(player.lamp_is_enabled() and native_rig.reaction_player.current == "lamp_trim", "actual L starts the physical lamp reaction from the original power state")
	for index in 360:
		await get_tree().physics_frame
		if native_rig.reaction_player.current.is_empty(): break
	check(native_rig.reaction_player.current.is_empty(), "real lamp reaction completes without locking input")
	var last_wink: float = float(native_rig.reaction_player._last.get("vaudeville_wink", -1.0))
	await key(KEY_E)
	# key() also waits for arrival and keyboard presentation. That presentation
	# correctly takes the face away; verify the actual accepted start timestamp,
	# rather than requiring an interrupted animation to remain current forever.
	check(carrier.reading and float(native_rig.reaction_player._last.get("vaudeville_wink", -1.0)) > last_wink, "actual recall starts a courteous physical wink")
	var former_pin: Vector3 = native_rig._keyboard_home
	var query := PhysicsRayQueryParameters3D.create(native_rig.model.to_global(former_pin + Vector3(0, 0, .03)), native_rig.model.to_global(former_pin - Vector3(0, 0, .01)), carrier._hand.occlusion.collision_layer)
	query.collide_with_areas = true; query.collide_with_bodies = false
	# Positive control proves the changed private pick layer is actually being
	# queried; an empty retired-pin ray alone could pass with the wrong mask.
	var fixed_area: Area3D = carrier._hand.occlusion
	var triangles: PackedVector3Array = fixed_area.get_child(0).shape.get_faces()
	var fixed_hit := false
	for triangle in range(0, mini(triangles.size(), 180), 3):
		var center := (triangles[triangle] + triangles[triangle+1] + triangles[triangle+2]) / 3.0
		var normal := (triangles[triangle+1]-triangles[triangle]).cross(triangles[triangle+2]-triangles[triangle]).normalized()
		if normal.length_squared() < .5: continue
		var probe := PhysicsRayQueryParameters3D.create(fixed_area.to_global(center + normal * .5), fixed_area.to_global(center - normal * .5), fixed_area.collision_layer)
		probe.collide_with_areas = true; probe.collide_with_bodies = false
		var hit := player.get_world_3d().direct_space_state.intersect_ray(probe)
		if hit.get("collider") == fixed_area: fixed_hit = true; break
	check(fixed_hit, "positive control reaches actual fixed stock through the private pick layer")
	var vacated: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	check(vacated.is_empty(), "retracted hinge leaves no stale fixed pick blocker at its vacated pin seat")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("actual_recall_face.png"))
	await key(KEY_E)
	var lens: MeshInstance3D = carrier.device.teletype.torch_lens
	player._carry_service_light(.016)
	check(player._hand.global_position.distance_to(lens.to_global(lens.mesh.get_aabb().get_center())) < .00001, "real lamp originates at native lens instead of the player's eye")
	check(player.flashlight.get_parent() == player._hand, "original player lamp remains the only light owner")
	var output: Transform3D = carrier.world_lamp_transform()
	check((-output.basis.z).dot((carrier.motion.light_target-output.origin).normalized()) > .9999,
		"framed companion lamp converges from its native aperture on the authoritative reticle target")
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

func drag(amount: Vector2) -> void:
	Input.flush_buffered_events()
	await RenderingServer.frame_post_draw
	await super.drag(amount)

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
			if target.get("part") == part:
				# OS pointer warps can arrive after process_frame. Flush only before
				# acquisition, then require the same authoritative hit in a rendered
				# frame; never hide a blocker or fabricate the grab descriptor.
				await RenderingServer.frame_post_draw
				Input.flush_buffered_events()
				await get_tree().physics_frame
				if player._grab.find_target().get("part") == part: return true
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
