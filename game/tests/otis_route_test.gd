extends "res://tests/carried_case_route_test.gd"
## Otis & Son in the production V2 root with real input: the real hand orders at the
## fountain, the cup comes up empty, a click grabs the tap handle, motion opens it and
## the cup fills only while it is open, it springs back on release, the cup is lifted
## by hand and goes down only at the mouth, and the main counter sells the rest.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")
const Fountain := preload("res://scripts/props/otis_fountain.gd")

func _init() -> void:
	route_label = "OTIS ROUTE"

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
		motion.relative = Vector2(0, signf(pixels) * 6.0)
		player._unhandled_input(motion)
		await get_tree().physics_frame

func _route() -> void:
	CampaignClock.new().configure_date(1929, 2, 1, 12 * 60)
	var main: Node3D = world.shop_counters.get("otis_son")
	var point: Node3D = world.shop_counters.get("otis_fountain")
	var fountain: Node3D = world.otis_fountain
	if not _require(main != null and point != null and fountain != null, "Otis has a counter and a fountain"): return
	_require("soda_at_the_fountain" in point.item_ids and "egg_cream" in point.item_ids and point.item_ids.size() == 2, "the fountain sells the fountain's: %s" % str(point.item_ids))
	_require("earplugs_wax_pair" in main.item_ids and "soda_at_the_fountain" not in main.item_ids, "the counter sells the rest: %s" % str(main.item_ids))
	var economy: Node = world.get_node("CaretakerEconomy")
	economy.book().cash = 300
	var hand: Node = Hands.new()
	hand.set_meta("shared_world_validation", true)
	add_child(hand)
	hand.player = player

	player.global_position = main.global_position + Vector3(0, -1.06, -1.1)
	await get_tree().create_timer(0.4).timeout
	player.camera.look_at(main.global_position)
	await _capture_interaction("otis_counter")
	main.select(main.item_ids.find("earplugs_wax_pair"))
	var cash := int(economy.book().cash)
	_require(await hand._stroke(main.terminal, main.terminal.TRAVEL), "the real hand buys earplugs")
	_require(int(economy.book().cash) == cash - 10 and PersonInventory.goods_count("player", "earplugs_wax_pair") == 1, "ten cents, and they are carried")

	player.global_position = point.global_position + Vector3(0, -1.08, 0.95)
	await get_tree().create_timer(0.6).timeout
	player.camera.look_at(point.global_position)
	await get_tree().physics_frame
	_require(not fountain.cup.visible, "no cup before an order")
	point.select(point.item_ids.find("soda_at_the_fountain"))
	cash = int(economy.book().cash)
	_require(await hand._stroke(point.terminal, point.terminal.TRAVEL), "the real hand orders a soda")
	_require(int(economy.book().cash) == cash - 5 and fountain.cup.visible, "five cents, and the cup comes up")
	_require(is_zero_approx(float(Fountain.book().drawn)) and float(Fountain.book().owed) == Fountain.PORTION, "the cup is empty and the portion owed")
	player.camera.look_at(point.global_position)
	await _capture_interaction("otis_fountain_point")
	await _capture_interaction("otis_cup_empty")

	# Nothing to drink yet: lifting the empty cup does not spend the portion.
	var grip: Dictionary = await _aim(fountain.cup.global_position + Vector3.UP * 0.04)
	_require(grip.get("part") == fountain.cup, "the ray reaches the cup: %s" % str(grip.get("part")))
	await _click()
	await _drag(-260.0)
	await get_tree().create_timer(0.4).timeout
	_require(float(Fountain.book().owed) == Fountain.PORTION, "an empty cup at the mouth drinks nothing")
	await _click()
	await get_tree().create_timer(1.0).timeout

	# The tap.
	_require(fountain.handle != null, "the tap handle is its own moving part")
	if fountain.handle == null: return
	var at: Vector3 = fountain.handle.to_global(fountain.handle.get_aabb().get_center())
	var rest: Vector3 = at
	grip = await _aim(at)
	_require(grip.get("owner") == fountain and grip.get("part") == fountain.handle, "the ray reaches the tap handle: %s" % str(grip.get("part")))
	await _click()
	_require(player._grab.active() and is_zero_approx(fountain.pull), "a click grabs and does not open it")
	await get_tree().create_timer(0.4).timeout
	_require(is_zero_approx(float(Fountain.book().drawn)), "a closed tap runs nothing")
	await _drag(150.0)
	_require(fountain.pull >= Fountain.PULL * Fountain.OPEN_AT, "motion opens it: %f" % fountain.pull)
	_require(fountain.handle.to_global(fountain.handle.get_aabb().get_center()).distance_to(rest) > 0.03, "and the handle visibly moves")
	player.camera.look_at(at + Vector3.DOWN * 0.1)
	await _capture_interaction("otis_tap_open")
	await get_tree().create_timer(1.5).timeout
	var drawn := float(Fountain.book().drawn)
	_require(drawn > 1.0, "the cup fills while it is held open: %f" % drawn)
	await _click()
	_require(not player._grab.active(), "the next click lets go")
	await get_tree().create_timer(0.6).timeout
	_require(is_zero_approx(fountain.pull), "the handle springs back: %f" % fountain.pull)
	var stopped := float(Fountain.book().drawn)
	await get_tree().create_timer(0.5).timeout
	_require(is_equal_approx(float(Fountain.book().drawn), stopped), "and the tap stops running")

	# Drink it.
	grip = await _aim(fountain.cup.global_position + Vector3.UP * 0.04)
	var before := float(Fountain.book().drawn)
	await _click()
	await get_tree().create_timer(0.4).timeout
	_require(is_equal_approx(float(Fountain.book().drawn), before), "nothing goes down on the counter")
	await _drag(-260.0)
	_require(fountain.cup.global_position.distance_to(player.camera.global_position) < 0.4, "motion lifts it to the mouth")
	await _capture_interaction("otis_lifted")
	await get_tree().create_timer(1.0).timeout
	_require(float(Fountain.book().drawn) < before - 0.5, "at the mouth it goes down: %f" % float(Fountain.book().drawn))
	await _click()
	await get_tree().create_timer(1.2).timeout
	_require(is_zero_approx(fountain.lift), "the cup settles back")

	_require(Fountain.valid({"drawn": 1.0, "owed": 0.0}) and not Fountain.valid({"drawn": -1.0, "owed": 0.0}) and not Fountain.valid({"drawn": 1.0}), "the save shape is validated")
	RealityState.data[Fountain.KEY] = {"drawn": 0.0, "owed": 0.0}
	fountain.refresh()
	await get_tree().create_timer(0.1).timeout
	_require(not fountain.cup.visible, "an empty book leaves the fountain clear")
	RealityState.data[Fountain.KEY] = {"drawn": 2.0, "owed": 0.0}
	fountain.refresh()
	_require(fountain.cup.visible, "what is saved comes back")
	RealityState.data[Fountain.KEY] = {"drawn": 0.0, "owed": 0.0}
	fountain.refresh()
