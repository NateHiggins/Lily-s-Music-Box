extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Selling in the production V2 root with the real hand: the Hardware counter's
## selector slides to a stop and its lever settles the sale; the goods land in the
## case; News charges for a paper and never withholds one; the Bodega sells a
## grocery into the bag; a list taken at a door is carried back and paid for.

const Hands := preload("res://tests/v2_fire_maintenance_hand_bench.gd")

var _hand: Node

func _init() -> void:
	route_label = "SHOP COUNTERS ROUTE"

func _prepare_player_start() -> void:
	player.velocity = Vector3.ZERO

func _stand_before(point: Node3D, distance := 0.95) -> void:
	# Stand the player on the customer side: the terminal's lettering faces local -Z.
	var forward: Vector3 = -point.global_basis.z
	player.global_position = point.global_position + forward * distance + Vector3.DOWN * 1.1
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.camera.look_at(point.global_position)
	await get_tree().physics_frame

func _slide_selector(point: Node3D, goal: float) -> bool:
	await _hand.aim(point.selector.to_global(Vector3(0, .094, -.025)))
	_hand.click()
	if not player._grab.active() or player._grab.target.part != point.selector:
		if player._grab.active():
			_hand.click()
		print("[SHOP COUNTERS] selector not grabbed; hit=", player._grab.last_hit)
		return false
	var moved: bool = await _hand._gesture_to(goal)
	if player._grab.active():
		_hand.click()
	return moved and not player._grab.active()

func _route() -> void:
	var points: Dictionary = world.shop_counters
	for shop_id: String in ["hardware_paint", "news_cigars", "bodega"]:
		_require(points.get(shop_id) is Node3D, shop_id + " has a counter")
	var economy: Node = world.get_node("CaretakerEconomy")
	economy.book().cash = 2000
	_hand = Hands.new()
	_hand.set_meta("shared_world_validation", true)
	add_child(_hand)
	_hand.player = player

	# Hardware: the real hand on the selector, then the lever.
	var hardware: Node3D = points.hardware_paint
	await _stand_before(hardware)
	await _capture_interaction("shop_hardware_counter")
	var chosen: String = hardware.selected_item()
	var moved: bool = await _slide_selector(hardware, 0.05)
	_require(moved, "the real hand moves the selector")
	_require(hardware.selected_item() != chosen, "the selector walks the list")
	chosen = hardware.selected_item()
	var record: Dictionary = hardware.sales.stock_record(chosen)
	var cash := int(economy.book().cash)
	var done: bool = await _hand._stroke(hardware.terminal, hardware.terminal.TRAVEL)
	_require(done, "the real hand strokes the lever")
	_require(int(economy.book().cash) == cash - int(record.price_cents), "the stroke debits the price: " + chosen)
	_require(hardware.flag.text == "SETTLED", "the flag says settled")
	if str(record.kind) in ["goods", "part"]:
		_require(CarriedCase.place_of(chosen).size() > 0, "the goods land in the case")
	await _capture_interaction("shop_hardware_settled")

	# Bodega: a grocery goes in the bag.
	var bodega: Node3D = points.bodega
	await _stand_before(bodega)
	await _capture_interaction("shop_bodega_counter")
	var grocery_at := -1
	for i in bodega.item_ids.size():
		if str(bodega.sales.stock_record(bodega.item_ids[i]).kind) == "grocery":
			grocery_at = i
			break
	_require(bodega.item_ids.size() >= 50, "the Bodega sells the residents' list")
	_require(grocery_at >= 0, "the Bodega sells groceries")
	bodega.select(grocery_at)
	var item: String = bodega.selected_item()
	await _capture_interaction("shop_bodega_selected")
	_require(await _hand._stroke(bodega.terminal, bodega.terminal.TRAVEL), "the real hand settles a grocery")
	_require(bodega.flag.text == "SETTLED", "the Bodega's flag says settled: " + bodega.flag.text)
	_require(PersonInventory.carried("player", item) > 0.0, "and goes in the bag")

	# News: charged when it can, and free when it can't.
	await _stand_before(points.news_cigars)
	await _capture_interaction("shop_news_counter")
	var news: Node3D = points.news_cigars
	var news_cash := int(economy.book().cash)
	_require(news.selected_item() != "the_borough_record", "the counter leaves papers to the rack")
	_require(await _hand._stroke(news.terminal, news.terminal.TRAVEL), "the real hand settles at News")
	_require(int(economy.book().cash) < news_cash, "News charges its price")
	var stand: Node = world.passage_region.transaction_actor_root().get_node("NewsStand")
	_require(stand.sales != null, "the rack knows its counter")
	var catalog: NewspaperCatalog = stand._catalog()
	var offers := NewsRackProp.offers_for(catalog, catalog.today(), true)
	if _require(offers.size() >= 2, "the rack offers papers"):
		var before := int(economy.book().cash)
		stand._take(player, catalog, str(offers[0].paper), str(offers[0].date))
		_require(int(economy.book().cash) < before, "a paper is charged")
		_require(catalog.is_collected(str(offers[0].paper), str(offers[0].date)), "and kept")
		if stand._panel != null:
			stand._panel.close()
		await get_tree().process_frame
		economy.book().cash = 0
		stand._take(player, catalog, str(offers[1].paper), str(offers[1].date))
		_require(catalog.is_collected(str(offers[1].paper), str(offers[1].date)), "being broke never withholds a paper")
		if stand._panel != null:
			stand._panel.close()
		await get_tree().process_frame
		economy.book().cash = 2000

	# An errand, end to end, through the real conversations node.
	var errands: ResidentErrands = world.conversations.errands
	if _require(errands != null and errands.ready(), "errands are bound"):
		var resident := ""
		for candidate: String in world.conversations.resident_ids():
			if errands.can_ask(candidate):
				resident = candidate
				break
		if resident == "":
			var kitchens: KitchenLarder = errands.larder
			resident = "omar_bell"
			var unit := kitchens.unit_of(resident)
			kitchens.state.units[unit].stock = {}
		if _require(errands.can_ask(resident), "someone is short: " + resident):
			var words := errands.list_words(resident)
			_require(words != "", "the list is read out: " + words)
			var door: Dictionary = world.conversations.with_errand(resident, world.conversations.trees[resident])
			_require(door.nodes.has(ResidentConversations.ERRAND_ASK) and not errands.has_open(resident),
					"offering the reply takes nothing down")
			errands.ask(resident)
			_require(not errands.can_deliver(resident), "an empty bag cannot deliver")
			for wanted: String in RealityState.data.resident_errands[resident].items:
				PersonInventory.carry("player", wanted, float(RealityState.data.resident_errands[resident].items[wanted]))
			var paid := int(economy.book().cash)
			_require(errands.can_deliver(resident), "a full bag can")
			_require(errands.deliver(resident), "the list is handed over")
			_require(int(economy.book().cash) > paid, "the errand tips")
			_require(not errands.can_ask(resident), "and not again today")
			for wanted: String in RealityState.data.resident_errands[resident].items:
				_require(PersonInventory.carried(resident, wanted) > 0.0, "the bag is the resident's: " + wanted)
	_require(ResidentErrands.valid(RealityState.data.get("resident_errands", {})), "errands stay valid")
	await _capture_interaction("shop_news_counter_after")
