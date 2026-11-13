extends Node3D
## Actual directional/primary input and capsule, fitted leaves, diagnostic jambs.
const ErrorCapture := preload("res://tests/guide_bell_error_capture.gd")
var checks := 0
var failures: Array[String] = []
var player: PlayerController
var previous := Vector3.INF
var watching := false
var tracked_door: DoorProp
var max_step := 0.0
var started := Time.get_ticks_msec()

func check(ok: bool, label: String) -> void:
	checks += 1; print("DOOR PASSAGE: ", label, " = ", ok)
	if not ok: failures.append(label)

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	player._unhandled_input(event)

func drag(x: float) -> void:
	var event := InputEventMouseMotion.new(); event.relative = Vector2(x, 0)
	player._unhandled_input(event)

func make_door() -> DoorProp:
	return preload("res://scripts/building/orison_v2_fitted_door.gd").new()

func inspect_door(_door: DoorProp, _swing: bool) -> void:
	pass

func _ready() -> void: _run.call_deferred()

func _block(at: Vector3, size: Vector3, parent: Node3D = null) -> StaticBody3D:
	if parent == null: parent = self
	var body := StaticBody3D.new(); parent.add_child(body); body.position = at
	var collision := CollisionShape3D.new(); var box := BoxShape3D.new()
	box.size = size; collision.shape = box; body.add_child(collision)
	return body

func _place(door: DoorProp, side: float) -> void:
	watching = false; player._door_passage.reset()
	player.global_position = door.to_global(Vector3(door.width * .35, .02, side * .8))
	player.global_rotation = Vector3(0, door.global_rotation.y + (0.0 if side > 0 else PI), 0)
	player.camera.rotation = Vector3.ZERO; player.velocity = Vector3.ZERO
	previous = player.global_position; tracked_door = door

func _drive(door: DoorProp, side: float, seconds := 4.0) -> bool:
	previous = player.global_position; watching = true
	Input.action_press("move_forward")
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	var crossed := false
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if door.to_local(player.global_position).z * side < -(door.width + .6) and not player._door_passage.active():
			crossed = true; break
	Input.action_release("move_forward")
	await get_tree().physics_frame; watching = false
	return crossed

func _settle(door: DoorProp) -> void:
	var deadline := Time.get_ticks_msec() + 2500
	while (door._moving or door._key_turning) and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	check(not door._moving and not door._key_turning, "bounded leaf/key motion settles")

func _physics_process(delta: float) -> void:
	if not watching or player == null: return
	var distance := player.global_position.distance_to(previous)
	max_step = maxf(max_step, distance)
	if distance > player.WALK * delta * 1.25 + .035: check(false, "continuous ordinary-speed movement")
	if is_instance_valid(tracked_door) and player.get_collision_exceptions().has(tracked_door._body):
		check(false, "real door collision remains enabled")
	previous = player.global_position

func _run() -> void:
	var logger := ErrorCapture.new(); OS.add_logger(logger)
	var prior_data: Dictionary = RealityState.data
	var preview := RealityState.begin_preview_campaign(self)
	check(preview, "nonpersistent preview protects original campaign")
	if not preview: get_tree().quit(2); return
	var prior_mouse := Input.mouse_mode
	_block(Vector3(0, -.1, 0), Vector3(24, .2, 24))
	player = PlayerController.new(); add_child(player); player.camera.make_current()
	player.set_lamp_enabled(false); player.set_beam_mask_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, -30, 0); add_child(sun)
	for swing: bool in [false, true]:
		var door := make_door(); door.name = "GuidedDoor" + str(swing)
		door.swing_out = swing; door.position.x = 4.0 if swing else 0.0
		door.rotation.y = .6 if swing else 0.0; add_child(door)
		_block(Vector3(-.2, 1.2, 0), Vector3(.4, 2.4, .3), door)
		_block(Vector3(door.width + .2, 1.2, 0), Vector3(.4, 2.4, .3), door)
		_block(Vector3(door.width * .5, door.height + .15, 0), Vector3(door.width, .3, .3), door)
		for side: float in [-1.0, 1.0]:
			_place(door, side); door.restore_mechanism({"angle": 0.0})
			await get_tree().physics_frame; await get_tree().physics_frame
			await inspect_door(door, swing)
			var look := player.camera.rotation
			check(await _drive(door, side), "directional input clears frame and leaf: swing=%s side=%s" % [swing, side])
			check(player.camera.rotation.is_equal_approx(look), "guidance never rotates view")
			check(not player._door_passage.active(), "normal control released after clearance")
			check(not player.get_collision_exceptions().has(door._body), "no leaf collision exemption")
			check(door.open, "passed door remains open")
		await get_tree().create_timer(4.2).timeout
		check(door.open and absf(door._body.rotation.y - door.motion_target_angle(true)) < .03, "no hidden closer")
		player.global_position = door._body.to_global(Vector3(door.width * .5, 0, 1.5))
		player.camera.look_at(door._body.to_global(Vector3(door.width * .5, 1.05, 0)))
		await get_tree().physics_frame; click(); await _settle(door)
		check(not door.open and not player._grab.active(), "primary click explicitly closes door")
		# The open leaf's face-on stance is beside the closed frame; its jamb
		# correctly blocks a diagonal key ray. Approach the closed key barrel.
		player.global_position = door.to_global(Vector3(door.width * .5, .02, 1.4))
		player.velocity = Vector3.ZERO
		player.camera.look_at(door._body.to_global(Vector3(door.width - .085, .89, door._hinge_offset)))
		await get_tree().physics_frame; await get_tree().physics_frame
		var key_ray := PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position - player.camera.global_basis.z * 2.1)
		key_ray.collide_with_areas = true; key_ray.exclude = [player.get_rid()]
		var key_hit := get_world_3d().direct_space_state.intersect_ray(key_ray)
		check(key_hit.get("collider") == door._body.get_node("KeyholeControl"), "actual key ray reaches barrel without excluding frame")
		click(); await _settle(door)
		check(door.leaf_state == "locked", "keyhole click explicitly locks door")
		click(); await _settle(door)
		check(door.leaf_state == "closed", "keyhole click explicitly unlocks door")
		Input.action_press("door_key")
		await get_tree().process_frame; await get_tree().process_frame
		Input.action_release("door_key"); await _settle(door)
		check(door.leaf_state == "locked", "existing keyboard key control reaches barrel owner")
		click(); await _settle(door)
		check(door.leaf_state == "closed", "primary click unlocks after keyboard operation")
		_place(door, 1.0)
		var obstacle := _block(Vector3(door.width * .5, 1.0, 0), Vector3(door.width, 2, .15), door)
		await get_tree().physics_frame
		check(not (await _drive(door, 1.0, 2.0)), "real obstruction refuses transit")
		check(door.to_local(player.global_position).z > .2, "no teleport through barrier")
		obstacle.free()
		door.restore_mechanism({"angle": 0.0}); _place(door, -1.0)
		Input.action_press("move_forward"); await get_tree().physics_frame; await get_tree().physics_frame
		Input.action_release("move_forward"); await get_tree().physics_frame; await get_tree().physics_frame
		check(not player._door_passage.active(), "releasing direction cancels guide")
		Input.action_press("move_back"); await get_tree().physics_frame; await get_tree().physics_frame
		check(not player._door_passage.active(), "reverse direction retains normal movement")
		Input.action_release("move_back"); door.free()
	var locked := make_door(); locked.name = "PrivateNoKey"; locked.unit = "6C"; locked.leaf_state = "locked"; add_child(locked)
	_place(locked, 1.0); await get_tree().physics_frame
	check(not DoorKeyring.player_has_key(locked), "negative control has no key")
	check(not (await _drive(locked, 1.0, 1.0)) and locked.leaf_state == "locked" and not locked.open, "directional input preserves private lock")
	locked.free()
	var own := make_door(); own.name = "PlayerKeyPassage"; own.unit = DoorKeyring.player_unit()
	own.leaf_state = "locked"; add_child(own); _place(own, -1.0)
	await get_tree().physics_frame
	check(DoorKeyring.player_has_key(own), "positive directional control carries actual own key")
	check(await _drive(own, -1.0), "direction alone unlocks and crosses with actual own key")
	check(own.leaf_state != "locked" and DoorKeyring.initial_state(own, "locked") == "closed", "automatic player unlock remains remembered after transit")
	own.restore_mechanism({"angle": own.motion_target_angle(true) * .25}); _place(own, 1.0)
	await get_tree().physics_frame
	check(await _drive(own, 1.0), "direction resumes a partial saved opening and crosses")
	own.restore_mechanism({"angle": 0.0}); _place(own, -1.0)
	Input.action_press("move_forward"); await get_tree().physics_frame; await get_tree().physics_frame
	check(player._door_passage.active(), "guide owns an active approach before dialogue")
	player.call_locked = true; await get_tree().physics_frame; await get_tree().physics_frame
	check(not player._door_passage.active() and not own.passage_held(), "dialogue takeover immediately releases guide and closer hold")
	Input.action_release("move_forward"); player.call_locked = false
	_place(own, -1.0); Input.action_press("move_forward")
	await get_tree().physics_frame; await get_tree().physics_frame
	check(player._door_passage.active(), "guide active before household restore cancellation")
	player.cancel_manipulation()
	check(not player._door_passage.active() and not own.passage_held(), "household restore cancellation releases transient doorway custody")
	Input.action_release("move_forward")
	own.free(); watching = false; player.free(); player = null
	check(RealityState.end_preview_campaign(self) and is_same(prior_data, RealityState.data), "original campaign restored")
	Input.mouse_mode = prior_mouse
	check(logger.errors.is_empty(), "no engine errors: " + str(logger.errors)); OS.remove_logger(logger)
	_write_contract()
	print("DOOR PASSAGE PLAYER: ", "PASS" if failures.is_empty() else "FAIL", "; ", checks, " checks; ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func _write_contract() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	var sources := {}
	for path: String in [get_script().resource_path, "res://scripts/player/door_passage_guide.gd", "res://scripts/player/player_controller.gd", "res://scripts/props/door_prop.gd", "res://scripts/props/easy_door_motion.gd"]:
		sources[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	var passed := failures.is_empty()
	var receipt := {"schema_version": 2, "evidence_kind": "runtime_contract", "production_runtime": false, "selector": "v2",
		"scope": "Actual player directional and primary input, capsule, fitted doors and diagnostic floor/frame/obstacle. No occupied building, NPC or mechanical closer qualification.",
		"execution": {"completed": true, "exit_code": 0 if passed else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started) / 1000.0},
		"source": {"inputs": sources}, "checks": checks, "failures": failures, "max_step": max_step,
		"contracts": {"directional_passage": {"executed": true, "status": "PASS" if passed else "FAIL"}}}
	FileAccess.open(directory.path_join("runtime_contract.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt, "\t"))
