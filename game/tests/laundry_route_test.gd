extends "res://tests/carried_case_route_test.gd"
## The Model Laundry in the production V2 root with real input: the real hand pays for a wash, the
## bundle stands on the counter, a click grabs it, motion pushes it, short of the end it comes back,
## and the whole way hands it over. It returns the next day and the same stroke brings it home
## clean. A week later the uniform is dirty, and that costs one point at first contact only.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")

func _init() -> void:
	route_label = "LAUNDRY ROUTE"

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
		motion.relative = Vector2(0, signf(pixels) * 6.0)
		player._unhandled_input(motion)
		await get_tree().physics_frame

func _route() -> void:
	var clock := CampaignClock.new()
	clock.configure_date(1929, 2, 1, 12 * 60)
	var point: Node3D = world.shop_counters.get("model_laundry")
	var counter: Node3D = world.laundry_bundle
	if not _require(point != null and counter != null, "the Laundry has a terminal and a bundle"): return
	_require(point.item_ids == [LaundrySales.UNIFORM], "the terminal offers the uniform: %s" % [point.item_ids])
	_require(LaundrySales.presentable(), "the uniform starts clean")
	world.get_node("CaretakerEconomy").book().cash = 300
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player

	player.global_position = point.global_position - point.global_basis.z * 0.95 + Vector3(0, -1.03, 0)
	await get_tree().create_timer(0.4).timeout
	player.camera.look_at(point.global_position)
	await get_tree().physics_frame
	await _capture_interaction("laundry_terminal")
	_require(not counter.bundle.visible, "no bundle before anyone pays")
	point.select(0)
	_require(await hand._stroke(point.terminal, point.terminal.TRAVEL), "the real hand pays for a wash")
	await get_tree().physics_frame
	_require(bool(LaundrySales.book().paid), "paying takes the order: %s" % [LaundrySales.book()])
	_require(counter.bundle.visible, "the bundle stands on the counter")
	_require(not LaundrySales.presentable(), "and the uniform is off your back")

	player.global_position = counter.global_position + Vector3(-0.85, -1.05, 0)
	await get_tree().create_timer(0.3).timeout
	var at: Vector3 = counter.bundle.global_position + Vector3.UP * 0.05
	var grip := await _aim(at)
	await _capture_interaction("laundry_bundle")
	_require(grip.get("owner") == counter, "the ray reaches the bundle: %s" % [grip])
	await _click()
	_require(player._grab.active() and is_zero_approx(counter.along), "a click grabs and does not move it")
	await _push(-60.0)
	var moved: float = counter.along
	_require(moved > 0.05 and moved < counter.TRAVEL * counter.TAKEN_AT, "motion pushes it part way: %f" % moved)
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(1.0).timeout
	_require(is_zero_approx(counter.along) and bool(LaundrySales.book().paid), "short of the end it comes back")

	grip = await _aim(counter.bundle.global_position + Vector3.UP * 0.05)
	await _click()
	await _push(-260.0)
	_require(counter.along >= counter.TRAVEL * counter.TAKEN_AT, "the whole way reaches the back: %f" % counter.along)
	await _click()
	await get_tree().physics_frame
	_require(bool(LaundrySales.book().away) and not counter.bundle.visible, "and the shop has it: %s" % [LaundrySales.book()])
	_require(point.sales.transaction_status(LaundrySales.UNIFORM) == "out_of_stock", "and there's no second uniform to wash")

	clock.configure_date(1929, 2, 2, 12 * 60)
	await get_tree().create_timer(0.6).timeout
	counter.refresh()
	_require(LaundrySales.collectable() and counter.bundle.visible, "the next day it's back at the far edge")
	grip = await _aim(counter.bundle.global_position + Vector3.UP * 0.05)
	await _capture_interaction("laundry_bundle_ready")
	await _click()
	await _push(260.0)
	await _click()
	await get_tree().physics_frame
	_require(LaundrySales.presentable() and not counter.bundle.visible, "brought home, clean: %s" % [LaundrySales.book()])

	clock.configure_date(1929, 2, 8, 12 * 60)
	_require(LaundrySales.presentable(), "six days on it still passes")
	clock.configure_date(1929, 2, 9, 12 * 60)
	_require(not LaundrySales.presentable(), "a week on it doesn't")

	var talk: ResidentConversations = world.conversations
	const FIRST := "omar_bell"
	var before := RealityState.resident_trust(FIRST)
	RealityState.record_conversation_visit(FIRST)
	talk._record(FIRST, "", 2)
	_require(RealityState.resident_trust(FIRST) == before + 1, "a dirty uniform takes one point of a first warm reply")
	talk._record(FIRST, "", 2)
	_require(RealityState.resident_trust(FIRST) == before + 3, "and only the once")
	const OTHER := "cal_dwyer"
	var other_before := RealityState.resident_trust(OTHER)
	RealityState.record_conversation_visit(OTHER)
	talk._record(OTHER, "", -1)
	_require(RealityState.resident_trust(OTHER) == other_before - 1, "and it adds nothing to a cold one")

	_require(LaundrySales.valid(LaundrySales.book()), "the book is valid for a save")
	_require(not LaundrySales.valid({"washed": 0, "paid": "yes", "away": false, "ready": 0}), "and a made-up one isn't")
