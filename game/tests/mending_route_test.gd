extends "res://tests/carried_case_route_test.gd"
## Lena's mending counter in the production V2 root with real input: the real hand pays, the coat
## slides along the counter to her end, and it comes back the next day. Four weeks on the cuffs have
## gone, and washing doesn't help. She stands there on weekday afternoons and not otherwise.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")


func _init() -> void:
	route_label = "MENDING ROUTE"


func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	player._unhandled_input(click)
	await get_tree().physics_frame


func _aim(at: Vector3) -> Dictionary:
	player.camera.look_at(at)
	await get_tree().physics_frame
	player.camera.look_at(at)
	return player._grab.find_target()


func _push(pixels: float) -> void:
	for _step in int(absf(pixels) / 6.0):
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(signf(pixels) * 6.0, 0)
		player._unhandled_input(motion)
		await get_tree().physics_frame


func _route() -> void:
	var clock := CampaignClock.new()
	clock.configure_date(1929, 2, 1, 15 * 60) # A Friday.
	var point: Node3D = world.shop_counters.get("model_laundry")
	var counter: Node3D = world.mending_counter
	if not _require(point != null and counter != null, "the Laundry has a terminal and a mending end"): return
	_require(point.item_ids.has(LaundrySales.MENDING), "the terminal offers mending: %s" % [point.item_ids])
	_require(not LaundrySales.frayed(), "the cuffs start whole")
	world.get_node("CaretakerEconomy").book().cash = 300
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player

	_require(str(world.resident_whereabouts("lena_ortiz").get("place", "")) == counter.PLACE, "the timetable has her at the Laundry: %s" % [world.resident_whereabouts("lena_ortiz")])
	counter.attend()
	_require(counter.lena != null and counter.lena._model != null, "and her body stands at the counter")
	_require(counter.lena.has_method("interact"), "and she can be spoken to")
	var route: Node = world.resident_routes.get("lena_ortiz")
	await get_tree().create_timer(0.5).timeout
	_require(route._leaves_unseen(), "the walking body isn't in the building meanwhile")

	var floor_y: float = counter.global_position.y - 1.05
	player.global_position = counter.to_global(Vector3(-0.9, 0, 0)) * Vector3(1, 0, 1) + Vector3.UP * floor_y
	await get_tree().create_timer(0.4).timeout
	point.select(1)
	var at_terminal: Vector3 = point.global_position
	player.global_position = at_terminal - point.global_basis.z * 0.95 + Vector3(0, -1.03, 0)
	await get_tree().create_timer(0.4).timeout
	player.camera.look_at(at_terminal)
	await get_tree().physics_frame
	_require(await hand._stroke(point.terminal, point.terminal.TRAVEL), "the real hand pays for mending")
	await get_tree().physics_frame
	_require(bool(LaundrySales.book(counter.job).paid), "paying takes the order: %s" % [LaundrySales.book(counter.job)])
	_require(counter.bundle.visible, "the coat lies on the counter")
	_require(point.sales.transaction_status(LaundrySales.UNIFORM) == "out_of_stock", "and it can't go to the wash as well")

	player.global_position = counter.to_global(Vector3(-0.9, 0, 0)) * Vector3(1, 0, 1) + Vector3.UP * floor_y
	await get_tree().create_timer(0.3).timeout
	var grip := await _aim(counter.bundle.global_position + Vector3.UP * 0.05)
	await _capture_interaction("mending_counter")
	_require(grip.get("owner") == counter, "the ray reaches the coat: %s" % [grip])
	await _click()
	_require(player._grab.active() and is_zero_approx(counter.along), "a click grabs and doesn't move it")
	await _push(-60.0)
	var moved: float = counter.along
	_require(moved > 0.05 and moved < counter.TRAVEL * counter.TAKEN_AT, "motion slides it part way: %f" % moved)
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(1.0).timeout
	_require(is_zero_approx(counter.along) and bool(LaundrySales.book(counter.job).paid), "short of her end it comes back")
	grip = await _aim(counter.bundle.global_position + Vector3.UP * 0.05)
	await _click()
	await _push(-260.0)
	_require(counter.along >= counter.TRAVEL * counter.TAKEN_AT, "the whole way reaches her: %f" % counter.along)
	await _capture_interaction("mending_at_lena")
	await _click()
	await get_tree().physics_frame
	_require(bool(LaundrySales.book(counter.job).away) and not counter.bundle.visible, "and she has it: %s" % [LaundrySales.book(counter.job)])

	clock.configure_date(1929, 2, 2, 12 * 60) # A Saturday.
	await get_tree().create_timer(0.6).timeout
	counter.refresh()
	counter.attend()
	await get_tree().physics_frame
	_require(counter.lena == null, "on Saturday she isn't there")
	_require(LaundrySales.collectable(counter.job) and counter.bundle.visible, "but the coat is back at her end")
	grip = await _aim(counter.bundle.global_position + Vector3.UP * 0.05)
	await _click()
	await _push(260.0)
	await _click()
	await get_tree().physics_frame
	_require(not LaundrySales.book(counter.job).away and not counter.bundle.visible, "brought home: %s" % [LaundrySales.book(counter.job)])
	_require(not LaundrySales.frayed(), "mended")

	LaundrySales.book().washed = LaundrySales.day() + 27
	clock.configure_date(1929, 3, 1, 12 * 60)
	_require(not LaundrySales.frayed(), "twenty-seven days on it holds")
	_require(LaundrySales.presentable(), "and passes with a clean wash")
	clock.configure_date(1929, 3, 2, 12 * 60)
	LaundrySales.book().washed = LaundrySales.day()
	_require(LaundrySales.frayed() and not LaundrySales.presentable(), "four weeks on the cuffs have gone, however clean it is")
	_require(LaundrySales.valid(LaundrySales.book(counter.job)), "the book is valid for a save")
