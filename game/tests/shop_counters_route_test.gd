extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Selling in the production V2 root with the real hand: the Hardware counter's
## selector slides to a stop and its lever settles the sale; the goods land in the
## case; News settles into a single transport slot; the Bodega sells a
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

func _fitted_counter_support(shop_id: String, model_name: String, point: Node3D) -> bool:
	var model := world.passage_region.shop_fitting("shop_" + shop_id,model_name)
	var mesh := model.find_child("*counter__countertop",true,false) as MeshInstance3D if model != null else null
	if mesh == null: return false
	var bounds: AABB = mesh.global_transform * mesh.get_aabb()
	var at := point.global_position
	return absf(at.y-bounds.end.y)<.001 and at.x>bounds.position.x and at.x<bounds.end.x \
		and at.z>bounds.position.z and at.z<bounds.end.z

## The bodega has no prepared fitting; its counter top is an authored box.
func _bodega_counter_support(point: Node3D) -> bool:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(OrisonV2ExteriorCell.GEOMETRY_PATH))
	if source is not Dictionary: return false
	var top: Dictionary = {}
	for template: Dictionary in source.templates:
		if template.id != "TEMPLATE_BODEGA_CELL_V1": continue
		for box: Dictionary in template.boxes:
			if box.id == "counter_top": top = box
	if top.is_empty(): return false
	var frame: Transform3D = world.exterior_cell.spatial_resolver.instance_world_transform("SHOP_BODEGA")
	var local: Vector3 = frame.affine_inverse() * point.global_position
	var centre := Vector3(float(top.position_m[0]), float(top.position_m[1]), float(top.position_m[2]))
	var half := Vector3(float(top.size_m[0]), float(top.size_m[1]), float(top.size_m[2])) * .5
	var ok := absf(local.y - (centre.y + half.y)) < .002 and absf(local.x - centre.x) < half.x \
		and absf(local.z - centre.z) < half.z
	if not ok: print("[SHOP COUNTERS] bodega terminal local=", local, " top=", centre, "+", half)
	return ok

func _route() -> void:
	var points: Dictionary = world.shop_counters
	for shop_id: String in ["hardware_paint", "news_cigars", "bodega"]:
		if not _require(points.get(shop_id) is Node3D, shop_id + " has a counter"): return
	if world.passage_region.uses_prepared_geometry():
		if not _require(world.passage_region.uses_prepared_geometry(),"the real world loaded the prepared arcade"): return
		if not _require(_fitted_counter_support("hardware_paint","HardwareStock",points.hardware_paint),
			"Hardware's terminal rests on its relocated native counter"): return
		if not _require(_fitted_counter_support("news_cigars","NewsFittings",points.news_cigars),
			"News's terminal rests on its relocated native counter"): return
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
	_require(_bodega_counter_support(bodega), "the Bodega's terminal rests on its counter top")
	# Aim inside a run of groceries so one stop either side is still a grocery.
	var aim_at := grocery_at
	for i in range(grocery_at, bodega.item_ids.size() - 1):
		if str(bodega.sales.stock_record(bodega.item_ids[i + 1]).kind) == "grocery":
			aim_at = i + 1
			break
	var bodega_moved: bool = await _slide_selector(bodega, bodega._stop_travel(aim_at))
	_require(bodega_moved, "the real hand walks the Bodega's selector down its list")
	var item: String = bodega.selected_item()
	_require(str(bodega.sales.stock_record(item).kind) == "grocery",
			"the hand-chosen stop is a grocery: " + item)
	await _capture_interaction("shop_bodega_selected")
	_require(await _hand._stroke(bodega.terminal, bodega.terminal.TRAVEL), "the real hand settles a grocery")
	_require(bodega.flag.text == "SETTLED", "the Bodega's flag says settled: " + bodega.flag.text)
	_require(PersonInventory.carried("player", item) > 0.0, "and goes in the bag")

	# News: ordinary stock at the counter and newspapers at the rack.
	await _stand_before(points.news_cigars)
	await _capture_interaction("shop_news_counter")
	var news: Node3D = points.news_cigars
	var news_cash := int(economy.book().cash)
	_require(news.selected_item() != "the_borough_record", "the counter leaves papers to the rack")
	_require(await _hand._stroke(news.terminal, news.terminal.TRAVEL), "the real hand settles at News")
	_require(int(economy.book().cash) < news_cash, "News charges its price")
	await _newspaper_sales(economy)

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


func _newspaper_sales(economy: Node) -> void:
	var stand := world.passage_region.transaction_actor_root().get_node_or_null("NewsStand") as NewsRackProp
	if not _require(stand != null and stand.sales != null,"the rack knows its counter"): return
	var catalog := stand._catalog()
	var offers := NewsRackProp.offers_for(catalog,catalog.today(),true)
	if not _require(offers.size() >= 2,"the rack offers two published papers"): return
	var first := offers[0]
	var second := offers[1]
	var first_key := NewspaperCatalog.key_of(str(first.paper),str(first.date))
	var second_key := NewspaperCatalog.key_of(str(second.paper),str(second.date))
	var first_price := int(stand.sales.stock_record(NewsRackProp.SALE_ITEMS[first.paper]).price_cents)
	var second_price := int(stand.sales.stock_record(NewsRackProp.SALE_ITEMS[second.paper]).price_cents)
	var stock := stand.sales.stock
	var before := int(economy.book().cash)
	var units := stock.units(stand.sales.shop_id,"papers")
	_require(stand._take(player,catalog,str(first.paper),str(first.date)),"the rack sells the first issue")
	_require(int(economy.book().cash) == before - first_price
		and is_equal_approx(stock.units(stand.sales.shop_id,"papers"),units - 1.0),
		"the first issue debits its price and one stock unit")
	_require(catalog.is_collected(str(first.paper),str(first.date)) and PaperPocket.transit_news() == first_key,
		"the first issue is kept in the single transport slot")
	if stand._panel != null: stand._panel.close()
	await get_tree().process_frame

	before = int(economy.book().cash)
	units = stock.units(stand.sales.shop_id,"papers")
	_require(not stand._take(null,catalog,str(second.paper),str(second.date))
		and int(economy.book().cash) == before and is_equal_approx(stock.units(stand.sales.shop_id,"papers"),units)
		and not catalog.is_collected(str(second.paper),str(second.date)) and PaperPocket.transit_news() == first_key,
		"a full newspaper slot refuses a second paid issue without changing cash, stock or custody")

	var stack := world.news_stack as NewsStackProp
	if not _require(stack != null,"the apartment's physical stack is mounted"): return
	var filed := stack.count()
	_require(PaperPocket.file_news() and stack.count() == filed + 1 and PaperPocket.has_room_for_news()
		and catalog.is_collected(str(first.paper),str(first.date)),
		"filing moves the kept issue from the slot to the apartment stack")
	economy.book().cash = 0
	_require(not stand._take(null,catalog,str(second.paper),str(second.date))
		and int(economy.book().cash) == 0 and is_equal_approx(stock.units(stand.sales.shop_id,"papers"),units)
		and not catalog.is_collected(str(second.paper),str(second.date)) and PaperPocket.has_room_for_news(),
		"short cash refuses a paper with an empty slot and leaves stock and custody intact")

	economy.book().cash = 2000
	_require(stand._take(player,catalog,str(second.paper),str(second.date))
		and int(economy.book().cash) == 2000 - second_price
		and is_equal_approx(stock.units(stand.sales.shop_id,"papers"),units - 1.0)
		and PaperPocket.transit_news() == second_key and stack.count() == filed + 1,
		"the next paid issue occupies the freed slot and the first stays on the stack")
	if stand._panel != null: stand._panel.close()
	await get_tree().process_frame
