extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## The carried case in the production V2 root, with real input events: the key
## opens it, a click grabs a stack, motion carries it, a click sets it down, a right
## click turns it, an occupied square refuses and the hand keeps it, and the key
## closes it and frees everything. Goods are seeded; a sale is not under test here.

func _init() -> void:
	route_label = "CARRIED CASE ROUTE"

func _prepare_player_start() -> void:
	player.velocity = Vector3.ZERO

func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	await get_tree().process_frame

func _press(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	await _motion(at)
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _screen(view: Node, x: float, y: float) -> Vector2:
	var cell := float(CarriedCase.data().cell)
	var size := Vector2(CarriedCase.grid()) * cell
	return view._camera.unproject_position(Vector3(-size.x * 0.5 + x * cell, 0.003, -size.y * 0.5 + y * cell))

func _route() -> void:
	var view: Node = world.carried_case_view
	if not _require(view != null, "the view is mounted"): return
	var names := {"chocolate": ["A bar of chocolate", "packet"], "flask": ["Cough syrup", "bottle"],
		"papers": ["The Borough Record", "flat"], "screwdriver": ["Screwdriver", "tool"],
		"tin": ["Pipe tobacco", "tin"], "valve": ["Long-life valve", "valve"], "parcel": ["Brown parcel", "parcel"],
		"jar": ["Cold cream", "jar"], "box": ["Soap flakes", "box"], "roll": ["Friction tape", "roll"], "card": ["Postal card", "card"]}
	for item: String in names:
		_require(PersonInventory.carry_goods(PersonInventory.PLAYER, item, names[item][0], names[item][1]), "seeds " + item)
	RealityState.commit()
	await _key(KEY_TAB)
	if not _require(view.opened and player.call_locked, "the key opens the case"): return
	await get_tree().create_timer(0.1).timeout
	var halfway: Vector3 = view._stacks["chocolate"].global_position
	await _capture_interaction("carried_case_opening")
	await get_tree().create_timer(0.7).timeout
	_require(view.settled, "the shelf settles open")
	_require(is_equal_approx(rad_to_deg(view._lid.rotation.x), 104.0), "the shelf folds forward to 104 degrees")
	var laid: Dictionary = CarriedCase.place_of("chocolate")
	var cell := float(CarriedCase.data().cell)
	var expected := Vector3(-0.25 + (float(laid.x) + 0.5) * cell, 0.0, -0.15 + (float(laid.y) + 0.5) * cell)
	var relative: Vector3 = view._stacks["chocolate"].global_transform.origin - view._lid.get_parent().global_transform.origin
	_require(relative.distance_to(expected) < 0.001, "open goods lie on their square: %s" % [relative - expected])
	_require(halfway.distance_to(view._stacks["chocolate"].global_position) > 0.01, "goods ride with the shelf")
	for assembly: String in view._stays:
		_require(view._stays[assembly].get_child_count() > 0, assembly + " is bound")
	var upper: Node3D = view._stays["Stay_Port_Upper"]
	var lower: Node3D = view._stays["Stay_Port_Lower"]
	var knee_gap: float = (upper.position + upper.basis.y * 0.2 - lower.position).length()
	_require(knee_gap < 0.004, "the two links of a stay meet at the knee: %f" % knee_gap)
	await _capture_interaction("carried_case_open")
	var place: Dictionary = CarriedCase.place_of("chocolate").duplicate()
	var from := _screen(view, float(place.x) + 0.5, float(place.y) + 0.5)
	await _press(from)
	_require(view.held_item == "chocolate", "a click grabs the stack under the cursor")
	var free_cell := Vector2i(-1, -1)
	for y in 6:
		for x in 10:
			if free_cell.x < 0 and CarriedCase.fits("chocolate", "packet", x, y, false) and Vector2i(x, y) != Vector2i(int(place.x), int(place.y)):
				free_cell = Vector2i(x, y)
	_require(free_cell.x >= 0, "the arrangement leaves a free square")
	var to := _screen(view, free_cell.x + 0.5, free_cell.y + 0.5)
	await _motion(to)
	await _capture_interaction("carried_case_held")
	await _press(to)
	_require(view.held_item == "", "the next click sets it down")
	var moved := CarriedCase.place_of("chocolate")
	_require(int(moved.x) == free_cell.x and int(moved.y) == free_cell.y, "it lies on the square it was set on")
	_require(CarriedCase.valid(RealityState.data[CarriedCase.KEY]), "the arrangement stays valid")
	# Occupied squares refuse and the hand keeps it.
	var other := CarriedCase.place_of("flask")
	await _press(to)
	await _press(_screen(view, float(other.x) + 0.5, float(other.y) + 0.5))
	_require(view.held_item == "chocolate", "an occupied square refuses and the hand keeps it")
	await _press(to)
	# A right click turns what is held.
	var flask := CarriedCase.place_of("flask")
	var was_turned := bool(flask.turned)
	await _press(_screen(view, float(flask.x) + 0.5, float(flask.y) + 0.5))
	await _press(_pointer_free(view), MOUSE_BUTTON_RIGHT)
	_require(view._held_turned != was_turned, "a right click turns the held stack")
	await _press(_pointer_free(view))
	if view.held_item != "":
		await _press(_screen(view, float(flask.x) + 0.5, float(flask.y) + 0.5), MOUSE_BUTTON_RIGHT)
		await _press(_screen(view, float(flask.x) + 0.5, float(flask.y) + 0.5))
	_require(view.held_item == "", "the turned stack can be set down")
	await _capture_interaction("carried_case_rearranged")
	# Closing with a stack in the hand returns it to its saved square.
	var returned: Dictionary = CarriedCase.place_of("chocolate").duplicate()
	await _press(_screen(view, float(returned.x) + 0.5, float(returned.y) + 0.5))
	_require(view.held_item == "chocolate", "a stack is in the hand before closing")
	await _key(KEY_TAB)
	await get_tree().create_timer(0.1).timeout
	await _capture_interaction("carried_case_closing")
	await get_tree().create_timer(0.5).timeout
	_require(CarriedCase.place_of("chocolate") == returned, "closing returns a held stack")
	_require(not view.opened and not player.call_locked, "the key closes it and returns the player")
	_require(view.get_child_count() == 0, "nothing of it stays built while closed")

func _pointer_free(view: Node) -> Vector2:
	for y in 6:
		for x in 9:
			if CarriedCase.fits(view.held_item, str(CarriedCase.place_of(view.held_item).form), x, y, view._held_turned):
				return _screen(view, x + 0.5 * float(CarriedCase.form_size(str(CarriedCase.place_of(view.held_item).form), view._held_turned).x),
						y + 0.5 * float(CarriedCase.form_size(str(CarriedCase.place_of(view.held_item).form), view._held_turned).y))
	return Vector2.ZERO
