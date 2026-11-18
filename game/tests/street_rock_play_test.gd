extends Node3D

const Play := preload("res://scripts/game/street_rock_play.gd")
const DRIVE_ORIGIN := Vector3(3.0, 0.02, 0.0)
var failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_solid(Vector3(0, -0.1, -2), Vector3(12, 0.2, 12))
	var player := PlayerController.new()
	add_child(player)
	var play := Play.new()
	add_child(play)
	play.setup(player)
	await _frames(20)

	var stone := play.add_stone(Vector3(0, 0.05, -0.75), 1.0, 0.0)
	var barrier := _solid(Vector3(0, 0.2, -0.4), Vector3(0.3, 0.4, 0.12))
	await _frames(4)
	await _press_kick()
	_check(play.links == 0 and absf(stone.linear_velocity.z) < 0.3, "a wall blocks a kick")
	barrier.queue_free()
	await _frames(4)

	_check(player.acquire_text_input(self), "fixture acquires protected text input")
	await _press_kick()
	_check(play.links == 0 and absf(stone.linear_velocity.z) < 0.3, "text input blocks a kick")
	player.release_text_input(self)
	await _press_kick()
	_check(play.links == 1 and play.pending == 20, "G starts a ground kick and scores it")
	_check(not play._combo_music.playing, "a single kick leaves the music quiet")
	_check(stone.linear_velocity.z < -1.0, "a real rigid body receives the kick")
	await get_tree().process_frame
	_check(play._hud.text.begins_with("Tony Rawks Pro Rock Kicker"), "the rock-kicking title is visible")
	var first_position := stone.position
	await _frames(12)
	_check(stone.position.distance_to(first_position) > 0.15, "the stone rolls away physically")

	var pop := play.add_stone(Vector3(0.26, 0.05, -0.7), 0.9, 0.0)
	player._set_crouched(true)
	await _frames(12)
	await _press_kick()
	player._set_crouched(false)
	_check(pop.linear_velocity.y > 1.0, "crouch and G pops a second stone up")
	_check(play.links >= 2 and play.pending >= 70, "different kicks link into one combo")
	_check(play._combo_music.playing and play._combo_music.bus == &"Nondiegetic", "the second kick starts ska on the music bus")
	await _frames(30)
	_check(play._variety.has("Air Spin"), "an actual airborne turn registers")
	await get_tree().create_timer(2.5).timeout
	_check(play.links == 0 and play.total > 140, "timeout banks a multiplied total")
	_check(not play._combo_music.playing, "ska fades out after banking")

	player.rotation.y = PI
	await _press_kick()
	_check(play.links == 0, "stones behind the player are ineligible")
	player.rotation.y = 0
	var bank := play.add_stone(Vector3(-0.2, 0.056, -0.7), 1.0, 0.5)
	_solid(Vector3(-0.37, 0.22, -1.37), Vector3(1.0, 0.44, 0.12))
	await _frames(4)
	await _press_kick()
	await _frames(30)
	_check(play._variety.has("Bank Shot"), "a physical wall impact registers")
	_check(bank.position.z > -1.31, "the wall keeps the stone in bounds")
	await get_tree().create_timer(2.5).timeout
	var pad_stone := play.add_stone(Vector3(0.2, 0.05, -0.63), 1.0, 0.0)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	Input.parse_input_event(button)
	await _frames(3)
	button.pressed = false
	Input.parse_input_event(button)
	_check(play.links == 1 and pad_stone.linear_velocity.z < -1.0, "controller B kicks in walking mode")
	await get_tree().create_timer(2.5).timeout

	var touch := TouchControls.new()
	add_child(touch)
	touch.set_enabled(true)
	player.touch_input = true
	play.bind_touch(touch)
	var touch_stone := play.add_stone(Vector3(0.1, 0.05, -0.66), 1.0, 0.0)
	await _frames(10)
	_check(touch._street_kick_available, "touch only offers its Kick control in reach")
	for control: Dictionary in touch._buttons:
		if control.action == "street_rock_kick":
			touch._press(0, control.centre)
	await _frames(4)
	_check(play.links == 1 and touch_stone.linear_velocity.z < -1.0, "the touch Kick control kicks")
	await get_tree().create_timer(2.5).timeout
	player.global_position = DRIVE_ORIGIN
	player.velocity = Vector3.ZERO
	await _frames(12)
	var drive := play.add_stone(DRIVE_ORIGIN + Vector3(0.0, 0.03, -1.35), 1.0, 0.0)
	Input.action_press(&"run")
	Input.action_press(&"move_forward")
	await _frames(9)
	await _press_kick()
	Input.action_release(&"move_forward")
	Input.action_release(&"run")
	_check(play._variety.has("Drive Kick") and drive.linear_velocity.z < -4.0, "a running approach delivers a drive kick")
	get_tree().quit(0 if failures == 0 else 1)


func _solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


func _press_kick() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_G
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(3)
	event = InputEventKey.new()
	event.physical_keycode = KEY_G
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print("STREET STONE %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		failures += 1
