extends "res://tests/carried_case_route_test.gd"
## Shoe Rebuilding in the production V2 root with real input: the real hand buys half soles, the
## boots stand on the bench and the player is in slippers, a click grabs them, motion slides them,
## short of the end they come back, and the whole way sends them off. They return the next day,
## the same stroke brings them home, and the steps are quieter on rubber.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")

func _init() -> void:
	route_label = "SHOE ROUTE"

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

func _drag(pixels: float) -> void:
	for _step in int(absf(pixels) / 6.0):
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(signf(pixels) * 6.0, 0)
		player._unhandled_input(motion)
		await get_tree().physics_frame

func _route() -> void:
	var clock := CampaignClock.new()
	clock.configure_date(1929, 2, 1, 12 * 60)
	var point: Node3D = world.shop_counters.get("shoe_bench")
	var counter: Node3D = world.shop_counters.get("shoe_rebuilding")
	var bench: Node3D = world.shoe_bench
	if not _require(point != null and counter != null and bench != null, "Shoe Rebuilding has a bench and a counter"): return
	_require("half_soles_rubber" in point.item_ids and "half_soles_leather" in point.item_ids, "the bench takes soles: %s" % [point.item_ids])
	_require("half_soles_rubber" not in counter.item_ids and "polish_tin" in counter.item_ids, "the counter sells the rest: %s" % [counter.item_ids])
	_require(ShoeSales.footwear() == "worn", "the boots start worn")
	world.get_node("CaretakerEconomy").book().cash = 300
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player

	player.global_position = point.global_position + Vector3(0, -1.03, 1.1)
	await get_tree().create_timer(0.4).timeout
	player.camera.look_at(point.global_position)
	await get_tree().physics_frame
	_require(not bench.boots.visible, "no boots on the bench before anyone pays")
	point.select(point.item_ids.find("half_soles_rubber"))
	_require(await hand._stroke(point.terminal, point.terminal.TRAVEL), "the real hand pays for rubber soles")
	await get_tree().physics_frame
	_require(str(ShoeSales.book().paid) == "rubber", "paying takes the order: %s" % [ShoeSales.book()])
	_require(bench.boots.visible, "the boots stand on the bench")
	_require(ShoeSales.footwear() == "slippers", "and the player is in slippers")
	await _capture_interaction("shoe_boots_on_bench")

	var at: Vector3 = bench.boots.global_position + Vector3.UP * 0.1
	var grip := await _aim(at)
	await _capture_interaction("shoe_boots_aimed")
	_require(grip.get("owner") == bench, "the ray reaches the boots: %s" % [grip])
	await _click()
	_require(player._grab.active() and is_zero_approx(bench.along), "a click grabs and does not move them")
	await _drag(-90.0)
	var moved: float = bench.along
	_require(moved > 0.1 and moved < bench.TRAVEL * bench.TAKEN_AT, "motion slides them part way: %f" % moved)
	_require(bench.boots.global_position.distance_to(at - Vector3.UP * 0.1) > 0.08, "and they really move")
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(1.2).timeout
	_require(is_zero_approx(bench.along) and str(ShoeSales.book().paid) == "rubber", "short of the end they come back")

	grip = await _aim(bench.boots.global_position + Vector3.UP * 0.1)
	await _click()
	await _drag(-320.0)
	_require(bench.along >= bench.TRAVEL * bench.TAKEN_AT, "the whole way reaches the finisher: %f" % bench.along)
	await _click()
	await get_tree().physics_frame
	_require(str(ShoeSales.book().away) == "rubber" and not bench.boots.visible, "and the shop has them: %s" % [ShoeSales.book()])
	_require(ShoeSales.footwear() == "slippers", "still in slippers")
	_require(not point.sales.transaction_status("half_soles_leather") == "available", "and there's no second pair to sole")

	clock.configure_date(1929, 2, 2, 12 * 60)
	await get_tree().create_timer(0.6).timeout
	bench.refresh()
	_require(bench.collectable() and bench.boots.visible, "the next day they're back at the far end")
	grip = await _aim(bench.boots.global_position + Vector3.UP * 0.1)
	await _capture_interaction("shoe_boots_far_end")
	await _click()
	await _drag(320.0)
	await _click()
	await get_tree().physics_frame
	_require(ShoeSales.footwear() == "rubber" and not bench.boots.visible, "brought home, on rubber: %s" % [ShoeSales.book()])

	var steps: AudioStreamPlayer = player.get_node_or_null("PlayerFootsteps")
	if _require(steps != null, "the player has footsteps"):
		player.mechanical_stimulus.emit(player.global_position, &"impulse", 0.5, Vector3.FORWARD, 0.42, &"floor")
		_require(steps.playing and is_equal_approx(steps.volume_db, steps.DECIBELS.rubber), "a step on rubber is quiet: %f" % steps.volume_db)
		ShoeSales.book().sole = "leather"
		player.mechanical_stimulus.emit(player.global_position, &"impulse", 0.5, Vector3.FORWARD, 0.42, &"floor")
		_require(is_equal_approx(steps.volume_db, steps.DECIBELS.leather), "and on leather it's louder: %f" % steps.volume_db)
		ShoeSales.book().sole = "rubber"

	var document: Variant = preload("res://scripts/game/reality_save_document.gd")
	_require(ShoeSales.valid(ShoeSales.book()), "the book is valid for a save")
	_require(not ShoeSales.valid({"sole": "gold", "paid": "", "away": "", "ready": 0}), "and a made-up sole isn't")
	_require(document != null, "save validation is present")
