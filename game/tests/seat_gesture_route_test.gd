extends "res://tests/carried_case_route_test.gd"
## Sitting in the production V2 root with real input: a click grabs the seat without
## moving the body, motion lowers it, the next click finishes it, walking is held while
## looking and reaching are not, and both the grip and the walking keys stand back up.

const STOOL := "storm_shop_luncheonette_stool2"

var seats: Node3D

func _init() -> void:
	route_label = "SEAT GESTURE ROUTE"

func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	await get_tree().physics_frame

func _drag(pixels: float) -> void:
	for _step in int(absf(pixels) / 6.0):
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(0, signf(pixels) * 6.0)
		player._unhandled_input(motion)
		await get_tree().physics_frame

func _aim_seat(identity: String) -> Dictionary:
	var at: Vector3 = seats.seats[identity].area.global_position
	player.camera.look_at(at)
	await get_tree().physics_frame
	player.camera.look_at(at)
	return player._grab.find_target()

func _sit_on(identity: String) -> void:
	var seat: Node3D = seats.seats[identity].area
	var there: Vector3 = seat.global_position
	var floor_hit := {}
	for side: Vector3 in [Vector3(0.75, 0, 0), Vector3(-0.75, 0, 0), Vector3(0, 0, 0.75), Vector3(0, 0, -0.75)]:
		var from := there + side + Vector3.UP * 0.6
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.2)
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
		player.global_position = there + side + Vector3.UP * 0.2
		await get_tree().create_timer(2.5).timeout
		query = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.2)
		hit = player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.position.y < there.y - 0.3:
			floor_hit = hit
			player.global_position = hit.position
			break
	if not _require(not floor_hit.is_empty(), "room to stand beside " + identity): return
	await get_tree().create_timer(0.5).timeout
	player.camera.rotation = Vector3.ZERO
	var stand: Vector3 = player.global_position
	var grip: Dictionary = await _aim_seat(identity)
	if not _require(grip.get("owner") == seats and grip.get("part") == seat, "the cursor finds %s: %s" % [identity, str(player._grab.last_hit.get("collider"))]): return
	await _click()
	await _drag(190.0)
	await _click()
	await get_tree().create_timer(0.3).timeout
	_require(seats.sitting(), "seated on " + identity)
	player.camera.rotation = Vector3(-0.15, 0, 0)
	await _capture_interaction("sit_" + identity)
	grip = await _aim_seat(identity)
	_require(grip.get("part") == seat, "the seat is under the hand on " + identity)
	await _click()
	await _drag(-190.0)
	await _click()
	await get_tree().create_timer(0.3).timeout
	_require(player.seated_on == null and player.global_position.distance_to(stand) < 0.02, "up again from " + identity)

func _route() -> void:
	seats = world.seat_gestures
	if not _require(seats != null and seats.seats.has(STOOL), "stools are seats: %d seats" % seats.seats.size()): return
	for identity: String in ["retail_bar_stool2", "retail_bar_ch0_0", "storm_shop_otis___son_stool1", "storm_shop_news_cigars_stool"]:
		_require(seats.seats.has(identity), "a seat at " + identity)
	_require(not seats.seats.has("4B_desk_chair"), "the call desk keeps its own chair")
	for prefix: String in ["storm_shop_luncheonette_stool", "storm_shop_otis___son_stool"]:
		_require(seats.seats.keys().filter(func(id): return id.begins_with(prefix)).size() == 3, "three stools at " + prefix)

	var counter: Node3D = world.luncheonette_counter
	var area: Node3D = seats.seats[STOOL].area
	var floor_y := float(counter.global_position.y) - 1.12
	player.global_position = Vector3(area.global_position.x - 0.8, floor_y + 0.1, area.global_position.z)
	await get_tree().create_timer(0.4).timeout
	var stand_at: Vector3 = player.global_position
	var eye: float = player.camera.global_position.y
	await _capture_interaction("seat_before")

	var grip: Dictionary = await _aim_seat(STOOL)
	_require(grip.get("owner") == seats and grip.get("part") == area, "the player's ray finds the seat: %s" % str(grip.get("part")))
	await _click()
	_require(player._grab.active() and player.global_position.distance_to(stand_at) < 0.001, "a click grabs and does not move the body")
	await _drag(60.0)
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(0.8).timeout
	_require(player.seated_on == null and player.global_position.distance_to(stand_at) < 0.01, "let go early, the body stands back up")
	_require(absf(player.camera.global_position.y - eye) < 0.01, "and the eye comes back")

	grip = await _aim_seat(STOOL)
	await _click()
	await _drag(190.0)
	_require(absf(float(grip.read.call()) - 1.0) < 0.001, "motion lowers the body the whole way: %f" % float(grip.read.call()))
	await _click()
	await get_tree().create_timer(0.3).timeout
	_require(seats.sitting(), "seated")
	var seat_top: float = area.global_position.y
	_require(absf(player.camera.global_position.y - (seat_top + seats.EYE_ABOVE_SEAT)) < 0.01, "the eye is above the seat: %f" % player.camera.global_position.y)
	_require(Vector2(player.global_position.x - area.global_position.x, player.global_position.z - area.global_position.z).length() < 0.01, "the body is on the stool")
	_require(absf(wrapf(player.rotation.y + PI * 0.5, -PI, PI)) < 0.01, "facing the counter: %f" % player.rotation.y)
	var pitch: float = player.camera.rotation.x
	player.camera.rotation = Vector3(-0.2, 0, 0)
	await _capture_interaction("seat_seated")
	player.camera.rotation.x = pitch
	var yaw_before: float = player.rotation.y
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(40, 0)
	player.apply_look(look.relative)
	_require(not is_equal_approx(yaw_before, player.rotation.y), "looking around still works")

	# Reaching: the cup on the counter is grabbed from the stool.
	RealityState.data[counter.KEY] = {"cup": 3.0, "plate": 0.0}
	counter.refresh()
	player.camera.look_at(counter.parts.cup.global_position + Vector3.UP * 0.04)
	await get_tree().physics_frame
	player.camera.look_at(counter.parts.cup.global_position + Vector3.UP * 0.04)
	_require(player._grab.find_target().get("part") == counter.parts.cup, "the cup is in reach from the stool")
	RealityState.data[counter.KEY] = {"cup": 0.0, "plate": 0.0}
	counter.refresh()

	# Up by the same grip.
	grip = await _aim_seat(STOOL)
	_require(grip.get("part") == area, "the seat is still under the hand")
	await _click()
	await _drag(-190.0)
	await _click()
	await get_tree().create_timer(0.3).timeout
	_require(player.seated_on == null and player.global_position.distance_to(stand_at) < 0.01, "pushing up stands back up where the body came from")

	# Up by walking.
	grip = await _aim_seat(STOOL)
	await _click()
	await _drag(190.0)
	await _click()
	await get_tree().create_timer(0.2).timeout
	_require(seats.sitting(), "seated again")
	Input.action_press("move_forward")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("move_forward")
	_require(player.seated_on == null, "a walking key stands up")

	# A resident's stool and a far one are not offered, and hide nothing behind them.
	seats.taken[STOOL] = "iris_bell"
	player.global_position = stand_at
	await get_tree().physics_frame
	grip = await _aim_seat(STOOL)
	_require(grip.get("part") != area, "a taken stool cannot be grabbed")
	seats.taken.erase(STOOL)
	player.global_position = stand_at + Vector3(-1.5, 0, 0)
	await get_tree().physics_frame
	grip = await _aim_seat(STOOL)
	_require(grip.get("part") != area, "a seat is not sat on from across the room")

	# Something else moving the body ends the seat rather than fighting it.
	player.global_position = stand_at
	await get_tree().physics_frame
	grip = await _aim_seat(STOOL)
	await _click()
	await _drag(190.0)
	await _click()
	await get_tree().create_timer(0.2).timeout
	player.global_position = stand_at + Vector3(-3, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_require(player.seated_on == null, "a teleport lets go of the seat")
	_require(absf(player.camera.position.y - player.STANDING_EYE) < 0.01, "and the eye is reset")

	# A real sit on each sort of seat, where it stands in the world.
	for identity: String in ["retail_bar_stool2", "retail_bar_ch0_0", "storm_shop_news_cigars_stool", "storm_shop_otis___son_stool1", "2A_din_dc1", "3B_stool", "5C_bed_chair"]:
		if not seats.seats.has(identity):
			print("SEAT ABSENT " + identity)
			continue
		await _sit_on(identity)

	# One chair upstairs, through its own resolved node.
	var domestic := 0
	for identity: String in seats.seats:
		if not identity.begins_with("storm_") and not identity.begins_with("retail_"):
			domestic += 1
	_require(domestic >= 30, "the household chairs are seats: %d" % domestic)
